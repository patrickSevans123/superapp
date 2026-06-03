package main

import (
	"bytes"
	"context"
	"database/sql"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/limiter"
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
	if _, err := getJWTSecret(); err != nil {
		log.Fatal(err)
	}

	// ── DuckDB initialisation (fully optional, zero coupling) ──
	// Set DUCKDB_PATH env var if you want scholarship queries.
	// This does NOT depend on any external project path.
	var err error
	dbPath := os.Getenv("DUCKDB_PATH")
	if dbPath == "" {
		log.Println("INFO: DUCKDB_PATH not set — scholarship queries disabled (zero-coupling mode)")
		db = nil
	} else {
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

	// ── Background maintenance: clean up expired JWT blacklist entries
	// every 15 minutes. Previously this ran on every authenticated request
	// (a DB write per request — wasteful).
	stopCleanup := startBlacklistCleanup(15 * time.Minute)

	// ── Fiber app ───────────────────────────────────────────────────────
	app := fiber.New(fiber.Config{
		AppName: "superapp-api",
	})

	// Middleware
	app.Use(recover.New())
	app.Use(logger.New())

	corsOrigins := os.Getenv("CORS_ALLOWED_ORIGINS")
	if corsOrigins == "" {
		corsOrigins = "http://localhost:3000,http://localhost:5173"
	}
	app.Use(cors.New(cors.Config{
		AllowOrigins: corsOrigins,
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
	}))

	// Health check (liveness — always returns 200 if process is up)
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok", "service": "superapp-api"})
	})

	// Readiness check — verifies critical dependencies. Returns 503 if any
	// required dependency is unreachable so load balancers can drain traffic.
	// This is what monitoring should poll, not /health.
	app.Get("/health/ready", handleReadiness)

	// API v1
	v1 := app.Group("/api/v1")

	// ─── Auth middleware (applied to all v1 routes, skips auth paths) ──
	v1.Use(authMiddleware)

	// ─── Auth endpoints (no auth required, skipped by middleware) ──────
	// Rate limiter for auth routes: 20 req/min per IP
	authLimiter := limiter.New(limiter.Config{
		Max:        20,
		Expiration: 1 * time.Minute,
		KeyGenerator: func(c *fiber.Ctx) string {
			return c.IP()
		},
		LimitReached: func(c *fiber.Ctx) error {
			return c.Status(429).JSON(fiber.Map{"error": "too many requests, please try again later"})
		},
	})
	auth := v1.Group("/auth", authLimiter)
	auth.Post("/register", handleRegister)
	auth.Post("/login", handleLogin)
	auth.Post("/refresh", handleRefresh)
	auth.Post("/logout", handleLogout)

	// ─── Trade endpoints ───
	trade := v1.Group("/market")
	trade.Get("/quote", handleMarketQuote)
	trade.Get("/quotes", handleMarketQuotes)

	v1.Get("/plans", handlePlans)
	v1.Get("/plans/summary", handlePlansSummary)
	v1.Get("/news", handleNews)
	v1.Get("/news/status", handleNewsStatus)
	v1.Get("/events", handleEvents)
	v1.Get("/scrapers/health", handleScrapersHealth)
	v1.Get("/reports", handleDailyReports)
	v1.Get("/research-reports", handleResearchReports)
	v1.Get("/research-reports/:id", handleResearchReportByID)

	// ─── Trade Intelligence endpoints (signals, regime, briefing) ───
	v1.Get("/signals/:asset", handleSignals)
	v1.Get("/regime", handleRegime)
	v1.Get("/briefing/today", handleMorningBriefing)
	v1.Get("/sentiment", handleSentiment)
	v1.Get("/technical/:ticker", handleTechnical)

	// ─── LPDP endpoints ───
	lpdp := v1.Group("/lpdp")
	lpdp.Get("/universities", handleLPDPUniversities)
	lpdp.Get("/universities/:name", handleLPDPUniversityDetail)
	lpdp.Get("/programs", handleLPDPPrograms)
	lpdp.Get("/stats", handleLPDPStats)
	lpdp.Get("/search", handleLPDPSearch)

	// ─── Scholarship endpoints ───
	v1.Get("/scholarships", handleListScholarships)
	// Saved/bookmarked scholarships (must register before :id to avoid conflict)
	v1.Get("/scholarships/saved", handleGetSavedScholarships)
	v1.Get("/scholarships/stats", handleScholarshipStats)
	v1.Get("/scholarships/batch", handleGetScholarshipsBatch)
	v1.Get("/scholarships/:id/related", handleGetRelatedScholarships)
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
	// VTON upstream (Replicate / Fashn) is expensive — ~5-15s per call and
	// costs real money. Cap each user to 10 try-on requests per minute to
	// prevent abuse and runaway cost. Falls back to IP keying for unauth'd
	// requests (defence in depth — auth middleware should run first).
	tryonLimiter := limiter.New(limiter.Config{
		Max:        10,
		Expiration: 1 * time.Minute,
		KeyGenerator: func(c *fiber.Ctx) string {
			if uid, ok := c.Locals("user_id").(string); ok && uid != "" {
				return uid
			}
			return c.IP()
		},
		LimitReached: func(c *fiber.Ctx) error {
			return c.Status(429).JSON(fiber.Map{"error": "try-on rate limit exceeded, please slow down"})
		},
	})
	tryon := v1.Group("/tryon")
	tryon.Get("/history", HandleGetTryonHistory)
	tryon.Post("/", tryonLimiter, HandleCreateTryon)
	tryon.Delete("/:id", HandleDeleteTryonResult)

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

	// ─── Static reference data (university, country tips, fashion, trade) ──
	// These endpoints are public and serve curated reference datasets loaded
	// from JSON files at startup. See static_data_handlers.go.
	v1.Get("/reference/status", handleStaticDataStatus)
	v1.Get("/reference/universities", handleListUniversities)
	v1.Get("/reference/universities/:id", handleGetUniversity)
	v1.Get("/reference/country-tips", handleListCountryTips)
	v1.Get("/reference/country-tips/:country", handleGetCountryTips)
	v1.Get("/reference/fashion/brands", handleListBrands)
	v1.Get("/reference/fashion/colors", handleListColors)
	v1.Get("/reference/fashion/ootd-rules", handleGetOOTDRules)
	v1.Get("/reference/trade/idx", handleListIDX)
	v1.Get("/reference/trade/watchlists", handleListWatchlists)

	// Load all static reference datasets into memory
	loadStaticData()

	// Load LPDP data into memory
	loadLPDPData()

	// Serve uploads directory
	uploadsDir := filepath.Join("data", "uploads")
	os.MkdirAll(uploadsDir, 0755)
	app.Static("/uploads", uploadsDir)

	// ─── Beasiswa frontend (optional, zero-coupling) ───
	// Set BEASISWA_DIR=/home/evans/Project/beasiswa to serve the scholarship SPA.
	// This eliminates the need for a separate Python serve.py process.
	if beasiswaDir := os.Getenv("BEASISWA_DIR"); beasiswaDir != "" {
		app.Static("/beasiswa", beasiswaDir, fiber.Static{
			Browse: false,
			Index:  "docs/index.html",
		})
		// Also serve beasiswa root index at /beasiswa/
		app.Get("/beasiswa", func(c *fiber.Ctx) error {
			return c.Redirect("/beasiswa/")
		})
		log.Printf("Beasiswa frontend mounted at /beasiswa from %s", beasiswaDir)
	} else {
		log.Println("INFO: BEASISWA_DIR not set — beasiswa frontend not mounted (zero-coupling mode)")
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// ─── TLS configuration ────────────────────────────────────────────────
	// For production, use a reverse proxy (nginx/Caddy) for TLS termination,
	// OR provide TLS_CERT_FILE + TLS_KEY_FILE for direct TLS.
	certFile := os.Getenv("TLS_CERT_FILE")
	keyFile := os.Getenv("TLS_KEY_FILE")
	useTLS := certFile != "" && keyFile != ""

	// Graceful shutdown — server runs in a goroutine so we can select on
	// either a startup error or an OS signal. Without this, a port conflict
	// would block indefinitely.
	errCh := make(chan error, 1)
	go func() {
		if useTLS {
			log.Printf("🔒 API Gateway starting with TLS on :%s", port)
			errCh <- app.ListenTLS(":"+port, certFile, keyFile)
		} else {
			log.Printf("🚀 API Gateway starting on :%s", port)
			errCh <- app.Listen(":" + port)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err := <-errCh:
		if err != nil {
			close(stopCleanup)
			log.Fatalf("server error: %v", err)
		}
	case sig := <-quit:
		log.Printf("received %s, shutting down", sig)
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := app.ShutdownWithContext(shutdownCtx); err != nil {
			log.Printf("server forced to shutdown: %v", err)
		}
	}

	close(stopCleanup)
	log.Println("Server stopped gracefully")
}

// ─── Readiness Check ────────────────────────────────────────────────────────

// handleReadiness returns 200 only if every critical dependency is reachable.
// Currently checks:
//   - SQLite (local auth + data) — required
//   - DuckDB (scholarship data) — optional (zero-coupling mode)
//   - self-trade Python API — optional (graceful degradation)
//
// Returns 503 if any REQUIRED dependency is down. Optional dependencies are
// reported in the JSON body but do not fail the check — the API gateway
// keeps serving requests with `degraded: true` markers.
func handleReadiness(c *fiber.Ctx) error {
	type depStatus struct {
		OK        bool   `json:"ok"`
		Required  bool   `json:"required"`
		Detail    string `json:"detail,omitempty"`
	}
	deps := map[string]depStatus{}

	// SQLite: required.
	if database.DB != nil {
		if err := database.DB.PingContext(c.Context()); err == nil {
			deps["sqlite"] = depStatus{OK: true, Required: true}
		} else {
			deps["sqlite"] = depStatus{OK: false, Required: true, Detail: err.Error()}
		}
	} else {
		deps["sqlite"] = depStatus{OK: false, Required: true, Detail: "not initialized"}
	}

	// DuckDB: optional (zero-coupling mode means the service is not required).
	if db != nil {
		if err := db.PingContext(c.Context()); err == nil {
			deps["duckdb"] = depStatus{OK: true, Required: false}
		} else {
			deps["duckdb"] = depStatus{OK: false, Required: false, Detail: err.Error()}
		}
	} else {
		deps["duckdb"] = depStatus{OK: false, Required: false, Detail: "DUCKDB_PATH not set (zero-coupling mode)"}
	}

	// self-trade: optional — even if it's down the gateway keeps serving.
	upstreamURL := strings.TrimSuffix(selfTradeBase, "/") + "/api/health"
	req, _ := http.NewRequestWithContext(c.Context(), http.MethodGet, upstreamURL, nil)
	req.Header.Set("User-Agent", userAgent)
	upstreamClient := &http.Client{Timeout: 2 * time.Second}
	if resp, err := upstreamClient.Do(req); err != nil {
		deps["self_trade"] = depStatus{OK: false, Required: false, Detail: err.Error()}
	} else {
		resp.Body.Close()
		deps["self_trade"] = depStatus{OK: resp.StatusCode < 500, Required: false, Detail: fmt.Sprintf("status %d", resp.StatusCode)}
	}

	// Required deps must all be OK for the overall check to pass.
	ready := true
	for _, d := range deps {
		if d.Required && !d.OK {
			ready = false
			break
		}
	}

	status := "ok"
	code := fiber.StatusOK
	if !ready {
		status = "not_ready"
		code = fiber.StatusServiceUnavailable
	}
	return c.Status(code).JSON(fiber.Map{
		"status":        status,
		"service":       "superapp-api",
		"dependencies":  deps,
	})
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

	// Save to data/uploads/ — keep the lowercased extension for consistency
	filename := fmt.Sprintf("%d%s", time.Now().UnixNano(), ext)
	uploadDir := filepath.Join("data", "uploads")
	os.MkdirAll(uploadDir, 0755)

	dst := filepath.Join(uploadDir, filename)
	src, err := file.Open()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to read uploaded file"})
	}
	defer src.Close()

	// ─── Magic-byte validation ─────────────────────────────────────────
	// Extension can be spoofed; sniff the first 512 bytes and reject
	// anything that isn't a real JPEG/PNG/WebP. Prevents uploading e.g.
	// an .exe renamed to .jpg.
	header := make([]byte, 512)
	n, _ := io.ReadFull(src, header)
	detectedMIME := http.DetectContentType(header[:n])
	allowedMIMEs := map[string]bool{
		"image/jpeg": true,
		"image/png":  true,
		"image/webp": true,
	}
	if !allowedMIMEs[detectedMIME] {
		return c.Status(400).JSON(fiber.Map{
			"error": "file content does not match allowed types (image/jpeg, image/png, image/webp)",
		})
	}

	// Replay the bytes we already read, then continue with the rest of the file.
	// Use a separate variable so `src` keeps its multipart.File type for Close().
	body := io.MultiReader(bytes.NewReader(header[:n]), src)

	dstFile, err := os.Create(dst)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to save file"})
	}
	defer dstFile.Close()

	if _, err := io.Copy(dstFile, body); err != nil {
		os.Remove(dst) // best-effort cleanup of partial file
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
