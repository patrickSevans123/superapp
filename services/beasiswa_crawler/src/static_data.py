import json
import logging
from beasiswa_scraper.models import Scholarship
from beasiswa_scraper.config import DATA_DIR, PROJECT_ROOT as ROOT_DIR

log = logging.getLogger(__name__)


def _load_scholarships(filename: str, subdir: str | None = None) -> list[Scholarship]:
    base = DATA_DIR if subdir is None else ROOT_DIR
    path = base / filename
    if not path.exists():
        path = DATA_DIR / filename
    if not path.exists():
        log.warning("Data file not found: %s", path)
        return []
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        return [Scholarship(**item) for item in raw]
    except Exception as e:
        log.warning("Failed to load %s: %s", filename, e)
        return []


_STATIC_SCHOLARSHIPS: list[Scholarship] = _load_scholarships("scholarships_static.json")
_AGGREGATOR_SCHOLARSHIPS: list[Scholarship] = _load_scholarships("scholarships_aggregator.json")
_S2_FULLY_FUNDED: list[Scholarship] = _load_scholarships("scholarships_s2_fully_funded.json", subdir="root")
_S2_ASIA_EUROPE_AFRICA: list[Scholarship] = _load_scholarships("s2_scholarships_asia_europe_africa.json", subdir="root")
_S2_AMERICAS_OCEANIA: list[Scholarship] = _load_scholarships("s2_scholarships_americas_oceania.json", subdir="root")
