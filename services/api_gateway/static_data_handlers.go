// Static reference data handlers for the superapp API gateway.
//
// Endpoints expose reference datasets that are loaded once at startup from
// JSON files in STATIC_DATA_DIR (default: ./data):
//
//   GET /api/v1/reference/universities          - universities_static.json
//   GET /api/v1/reference/universities/:id
//   GET /api/v1/reference/country-tips          - country_tips.json
//   GET /api/v1/reference/country-tips/:country
//   GET /api/v1/reference/fashion/brands        - fashion_brands.json
//   GET /api/v1/reference/fashion/colors        - color_palette.json
//   GET /api/v1/reference/trade/idx             - idx_universe.json (stocks + watchlists)
//   GET /api/v1/reference/trade/watchlists      - watchlist presets only
//   GET /api/v1/reference/fashion/ootd-rules    - ootd_rules.json
//
// All endpoints are public (no auth) — they're reference data, not user data.

package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
)

// ─── Data shapes ────────────────────────────────────────────────────────────

// University mirrors a single entry in universities_static.json
type University struct {
	ID                   string    `json:"id"`
	Name                 string    `json:"name"`
	Country              string    `json:"country"`
	City                 string    `json:"city"`
	Ranking              int       `json:"ranking"`
	Description          string    `json:"description"`
	Website              string    `json:"website"`
	ApplicationPortal    string    `json:"application_portal"`
	IntakeMonths         []string  `json:"intake_months"`
	LanguageRequirements string    `json:"language_requirements"`
	AvgTuitionS2         string    `json:"avg_tuition_s2"`
	Tags                 []string  `json:"tags"`
	Programs             []Program `json:"programs"`
}

// Program is a nested university program.
type Program struct {
	Name        string `json:"name"`
	Degree      string `json:"degree"`
	Description string `json:"description"`
	Language    string `json:"language"`
	Duration    string `json:"duration"`
	TuitionFee  string `json:"tuition_fee"`
	Department  string `json:"department"`
	Field       string `json:"field"`
}

// CountryTips mirrors country_tips.json structure.
type CountryTips struct {
	Overview        string   `json:"overview"`
	VisaTips        []string `json:"visa_tips"`
	ScholarshipTips []string `json:"scholarship_tips"`
	CostOfLiving    string   `json:"cost_of_living"`
	WorkRules       string   `json:"work_rules"`
	CulturalTips    []string `json:"cultural_tips"`
	LanguageTips    string   `json:"language_tips"`
	HousingTips     []string `json:"housing_tips"`
	GeneralTips     []string `json:"general_tips"`
}

// FashionBrand mirrors fashion_brands.json entries.
type FashionBrand struct {
	Name         string   `json:"name"`
	Category     string   `json:"category"`
	Country      string   `json:"country"`
	PriceRange   string   `json:"price_range"`
	PopularItems []string `json:"popular_items"`
	StyleTags    []string `json:"style_tags"`
}

// ColorEntry mirrors color_palette.json entries.
type ColorEntry struct {
	Name      string                 `json:"name"`
	Hex       string                 `json:"hex"`
	R         int                    `json:"r"`
	G         int                    `json:"g"`
	B         int                    `json:"b"`
	Seasons   []string               `json:"seasons"`
	SkinTones []string               `json:"skin_tones"`
	Harmony   map[string]interface{} `json:"harmony"`
}

// IDXStock mirrors idx_universe.json stock entries.
type IDXStock struct {
	Ticker                string  `json:"ticker"`
	Name                  string  `json:"name"`
	Sector                string  `json:"sector"`
	SubSector             string  `json:"sub_sector"`
	MarketCapIDRTrillions float64 `json:"market_cap_idr_trillions"`
	LotSize               int     `json:"lot_size"`
	Currency              string  `json:"currency"`
}

// WatchlistPreset mirrors idx_universe.json presets.
type WatchlistPreset struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Tickers     []string `json:"tickers"`
}

// ─── In-memory cache ────────────────────────────────────────────────────────

type staticDataCache struct {
	mu                    sync.RWMutex
	loadedAt              time.Time
	universities          map[string]University // by ID
	universitiesByCountry map[string][]University
	countryTips           map[string]CountryTips
	brands                []FashionBrand
	brandsByCategory      map[string][]FashionBrand
	colors                []ColorEntry
	idxStocks             map[string]IDXStock
	watchlists            []WatchlistPreset
	ootdRules             map[string]interface{}
}

var staticCache = &staticDataCache{}

// ─── Loader ─────────────────────────────────────────────────────────────────

// loadStaticData reads all reference JSON files into memory at startup.
// It logs warnings for missing files but never fails the server — endpoints
// return 503 if their specific dataset is unavailable.
func loadStaticData() {
	dataDir := os.Getenv("STATIC_DATA_DIR")
	if dataDir == "" {
		dataDir = "data"
	}
	log.Printf("Loading static reference data from %s", dataDir)

	// Universities
	if path := filepath.Join(dataDir, "universities_static.json"); fileExists(path) {
		uniList, err := readJSONList[University](path)
		if err != nil {
			log.Printf("WARN: failed to load universities: %v", err)
		} else {
			byID := make(map[string]University, len(uniList))
			byCountry := make(map[string][]University, 30)
			for _, u := range uniList {
				byID[u.ID] = u
				byCountry[u.Country] = append(byCountry[u.Country], u)
			}
			staticCache.mu.Lock()
			staticCache.universities = byID
			staticCache.universitiesByCountry = byCountry
			staticCache.mu.Unlock()
			log.Printf("  universities: %d records", len(uniList))
		}
	} else {
		log.Printf("WARN: %s not found — /reference/universities will 503", path)
	}

	// Country tips
	if path := filepath.Join(dataDir, "country_tips.json"); fileExists(path) {
		raw, err := os.ReadFile(path)
		if err != nil {
			log.Printf("WARN: failed to read country_tips: %v", err)
		} else {
			var tips map[string]CountryTips
			if err := json.Unmarshal(raw, &tips); err != nil {
				log.Printf("WARN: failed to parse country_tips: %v", err)
			} else {
				staticCache.mu.Lock()
				staticCache.countryTips = tips
				staticCache.mu.Unlock()
				log.Printf("  country_tips: %d countries", len(tips))
			}
		}
	} else {
		log.Printf("WARN: %s not found — /reference/country-tips will 503", path)
	}

	// Fashion brands
	if path := filepath.Join(dataDir, "fashion_brands.json"); fileExists(path) {
		raw, err := os.ReadFile(path)
		if err != nil {
			log.Printf("WARN: failed to read fashion_brands: %v", err)
		} else {
			var wrapper struct {
				Brands []FashionBrand `json:"brands"`
			}
			if err := json.Unmarshal(raw, &wrapper); err != nil {
				log.Printf("WARN: failed to parse fashion_brands: %v", err)
			} else {
				byCat := make(map[string][]FashionBrand, 10)
				for _, b := range wrapper.Brands {
					if b.Category != "" {
						byCat[b.Category] = append(byCat[b.Category], b)
					}
				}
				staticCache.mu.Lock()
				staticCache.brands = wrapper.Brands
				staticCache.brandsByCategory = byCat
				staticCache.mu.Unlock()
				log.Printf("  fashion_brands: %d records", len(wrapper.Brands))
			}
		}
	} else {
		log.Printf("WARN: %s not found — /reference/fashion/brands will 503", path)
	}

	// Color palette
	if path := filepath.Join(dataDir, "color_palette.json"); fileExists(path) {
		raw, err := os.ReadFile(path)
		if err != nil {
			log.Printf("WARN: failed to read color_palette: %v", err)
		} else {
			var wrapper struct {
				Colors []ColorEntry `json:"colors"`
			}
			if err := json.Unmarshal(raw, &wrapper); err != nil {
				log.Printf("WARN: failed to parse color_palette: %v", err)
			} else {
				staticCache.mu.Lock()
				staticCache.colors = wrapper.Colors
				staticCache.mu.Unlock()
				log.Printf("  color_palette: %d colors", len(wrapper.Colors))
			}
		}
	} else {
		log.Printf("WARN: %s not found — /reference/fashion/colors will 503", path)
	}

	// IDX universe
	if path := filepath.Join(dataDir, "idx_universe.json"); fileExists(path) {
		raw, err := os.ReadFile(path)
		if err != nil {
			log.Printf("WARN: failed to read idx_universe: %v", err)
		} else {
			var wrapper struct {
				Stocks     []IDXStock        `json:"stocks"`
				Watchlists []WatchlistPreset `json:"watchlist_presets"`
			}
			if err := json.Unmarshal(raw, &wrapper); err != nil {
				log.Printf("WARN: failed to parse idx_universe: %v", err)
			} else {
				byTicker := make(map[string]IDXStock, len(wrapper.Stocks))
				for _, s := range wrapper.Stocks {
					byTicker[s.Ticker] = s
				}
				staticCache.mu.Lock()
				staticCache.idxStocks = byTicker
				staticCache.watchlists = wrapper.Watchlists
				staticCache.mu.Unlock()
				log.Printf("  idx_universe: %d stocks, %d watchlists", len(wrapper.Stocks), len(wrapper.Watchlists))
			}
		}
	} else {
		log.Printf("WARN: %s not found — /reference/trade/idx will 503", path)
	}

	// OOTD rules
	if path := filepath.Join(dataDir, "ootd_rules.json"); fileExists(path) {
		raw, err := os.ReadFile(path)
		if err != nil {
			log.Printf("WARN: failed to read ootd_rules: %v", err)
		} else {
			var rules map[string]interface{}
			if err := json.Unmarshal(raw, &rules); err != nil {
				log.Printf("WARN: failed to parse ootd_rules: %v", err)
			} else {
				staticCache.mu.Lock()
				staticCache.ootdRules = rules
				staticCache.mu.Unlock()
				counts := len(rules)
				log.Printf("  ootd_rules: %d top-level sections", counts)
			}
		}
	} else {
		log.Printf("WARN: %s not found — /reference/fashion/ootd-rules will 503", path)
	}

	staticCache.mu.Lock()
	staticCache.loadedAt = time.Now()
	staticCache.mu.Unlock()
}

// ─── Helpers ────────────────────────────────────────────────────────────────

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func readJSONList[T any](path string) ([]T, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var list []T
	if err := json.Unmarshal(raw, &list); err != nil {
		return nil, fmt.Errorf("parse: %w", err)
	}
	return list, nil
}

// ─── Handlers ───────────────────────────────────────────────────────────────

// handleListUniversities returns all universities, optionally filtered by
// country. GET /api/v1/reference/universities[?country=]
func handleListUniversities(c *fiber.Ctx) error {
	staticCache.mu.RLock()
	defer staticCache.mu.RUnlock()
	if staticCache.universities == nil {
		return c.Status(503).JSON(fiber.Map{"error": "universities data unavailable"})
	}
	country := strings.TrimSpace(c.Query("country"))
	if country != "" {
		list := staticCache.universitiesByCountry[country]
		if list == nil {
			list = []University{}
		}
		return c.JSON(fiber.Map{
			"data":    list,
			"total":   len(list),
			"country": country,
		})
	}
	all := make([]University, 0, len(staticCache.universities))
	for _, u := range staticCache.universities {
		all = append(all, u)
	}
	return c.JSON(fiber.Map{
		"data":  all,
		"total": len(all),
	})
}

// handleGetUniversity returns a single university by id.
// GET /api/v1/reference/universities/:id
func handleGetUniversity(c *fiber.Ctx) error {
	staticCache.mu.RLock()
	defer staticCache.mu.RUnlock()
	if staticCache.universities == nil {
		return c.Status(503).JSON(fiber.Map{"error": "universities data unavailable"})
	}
	id := c.Params("id")
	u, ok := staticCache.universities[id]
	if !ok {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(u)
}

// handleListCountryTips returns all country tips.
// GET /api/v1/reference/country-tips
func handleListCountryTips(c *fiber.Ctx) error {
	staticCache.mu.RLock()
	defer staticCache.mu.RUnlock()
	if staticCache.countryTips == nil {
		return c.Status(503).JSON(fiber.Map{"error": "country tips data unavailable"})
	}
	return c.JSON(fiber.Map{
		"data":  staticCache.countryTips,
		"total": len(staticCache.countryTips),
	})
}

// handleGetCountryTips returns tips for a single country.
// GET /api/v1/reference/country-tips/:country
func handleGetCountryTips(c *fiber.Ctx) error {
	staticCache.mu.RLock()
	defer staticCache.mu.RUnlock()
	if staticCache.countryTips == nil {
		return c.Status(503).JSON(fiber.Map{"error": "country tips data unavailable"})
	}
	country := c.Params("country")
	tips, ok := staticCache.countryTips[country]
	if !ok {
		return c.Status(404).JSON(fiber.Map{"error": "country not found", "country": country})
	}
	return c.JSON(tips)
}

// handleListBrands returns fashion brands, optionally filtered by category.
// GET /api/v1/reference/fashion/brands[?category=]
func handleListBrands(c *fiber.Ctx) error {
	staticCache.mu.RLock()
	defer staticCache.mu.RUnlock()
	if staticCache.brands == nil {
		return c.Status(503).JSON(fiber.Map{"error": "fashion brands data unavailable"})
	}
	category := strings.TrimSpace(c.Query("category"))
	if category != "" {
		list := staticCache.brandsByCategory[category]
		if list == nil {
			list = []FashionBrand{}
		}
		return c.JSON(fiber.Map{
			"data":     list,
			"total":    len(list),
			"category": category,
		})
	}
	return c.JSON(fiber.Map{
		"data":  staticCache.brands,
		"total": len(staticCache.brands),
	})
}

// handleListColors returns the color palette, optionally filtered by season.
// GET /api/v1/reference/fashion/colors[?season=]
func handleListColors(c *fiber.Ctx) error {
	staticCache.mu.RLock()
	defer staticCache.mu.RUnlock()
	if staticCache.colors == nil {
		return c.Status(503).JSON(fiber.Map{"error": "color palette data unavailable"})
	}
	season := strings.TrimSpace(strings.ToLower(c.Query("season")))
	if season == "" {
		return c.JSON(fiber.Map{
			"data":  staticCache.colors,
			"total": len(staticCache.colors),
		})
	}
	filtered := make([]ColorEntry, 0)
	for _, c := range staticCache.colors {
		for _, s := range c.Seasons {
			if strings.ToLower(s) == season {
				filtered = append(filtered, c)
				break
			}
		}
	}
	return c.JSON(fiber.Map{
		"data":   filtered,
		"total":  len(filtered),
		"season": season,
	})
}

// handleListIDX returns all IDX stocks + watchlists.
// GET /api/v1/reference/trade/idx[?sector=]
func handleListIDX(c *fiber.Ctx) error {
	staticCache.mu.RLock()
	defer staticCache.mu.RUnlock()
	if staticCache.idxStocks == nil {
		return c.Status(503).JSON(fiber.Map{"error": "IDX universe data unavailable"})
	}
	sector := strings.TrimSpace(c.Query("sector"))
	all := make([]IDXStock, 0, len(staticCache.idxStocks))
	for _, s := range staticCache.idxStocks {
		all = append(all, s)
	}
	if sector != "" {
		filtered := make([]IDXStock, 0, len(all))
		for _, s := range all {
			if strings.EqualFold(s.Sector, sector) {
				filtered = append(filtered, s)
			}
		}
		all = filtered
	}
	return c.JSON(fiber.Map{
		"stocks":     all,
		"watchlists": staticCache.watchlists,
		"total":      len(all),
		"sector":     sector,
	})
}

// handleListWatchlists returns only watchlist presets (subset of IDX data).
// GET /api/v1/reference/trade/watchlists
func handleListWatchlists(c *fiber.Ctx) error {
	staticCache.mu.RLock()
	defer staticCache.mu.RUnlock()
	if staticCache.watchlists == nil {
		return c.Status(503).JSON(fiber.Map{"error": "watchlists data unavailable"})
	}
	return c.JSON(fiber.Map{
		"data":  staticCache.watchlists,
		"total": len(staticCache.watchlists),
	})
}

// handleGetOOTDRules returns the OOTD rule engine data.
// GET /api/v1/reference/fashion/ootd-rules
func handleGetOOTDRules(c *fiber.Ctx) error {
	staticCache.mu.RLock()
	defer staticCache.mu.RUnlock()
	if staticCache.ootdRules == nil {
		return c.Status(503).JSON(fiber.Map{"error": "OOTD rules data unavailable"})
	}
	return c.JSON(staticCache.ootdRules)
}

// handleStaticDataStatus reports which datasets are loaded and when.
// GET /api/v1/reference/status
func handleStaticDataStatus(c *fiber.Ctx) error {
	staticCache.mu.RLock()
	defer staticCache.mu.RUnlock()
	return c.JSON(fiber.Map{
		"loaded_at":      staticCache.loadedAt,
		"universities":   len(staticCache.universities),
		"country_tips":   len(staticCache.countryTips),
		"fashion_brands": len(staticCache.brands),
		"color_palette":  len(staticCache.colors),
		"idx_stocks":     len(staticCache.idxStocks),
		"watchlists":     len(staticCache.watchlists),
		"ootd_rules":     len(staticCache.ootdRules) > 0,
	})
}
