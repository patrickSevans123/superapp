package main

import (
	"crypto/rand"
	"database/sql"
	"encoding/base64"
	"fmt"
	"log"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/patrickSevans123/superapp-api/database"
)

// ─── JWT Config ─────────────────────────────────────────────────────────────

var (
	jwtSecretMu sync.Mutex
	jwtSecret   []byte
)

func getJWTSecret() ([]byte, error) {
	jwtSecretMu.Lock()
	defer jwtSecretMu.Unlock()

	if len(jwtSecret) > 0 {
		return jwtSecret, nil
	}

	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		return nil, fmt.Errorf("JWT_SECRET environment variable is required")
	}
	jwtSecret = []byte(secret)
	return jwtSecret, nil
}

// parseAndValidateJWT parses a JWT token string and returns its claims.
// Returns an error if the token is invalid, expired, or has wrong signing method.
func parseAndValidateJWT(tokenStr string) (jwt.MapClaims, error) {
	jwtSecret, err := getJWTSecret()
	if err != nil {
		return nil, err
	}

	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return jwtSecret, nil
	})
	if err != nil || !token.Valid {
		return nil, fmt.Errorf("invalid or expired token")
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return nil, fmt.Errorf("invalid token claims")
	}
	return claims, nil
}

// generateJWT creates a signed JWT token for the given user.
func generateJWT(userID, email string) (string, error) {
	jwtSecret, err := getJWTSecret()
	if err != nil {
		return "", err
	}

	now := time.Now()
	jti := make([]byte, 16)
	_, _ = rand.Read(jti)

	claims := jwt.MapClaims{
		"user_id": userID,
		"email":   email,
		"exp":     now.Add(30 * 24 * time.Hour).Unix(),
		"iat":     now.Unix(),
		"jti":     base64.RawURLEncoding.EncodeToString(jti),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

// ─── Auth Middleware ────────────────────────────────────────────────────────

// authMiddleware verifies the JWT in the Authorization header and sets user_id
// and email in Fiber locals. It skips auth routes and health check.
func authMiddleware(c *fiber.Ctx) error {
	// Skip auth routes, health check, and public reference data
	path := c.Path()
	if strings.HasPrefix(path, "/api/v1/auth") ||
		path == "/health" ||
		strings.HasPrefix(path, "/api/v1/reference") {
		return c.Next()
	}

	authHeader := c.Get("Authorization")
	if authHeader == "" {
		return c.Status(401).JSON(fiber.Map{"error": "missing authorization header"})
	}

	tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
	if tokenStr == authHeader {
		return c.Status(401).JSON(fiber.Map{"error": "invalid authorization format"})
	}

	claims, err := parseAndValidateJWT(tokenStr)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "invalid or expired token"})
	}

	// Check if token is blacklisted.
	jtiRaw, _ := claims["jti"]
	jtiStr, _ := jtiRaw.(string)
	if jtiStr != "" {
		var count int
		err := database.DB.QueryRow("SELECT COUNT(*) FROM token_blacklist WHERE jti = ?", jtiStr).Scan(&count)
		if err == nil && count > 0 {
			return c.Status(401).JSON(fiber.Map{"error": "token revoked"})
		}
	}

	c.Locals("user_id", claims["user_id"])
	c.Locals("email", claims["email"])
	return c.Next()
}

// cleanupExpiredBlacklistEntries removes expired rows from token_blacklist.
// Called periodically by the background cleanup goroutine (see main.go).
// Public so existing tests can call it directly.
func cleanupExpiredBlacklistEntries() {
	if _, err := database.DB.Exec(
		"DELETE FROM token_blacklist WHERE datetime(expires_at) < datetime('now')",
	); err != nil {
		log.Printf("WARN: cleanup expired blacklist entries: %v", err)
	}
}

// startBlacklistCleanup runs cleanupExpiredBlacklistEntries every interval
// in a background goroutine. This replaces the previous "run on every
// authenticated request" pattern, which was a DB write per request.
func startBlacklistCleanup(interval time.Duration) chan struct{} {
	stop := make(chan struct{})
	go func() {
		t := time.NewTicker(interval)
		defer t.Stop()
		// Run once on startup to clear anything stale from a prior crash.
		cleanupExpiredBlacklistEntries()
		for {
			select {
			case <-t.C:
				cleanupExpiredBlacklistEntries()
			case <-stop:
				return
			}
		}
	}()
	return stop
}

// ─── Auth Response Helper ───────────────────────────────────────────────────

type authUserResponse struct {
	ID          string `json:"id"`
	Email       string `json:"email"`
	DisplayName string `json:"display_name"`
	CreatedAt   string `json:"created_at"`
}

type authResponse struct {
	User  authUserResponse `json:"user"`
	Token string           `json:"token"`
}

// emailRegex is intentionally simple — full RFC 5322 is hundreds of lines
// and rejects some valid addresses. The goal is to catch typos, not be
// authoritative. Server-side validation is the second layer; the user
// verifies their email via the link sent to it.
var emailRegex = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)

const (
	minPasswordLen  = 8
	maxPasswordLen  = 128
	minDisplayName  = 1
	maxDisplayName  = 50
	maxEmailLength  = 254
)

// getBcryptCost returns the bcrypt cost factor to use when hashing passwords.
// The value is read from the BCRYPT_COST env var, with a default of 12.
// We clamp the result to a safe range [10, 15]: below 10 is insecure (hashes
// are brute-forceable in seconds), above 15 is slow enough to DoS the login
// endpoint. Invalid values (non-numeric, < 4) fall back to the default.
func getBcryptCost() int {
	v := os.Getenv("BCRYPT_COST")
	if v == "" {
		return 12
	}
	n, err := strconv.Atoi(v)
	if err != nil || n < 4 {
		log.Printf("WARN: invalid BCRYPT_COST %q, using 12", v)
		return 12
	}
	if n < 10 {
		log.Printf("WARN: BCRYPT_COST %d is too low (min 10), clamping to 10", n)
		return 10
	}
	if n > 15 {
		log.Printf("WARN: BCRYPT_COST %d is too high (max 15), clamping to 15", n)
		return 15
	}
	return n
}

// ─── Auth Handlers ──────────────────────────────────────────────────────────

// handleRegister creates a new user account.
// POST /api/v1/auth/register
func handleRegister(c *fiber.Ctx) error {
	var body struct {
		Email       string `json:"email"`
		Password    string `json:"password"`
		DisplayName string `json:"display_name"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}

	// Validate inputs
	body.Email = strings.TrimSpace(strings.ToLower(body.Email))
	if body.Email == "" {
		return c.Status(400).JSON(fiber.Map{"error": "email is required"})
	}
	if len(body.Email) > maxEmailLength {
		return c.Status(400).JSON(fiber.Map{"error": "email too long"})
	}
	if !emailRegex.MatchString(body.Email) {
		return c.Status(400).JSON(fiber.Map{"error": "email format is invalid"})
	}
	if n := len(body.Password); n < minPasswordLen || n > maxPasswordLen {
		return c.Status(400).JSON(fiber.Map{
			"error": fmt.Sprintf("password must be between %d and %d characters", minPasswordLen, maxPasswordLen),
		})
	}
	body.DisplayName = strings.TrimSpace(body.DisplayName)
	if n := len(body.DisplayName); n < minDisplayName {
		body.DisplayName = strings.Split(body.Email, "@")[0]
	} else if n > maxDisplayName {
		body.DisplayName = body.DisplayName[:maxDisplayName]
	}

	// Check if email already exists
	var existingID string
	err := database.DB.QueryRow("SELECT id FROM users WHERE email = ?", body.Email).Scan(&existingID)
	if err == nil {
		return c.Status(409).JSON(fiber.Map{"error": "email already registered"})
	}

	// Hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(body.Password), getBcryptCost())
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to hash password"})
	}

	// Generate IDs
	userID := randomID()
	prefsID := randomID()
	now := time.Now().UTC().Format("20060102T150405Z")

	// ── Transactional inserts: users + profiles + preferences ──
	tx, err := database.DB.Begin()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to begin transaction"})
	}
	defer tx.Rollback() // no-op on successful Commit

	// Insert user
	_, err = tx.Exec(
		"INSERT INTO users (id, email, password_hash, display_name, created_at) VALUES (?, ?, ?, ?, ?)",
		userID, body.Email, string(hash), body.DisplayName, now,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to create user"})
	}

	// Insert profile
	_, err = tx.Exec(
		"INSERT INTO profiles (id, email, display_name, created_at) VALUES (?, ?, ?, ?)",
		userID, body.Email, body.DisplayName, now,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to create profile"})
	}

	// Insert default preferences
	_, err = tx.Exec(
		`INSERT INTO user_preferences (id, user_id, tp_hit, sl_hit, price_alert, msci_announce, ftse_notice, new_report, plan_created, scholarship_alert, fashion_alert, created_at)
		 VALUES (?, ?, 1, 1, 1, 1, 1, 1, 1, 1, 1, ?)`,
		prefsID, userID, now,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to create preferences"})
	}

	// Commit all inserts atomically
	if err := tx.Commit(); err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to finalize registration"})
	}

	// Generate JWT
	token, err := generateJWT(userID, body.Email)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to generate token"})
	}

	return c.Status(201).JSON(authResponse{
		User: authUserResponse{
			ID:          userID,
			Email:       body.Email,
			DisplayName: body.DisplayName,
			CreatedAt:   now,
		},
		Token: token,
	})
}

// handleLogin authenticates a user with email and password.
// POST /api/v1/auth/login
func handleLogin(c *fiber.Ctx) error {
	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}

	body.Email = strings.TrimSpace(strings.ToLower(body.Email))
	if body.Email == "" {
		return c.Status(400).JSON(fiber.Map{"error": "email is required"})
	}
	if body.Password == "" {
		return c.Status(400).JSON(fiber.Map{"error": "password is required"})
	}

	// Look up user
	var userID, email, passwordHash, displayName, createdAt string
	err := database.DB.QueryRow(
		"SELECT id, email, password_hash, display_name, created_at FROM users WHERE email = ?",
		body.Email,
	).Scan(&userID, &email, &passwordHash, &displayName, &createdAt)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "invalid email or password"})
	}

	// Compare password
	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(body.Password)); err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "invalid email or password"})
	}

	// Generate JWT
	token, err := generateJWT(userID, email)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to generate token"})
	}

	return c.JSON(authResponse{
		User: authUserResponse{
			ID:          userID,
			Email:       email,
			DisplayName: displayName,
			CreatedAt:   createdAt,
		},
		Token: token,
	})
}

// handleRefresh issues a new JWT token and implements rotation: the old
// token is immediately blacklisted so it cannot be used again.
// POST /api/v1/auth/refresh
func handleRefresh(c *fiber.Ctx) error {
	authHeader := c.Get("Authorization")
	if authHeader == "" {
		return c.Status(401).JSON(fiber.Map{"error": "missing authorization header"})
	}

	tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
	claims, err := parseAndValidateJWT(tokenStr)
	if err != nil {
		return c.Status(401).JSON(fiber.Map{"error": "invalid or expired token"})
	}

	userID, _ := claims["user_id"].(string)
	email, _ := claims["email"].(string)

	if userID == "" {
		return c.Status(401).JSON(fiber.Map{"error": "invalid token payload"})
	}

	// Opportunistic cleanup of expired blacklist entries
	cleanupExpiredBlacklistEntries()

	// Check if token is blacklisted
	jtiRaw, _ := claims["jti"]
	jtiStr, _ := jtiRaw.(string)
	if jtiStr != "" {
		var count int
		err := database.DB.QueryRow("SELECT COUNT(*) FROM token_blacklist WHERE jti = ?", jtiStr).Scan(&count)
		if err == nil && count > 0 {
			return c.Status(401).JSON(fiber.Map{"error": "token revoked"})
		}
	}

	// Generate new token before blacklisting old one
	newToken, err := generateJWT(userID, email)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to generate token"})
	}

	// Blacklist the old token (rotation) so it cannot be reused
	if jtiStr != "" {
		expRaw, _ := claims["exp"]
		if expFloat, ok := expRaw.(float64); ok {
			expiresAt := time.Unix(int64(expFloat), 0).UTC().Format(time.RFC3339)
			_, _ = database.DB.Exec(
				"INSERT OR IGNORE INTO token_blacklist (jti, expires_at) VALUES (?, ?)",
				jtiStr, expiresAt,
			)
		}
	}

	return c.JSON(fiber.Map{"token": newToken})
}

// handleLogout revokes the current JWT token.
// POST /api/v1/auth/logout
func handleLogout(c *fiber.Ctx) error {
	// Extract JTI from a verified current token
	authHeader := c.Get("Authorization")
	tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
	claims, err := parseAndValidateJWT(tokenStr)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid token"})
	}
	jti, _ := claims["jti"].(string)
	exp, _ := claims["exp"].(float64)

	if jti == "" {
		return c.Status(400).JSON(fiber.Map{"error": "token has no jti"})
	}

	// Opportunistic cleanup of expired blacklist entries
	cleanupExpiredBlacklistEntries()

	expiresAt := time.Unix(int64(exp), 0).UTC().Format(time.RFC3339)
	_, err = database.DB.Exec(
		"INSERT OR IGNORE INTO token_blacklist (jti, expires_at) VALUES (?, ?)",
		jti, expiresAt,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to revoke token"})
	}

	return c.JSON(fiber.Map{"message": "logged out successfully"})
}

// ─── JSON Helpers ───────────────────────────────────────────────────────────

// scanRows converts SQLite rows into a slice of map[string]interface{}.
func scanRows(rows *sql.Rows) ([]map[string]interface{}, error) {
	cols, err := rows.Columns()
	if err != nil {
		return nil, fmt.Errorf("get columns: %w", err)
	}

	var results []map[string]interface{}
	for rows.Next() {
		values := make([]interface{}, len(cols))
		valuePtrs := make([]interface{}, len(cols))
		for i := range cols {
			valuePtrs[i] = &values[i]
		}

		if err := rows.Scan(valuePtrs...); err != nil {
			return nil, fmt.Errorf("scan row: %w", err)
		}

		entry := make(map[string]interface{})
		for i, col := range cols {
			val := values[i]
			// NOTE: SQLite returns TEXT as []byte — safe to convert since all columns queried
			// by the callers are text/boolean/numeric (never binary BLOBs).
			if b, ok := val.([]byte); ok {
				val = string(b)
			}
			entry[col] = val
		}
		results = append(results, entry)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows iteration: %w", err)
	}

	return results, nil
}

// scanOneRow scans a single row and returns a map, or sql.ErrNoRows if empty.
func scanOneRow(rows *sql.Rows) (map[string]interface{}, error) {
	results, err := scanRows(rows)
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, sql.ErrNoRows
	}
	return results[0], nil
}
