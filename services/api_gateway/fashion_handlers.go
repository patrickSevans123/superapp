package main

import (
	"crypto/rand"
	"database/sql"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"

	"github.com/patrickSevans123/superapp-api/database"
)

// ─── Helpers ───────────────────────────────────────────────────────────────

// getUserID extracts the authenticated user ID from Fiber context locals.
func getUserID(c *fiber.Ctx) (string, error) {
	uid, ok := c.Locals("user_id").(string)
	if !ok || uid == "" {
		return "", fmt.Errorf("unauthorized")
	}
	return uid, nil
}

// randomID generates a simple unique identifier using crypto/rand.
func randomID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

// ─── Wardrobe Handlers ─────────────────────────────────────────────────────

// HandleGetWardrobe returns a paginated, filterable list of clothing items.
// GET /api/v1/wardrobe
func HandleGetWardrobe(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

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

	// Build query with filters
	baseQuery := "SELECT * FROM clothing_items WHERE user_id = ?"
	countQuery := "SELECT COUNT(*) FROM clothing_items WHERE user_id = ?"
	var args []interface{} = []interface{}{userID}
	var countArgs []interface{} = []interface{}{userID}

	if category := c.Query("category"); category != "" {
		baseQuery += " AND category = ?"
		countQuery += " AND category = ?"
		args = append(args, category)
		countArgs = append(countArgs, category)
	}
	if season := c.Query("season"); season != "" {
		baseQuery += " AND season_tags LIKE ?"
		countQuery += " AND season_tags LIKE ?"
		args = append(args, "%"+season+"%")
		countArgs = append(countArgs, "%"+season+"%")
	}
	if search := c.Query("search"); search != "" {
		baseQuery += " AND name LIKE ?"
		countQuery += " AND name LIKE ?"
		args = append(args, "%"+search+"%")
		countArgs = append(countArgs, "%"+search+"%")
	}

	// Get total count
	var total int
	if err := database.DB.QueryRowContext(c.Context(), countQuery, countArgs...).Scan(&total); err != nil {
		total = 0
	}

	// Execute data query
	rows, err := database.DB.QueryContext(c.Context(), baseQuery+" ORDER BY created_at DESC LIMIT ? OFFSET ?", append(args, limit, offset)...)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query wardrobe"})
	}
	defer rows.Close()

	items, err := scanRows(rows)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse wardrobe items"})
	}
	if items == nil {
		items = []map[string]interface{}{}
	}

	return c.JSON(fiber.Map{
		"data":  items,
		"total": total,
		"page":  page,
		"limit": limit,
	})
}

// HandleCreateWardrobeItem creates a new clothing item.
// POST /api/v1/wardrobe
func HandleCreateWardrobeItem(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var body struct {
		Name            string   `json:"name"`
		Category        string   `json:"category"`
		Brand           string   `json:"brand"`
		Cost            *float64 `json:"cost"`
		DominantColors  string   `json:"dominant_colors"`
		SeasonTags      string   `json:"season_tags"`
		OriginalImageURL string  `json:"original_image_url"`
		ProcessedImageURL string `json:"processed_image_url"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}
	if body.Name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}

	id := randomID()
	now := time.Now().UTC().Format("20060102T150405Z")

	var cost float64
	if body.Cost != nil {
		cost = *body.Cost
	}

	_, err = database.DB.ExecContext(c.Context(),
		`INSERT INTO clothing_items (id, user_id, name, category, brand, cost, dominant_colors, season_tags, original_image_url, processed_image_url, created_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, userID, body.Name, body.Category, body.Brand, cost, body.DominantColors, body.SeasonTags,
		body.OriginalImageURL, body.ProcessedImageURL, now,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to create item"})
	}

	// Return the created item
	rows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM clothing_items WHERE id = ?", id)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to read created item"})
	}
	defer rows.Close()

	item, err := scanOneRow(rows)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse created item"})
	}

	return c.Status(201).JSON(item)
}

// HandleGetWardrobeItem returns a single clothing item by ID.
// GET /api/v1/wardrobe/:id
func HandleGetWardrobeItem(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	id := c.Params("id")
	rows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM clothing_items WHERE id = ? AND user_id = ?", id, userID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query item"})
	}
	defer rows.Close()

	item, err := scanOneRow(rows)
	if err == sql.ErrNoRows {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse item"})
	}

	return c.JSON(item)
}

// HandleUpdateWardrobeItem updates a clothing item by ID.
// PATCH /api/v1/wardrobe/:id
func HandleUpdateWardrobeItem(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	id := c.Params("id")

	// Verify ownership
	var exists int
	err = database.DB.QueryRowContext(c.Context(), "SELECT 1 FROM clothing_items WHERE id = ? AND user_id = ?", id, userID).Scan(&exists)
	if err == sql.ErrNoRows {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to verify ownership"})
	}

	var body map[string]interface{}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}

	// Remove user_id from update payload to prevent reassignment
	delete(body, "user_id")
	delete(body, "id")
	delete(body, "created_at")

	if len(body) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "no fields to update"})
	}

	body["updated_at"] = time.Now().UTC().Format("20060102T150405Z")

	// Build SET clause with column whitelist
	allowedWardrobeCols := map[string]bool{
		"name": true, "category": true, "brand": true, "cost": true,
		"dominant_colors": true, "season_tags": true,
		"original_image_url": true, "processed_image_url": true,
	}
	var setClauses []string
	var updateArgs []interface{}
	for col, val := range body {
		if !allowedWardrobeCols[col] {
			continue
		}
		setClauses = append(setClauses, col+" = ?")
		updateArgs = append(updateArgs, val)
	}
	if len(setClauses) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "no valid fields to update"})
	}
	updateArgs = append(updateArgs, id, userID)

	_, err = database.DB.ExecContext(c.Context(),
		"UPDATE clothing_items SET "+strings.Join(setClauses, ", ")+" WHERE id = ? AND user_id = ?",
		updateArgs...,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to update item"})
	}

	// Return updated item
	rows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM clothing_items WHERE id = ?", id)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to read updated item"})
	}
	defer rows.Close()

	item, err := scanOneRow(rows)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse updated item"})
	}

	return c.JSON(item)
}

// HandleDeleteWardrobeItem deletes a clothing item by ID.
// DELETE /api/v1/wardrobe/:id
func HandleDeleteWardrobeItem(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	id := c.Params("id")

	// Verify ownership
	var exists int
	err = database.DB.QueryRowContext(c.Context(), "SELECT 1 FROM clothing_items WHERE id = ? AND user_id = ?", id, userID).Scan(&exists)
	if err == sql.ErrNoRows {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to verify ownership"})
	}

	_, err = database.DB.ExecContext(c.Context(), "DELETE FROM clothing_items WHERE id = ? AND user_id = ?", id, userID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to delete item"})
	}

	return c.JSON(fiber.Map{"success": true})
}

// HandleMarkWorn increments the worn count for a clothing item.
// POST /api/v1/wardrobe/:id/worn
func HandleMarkWorn(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	id := c.Params("id")
	now := time.Now().UTC().Format("20060102T150405Z")

	result, err := database.DB.ExecContext(c.Context(),
		"UPDATE clothing_items SET times_worn = times_worn + 1, last_worn_at = ? WHERE id = ? AND user_id = ?",
		now, id, userID,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to mark as worn"})
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}

	return c.JSON(fiber.Map{"success": true})
}

// ─── Insights ──────────────────────────────────────────────────────────────

// cpwItem holds cost-per-wear data for a single clothing item.
type cpwItem struct {
	Name string  `json:"name"`
	Cost float64 `json:"cost"`
	Worn int     `json:"times_worn"`
	CPW  float64 `json:"cpw"`
}

// HandleGetWardrobeInsights returns aggregated statistics for the user's wardrobe.
// GET /api/v1/wardrobe/insights
func HandleGetWardrobeInsights(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	// Fetch all items for the user (no pagination for insights)
	rows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM clothing_items WHERE user_id = ?", userID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query wardrobe"})
	}
	defer rows.Close()

	items, err := scanRows(rows)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse items"})
	}

	totalItems := len(items)
	var totalCost float64
	totalWorn := 0
	byCategory := make(map[string]int)
	var cpwList []cpwItem

	for _, item := range items {
		// Category aggregation
		cat, _ := item["category"].(string)
		if cat == "" {
			cat = "uncategorized"
		}
		byCategory[cat]++

		// Cost accumulation (handle int64 from SQLite)
		cost := 0.0
		switch v := item["cost"].(type) {
		case float64:
			cost = v
		case int64:
			cost = float64(v)
		}
		totalCost += cost

		// Worn count (handle int64 from SQLite)
		worn := 0
		switch v := item["times_worn"].(type) {
		case int64:
			worn = int(v)
		case float64:
			worn = int(v)
		}
		totalWorn += worn

		// CPW calculation (only if cost > 0 and worn > 0)
		if cost > 0 && worn > 0 {
			name, _ := item["name"].(string)
			if name == "" {
				name = "Unnamed"
			}
			cpwList = append(cpwList, cpwItem{
				Name: name,
				Cost: cost,
				Worn: worn,
				CPW:  cost / float64(worn),
			})
		}
	}

	// Sort ascending for lowest CPW
	sort.Slice(cpwList, func(i, j int) bool {
		return cpwList[i].CPW < cpwList[j].CPW
	})

	// Top 5 lowest CPW
	lowestCPW := cpwList
	if len(lowestCPW) > 5 {
		lowestCPW = lowestCPW[:5]
	}

	// Top 5 highest CPW (descending)
	highestCPW := make([]cpwItem, len(cpwList))
	copy(highestCPW, cpwList)
	sort.Slice(highestCPW, func(i, j int) bool {
		return highestCPW[i].CPW > highestCPW[j].CPW
	})
	if len(highestCPW) > 5 {
		highestCPW = highestCPW[:5]
	}

	// Ensure non-nil arrays in JSON response
	if lowestCPW == nil {
		lowestCPW = []cpwItem{}
	}
	if highestCPW == nil {
		highestCPW = []cpwItem{}
	}

	return c.JSON(fiber.Map{
		"total_items": totalItems,
		"total_cost":  totalCost,
		"total_worn":  totalWorn,
		"by_category": byCategory,
		"cpw_data": fiber.Map{
			"lowest_cpw":  lowestCPW,
			"highest_cpw": highestCPW,
		},
	})
}

// ─── Try-On Handlers ───────────────────────────────────────────────────────

// HandleGetTryonHistory returns try-on results for the authenticated user.
// GET /api/v1/tryon/history
func HandleGetTryonHistory(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	// Get count
	var total int
	if err := database.DB.QueryRowContext(c.Context(), "SELECT COUNT(*) FROM tryon_results WHERE user_id = ?", userID).Scan(&total); err != nil {
		total = 0
	}

	rows, err := database.DB.QueryContext(c.Context(),
		`SELECT tr.*, ci.name as clothing_name, ci.category as clothing_category
		 FROM tryon_results tr
		 LEFT JOIN clothing_items ci ON tr.clothing_item_id = ci.id
		 WHERE tr.user_id = ?
		 ORDER BY tr.created_at DESC`, userID)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query try-on history"})
	}
	defer rows.Close()

	items, err := scanRows(rows)
	if err != nil {
		items = []map[string]interface{}{}
	}
	if items == nil {
		items = []map[string]interface{}{}
	}

	return c.JSON(fiber.Map{
		"data":  items,
		"total": total,
	})
}

// HandleCreateTryon creates a new try-on result.
// POST /api/v1/tryon
func HandleCreateTryon(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	var body struct {
		ClothingItemID *string `json:"clothing_item_id"`
		PersonImageURL *string `json:"person_image_url"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}
	if body.PersonImageURL == nil {
		return c.Status(400).JSON(fiber.Map{"error": "person_image_url is required"})
	}

	id := randomID()
	now := time.Now().UTC().Format("20060102T150405Z")

	_, err = database.DB.ExecContext(c.Context(),
		`INSERT INTO tryon_results (id, user_id, clothing_item_id, person_image_url, status, fashn_job_id, created_at)
		 VALUES (?, ?, ?, ?, 'queued', ?, ?)`,
		id, userID, body.ClothingItemID, *body.PersonImageURL, "pending-"+randomID(), now,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to create try-on"})
	}

	// Return created record
	rows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM tryon_results WHERE id = ?", id)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to read created try-on"})
	}
	defer rows.Close()

	item, err := scanOneRow(rows)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse created try-on"})
	}

	return c.Status(201).JSON(item)
}

// ─── OOTD Handlers ─────────────────────────────────────────────────────────

// HandleGetOOTDLogs returns OOTD logs for the authenticated user.
// GET /api/v1/ootd
func HandleGetOOTDLogs(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	// Get count
	var total int
	if err := database.DB.QueryRowContext(c.Context(), "SELECT COUNT(*) FROM ootd_logs WHERE user_id = ?", userID).Scan(&total); err != nil {
		total = 0
	}

	rows, err := database.DB.QueryContext(c.Context(),
		"SELECT * FROM ootd_logs WHERE user_id = ? ORDER BY suggested_at DESC",
		userID,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query OOTD logs"})
	}
	defer rows.Close()

	items, err := scanRows(rows)
	if err != nil {
		items = []map[string]interface{}{}
	}
	if items == nil {
		items = []map[string]interface{}{}
	}

	return c.JSON(fiber.Map{
		"data":  items,
		"total": total,
	})
}

// ─── Numeric Helpers ───────────────────────────────────────────────────────

// getFloat safely extracts a float64 from a map value that may be
// float64, json.Number, or string.
func getFloat(v interface{}) (float64, bool) {
	switch val := v.(type) {
	case float64:
		return val, true
	case int64:
		return float64(val), true
	case string:
		if f, err := strconv.ParseFloat(val, 64); err == nil {
			return f, true
		}
	}
	return 0, false
}

// getInt safely extracts an int from a map value that may be
// float64, json.Number, string, or int.
func getInt(v interface{}) (int, bool) {
	switch val := v.(type) {
	case float64:
		return int(val), true
	case int64:
		return int(val), true
	case string:
		if i, err := strconv.Atoi(val); err == nil {
			return i, true
		}
	case int:
		return val, true
	}
	return 0, false
}
