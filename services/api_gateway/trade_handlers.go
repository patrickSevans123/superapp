package main

import (
	"bufio"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
	_ "github.com/marcboeker/go-duckdb"
)

// ─── Response types ────────────────────────────────────────────────────────

// QuoteResponse is the JSON shape returned by the /market/quote endpoint.
type QuoteResponse struct {
	Symbol        string  `json:"symbol"`
	Name          string  `json:"name"`
	Price         float64 `json:"price"`
	PreviousClose float64 `json:"previousClose"`
	Change        float64 `json:"change"`
	ChangePct     float64 `json:"changePct"`
	High          float64 `json:"high"`
	Low           float64 `json:"low"`
	Volume        int64   `json:"volume"`
	Currency      string  `json:"currency"`
	Timestamp     int64   `json:"timestamp"`
}

// yahooMeta maps the relevant fields from the Yahoo Finance v8 meta object.
type yahooMeta struct {
	Symbol             string  `json:"symbol"`
	RegularMarketPrice float64 `json:"regularMarketPrice"`
	PreviousClose      float64 `json:"previousClose"`
	RegularMarketDayHi float64 `json:"regularMarketDayHigh"`
	RegularMarketDayLo float64 `json:"regularMarketDayLow"`
	RegularMarketVol   int64   `json:"regularMarketVolume"`
	Currency           string  `json:"currency"`
}

// yahooChart is a partial representation of the Yahoo Finance v8 response.
type yahooChart struct {
	Result []struct {
		Meta yahooMeta `json:"meta"`
	} `json:"result"`
}

type yahooResponse struct {
	Chart yahooChart `json:"chart"`
}

// ─── HTTP client (shared, with connection pooling) ────────────────────────

// httpClient is reused across all upstream calls. Creating a new http.Client
// per request is wasteful: each new client gets its own Transport, its own
// connection pool, its own DNS resolver — none of which can be reused. Yahoo
// in particular enforces low per-connection rate limits; pooling helps a lot.
var httpClient = &http.Client{
	Timeout: 10 * time.Second,
	Transport: &http.Transport{
		MaxIdleConns:        100,
		MaxIdleConnsPerHost: 20,
		IdleConnTimeout:     90 * time.Second,
		DisableCompression:  false,
	},
}

const userAgent = "Mozilla/5.0 (compatible; superapp-api/1.0; +https://github.com/patrickSevans123/superapp)"

// ─── Yahoo Finance helpers ─────────────────────────────────────────────────

var yahooSuffixes = []string{".JK", ".SI", ".L", ".AX", ".HK", ".SS", ".T", ".KS", ".O"}

// yahooQuoteURL builds the Yahoo Finance v8 chart URL for a given symbol.
// It only appends .JK (Indonesia Stock Exchange) if the symbol doesn't already
// have a recognized exchange suffix. The symbol is path-escaped so that any
// special characters (e.g. ".", "-", "/") are properly encoded for the URL.
// Callers are expected to uppercase the symbol (see handleMarketQuote).
func yahooQuoteURL(symbol string) string {
	for _, suffix := range yahooSuffixes {
		if strings.HasSuffix(symbol, suffix) {
			return fmt.Sprintf(
				"https://query1.finance.yahoo.com/v8/finance/chart/%s?interval=1d&range=1d",
				url.PathEscape(symbol),
			)
		}
	}
	return fmt.Sprintf(
		"https://query1.finance.yahoo.com/v8/finance/chart/%s.JK?interval=1d&range=1d",
		url.PathEscape(symbol),
	)
}

// fetchQuote calls the Yahoo Finance API for a single symbol and returns
// a populated QuoteResponse.
func fetchQuote(symbol string) (*QuoteResponse, error) {
	url := yahooQuoteURL(symbol)
	log.Printf("Fetching quote for %s", symbol)

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("yahoo request build: %w", err)
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("yahoo request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500 {
		return nil, fmt.Errorf("yahoo upstream %d", resp.StatusCode)
	}
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, fmt.Errorf("yahoo returned status %d: %s", resp.StatusCode, string(body))
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read yahoo response: %w", err)
	}

	var yres yahooResponse
	if err := json.Unmarshal(body, &yres); err != nil {
		return nil, fmt.Errorf("parse yahoo response: %w", err)
	}
	if len(yres.Chart.Result) == 0 {
		return nil, fmt.Errorf("yahoo returned empty result for %s", symbol)
	}

	meta := yres.Chart.Result[0].Meta
	cleanSymbol := strings.TrimSuffix(meta.Symbol, ".JK")
	change := meta.RegularMarketPrice - meta.PreviousClose
	changePct := 0.0
	if meta.PreviousClose != 0 {
		changePct = (change / meta.PreviousClose) * 100
	}

	return &QuoteResponse{
		Symbol:        cleanSymbol,
		Name:          cleanSymbol,
		Price:         meta.RegularMarketPrice,
		PreviousClose: meta.PreviousClose,
		Change:        change,
		ChangePct:     changePct,
		High:          meta.RegularMarketDayHi,
		Low:           meta.RegularMarketDayLo,
		Volume:        meta.RegularMarketVol,
		Currency:      meta.Currency,
		Timestamp:     time.Now().Unix(),
	}, nil
}

// ─── Proxy helper ──────────────────────────────────────────────────────────

// proxyGet forwards an HTTP GET request to targetURL and writes the upstream
// response body to the Fiber client, preserving the status code. On any
// upstream failure (network error, non-2xx), it returns a degraded response
// with `degraded: true` so the Flutter client can clearly show "service
// unavailable" instead of fabricated data.
func proxyGet(targetURL string, c *fiber.Ctx) error {
	log.Printf("Proxying GET %s", targetURL)

	req, err := http.NewRequest(http.MethodGet, targetURL, nil)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{
			"error":     "failed to build upstream request",
			"degraded":  true,
			"upstream":  targetURL,
		})
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		log.Printf("WARN upstream %s unavailable: %v", targetURL, err)
		return c.Status(502).JSON(fiber.Map{
			"error":    fmt.Sprintf("upstream unavailable: %v", err),
			"degraded": true,
			"upstream": targetURL,
		})
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("WARN reading upstream response for %s: %v", targetURL, err)
		return c.Status(502).JSON(fiber.Map{
			"error":    fmt.Sprintf("upstream read error: %v", err),
			"degraded": true,
			"upstream": targetURL,
		})
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		log.Printf("WARN upstream %s returned status %d", targetURL, resp.StatusCode)
		c.Status(resp.StatusCode)
		return c.JSON(fiber.Map{
			"error":    fmt.Sprintf("upstream status %d", resp.StatusCode),
			"degraded": true,
			"upstream": targetURL,
			"raw":      string(body),
		})
	}
	return c.Status(resp.StatusCode).Send(body)
}

// proxyGetRaw is the inspectable variant of proxyGet: it returns the raw
// upstream body, status code, and any error so callers can decide whether
// the response is "good enough" to forward, or whether to fall back to a
// local source. Used by handleNews / handleNewsStatus which need to peek
// at the body to detect empty payloads.
func proxyGetRaw(targetURL string) ([]byte, int, error) {
	req, err := http.NewRequest(http.MethodGet, targetURL, nil)
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, resp.StatusCode, err
	}
	return body, resp.StatusCode, nil
}

// ─── Trade Handlers ────────────────────────────────────────────────────────

// handleMarketQuote returns a real-time stock quote from Yahoo Finance.
// GET /api/v1/market/quote?symbol=BBCA
func handleMarketQuote(c *fiber.Ctx) error {
	symbol := strings.TrimSpace(strings.ToUpper(c.Query("symbol")))
	if symbol == "" {
		return c.Status(400).JSON(fiber.Map{"error": "symbol query parameter is required"})
	}

	quote, err := fetchQuote(symbol)
	if err != nil {
		log.Printf("ERROR fetching quote for %s: %v", symbol, err)
		return c.Status(502).JSON(fiber.Map{
			"error":   fmt.Sprintf("failed to fetch quote: %v", err),
			"symbol":  symbol,
			"degraded": true,
		})
	}

	return c.JSON(quote)
}

// QuoteBatchResult is the per-symbol result returned by handleMarketQuotes.
// Errors are returned in-band (alongside successful quotes) so the client
// can render partial state and retry only the failed symbols.
type QuoteBatchResult struct {
	Symbol string  `json:"symbol"`
	OK     bool    `json:"ok"`
	Quote  *QuoteResponse `json:"quote,omitempty"`
	Error  string  `json:"error,omitempty"`
}

// handleMarketQuotes returns batch quotes for multiple symbols.
// GET /api/v1/market/quotes?symbols=BBCA,BBRI,TLKM
func handleMarketQuotes(c *fiber.Ctx) error {
	raw := strings.TrimSpace(c.Query("symbols"))
	if raw == "" {
		return c.Status(400).JSON(fiber.Map{"error": "symbols query parameter is required"})
	}

	// Cap to 20 to keep latency bounded and respect Yahoo's anti-bot limits.
	const maxBatch = 20
	rawSyms := strings.Split(raw, ",")
	symbols := make([]string, 0, len(rawSyms))
	for _, s := range rawSyms {
		if s = strings.TrimSpace(strings.ToUpper(s)); s != "" {
			symbols = append(symbols, s)
			if len(symbols) >= maxBatch {
				break
			}
		}
	}
	if len(symbols) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "no valid symbols provided"})
	}

	results := make([]QuoteBatchResult, len(symbols))
	sem := make(chan struct{}, 5) // 5 concurrent — keeps us under Yahoo's per-IP throttle
	var wg sync.WaitGroup

	for i, sym := range symbols {
		wg.Add(1)
		sem <- struct{}{}
		go func(idx int, symbol string) {
			defer wg.Done()
			defer func() { <-sem }()

			quote, err := fetchQuote(symbol)
			if err != nil {
				log.Printf("WARN quote failed for %s: %v", symbol, err)
				results[idx] = QuoteBatchResult{Symbol: symbol, OK: false, Error: err.Error()}
				return
			}
			results[idx] = QuoteBatchResult{Symbol: symbol, OK: true, Quote: quote}
		}(i, sym)
	}
	wg.Wait()

	// Preserve the order returned by fetchQuote goroutines via index assignment.
	successCount := 0
	for _, r := range results {
		if r.OK {
			successCount++
		}
	}

	return c.JSON(fiber.Map{
		"data":    results,
		"quotes":  results,
		"count":   len(results),
		"success": successCount,
		"failed":  len(results) - successCount,
	})
}

// selfTradeBase is the base URL for the self-trade Go backend.
// Reads from TRADE_API_BASE_URL env var at startup; falls back to
// host.docker.internal:8081 for Docker, localhost:8081 for local dev.
var selfTradeBase string

// selfTradePythonBase is the base URL for the self-trade Python FastAPI
// which serves intelligence endpoints (signals, regime, briefing, etc).
// Reads from TRADE_PYTHON_BASE_URL env var; falls back to localhost:8766.
var selfTradePythonBase string

// newsParquetDir is the base directory containing per-source news parquet
// subdirectories (e.g. ${newsParquetDir}/bloomberg_english/*.parquet).
// Used as a local fallback when the self-trade Go backend is unreachable.
// Reads from NEWS_PARQUET_DIR env var; falls back to the standard
// self-trade dataset location.
var newsParquetDir string

// newsDB is an in-memory DuckDB connection used for parquet queries only.
// It is intentionally separate from the scholarships DuckDB (which is
// read-only on a .duckdb file) because parquet reading works best with
// an in-memory engine that can glob across files with read_parquet().
var newsDB *sql.DB

// reportsParquetDir is the base directory containing per-source broker
// research parquet files. The self-trade Go backend's /api/reports and
// /api/research-reports endpoints are not always healthy (DuckDB binder
// errors when source has no `date` column, 404s for missing routes), so
// we read these parquet files directly as a graceful fallback. Reads
// from REPORTS_PARQUET_DIR env var.
var reportsParquetDir string

// reportsDB is a SECOND in-memory DuckDB connection used for research
// and daily reports parquet. We can't share the newsDB connection with
// these because each holds its own global DuckDB state, and concurrent
// schema discovery (read_parquet) on the same instance trips DuckDB.
var reportsDB *sql.DB

// validNewsSources restricts the local-parquet fallback to known scraper
// names. Whitelisting prevents a caller from smuggling arbitrary glob
// patterns (e.g. source="../../etc") into the filesystem read.
var validNewsSources = map[string]bool{
	"bloomberg_english": true,
	"bloomberg_technoz": true,
	"reuters":           true,
}

// validResearchSources is the whitelist for /api/v1/research-reports and
// /api/v1/reports local fallbacks. The `rk` source has no local parquet
// (and self-trade does not have a parquet file for it either) — we
// whitelist it anyway so the request returns a graceful empty list
// instead of "unknown source".
var validResearchSources = map[string]bool{
	"samuel":  true,
	"kiwoom":  true,
	"mandiri": true,
	"revalue": true,
	"rk":      true, // known but no local data
}

func init() {
	selfTradeBase = os.Getenv("TRADE_API_BASE_URL")
	if selfTradeBase == "" {
		selfTradeBase = "http://host.docker.internal:8081"
	}
	selfTradePythonBase = os.Getenv("TRADE_PYTHON_BASE_URL")
	if selfTradePythonBase == "" {
		selfTradePythonBase = "http://localhost:8766"
	}
	newsParquetDir = os.Getenv("NEWS_PARQUET_DIR")
	if newsParquetDir == "" {
		newsParquetDir = "/home/evans/Projects/self-trade/datasets/parquet/news"
	}
	reportsParquetDir = os.Getenv("REPORTS_PARQUET_DIR")
	if reportsParquetDir == "" {
		// Default to the standard self-trade dataset layout.
		reportsParquetDir = "/home/evans/Projects/self-trade/datasets/parquet"
	}
}

// ─── News: local parquet fallback ───────────────────────────────────────────

// initNewsDB opens an in-memory DuckDB connection for news parquet queries.
// In-memory is intentional: parquet files are read on every request via
// read_parquet('${dir}/${source}/*.parquet'), so there is no state to persist.
// The single connection (SetMaxOpenConns(1)) prevents DuckDB from complaining
// about concurrent access to the same in-memory instance.
func initNewsDB() error {
	db, err := sql.Open("duckdb", "")
	if err != nil {
		return fmt.Errorf("open in-memory DuckDB: %w", err)
	}
	if err := db.Ping(); err != nil {
		_ = db.Close()
		return fmt.Errorf("ping in-memory DuckDB: %w", err)
	}
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("SET threads TO 2"); err != nil {
		log.Printf("WARN: could not set DuckDB threads=2: %v", err)
	}
	newsDB = db
	return nil
}

// buildNewsSelect returns the per-source SELECT projection that maps the
// heterogeneous parquet schemas (bloomberg_english, bloomberg_technoz,
// reuters) into a uniform shape matching the Flutter NewsItem contract:
//
//	id, title, summary, content, date, processed_at, url, source
//
// The query is built with %s-formatted literals because the path and source
// name are validated against a hardcoded whitelist (validNewsSources),
// so SQL injection from the path component is not possible. The single-
// quote escape is belt-and-braces.
func buildNewsSelect(source, pattern string, limit int) (string, error) {
	escPattern := strings.ReplaceAll(pattern, "'", "''")
	escSource := strings.ReplaceAll(source, "'", "''")

	switch source {
	case "bloomberg_english":
		// Columns: title, publish_date, url, content, processed_at
		return fmt.Sprintf(`
			SELECT
				NULL::VARCHAR                                       AS id,
				title,
				NULL::VARCHAR                                       AS summary,
				content,
				CAST(publish_date AS VARCHAR)                       AS date,
				CAST(processed_at AS TIMESTAMP)                     AS processed_at,
				url,
				'%s'                                                AS source
			FROM read_parquet('%s')
			ORDER BY publish_date DESC
			LIMIT %d
		`, escSource, escPattern, limit), nil

	case "bloomberg_technoz":
		// Columns: id, date, title, url, content
		// Note: this source uses `date` not `publish_date`.
		return fmt.Sprintf(`
			SELECT
				CAST(id AS VARCHAR)                                 AS id,
				title,
				NULL::VARCHAR                                       AS summary,
				content,
				CAST(date AS VARCHAR)                               AS date,
				NULL::TIMESTAMP                                     AS processed_at,
				url,
				'%s'                                                AS source
			FROM read_parquet('%s')
			ORDER BY date DESC
			LIMIT %d
		`, escSource, escPattern, limit), nil

	case "reuters":
		// Columns: title, publish_date, url, description, content
		return fmt.Sprintf(`
			SELECT
				NULL::VARCHAR                                       AS id,
				title,
				description                                         AS summary,
				content,
				CAST(publish_date AS VARCHAR)                       AS date,
				NULL::TIMESTAMP                                     AS processed_at,
				url,
				'%s'                                                AS source
			FROM read_parquet('%s')
			ORDER BY publish_date DESC
			LIMIT %d
		`, escSource, escPattern, limit), nil
	}
	return "", fmt.Errorf("unsupported source: %s", source)
}

// buildNewsDateColumn returns the parquet column that holds the news publish
// timestamp for the given source. Used by the status endpoint to compute
// "latest_mtime" for the freshness check.
func buildNewsDateColumn(source string) string {
	switch source {
	case "bloomberg_technoz":
		return "date"
	default:
		return "publish_date"
	}
}

// fetchLocalNews reads up to `limit` news items from the local parquet
// directory for the given whitelisted source. Returns a slice of plain
// maps so callers can serialise directly to JSON without a Go struct
// round-trip (parquet row shapes vary by source).
func fetchLocalNews(source string, limit int) ([]map[string]any, error) {
	if !validNewsSources[source] {
		return nil, fmt.Errorf("invalid source: %s", source)
	}
	if newsDB == nil {
		return nil, fmt.Errorf("news DB not initialized")
	}
	if newsParquetDir == "" {
		return nil, fmt.Errorf("NEWS_PARQUET_DIR not configured")
	}

	pattern := filepath.Join(newsParquetDir, source, "*.parquet")
	query, err := buildNewsSelect(source, pattern, limit)
	if err != nil {
		return nil, err
	}

	rows, err := newsDB.Query(query)
	if err != nil {
		return nil, fmt.Errorf("duckdb query: %w", err)
	}
	defer rows.Close()

	cols, err := rows.Columns()
	if err != nil {
		return nil, fmt.Errorf("duckdb columns: %w", err)
	}

	var results []map[string]any
	for rows.Next() {
		raw := make([]any, len(cols))
		ptrs := make([]any, len(cols))
		for i := range raw {
			ptrs[i] = &raw[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return nil, fmt.Errorf("scan: %w", err)
		}
		row := make(map[string]any, len(cols))
		for i, col := range cols {
			v := raw[i]
			switch t := v.(type) {
			case time.Time:
				row[col] = t.UTC().Format(time.RFC3339)
			case []byte:
				row[col] = string(t)
			case nil:
				// leave the key out so JSON omits it
			default:
				row[col] = v
			}
		}
		results = append(results, row)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows iter: %w", err)
	}
	return results, nil
}

// fetchLocalNewsStatus returns the per-source freshness of the local
// parquet directories. Mirrors the self-trade response shape so the
// Flutter app can consume the fallback transparently.
func fetchLocalNewsStatus() []map[string]any {
	sources := []string{"bloomberg_english", "bloomberg_technoz", "reuters"}
	results := make([]map[string]any, 0, len(sources))

	for _, source := range sources {
		row := map[string]any{
			"source":  source,
			"healthy": false,
			"stale":   true,
			"count":   0,
		}

		if newsDB == nil {
			row["error"] = "news DB not initialized"
			results = append(results, row)
			continue
		}

		pattern := filepath.Join(newsParquetDir, source, "*.parquet")
		esc := strings.ReplaceAll(pattern, "'", "''")
		dateCol := buildNewsDateColumn(source)

		query := fmt.Sprintf(`
			SELECT COUNT(*) AS cnt, MAX(%s) AS latest
			FROM read_parquet('%s')
		`, dateCol, esc)

		var count int64
		var latest sql.NullString
		if err := newsDB.QueryRow(query).Scan(&count, &latest); err != nil {
			row["error"] = err.Error()
			results = append(results, row)
			continue
		}

		row["count"] = count
		row["healthy"] = count > 0
		row["stale"] = false
		if latest.Valid {
			row["latest_file_mtime"] = latest.String
		}
		results = append(results, row)
	}
	return results
}

// ─── News HTTP handlers (with local fallback) ───────────────────────────────

// handleNews proxies to the self-trade Go backend, but transparently
// falls back to local parquet files when the upstream is unreachable
// or returns an empty payload. This means the Flutter News screen
// keeps working even when the self-trade backend (saham-agentic) is down.
func handleNews(c *fiber.Ctx) error {
	source := c.Query("source")
	limitStr := c.Query("limit", "20")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}

	target := fmt.Sprintf("%s/api/news?source=%s&limit=%d",
		selfTradeBase, url.QueryEscape(source), limit)

	// Attempt upstream first. We only short-circuit on a *successful*
	// response that actually contains news items.
	if body, status, perr := proxyGetRaw(target); perr == nil && status == 200 {
		var probe struct {
			News  []map[string]any `json:"news"`
			Data  []map[string]any `json:"data"`
			Count int              `json:"count"`
		}
		if jerr := json.Unmarshal(body, &probe); jerr == nil {
			if len(probe.News) > 0 || len(probe.Data) > 0 || probe.Count > 0 {
				c.Status(status)
				return c.Send(body)
			}
		}
	}

	// Upstream empty or down — try local parquet fallback.
	if validNewsSources[source] {
		items, ferr := fetchLocalNews(source, limit)
		if ferr == nil && len(items) > 0 {
			log.Printf("INFO: serving news source=%s from local parquet fallback (%d items)",
				source, len(items))
			return c.JSON(fiber.Map{
				"news":   items,
				"count":  len(items),
				"source": "local_parquet_fallback",
			})
		}
		log.Printf("WARN: local parquet fallback for %s failed: %v", source, ferr)
	}

	// Both upstream and fallback failed — return whatever the proxy
	// would have returned (degraded JSON), so the client gets a clear
	// error rather than an empty success response.
	return proxyGet(target, c)
}

// handleNewsStatus returns the per-source news freshness. Falls back to
// the local parquet status when self-trade is unreachable.
func handleNewsStatus(c *fiber.Ctx) error {
	target := selfTradeBase + "/api/news/status"

	if body, status, perr := proxyGetRaw(target); perr == nil && status == 200 {
		var probe struct {
			Sources []map[string]any `json:"sources"`
		}
		if jerr := json.Unmarshal(body, &probe); jerr == nil && len(probe.Sources) > 0 {
			c.Status(status)
			return c.Send(body)
		}
	}

	// Local fallback: report freshness based on parquet mtimes / row counts.
	sources := fetchLocalNewsStatus()
	healthy := 0
	for _, s := range sources {
		if h, _ := s["healthy"].(bool); h {
			healthy++
		}
	}
	return c.JSON(fiber.Map{
		"sources":       sources,
		"total":         len(sources),
		"healthy_count": healthy,
		"stale_count":   len(sources) - healthy,
		"all_ok":        healthy == len(sources),
		"checked_at":    time.Now().UTC().Format(time.RFC3339),
		"source":        "local_parquet_fallback",
	})
}

// ─── Research/Daily reports: local parquet fallback ──────────────────────────
//
// The self-trade Go backend exposes /api/reports and /api/research-reports
// but both can fail in unhelpful ways:
//   - /api/reports hardcodes `ORDER BY date DESC` and crashes with a DuckDB
//     Binder Error when the source parquet has no `date` column (e.g.
//     sekuritas/*.parquet only have `released_at` and `processed_at`).
//   - /api/research-reports is not implemented in the self-trade router
//     at all (returns 404 "Cannot GET /api/research-reports").
//
// To keep the Flutter app functional regardless, we treat upstream 4xx/5xx
// and empty payloads as a soft failure and serve a local parquet
// fallback. The Flutter `ResearchReport` and `DailyReport` shapes are
// matched exactly so the client can render the same widgets.

// initReportsDB opens a SECOND in-memory DuckDB connection for parquet
// queries on broker research and daily reports. We can't share the news
// DuckDB because each connection holds its own session state.
func initReportsDB() error {
	db, err := sql.Open("duckdb", "")
	if err != nil {
		return fmt.Errorf("open in-memory DuckDB (reports): %w", err)
	}
	if err := db.Ping(); err != nil {
		_ = db.Close()
		return fmt.Errorf("ping in-memory DuckDB (reports): %w", err)
	}
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("SET threads TO 2"); err != nil {
		log.Printf("WARN: could not set DuckDB threads=2 (reports): %v", err)
	}
	reportsDB = db
	return nil
}

// researchSourceParquet maps a whitelisted source to its parquet file
// under reportsParquetDir. We try both `sekuritas/<source>_scraped_reports.parquet`
// (the self-trade convention) and `kelas/<source>_reports.parquet` (the
// revalue convention). Returns "" when the source is whitelisted but has
// no known local file (e.g. "rk").
func researchSourceParquet(source string) string {
	candidates := []string{
		filepath.Join(reportsParquetDir, "sekuritas", source+"_scraped_reports.parquet"),
		filepath.Join(reportsParquetDir, "kelas", source+"_reports.parquet"),
	}
	for _, p := range candidates {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}

// buildResearchReportSelect returns the per-source SELECT projection
// for the Flutter ResearchReport shape:
//
//	id, source, title, date, author, tickers, markdown_body, pdf_url
//
// The four data sources we serve have heterogeneous parquet schemas:
//   - samuel:  (no columns known — likely title+content+date)
//   - kiwoom:  seqno, title, released_at, pdf_url, content, processed_at
//   - mandiri: url, title, released_at, content, pdf_url, slug, processed_at
//   - revalue: title, pdf_url, processed_at, content
//
// We pick a common projection: id from seqno/slug, title, date from
// released_at or processed_at, content as markdown_body, pdf_url. The
// query is %s-formatted but the path and source are whitelisted, so
// SQL injection is not possible.
func buildResearchReportSelect(source, parquetPath string, limit int) (string, error) {
	escPath := strings.ReplaceAll(parquetPath, "'", "''")
	escSource := strings.ReplaceAll(source, "'", "''")

	// Choose a date column based on the source. We COALESCE so files
	// that only have one of the timestamps still get a usable date.
	var dateExpr string
	switch source {
	case "kiwoom", "mandiri":
		dateExpr = "COALESCE(CAST(released_at AS VARCHAR), CAST(processed_at AS VARCHAR))"
	case "revalue":
		dateExpr = "CAST(processed_at AS VARCHAR)"
	case "samuel":
		// samuel parquet has no `date` column (only url, title, released_at,
		// content, processed_at). Use released_at as the primary date.
		dateExpr = "COALESCE(CAST(released_at AS VARCHAR), CAST(processed_at AS VARCHAR))"
	default:
		return "", fmt.Errorf("unsupported research source: %s", source)
	}

	// id: prefer seqno (kiwoom), then slug (mandiri), then NULL.
	var idExpr string
	switch source {
	case "kiwoom":
		idExpr = "CAST(seqno AS VARCHAR)"
	case "mandiri":
		idExpr = "COALESCE(slug, '')"
	case "revalue", "samuel":
		// Use row_number as a stable synthetic id since neither has a
		// natural unique column. Filter rows with a non-empty title to
		// avoid empty rows skewing the numbering.
		idExpr = "CAST(row_number() OVER (ORDER BY processed_at DESC) AS VARCHAR)"
	default:
		idExpr = "CAST(row_number() OVER (ORDER BY processed_at DESC) AS VARCHAR)"
	}

	// pdf_url: most sources have it directly. samuel does NOT have a
	// pdf_url column (its schema is url, title, released_at, content,
	// processed_at) — emitting COALESCE(pdf_url, '') against samuel
	// trips DuckDB's binder. Use a literal '' for samuel.
	var pdfExpr string
	switch source {
	case "samuel":
		pdfExpr = "''"
	default:
		pdfExpr = "COALESCE(pdf_url, '')"
	}

	return fmt.Sprintf(`
		SELECT
			%s                                          AS id,
			'%s'                                        AS source,
			COALESCE(title, '')                         AS title,
			%s                                          AS date,
			''                                          AS author,
			CAST([] AS VARCHAR[])                       AS tickers,
			COALESCE(content, '')                       AS markdown_body,
			%s                                          AS pdf_url
		FROM read_parquet('%s')
		ORDER BY processed_at DESC NULLS LAST
		LIMIT %d
	`, idExpr, escSource, dateExpr, pdfExpr, escPath, limit), nil
}

// fetchLocalResearchReports reads up to `limit` research reports for the
// given source from local parquet. Returns ([]map, nil) on success,
// including an empty slice when the source has no data file (e.g. rk).
// The empty-but-OK case is important: it means the request did not fail,
// there's just no data to show — different from a 5xx.
func fetchLocalResearchReports(source string, limit int) ([]map[string]any, error) {
	if !validResearchSources[source] {
		return nil, fmt.Errorf("invalid research source: %s", source)
	}
	if reportsDB == nil {
		return nil, fmt.Errorf("reports DB not initialized")
	}

	parquetPath := researchSourceParquet(source)
	if parquetPath == "" {
		// Source is whitelisted but has no local data — return empty.
		return []map[string]any{}, nil
	}

	query, err := buildResearchReportSelect(source, parquetPath, limit)
	if err != nil {
		return nil, err
	}

	rows, err := reportsDB.Query(query)
	if err != nil {
		return nil, fmt.Errorf("duckdb query: %w", err)
	}
	defer rows.Close()

	cols, err := rows.Columns()
	if err != nil {
		return nil, fmt.Errorf("duckdb columns: %w", err)
	}

	results := make([]map[string]any, 0, 16)
	for rows.Next() {
		raw := make([]any, len(cols))
		ptrs := make([]any, len(cols))
		for i := range raw {
			ptrs[i] = &raw[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			log.Printf("WARN: research report scan failed for %s: %v", source, err)
			continue
		}
		row := make(map[string]any, len(cols))
		for i, c := range cols {
			row[c] = raw[i]
		}
		results = append(results, row)
	}
	return results, rows.Err()
}

// fetchAllLocalResearchReports aggregates research reports from every
// whitelisted source that has a local parquet file, then sorts by date
// DESC and trims to the requested limit. Used when the caller didn't
// filter by source (the Flutter Research Reports home screen).
//
// Per-source queries may fail (e.g. schema drift) — those sources are
// silently skipped so a single bad file doesn't break the whole feed.
func fetchAllLocalResearchReports(limit int) []map[string]any {
	all := make([]map[string]any, 0, 64)
	for src := range validResearchSources {
		items, err := fetchLocalResearchReports(src, limit)
		if err != nil {
			log.Printf("WARN: skipping %s in all-sources research fallback: %v", src, err)
			continue
		}
		all = append(all, items...)
	}
	// Sort by date DESC. The date column is a string so lexical compare
	// gives chronological order for ISO 8601 (YYYY-MM-DD) and "Mon DD,
	// YYYY" lex order — good enough for a fallback feed.
	sort.SliceStable(all, func(i, j int) bool {
		di, _ := all[i]["date"].(string)
		dj, _ := all[j]["date"].(string)
		return di > dj
	})
	if len(all) > limit {
		all = all[:limit]
	}
	return all
}

// fetchLocalResearchReportByID reads a single research report by id.
// id format is "<source>:<seqno>" (e.g. "kiwoom:4815") — mirrors the
// convention self-trade uses (e.g. "samuel:abc123"). Falls back to
// "source:<row_no>" when the source has no native id column.
func fetchLocalResearchReportByID(id string) (map[string]any, error) {
	// Reject obviously bad ids before any disk access.
	if strings.ContainsAny(id, "/\\\"'`;") {
		return nil, fmt.Errorf("invalid id")
	}

	parts := strings.SplitN(id, ":", 2)
	if len(parts) != 2 {
		return nil, fmt.Errorf("invalid id format; expected <source>:<seq>")
	}
	source := parts[0]
	seq := parts[1]
	if !validResearchSources[source] {
		return nil, fmt.Errorf("invalid research source: %s", source)
	}

	parquetPath := researchSourceParquet(source)
	if parquetPath == "" {
		return nil, fmt.Errorf("not found")
	}

	if reportsDB == nil {
		return nil, fmt.Errorf("reports DB not initialized")
	}

	escPath := strings.ReplaceAll(parquetPath, "'", "''")
	escSource := strings.ReplaceAll(source, "'", "''")
	escSeq := strings.ReplaceAll(seq, "'", "''")

	// Build a lookup query depending on which id column the source has.
	var query string
	switch source {
	case "kiwoom":
		query = fmt.Sprintf(`
			SELECT
				CAST(seqno AS VARCHAR) AS id,
				'%s' AS source,
				COALESCE(title, '') AS title,
				COALESCE(CAST(released_at AS VARCHAR), '') AS date,
				'' AS author,
				CAST([] AS VARCHAR[]) AS tickers,
				COALESCE(content, '') AS markdown_body,
				COALESCE(pdf_url, '') AS pdf_url
			FROM read_parquet('%s')
			WHERE seqno = '%s'
			LIMIT 1
		`, escSource, escPath, escSeq)
	case "mandiri":
		query = fmt.Sprintf(`
			SELECT
				COALESCE(slug, '') AS id,
				'%s' AS source,
				COALESCE(title, '') AS title,
				COALESCE(CAST(released_at AS VARCHAR), '') AS date,
				'' AS author,
				CAST([] AS VARCHAR[]) AS tickers,
				COALESCE(content, '') AS markdown_body,
				COALESCE(pdf_url, '') AS pdf_url
			FROM read_parquet('%s')
			WHERE slug = '%s'
			LIMIT 1
		`, escSource, escPath, escSeq)
	case "revalue":
		// revalue has no native id; row_number() over processed_at DESC.
		// We accept numeric seq (1-indexed) and use it as the row offset.
		query = fmt.Sprintf(`
			WITH numbered AS (
				SELECT *, row_number() OVER (ORDER BY processed_at DESC) AS _rn
				FROM read_parquet('%s')
			)
			SELECT
				CAST(_rn AS VARCHAR) AS id,
				'%s' AS source,
				COALESCE(title, '') AS title,
				COALESCE(CAST(processed_at AS VARCHAR), '') AS date,
				'' AS author,
				CAST([] AS VARCHAR[]) AS tickers,
				COALESCE(content, '') AS markdown_body,
				COALESCE(pdf_url, '') AS pdf_url
			FROM numbered
			WHERE CAST(_rn AS VARCHAR) = '%s'
			LIMIT 1
		`, escPath, escSource, escSeq)
	default:
		return nil, fmt.Errorf("not found")
	}

	row := reportsDB.QueryRow(query)
	cols := []string{"id", "source", "title", "date", "author", "tickers", "markdown_body", "pdf_url"}
	raw := make([]any, len(cols))
	ptrs := make([]any, len(cols))
	for i := range raw {
		ptrs[i] = &raw[i]
	}
	if err := row.Scan(ptrs...); err != nil {
		return nil, err
	}
	result := make(map[string]any, len(cols))
	for i, c := range cols {
		result[c] = raw[i]
	}
	return result, nil
}

// fetchLocalReports reads daily reports (one per source, merged). The
// self-trade upstream's /api/reports endpoint hardcodes `ORDER BY date`
// and crashes on the broker parquet files because they have no `date`
// column. We fix that by using `processed_at` consistently.
func fetchLocalReports(dateFilter string, limit int) ([]map[string]any, error) {
	if reportsDB == nil {
		return nil, fmt.Errorf("reports DB not initialized")
	}

	// Per-source queries. Each parquet has a different column layout, so
	// we can't share a single template (DuckDB's binder validates column
	// names against the file's actual schema at parse time, not run time).
	// Schemas (confirmed via DESCRIBE):
	//   samuel:  url, title, released_at, content, processed_at
	//   kiwoom:  seqno, title, released_at, pdf_url, content, processed_at
	//   mandiri: url, title, released_at, content, pdf_url, slug, processed_at
	//   revalue: title, pdf_url, processed_at, content
	type srcFile struct {
		source string
		path   string
	}
	files := []srcFile{}
	for src := range validResearchSources {
		if src == "rk" {
			continue // no local data
		}
		if p := researchSourceParquet(src); p != "" {
			files = append(files, srcFile{src, p})
		}
	}

	all := make([]map[string]any, 0, 64)
	for _, sf := range files {
		escPath := strings.ReplaceAll(sf.path, "'", "''")
		escSrc := strings.ReplaceAll(sf.source, "'", "''")

		var q string
		switch sf.source {
		case "kiwoom":
			// kiwoom has seqno, title, released_at, pdf_url, content, processed_at
			if dateFilter != "" {
				esc := strings.ReplaceAll(dateFilter, "'", "''")
				q = fmt.Sprintf(`
					SELECT
						COALESCE(CAST(seqno AS VARCHAR), '') AS id,
						'%s' AS source,
						COALESCE(title, '') AS title,
						COALESCE(CAST(released_at AS VARCHAR), CAST(processed_at AS VARCHAR), '') AS date,
						COALESCE(content, '') AS preview,
						COALESCE(pdf_url, '') AS url
					FROM read_parquet('%s')
					WHERE CAST(processed_at AS DATE) = DATE '%s'
					ORDER BY processed_at DESC NULLS LAST
					LIMIT %d
				`, escSrc, escPath, esc, limit)
			} else {
				q = fmt.Sprintf(`
					SELECT
						COALESCE(CAST(seqno AS VARCHAR), '') AS id,
						'%s' AS source,
						COALESCE(title, '') AS title,
						COALESCE(CAST(released_at AS VARCHAR), CAST(processed_at AS VARCHAR), '') AS date,
						COALESCE(content, '') AS preview,
						COALESCE(pdf_url, '') AS url
					FROM read_parquet('%s')
					ORDER BY processed_at DESC NULLS LAST
					LIMIT %d
				`, escSrc, escPath, limit)
			}
		case "mandiri":
			// mandiri has url, title, released_at, content, pdf_url, slug, processed_at
			if dateFilter != "" {
				esc := strings.ReplaceAll(dateFilter, "'", "''")
				q = fmt.Sprintf(`
					SELECT
						COALESCE(slug, '') AS id,
						'%s' AS source,
						COALESCE(title, '') AS title,
						COALESCE(CAST(released_at AS VARCHAR), CAST(processed_at AS VARCHAR), '') AS date,
						COALESCE(content, '') AS preview,
						COALESCE(pdf_url, '') AS url
					FROM read_parquet('%s')
					WHERE CAST(processed_at AS DATE) = DATE '%s'
					ORDER BY processed_at DESC NULLS LAST
					LIMIT %d
				`, escSrc, escPath, esc, limit)
			} else {
				q = fmt.Sprintf(`
					SELECT
						COALESCE(slug, '') AS id,
						'%s' AS source,
						COALESCE(title, '') AS title,
						COALESCE(CAST(released_at AS VARCHAR), CAST(processed_at AS VARCHAR), '') AS date,
						COALESCE(content, '') AS preview,
						COALESCE(pdf_url, '') AS url
					FROM read_parquet('%s')
					ORDER BY processed_at DESC NULLS LAST
					LIMIT %d
				`, escSrc, escPath, limit)
			}
		case "revalue":
			// revalue has title, pdf_url, processed_at, content (no id column, no released_at)
			q = fmt.Sprintf(`
				SELECT
					CAST(row_number() OVER (ORDER BY processed_at DESC) AS VARCHAR) AS id,
					'%s' AS source,
					COALESCE(title, '') AS title,
					COALESCE(CAST(processed_at AS VARCHAR), '') AS date,
					COALESCE(content, '') AS preview,
					COALESCE(pdf_url, '') AS url
				FROM read_parquet('%s')
				%s
				ORDER BY processed_at DESC NULLS LAST
				LIMIT %d
			`, escSrc, escPath, dateWhere(dateFilter), limit)
		case "samuel":
			// samuel has url, title, released_at, content, processed_at (no pdf_url, no slug/seqno)
			q = fmt.Sprintf(`
				SELECT
					COALESCE(url, '') AS id,
					'%s' AS source,
					COALESCE(title, '') AS title,
					COALESCE(CAST(released_at AS VARCHAR), CAST(processed_at AS VARCHAR), '') AS date,
					COALESCE(content, '') AS preview,
					'' AS url
				FROM read_parquet('%s')
				%s
				ORDER BY processed_at DESC NULLS LAST
				LIMIT %d
			`, escSrc, escPath, dateWhere(dateFilter), limit)
		default:
			continue
		}

		rows, err := reportsDB.Query(q)
		if err != nil {
			log.Printf("WARN: local reports query failed for %s: %v", sf.source, err)
			continue
		}
		cols, _ := rows.Columns()
		for rows.Next() {
			raw := make([]any, len(cols))
			ptrs := make([]any, len(cols))
			for i := range raw {
				ptrs[i] = &raw[i]
			}
			if err := rows.Scan(ptrs...); err != nil {
				continue
			}
			row := make(map[string]any, len(cols))
			for i, c := range cols {
				row[c] = raw[i]
			}
			all = append(all, row)
		}
		rows.Close()
	}

	// Sort by date DESC.
	sort.SliceStable(all, func(i, j int) bool {
		di, _ := all[i]["date"].(string)
		dj, _ := all[j]["date"].(string)
		return di > dj
	})

	if len(all) > limit {
		all = all[:limit]
	}
	return all, nil
}

// dateWhere returns a WHERE clause fragment for a YYYY-MM-DD filter, or
// the empty string if dateFilter is unset. Used by per-source daily
// reports queries — extracted to avoid six near-identical fmt.Sprintf
// branches.
func dateWhere(dateFilter string) string {
	if dateFilter == "" {
		return ""
	}
	esc := strings.ReplaceAll(dateFilter, "'", "''")
	return fmt.Sprintf("WHERE CAST(processed_at AS DATE) = DATE '%s'", esc)
}

// handlePlans proxies to the self-trade Python API plans endpoint.
// GET /api/v1/plans?status=ACTIVE|CLOSED
func handlePlans(c *fiber.Ctx) error {
	status := c.Query("status")
	target := selfTradeBase + "/api/plans"
	if status != "" {
		target += "?status=" + url.QueryEscape(status)
	}
	return proxyGet(target, c)
}

// handlePlansSummary proxies to the self-trade Python API plans summary.
// GET /api/v1/plans/summary
func handlePlansSummary(c *fiber.Ctx) error {
	return proxyGet(selfTradeBase+"/api/plans/summary", c)
}

// handleEvents proxies to the self-trade Python API events endpoint.
// GET /api/v1/events
func handleEvents(c *fiber.Ctx) error {
	return proxyGet(selfTradeBase+"/api/events", c)
}

// handleScrapersHealth proxies to the self-trade scraper health endpoint.
// Returns per-source data freshness (mtime, age, stale flag) and the HTTP
// status code (200 healthy / 503 stale) so monitoring can use both.
// GET /api/v1/scrapers/health
func handleScrapersHealth(c *fiber.Ctx) error {
	return proxyGet(selfTradeBase+"/api/scrapers/health", c)
}

// handleDailyReports serves daily trading reports. Tries the self-trade
// upstream first; on any failure (404, 5xx, network error, empty
// payload) it falls back to local parquet files. The response shape is
// always {"reports":[...], "count":N, "degraded":bool} so the Flutter
// client can render identically regardless of where the data came from.
// GET /api/v1/reports?date=YYYY-MM-DD&limit=20
func handleDailyReports(c *fiber.Ctx) error {
	date := strings.TrimSpace(c.Query("date"))
	limitStr := c.Query("limit", "20")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}

	target := fmt.Sprintf("%s/api/reports?limit=%d", selfTradeBase, limit)
	if date != "" {
		target += "&date=" + url.QueryEscape(date)
	}

	// Try upstream first. Only short-circuit on 200 + non-empty list.
	if body, status, perr := proxyGetRaw(target); perr == nil && status == 200 {
		var probe struct {
			Reports []map[string]any `json:"reports"`
			Data    []map[string]any `json:"data"`
			Count   int              `json:"count"`
		}
		if jerr := json.Unmarshal(body, &probe); jerr == nil {
			if len(probe.Reports) > 0 || len(probe.Data) > 0 || probe.Count > 0 {
				c.Status(status)
				return c.Send(body)
			}
		}
	}

	// Local parquet fallback.
	items, ferr := fetchLocalReports(date, limit)
	if ferr == nil {
		log.Printf("INFO: serving /api/v1/reports from local parquet fallback (%d items)", len(items))
		return c.JSON(fiber.Map{
			"reports":      items,
			"count":        len(items),
			"degraded":     true,
			"source":       "local_parquet_fallback",
			"date_filter":  date,
		})
	}
	log.Printf("WARN: local reports fallback failed: %v", ferr)

	// Both failed. Return a graceful empty list rather than a 5xx so the
	// Flutter app renders an empty state, not an error widget.
	return c.JSON(fiber.Map{
		"reports":  []map[string]any{},
		"count":    0,
		"degraded": true,
		"source":   "unavailable",
	})
}

// handleResearchReports serves broker research reports. Falls back to
// local parquet when the self-trade upstream is unreachable or returns
// 404 (the upstream does not implement this endpoint). For unknown
// sources, returns a graceful empty list (200 OK) so the Flutter screen
// shows the empty state, not the "Could not load research reports"
// error widget.
// GET /api/v1/research-reports?source=&limit=20
func handleResearchReports(c *fiber.Ctx) error {
	source := strings.TrimSpace(c.Query("source"))
	limitStr := c.Query("limit", "20")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}

	// Validate the source early. Unknown sources would 400 upstream
	// and the Flutter app would render an ugly error. Treat as empty.
	if source != "" && !validResearchSources[source] {
		log.Printf("WARN: research-reports source=%q not in whitelist, returning empty", source)
		return c.JSON(fiber.Map{
			"research_reports": []map[string]any{},
			"count":            0,
			"source":           source,
			"degraded":         true,
		})
	}

	// Try upstream first.
	target := fmt.Sprintf("%s/api/research-reports?source=%s&limit=%d",
		selfTradeBase, url.QueryEscape(source), limit)
	if body, status, perr := proxyGetRaw(target); perr == nil && status == 200 {
		var probe struct {
			Reports []map[string]any `json:"research_reports"`
			Data    []map[string]any `json:"data"`
			Count   int              `json:"count"`
		}
		if jerr := json.Unmarshal(body, &probe); jerr == nil {
			if len(probe.Reports) > 0 || len(probe.Data) > 0 || probe.Count > 0 {
				c.Status(status)
				return c.Send(body)
			}
		}
	}

	// Local parquet fallback. If the caller didn't filter by source,
	// aggregate across every whitelisted source so the Flutter Research
	// Reports home screen can show a unified feed even when the upstream
	// is down.
	var items []map[string]any
	if source == "" {
		items = fetchAllLocalResearchReports(limit)
		log.Printf("INFO: serving /api/v1/research-reports (all sources) from local parquet fallback (%d items)", len(items))
		return c.JSON(fiber.Map{
			"research_reports": items,
			"count":            len(items),
			"degraded":         true,
			"source_filter":    source,
			"source":           "local_parquet_fallback",
		})
	}
	items, ferr := fetchLocalResearchReports(source, limit)
	if ferr == nil {
		log.Printf("INFO: serving /api/v1/research-reports source=%s from local parquet fallback (%d items)",
			source, len(items))
		return c.JSON(fiber.Map{
			"research_reports": items,
			"count":            len(items),
			"degraded":         true,
			"source_filter":    source,
			"source":           "local_parquet_fallback",
		})
	}
	log.Printf("WARN: local research-reports fallback failed: %v", ferr)

	// Both failed. Return empty (200) so client renders empty state.
	return c.JSON(fiber.Map{
		"research_reports": []map[string]any{},
		"count":            0,
		"degraded":         true,
		"source_filter":    source,
		"source":           "unavailable",
	})
}

// handleResearchReportByID serves a single broker research report by id.
// Falls back to local parquet. Returns 404 with a clean body (not 5xx)
// when the id does not exist anywhere, so the Flutter client can
// gracefully render a "not found" UI.
// GET /api/v1/research-reports/:id
func handleResearchReportByID(c *fiber.Ctx) error {
	id := c.Params("id")
	if id == "" {
		return c.Status(400).JSON(fiber.Map{"error": "id path parameter is required"})
	}
	// Reject obvious path-traversal attempts before forwarding to upstream
	if strings.Contains(id, "/") || strings.Contains(id, "..") ||
		strings.ContainsAny(id, "\\\"'`;") {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}

	// Try upstream first.
	target := fmt.Sprintf("%s/api/research-reports/%s", selfTradeBase, url.PathEscape(id))
	if body, status, perr := proxyGetRaw(target); perr == nil && status == 200 {
		var probe struct {
			ID string `json:"id"`
		}
		if jerr := json.Unmarshal(body, &probe); jerr == nil && probe.ID != "" {
			c.Status(status)
			return c.Send(body)
		}
	}

	// Local parquet fallback.
	if item, ferr := fetchLocalResearchReportByID(id); ferr == nil {
		log.Printf("INFO: serving /api/v1/research-reports/%s from local parquet fallback", id)
		return c.JSON(fiber.Map{
			"data":     item,
			"degraded": true,
			"source":   "local_parquet_fallback",
		})
	}

	// Not found anywhere — return 404 with a structured body so the
	// Flutter client can show a clean "not found" message instead of
	// "ReportsApiException(404): ...".
	return c.Status(404).JSON(fiber.Map{
		"error":      "research report not found",
		"id":         id,
		"degraded":   true,
	})
}

// handleDecisionReflection is a graceful stub for
// GET /api/v1/decisions/:id/reflection. The self-trade upstream does not
// implement this route. We return 200 with reflection=null so the Flutter
// Decision Journal screen renders normally (the decision_model.dart
// already supports a null reflection field). If we ever implement LLM
// reflections server-side, replace this stub.
func handleDecisionReflection(c *fiber.Ctx) error {
	id := c.Params("id")
	if id == "" {
		return c.Status(400).JSON(fiber.Map{"error": "id path parameter is required"})
	}
	return c.JSON(fiber.Map{
		"id":         id,
		"reflection": nil,
		"available":  false,
		"source":     "stub",
		"message":    "AI reflections not yet implemented",
	})
}

// handleSignals proxies to the self-trade signals endpoint.
// GET /api/v1/signals/:asset   (asset = idx | us | crypto)
func handleSignals(c *fiber.Ctx) error {
	asset := strings.ToLower(strings.TrimSpace(c.Params("asset")))
	if asset == "" {
		asset = "idx"
	}
	// Validate asset class
	switch asset {
	case "idx", "us", "crypto":
		// valid
	default:
		return c.Status(400).JSON(fiber.Map{"error": "invalid asset; use idx, us, or crypto"})
	}
	target := fmt.Sprintf("%s/api/signals/%s", selfTradePythonBase, asset)
	return proxyGet(target, c)
}

// handleRegime proxies to the self-trade regime detection endpoint.
// GET /api/v1/regime
func handleRegime(c *fiber.Ctx) error {
	return proxyGet(selfTradePythonBase+"/api/regime", c)
}

// handleMorningBriefing proxies to the self-trade morning briefing endpoint.
// GET /api/v1/briefing/today
func handleMorningBriefing(c *fiber.Ctx) error {
	return proxyGet(selfTradePythonBase+"/api/briefing/today", c)
}

// handleSentiment proxies to the self-trade sentiment endpoint.
// GET /api/v1/sentiment
func handleSentiment(c *fiber.Ctx) error {
	return proxyGet(selfTradePythonBase+"/api/sentiment", c)
}

// handleTechnical proxies to the self-trade technical analysis endpoint.
// GET /api/v1/technical/:ticker
func handleTechnical(c *fiber.Ctx) error {
	ticker := strings.ToUpper(strings.TrimSpace(c.Params("ticker")))
	if ticker == "" {
		return c.Status(400).JSON(fiber.Map{"error": "ticker path parameter is required"})
	}
	target := fmt.Sprintf("%s/api/technical/%s", selfTradePythonBase, url.PathEscape(ticker))
	return proxyGet(target, c)
}

// handleDecisions proxies to the self-trade decision memory endpoint.
// GET /api/v1/decisions?ticker=BBCA&limit=20&with_reflections=true
func handleDecisions(c *fiber.Ctx) error {
	ticker := strings.TrimSpace(c.Query("ticker"))
	limitStr := c.Query("limit", "20")
	withReflections := c.Query("with_reflections", "false")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}

	target := fmt.Sprintf("%s/api/decisions?limit=%d&with_reflections=%s", selfTradePythonBase, limit, withReflections)
	if ticker != "" {
		target += "&ticker=" + url.QueryEscape(strings.ToUpper(ticker))
	}
	return proxyGet(target, c)
}

// ─── P2: Strategy Performance ──────────────────────────────────────────

// handleStrategyPerformance proxies to the self-trade strategy performance endpoint.
// GET /api/v1/strategy-performance
func handleStrategyPerformance(c *fiber.Ctx) error {
	return proxyGet(selfTradePythonBase+"/api/strategy-performance", c)
}

// ─── P2: Factor Scores ────────────────────────────────────────────────

// handleFactors proxies to the self-trade factor scores endpoint.
// GET /api/v1/factors
func handleFactors(c *fiber.Ctx) error {
	return proxyGet(selfTradePythonBase+"/api/factors", c)
}

// ─── P3: Portfolio Optimization ────────────────────────────────────────

// handlePortfolioOptimize proxies to the self-trade portfolio optimization endpoint.
// GET /api/v1/portfolio-optimize?tickers=BBCA,BBRI&risk_free_rate=0.06&n_portfolios=5000
func handlePortfolioOptimize(c *fiber.Ctx) error {
	tickers := c.Query("tickers")
	riskFreeRate := c.Query("risk_free_rate", "0.06")
	nPortfolios := c.Query("n_portfolios", "5000")
	targetReturn := c.Query("target_return")

	target := fmt.Sprintf("%s/api/portfolio-optimize?risk_free_rate=%s&n_portfolios=%s",
		selfTradePythonBase, riskFreeRate, nPortfolios)
	if tickers != "" {
		target += "&tickers=" + url.QueryEscape(tickers)
	}
	if targetReturn != "" {
		target += "&target_return=" + url.QueryEscape(targetReturn)
	}
	return proxyGet(target, c)
}

// ─── P3: Enhanced SSE Streaming ────────────────────────────────────────

// handleStreamEnhanced proxies the enhanced SSE stream with real regime/signal events.
// GET /api/v1/stream/enhanced
func handleStreamEnhanced(c *fiber.Ctx) error {
	return proxySSE(selfTradePythonBase+"/api/stream/enhanced", c)
}

// ─── P2: SSE Streaming ────────────────────────────────────────────────

// sseClient is a shared HTTP client for SSE connections (no timeout).
var sseClient = &http.Client{
	Timeout: 0, // No timeout for SSE
	Transport: &http.Transport{
		MaxIdleConns:        10,
		MaxIdleConnsPerHost: 5,
		IdleConnTimeout:     300 * time.Second,
	},
}

// proxySSE sets up a long-lived SSE connection to targetURL and streams
// events to the Fiber client. Shared by handleStream and handleStreamEnhanced.
func proxySSE(targetURL string, c *fiber.Ctx) error {
	req, err := http.NewRequest(http.MethodGet, targetURL, nil)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "failed to build upstream request"})
	}
	req.Header.Set("Accept", "text/event-stream")
	req.Header.Set("Cache-Control", "no-cache")
	req.Header.Set("Connection", "keep-alive")

	resp, err := sseClient.Do(req)
	if err != nil {
		log.Printf("WARN SSE upstream %s unavailable: %v", targetURL, err)
		return c.Status(502).JSON(fiber.Map{
			"error":    fmt.Sprintf("upstream unavailable: %v", err),
			"degraded": true,
		})
	}
	defer resp.Body.Close()

	c.Set("Content-Type", "text/event-stream")
	c.Set("Cache-Control", "no-cache")
	c.Set("Connection", "keep-alive")
	c.Set("X-Accel-Buffering", "no")

	c.Context().SetBodyStreamWriter(func(w *bufio.Writer) {
		buf := make([]byte, 4096)
		for {
			n, readErr := resp.Body.Read(buf)
			if n > 0 {
				w.Write(buf[:n])
				w.Flush()
			}
			if readErr != nil {
				break
			}
		}
	})

	return nil
}

// handleStream proxies the SSE stream from the self-trade Python API.
// GET /api/v1/stream
func handleStream(c *fiber.Ctx) error {
	return proxySSE(selfTradePythonBase+"/api/stream", c)
}

// ─── P4: Factor Library ──────────────────────────────────────────────

// handleFactorLibrary proxies to the self-trade factor library endpoint.
// GET /api/v1/factors/library
func handleFactorLibrary(c *fiber.Ctx) error {
	return proxyGet(selfTradePythonBase+"/api/factors/library", c)
}

// handleFactorCompute triggers factor miner computation.
// POST /api/v1/factors/compute
func handleFactorCompute(c *fiber.Ctx) error {
	target := selfTradePythonBase + "/api/factors/compute"
	req, err := http.NewRequest(http.MethodPost, target, nil)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "failed to build upstream request"})
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": fmt.Sprintf("upstream unavailable: %v", err), "degraded": true})
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return c.Status(resp.StatusCode).Send(body)
}

// ─── P4: Device Registration ─────────────────────────────────────────

// handleDevicesRegister registers a device token for push notifications.
// POST /api/v1/devices/register?user_id=xxx&token=xxx&platform=android
func handleDevicesRegister(c *fiber.Ctx) error {
	userID := c.Query("user_id")
	token := c.Query("token")
	platform := c.Query("platform", "android")

	if userID == "" || token == "" {
		return c.Status(400).JSON(fiber.Map{"error": "user_id and token are required"})
	}

	target := fmt.Sprintf("%s/api/devices/register?user_id=%s&token=%s&platform=%s",
		selfTradePythonBase,
		url.QueryEscape(userID),
		url.QueryEscape(token),
		url.QueryEscape(platform),
	)

	req, err := http.NewRequest(http.MethodPost, target, nil)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "failed to build upstream request"})
	}
	req.Header.Set("User-Agent", userAgent)
	resp, err := httpClient.Do(req)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": fmt.Sprintf("upstream unavailable: %v", err), "degraded": true})
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return c.Status(resp.StatusCode).Send(body)
}

// handleDevicesUnregister removes a device token.
// DELETE /api/v1/devices/unregister?user_id=xxx
func handleDevicesUnregister(c *fiber.Ctx) error {
	userID := c.Query("user_id")
	if userID == "" {
		return c.Status(400).JSON(fiber.Map{"error": "user_id is required"})
	}
	target := fmt.Sprintf("%s/api/devices/unregister?user_id=%s", selfTradePythonBase, url.QueryEscape(userID))
	req, err := http.NewRequest(http.MethodDelete, target, nil)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "failed to build upstream request"})
	}
	req.Header.Set("User-Agent", userAgent)
	resp, err := httpClient.Do(req)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": fmt.Sprintf("upstream unavailable: %v", err), "degraded": true})
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return c.Status(resp.StatusCode).Send(body)
}

// handleDevicesList lists all registered device tokens.
// GET /api/v1/devices
func handleDevicesList(c *fiber.Ctx) error {
	return proxyGet(selfTradePythonBase+"/api/devices", c)
}

// ─── P4: Push Notifications ──────────────────────────────────────────

// handleNotificationsSend sends push notifications via FCM.
// POST /api/v1/notifications/send?title=xxx&body=xxx&user_id=xxx&data=xxx
func handleNotificationsSend(c *fiber.Ctx) error {
	title := c.Query("title")
	body := c.Query("body")
	userID := c.Query("user_id")
	data := c.Query("data")

	if title == "" || body == "" {
		return c.Status(400).JSON(fiber.Map{"error": "title and body are required"})
	}

	target := fmt.Sprintf("%s/api/notifications/send?title=%s&body=%s",
		selfTradePythonBase,
		url.QueryEscape(title),
		url.QueryEscape(body),
	)
	if userID != "" {
		target += "&user_id=" + url.QueryEscape(userID)
	}
	if data != "" {
		target += "&data=" + url.QueryEscape(data)
	}

	req, err := http.NewRequest(http.MethodPost, target, nil)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "failed to build upstream request"})
	}
	req.Header.Set("User-Agent", userAgent)
	resp, err := httpClient.Do(req)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": fmt.Sprintf("upstream unavailable: %v", err), "degraded": true})
	}
	defer resp.Body.Close()
	bodyBytes, _ := io.ReadAll(resp.Body)
	return c.Status(resp.StatusCode).Send(bodyBytes)
}

// ─── P4: Refresh ─────────────────────────────────────────────────────

// handleRefreshFactors manually triggers factor cache refresh.
// POST /api/v1/refresh/factors
func handleRefreshFactors(c *fiber.Ctx) error {
	target := selfTradePythonBase + "/api/refresh/factors"
	req, err := http.NewRequest(http.MethodPost, target, nil)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "failed to build upstream request"})
	}
	req.Header.Set("User-Agent", userAgent)
	resp, err := httpClient.Do(req)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": fmt.Sprintf("upstream unavailable: %v", err), "degraded": true})
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return c.Status(resp.StatusCode).Send(body)
}
