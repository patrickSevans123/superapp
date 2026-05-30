package main

import (
	"crypto/rand"
	"database/sql"
	"encoding/base64"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/patrickSevans123/superapp-api/database"
)

// ─── JWT Config ─────────────────────────────────────────────────────────────

var jwtSecret = []byte(getEnvOrDefault("JWT_SECRET", "superapp-dev-secret-change-in-production"))

func getEnvOrDefault(key, defaultVal string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultVal
}

// generateJWT creates a signed JWT token for the given user.
func generateJWT(userID, email string) (string, error) {
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
	// Skip auth routes and health check
	path := c.Path()
	if strings.HasPrefix(path, "/api/v1/auth") || path == "/health" {
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

	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return jwtSecret, nil
	})
	if err != nil || !token.Valid {
		return c.Status(401).JSON(fiber.Map{"error": "invalid or expired token"})
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "invalid token claims"})
	}

	c.Locals("user_id", claims["user_id"])
	c.Locals("email", claims["email"])
	return c.Next()
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

// ─── Auth Handlers ──────────────────────────────────────────────────────────

// handleRegister creates a new user account.
// POST /api/v1/auth/register
func handleRegister(c *fiber.Ctx) error {
	var body struct {
		Email       string `json:"email"`
		Password    string `json:"password"`
		DisplayName string `json:"display_name"`
	}
	rawBody := string(c.Body())
	log.Printf("DEBUG register raw body (%d bytes): %q", len(rawBody), rawBody)
	if err := c.BodyParser(&body); err != nil {
		log.Printf("DEBUG register parse error: %v", err)
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}

	// Validate inputs
	body.Email = strings.TrimSpace(strings.ToLower(body.Email))
	if body.Email == "" {
		return c.Status(400).JSON(fiber.Map{"error": "email is required"})
	}
	if len(body.Password) < 6 {
		return c.Status(400).JSON(fiber.Map{"error": "password must be at least 6 characters"})
	}
	if body.DisplayName == "" {
		body.DisplayName = strings.Split(body.Email, "@")[0]
	}

	// Check if email already exists
	var existingID string
	err := database.DB.QueryRow("SELECT id FROM users WHERE email = ?", body.Email).Scan(&existingID)
	if err == nil {
		return c.Status(409).JSON(fiber.Map{"error": "email already registered"})
	}

	// Hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(body.Password), 12)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to hash password"})
	}

	// Generate IDs
	userID := randomID()
	prefsID := randomID()
	now := time.Now().UTC().Format("20060102T150405Z")

	// Insert user
	_, err = database.DB.Exec(
		"INSERT INTO users (id, email, password_hash, display_name, created_at) VALUES (?, ?, ?, ?, ?)",
		userID, body.Email, string(hash), body.DisplayName, now,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to create user"})
	}

	// Insert profile
	_, err = database.DB.Exec(
		"INSERT INTO profiles (id, email, display_name, created_at) VALUES (?, ?, ?, ?)",
		userID, body.Email, body.DisplayName, now,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to create profile"})
	}

	// Insert default preferences
	_, err = database.DB.Exec(
		`INSERT INTO user_preferences (id, user_id, tp_hit, sl_hit, price_alert, msci_announce, ftse_notice, new_report, plan_created, scholarship_alert, fashion_alert, created_at)
		 VALUES (?, ?, 1, 1, 1, 1, 1, 1, 1, 1, 1, ?)`,
		prefsID, userID, now,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to create preferences"})
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

// handleRefresh issues a new JWT token if the current one is still valid.
// POST /api/v1/auth/refresh
func handleRefresh(c *fiber.Ctx) error {
	authHeader := c.Get("Authorization")
	if authHeader == "" {
		return c.Status(401).JSON(fiber.Map{"error": "missing authorization header"})
	}

	tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return jwtSecret, nil
	})
	if err != nil || !token.Valid {
		return c.Status(401).JSON(fiber.Map{"error": "invalid or expired token"})
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return c.Status(401).JSON(fiber.Map{"error": "invalid token claims"})
	}

	userID, _ := claims["user_id"].(string)
	email, _ := claims["email"].(string)

	if userID == "" {
		return c.Status(401).JSON(fiber.Map{"error": "invalid token payload"})
	}

	// Generate new token
	newToken, err := generateJWT(userID, email)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to generate token"})
	}

	return c.JSON(fiber.Map{"token": newToken})
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
