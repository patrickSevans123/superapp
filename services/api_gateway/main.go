package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/joho/godotenv"
	_ "github.com/marcboeker/go-duckdb"
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

	var body struct {
		UserID string `json:"user_id"`
		Status string `json:"status"`
	}
	if err := c.BodyParser(&body); err != nil {
		body.UserID = "" // ignore parse errors for now
	}

	log.Printf("TODO: save scholarship %s for user %s (status=%s)", id, body.UserID, body.Status)
	// TODO: wire to Supabase REST API — upsert into saved_scholarships table

	return c.JSON(fiber.Map{
		"saved": true,
		"id":    id,
	})
}

// handleGetSavedScholarships returns saved scholarship IDs for a user.
// GET /api/v1/scholarships/saved?user_id=xxx
func handleGetSavedScholarships(c *fiber.Ctx) error {
	userID := c.Query("user_id")
	log.Printf("TODO: fetch saved scholarships for user %s", userID)
	// TODO: wire to Supabase REST API — SELECT id FROM saved_scholarships WHERE user_id = ?

	return c.JSON(fiber.Map{
		"data":  []string{},
		"total": 0,
	})
}

// handleUnsaveScholarship removes a saved/bookmarked scholarship.
// DELETE /api/v1/scholarships/:id/save
func handleUnsaveScholarship(c *fiber.Ctx) error {
	id := c.Params("id")

	var body struct {
		UserID string `json:"user_id"`
	}
	if err := c.BodyParser(&body); err != nil {
		body.UserID = ""
	}

	log.Printf("TODO: unsave scholarship %s for user %s", id, body.UserID)
	// TODO: wire to Supabase REST API — DELETE FROM saved_scholarships WHERE id = ? AND user_id = ?

	return c.JSON(fiber.Map{
		"saved": false,
		"id":    id,
	})
}

func handleGetProfile(c *fiber.Ctx) error {
	userID := c.Query("user_id")
	if userID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "user_id query parameter is required"})
	}

	path := "/rest/v1/profiles?select=*&id=eq." + userID
	status, body, err := supabaseRequest("GET", path, nil, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "upstream error", "detail": string(body)})
	}

	// Supabase returns an array; extract the first element
	var items []json.RawMessage
	if err := json.Unmarshal(body, &items); err != nil || len(items) == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "profile not found"})
	}

	var profile map[string]interface{}
	if err := json.Unmarshal(items[0], &profile); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse profile"})
	}

	return c.JSON(profile)
}

func handleUpdateProfile(c *fiber.Ctx) error {
	userID := c.Query("user_id")
	if userID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "user_id query parameter is required"})
	}

	var body struct {
		DisplayName *string `json:"display_name"`
		AvatarURL   *string `json:"avatar_url"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}

	// Build update payload with only provided fields
	payload := make(map[string]interface{})
	if body.DisplayName != nil {
		payload["display_name"] = *body.DisplayName
	}
	if body.AvatarURL != nil {
		payload["avatar_url"] = *body.AvatarURL
	}

	if len(payload) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "no fields to update"})
	}

	path := "/rest/v1/profiles?id=eq." + userID
	status, respBody, err := supabaseJSONRequest("PATCH", path, payload, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "update failed", "detail": string(respBody)})
	}

	// Parse and return the updated profile
	var items []json.RawMessage
	if err := json.Unmarshal(respBody, &items); err != nil || len(items) == 0 {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse updated profile"})
	}

	var profile map[string]interface{}
	if err := json.Unmarshal(items[0], &profile); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse profile"})
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
// GET /api/v1/settings?user_id=xxx
func handleGetSettings(c *fiber.Ctx) error {
	userID := c.Query("user_id")
	if userID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "user_id query parameter is required"})
	}

	// Fetch profile from Supabase
	path := "/rest/v1/profiles?select=*&id=eq." + userID
	status, body, err := supabaseRequest("GET", path, nil, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "upstream error", "detail": string(body)})
	}

	// Supabase returns an array; extract the first element
	var profileItems []json.RawMessage
	if err := json.Unmarshal(body, &profileItems); err != nil || len(profileItems) == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "profile not found"})
	}

	var profile map[string]interface{}
	if err := json.Unmarshal(profileItems[0], &profile); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse profile"})
	}

	// Fetch preferences from Supabase
	prefsPath := "/rest/v1/user_preferences?select=*&user_id=eq." + userID
	pStatus, pBody, err := supabaseRequest("GET", prefsPath, nil, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}

	var prefs interface{}
	// Return empty object if preferences table returns 404 or empty array
	if pStatus == 404 || string(pBody) == "[]" || string(pBody) == "null" {
		prefs = map[string]interface{}{}
	} else if pStatus >= 400 {
		return c.Status(pStatus).JSON(fiber.Map{"error": "upstream error", "detail": string(pBody)})
	} else {
		var prefItems []json.RawMessage
		if err := json.Unmarshal(pBody, &prefItems); err != nil || len(prefItems) == 0 {
			prefs = map[string]interface{}{}
		} else {
			var pref map[string]interface{}
			if err := json.Unmarshal(prefItems[0], &pref); err != nil {
				prefs = map[string]interface{}{}
			} else {
				prefs = pref
			}
		}
	}

	return c.JSON(fiber.Map{
		"account":     profile,
		"preferences": prefs,
	})
}

// handleUpdateSettings updates account and/or preference fields for a user.
// PATCH /api/v1/settings?user_id=xxx
func handleUpdateSettings(c *fiber.Ctx) error {
	userID := c.Query("user_id")
	if userID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "user_id query parameter is required"})
	}

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
		payload := make(map[string]interface{})
		if body.DisplayName != nil {
			payload["display_name"] = *body.DisplayName
		}
		if body.AvatarURL != nil {
			payload["avatar_url"] = *body.AvatarURL
		}

		profilePath := "/rest/v1/profiles?id=eq." + userID
		pStatus, pBody, err := supabaseJSONRequest("PATCH", profilePath, payload, "")
		if err != nil {
			return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
		}
		if pStatus >= 400 {
			return c.Status(pStatus).JSON(fiber.Map{"error": "update failed", "detail": string(pBody)})
		}
		updated = true
	}

	// Update preferences if provided
	if body.Preferences != nil {
		prefsPayload := *body.Preferences
		prefsPayload["user_id"] = userID

		// Check if preferences row exists — POST to create, PATCH to update
		getPath := "/rest/v1/user_preferences?user_id=eq." + userID
		getStatus, getBody, err := supabaseRequest("GET", getPath, nil, "")
		if err != nil {
			return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
		}

		var method, prefsPath string
		if getStatus == 404 || string(getBody) == "[]" {
			method = "POST"
			prefsPath = "/rest/v1/user_preferences"
		} else {
			method = "PATCH"
			prefsPath = "/rest/v1/user_preferences?user_id=eq." + userID
		}

		upStatus, upBody, err := supabaseJSONRequest(method, prefsPath, prefsPayload, "")
		if err != nil {
			return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
		}
		if upStatus >= 400 {
			return c.Status(upStatus).JSON(fiber.Map{"error": "preferences update failed", "detail": string(upBody)})
		}
		updated = true
	}

	if !updated {
		return c.Status(400).JSON(fiber.Map{"error": "no fields to update"})
	}

	// Return combined settings (same format as handleGetSettings)
	// Re-fetch the profile and preferences to build the full response
	profilePath := "/rest/v1/profiles?select=*&id=eq." + userID
	pStatus, pBody, err := supabaseRequest("GET", profilePath, nil, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if pStatus >= 400 {
		return c.Status(pStatus).JSON(fiber.Map{"error": "upstream error", "detail": string(pBody)})
	}

	var profileItems []json.RawMessage
	if err := json.Unmarshal(pBody, &profileItems); err != nil || len(profileItems) == 0 {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse updated profile"})
	}

	var profile map[string]interface{}
	if err := json.Unmarshal(profileItems[0], &profile); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse updated profile"})
	}

	prefsPath := "/rest/v1/user_preferences?select=*&user_id=eq." + userID
	prStatus, prBody, err := supabaseRequest("GET", prefsPath, nil, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}

	var prefs interface{}
	if prStatus == 404 || string(prBody) == "[]" || string(prBody) == "null" {
		prefs = map[string]interface{}{}
	} else if prStatus >= 400 {
		prefs = map[string]interface{}{}
	} else {
		var prefItems []json.RawMessage
		if err := json.Unmarshal(prBody, &prefItems); err != nil || len(prefItems) == 0 {
			prefs = map[string]interface{}{}
		} else {
			var pref map[string]interface{}
			if err := json.Unmarshal(prefItems[0], &pref); err != nil {
				prefs = map[string]interface{}{}
			} else {
				prefs = pref
			}
		}
	}

	return c.JSON(fiber.Map{
		"account":     profile,
		"preferences": prefs,
	})
}
