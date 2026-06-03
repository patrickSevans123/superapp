package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
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

func init() {
	selfTradeBase = os.Getenv("TRADE_API_BASE_URL")
	if selfTradeBase == "" {
		selfTradeBase = "http://host.docker.internal:8081"
	}
	selfTradePythonBase = os.Getenv("TRADE_PYTHON_BASE_URL")
	if selfTradePythonBase == "" {
		selfTradePythonBase = "http://localhost:8766"
	}
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

// handleNews proxies to the self-trade Python API news endpoint.
// GET /api/v1/news?source=bloomberg_english&limit=20
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

	target := fmt.Sprintf("%s/api/news?source=%s&limit=%d", selfTradeBase, url.QueryEscape(source), limit)
	return proxyGet(target, c)
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

// handleNewsStatus proxies to the self-trade news freshness endpoint.
// Returns per-source last_updated, count, age, stale flag.
// GET /api/v1/news/status
func handleNewsStatus(c *fiber.Ctx) error {
	return proxyGet(selfTradeBase+"/api/news/status", c)
}

// handleDailyReports proxies to the self-trade daily reports endpoint.
// Supports filtering by date (YYYY-MM-DD) and limiting the result count.
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
	return proxyGet(target, c)
}

// handleResearchReports proxies to the self-trade research reports list.
// Supports filtering by source and limiting the result count.
// GET /api/v1/research-reports?source=&limit=20
func handleResearchReports(c *fiber.Ctx) error {
	source := c.Query("source")
	limitStr := c.Query("limit", "20")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 20
	}
	if limit > 200 {
		limit = 200
	}

	target := fmt.Sprintf("%s/api/research-reports?source=%s&limit=%d", selfTradeBase, url.QueryEscape(source), limit)
	return proxyGet(target, c)
}

// handleResearchReportByID proxies to the self-trade research report detail.
// GET /api/v1/research-reports/:id
func handleResearchReportByID(c *fiber.Ctx) error {
	id := c.Params("id")
	if id == "" {
		return c.Status(400).JSON(fiber.Map{"error": "id path parameter is required"})
	}
	// Reject obvious path-traversal attempts before forwarding to upstream
	if strings.Contains(id, "/") || strings.Contains(id, "..") {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	target := fmt.Sprintf("%s/api/research-reports/%s", selfTradeBase, url.PathEscape(id))
	return proxyGet(target, c)
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
	target := selfTradePythonBase + "/api/stream/enhanced"

	req, err := http.NewRequest(http.MethodGet, target, nil)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "failed to build upstream request"})
	}
	req.Header.Set("Accept", "text/event-stream")
	req.Header.Set("Cache-Control", "no-cache")
	req.Header.Set("Connection", "keep-alive")

	sseClient := &http.Client{
		Timeout: 0,
		Transport: &http.Transport{
			MaxIdleConns:        10,
			MaxIdleConnsPerHost: 5,
			IdleConnTimeout:     300 * time.Second,
		},
	}

	resp, err := sseClient.Do(req)
	if err != nil {
		log.Printf("WARN enhanced SSE upstream %s unavailable: %v", target, err)
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

// ─── P2: SSE Streaming ────────────────────────────────────────────────

// handleStream proxies the SSE stream from the self-trade Python API.
// GET /api/v1/stream
// This sets up a long-lived SSE connection and forwards events to the client.
func handleStream(c *fiber.Ctx) error {
	target := selfTradePythonBase + "/api/stream"

	// Create upstream request
	req, err := http.NewRequest(http.MethodGet, target, nil)
	if err != nil {
		return c.Status(502).JSON(fiber.Map{"error": "failed to build upstream request"})
	}
	req.Header.Set("Accept", "text/event-stream")
	req.Header.Set("Cache-Control", "no-cache")
	req.Header.Set("Connection", "keep-alive")

	// Use a longer timeout for SSE connections
	sseClient := &http.Client{
		Timeout: 0, // No timeout for SSE
		Transport: &http.Transport{
			MaxIdleConns:        10,
			MaxIdleConnsPerHost: 5,
			IdleConnTimeout:     300 * time.Second,
		},
	}

	resp, err := sseClient.Do(req)
	if err != nil {
		log.Printf("WARN SSE upstream %s unavailable: %v", target, err)
		return c.Status(502).JSON(fiber.Map{
			"error":    fmt.Sprintf("upstream unavailable: %v", err),
			"degraded": true,
		})
	}
	defer resp.Body.Close()

	// Set SSE headers
	c.Set("Content-Type", "text/event-stream")
	c.Set("Cache-Control", "no-cache")
	c.Set("Connection", "keep-alive")
	c.Set("X-Accel-Buffering", "no")

	// Stream the response body
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
