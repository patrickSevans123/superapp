"""
Migrate scholarships from JSON to DuckDB.

Reads scholarships.json (~205 entries) and writes to
a DuckDB database with a typed schema.
"""

import json
import os
from datetime import datetime
from pathlib import Path

import duckdb


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
JSON_PATH = Path(
    r"C:\Users\patri\Documents\Individuel\beasiswa\data\scholarships.json"
)
DB_DIR = Path(
    r"C:\Users\patri\Documents\Individuel\superapp\services\beasiswa_crawler\data"
)
DB_PATH = DB_DIR / "scholarships.duckdb"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _str(val: object, default: str = "") -> str:
    """Return val if it is a non-empty string, else *default*."""
    if isinstance(val, str) and val:
        return val
    return default


def _list(val: object) -> list:
    """Return val if it is a list, else []."""
    return val if isinstance(val, list) else []


def _coverage_detail(d: dict | None) -> dict:
    """Return a flat dict of coverage_detail fields (or empty defaults)."""
    if not isinstance(d, dict):
        d = {}
    return {
        "cd_tuition": _str(d.get("tuition")),
        "cd_monthly_stipend": _str(d.get("monthly_stipend")),
        "cd_currency": _str(d.get("currency")),
        "cd_travel": _str(d.get("travel")),
        "cd_accommodation": _str(d.get("accommodation")),
        "cd_insurance": _str(d.get("insurance")),
        "cd_language_course": _str(d.get("language_course")),
        "cd_other": _list(d.get("other")),
    }


def _parse_dt(val: str | None) -> datetime | None:
    """Parse ISO‑8601 string -> datetime (or None if missing/invalid)."""
    if isinstance(val, str) and val.strip():
        try:
            return datetime.fromisoformat(val)
        except (ValueError, TypeError):
            return None
    return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    print(f"Reading scholarships from: {JSON_PATH}")
    with open(JSON_PATH, encoding="utf-8") as f:
        scholarships = json.load(f)

    print(f"Loaded {len(scholarships)} entries from JSON")

    # Remove existing database so we start fresh
    if DB_PATH.exists():
        DB_PATH.unlink()
        print(f"Removed existing database: {DB_PATH}")

    # Ensure output directory exists
    DB_DIR.mkdir(parents=True, exist_ok=True)

    # Connect (creates the database)
    conn = duckdb.connect(str(DB_PATH))
    conn.execute("PRAGMA enable_progress_bar;")

    # ------------------------------------------------------------------
    # Create table
    # ------------------------------------------------------------------
    conn.execute("""
        CREATE TABLE IF NOT EXISTS scholarships (
            id VARCHAR PRIMARY KEY,
            title VARCHAR NOT NULL,
            provider VARCHAR,
            description VARCHAR,
            "level" VARCHAR[],
            destination VARCHAR,
            country VARCHAR,
            coverage VARCHAR,
            cd_tuition VARCHAR,
            cd_monthly_stipend VARCHAR,
            cd_currency VARCHAR,
            cd_travel VARCHAR,
            cd_accommodation VARCHAR,
            cd_insurance VARCHAR,
            cd_language_course VARCHAR,
            cd_other VARCHAR[],
            deadline VARCHAR,
            opening_date VARCHAR,
            url VARCHAR,
            source_url VARCHAR,
            requirements VARCHAR[],
            field_of_study VARCHAR[],
            tags VARCHAR[],
            funding_type VARCHAR,
            tips VARCHAR[],
            version INTEGER DEFAULT 1,
            checksum VARCHAR,
            found_at TIMESTAMP,
            updated_at TIMESTAMP
        )
    """)

    # Print schema
    print("\n--- Table Schema ---")
    for row in conn.execute("DESCRIBE scholarships").fetchall():
        print(f"  {row[0]:25s} {row[1]}")
    print()

    # ------------------------------------------------------------------
    # Prepare rows for insertion
    # ------------------------------------------------------------------
    rows = []
    for s in scholarships:
        cd = _coverage_detail(s.get("coverage_detail"))
        rows.append((
            _str(s.get("id")),
            _str(s.get("title")),
            _str(s.get("provider")),
            _str(s.get("description")),
            _list(s.get("level")),
            _str(s.get("destination")),
            _str(s.get("country")),
            _str(s.get("coverage")),
            cd["cd_tuition"],
            cd["cd_monthly_stipend"],
            cd["cd_currency"],
            cd["cd_travel"],
            cd["cd_accommodation"],
            cd["cd_insurance"],
            cd["cd_language_course"],
            cd["cd_other"],
            _str(s.get("deadline")),
            _str(s.get("opening_date")),
            _str(s.get("url")),
            _str(s.get("source_url")),
            _list(s.get("requirements")),
            _list(s.get("field_of_study")),
            _list(s.get("tags")),
            _str(s.get("funding_type")),
            _list(s.get("tips")),
            s.get("version", 1) if isinstance(s.get("version"), int) else 1,
            _str(s.get("checksum")),
            _parse_dt(s.get("found_at")),
            _parse_dt(s.get("updated_at")),
        ))

    # ------------------------------------------------------------------
    # Insert using executemany
    # ------------------------------------------------------------------
    conn.executemany(
        """
        INSERT INTO scholarships VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?
        )
        """,
        rows,
    )

    # ------------------------------------------------------------------
    # Verify
    # ------------------------------------------------------------------
    count_row = conn.execute("SELECT COUNT(*) FROM scholarships").fetchone()
    count = count_row[0] if count_row else 0
    print(f"Loaded {count} scholarships into DuckDB")
    print(f"Database file: {DB_PATH} ({DB_PATH.stat().st_size:,} bytes)")

    print("\n--- Sample rows (id, title, country, funding_type) ---")
    sample = conn.execute(
        "SELECT id, title, country, funding_type FROM scholarships LIMIT 3"
    ).fetchall()
    for row in sample:
        print(f"  {row[0]:18s} | {row[1]:45s} | {str(row[2] or ''):12s} | {row[3]}")

    conn.close()
    print("\nMigration complete.")


if __name__ == "__main__":
    main()
