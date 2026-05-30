package main

import (
	"context"
	"database/sql"
	"fmt"
	"io"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/joho/godotenv"
	_ "github.com/marcboeker/go-duckdb"

	"github.com/patrickSevans123/superapp-api/database"
)

// ─── Globals ─────────────────────────────────────────────────────────────────

var db *sql.DB



// ─── Main ────────────────────────────────────────────────────────────────────

func main() {
	_ = godotenv.Load()

	// ── DuckDB initialisation (non-fatal — scholarship queries only) ──
	var err error
	dbPath := os.Getenv("DUCKDB_PATH")
	if dbPath == "" {
		dbPath = "services/beasiswa_crawler/data/scholarships.duckdb" // relative to repo root
	}
	db, err = sql.Open("duckdb", dbPath+"?access_mode=read_only&threads=4")
	if err != nil {
		log.Printf("WARN: DuckDB unavailable (scholarship queries disabled): %v", err)
		db = nil
	} else {
		db.SetMaxOpenConns(1)
		if err = db.Ping(); err != nil {
			log.Printf("WARN: DuckDB ping failed (scholarship queries disabled): %v", err)
			db.Close()
			db = nil
		} else {
			log.Println("Connected to DuckDB (read-only)")
		}
	}

	// ── SQLite initialisation (local auth + data store) ──────────────
	sqlitePath := os.Getenv("SQLITE_PATH")
	if sqlitePath == "" {
		sqlitePath = "data/superapp.db"
	}
	if err := database.Init(sqlitePath); err != nil {
		log.Fatalf("Failed to init SQLite: %v", err)
	}
	if err := database.RunMigrations(); err != nil {
		log.Fatalf("Failed to run SQLite migrations: %v", err)
	}
	defer database.DB.Close()
	log.Println("SQLite initialised and migrated")

	// ── Fiber app ───────────────────────────────────────────────────────
	app := fiber.New(fiber.Config{
		AppName: "superapp-api",
	})

	// Middleware
	app.Use(recover.New())
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
	}))

	// Health check
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok", "service": "superapp-api"})
	})

	// API v1
	v1 := app.Group("/api/v1")

	// ─── Auth middleware (applied to all v1 routes, skips auth paths) ──
	v1.Use(authMiddleware)

	// ─── Auth endpoints (no auth required, skipped by middleware) ──────
	v1.Post("/auth/register", handleRegister)
	v1.Post("/auth/login", handleLogin)
	v1.Post("/auth/refresh", handleRefresh)
	v1.Post("/auth/logout", handleLogout)

	// ─── Trade endpoints ───
	trade := v1.Group("/market")
	trade.Get("/quote", handleMarketQuote)
	trade.Get("/quotes", handleMarketQuotes)

	v1.Get("/plans", handlePlans)
	v1.Get("/plans/summary", handlePlansSummary)
	v1.Get("/news", handleNews)
	v1.Get("/events", handleEvents)

	// ─── Scholarship endpoints ───
	v1.Get("/scholarships", handleListScholarships)
	// Saved/bookmarked scholarships (must register before :id to avoid conflict)
	v1.Get("/scholarships/saved", handleGetSavedScholarships)
	v1.Post("/scholarships/:id/save", handleSaveScholarship)
	v1.Delete("/scholarships/:id/save", handleUnsaveScholarship)
	v1.Get("/scholarships/:id", handleGetScholarship)

	// ─── Fashion / Wardrobe (proxied to Supabase) ───
	wardrobe := v1.Group("/wardrobe")
	wardrobe.Get("/", HandleGetWardrobe)
	wardrobe.Post("/", HandleCreateWardrobeItem)
	wardrobe.Get("/insights", HandleGetWardrobeInsights)
	wardrobe.Get("/:id", HandleGetWardrobeItem)
	wardrobe.Patch("/:id", HandleUpdateWardrobeItem)
	wardrobe.Delete("/:id", HandleDeleteWardrobeItem)
	wardrobe.Post("/:id/worn", HandleMarkWorn)

	// ─── Try-On ───
	tryon := v1.Group("/tryon")
	tryon.Get("/history", HandleGetTryonHistory)
	tryon.Post("/", HandleCreateTryon)

	// ─── OOTD ───
	ootd := v1.Group("/ootd")
	ootd.Get("/", HandleGetOOTDLogs)

	// ─── Profile endpoints ───
	v1.Get("/profile", handleGetProfile)
	v1.Patch("/profile", handleUpdateProfile)

	// ─── Settings endpoints ───
	v1.Get("/settings", handleGetSettings)
	v1.Patch("/settings", handleUpdateSettings)

	// ─── Upload endpoints ───
	v1.Post("/upload/photo", handleUploadPhoto)

	// Serve uploads directory
	uploadsDir := filepath.Join("data", "uploads")
	os.MkdirAll(uploadsDir, 0755)
	app.Static("/uploads", uploadsDir)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	// Graceful shutdown
	go func() {
		log.Printf("🚀 API Gateway starting on :%s", port)
		if err := app.Listen(":" + port); err != nil {
			log.Fatalf("server error: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := app.ShutdownWithContext(shutdownCtx); err != nil {
		log.Fatalf("server forced to shutdown: %v", err)
	}
	log.Println("Server stopped gracefully")
}

// ─── Upload Handler ─────────────────────────────────────────────────────────

// handleUploadPhoto accepts a multipart file upload and returns a public URL.
// POST /api/v1/upload/photo
// Form field: "file"
func handleUploadPhoto(c *fiber.Ctx) error {
	file, err := c.FormFile("file")
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "file field is required"})
	}

	// Validate file size (max 10MB)
	if file.Size > 10*1024*1024 {
		return c.Status(400).JSON(fiber.Map{"error": "file too large, max 10MB"})
	}

	// Validate file extension
	ext := strings.ToLower(filepath.Ext(file.Filename))
	allowedExts := map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true}
	if !allowedExts[ext] {
		return c.Status(400).JSON(fiber.Map{"error": "only .jpg, .jpeg, .png, .webp files are allowed"})
	}

	// Save to data/uploads/
	ext = filepath.Ext(file.Filename)
	filename := fmt.Sprintf("%d%s", time.Now().UnixNano(), ext)
	uploadDir := filepath.Join("data", "uploads")
	os.MkdirAll(uploadDir, 0755)

	dst := filepath.Join(uploadDir, filename)
	src, err := file.Open()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to read uploaded file"})
	}
	defer src.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to save file"})
	}
	defer dstFile.Close()

	if _, err := io.Copy(dstFile, src); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to write file"})
	}

	// Build public URL
	scheme := "http"
	if c.Get("X-Forwarded-Proto") == "https" {
		scheme = "https"
	}
	host := c.Hostname()
	publicURL := fmt.Sprintf("%s://%s/uploads/%s", scheme, host, filename)

	return c.JSON(fiber.Map{"url": publicURL})
}


