import json
import logging
from datetime import datetime
from beasiswa_scraper.models import Scholarship, University, CoverageDetail, _content_checksum
from beasiswa_scraper.config import DATA_DIR

log = logging.getLogger("beasiswa_scraper.storage")

DATA_FILE = DATA_DIR / "scholarships.json"
UNIVERSITY_FILE = DATA_DIR / "universities.json"


# ── Scholarship storage ──

def load() -> list[Scholarship]:
    if not DATA_FILE.exists():
        return []
    try:
        raw = json.loads(DATA_FILE.read_text(encoding="utf-8"))
        return [Scholarship(**item) for item in raw]
    except Exception as e:
        log.warning("Failed to load scholarships.json: %s", e)
        return []


def save(items: list[Scholarship]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    items = _ensure_ids_and_checksums(items)
    raw = [item.model_dump() for item in items]
    DATA_FILE.write_text(json.dumps(raw, indent=2, ensure_ascii=False), encoding="utf-8")


def _ensure_ids_and_checksums(items: list[Scholarship]) -> list[Scholarship]:
    for s in items:
        if not s.id:
            from beasiswa_scraper.models import _make_id
            s.id = _make_id(s.url, s.title, s.provider)
        s.checksum = _content_checksum(s)
    return items


def _recalc_checksums(items: list[Scholarship]) -> None:
    for s in items:
        s.checksum = _content_checksum(s)


# ── University storage ──

def load_universities() -> list[University]:
    if not UNIVERSITY_FILE.exists():
        return []
    try:
        raw = json.loads(UNIVERSITY_FILE.read_text(encoding="utf-8"))
        return [University(**item) for item in raw]
    except Exception as e:
        log.warning("Failed to load universities.json: %s", e)
        return []


def save_universities(items: list[University]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    raw = [item.model_dump() for item in items]
    UNIVERSITY_FILE.write_text(json.dumps(raw, indent=2, ensure_ascii=False), encoding="utf-8")


def merge_universities(existing: list[University], incoming: list[University]) -> list[University]:
    indexed: dict[str, University] = {}
    for u in existing:
        indexed[u.id] = u
    for u in incoming:
        if u.id in indexed:
            existing_u = indexed[u.id]
            existing_u.updated_at = u.updated_at
            if u.description and len(u.description) >= len(existing_u.description):
                existing_u.description = u.description
            if u.programs:
                existing_prog_names = {p.name for p in existing_u.programs}
                for p in u.programs:
                    if p.name not in existing_prog_names:
                        existing_u.programs.append(p)
            if u.application_requirements:
                existing_u.application_requirements = list(set(existing_u.application_requirements + u.application_requirements))
            if u.tips:
                existing_u.tips = list(dict.fromkeys(existing_u.tips + u.tips))
            if u.tags:
                existing_tags_lower = {t.lower() for t in existing_u.tags}
                for t in u.tags:
                    if t.lower() not in existing_tags_lower:
                        existing_u.tags.append(t)
        else:
            indexed[u.id] = u
    return list(indexed.values())


def merge(existing: list[Scholarship], incoming: list[Scholarship]) -> list[Scholarship]:
    _ensure_ids_and_checksums(incoming)
    indexed: dict[str, Scholarship] = {}
    for s in existing:
        indexed[s.id] = s
    for s in incoming:
        if s.id in indexed:
            existing_s = indexed[s.id]
            csum_changed = s.checksum != existing_s.checksum
            if csum_changed:
                existing_s.version += 1
            if s.deadline:
                existing_s.deadline = s.deadline
            if s.description and len(s.description) >= len(existing_s.description):
                existing_s.description = s.description
            if s.field_of_study:
                existing_s.field_of_study = s.field_of_study
            if s.funding_type:
                existing_s.funding_type = s.funding_type
            # always propagate derived fields
            if s.coverage_detail.model_dump() != CoverageDetail().model_dump():
                existing_s.coverage_detail = s.coverage_detail
            existing_s.requirements = s.requirements
            if s.tags:
                existing_tags_lower = {t.lower() for t in existing_s.tags}
                for t in s.tags:
                    if t.lower() not in existing_tags_lower:
                        existing_s.tags.append(t)
                        existing_tags_lower.add(t.lower())
            if csum_changed:
                existing_s.checksum = s.checksum
            existing_s.updated_at = datetime.now().isoformat()
        else:
            indexed[s.id] = s
    return list(indexed.values())
