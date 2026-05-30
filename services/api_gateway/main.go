package main

import (
	"database/sql"
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
	db, err = sql.Open("duckdb", "../beasiswa_crawler/data/scholarships.duckdb?access_mode=read_only&threads=4")
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

func handleListWardrobe(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "wardrobe list — coming in Phase 2"})
}

func handleGetProfile(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{"message": "profile — coming in Phase 1"})
}
