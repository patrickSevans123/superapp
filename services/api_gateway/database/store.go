package database

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "modernc.org/sqlite"
)

// DB is the global SQLite database connection.
var DB *sql.DB

// Init opens (or creates) the SQLite database at dbPath and verifies connectivity.
func Init(dbPath string) error {
	var err error
	DB, err = sql.Open("sqlite", dbPath)
	if err != nil {
		return fmt.Errorf("open sqlite: %w", err)
	}

	// Multiple conns are safe with WAL mode for reads; writes still serialize.
	// 5 conns gives a small concurrent-read pool without contention on writes.
	DB.SetMaxOpenConns(5)
	DB.SetMaxIdleConns(5)
	DB.SetConnMaxIdleTime(5 * time.Minute)

	// WAL mode for better concurrent reads
	if _, err := DB.Exec("PRAGMA journal_mode=WAL"); err != nil {
		log.Printf("WARN: failed to set WAL mode: %v", err)
	}

	// Enable foreign keys
	if _, err := DB.Exec("PRAGMA foreign_keys=ON"); err != nil {
		log.Printf("WARN: failed to enable foreign keys: %v", err)
	}

	if err = DB.Ping(); err != nil {
		return fmt.Errorf("ping sqlite: %w", err)
	}

	log.Printf("SQLite database opened at %s", dbPath)
	return nil
}

// RunMigrations creates all required tables and indexes if they don't exist.
func RunMigrations() error {
	migrations := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id TEXT PRIMARY KEY,
			email TEXT NOT NULL UNIQUE,
			password_hash TEXT NOT NULL,
			display_name TEXT,
			created_at TEXT DEFAULT (strftime('%Y%m%dT%H%M%SZ', 'now'))
		)`,
		`CREATE TABLE IF NOT EXISTS profiles (
			id TEXT PRIMARY KEY,
			email TEXT,
			display_name TEXT,
			avatar_url TEXT,
			is_premium INTEGER DEFAULT 0,
			created_at TEXT DEFAULT (strftime('%Y%m%dT%H%M%SZ', 'now'))
		)`,
		`CREATE TABLE IF NOT EXISTS user_preferences (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL UNIQUE,
			tp_hit INTEGER DEFAULT 1,
			sl_hit INTEGER DEFAULT 1,
			price_alert INTEGER DEFAULT 1,
			msci_announce INTEGER DEFAULT 1,
			ftse_notice INTEGER DEFAULT 1,
			new_report INTEGER DEFAULT 1,
			plan_created INTEGER DEFAULT 1,
			scholarship_alert INTEGER DEFAULT 1,
			fashion_alert INTEGER DEFAULT 1,
			created_at TEXT DEFAULT (strftime('%Y%m%dT%H%M%SZ', 'now'))
		)`,
		`CREATE TABLE IF NOT EXISTS clothing_items (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			name TEXT NOT NULL,
			category TEXT,
			brand TEXT,
			cost REAL,
			times_worn INTEGER DEFAULT 0,
			last_worn_at TEXT,
			dominant_colors TEXT,
			season_tags TEXT,
			original_image_url TEXT,
			processed_image_url TEXT,
			created_at TEXT DEFAULT (strftime('%Y%m%dT%H%M%SZ', 'now')),
			updated_at TEXT
		)`,
		`CREATE TABLE IF NOT EXISTS tryon_results (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			clothing_item_id TEXT,
			person_image_url TEXT,
			result_image_url TEXT,
			status TEXT DEFAULT 'queued',
			fashn_job_id TEXT,
			created_at TEXT DEFAULT (strftime('%Y%m%dT%H%M%SZ', 'now'))
		)`,
		`CREATE TABLE IF NOT EXISTS tryon_queue (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			clothing_item_id TEXT,
			fashn_job_id TEXT,
			status TEXT DEFAULT 'queued',
			error_message TEXT,
			created_at TEXT DEFAULT (strftime('%Y%m%dT%H%M%SZ', 'now'))
		)`,
		`CREATE TABLE IF NOT EXISTS ootd_logs (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			outfit TEXT,
			weather_snapshot TEXT,
			suggested_at TEXT,
			created_at TEXT DEFAULT (strftime('%Y%m%dT%H%M%SZ', 'now'))
		)`,
		`CREATE TABLE IF NOT EXISTS saved_scholarships (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			scholarship_id TEXT NOT NULL,
			notes TEXT,
			deadline TEXT,
			status TEXT DEFAULT 'interested',
			created_at TEXT DEFAULT (strftime('%Y%m%dT%H%M%SZ', 'now'))
		)`,
		// JWT token blacklist (revoked tokens before expiry)
		`CREATE TABLE IF NOT EXISTS token_blacklist (
			jti TEXT PRIMARY KEY,
			expires_at TEXT NOT NULL,
			revoked_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
		)`,
		`CREATE INDEX IF NOT EXISTS idx_token_blacklist_expires ON token_blacklist(expires_at)`,
		// Indexes
		`CREATE INDEX IF NOT EXISTS idx_clothing_items_user ON clothing_items(user_id)`,
		`CREATE INDEX IF NOT EXISTS idx_clothing_items_category ON clothing_items(category)`,
		`CREATE INDEX IF NOT EXISTS idx_tryon_results_user ON tryon_results(user_id)`,
		`CREATE INDEX IF NOT EXISTS idx_ootd_logs_user ON ootd_logs(user_id)`,
		`CREATE INDEX IF NOT EXISTS idx_saved_scholarships_user ON saved_scholarships(user_id)`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_saved_scholarships_user_scholarship ON saved_scholarships(user_id, scholarship_id)`,
		`CREATE INDEX IF NOT EXISTS idx_user_preferences_user ON user_preferences(user_id)`,
	}

	for _, m := range migrations {
		if _, err := DB.Exec(m); err != nil {
			return fmt.Errorf("migration failed: %w\nSQL: %s", err, m)
		}
	}

	log.Println("SQLite migrations completed successfully")
	return nil
}
