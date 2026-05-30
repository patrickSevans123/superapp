import json
import logging
from beasiswa_scraper.models import University, Program
from beasiswa_scraper.config import DATA_DIR

log = logging.getLogger(__name__)

UNIVERSITY_FILE = DATA_DIR / "universities_static.json"


def _load_all() -> list[University]:
    if not UNIVERSITY_FILE.exists():
        log.warning("University data file not found: %s", UNIVERSITY_FILE)
        return []
    try:
        raw = json.loads(UNIVERSITY_FILE.read_text(encoding="utf-8"))
        return [University(**item) for item in raw]
    except Exception as e:
        log.warning("Failed to load universities_static.json: %s", e)
        return []


_UNIVERSITIES: list[University] = _load_all()


def get_all() -> list[University]:
    return _UNIVERSITIES


def enrich_universities(items: list[University]) -> list[University]:
    for u in items:
        u.id = u.name.lower().replace(" ", "-").replace("(", "").replace(")", "")[:60]
        seen = set()
        deduped = []
        for p in u.programs:
            key = p.name.lower().strip()
            if key not in seen:
                seen.add(key)
                deduped.append(p)
        u.programs = deduped
    return items
