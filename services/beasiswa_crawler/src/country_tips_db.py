import json
import logging
from dataclasses import dataclass, field

from beasiswa_scraper.config import DATA_DIR

log = logging.getLogger(__name__)

TIPS_FILE = DATA_DIR / "country_tips.json"


@dataclass
class CountryTips:
    overview: str
    visa_tips: list[str] = field(default_factory=list)
    scholarship_tips: list[str] = field(default_factory=list)
    cost_of_living: str = ""
    work_rules: str = ""
    cultural_tips: list[str] = field(default_factory=list)
    language_tips: str = ""
    housing_tips: list[str] = field(default_factory=list)
    general_tips: list[str] = field(default_factory=list)


def _load_tips() -> dict[str, CountryTips]:
    if not TIPS_FILE.exists():
        log.warning("Country tips file not found: %s", TIPS_FILE)
        return {}
    try:
        raw = json.loads(TIPS_FILE.read_text(encoding="utf-8"))
        result = {}
        for country, data in raw.items():
            result[country] = CountryTips(**data)
        return result
    except Exception as e:
        log.warning("Failed to load country_tips.json: %s", e)
        return {}


_COUNTRY_TIPS: dict[str, CountryTips] = _load_tips()


def get_all_country_tips() -> dict[str, CountryTips]:
    return _COUNTRY_TIPS


def get_country_tips(country: str) -> CountryTips | None:
    return _COUNTRY_TIPS.get(country)
