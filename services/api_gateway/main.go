package main

import (
	"database/sql"
	"log"
	"os"
	"strconv"
	"strings"
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

// ─── Types ────────────────────────────────────────────────────────────────────

// CoverageDetail holds the flattened coverage_detail fields from DuckDB.
type CoverageDetail struct {
	Tuition        string   `json:"tuition"`
	MonthlyStipend string   `json:"monthly_stipend"`
	Currency       string   `json:"currency"`
	Travel         string   `json:"travel"`
	Accommodation  string   `json:"accommodation"`
	Insurance      string   `json:"insurance"`
	LanguageCourse string   `json:"language_course"`
	Other          []string `json:"other"`
}

// ScholarshipResponse is the full scholarship JSON shape returned to clients.
type ScholarshipResponse struct {
	ID             string          `json:"id"`
	Title          string          `json:"title"`
	Provider       string          `json:"provider"`
	Description    string          `json:"description"`
	Level          []string        `json:"level"`
	Destination    string          `json:"destination"`
	Country        string          `json:"country"`
	Coverage       string          `json:"coverage"`
	CoverageDetail CoverageDetail  `json:"coverage_detail"`
	Deadline       string          `json:"deadline"`
	OpeningDate    string          `json:"opening_date"`
	URL            string          `json:"url"`
	SourceURL      string          `json:"source_url"`
	Requirements   []string        `json:"requirements"`
	FieldOfStudy   []string        `json:"field_of_study"`
	Tags           []string        `json:"tags"`
	FundingType    string          `json:"funding_type"`
	Tips           []string        `json:"tips"`
	Version        int             `json:"version"`
	Checksum       string          `json:"checksum"`
	FoundAt        string          `json:"found_at"`
	UpdatedAt      string          `json:"updated_at"`
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

// scanStringArray converts a DuckDB VARCHAR[] value (returned as []interface{})
// to a []string. Returns an empty slice for nil / non-array values.
func scanStringArray(val interface{}) []string {
	if val == nil {
		return []string{}
	}
	arr, ok := val.([]interface{})
	if !ok {
		return []string{}
	}
	result := make([]string, len(arr))
	for i, v := range arr {
		if s, ok := v.(string); ok {
			result[i] = s
		}
	}
	return result
}

// scanNullString safely converts a nullable string (interface{} from DuckDB)
// to a string, returning "" for nil.
func scanNullString(val interface{}) string {
	if val == nil {
		return ""
	}
	if s, ok := val.(string); ok {
		return s
	}
	return ""
}

// scanNullInt safely converts a nullable int (interface{} from DuckDB)
// to int, returning 0 for nil.
func scanNullInt(val interface{}) int {
	if val == nil {
		return 0
	}
	switch v := val.(type) {
	case int64:
		return int(v)
	case float64:
		return int(v)
	case int:
		return v
	}
	return 0
}

// scanRowToScholarship scans a single row returned by the DuckDB query
// into a ScholarshipResponse.
func scanRowToScholarship(row []interface{}) ScholarshipResponse {
	return ScholarshipResponse{
		ID:          scanNullString(row[0]),
		Title:       scanNullString(row[1]),
		Provider:    scanNullString(row[2]),
		Description: scanNullString(row[3]),
		Level:       scanStringArray(row[4]),
		Destination: scanNullString(row[5]),
		Country:     scanNullString(row[6]),
		Coverage:    scanNullString(row[7]),
		CoverageDetail: CoverageDetail{
			Tuition:        scanNullString(row[8]),
			MonthlyStipend: scanNullString(row[9]),
			Currency:       scanNullString(row[10]),
			Travel:         scanNullString(row[11]),
			Accommodation:  scanNullString(row[12]),
			Insurance:      scanNullString(row[13]),
			LanguageCourse: scanNullString(row[14]),
			Other:          scanStringArray(row[15]),
		},
		Deadline:     scanNullString(row[16]),
		OpeningDate:  scanNullString(row[17]),
		URL:          scanNullString(row[18]),
		SourceURL:    scanNullString(row[19]),
		Requirements: scanStringArray(row[20]),
		FieldOfStudy: scanStringArray(row[21]),
		Tags:         scanStringArray(row[22]),
		FundingType:  scanNullString(row[23]),
		Tips:         scanStringArray(row[24]),
		Version:      scanNullInt(row[25]),
		Checksum:     scanNullString(row[26]),
		FoundAt:      scanNullString(row[27]),
		UpdatedAt:    scanNullString(row[28]),
	}
}

// ─── Main ────────────────────────────────────────────────────────────────────

func main() {
	_ = godotenv.Load()

	// ── DuckDB initialisation ───────────────────────────────────────────
	var err error
	dbPath := os.Getenv("DUCKDB_PATH")
	if dbPath == "" {
		dbPath = "services/beasiswa_crawler/data/scholarships.duckdb" // relative to repo root
	}
	db, err = sql.Open("duckdb", dbPath+"?access_mode=read_only&threads=4")
	if err != nil {
		log.Fatalf("Failed to open DuckDB: %v", err)
	}
	db.SetMaxOpenConns(1)

	// Verify connection
	if err = db.Ping(); err != nil {
		log.Fatalf("Failed to ping DuckDB: %v", err)
	}
	log.Println("Connected to DuckDB (read-only)")

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

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("🚀 API Gateway starting on :%s", port)
	log.Fatal(app.Listen(":" + port))
}

// ─── Handlers (skeletons — will be implemented in Phase 1-3) ───

// handleListScholarships returns a paginated, filterable list of scholarships.
// GET /api/v1/scholarships?q=&level=&country=&funding_type=&page=1&limit=20
func handleListScholarships(c *fiber.Ctx) error {
	// ── Parse query params ──────────────────────────────────────────────
	q := strings.TrimSpace(c.Query("q"))
	level := strings.TrimSpace(c.Query("level"))
	country := strings.TrimSpace(c.Query("country"))
	fundingType := strings.TrimSpace(c.Query("funding_type"))

	page, _ := strconv.Atoi(c.Query("page", "1"))
	if page < 1 {
		page = 1
	}
	limit, _ := strconv.Atoi(c.Query("limit", "20"))
	if limit < 1 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	offset := (page - 1) * limit

	// ── Build dynamic query ─────────────────────────────────────────────
	baseSelect := `SELECT id, title, provider, description, "level", destination, country,
		coverage,
		cd_tuition, cd_monthly_stipend, cd_currency, cd_travel,
		cd_accommodation, cd_insurance, cd_language_course, cd_other,
		deadline, opening_date, url, source_url,
		requirements, field_of_study, tags, funding_type, tips,
		version, checksum, found_at, updated_at
		FROM scholarships WHERE 1=1`

	var args []interface{}

	if q != "" {
		baseSelect += ` AND (title ILIKE ? OR provider ILIKE ? OR description ILIKE ? OR country ILIKE ?)`
		pattern := "%" + q + "%"
		args = append(args, pattern, pattern, pattern, pattern)
	}
	if level != "" {
		baseSelect += ` AND ? = ANY("level")`
		args = append(args, level)
	}
	if country != "" {
		baseSelect += ` AND country ILIKE ?`
		args = append(args, "%"+country+"%")
	}
	if fundingType != "" {
		baseSelect += ` AND funding_type ILIKE ?`
		args = append(args, "%"+fundingType+"%")
	}

	// ── Count query ─────────────────────────────────────────────────────
	countQuery := `SELECT COUNT(*) FROM scholarships WHERE 1=1`
	var countArgs []interface{}
	// Replicate filter logic for the count query
	if q != "" {
		countQuery += ` AND (title ILIKE ? OR provider ILIKE ? OR description ILIKE ? OR country ILIKE ?)`
		pattern := "%" + q + "%"
		countArgs = append(countArgs, pattern, pattern, pattern, pattern)
	}
	if level != "" {
		countQuery += ` AND ? = ANY("level")`
		countArgs = append(countArgs, level)
	}
	if country != "" {
		countQuery += ` AND country ILIKE ?`
		countArgs = append(countArgs, "%"+country+"%")
	}
	if fundingType != "" {
		countQuery += ` AND funding_type ILIKE ?`
		countArgs = append(countArgs, "%"+fundingType+"%")
	}

	var total int
	if err := db.QueryRow(countQuery, countArgs...).Scan(&total); err != nil {
		log.Printf("ERROR counting scholarships: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to count scholarships"})
	}

	// ── Data query ──────────────────────────────────────────────────────
	baseSelect += ` ORDER BY updated_at DESC, title ASC LIMIT ? OFFSET ?`
	args = append(args, limit, offset)

	rows, err := db.Query(baseSelect, args...)
	if err != nil {
		log.Printf("ERROR querying scholarships: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to query scholarships"})
	}
	defer rows.Close()

	scholarships := make([]ScholarshipResponse, 0, limit)
	for rows.Next() {
		vals := make([]interface{}, 29)
		ptrs := make([]interface{}, 29)
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			log.Printf("ERROR scanning scholarship row: %v", err)
			continue
		}
		scholarships = append(scholarships, scanRowToScholarship(vals))
	}

	if err := rows.Err(); err != nil {
		log.Printf("ERROR iterating scholarship rows: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to read scholarships"})
	}

	return c.JSON(fiber.Map{
		"data":  scholarships,
		"total": total,
		"page":  page,
		"limit": limit,
	})
}

// handleGetScholarship returns a single scholarship by its id.
// GET /api/v1/scholarships/:id
func handleGetScholarship(c *fiber.Ctx) error {
	id := c.Params("id")

	query := `SELECT id, title, provider, description, "level", destination, country,
		coverage,
		cd_tuition, cd_monthly_stipend, cd_currency, cd_travel,
		cd_accommodation, cd_insurance, cd_language_course, cd_other,
		deadline, opening_date, url, source_url,
		requirements, field_of_study, tags, funding_type, tips,
		version, checksum, found_at, updated_at
		FROM scholarships WHERE id = ?`

	vals := make([]interface{}, 29)
	ptrs := make([]interface{}, 29)
	for i := range vals {
		ptrs[i] = &vals[i]
	}

	err := db.QueryRow(query, id).Scan(ptrs...)
	if err == sql.ErrNoRows {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	if err != nil {
		log.Printf("ERROR querying scholarship %s: %v", id, err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to query scholarship"})
	}

	return c.JSON(scanRowToScholarship(vals))
}

// ─── Saved / Bookmarked Scholarship Handlers (placeholder) ────────────────

// handleSaveScholarship saves (bookmarks) a scholarship for a user.
// POST /api/v1/scholarships/:id/save
func handleSaveScholarship(c *fiber.Ctx) error {
	id := c.Params("id")
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	uid := userID.(string)

	var body struct {
		Status string `json:"status"`
		Notes  string `json:"notes"`
	}
	_ = c.BodyParser(&body)
	if body.Status == "" {
		body.Status = "interested"
	}

	// Upsert based on (user_id, scholarship_id) uniqueness
	_, err := database.DB.Exec(
		`INSERT INTO saved_scholarships (id, user_id, scholarship_id, notes, status)
		 VALUES (?, ?, ?, ?, ?)
		 ON CONFLICT(user_id, scholarship_id) DO UPDATE SET status = ?, notes = ?`,
		randomID(), uid, id, body.Notes, body.Status, body.Status, body.Notes,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to save scholarship"})
	}

	return c.JSON(fiber.Map{
		"saved": true,
		"id":    id,
	})
}

// handleGetSavedScholarships returns saved scholarship IDs for a user.
// GET /api/v1/scholarships/saved
func handleGetSavedScholarships(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	uid := userID.(string)

	rows, err := database.DB.Query("SELECT scholarship_id FROM saved_scholarships WHERE user_id = ?", uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query saved scholarships"})
	}
	defer rows.Close()

	var savedIDs []string
	for rows.Next() {
		var sid string
		if err := rows.Scan(&sid); err == nil {
			savedIDs = append(savedIDs, sid)
		}
	}

	if savedIDs == nil {
		savedIDs = []string{}
	}

	return c.JSON(fiber.Map{
		"data":  savedIDs,
		"total": len(savedIDs),
	})
}

// handleUnsaveScholarship removes a saved/bookmarked scholarship.
// DELETE /api/v1/scholarships/:id/save
func handleUnsaveScholarship(c *fiber.Ctx) error {
	id := c.Params("id")
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}
	uid := userID.(string)

	_, err := database.DB.Exec(
		"DELETE FROM saved_scholarships WHERE scholarship_id = ? AND user_id = ?",
		id, uid,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to unsave scholarship"})
	}

	return c.JSON(fiber.Map{
		"saved": false,
		"id":    id,
	})
}

func handleGetProfile(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "authentication required"})
	}

	rows, err := database.DB.Query("SELECT * FROM profiles WHERE id = ?", userID.(string))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query profile"})
	}
	defer rows.Close()

	profile, err := scanOneRow(rows)
	if err == sql.ErrNoRows {
		return c.Status(404).JSON(fiber.Map{"error": "profile not found"})
	}
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse profile"})
	}

	return c.JSON(profile)
}

func handleUpdateProfile(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "authentication required"})
	}

	var body struct {
		DisplayName *string `json:"display_name"`
		AvatarURL   *string `json:"avatar_url"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}

	// Build SET clause with only provided fields
	var setClauses []string
	var args []interface{}
	if body.DisplayName != nil {
		setClauses = append(setClauses, "display_name = ?")
		args = append(args, *body.DisplayName)
	}
	if body.AvatarURL != nil {
		setClauses = append(setClauses, "avatar_url = ?")
		args = append(args, *body.AvatarURL)
	}

	if len(setClauses) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "no fields to update"})
	}

	args = append(args, userID.(string))
	_, err := database.DB.Exec(
		"UPDATE profiles SET "+strings.Join(setClauses, ", ")+" WHERE id = ?",
		args...,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to update profile"})
	}

	// Return updated profile
	rows, err := database.DB.Query("SELECT * FROM profiles WHERE id = ?", userID.(string))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query updated profile"})
	}
	defer rows.Close()

	profile, err := scanOneRow(rows)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse updated profile"})
	}

	return c.JSON(profile)
}

// ─── Settings Handlers ─────────────────────────────────────────────────────

// user_preferences table schema:
//
//	CREATE TABLE IF NOT EXISTS user_preferences (
//	  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
//	  user_id TEXT NOT NULL UNIQUE,
//	  tp_hit BOOLEAN DEFAULT true,
//	  sl_hit BOOLEAN DEFAULT true,
//	  price_alert BOOLEAN DEFAULT true,
//	  msci_announce BOOLEAN DEFAULT true,
//	  ftse_notice BOOLEAN DEFAULT true,
//	  new_report BOOLEAN DEFAULT true,
//	  plan_created BOOLEAN DEFAULT true,
//	  scholarship_alert BOOLEAN DEFAULT true,
//	  fashion_alert BOOLEAN DEFAULT true,
//	  created_at TIMESTAMPTZ DEFAULT now()
//	);

// handleGetSettings returns the combined account and preferences for a user.
// GET /api/v1/settings
func handleGetSettings(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "authentication required"})
	}
	uid := userID.(string)

	// Fetch profile from SQLite
	profileRows, err := database.DB.Query("SELECT * FROM profiles WHERE id = ?", uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query profile"})
	}
	defer profileRows.Close()

	profile, err := scanOneRow(profileRows)
	if err != nil {
		profile = map[string]interface{}{}
	}

	// Fetch preferences from SQLite
	prefRows, err := database.DB.Query("SELECT * FROM user_preferences WHERE user_id = ?", uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query preferences"})
	}
	defer prefRows.Close()

	prefs, err := scanOneRow(prefRows)
	if err != nil {
		prefs = map[string]interface{}{}
	}

	return c.JSON(fiber.Map{
		"account":     profile,
		"preferences": prefs,
	})
}

// handleUpdateSettings updates account and/or preference fields for a user.
// PATCH /api/v1/settings
func handleUpdateSettings(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "authentication required"})
	}
	uid := userID.(string)

	var body struct {
		DisplayName *string                `json:"display_name"`
		AvatarURL   *string                `json:"avatar_url"`
		Preferences *map[string]interface{} `json:"preferences"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}

	updated := false

	// Update profile fields if provided
	if body.DisplayName != nil || body.AvatarURL != nil {
		var setClauses []string
		var args []interface{}
		if body.DisplayName != nil {
			setClauses = append(setClauses, "display_name = ?")
			args = append(args, *body.DisplayName)
		}
		if body.AvatarURL != nil {
			setClauses = append(setClauses, "avatar_url = ?")
			args = append(args, *body.AvatarURL)
		}
		args = append(args, uid)
		_, err := database.DB.Exec(
			"UPDATE profiles SET "+strings.Join(setClauses, ", ")+" WHERE id = ?",
			args...,
		)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "failed to update profile"})
		}
		updated = true
	}

	// Update preferences if provided
	if body.Preferences != nil {
		prefs := *body.Preferences
		// Remove non-preference keys
		delete(prefs, "id")
		delete(prefs, "user_id")
		delete(prefs, "created_at")

		if len(prefs) > 0 {
			// Check if preferences row exists
			var exists int
			err := database.DB.QueryRow("SELECT 1 FROM user_preferences WHERE user_id = ?", uid).Scan(&exists)

			if err == sql.ErrNoRows {
				// Insert new preferences row
				var cols []string
				var vals []string
				var args []interface{}
				args = append(args, randomID(), uid)
				for k, v := range prefs {
					cols = append(cols, k)
					vals = append(vals, "?")
					args = append(args, v)
				}
				args = append(args, time.Now().UTC().Format("20060102T150405Z"))
				cols = append(cols, "created_at")
				vals = append(vals, "?")

				_, err = database.DB.Exec(
					"INSERT INTO user_preferences (id, user_id, "+strings.Join(cols, ", ")+") VALUES (?, ?, "+strings.Join(vals, ", ")+")",
					args...,
				)
			} else {
				// Update existing preferences row
				var setClauses []string
				var args []interface{}
				for k, v := range prefs {
					setClauses = append(setClauses, k+" = ?")
					args = append(args, v)
				}
				args = append(args, uid)
				_, err = database.DB.Exec(
					"UPDATE user_preferences SET "+strings.Join(setClauses, ", ")+" WHERE user_id = ?",
					args...,
				)
			}
			if err != nil {
				return c.Status(500).JSON(fiber.Map{"error": "failed to update preferences"})
			}
			updated = true
		}
	}

	if !updated {
		return c.Status(400).JSON(fiber.Map{"error": "no fields to update"})
	}

	// Return combined settings
	profileRows, err := database.DB.Query("SELECT * FROM profiles WHERE id = ?", uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query profile"})
	}
	defer profileRows.Close()

	profile, err := scanOneRow(profileRows)
	if err != nil {
		profile = map[string]interface{}{}
	}

	prefRows, err := database.DB.Query("SELECT * FROM user_preferences WHERE user_id = ?", uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query preferences"})
	}
	defer prefRows.Close()

	prefs, err := scanOneRow(prefRows)
	if err != nil {
		prefs = map[string]interface{}{}
	}

	return c.JSON(fiber.Map{
		"account":     profile,
		"preferences": prefs,
	})
}
