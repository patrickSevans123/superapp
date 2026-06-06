package main

import (
	"database/sql"
	"fmt"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"

	"github.com/patrickSevans123/superapp-api/database"
)

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
	ID                   string         `json:"id"`
	Title                string         `json:"title"`
	Provider             string         `json:"provider"`
	Description          string         `json:"description"`
	Level                []string       `json:"level"`
	Destination          string         `json:"destination"`
	Country              string         `json:"country"`
	Coverage             string         `json:"coverage"`
	CoverageDetail       CoverageDetail `json:"coverage_detail"`
	Deadline             string         `json:"deadline"`
	OpeningDate          string         `json:"opening_date"`
	URL                  string         `json:"url"`
	SourceURL            string         `json:"source_url"`
	Requirements         []string       `json:"requirements"`
	FieldOfStudy         []string       `json:"field_of_study"`
	Tags                 []string       `json:"tags"`
	FundingType          string         `json:"funding_type"`
	Tips                 []string       `json:"tips"`
	Version              int            `json:"version"`
	Checksum             string         `json:"checksum"`
	FoundAt              string         `json:"found_at"`
	UpdatedAt            string         `json:"updated_at"`
	LanguageRequirements string         `json:"language_requirements,omitempty"`
	ApplicationFee       string         `json:"application_fee,omitempty"`
	AgeLimit             string         `json:"age_limit,omitempty"`
	ScholarshipType      string         `json:"scholarship_type,omitempty"`
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

// ─── Scholarship Handlers ─────────────────────────────────────────────────────

// buildScholarshipFilters builds the WHERE clause and args for scholarship queries.
func buildScholarshipFilters(q, level, country, fundingType string, deadlineDays int) (string, []interface{}) {
	var conditions []string
	var args []interface{}
	if q != "" {
		conditions = append(conditions, `(title ILIKE ? OR provider ILIKE ? OR description ILIKE ?)`)
		like := "%" + q + "%"
		args = append(args, like, like, like)
	}
	if level != "" {
		conditions = append(conditions, `? = ANY("level")`)
		args = append(args, level)
	}
	if country != "" {
		conditions = append(conditions, `country ILIKE ?`)
		args = append(args, "%"+country+"%")
	}
	if fundingType != "" {
		conditions = append(conditions, `funding_type ILIKE ?`)
		args = append(args, fundingType)
	}
	if deadlineDays > 0 {
		endDate := time.Now().AddDate(0, 0, deadlineDays).Format("2006-01-02")
		conditions = append(conditions, `deadline IS NOT NULL AND deadline >= CURRENT_DATE AND deadline <= ?`)
		args = append(args, endDate)
	}
	filterClause := strings.Join(conditions, " AND ")
	return filterClause, args
}

// handleListScholarships returns a paginated, filterable list of scholarships.
// GET /api/v1/scholarships?q=&level=&country=&funding_type=&page=1&limit=20
func handleListScholarships(c *fiber.Ctx) error {
	if db == nil {
		return c.Status(503).JSON(fiber.Map{"error": "scholarship database unavailable"})
	}
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

	// ── Sort and deadline params ────────────────────────────────────────
	sortBy := strings.TrimSpace(c.Query("sort_by", "updated_at"))
	sortOrder := strings.TrimSpace(c.Query("sort_order", "DESC"))
	deadlineDays, _ := strconv.Atoi(c.Query("deadline_days", "0"))
	if deadlineDays < 0 {
		deadlineDays = 0
	}

	// Whitelist sort_by to prevent SQL injection
	sortByWhitelist := map[string]bool{"deadline": true, "updated_at": true, "title": true}
	if !sortByWhitelist[sortBy] {
		sortBy = "updated_at"
	}
	sortOrderWhitelist := map[string]bool{"ASC": true, "DESC": true}
	if !sortOrderWhitelist[sortOrder] {
		sortOrder = "DESC"
	}

	// ── Build filters once ──────────────────────────────────────────────
	filterClause, filterArgs := buildScholarshipFilters(q, level, country, fundingType, deadlineDays)

	// ── Count query ─────────────────────────────────────────────────────
	countQuery := `SELECT COUNT(*) FROM scholarships`
	var total int
	if filterClause != "" {
		countQuery += " WHERE " + filterClause
	}
	if err := db.QueryRow(countQuery, filterArgs...).Scan(&total); err != nil {
		log.Printf("ERROR counting scholarships: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to count scholarships"})
	}

	// ── Data query ──────────────────────────────────────────────────────
	baseSelect := `SELECT id, title, provider, description, "level", destination, country,
		coverage,
		cd_tuition, cd_monthly_stipend, cd_currency, cd_travel,
		cd_accommodation, cd_insurance, cd_language_course, cd_other,
		deadline, opening_date, url, source_url,
		requirements, field_of_study, tags, funding_type, tips,
		version, checksum, found_at, updated_at
		FROM scholarships`
	if filterClause != "" {
		baseSelect += " WHERE " + filterClause
	}
	baseSelect += ` ORDER BY ` + sortBy + ` ` + sortOrder + `, title ASC LIMIT ? OFFSET ?`

	dataArgs := append(filterArgs, limit, offset)
	rows, err := db.Query(baseSelect, dataArgs...)
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
	if db == nil {
		return c.Status(503).JSON(fiber.Map{"error": "scholarship database unavailable"})
	}
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

// handleGetScholarshipsBatch returns multiple scholarships by comma-separated IDs.
// GET /api/v1/scholarships/batch?ids=id1,id2,id3
func handleGetScholarshipsBatch(c *fiber.Ctx) error {
	if db == nil {
		return c.Status(503).JSON(fiber.Map{"error": "scholarship database unavailable"})
	}
	idsParam := strings.TrimSpace(c.Query("ids"))
	if idsParam == "" {
		return c.Status(400).JSON(fiber.Map{"error": "ids query parameter is required"})
	}
	parts := strings.Split(idsParam, ",")
	var ids []string
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			ids = append(ids, p)
		}
	}
	if len(ids) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "ids query parameter must contain at least one id"})
	}

	placeholders := make([]string, len(ids))
	args := make([]interface{}, len(ids))
	for i, id := range ids {
		placeholders[i] = "?"
		args[i] = id
	}

	query := `SELECT id, title, provider, description, "level", destination, country,
		coverage,
		cd_tuition, cd_monthly_stipend, cd_currency, cd_travel,
		cd_accommodation, cd_insurance, cd_language_course, cd_other,
		deadline, opening_date, url, source_url,
		requirements, field_of_study, tags, funding_type, tips,
		version, checksum, found_at, updated_at
		FROM scholarships WHERE id IN (` + strings.Join(placeholders, ",") + `)`

	rows, err := db.Query(query, args...)
	if err != nil {
		log.Printf("ERROR querying batch scholarships: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to query scholarships"})
	}
	defer rows.Close()

	scholarships := make([]ScholarshipResponse, 0, len(ids))
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
		"data": scholarships,
	})
}

// ─── Saved / Bookmarked Scholarship Handlers ────────────────────────────────

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
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}
	if body.Status == "" {
		body.Status = "interested"
	}

	// Upsert based on (user_id, scholarship_id) uniqueness
	_, err := database.DB.ExecContext(c.Context(),
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

// handleGetRelatedScholarships returns scholarships related to a given scholarship
// by matching country OR field_of_study.
// GET /api/v1/scholarships/:id/related?limit=6
func handleGetRelatedScholarships(c *fiber.Ctx) error {
	if db == nil {
		return c.Status(503).JSON(fiber.Map{"error": "scholarship database unavailable"})
	}
	id := c.Params("id")

	limit, _ := strconv.Atoi(c.Query("limit", "6"))
	if limit < 1 {
		limit = 6
	}
	if limit > 12 {
		limit = 12
	}

	// Get current scholarship's country and field_of_study
	var countryVal, fosVal interface{}
	err := db.QueryRow("SELECT country, field_of_study FROM scholarships WHERE id = ?", id).Scan(&countryVal, &fosVal)
	if err == sql.ErrNoRows {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	if err != nil {
		log.Printf("ERROR querying current scholarship %s: %v", id, err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to query scholarship"})
	}

	country := scanNullString(countryVal)
	fieldOfStudy := scanStringArray(fosVal)

	if country == "" && len(fieldOfStudy) == 0 {
		return c.JSON(fiber.Map{"data": []ScholarshipResponse{}})
	}

	// Build related scholarships query
	query := `SELECT id, title, provider, description, "level", destination, country,
		coverage,
		cd_tuition, cd_monthly_stipend, cd_currency, cd_travel,
		cd_accommodation, cd_insurance, cd_language_course, cd_other,
		deadline, opening_date, url, source_url,
		requirements, field_of_study, tags, funding_type, tips,
		version, checksum, found_at, updated_at
		FROM scholarships WHERE id != ?`

	var conditions []string
	var args []interface{}
	args = append(args, id)

	if country != "" {
		conditions = append(conditions, "country = ?")
		args = append(args, country)
	}
	if len(fieldOfStudy) > 0 {
		// DuckDB equivalent of ClickHouse's `array_has_any` — see
		// https://duckdb.org/docs/sql/functions/list#listhasanylist-other
		// The marcboeker/go-duckdb driver cannot bind a Go []string to a
		// VARCHAR[] column, so we inline the array as a SQL literal. All
		// values are single-quote-escaped to keep multi-word entries
		// (e.g. "Medical & Health Sciences") intact and injection-safe
		// — field_of_study values originate from the crawled scholarship
		// database, not from untrusted user input.
		literalElems := make([]string, 0, len(fieldOfStudy))
		for _, s := range fieldOfStudy {
			literalElems = append(literalElems, "'"+strings.ReplaceAll(s, "'", "''")+"'")
		}
		arrayLit := "[" + strings.Join(literalElems, ",") + "]"
		conditions = append(conditions, fmt.Sprintf(`list_has_any("field_of_study", %s)`, arrayLit))
	}

	if len(conditions) > 0 {
		query += " AND (" + strings.Join(conditions, " OR ") + ")"
	}

	query += ` ORDER BY updated_at DESC LIMIT ?`
	args = append(args, limit)

	rows, err := db.Query(query, args...)
	if err != nil {
		log.Printf("ERROR querying related scholarships: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to query related scholarships"})
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
			log.Printf("ERROR scanning related scholarship row: %v", err)
			continue
		}
		scholarships = append(scholarships, scanRowToScholarship(vals))
	}

	if err := rows.Err(); err != nil {
		log.Printf("ERROR iterating related scholarship rows: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to read related scholarships"})
	}

	return c.JSON(fiber.Map{
		"data": scholarships,
	})
}

// ─── Stats Handler ───────────────────────────────────────────────────────────

// handleScholarshipStats returns aggregated statistics about all scholarships.
// GET /api/v1/scholarships/stats
func handleScholarshipStats(c *fiber.Ctx) error {
	if db == nil {
		return c.Status(503).JSON(fiber.Map{"error": "scholarship database unavailable"})
	}

	// ── 1. Total count ────────────────────────────────────────────────
	var total int
	if err := db.QueryRow("SELECT COUNT(*) FROM scholarships").Scan(&total); err != nil {
		log.Printf("ERROR counting scholarships: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to count scholarships"})
	}

	// ── 2. By country ────────────────────────────────────────────────
	byCountry := make(map[string]int)
	countryRows, err := db.Query("SELECT country, COUNT(*) as count FROM scholarships GROUP BY country ORDER BY count DESC")
	if err != nil {
		log.Printf("ERROR querying by country: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to query by country"})
	}
	defer countryRows.Close()
	for countryRows.Next() {
		var ctry string
		var cnt int
		if err := countryRows.Scan(&ctry, &cnt); err != nil {
			log.Printf("ERROR scanning by country row: %v", err)
			continue
		}
		byCountry[ctry] = cnt
	}
	if err := countryRows.Err(); err != nil {
		log.Printf("ERROR iterating by country rows: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to read by country"})
	}

	// ── 3. By funding_type ───────────────────────────────────────────
	byFundingType := make(map[string]int)
	fundingRows, err := db.Query("SELECT funding_type, COUNT(*) as count FROM scholarships WHERE funding_type != '' GROUP BY funding_type")
	if err != nil {
		log.Printf("ERROR querying by funding_type: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to query by funding_type"})
	}
	defer fundingRows.Close()
	for fundingRows.Next() {
		var ft string
		var cnt int
		if err := fundingRows.Scan(&ft, &cnt); err != nil {
			log.Printf("ERROR scanning by funding_type row: %v", err)
			continue
		}
		byFundingType[ft] = cnt
	}
	if err := fundingRows.Err(); err != nil {
		log.Printf("ERROR iterating by funding_type rows: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to read by funding_type"})
	}

	// ── 4. Deadlines this month ──────────────────────────────────────
	// Compute the end-of-current-month in Go (DuckDB's `INTERVAL '1 month'`
	// and `DATE_TRUNC('month', ... + INTERVAL '1 month')` syntax trips the
	// binder — see github.com/marcboeker/go-duckdb issue with date math).
	// Using precomputed Go dates keeps the query portable and bulletproof.
	//
	// Note: the `deadline` column in scholarships.duckdb is VARCHAR, not
	// DATE — DuckDB refuses VARCHAR-vs-DATE comparisons without an explicit
	// cast. Worse, the column contains a mix of ISO-8601 dates ("2026-12-15")
	// and free-form text ("Oktober–November 2026 (bervariasi per program)").
	// Plain `CAST(... AS DATE)` errors out on the free-form text. Use
	// `TRY_CAST` which returns NULL on failure so the query still returns
	// a count and the bad rows are silently excluded.
	now := time.Now()
	endOfMonth := time.Date(now.Year(), now.Month()+1, 0, 23, 59, 59, 0, now.Location())
	var deadlinesThisMonth int
	if err := db.QueryRow(
		`SELECT COUNT(*) FROM scholarships
		 WHERE deadline IS NOT NULL
		   AND deadline != ''
		   AND TRY_CAST(deadline AS DATE) IS NOT NULL
		   AND TRY_CAST(deadline AS DATE) >= CURRENT_DATE
		   AND TRY_CAST(deadline AS DATE) <= ?`,
		endOfMonth,
	).Scan(&deadlinesThisMonth); err != nil {
		log.Printf("ERROR counting deadlines this month: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to count deadlines this month"})
	}

	// ── 5. Deadlines next 30 days ────────────────────────────────────
	var deadlinesNext30 int
	if err := db.QueryRow(
		`SELECT COUNT(*) FROM scholarships
		 WHERE deadline IS NOT NULL
		   AND deadline != ''
		   AND TRY_CAST(deadline AS DATE) IS NOT NULL
		   AND TRY_CAST(deadline AS DATE) >= CURRENT_DATE
		   AND TRY_CAST(deadline AS DATE) <= ?`,
		now.AddDate(0, 0, 30),
	).Scan(&deadlinesNext30); err != nil {
		log.Printf("ERROR counting deadlines next 30 days: %v", err)
		return c.Status(500).JSON(fiber.Map{"error": "failed to count deadlines next 30 days"})
	}

	return c.JSON(fiber.Map{
		"total":                  total,
		"by_country":             byCountry,
		"by_funding_type":        byFundingType,
		"deadlines_this_month":   deadlinesThisMonth,
		"deadlines_next_30_days": deadlinesNext30,
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

	rows, err := database.DB.QueryContext(c.Context(), "SELECT scholarship_id FROM saved_scholarships WHERE user_id = ?", uid)
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

	_, err := database.DB.ExecContext(c.Context(),
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
