package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()

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

	// ─── Trade endpoints ───
	v1.Get("/market/quote", handleMarketQuote)

	// ─── Scholarship endpoints ───
	v1.Get("/scholarships", handleListScholarships)
	v1.Get("/scholarships/:id", handleGetScholarship)

	// ─── Fashion endpoints (proxied to Supabase) ───
	v1.Get("/wardrobe", handleListWardrobe)

	// ─── Profile endpoints ───
	v1.Get("/profile", handleGetProfile)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("🚀 API Gateway starting on :%s", port)
	log.Fatal(app.Listen(":" + port))
}

// ─── Handlers (skeletons — will be implemented in Phase 1-3) ───

func handleMarketQuote(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "market quote — coming in Phase 3"})
}

func handleListScholarships(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "scholarship list — coming in Phase 1"})
}

func handleGetScholarship(c *fiber.Ctx) error {
	id := c.Params("id")
	return c.JSON(fiber.Map{"id": id, "message": "scholarship detail — coming in Phase 1"})
}

func handleListWardrobe(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "wardrobe list — coming in Phase 2"})
}

func handleGetProfile(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "profile — coming in Phase 1"})
}
