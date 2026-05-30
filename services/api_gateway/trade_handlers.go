package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
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

// ─── Yahoo Finance helpers ─────────────────────────────────────────────────

// yahooQuoteURL builds the Yahoo Finance v8 chart URL for a given symbol.
func yahooQuoteURL(symbol string) string {
	return fmt.Sprintf(
		"https://query1.finance.yahoo.com/v8/finance/chart/%s.JK?interval=1d&range=1d",
		symbol,
	)
}

// fetchQuote calls the Yahoo Finance API for a single symbol and returns
// a populated QuoteResponse.
func fetchQuote(symbol string) (*QuoteResponse, error) {
	url := yahooQuoteURL(symbol)
	log.Printf("Fetching quote for %s", symbol)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("yahoo request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
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

	// Remove trailing .JK from symbol for cleaner output
	cleanSymbol := strings.TrimSuffix(meta.Symbol, ".JK")

	return &QuoteResponse{
		Symbol:        cleanSymbol,
		Name:          cleanSymbol,
		Price:         meta.RegularMarketPrice,
		PreviousClose: meta.PreviousClose,
		Change:        meta.RegularMarketPrice - meta.PreviousClose,
		ChangePct:    ((meta.RegularMarketPrice - meta.PreviousClose) / meta.PreviousClose) * 100,
		High:         meta.RegularMarketDayHi,
		Low:          meta.RegularMarketDayLo,
		Volume:       meta.RegularMarketVol,
		Currency:     meta.Currency,
		Timestamp:    time.Now().Unix(),
	}, nil
}

// ─── Proxy helper ──────────────────────────────────────────────────────────

// proxyGet forwards an HTTP GET request to the given targetURL and writes the
// upstream response body directly to the Fiber client, preserving the status
// code. It returns a suitable Fiber error when the upstream is unreachable.
func proxyGet(targetURL string, c *fiber.Ctx) error {
	log.Printf("Proxying GET %s", targetURL)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Get(targetURL)
	if err != nil {
		log.Printf("ERROR proxying %s: %v", targetURL, err)
		return c.Status(503).JSON(fiber.Map{
			"error": "upstream service unavailable",
		})
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("ERROR reading upstream response for %s: %v", targetURL, err)
		return c.Status(502).JSON(fiber.Map{
			"error": "failed to read upstream response",
		})
	}

	// Forward the status code and body as-is
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
		return c.Status(502).JSON(fiber.Map{"error": fmt.Sprintf("failed to fetch quote: %v", err)})
	}

	return c.JSON(quote)
}

// handleMarketQuotes returns batch quotes for multiple symbols.
// GET /api/v1/market/quotes?symbols=BBCA,BBRI,TLKM
func handleMarketQuotes(c *fiber.Ctx) error {
	raw := strings.TrimSpace(c.Query("symbols"))
	if raw == "" {
		return c.Status(400).JSON(fiber.Map{"error": "symbols query parameter is required"})
	}

	symbols := strings.Split(raw, ",")
	quotes := make([]QuoteResponse, 0, len(symbols))

	for _, sym := range symbols {
		sym = strings.TrimSpace(strings.ToUpper(sym))
		if sym == "" {
			continue
		}

		quote, err := fetchQuote(sym)
		if err != nil {
			log.Printf("WARN skipping %s: %v", sym, err)
			// Include a placeholder so the caller knows which symbols failed
			quotes = append(quotes, QuoteResponse{
				Symbol: sym,
				Name:   sym,
			})
			continue
		}
		quotes = append(quotes, *quote)
	}

	if quotes == nil {
		quotes = []QuoteResponse{}
	}

	return c.JSON(fiber.Map{"quotes": quotes})
}

// handlePlans proxies to the self-trade Python API plans endpoint.
// GET /api/v1/plans?status=ACTIVE|CLOSED
func handlePlans(c *fiber.Ctx) error {
	status := c.Query("status")
	target := "http://localhost:8081/api/plans"
	if status != "" {
		target += "?status=" + status
	}
	return proxyGet(target, c)
}

// handlePlansSummary proxies to the self-trade Python API plans summary.
// GET /api/v1/plans/summary
func handlePlansSummary(c *fiber.Ctx) error {
	return proxyGet("http://localhost:8081/api/plans/summary", c)
}

// handleNews proxies to the self-trade Python API news endpoint.
// GET /api/v1/news?source=bloomberg_english&limit=20
func handleNews(c *fiber.Ctx) error {
	source := c.Query("source")
	limitStr := c.Query("limit", "20")

	// Validate limit is a positive integer
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 20
	}

	target := fmt.Sprintf("http://localhost:8081/api/news?source=%s&limit=%d", source, limit)
	return proxyGet(target, c)
}

// handleEvents proxies to the self-trade Python API events endpoint.
// GET /api/v1/events
func handleEvents(c *fiber.Ctx) error {
	return proxyGet("http://localhost:8081/api/events", c)
}
