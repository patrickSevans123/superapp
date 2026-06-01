package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/patrickSevans123/superapp-api/database"
)

// ─── Test Main ───────────────────────────────────────────────────────────────

func TestMain(m *testing.M) {
	// Must be set before any auth handler init() runs
	os.Setenv("JWT_SECRET", "test-secret-for-unit-tests-do-not-use-in-production")

	code := m.Run()
	os.Unsetenv("JWT_SECRET")
	os.Exit(code)
}

// ─── Setup ───────────────────────────────────────────────────────────────────

// setupTestDB creates a fresh in-memory SQLite database, runs migrations,
// registers a cleanup callback on t, and returns the DB.
func setupTestDB(t *testing.T) {
	t.Helper()

	if err := database.Init(":memory:"); err != nil {
		t.Fatalf("failed to init test DB: %v", err)
	}
	if err := database.RunMigrations(); err != nil {
		t.Fatalf("failed to run migrations: %v", err)
	}
	t.Cleanup(func() {
		database.DB.Close()
	})
}

// setupTestApp creates a minimal Fiber app with health + auth routes.
// It mirrors the route + middleware setup from main.go but without
// unnecessary handlers (trade, scholarship, fashion, etc.).
func setupTestApp() *fiber.App {
	app := fiber.New(fiber.Config{AppName: "superapp-api-test"})

	// Middleware
	app.Use(recover.New())

	// Health check
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok", "service": "superapp-api"})
	})

	// API v1
	v1 := app.Group("/api/v1")

	// Auth middleware (applied to all v1 routes, skips auth paths)
	v1.Use(authMiddleware)

	// Auth endpoints (no auth required) with rate limiter
	authLimiter := limiter.New(limiter.Config{
		Max:        20,
		Expiration: 1 * time.Minute,
		KeyGenerator: func(c *fiber.Ctx) string {
			return c.IP()
		},
		LimitReached: func(c *fiber.Ctx) error {
			return c.Status(429).JSON(fiber.Map{"error": "too many requests, please try again later"})
		},
	})
	auth := v1.Group("/auth", authLimiter)
	auth.Post("/register", handleRegister)
	auth.Post("/login", handleLogin)
	auth.Post("/refresh", handleRefresh)
	auth.Post("/logout", handleLogout)

	// Settings endpoints
	v1.Get("/settings", handleGetSettings)
	v1.Patch("/settings", handleUpdateSettings)

	// Trade proxy endpoints (plans uses proxyGet for fallback testing)
	v1.Get("/plans", handlePlans)

	// Settings endpoints (used by preferences upsert + 401 tests)
	v1.Get("/profile", handleGetProfile)
	v1.Get("/settings", handleGetSettings)
	v1.Patch("/settings", handleUpdateSettings)

	// Trade proxy endpoint (used by fallback shape tests)
	v1.Get("/plans", handlePlans)

	return app
}

// ─── Health Endpoint ─────────────────────────────────────────────────────────

func TestHealthEndpoint(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	req := httptest.NewRequest("GET", "/health", nil)
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("GET /health: %v", err)
	}
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200, got %d", resp.StatusCode)
	}

	var body map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("expected status=ok, got %q", body["status"])
	}
	if body["service"] != "superapp-api" {
		t.Errorf("expected service=superapp-api, got %q", body["service"])
	}
}

// ─── Auth Register ───────────────────────────────────────────────────────────

func TestAuthRegister_Success(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	payload := `{"email":"test@example.com","password":"secret123","display_name":"Test User"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("POST /api/v1/auth/register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("expected 201, got %d", resp.StatusCode)
	}

	var body map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	user, ok := body["user"].(map[string]interface{})
	if !ok {
		t.Fatal("response missing 'user' object")
	}
	if user["email"] != "test@example.com" {
		t.Errorf("expected email test@example.com, got %v", user["email"])
	}
	if user["display_name"] != "Test User" {
		t.Errorf("expected display_name Test User, got %v", user["display_name"])
	}
	if _, ok := body["token"]; !ok {
		t.Error("response missing 'token'")
	}
}

func TestAuthRegister_DuplicateEmail(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// Register once
	payload := `{"email":"dup@example.com","password":"secret123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("first register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("expected 201, got %d", resp.StatusCode)
	}

	// Register again with the same email
	req2 := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(payload))
	req2.Header.Set("Content-Type", "application/json")
	resp2, err := app.Test(req2, 1000)
	if err != nil {
		t.Fatalf("second register: %v", err)
	}
	if resp2.StatusCode != fiber.StatusConflict {
		t.Fatalf("expected 409 for duplicate email, got %d", resp2.StatusCode)
	}
}

func TestAuthRegister_Validation(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	tests := []struct {
		name    string
		payload string
		want    int
	}{
		{"missing email", `{"password":"secret123"}`, 400},
		{"short password", `{"email":"a@b.com","password":"123"}`, 400},
		{"invalid json", `not-json`, 400},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(tt.payload))
			req.Header.Set("Content-Type", "application/json")
			resp, err := app.Test(req, 1000)
			if err != nil {
				t.Fatalf("request: %v", err)
			}
			if resp.StatusCode != tt.want {
				t.Errorf("expected %d, got %d", tt.want, resp.StatusCode)
			}
		})
	}
}

// ─── Auth Login ──────────────────────────────────────────────────────────────

func TestAuthLogin_Success(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// Register a user first
	regPayload := `{"email":"login@example.com","password":"secret123","display_name":"Login User"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(regPayload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register: expected 201, got %d", resp.StatusCode)
	}

	// Now login
	loginPayload := `{"email":"login@example.com","password":"secret123"}`
	req2 := httptest.NewRequest("POST", "/api/v1/auth/login", strings.NewReader(loginPayload))
	req2.Header.Set("Content-Type", "application/json")
	resp2, err := app.Test(req2, 1000)
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	if resp2.StatusCode != fiber.StatusOK {
		t.Fatalf("login: expected 200, got %d", resp2.StatusCode)
	}

	var body map[string]interface{}
	if err := json.NewDecoder(resp2.Body).Decode(&body); err != nil {
		t.Fatalf("decode login response: %v", err)
	}
	user, ok := body["user"].(map[string]interface{})
	if !ok {
		t.Fatal("login response missing 'user' object")
	}
	if user["email"] != "login@example.com" {
		t.Errorf("expected email login@example.com, got %v", user["email"])
	}
	if _, ok := body["token"]; !ok {
		t.Error("login response missing 'token'")
	}
}

func TestAuthLogin_WrongPassword(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// Register
	regPayload := `{"email":"wrongpw@example.com","password":"secret123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(regPayload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register: expected 201, got %d", resp.StatusCode)
	}

	// Login with wrong password
	loginPayload := `{"email":"wrongpw@example.com","password":"wrongpassword"}`
	req2 := httptest.NewRequest("POST", "/api/v1/auth/login", strings.NewReader(loginPayload))
	req2.Header.Set("Content-Type", "application/json")
	resp2, err := app.Test(req2, 1000)
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	if resp2.StatusCode != fiber.StatusUnauthorized {
		t.Fatalf("login: expected 401, got %d", resp2.StatusCode)
	}
}

// ─── Auth Middleware ─────────────────────────────────────────────────────────

func TestAuthMiddleware_BlocksWithoutToken(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	req := httptest.NewRequest("GET", "/api/v1/profile", nil)
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("GET /api/v1/profile: %v", err)
	}
	if resp.StatusCode != fiber.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", resp.StatusCode)
	}
}

func TestAuthMiddleware_SkipsAuthRoutes(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// Register endpoint should work without auth header
	payload := `{"email":"skipauth@example.com","password":"secret123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register without token: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("expected 201, got %d", resp.StatusCode)
	}
}

func TestAuthMiddleware_AllowsValidToken(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// Register
	regPayload := `{"email":"authtest@example.com","password":"secret123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(regPayload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register: expected 201, got %d", resp.StatusCode)
	}

	var regResult map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&regResult); err != nil {
		t.Fatalf("decode register response: %v", err)
	}
	token, ok := regResult["token"].(string)
	if !ok || token == "" {
		t.Fatal("register did not return a token")
	}

	// Access protected endpoint with the valid token
	req2 := httptest.NewRequest("GET", "/api/v1/profile", nil)
	req2.Header.Set("Authorization", "Bearer "+token)
	resp2, err := app.Test(req2, 1000)
	if err != nil {
		t.Fatalf("GET /api/v1/profile with token: %v", err)
	}
	// The handler handleGetProfile is defined elsewhere; we just need to
	// verify the middleware passes (status is not 401).
	if resp2.StatusCode == fiber.StatusUnauthorized {
		t.Fatal("expected middleware to allow valid token, got 401")
	}
}

// ─── Preferences Upsert Idempotence ──────────────────────────────────────

func TestPreferencesUpdate_Idempotent(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// Register a user
	regPayload := `{"email":"prefs-idempotent@example.com","password":"secret123","display_name":"Prefs User"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(regPayload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register: expected 201, got %d", resp.StatusCode)
	}

	var regResult map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&regResult); err != nil {
		t.Fatalf("decode register response: %v", err)
	}
	token, ok := regResult["token"].(string)
	if !ok || token == "" {
		t.Fatal("register did not return a token")
	}

	// 1. First PATCH settings with preferences (insert)
	patchPayload := `{"preferences":{"tp_hit":0,"price_alert":0}}`
	req2 := httptest.NewRequest("PATCH", "/api/v1/settings", strings.NewReader(patchPayload))
	req2.Header.Set("Content-Type", "application/json")
	req2.Header.Set("Authorization", "Bearer "+token)
	resp2, err := app.Test(req2, 1000)
	if err != nil {
		t.Fatalf("first PATCH settings: %v", err)
	}
	if resp2.StatusCode != fiber.StatusOK {
		t.Fatalf("first PATCH settings: expected 200, got %d", resp2.StatusCode)
	}

	var settingsResp map[string]interface{}
	if err := json.NewDecoder(resp2.Body).Decode(&settingsResp); err != nil {
		t.Fatalf("decode first PATCH response: %v", err)
	}
	prefs, ok := settingsResp["preferences"].(map[string]interface{})
	if !ok {
		t.Fatal("first PATCH response missing 'preferences'")
	}
	if prefs["tp_hit"] != float64(0) {
		t.Errorf("expected tp_hit=0, got %v", prefs["tp_hit"])
	}

	// 2. Second PATCH settings with same values (idempotent — should not error)
	req3 := httptest.NewRequest("PATCH", "/api/v1/settings", strings.NewReader(patchPayload))
	req3.Header.Set("Content-Type", "application/json")
	req3.Header.Set("Authorization", "Bearer "+token)
	resp3, err := app.Test(req3, 1000)
	if err != nil {
		t.Fatalf("second PATCH settings: %v", err)
	}
	if resp3.StatusCode != fiber.StatusOK {
		t.Fatalf("second PATCH settings: expected 200, got %d", resp3.StatusCode)
	}

	// 3. GET settings to verify prefs are unchanged after the second upsert
	req4 := httptest.NewRequest("GET", "/api/v1/settings", nil)
	req4.Header.Set("Authorization", "Bearer "+token)
	resp4, err := app.Test(req4, 1000)
	if err != nil {
		t.Fatalf("GET settings: %v", err)
	}
	if resp4.StatusCode != fiber.StatusOK {
		t.Fatalf("GET settings: expected 200, got %d", resp4.StatusCode)
	}

	var getResp map[string]interface{}
	if err := json.NewDecoder(resp4.Body).Decode(&getResp); err != nil {
		t.Fatalf("decode GET response: %v", err)
	}
	getPrefs, ok := getResp["preferences"].(map[string]interface{})
	if !ok {
		t.Fatal("GET response missing 'preferences'")
	}
	if getPrefs["tp_hit"] != float64(0) {
		t.Errorf("after idempotent upsert: expected tp_hit=0, got %v", getPrefs["tp_hit"])
	}
	if getPrefs["price_alert"] != float64(0) {
		t.Errorf("after idempotent upsert: expected price_alert=0, got %v", getPrefs["price_alert"])
	}

	// 4. PATCH settings with a different value (update existing row)
	patchPayload2 := `{"preferences":{"tp_hit":1}}`
	req5 := httptest.NewRequest("PATCH", "/api/v1/settings", strings.NewReader(patchPayload2))
	req5.Header.Set("Content-Type", "application/json")
	req5.Header.Set("Authorization", "Bearer "+token)
	resp5, err := app.Test(req5, 1000)
	if err != nil {
		t.Fatalf("third PATCH settings: %v", err)
	}
	if resp5.StatusCode != fiber.StatusOK {
		t.Fatalf("third PATCH settings: expected 200, got %d", resp5.StatusCode)
	}

	// 5. GET settings to verify the update took effect
	req6 := httptest.NewRequest("GET", "/api/v1/settings", nil)
	req6.Header.Set("Authorization", "Bearer "+token)
	resp6, err := app.Test(req6, 1000)
	if err != nil {
		t.Fatalf("GET settings after update: %v", err)
	}
	if resp6.StatusCode != fiber.StatusOK {
		t.Fatalf("GET settings after update: expected 200, got %d", resp6.StatusCode)
	}

	var getResp2 map[string]interface{}
	if err := json.NewDecoder(resp6.Body).Decode(&getResp2); err != nil {
		t.Fatalf("decode GET response after update: %v", err)
	}
	getPrefs2, ok := getResp2["preferences"].(map[string]interface{})
	if !ok {
		t.Fatal("GET response after update missing 'preferences'")
	}
	if getPrefs2["tp_hit"] != float64(1) {
		t.Errorf("after update: expected tp_hit=1, got %v", getPrefs2["tp_hit"])
	}
	// price_alert should still be 0 — it was not included in the second PATCH
	if getPrefs2["price_alert"] != float64(0) {
		t.Errorf("after update: expected price_alert=0 (unchanged), got %v", getPrefs2["price_alert"])
	}
}

// ─── Auth-Required Handlers Return 401 (not 400) ─────────────────────────

func TestAuthRequired_SettingsAndPlans_Returns401(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	tests := []struct {
		name   string
		method string
		path   string
		body   string
	}{
		{"GET /api/v1/settings", "GET", "/api/v1/settings", ""},
		{"PATCH /api/v1/settings", "PATCH", "/api/v1/settings", `{"display_name":"x"}`},
		{"GET /api/v1/plans", "GET", "/api/v1/plans", ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var req *http.Request
			if tt.body != "" {
				req = httptest.NewRequest(tt.method, tt.path, strings.NewReader(tt.body))
				req.Header.Set("Content-Type", "application/json")
			} else {
				req = httptest.NewRequest(tt.method, tt.path, nil)
			}
			resp, err := app.Test(req, 1000)
			if err != nil {
				t.Fatalf("request: %v", err)
			}
			if resp.StatusCode != fiber.StatusUnauthorized {
				t.Fatalf("expected 401, got %d", resp.StatusCode)
			}
			// Verify the body is a JSON error (not HTML, not empty)
			var body map[string]interface{}
			if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
				t.Fatalf("expected JSON body: %v", err)
			}
			if _, ok := body["error"]; !ok {
				t.Error("response should contain an 'error' field")
			}
		})
	}
}

// ─── Trade Proxy: Degraded Response on Upstream Failure ──────────────────

// TestTradeProxyDegradedResponse verifies that when the self-trade backend is
// unreachable, the proxy returns 502 with `degraded: true` instead of serving
// fabricated hardcoded data. This is critical — the Flutter app needs to be
// able to distinguish "service is down" from "empty data" so it can show the
// right UI state.
func TestTradeProxyDegradedResponse(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// Register and get token
	regPayload := `{"email":"proxy-fallback@example.com","password":"secret123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(regPayload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register: expected 201, got %d", resp.StatusCode)
	}

	var regResult map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&regResult); err != nil {
		t.Fatalf("decode register response: %v", err)
	}
	token, ok := regResult["token"].(string)
	if !ok || token == "" {
		t.Fatal("register did not return a token")
	}

	// Override selfTradeBase to a fast-failing address so proxyGet returns 502
	originalBase := selfTradeBase
	selfTradeBase = "http://127.0.0.1:1"
	t.Cleanup(func() {
		selfTradeBase = originalBase
	})

	// GET /api/v1/plans — should return 502 + degraded=true since upstream is unavailable
	req2 := httptest.NewRequest("GET", "/api/v1/plans", nil)
	req2.Header.Set("Authorization", "Bearer "+token)
	resp2, err := app.Test(req2, 5000)
	if err != nil {
		t.Fatalf("GET /api/v1/plans: %v", err)
	}
	if resp2.StatusCode != fiber.StatusBadGateway {
		t.Fatalf("expected 502 (upstream unavailable), got %d", resp2.StatusCode)
	}

	var body map[string]interface{}
	if err := json.NewDecoder(resp2.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if degraded, _ := body["degraded"].(bool); !degraded {
		t.Errorf("expected 'degraded' = true, got %v", body["degraded"])
	}
	if _, ok := body["error"]; !ok {
		t.Error("response missing 'error' key")
	}
	if up, _ := body["upstream"].(string); up == "" {
		t.Error("response missing 'upstream' key")
	}

	// Critical: no fabricated data. Ensure none of the old mock keys leak through.
	for _, k := range []string{"plans", "summary", "news", "events"} {
		if _, ok := body[k]; ok {
			t.Errorf("response should NOT contain fabricated '%s' data when upstream is down", k)
		}
	}
}

// ─── Auth Refresh: Token Rotation (old token rejected after refresh) ────

func TestAuthRefresh_TokenRotation_OldTokenRejected(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// 1. Register a user to get a token
	regPayload := `{"email":"rotation@example.com","password":"secret123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(regPayload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register: expected 201, got %d", resp.StatusCode)
	}

	var regResult map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&regResult); err != nil {
		t.Fatalf("decode register response: %v", err)
	}
	oldToken, ok := regResult["token"].(string)
	if !ok || oldToken == "" {
		t.Fatal("register did not return a token")
	}

	// 2. Refresh — get a new token (this should blacklist the old one)
	refreshReq := httptest.NewRequest("POST", "/api/v1/auth/refresh", nil)
	refreshReq.Header.Set("Authorization", "Bearer "+oldToken)
	refreshResp, err := app.Test(refreshReq, 1000)
	if err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if refreshResp.StatusCode != fiber.StatusOK {
		t.Fatalf("refresh: expected 200, got %d", refreshResp.StatusCode)
	}

	var refreshBody map[string]interface{}
	if err := json.NewDecoder(refreshResp.Body).Decode(&refreshBody); err != nil {
		t.Fatalf("decode refresh response: %v", err)
	}
	newToken, ok := refreshBody["token"].(string)
	if !ok || newToken == "" {
		t.Fatal("refresh response missing 'token'")
	}
	if newToken == oldToken {
		t.Fatal("refresh returned the same token; rotation requires a new one")
	}

	// 3. Try to refresh again with the OLD token — should be rejected (401)
	refreshOldReq := httptest.NewRequest("POST", "/api/v1/auth/refresh", nil)
	refreshOldReq.Header.Set("Authorization", "Bearer "+oldToken)
	refreshOldResp, err := app.Test(refreshOldReq, 1000)
	if err != nil {
		t.Fatalf("refresh with old token: %v", err)
	}
	if refreshOldResp.StatusCode != fiber.StatusUnauthorized {
		t.Fatalf("expected 401 when reusing old token, got %d", refreshOldResp.StatusCode)
	}

	var oldRefreshBody map[string]interface{}
	if err := json.NewDecoder(refreshOldResp.Body).Decode(&oldRefreshBody); err != nil {
		t.Fatalf("decode old-token refresh response: %v", err)
	}
	errMsg, _ := oldRefreshBody["error"].(string)
	if errMsg != "token revoked" {
		t.Errorf("expected error 'token revoked', got %q", errMsg)
	}

	// 4. Try to access a protected endpoint with the OLD token — should be rejected
	profileReq := httptest.NewRequest("GET", "/api/v1/profile", nil)
	profileReq.Header.Set("Authorization", "Bearer "+oldToken)
	profileResp, err := app.Test(profileReq, 1000)
	if err != nil {
		t.Fatalf("GET /api/v1/profile with old token: %v", err)
	}
	if profileResp.StatusCode != fiber.StatusUnauthorized {
		t.Fatalf("expected 401 for old token on protected endpoint, got %d", profileResp.StatusCode)
	}

	// 5. The NEW token should still work on a protected endpoint
	newProfileReq := httptest.NewRequest("GET", "/api/v1/profile", nil)
	newProfileReq.Header.Set("Authorization", "Bearer "+newToken)
	newProfileResp, err := app.Test(newProfileReq, 1000)
	if err != nil {
		t.Fatalf("GET /api/v1/profile with new token: %v", err)
	}
	if newProfileResp.StatusCode == fiber.StatusUnauthorized {
		t.Fatal("new token was incorrectly rejected by auth middleware")
	}
}

// ─── Auth Register Transactional Integrity ──────────────────────────────

func TestAuthRegister_TransactionalIntegrity(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// 1. Register a user
	payload := `{"email":"tx-integrity@example.com","password":"secret123","display_name":"TX User"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register: expected 201, got %d", resp.StatusCode)
	}

	// 2. Verify all three related rows exist
	email := "tx-integrity@example.com"

	var userCount int
	if err := database.DB.QueryRow("SELECT COUNT(*) FROM users WHERE email = ?", email).Scan(&userCount); err != nil {
		t.Fatalf("query users: %v", err)
	}
	if userCount != 1 {
		t.Errorf("expected 1 user row, got %d", userCount)
	}

	var profileCount int
	if err := database.DB.QueryRow("SELECT COUNT(*) FROM profiles WHERE email = ?", email).Scan(&profileCount); err != nil {
		t.Fatalf("query profiles: %v", err)
	}
	if profileCount != 1 {
		t.Errorf("expected 1 profile row, got %d", profileCount)
	}

	// Join user_preferences via user_id for this email
	var prefsCount int
	if err := database.DB.QueryRow(
		"SELECT COUNT(*) FROM user_preferences up JOIN users u ON u.id = up.user_id WHERE u.email = ?", email,
	).Scan(&prefsCount); err != nil {
		t.Fatalf("query user_preferences: %v", err)
	}
	if prefsCount != 1 {
		t.Errorf("expected 1 user_preferences row, got %d", prefsCount)
	}

	// 3. Attempt duplicate registration — should fail with 409
	req2 := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(payload))
	req2.Header.Set("Content-Type", "application/json")
	resp2, err := app.Test(req2, 1000)
	if err != nil {
		t.Fatalf("duplicate register: %v", err)
	}
	if resp2.StatusCode != fiber.StatusConflict {
		t.Fatalf("duplicate register: expected 409, got %d", resp2.StatusCode)
	}

	// 4. Verify row counts are unchanged (no orphan rows from the duplicate attempt)
	if err := database.DB.QueryRow("SELECT COUNT(*) FROM users WHERE email = ?", email).Scan(&userCount); err != nil {
		t.Fatalf("query users after duplicate: %v", err)
	}
	if userCount != 1 {
		t.Errorf("after duplicate: expected 1 user row, got %d", userCount)
	}

	if err := database.DB.QueryRow("SELECT COUNT(*) FROM profiles WHERE email = ?", email).Scan(&profileCount); err != nil {
		t.Fatalf("query profiles after duplicate: %v", err)
	}
	if profileCount != 1 {
		t.Errorf("after duplicate: expected 1 profile row, got %d", profileCount)
	}

	if err := database.DB.QueryRow(
		"SELECT COUNT(*) FROM user_preferences up JOIN users u ON u.id = up.user_id WHERE u.email = ?", email,
	).Scan(&prefsCount); err != nil {
		t.Fatalf("query user_preferences after duplicate: %v", err)
	}
	if prefsCount != 1 {
		t.Errorf("after duplicate: expected 1 user_preferences row, got %d", prefsCount)
	}
}

// ─── Auth Refresh: Blacklisted Token ────────────────────────────────────

func TestAuthRefresh_BlacklistedToken(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// 1. Register a user to get a token
	regPayload := `{"email":"refresh-blacklist@example.com","password":"secret123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(regPayload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register: expected 201, got %d", resp.StatusCode)
	}

	var regResult map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&regResult); err != nil {
		t.Fatalf("decode register response: %v", err)
	}
	token, ok := regResult["token"].(string)
	if !ok || token == "" {
		t.Fatal("register did not return a token")
	}

	// 2. Logout (blacklists the token)
	logoutReq := httptest.NewRequest("POST", "/api/v1/auth/logout", nil)
	logoutReq.Header.Set("Authorization", "Bearer "+token)
	logoutResp, err := app.Test(logoutReq, 1000)
	if err != nil {
		t.Fatalf("logout: %v", err)
	}
	if logoutResp.StatusCode != fiber.StatusOK {
		t.Fatalf("logout: expected 200, got %d", logoutResp.StatusCode)
	}

	// 3. Try to refresh with the blacklisted token — should be rejected
	refreshReq := httptest.NewRequest("POST", "/api/v1/auth/refresh", nil)
	refreshReq.Header.Set("Authorization", "Bearer "+token)
	refreshResp, err := app.Test(refreshReq, 1000)
	if err != nil {
		t.Fatalf("refresh with blacklisted token: %v", err)
	}
	if refreshResp.StatusCode != fiber.StatusUnauthorized {
		t.Fatalf("expected 401 for blacklisted token, got %d", refreshResp.StatusCode)
	}

	var refreshBody map[string]interface{}
	if err := json.NewDecoder(refreshResp.Body).Decode(&refreshBody); err != nil {
		t.Fatalf("decode refresh response: %v", err)
	}
	errMsg, _ := refreshBody["error"].(string)
	if errMsg != "token revoked" {
		t.Errorf("expected error 'token revoked', got %q", errMsg)
	}
}

// ─── Auth Refresh: Rotation (old token blacklisted after refresh) ──────

func TestAuthRefresh_Rotation(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// 1. Register a user to get a token
	regPayload := `{"email":"rotation@example.com","password":"secret123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(regPayload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register: expected 201, got %d", resp.StatusCode)
	}

	var regResult map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&regResult); err != nil {
		t.Fatalf("decode register response: %v", err)
	}
	oldToken, ok := regResult["token"].(string)
	if !ok || oldToken == "" {
		t.Fatal("register did not return a token")
	}

	// 2. Refresh — gets a new token, old one gets blacklisted
	refreshReq := httptest.NewRequest("POST", "/api/v1/auth/refresh", nil)
	refreshReq.Header.Set("Authorization", "Bearer "+oldToken)
	refreshResp, err := app.Test(refreshReq, 1000)
	if err != nil {
		t.Fatalf("first refresh: %v", err)
	}
	if refreshResp.StatusCode != fiber.StatusOK {
		t.Fatalf("first refresh: expected 200, got %d", refreshResp.StatusCode)
	}

	var refreshResult map[string]interface{}
	if err := json.NewDecoder(refreshResp.Body).Decode(&refreshResult); err != nil {
		t.Fatalf("decode first refresh response: %v", err)
	}
	newToken, ok := refreshResult["token"].(string)
	if !ok || newToken == "" {
		t.Fatal("first refresh response missing 'token'")
	}
	if newToken == oldToken {
		t.Error("refresh returned the same token; expected rotation")
	}

	// 3. Try to refresh with the OLD token — should be rejected (rotated)
	repeatReq := httptest.NewRequest("POST", "/api/v1/auth/refresh", nil)
	repeatReq.Header.Set("Authorization", "Bearer "+oldToken)
	repeatResp, err := app.Test(repeatReq, 1000)
	if err != nil {
		t.Fatalf("refresh with old (rotated) token: %v", err)
	}
	if repeatResp.StatusCode != fiber.StatusUnauthorized {
		t.Fatalf("expected 401 for rotated old token, got %d", repeatResp.StatusCode)
	}

	var repeatBody map[string]interface{}
	if err := json.NewDecoder(repeatResp.Body).Decode(&repeatBody); err != nil {
		t.Fatalf("decode rotated-token response: %v", err)
	}
	errMsg, _ := repeatBody["error"].(string)
	if errMsg != "token revoked" {
		t.Errorf("expected error 'token revoked', got %q", errMsg)
	}

	// 4. The NEW token should still work on a protected endpoint
	profileReq := httptest.NewRequest("GET", "/api/v1/profile", nil)
	profileReq.Header.Set("Authorization", "Bearer "+newToken)
	profileResp, err := app.Test(profileReq, 1000)
	if err != nil {
		t.Fatalf("GET /api/v1/profile with new token: %v", err)
	}
	if profileResp.StatusCode == fiber.StatusUnauthorized {
		t.Fatal("new token was rejected by auth middleware after rotation")
	}
}

// ─── Auth Blacklist: Cleanup removes expired entries ──────────────────

func TestAuthBlacklist_Cleanup(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// 1. Insert an expired blacklist entry directly
	expiredJTI := "expired-jti-cleanup-test"
	pastTime := time.Now().UTC().Add(-1 * time.Hour).Format(time.RFC3339)
	_, err := database.DB.Exec(
		"INSERT INTO token_blacklist (jti, expires_at) VALUES (?, ?)",
		expiredJTI, pastTime,
	)
	if err != nil {
		t.Fatalf("insert expired blacklist entry: %v", err)
	}

	// 2. Insert a non-expired (still valid) blacklist entry
	validJTI := "valid-jti-cleanup-test"
	futureTime := time.Now().UTC().Add(24 * time.Hour).Format(time.RFC3339)
	_, err = database.DB.Exec(
		"INSERT INTO token_blacklist (jti, expires_at) VALUES (?, ?)",
		validJTI, futureTime,
	)
	if err != nil {
		t.Fatalf("insert valid blacklist entry: %v", err)
	}

	// 3. Verify both exist before cleanup
	var beforeCount int
	if err := database.DB.QueryRow("SELECT COUNT(*) FROM token_blacklist").Scan(&beforeCount); err != nil {
		t.Fatalf("count before cleanup: %v", err)
	}
	if beforeCount != 2 {
		t.Fatalf("expected 2 blacklist entries before cleanup, got %d", beforeCount)
	}

	// 4. Run cleanup
	cleanupExpiredBlacklistEntries()

	// 5. Verify expired entry was removed
	var expiredCount int
	if err := database.DB.QueryRow("SELECT COUNT(*) FROM token_blacklist WHERE jti = ?", expiredJTI).Scan(&expiredCount); err != nil {
		t.Fatalf("count expired after cleanup: %v", err)
	}
	if expiredCount != 0 {
		t.Error("expired blacklist entry was NOT removed by cleanup")
	}

	// 6. Verify valid (non-expired) entry remains
	var validCount int
	if err := database.DB.QueryRow("SELECT COUNT(*) FROM token_blacklist WHERE jti = ?", validJTI).Scan(&validCount); err != nil {
		t.Fatalf("count valid after cleanup: %v", err)
	}
	if validCount != 1 {
		t.Error("valid (non-expired) blacklist entry was incorrectly removed by cleanup")
	}

	var afterCount int
	if err := database.DB.QueryRow("SELECT COUNT(*) FROM token_blacklist").Scan(&afterCount); err != nil {
		t.Fatalf("count after cleanup: %v", err)
	}
	if afterCount != 1 {
		t.Fatalf("expected 1 blacklist entry after cleanup, got %d", afterCount)
	}

	// 7. Verify normal auth flow still works after cleanup
	regPayload := `{"email":"cleanup-auth-test@example.com","password":"secret123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(regPayload))
	req.Header.Set("Content-Type", "application/json")
	regResp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register after cleanup: %v", err)
	}
	if regResp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register after cleanup: expected 201, got %d", regResp.StatusCode)
	}

	var regResult map[string]interface{}
	if err := json.NewDecoder(regResp.Body).Decode(&regResult); err != nil {
		t.Fatalf("decode register response after cleanup: %v", err)
	}
	token, ok := regResult["token"].(string)
	if !ok || token == "" {
		t.Fatal("register after cleanup did not return a token")
	}

	// Access a protected endpoint with the new token
	profileReq := httptest.NewRequest("GET", "/api/v1/profile", nil)
	profileReq.Header.Set("Authorization", "Bearer "+token)
	profileResp, err := app.Test(profileReq, 1000)
	if err != nil {
		t.Fatalf("GET /api/v1/profile after cleanup: %v", err)
	}
	if profileResp.StatusCode == fiber.StatusUnauthorized {
		t.Fatal("valid token was rejected after blacklist cleanup")
	}

	// 8. Logout then verify the valid blacklist entry is still honoured
	logoutReq := httptest.NewRequest("POST", "/api/v1/auth/logout", nil)
	logoutReq.Header.Set("Authorization", "Bearer "+token)
	logoutResp, err := app.Test(logoutReq, 1000)
	if err != nil {
		t.Fatalf("logout after cleanup: %v", err)
	}
	if logoutResp.StatusCode != fiber.StatusOK {
		t.Fatalf("logout after cleanup: expected 200, got %d", logoutResp.StatusCode)
	}

	// Access the same endpoint with revoked token — should be blocked
	blockedReq := httptest.NewRequest("GET", "/api/v1/profile", nil)
	blockedReq.Header.Set("Authorization", "Bearer "+token)
	blockedResp, err := app.Test(blockedReq, 1000)
	if err != nil {
		t.Fatalf("GET /api/v1/profile with revoked token: %v", err)
	}
	if blockedResp.StatusCode != fiber.StatusUnauthorized {
		t.Fatalf("expected 401 for revoked token, got %d", blockedResp.StatusCode)
	}
}

// ─── Auth Refresh: Valid Token (not blacklisted) ────────────────────────

func TestAuthRefresh_ValidToken(t *testing.T) {
	setupTestDB(t)
	app := setupTestApp()

	// 1. Register a user to get a token
	regPayload := `{"email":"refresh-valid@example.com","password":"secret123"}`
	req := httptest.NewRequest("POST", "/api/v1/auth/register", strings.NewReader(regPayload))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, 1000)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("register: expected 201, got %d", resp.StatusCode)
	}

	var regResult map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&regResult); err != nil {
		t.Fatalf("decode register response: %v", err)
	}
	token, ok := regResult["token"].(string)
	if !ok || token == "" {
		t.Fatal("register did not return a token")
	}

	// 2. Refresh with the valid token — should succeed
	refreshReq := httptest.NewRequest("POST", "/api/v1/auth/refresh", nil)
	refreshReq.Header.Set("Authorization", "Bearer "+token)
	refreshResp, err := app.Test(refreshReq, 1000)
	if err != nil {
		t.Fatalf("refresh: %v", err)
	}
	if refreshResp.StatusCode != fiber.StatusOK {
		t.Fatalf("expected 200, got %d", refreshResp.StatusCode)
	}

	var refreshBody map[string]interface{}
	if err := json.NewDecoder(refreshResp.Body).Decode(&refreshBody); err != nil {
		t.Fatalf("decode refresh response: %v", err)
	}
	newToken, ok := refreshBody["token"].(string)
	if !ok || newToken == "" {
		t.Fatal("refresh response missing 'token'")
	}
	if newToken == token {
		t.Error("refresh returned the same token; expected a new one")
	}

	// 3. The new token should be usable on a protected endpoint
	profileReq := httptest.NewRequest("GET", "/api/v1/profile", nil)
	profileReq.Header.Set("Authorization", "Bearer "+newToken)
	profileResp, err := app.Test(profileReq, 1000)
	if err != nil {
		t.Fatalf("GET /api/v1/profile with new token: %v", err)
	}
	if profileResp.StatusCode == fiber.StatusUnauthorized {
		t.Fatal("new token was rejected by auth middleware")
	}
}
