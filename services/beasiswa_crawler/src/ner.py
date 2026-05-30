"""Named Entity Recognition for scholarship coverage text.

Uses spaCy's EntityRuler with custom patterns for English and Indonesian.
Detects benefit types, amounts, currencies, coverage levels, and periods.
"""

import re
import spacy
from spacy.language import Language

BENEFIT_TUITION = "BENEFIT_TUITION"
BENEFIT_STIPEND = "BENEFIT_STIPEND"
BENEFIT_TRAVEL = "BENEFIT_TRAVEL"
BENEFIT_ACCOMMODATION = "BENEFIT_ACCOMMODATION"
BENEFIT_INSURANCE = "BENEFIT_INSURANCE"
BENEFIT_LANGUAGE = "BENEFIT_LANGUAGE"
BENEFIT_OTHER = "BENEFIT_OTHER"
COVERAGE_FULL = "COVERAGE_FULL"
COVERAGE_PARTIAL = "COVERAGE_PARTIAL"
CURRENCY = "CURRENCY"
PERIOD = "PERIOD"

_currency_symbols = {
    "$": "USD", "\u20ac": "EUR", "\u00a3": "GBP", "\u00a5": "JPY",
    "\u20a9": "KRW", "\u20ba": "TRY", "\u20bd": "RUB", "\u20b9": "INR",
    "\u0e3f": "THB", "\u20ab": "VND",
}


def _build_nlp() -> Language:
    """Build spaCy pipeline with EntityRuler for scholarship entities."""
    nlp = spacy.blank("en")
    ruler = nlp.add_pipe("entity_ruler")

    patterns = []

    # ── Currency patterns (token-based) ──────────────────────
    currency_codes = [
        "USD", "EUR", "GBP", "JPY", "KRW", "NZD", "AUD", "CAD", "MYR", "SGD",
        "PLN", "TRY", "CHF", "SEK", "DKK", "NOK", "RM", "KWD", "CNY",
        "CZK", "RUB", "HUF", "BND", "RON", "INR", "BRL", "THB", "VND", "PKR",
        "KZT", "SAR", "AED", "QAR", "AZN", "IDR", "TWD", "HKD", "ZAR", "NGN",
        "EGP", "PEN", "MXN", "COP", "CLP", "ILS",
    ]
    for code in currency_codes:
        patterns.append({"label": CURRENCY, "pattern": [{"LOWER": code.lower()}]})
    for sym in _currency_symbols:
        patterns.append({"label": CURRENCY, "pattern": [{"ORTH": sym}]})

    # ── Coverage level ──────────────────────────────────────
    patterns.append({"label": COVERAGE_FULL, "pattern": [{"LOWER": {"IN": ["full", "fully", "bebas"]}}]})
    patterns.append({"label": COVERAGE_FULL, "pattern": [{"LOWER": "fully"}, {"LOWER": "funded"}]})
    patterns.append({"label": COVERAGE_FULL, "pattern": [{"LOWER": "full"}, {"LOWER": "tuition"}]})
    patterns.append({"label": COVERAGE_FULL, "pattern": [{"LOWER": "bebas"}, {"LOWER": "biaya"}, {"LOWER": "kuliah"}]})
    patterns.append({"label": COVERAGE_FULL, "pattern": [{"LOWER": "biaya"}, {"LOWER": "kuliah"}, {"LOWER": "penuh"}]})
    patterns.append({"label": COVERAGE_PARTIAL, "pattern": [{"LOWER": "partial"}]})
    patterns.append({"label": COVERAGE_PARTIAL, "pattern": [{"LOWER": "partial"}, {"LOWER": "to"}, {"LOWER": "full"}]})

    # ── Period ──────────────────────────────────────────────
    for word in ["monthly", "bulanan", "semester", "tahunan", "yearly", "annual", "mingguan", "weekly"]:
        patterns.append({"label": PERIOD, "pattern": [{"LOWER": word}]})
    patterns.append({"label": PERIOD, "pattern": [{"LOWER": "per"}, {"LOWER": "month"}]})
    patterns.append({"label": PERIOD, "pattern": [{"LOWER": "per"}, {"LOWER": "year"}]})
    patterns.append({"label": PERIOD, "pattern": [{"LOWER": "per"}, {"LOWER": "semester"}]})
    patterns.append({"label": PERIOD, "pattern": [{"LOWER": "per"}, {"LOWER": "bulan"}]})
    patterns.append({"label": PERIOD, "pattern": [{"LOWER": "per"}, {"LOWER": "tahun"}]})
    patterns.append({"label": PERIOD, "pattern": [{"LOWER": "per"}, {"LOWER": "minggu"}]})
    patterns.append({"label": PERIOD, "pattern": [{"LOWER": "per"}, {"LOWER": "week"}]})
    for tag in ["/month", "/year", "/bulan", "/tahun", "/minggu", "/week"]:
        patterns.append({"label": PERIOD, "pattern": [{"ORTH": tag}]})

    # ── Benefit: Tuition ────────────────────────────────────
    patterns.append({"label": BENEFIT_TUITION, "pattern": [{"LOWER": {"IN": ["tuition", "spp"]}}]})
    patterns.append({"label": BENEFIT_TUITION, "pattern": [{"LOWER": "biaya"}, {"LOWER": "kuliah"}]})
    patterns.append({"label": BENEFIT_TUITION, "pattern": [{"LOWER": "biaya"}, {"LOWER": "pendidikan"}]})
    patterns.append({"label": BENEFIT_TUITION, "pattern": [{"LOWER": "tuition"}, {"LOWER": "fee"}]})
    patterns.append({"label": BENEFIT_TUITION, "pattern": [{"LOWER": "tuition"}, {"LOWER": "reduction"}]})
    patterns.append({"label": BENEFIT_TUITION, "pattern": [{"LOWER": "tuition"}, {"LOWER": "discount"}]})
    patterns.append({"label": BENEFIT_TUITION, "pattern": [{"LOWER": "tuition"}, {"LOWER": "waiver"}]})
    patterns.append({"label": BENEFIT_TUITION, "pattern": [{"LOWER": "tuition"}, {"LOWER": "free"}]})
    patterns.append({"label": BENEFIT_TUITION, "pattern": [{"LOWER": "tuition"}, {"LOWER": "fee"}, {"LOWER": "waiver"}]})

    # ── Benefit: Stipend ────────────────────────────────────
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": {"IN": ["stipend", "stipened", "stipendnya", "tunjangan", "allowance"]}}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "living"}, {"LOWER": "cost"}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "living"}, {"LOWER": "costs"}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "living"}, {"LOWER": "allowance"}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "living"}, {"LOWER": "expense"}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "living"}, {"LOWER": "expenses"}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "biaya"}, {"LOWER": "hidup"}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "cost"}, {"LOWER": "of"}, {"LOWER": "living"}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "maintenance"}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "monthly"}, {"LOWER": "stipend"}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "monthly"}, {"LOWER": "allowance"}]})
    patterns.append({"label": BENEFIT_STIPEND, "pattern": [{"LOWER": "biaya"}, {"LOWER": "hidup"}, {"LOWER": "ditanggung"}]})

    # ── Benefit: Travel ─────────────────────────────────────
    for word in ["travel", "flights", "flight", "airfare", "relocation", "mobilitas", "visa", "subsistence", "transport"]:
        patterns.append({"label": BENEFIT_TRAVEL, "pattern": [{"LOWER": word}]})
    patterns.append({"label": BENEFIT_TRAVEL, "pattern": [{"LOWER": "tiket"}, {"LOWER": "pesawat"}]})
    patterns.append({"label": BENEFIT_TRAVEL, "pattern": [{"LOWER": "tiket"}, {"LOWER": "pp"}]})
    patterns.append({"label": BENEFIT_TRAVEL, "pattern": [{"LOWER": "biaya"}, {"LOWER": "perjalanan"}]})
    patterns.append({"label": BENEFIT_TRAVEL, "pattern": [{"LOWER": "arrival"}, {"LOWER": "allowance"}]})
    patterns.append({"label": BENEFIT_TRAVEL, "pattern": [{"LOWER": "baggage"}, {"LOWER": "allowance"}]})
    patterns.append({"label": BENEFIT_TRAVEL, "pattern": [{"LOWER": "settling"}, {"LOWER": "in"}]})
    patterns.append({"label": BENEFIT_TRAVEL, "pattern": [{"LOWER": "establishment"}, {"LOWER": "allowance"}]})
    patterns.append({"label": BENEFIT_TRAVEL, "pattern": [{"LOWER": "perjalanan"}]})

    # ── Benefit: Accommodation ──────────────────────────────
    for word in ["accommodation", "asrama", "akomodasi", "dormitory", "housing"]:
        patterns.append({"label": BENEFIT_ACCOMMODATION, "pattern": [{"LOWER": word}]})
    patterns.append({"label": BENEFIT_ACCOMMODATION, "pattern": [{"LOWER": "tempat"}, {"LOWER": "tinggal"}]})
    patterns.append({"label": BENEFIT_ACCOMMODATION, "pattern": [{"LOWER": "residence"}, {"LOWER": "support"}]})

    # ── Benefit: Insurance ──────────────────────────────────
    for word in ["insurance", "asuransi", "ihs"]:
        patterns.append({"label": BENEFIT_INSURANCE, "pattern": [{"LOWER": word}]})
    patterns.append({"label": BENEFIT_INSURANCE, "pattern": [{"LOWER": "health"}, {"LOWER": "cover"}]})
    patterns.append({"label": BENEFIT_INSURANCE, "pattern": [{"LOWER": "health"}, {"LOWER": "insurance"}]})
    patterns.append({"label": BENEFIT_INSURANCE, "pattern": [{"LOWER": "medical"}, {"LOWER": "insurance"}]})
    patterns.append({"label": BENEFIT_INSURANCE, "pattern": [{"LOWER": "asuransi"}, {"LOWER": "kesehatan"}]})
    patterns.append({"label": BENEFIT_INSURANCE, "pattern": [{"LOWER": "kesehatan"}]})

    # ── Benefit: Language course ────────────────────────────
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "language"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "language"}, {"LOWER": "training"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "language"}, {"LOWER": "program"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "language"}, {"LOWER": "class"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "korean"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "japanese"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "mandarin"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "chinese"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "german"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "french"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "spanish"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "turkish"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "slovak"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "arabic"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "english"}, {"LOWER": "training"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "english"}, {"LOWER": "course"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "english"}, {"LOWER": "program"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "english"}, {"LOWER": "class"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "bahasa"}, {"LOWER": "turki"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "bahasa"}, {"LOWER": "inggris"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "bahasa"}, {"LOWER": "jerman"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "bahasa"}, {"LOWER": "prancis"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "bahasa"}, {"LOWER": "jepang"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "bahasa"}, {"LOWER": "mandarin"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "bahasa"}, {"LOWER": "setempat"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "bahasa"}, {"LOWER": "lokal"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "bahasa"}, {"LOWER": "arab"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "dana"}, {"LOWER": "bahasa"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "bipa"}]})
    patterns.append({"label": BENEFIT_LANGUAGE, "pattern": [{"LOWER": "kursus"}, {"LOWER": "bahasa"}]})

    # ── Benefit: Other ──────────────────────────────────────
    for word in ["book", "buku", "thesis", "tesis", "disertasi", "dissertation", "laptop"]:
        patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": word}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "research"}, {"LOWER": "grant"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "research"}, {"LOWER": "funding"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "research"}, {"LOWER": "allowance"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "dana"}, {"LOWER": "penelitian"}]})
    for word in ["conference", "seminar", "workshop"]:
        patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": word}]})
    for word in ["publication", "publikasi"]:
        patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": word}]})
    for word in ["emergency", "darurat"]:
        patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": word}]})
    for word in ["training", "pelatihan"]:
        patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": word}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "professional"}, {"LOWER": "development"}]})
    for word in ["internship", "magang"]:
        patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": word}]})
    for word in ["certification", "sertifikat"]:
        patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": word}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "grant"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "incidental"}, {"LOWER": "fees"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "career"}, {"LOWER": "development"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "residence"}, {"LOWER": "permit"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "work"}, {"LOWER": "permit"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "visa"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "visa"}, {"LOWER": "fee"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "registration"}, {"LOWER": "fee"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "registration"}, {"LOWER": "cost"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "meal"}, {"LOWER": "allowance"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "baggage"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "uang"}, {"LOWER": "saku"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "biaya"}, {"LOWER": "riset"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "biaya"}, {"LOWER": "tesis"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "biaya"}, {"LOWER": "penelitian"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "dana"}, {"LOWER": "riset"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "family"}, {"LOWER": "allowance"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "pendaftaran"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "registrasi"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "installation"}]})
    patterns.append({"label": BENEFIT_OTHER, "pattern": [{"LOWER": "study"}, {"LOWER": "allowance"}]})

    ruler.add_patterns(patterns)
    return nlp


class ScholarshipNER:
    """NER-based coverage detail parser using spaCy EntityRuler."""

    def __init__(self):
        self._nlp = _build_nlp()

    def extract_entities(self, text: str) -> dict:
        """Extract NER entities from coverage text.

        Returns dict with entity types as keys and lists of (text, start_char, end_char) as values.
        """
        doc = self._nlp(text)
        result = {}
        for ent in doc.ents:
            label = ent.label_
            if label not in result:
                result[label] = []
            result[label].append((ent.text, ent.start_char, ent.end_char))
        return result

    def detect_tuition(self, text: str) -> str | None:
        """Detect tuition coverage level."""
        cl = text.lower()
        entities = self.extract_entities(cl)

        has_partial = COVERAGE_PARTIAL in entities
        has_full = COVERAGE_FULL in entities
        has_tuition = BENEFIT_TUITION in entities

        # Partial: "partial tuition" or "tuition reduction/discount"
        if has_partial and has_tuition:
            return "Partial"
        # Direct tuition reduction/discount keywords
        if re.search(r'(partial.*tuition|tuition.*(reduction|discount)|potongan.*biaya|diskon.*kuliah|top.up)', cl):
            return "Partial"
        # Full: "full tuition", "bebas biaya kuliah", "Full:" prefix
        if (has_full and has_tuition) or re.search(r'(bebas\s+biaya\s+kuliah|full.*tuition)', cl):
            return "Full"
        if cl.startswith("full") or cl.startswith("fully"):
            return "Full"
        return None

    def detect_currency(self, text: str) -> str | None:
        """Detect currency from text using NER patterns."""
        entities = self.extract_entities(text)
        if CURRENCY in entities:
            for ent_text, _, _ in entities[CURRENCY]:
                if ent_text in _currency_symbols:
                    return _currency_symbols[ent_text]
                if len(ent_text) <= 4 and ent_text.isalpha():
                    return ent_text.upper()
        return None

    def _extract_amount_near(self, text: str, position: int, window: int = 80) -> str | None:
        """Find the best numeric amount near a given character position.
        Prefers amounts with multiplier context (juta/jt) or currency suffix,
        and demotes amounts preceded by 'total' (budget totals, not per-person).
        """
        best: tuple[int, str] | None = None  # (score, result)
        for m in re.finditer(r'\d{1,3}(?:[\s,.]\d{3})*(?:[\s,.]\d+)?', text):
            if m.start() > 0 and text[m.start() - 1].isalpha():
                continue
            d = abs(m.start() - position)
            if d > window:
                continue
            after = text[m.end():m.end() + 12]
            if re.match(r'[\s,\-–]*%', after):
                continue
            score = d
            mm = re.match(r'\s*(juta|jt|ribu|rb)\b', after, re.IGNORECASE)
            if mm:
                mul = {"juta": 1_000_000, "jt": 1_000_000, "ribu": 1_000, "rb": 1_000}.get(mm.group(1).lower(), 1)
                raw = int(re.sub(r'[^\d]', '', m.group()))
                val = raw * mul
                result = f"{val:,}".replace(",", "")
                score -= 200
            elif re.match(r'\s*[A-Z]{3}\b', after):
                result = m.group().strip()
                score -= 100
            else:
                result = m.group().strip()
            before = text[max(0, m.start() - 30):m.start()].lower()
            if re.search(r'\btotal\b', before):
                score += 50
            if best is None or score < best[0]:
                best = (score, result)
        return best[1] if best else None

    def _extract_any_amount(self, text: str) -> str | None:
        """Find any numeric amount with stipend-context."""
        for m in re.finditer(r'\d{1,3}(?:[\s,.]\d{3})*(?:[\s,.]\d+)?', text):
            if m.start() > 0 and text[m.start() - 1].isalpha():
                continue
            after = text[m.end():m.end() + 12]
            if re.match(r'[\s,\-–]*%', after):
                continue
            ctx = text[max(0, m.start() - 80): m.end() + 80].lower()
            if re.search(r'(annual|/year\b|per\s*year|/tahun\b|per\s*tahun|yearly|a\s*year)', ctx):
                if not re.search(r'(monthly|/month\b|per\s*month|/bulan\b|per\s*bulan|bulanan)', ctx):
                    if not re.search(r'(fee\s*waiver|tuition\s*waiver|top.?up)', ctx):
                        continue
            if re.search(r'(stip[ae]nd?|allowance|tunjangan|living|biaya\s+hidup|maintenance|monthly|per\s*month)', ctx):
                mm = re.match(r'\s*(juta|jt|ribu|rb)\b', after, re.IGNORECASE)
                if mm:
                    mul = {"juta": 1_000_000, "jt": 1_000_000, "ribu": 1_000, "rb": 1_000}.get(mm.group(1).lower(), 1)
                    raw = int(re.sub(r'[^\d]', '', m.group()))
                    val = raw * mul
                    return f"{val:,}".replace(",", "")
                return m.group().strip()
        return None

    def _any_stipend_not_negated(self, text: str) -> bool:
        """Return True if any stipend keyword appears without a preceding negation phrase (within 60 chars)."""
        cl = text.lower()
        stipend_kws = r'(biaya\s+hidup|living\s*(cost|allowance|expense|stipend)?|stipend|tunjangan|allowance|cost\s+of\s+living|maintenance)'
        for m in re.finditer(stipend_kws, cl):
            before = cl[max(0, m.start() - 60):m.start()]
            if not re.search(r'tidak\s*(termasuk|mencakup)|not\s*include|not\s*covered|excluded|dikecualikan', before):
                return True
        return False

    def detect_stipend(self, text: str) -> str | None:
        """Extract monthly stipend amount or detect 'Included'."""
        cl = text.lower()

        # If ALL stipend keywords are negated, return None
        if not self._any_stipend_not_negated(text):
            return None

        entities = self.extract_entities(cl)

        has_stipend = BENEFIT_STIPEND in entities
        has_fee_waiver = bool(re.search(r'(fee\s*waiver|tuition\s*waiver|top.?up)', cl))

        if not has_stipend and not has_fee_waiver:
            # Check standalone "living" not followed by "only" via regex
            if re.search(r'\bliving\b(?!\s+only)', cl):
                has_stipend = True
            if not has_stipend and not has_fee_waiver:
                return None

        # Strategy 1: amount near a stipend entity
        if has_stipend and BENEFIT_STIPEND in entities:
            for _, start, end in entities[BENEFIT_STIPEND]:
                mid = (start + end) // 2
                amt = self._extract_amount_near(text, mid, window=120)
                if amt:
                    return amt

        # Strategy 2: amount with any stipend keyword in context
        amt = self._extract_any_amount(text)
        if amt:
            return amt

        # Strategy 3: amount near fee waiver
        if has_fee_waiver:
            for m in re.finditer(r'(fee\s*waiver|tuition\s*waiver|top.?up)', cl):
                amt = self._extract_amount_near(text, m.start(), window=120)
                if amt:
                    return amt

        return "Included"

    def detect_travel(self, text: str) -> bool:
        entities = self.extract_entities(text.lower())
        return BENEFIT_TRAVEL in entities

    def detect_accommodation(self, text: str) -> bool:
        entities = self.extract_entities(text.lower())
        return BENEFIT_ACCOMMODATION in entities

    def detect_insurance(self, text: str) -> bool:
        entities = self.extract_entities(text.lower())
        return BENEFIT_INSURANCE in entities

    def detect_language_course(self, text: str) -> bool:
        entities = self.extract_entities(text.lower())
        has_lang = BENEFIT_LANGUAGE in entities
        if not has_lang:
            return False
        cl = text.lower()
        if re.search(r'language\s*(proficiency|requirement|test|score|exam|certificate)', cl):
            return False
        if re.search(r'english\s*(proficiency|requirement|test|score)', cl):
            return False
        # "program inggris" = English program, not language course
        if re.search(r'program\s+inggris', cl):
            return False
        return True

    def _other_amount(self, text: str, pos: int, window: int = 60) -> str | None:
        for m in re.finditer(r'[\$\u20ac\u00a3\u00a5]?\s*(\d{1,3}(?:[\s,.]\d{3})*(?:[\s,.]\d+)?)\s*(?:EUR|USD|GBP|JPY|KRW|AUD|NZD|CAD|MYR|SGD|IDR|THB|VND|PKR|EGP|TRY|SAR|CNY|INR)?', text.lower()):
            if abs(m.start() - pos) <= window:
                return m.group().strip()
        return None

    def detect_other(self, text: str) -> list[str]:
        cl = text.lower()
        entities = self.extract_entities(cl)

        seen = set()
        results = []

        if BENEFIT_OTHER in entities:
            labels = {
            "book": "Book & research allowance",
            "buku": "Book & research allowance",
            "thesis": "Thesis allowance",
            "tesis": "Thesis allowance",
            "disertasi": "Thesis allowance",
            "dissertation": "Thesis allowance",
            "laptop": "Laptop/equipment",
            "research grant": "Book & research allowance",
            "research funding": "Book & research allowance",
            "research allowance": "Book & research allowance",
            "dana penelitian": "Book & research allowance",
            "dana riset": "Book & research allowance",
            "biaya riset": "Thesis allowance",
            "biaya tesis": "Thesis allowance",
            "biaya penelitian": "Thesis allowance",
            "conference": "Conference funding",
            "seminar": "Conference funding",
            "workshop": "Conference funding",
            "publication": "Publication funding",
            "publikasi": "Publication funding",
            "emergency": "Emergency fund",
            "darurat": "Emergency fund",
            "training": "Training & development",
            "pelatihan": "Training & development",
            "professional development": "Training & development",
            "internship": "Internship / practicum",
            "magang": "Internship / practicum",
            "certification": "Certification fees",
            "sertifikat": "Certification fees",
            "incidental fees": "Incidental fees",
            "career development": "Career development",
            "residence permit": "Residence/work permit",
            "work permit": "Residence/work permit",
            "visa": "Visa fee covered",
            "visa fee": "Visa fee covered",
            "registration fee": "Registration fee",
            "registration cost": "Registration fee",
            "meal allowance": "Meal allowance",
            "baggage": "Baggage allowance",
            "grant": "Grant funding",
            "uang saku": "Living allowance",
            "family allowance": "Family allowance",
            "pendaftaran": "Registration fee",
            "registrasi": "Registration fee",
            "installation": "Relocation allowance",
            "study allowance": "Book & research allowance",
        }

            for ent_text, ent_start, ent_end in entities[BENEFIT_OTHER]:
                for label_text in sorted(labels.keys(), key=len, reverse=True):
                    if label_text in ent_text:
                        mapped = labels[label_text]
                        if mapped == "Registration fee" and re.search(r'pendaftaran\s+online', cl):
                            break
                        if mapped not in seen:
                            seen.add(mapped)
                            amt = self._other_amount(cl, ent_start)
                            entry = f"{mapped} ({amt})" if amt else mapped
                            results.append(entry)
                        break

        # Post-processing: standalone "research" as a listed benefit
        if "Book & research allowance" not in seen:
            if re.search(r'\bresearch\b', cl):
                if not re.search(r'(?:or\s+|atau\s+)?research\s+only|research\s+(grant|funding|allowance|proposal|project|work|stay|assistant|fellowship|training|scholarship|program|institute|center|group|area|field|topic)', cl):
                    context_before = re.split(r'\bresearch\b', cl)[0]
                    if re.search(r'[,+]\s*$', context_before.strip()) or context_before.strip() == '':
                        results.append("Book & research allowance")

        return results

    def _entity_type_negated(self, text: str, entity_type: str) -> bool:
        """Return True if ALL entities of the given type appear only after a negation phrase (within 60 chars)."""
        cl = text.lower()
        entities = self.extract_entities(cl)
        if entity_type not in entities:
            return False
        for _, start, end in entities[entity_type]:
            before = cl[max(0, start - 60):start]
            if not re.search(r'tidak\s*(termasuk|mencakup)|not\s*include|not\s*covered|excluded|dikecualikan', before):
                return False
        return True

    def parse(self, text: str) -> dict:
        """Parse coverage text into structured fields.

        Returns dict with keys: tuition, monthly_stipend, currency, travel,
        accommodation, insurance, language_course, other.
        """
        result = {}

        tuition = self.detect_tuition(text)
        if tuition:
            result["tuition"] = tuition

        currency = self.detect_currency(text)
        if currency:
            result["currency"] = currency

        stipend = self.detect_stipend(text)
        if stipend:
            result["monthly_stipend"] = stipend

        if self.detect_travel(text):
            travel_negated = self._entity_type_negated(text, BENEFIT_TRAVEL)
            if not travel_negated:
                result["travel"] = "Covered"

        if self.detect_accommodation(text):
            accom_negated = self._entity_type_negated(text, BENEFIT_ACCOMMODATION)
            if not accom_negated:
                result["accommodation"] = "Covered"

        if self.detect_insurance(text):
            ins_negated = self._entity_type_negated(text, BENEFIT_INSURANCE)
            if not ins_negated:
                result["insurance"] = "Covered"

        if self.detect_language_course(text):
            lang_negated = self._entity_type_negated(text, BENEFIT_LANGUAGE)
            if not lang_negated:
                result["language_course"] = "Covered"

        others = self.detect_other(text)
        if others:
            result["other"] = others

        return result


# Singleton for reuse
_ner: ScholarshipNER | None = None


def get_ner() -> ScholarshipNER:
    global _ner
    if _ner is None:
        _ner = ScholarshipNER()
    return _ner


def parse_coverage_detail_with_ner(text: str) -> dict:
    """Parse coverage text using NER, returning field dict."""
    ner = get_ner()
    return ner.parse(text)
