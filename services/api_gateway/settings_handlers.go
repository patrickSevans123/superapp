package main

import (
	"database/sql"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"

	"github.com/patrickSevans123/superapp-api/database"
)

// allowedPrefs is the column whitelist for user_preferences updates.
// Prevents SQL injection via arbitrary JSON body keys.
var allowedPrefs = map[string]bool{
	"tp_hit": true, "sl_hit": true, "price_alert": true,
	"msci_announce": true, "ftse_notice": true, "new_report": true,
	"plan_created": true, "scholarship_alert": true, "fashion_alert": true,
}

// ─── Profile Handlers ──────────────────────────────────────────────────────

func handleGetProfile(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(401).JSON(fiber.Map{"error": "authentication required"})
	}

	rows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM profiles WHERE id = ?", userID.(string))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query profile"})
	}
	defer rows.Close()

	profile, err := scanOneRow(rows)
	if err == sql.ErrNoRows {
		return c.Status(404).JSON(fiber.Map{"error": "profile not found"})
	}
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse profile"})
	}

	return c.JSON(profile)
}

func handleUpdateProfile(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(401).JSON(fiber.Map{"error": "authentication required"})
	}

	var body struct {
		DisplayName *string `json:"display_name"`
		AvatarURL   *string `json:"avatar_url"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}

	// Build SET clause with only provided fields
	var setClauses []string
	var args []interface{}
	if body.DisplayName != nil {
		setClauses = append(setClauses, "display_name = ?")
		args = append(args, *body.DisplayName)
	}
	if body.AvatarURL != nil {
		setClauses = append(setClauses, "avatar_url = ?")
		args = append(args, *body.AvatarURL)
	}

	if len(setClauses) == 0 {
		return c.Status(400).JSON(fiber.Map{"error": "no fields to update"})
	}

	args = append(args, userID.(string))
	_, err := database.DB.ExecContext(c.Context(),
		"UPDATE profiles SET "+strings.Join(setClauses, ", ")+" WHERE id = ?",
		args...,
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to update profile"})
	}

	// Return updated profile
	rows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM profiles WHERE id = ?", userID.(string))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query updated profile"})
	}
	defer rows.Close()

	profile, err := scanOneRow(rows)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to parse updated profile"})
	}

	return c.JSON(profile)
}

// ─── Settings Handlers ─────────────────────────────────────────────────────

// handleGetSettings returns the combined account and preferences for a user.
// GET /api/v1/settings
func handleGetSettings(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(401).JSON(fiber.Map{"error": "authentication required"})
	}
	uid := userID.(string)

	// Fetch profile from SQLite
	profileRows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM profiles WHERE id = ?", uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query profile"})
	}
	defer profileRows.Close()

	profile, err := scanOneRow(profileRows)
	if err != nil {
		profile = map[string]interface{}{}
	}

	// Fetch preferences from SQLite
	prefRows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM user_preferences WHERE user_id = ?", uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query preferences"})
	}
	defer prefRows.Close()

	prefs, err := scanOneRow(prefRows)
	if err != nil {
		prefs = map[string]interface{}{}
	}

	return c.JSON(fiber.Map{
		"account":     profile,
		"preferences": prefs,
	})
}

// handleUpdateSettings updates account and/or preference fields for a user.
// PATCH /api/v1/settings
func handleUpdateSettings(c *fiber.Ctx) error {
	userID := c.Locals("user_id")
	if userID == nil || userID.(string) == "" {
		return c.Status(401).JSON(fiber.Map{"error": "authentication required"})
	}
	uid := userID.(string)

	var body struct {
		DisplayName *string                 `json:"display_name"`
		AvatarURL   *string                 `json:"avatar_url"`
		Preferences *map[string]interface{} `json:"preferences"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "invalid JSON body"})
	}

	updated := false

	// Update profile fields if provided
	if body.DisplayName != nil || body.AvatarURL != nil {
		var setClauses []string
		var args []interface{}
		if body.DisplayName != nil {
			setClauses = append(setClauses, "display_name = ?")
			args = append(args, *body.DisplayName)
		}
		if body.AvatarURL != nil {
			setClauses = append(setClauses, "avatar_url = ?")
			args = append(args, *body.AvatarURL)
		}
		args = append(args, uid)
		_, err := database.DB.ExecContext(c.Context(),
			"UPDATE profiles SET "+strings.Join(setClauses, ", ")+" WHERE id = ?",
			args...,
		)
		if err != nil {
			return c.Status(500).JSON(fiber.Map{"error": "failed to update profile"})
		}
		updated = true
	}

	// Update preferences if provided — single UPSERT avoids SELECT-then-INSERT race
	if body.Preferences != nil {
		prefs := *body.Preferences
		// Remove non-preference keys
		delete(prefs, "id")
		delete(prefs, "user_id")
		delete(prefs, "created_at")

		if len(prefs) > 0 {
			var cols []string
			var placeholders []string
			var setClauses []string
			var args []interface{}
			args = append(args, randomID(), uid)
			cols = append(cols, "id", "user_id")
			placeholders = append(placeholders, "?", "?")
			for k, v := range prefs {
				if !allowedPrefs[k] {
					continue
				}
				cols = append(cols, k)
				placeholders = append(placeholders, "?")
				setClauses = append(setClauses, k+" = excluded."+k)
				args = append(args, v)
			}
			cols = append(cols, "created_at")
			placeholders = append(placeholders, "?")
			args = append(args, time.Now().UTC().Format("20060102T150405Z"))

			_, err := database.DB.ExecContext(c.Context(),
				"INSERT INTO user_preferences ("+strings.Join(cols, ", ")+") VALUES ("+strings.Join(placeholders, ", ")+") ON CONFLICT(user_id) DO UPDATE SET "+strings.Join(setClauses, ", "),
				args...,
			)
			if err != nil {
				return c.Status(500).JSON(fiber.Map{"error": "failed to update preferences"})
			}
			updated = true
		}
	}

	if !updated {
		return c.Status(400).JSON(fiber.Map{"error": "no fields to update"})
	}

	// Return combined settings
	profileRows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM profiles WHERE id = ?", uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query profile"})
	}
	defer profileRows.Close()

	profile, err := scanOneRow(profileRows)
	if err != nil {
		profile = map[string]interface{}{}
	}

	prefRows, err := database.DB.QueryContext(c.Context(), "SELECT * FROM user_preferences WHERE user_id = ?", uid)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "failed to query preferences"})
	}
	defer prefRows.Close()

	prefs, err := scanOneRow(prefRows)
	if err != nil {
		prefs = map[string]interface{}{}
	}

	return c.JSON(fiber.Map{
		"account":     profile,
		"preferences": prefs,
	})
}
