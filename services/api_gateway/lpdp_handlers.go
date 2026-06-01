package main

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/gofiber/fiber/v2"
)

// ─── LPDP Data Types ─────────────────────────────────────────────────────────

// LpdpProgram is a single program entry within a university.
type LpdpProgram struct {
	Name            string `json:"name"`
	Level           string `json:"level"`
	BidangStrategis string `json:"bidang_strategis"`
	// Enriched fields populated by handlers
	UniversityName string `json:"university_name,omitempty"`
	Country        string `json:"country,omitempty"`
}

// LpdpUniversity is a university entry from the LPDP dataset.
type LpdpUniversity struct {
	Name     string        `json:"name"`
	Country  string        `json:"country"`
	Programs []LpdpProgram `json:"programs"`
}

// lpdpRoot mirrors the top-level structure of lpdp_unggulan.json.
type lpdpRoot struct {
	Source           string           `json:"source"`
	TotalPrograms    int              `json:"total_programs"`
	TotalUniversities int             `json:"total_universities"`
	Universities     []LpdpUniversity `json:"universities"`
}

// ─── In-memory cache ─────────────────────────────────────────────────────────

type lpdpCache struct {
	mu              sync.RWMutex
	root            *lpdpRoot
	universities    []LpdpUniversity
	programsFlat    []LpdpProgram // All programs flattened with university_name + country
}

var lpdpData = &lpdpCache{}

// ─── Loader ───────────────────────────────────────────────────────────────────

// loadLPDPData reads the LPDP unggulan JSON file into memory.
// It logs a warning if the file is missing but never crashes the server.
func loadLPDPData() {
	dataDir := os.Getenv("STATIC_DATA_DIR")
	if dataDir == "" {
		dataDir = "data"
	}
	path := filepath.Join(dataDir, "lpdp_unggulan.json")

	raw, err := os.ReadFile(path)
	if err != nil {
		log.Printf("WARN: failed to read %s — LPDP endpoints will 503: %v", path, err)
		return
	}

	var root lpdpRoot
	if err := json.Unmarshal(raw, &root); err != nil {
		log.Printf("WARN: failed to parse %s — LPDP endpoints will 503: %v", path, err)
		return
	}

	// Flatten programs with university context
	var flat []LpdpProgram
	for _, u := range root.Universities {
		for _, p := range u.Programs {
			flat = append(flat, LpdpProgram{
				Name:            p.Name,
				Level:           p.Level,
				BidangStrategis: p.BidangStrategis,
				UniversityName:  u.Name,
				Country:         u.Country,
			})
		}
	}

	lpdpData.mu.Lock()
	lpdpData.root = &root
	lpdpData.universities = root.Universities
	lpdpData.programsFlat = flat
	lpdpData.mu.Unlock()

	log.Printf("LPDP data loaded: %d universities, %d programs", len(root.Universities), len(flat))
}

// ─── Handlers ─────────────────────────────────────────────────────────────────

// handleLPDPUniversities returns all LPDP universities with nested programs.
// GET /api/v1/lpdp/universities
func handleLPDPUniversities(c *fiber.Ctx) error {
	lpdpData.mu.RLock()
	defer lpdpData.mu.RUnlock()

	if lpdpData.root == nil {
		return c.Status(503).JSON(fiber.Map{"error": "LPDP data unavailable"})
	}

	// Return universities with programs nested inside each
	return c.JSON(fiber.Map{
		"universities":    lpdpData.universities,
		"total":           len(lpdpData.universities),
	})
}

// handleLPDPUniversityDetail returns a single university by name (case-insensitive).
// GET /api/v1/lpdp/universities/:name
func handleLPDPUniversityDetail(c *fiber.Ctx) error {
	lpdpData.mu.RLock()
	defer lpdpData.mu.RUnlock()

	if lpdpData.root == nil {
		return c.Status(503).JSON(fiber.Map{"error": "LPDP data unavailable"})
	}

	name := c.Params("name")
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "university name is required"})
	}

	nameLower := strings.ToLower(name)
	for _, u := range lpdpData.universities {
		if strings.EqualFold(u.Name, nameLower) || strings.ToLower(u.Name) == nameLower {
			return c.JSON(u)
		}
	}

	return c.Status(404).JSON(fiber.Map{"error": "university not found"})
}

// handleLPDPPrograms filters programs across all universities by bidang (strategic field).
// GET /api/v1/lpdp/programs?bidang=Digitalisasi
func handleLPDPPrograms(c *fiber.Ctx) error {
	lpdpData.mu.RLock()
	defer lpdpData.mu.RUnlock()

	if lpdpData.root == nil {
		return c.Status(503).JSON(fiber.Map{"error": "LPDP data unavailable"})
	}

	bidang := strings.TrimSpace(c.Query("bidang"))
	if bidang == "" {
		// Return all programs
		return c.JSON(fiber.Map{
			"programs": lpdpData.programsFlat,
			"total":    len(lpdpData.programsFlat),
		})
	}

	bidangLower := strings.ToLower(bidang)
	var filtered []LpdpProgram
	for _, p := range lpdpData.programsFlat {
		if strings.Contains(strings.ToLower(p.BidangStrategis), bidangLower) ||
			strings.EqualFold(p.BidangStrategis, bidangLower) {
			filtered = append(filtered, p)
		}
	}

	if filtered == nil {
		filtered = []LpdpProgram{}
	}

	return c.JSON(fiber.Map{
		"programs": filtered,
		"total":    len(filtered),
		"bidang":   bidang,
	})
}

// handleLPDPStats returns aggregated statistics about the LPDP data.
// GET /api/v1/lpdp/stats
func handleLPDPStats(c *fiber.Ctx) error {
	lpdpData.mu.RLock()
	defer lpdpData.mu.RUnlock()

	if lpdpData.root == nil {
		return c.Status(503).JSON(fiber.Map{"error": "LPDP data unavailable"})
	}

	// Count unique countries
	countrySet := make(map[string]struct{})
	for _, u := range lpdpData.universities {
		countrySet[u.Country] = struct{}{}
	}

	// Count programs by bidang
	byBidang := make(map[string]int)
	for _, p := range lpdpData.programsFlat {
		byBidang[p.BidangStrategis]++
	}

	return c.JSON(fiber.Map{
		"total_universities": len(lpdpData.universities),
		"total_programs":     len(lpdpData.programsFlat),
		"total_countries":    len(countrySet),
		"programs_by_bidang": byBidang,
	})
}

// handleLPDPSearch searches programs by checking if the program name or
// university name contains the query string.
// GET /api/v1/lpdp/search?q=computer
func handleLPDPSearch(c *fiber.Ctx) error {
	lpdpData.mu.RLock()
	defer lpdpData.mu.RUnlock()

	if lpdpData.root == nil {
		return c.Status(503).JSON(fiber.Map{"error": "LPDP data unavailable"})
	}

	q := strings.TrimSpace(c.Query("q"))
	if q == "" {
		return c.Status(400).JSON(fiber.Map{"error": "q query parameter is required"})
	}

	qLower := strings.ToLower(q)
	var results []LpdpProgram
	for _, p := range lpdpData.programsFlat {
		if strings.Contains(strings.ToLower(p.Name), qLower) ||
			strings.Contains(strings.ToLower(p.UniversityName), qLower) {
			results = append(results, p)
		}
	}

	if results == nil {
		results = []LpdpProgram{}
	}

	return c.JSON(fiber.Map{
		"results": results,
		"total":   len(results),
		"query":   q,
	})
}
