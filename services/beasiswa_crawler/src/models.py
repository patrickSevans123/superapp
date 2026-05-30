import hashlib
import json
from datetime import datetime
from pydantic import BaseModel, Field, field_validator


def _make_id(url: str, title: str, provider: str) -> str:
    raw = f"{url}::{title}::{provider}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


class CoverageDetail(BaseModel):
    tuition: str = ""
    monthly_stipend: str = ""
    currency: str = ""
    travel: str = ""
    accommodation: str = ""
    insurance: str = ""
    language_course: str = ""
    other: list[str] = Field(default_factory=list)


def _content_checksum(s: "Scholarship") -> str:
    raw = json.dumps({
        "title": s.title,
        "provider": s.provider,
        "description": s.description,
        "level": s.level,
        "destination": s.destination,
        "coverage": s.coverage,
        "deadline": s.deadline,
        "opening_date": s.opening_date,
        "url": s.url,
        "source_url": s.source_url,
        "country": s.country,
        "field_of_study": s.field_of_study,
        "tags": s.tags,
        "funding_type": s.funding_type,
        "tips": s.tips,
        "requirements": s.requirements,
    }, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


class Scholarship(BaseModel):
    id: str = ""
    title: str
    provider: str
    description: str = ""
    level: list[str] = Field(default_factory=list)
    destination: str = ""
    coverage: str = ""
    coverage_detail: CoverageDetail = Field(default_factory=CoverageDetail)
    deadline: str = ""
    opening_date: str = ""
    url: str = ""
    source_url: str = ""
    country: str = ""
    requirements: list[str] = Field(default_factory=list)
    field_of_study: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    funding_type: str = ""
    tips: list[str] = Field(default_factory=list)
    version: int = 1
    checksum: str = ""
    found_at: str = Field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = Field(default_factory=lambda: datetime.now().isoformat())

    @field_validator("field_of_study", mode="before")
    @classmethod
    def _coerce_field_of_study(cls, v):
        if isinstance(v, str):
            return [v]
        return v

    def model_post_init(self, __context):
        if not self.id:
            self.id = _make_id(self.url, self.title, self.provider)
        if not self.checksum:
            self.checksum = _content_checksum(self)


class Program(BaseModel):
    name: str
    degree: str = "S2"
    description: str = ""
    language: str = ""
    duration: str = ""
    tuition_fee: str = ""
    application_fee: str = ""
    intake: list[str] = Field(default_factory=list)
    department: str = ""
    field: str = ""
    url: str = ""
    scholarship_ids: list[str] = Field(default_factory=list)


class University(BaseModel):
    id: str = ""
    name: str
    country: str
    city: str = ""
    ranking: int = 0
    description: str = ""
    website: str = ""
    application_portal: str = ""
    intake_months: list[str] = Field(default_factory=list)
    language_requirements: str = ""
    avg_tuition_s2: str = ""
    application_requirements: list[str] = Field(default_factory=list)
    documents_needed: list[str] = Field(default_factory=list)
    application_steps: list[str] = Field(default_factory=list)
    tips: list[str] = Field(default_factory=list)
    programs: list[Program] = Field(default_factory=list)
    faq: list[dict[str, str]] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    version: int = 1
    checksum: str = ""
    found_at: str = Field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = Field(default_factory=lambda: datetime.now().isoformat())

    def model_post_init(self, __context):
        if not self.id:
            raw = f"{self.name}::{self.country}"
            self.id = hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]
