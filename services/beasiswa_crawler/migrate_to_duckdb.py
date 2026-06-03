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
# Paths default to the repo layout but can be overridden via env vars.
# Override examples:
#   JSON_PATH=/path/to/scholarships.json DB_PATH=/path/to/out.duckdb
DEFAULT_JSON_PATH = (
    Path(__file__).resolve().parents[3]  # superapp/ root
    / "data" / "scholarships.json"
)
DEFAULT_DB_DIR = Path(__file__).resolve().parents[1] / "data"  # services/beasiswa_crawler/data
DEFAULT_DB_PATH = DEFAULT_DB_DIR / "scholarships.duckdb"

JSON_PATH = Path(os.environ.get("BEASISWA_JSON_PATH", str(DEFAULT_JSON_PATH)))
DB_DIR = Path(os.environ.get("BEASISWA_DB_DIR", str(DEFAULT_DB_DIR)))
DB_PATH = DB_DIR / Path(os.environ.get("BEASISWA_DB_NAME", DEFAULT_DB_PATH.name)).name

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

    # Ensure output directory exists
    DB_DIR.mkdir(parents=True, exist_ok=True)

    # Connect (creates the database if it does not exist)
    conn = duckdb.connect(str(DB_PATH))
    conn.execute("PRAGMA enable_progress_bar;")

    # Idempotency guard: a migration_marker table is created on first run.
    # Re-running will skip the destructive DROP and preserve data.
    MIGRATION_MARKER_TABLE = "_migration_log"
    already_migrated = conn.execute(
        f"SELECT COUNT(*) FROM information_schema.tables "
        f"WHERE table_name = '{MIGRATION_MARKER_TABLE}'"
    ).fetchone()[0] > 0

    if already_migrated:
        print(f"Migration already completed previously; refreshing {len(scholarships)} rows via UPSERT")

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
    # Upsert rows (idempotent — safe to re-run)
    # ------------------------------------------------------------------
    conn.executemany(
        """
        INSERT INTO scholarships VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?
        )
        ON CONFLICT (id) DO UPDATE SET
            title = EXCLUDED.title,
            provider = EXCLUDED.provider,
            description = EXCLUDED.description,
            "level" = EXCLUDED."level",
            destination = EXCLUDED.destination,
            country = EXCLUDED.country,
            coverage = EXCLUDED.coverage,
            cd_tuition = EXCLUDED.cd_tuition,
            cd_monthly_stipend = EXCLUDED.cd_monthly_stipend,
            cd_currency = EXCLUDED.cd_currency,
            cd_travel = EXCLUDED.cd_travel,
            cd_accommodation = EXCLUDED.cd_accommodation,
            cd_insurance = EXCLUDED.cd_insurance,
            cd_language_course = EXCLUDED.cd_language_course,
            cd_other = EXCLUDED.cd_other,
            deadline = EXCLUDED.deadline,
            opening_date = EXCLUDED.opening_date,
            url = EXCLUDED.url,
            source_url = EXCLUDED.source_url,
            requirements = EXCLUDED.requirements,
            field_of_study = EXCLUDED.field_of_study,
            tags = EXCLUDED.tags,
            funding_type = EXCLUDED.funding_type,
            tips = EXCLUDED.tips,
            version = EXCLUDED.version,
            checksum = EXCLUDED.checksum,
            found_at = EXCLUDED.found_at,
            updated_at = EXCLUDED.updated_at
        """,
        rows,
    )

    # Mark migration complete (only on first run)
    if not already_migrated:
        conn.execute(
            f"CREATE TABLE {MIGRATION_MARKER_TABLE} ("
            f"  ran_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
            f"  source_json VARCHAR,"
            f"  row_count INTEGER"
            f")"
        )
        conn.execute(
            f"INSERT INTO {MIGRATION_MARKER_TABLE} (source_json, row_count) "
            f"VALUES (?, ?)",
            [str(JSON_PATH), len(scholarships)],
        )
        print(f"Created migration marker: {MIGRATION_MARKER_TABLE}")

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
    print(f"\nMigration complete ({'refreshed' if already_migrated else 'initial'} run).")


if __name__ == "__main__":
    main()
