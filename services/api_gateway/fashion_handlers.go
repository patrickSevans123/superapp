package main

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
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

// supabaseRequest makes an HTTP request to the Supabase REST API.
// If userID is non-empty, it appends user_id=eq.{userID} to the URL query string.
// Returns the HTTP status code, response body, and any error.
func supabaseRequest(method, path string, body io.Reader, userID string) (int, []byte, error) {
	supabaseURL := strings.TrimRight(os.Getenv("SUPABASE_URL"), "/")
	serviceKey := os.Getenv("SUPABASE_SERVICE_KEY")

	fullURL := supabaseURL + path

	// Append user_id filter if userID is provided
	if userID != "" {
		sep := "?"
		if strings.Contains(path, "?") {
			sep = "&"
		}
		fullURL += sep + "user_id=eq." + userID
	}

	req, err := http.NewRequest(method, fullURL, body)
	if err != nil {
		return 0, nil, fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("apikey", serviceKey)
	req.Header.Set("Authorization", "Bearer "+serviceKey)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	req.Header.Set("Prefer", "return=representation")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return 0, nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp.StatusCode, nil, fmt.Errorf("read body: %w", err)
	}

	return resp.StatusCode, respBody, nil
}

// supabaseJSONRequest is a convenience wrapper that marshals the payload to JSON
// and calls supabaseRequest.
func supabaseJSONRequest(method, path string, payload interface{}, userID string) (int, []byte, error) {
	var body io.Reader
	if payload != nil {
		data, err := json.Marshal(payload)
		if err != nil {
			return 0, nil, fmt.Errorf("marshal payload: %w", err)
		}
		body = bytes.NewReader(data)
	}
	return supabaseRequest(method, path, body, userID)
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

	// Build query params for data request
	params := []string{"select=*"}
	params = append(params, "order=created_at.desc")
	params = append(params, "limit="+strconv.Itoa(limit))
	params = append(params, "offset="+strconv.Itoa(offset))

	if category := c.Query("category"); category != "" {
		params = append(params, "category=eq."+category)
	}
	if season := c.Query("season"); season != "" {
		params = append(params, "season_tags=cs.{"+season+"}")
	}
	if search := c.Query("search"); search != "" {
		params = append(params, "name=ilike.*"+search+"*")
	}

	queryString := "?" + strings.Join(params, "&")

	// Fetch data
	status, body, err := supabaseRequest("GET", "/rest/v1/clothing_items"+queryString, nil, userID)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "upstream error", "detail": string(body)})
	}

	// Parse items
	var items []json.RawMessage
	if err := json.Unmarshal(body, &items); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse response"})
	}

	// Get total count (separate request with select=count)
	countParams := []string{"select=count"}
	if category := c.Query("category"); category != "" {
		countParams = append(countParams, "category=eq."+category)
	}
	if season := c.Query("season"); season != "" {
		countParams = append(countParams, "season_tags=cs.{"+season+"}")
	}
	if search := c.Query("search"); search != "" {
		countParams = append(countParams, "name=ilike.*"+search+"*")
	}
	countQuery := "?" + strings.Join(countParams, "&")
	_, countBody, _ := supabaseRequest("GET", "/rest/v1/clothing_items"+countQuery, nil, userID)

	total := len(items)
	if len(countBody) > 0 {
		var countData []map[string]string
		if err := json.Unmarshal(countBody, &countData); err == nil && len(countData) > 0 {
			if c, err := strconv.Atoi(countData[0]["count"]); err == nil {
				total = c
			}
		}
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

	// Parse body into a generic map so we can inject user_id
	var bodyMap map[string]interface{}
	if err := c.BodyParser(&bodyMap); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}
	bodyMap["user_id"] = userID

	status, respBody, err := supabaseJSONRequest("POST", "/rest/v1/clothing_items", bodyMap, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "creation failed", "detail": string(respBody)})
	}

	return c.Status(201).JSON(json.RawMessage(respBody))
}

// HandleGetWardrobeItem returns a single clothing item by ID.
// GET /api/v1/wardrobe/:id
func HandleGetWardrobeItem(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	id := c.Params("id")
	path := "/rest/v1/clothing_items?id=eq." + id + "&select=*"

	status, body, err := supabaseRequest("GET", path, nil, userID)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 || string(body) == "[]" || string(body) == "null" {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}

	// Supabase returns an array; extract the first element
	var items []json.RawMessage
	if err := json.Unmarshal(body, &items); err != nil || len(items) == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}

	var item map[string]interface{}
	if err := json.Unmarshal(items[0], &item); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "parse error"})
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

	// Verify ownership first
	checkPath := "/rest/v1/clothing_items?id=eq." + id + "&select=id"
	checkStatus, checkBody, err := supabaseRequest("GET", checkPath, nil, userID)
	if err != nil || checkStatus >= 400 || string(checkBody) == "[]" {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}

	var bodyMap map[string]interface{}
	if err := c.BodyParser(&bodyMap); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}
	// Remove user_id from update payload to prevent reassignment
	delete(bodyMap, "user_id")
	bodyMap["updated_at"] = time.Now().UTC().Format(time.RFC3339)

	path := "/rest/v1/clothing_items?id=eq." + id
	status, respBody, err := supabaseJSONRequest("PATCH", path, bodyMap, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "update failed", "detail": string(respBody)})
	}

	return c.JSON(json.RawMessage(respBody))
}

// HandleDeleteWardrobeItem deletes a clothing item by ID.
// DELETE /api/v1/wardrobe/:id
func HandleDeleteWardrobeItem(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	id := c.Params("id")

	// Verify ownership first
	checkPath := "/rest/v1/clothing_items?id=eq." + id + "&select=id"
	checkStatus, checkBody, err := supabaseRequest("GET", checkPath, nil, userID)
	if err != nil || checkStatus >= 400 || string(checkBody) == "[]" {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}

	path := "/rest/v1/clothing_items?id=eq." + id
	status, respBody, err := supabaseRequest("DELETE", path, nil, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "delete failed", "detail": string(respBody)})
	}

	return c.JSON(fiber.Map{"success": true})
}

// HandleMarkWorn increments the worn count for a clothing item via Supabase RPC.
// POST /api/v1/wardrobe/:id/worn
func HandleMarkWorn(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	id := c.Params("id")

	// Verify ownership
	checkPath := "/rest/v1/clothing_items?id=eq." + id + "&select=id"
	checkStatus, checkBody, err := supabaseRequest("GET", checkPath, nil, userID)
	if err != nil || checkStatus >= 400 || string(checkBody) == "[]" {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}

	// Call RPC
	payload := map[string]string{"item_id": id}
	status, respBody, err := supabaseJSONRequest("POST", "/rest/v1/rpc/increment_worn_count", payload, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "rpc failed", "detail": string(respBody)})
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
	path := "/rest/v1/clothing_items?select=*"
	status, body, err := supabaseRequest("GET", path, nil, userID)
	if err != nil || status >= 400 {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}

	var items []map[string]interface{}
	if err := json.Unmarshal(body, &items); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "parse error"})
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

		// Cost accumulation
		cost, _ := getFloat(item["cost"])
		totalCost += cost

		// Worn count
		worn, _ := getInt(item["times_worn"])
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

	// Use Supabase resource embedding to join with clothing_items
	path := "/rest/v1/tryon_results?select=*,clothing_items(name,category)&order=created_at.desc"
	status, body, err := supabaseRequest("GET", path, nil, userID)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "upstream error", "detail": string(body)})
	}

	var items []json.RawMessage
	if err := json.Unmarshal(body, &items); err != nil {
		items = []json.RawMessage{}
	}

	// Get count
	countPath := "/rest/v1/tryon_results?select=count"
	_, countBody, _ := supabaseRequest("GET", countPath, nil, userID)
	total := len(items)
	if len(countBody) > 0 {
		var countData []map[string]string
		if err := json.Unmarshal(countBody, &countData); err == nil && len(countData) > 0 {
			if c, err := strconv.Atoi(countData[0]["count"]); err == nil {
				total = c
			}
		}
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
		ClothingItemID  *string `json:"clothing_item_id"`
		PersonImageURL  *string `json:"person_image_url"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}
	if body.PersonImageURL == nil {
		return c.Status(400).JSON(fiber.Map{"error": "person_image_url is required"})
	}

	record := map[string]interface{}{
		"user_id":         userID,
		"person_image_url": *body.PersonImageURL,
		"status":          "queued",
		"fashn_job_id":    "pending-" + randomID(),
	}
	if body.ClothingItemID != nil {
		record["clothing_item_id"] = *body.ClothingItemID
	}

	status, respBody, err := supabaseJSONRequest("POST", "/rest/v1/tryon_results", record, "")
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "creation failed", "detail": string(respBody)})
	}

	return c.Status(201).JSON(json.RawMessage(respBody))
}

// ─── OOTD Handlers ─────────────────────────────────────────────────────────

// HandleGetOOTDLogs returns OOTD logs for the authenticated user.
// GET /api/v1/ootd
func HandleGetOOTDLogs(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "unauthorized"})
	}

	path := "/rest/v1/ootd_logs?select=*&order=suggested_at.desc"
	status, body, err := supabaseRequest("GET", path, nil, userID)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "upstream request failed"})
	}
	if status >= 400 {
		return c.Status(status).JSON(fiber.Map{"error": "upstream error", "detail": string(body)})
	}

	var items []json.RawMessage
	if err := json.Unmarshal(body, &items); err != nil {
		items = []json.RawMessage{}
	}

	// Get count
	countPath := "/rest/v1/ootd_logs?select=count"
	_, countBody, _ := supabaseRequest("GET", countPath, nil, userID)
	total := len(items)
	if len(countBody) > 0 {
		var countData []map[string]string
		if err := json.Unmarshal(countBody, &countData); err == nil && len(countData) > 0 {
			if c, err := strconv.Atoi(countData[0]["count"]); err == nil {
				total = c
			}
		}
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
	case json.Number:
		if f, err := val.Float64(); err == nil {
			return f, true
		}
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
	case json.Number:
		if i, err := strconv.Atoi(val.String()); err == nil {
			return i, true
		}
	case string:
		if i, err := strconv.Atoi(val); err == nil {
			return i, true
		}
	case int:
		return val, true
	}
	return 0, false
}
