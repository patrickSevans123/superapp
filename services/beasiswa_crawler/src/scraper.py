import re
import logging
from datetime import datetime

from beasiswa_scraper.models import Scholarship, CoverageDetail, _content_checksum
from beasiswa_scraper.static_data import (
    _STATIC_SCHOLARSHIPS,
    _AGGREGATOR_SCHOLARSHIPS,
    _S2_FULLY_FUNDED,
    _S2_ASIA_EUROPE_AFRICA,
    _S2_AMERICAS_OCEANIA,
)
from beasiswa_scraper.ner import get_ner
from beasiswa_scraper.llm_enrich import enrich

log = logging.getLogger(__name__)


_DEADLINE_FALLBACKS: dict[str, str] = {
    "Beasiswa Unggulan": "Maret-April 2026 (perkiraan  -  cek website resmi)",
    "Quaid-e-Azam": "Juni-Juli 2026 (perkiraan)",
    "KOICA": "Februari-Maret 2026 (perkiraan  -  cek website resmi)",
    "Aga Khan Foundation": "Maret 2026 (perkiraan)",
    "Italian Government": "Mei-Juni 2026 (perkiraan  -  cek MAECI)",
    "Norwegian Government": "Maret 2026 (perkiraan  -  cek SIU)",
    "Austria Government": "Maret 2026 (perkiraan  -  cek OeAD)",
    "KAIST Scholarship": "Varies (check university deadlines  -  biasanya April-Oktober)",
    "Konrad-Adenauer": "Juli 2026 (perkiraan)",
    "Emile Boutmy": "Februari 2026 (perkiraan)",
    "Belgium ARES": "Oktober 2026 (perkiraan)",
    "Czech Government": "September 2026 (perkiraan  -  cek MSMT)",
    "Finland Government": "September 2026 (perkiraan  -  cek EDUFI)",
    "Spain Government": "Mei 2026 (perkiraan  -  cek AECID)",
    "Ireland Government": "Maret 2026 (perkiraan  -  cek HEA)",
    "Portugal Government": "April 2026 (perkiraan  -  cek FCT)",
    "Slovak Government": "Oktober 2026 (perkiraan  -  cek SAIA)",
    "KNB Scholarship": "Maret-Juni 2026 (perkiraan  -  cek KNB)",
    "CERN Administrative": "Varies (rolling  -  cek careers.cern)",
    "KAAD Scholarship": "Juni 2026 (perkiraan)",
    "Yale University": "Varies (need-based, rolling  -  cek Yale financial aid)",
    "MIT Need-Based": "Varies (need-based, rolling  -  cek MIT SFS)",
    "Harvard Financial": "Varies (need-based, rolling  -  cek Harvard financial aid)",
    "University of Sydney": "Varies (research scholarship  -  cek USydIS)",
    "Griffith University": "Varies (research scholarship  -  cek Griffith)",
    "University of Auckland": "Varies (merit-based  -  cek University of Auckland)",
    "SEARCA": "Oktober 2026 (perkiraan  -  cek SEARCA)",
    "Monash University Indonesia": "Varies (rolling  -  cek Monash Indonesia)",
    "Beasiswa BRIN": "Varies (cek BRIN untuk jadwal terbaru)",
    "DAAD-ACEH": "Varies (cek DAAD Indonesia)",
    "DAAD STEM": "Juni-Agustus 2026 (untuk winter semester 26/27)",
    "Orange Tulip": "Februari 2027 (perkiraan  -  cek Nuffic Neso)",
    "Bocconi University": "Varies (merit-based  -  cek Bocconi)",
    "Beasiswa S2 Universitas Pertahanan": "Varies (cek UNHAN)",
    "DAAD Study Scholarship": "Agustus 2026 (perkiraan  -  cek DAAD)",
    "Shanghai University": "Varies (cek Shanghai University)",
    "UNESCO-China": "April 2026 (perkiraan  -  cek UNESCO)",
    "China-AUN": "Maret 2026 (perkiraan  -  cek CSC)",
    "Eric Bleumink": "Desember 2026 (perkiraan  -  cek University of Groningen)",
    "Brunei Darussalam": "Februari 2027 (perkiraan  -  cek MFA Brunei)",
    "Royal Thai Government": "Mei 2026 (perkiraan  -  cek TICA)",
    "NUS Research": "Varies (rolling  -  cek NUS)",
    "NTU Research": "Varies (rolling  -  cek NTU)",
    "A*STAR Graduate": "Varies (rolling  -  cek A*STAR)",
    "Beasiswa Kominfo": "Varies (cek Kominfo)",
    "Beasiswa Indonesia Maju": "Varies (cek Puslapdik)",
    "The Indonesian AID": "Varies (cek TIAS)",
    "StuNed": "Maret 2026 (perkiraan  -  cek Nuffic Neso)",
    "Cultural Heritage": "Maret 2026 (perkiraan  -  cek Nuffic)",
    "Danish Government": "Varies (cek Study in Denmark)",
    "UNIL Master's": "Varies (cek UNIL)",
    "TU Delft Excellence": "Februari 2026 (perkiraan  -  cek TU Delft)",
    "Lund University": "Januari 2026 (perkiraan  -  cek Lund University)",
    "University of Amsterdam": "Januari 2026 (perkiraan  -  cek UvA)",
    "University of Helsinki": "Januari 2026 (perkiraan  -  cek Helsinki)",
    "OFID Scholarship": "Mei 2026 (perkiraan  -  cek OFID/OPEC Fund)",
    "Developing Solutions": "Maret 2026 (perkiraan  -  cek Nottingham)",
    "Allan & Nesta Ferguson": "April 2026 (perkiraan  -  cek Sheffield)",
    "Queen Elizabeth Commonwealth": "Varies (cek ACU)",
    "Scottish Government": "April 2026 (perkiraan  -  cek Scottish Government)",
    "Friedrich Ebert": "Juni 2026 (perkiraan  -  cek FES)",
    "Rosa Luxemburg": "Juni 2026 (perkiraan  -  cek Rosa Luxemburg)",
    "ARES Scholarship (Belgium)": "Oktober 2026 (perkiraan  -  cek ARES)",
    "VinUniversity": "Varies (cek VinUniversity)",
    "King AbdulAziz": "Varies (cek KAU)",
    "Sabanci University": "Varies (rolling  -  cek Sabanci)",
    "UAE University": "Varies (cek UAEU)",
    "University of Lausanne UNIL Master's Grant": "Varies (cek UNIL)",
    "LPDP PTUD": "Varies  -  pantau lpdp.kemenkeu.go.id",
    "LPDP - IE University": "Varies  -  pantau lpdp.kemenkeu.go.id",
    "LPDP-Australia Awards": "Varies  -  pantau lpdp.kemenkeu.go.id",
    "LPDP-Netherlands": "Varies  -  pantau lpdp.kemenkeu.go.id",
    "Beasiswa PMDSU": "Varies (cek Dikti)",
    "Beasiswa Professor Azyumardi": "Varies (cek STF UIN Jakarta)",
    "National Science Scholarship": "Varies (cek A*STAR)",
    "UCL Global Undergraduate": "Varies (cek UCL)",
    "GREAT Scholarship": "Mei 2026 (perkiraan  -  cek British Council)",
    "Transform Together": "Varies (cek Sheffield Hallam)",
    "Bolashak International": "Varies (cek Bolashak)",
    "Boustany Foundation": "Varies (cek Boustany Foundation)",
    "Melbourne International": "Varies (cek University of Melbourne)",
    "Deakin Vice-Chancellor": "Varies (cek Deakin University)",
    "Charles Darwin Global Merit": "Varies (cek CDU)",
    "Fulbright FLTA": "Varies (cek AMINEF)",
    "Graduate Studies Fellowship": "Varies (cek institusi Kanada)",
    "Beasiswa Orebro University": "Varies (cek Orebro University)",
}

_COUNTRY_SPECIFIC_TIPS: dict[str, list[str]] = {
    "Jerman": [
        "DAAD adalah beasiswa paling populer — daftar jauh-jauh hari, deadline Okt-Nov",
        "Jangan hanya apply DAAD — coba juga KAAD, Friedrich Ebert, Konrad Adenauer, Heinrich Böll, Rosa Luxemburg",
        "LPDP juga bisa dipakai untuk kuliah di Jerman, banyak yang sudah berhasil",
        "Tips: motivation letter DAAD harus jelas kaitannya dengan pembangunan Indonesia",
    ],
    "Amerika Serikat": [
        "Fulbright adalah beasiswa paling prestisius dari AS untuk Indonesia — cek AMINEF",
        "Universitas Ivy League punya need-blind financial aid — jangan ragu apply walau mahal",
        "LPDP juga bisa untuk AS, banyak kampus top yang sudah mitra",
    ],
    "Inggris": [
        "Chevening (UK government) — beasiswa paling bergengsi, deadline Oktober",
        "Rhodes Scholarship dan Clarendon (Oxford) — sangat kompetitif",
        "LPDP juga banyak untuk Inggris — partnership dengan berbagai universitas",
        "Commonwealth Scholarship untuk negara berkembang anggota Commonwealth",
    ],
    "Australia": [
        "Australia Awards adalah beasiswa utama dari Pemerintah Australia",
        "LPDP-Australia Awards program kerjasama khusus Indonesia",
    ],
    "Belanda": [
        "StuNed (dulu) — sudah tidak aktif tapi LPDP-Netherlands program penggantinya",
        "Orange Tulip Scholarship (OTS) khusus Indonesia — kerjasama Nuffic Neso",
        "Holland Scholarship (€5,000) — untuk tahun pertama",
    ],
}


def _fix_tips(s: Scholarship) -> list[str]:
    if s.tips:
        return s.tips
    country_tips = _COUNTRY_SPECIFIC_TIPS.get(s.country, [])
    if country_tips:
        return country_tips[:4]
    return []


_CURRENCY_MAP: dict[str, str] = {
    "\u20ac": "EUR", "$": "USD", "\u00a3": "GBP", "\u00a5": "JPY",
}

_NEGATION_PHRASES = r'tidak\s*(termasuk|mencakup)|not\s*include|not\s*covered|excluded|dikecualikan'


def _keywords_negated(kw_pattern: str, text: str) -> bool:
    """Return True if ALL occurrences of kw_pattern have a negation phrase within 60 chars before them."""
    cl = text.lower()
    for m in re.finditer(kw_pattern, cl):
        before = cl[max(0, m.start() - 60):m.start()]
        if not re.search(_NEGATION_PHRASES, before):
            return False
    return True


def _set_stipend(c: str, cd: CoverageDetail, sym: str, val: str) -> None:
    if cd.monthly_stipend:
        return
    amount_str = sym + val
    stipend_keywords = r'(stip[ae]nd?|allowance|tunjangan|living|biaya\s+hidup|maintenance|monthly|per\s*month|/month|/bulan|/week|/minggu|fee\s*waiver|tuition\s*waiver|top.?up)'
    annual_keywords = r'(annual|/year\b|per\s*year|/tahun\b|per\s*tahun|yearly|a\s*year)'
    non_stipend_allowance = r'\b(relocation|book|thesis|research|settlement|establishment|meals|baggage)\s+allowance\b'
    strong_stipend = r'(stip[ae]nd?|living|tunjangan|biaya\s+hidup|monthly|/month\b|/bulan\b|per\s*month|per\s*bulan|/minggu|/week)'
    idx = c.find(amount_str)
    if idx >= 0:
        context = c[max(0, idx - 80): idx + len(amount_str) + 80].lower()
        if re.search(stipend_keywords, context):
            # Skip if the stipend keyword in context is negated
            neg_match = re.search(r'tidak\s*(termasuk|mencakup)[^.]*?\b(biaya\s+hidup|living|tunjangan)\b', context)
            if neg_match:
                return
            # Skip non-stipend allowances unless a strong stipend keyword is also present
            if re.search(non_stipend_allowance, context) and not re.search(strong_stipend, context):
                return
            # Skip annual amounts unless monthly keywords or fee-waiver/top-up keywords also present
            if re.search(annual_keywords, context) and not re.search(r'(monthly|/month\b|per\s*month|/bulan\b|per\s*bulan|bulanan)', context) and not re.search(r'(fee\s*waiver|tuition\s*waiver|top.?up)', context):
                return
            cd.monthly_stipend = amount_str.strip()
        elif re.match(r'^(?:full|fully)\s*[:\-]?\s*(?:\w+\s*)?[$€£¥]', c.lower()):
            # Headline "Full: $X/year" without stipend keyword — accept as scholarship amount
            # but reject if the nearby context labels it as tuition-only
            if not re.search(r'tuition\s+fee|biaya\s+kuliah|fee\s+waiver', context):
                cd.monthly_stipend = amount_str.strip()


def _parse_coverage_detail(s: Scholarship) -> CoverageDetail:
    c = s.coverage
    if not c:
        return CoverageDetail()

    # ── Phase 1: NER-based parsing (primary) ──────────────
    ner = get_ner()
    ner_result = ner.parse(c)
    cd = CoverageDetail()
    if ner_result.get("tuition"):
        cd.tuition = ner_result["tuition"]
    if ner_result.get("currency"):
        cd.currency = ner_result["currency"]
    if ner_result.get("monthly_stipend"):
        cd.monthly_stipend = ner_result["monthly_stipend"]
    if ner_result.get("travel"):
        cd.travel = ner_result["travel"]
    if ner_result.get("accommodation"):
        cd.accommodation = ner_result["accommodation"]
    if ner_result.get("insurance"):
        cd.insurance = ner_result["insurance"]
    if ner_result.get("language_course"):
        cd.language_course = ner_result["language_course"]
    if ner_result.get("other"):
        cd.other = ner_result["other"]

    # ── Phase 1b: monthly_stipend from full text (NER needs description for entries
    #    where stipend keywords like "tunjangan hidup" are only in the description) ──
    if not cd.monthly_stipend:
        full_ner = ner.parse(s.description + " " + c)
        if full_ner.get("monthly_stipend"):
            cd.monthly_stipend = full_ner["monthly_stipend"]

    # ── Phase 2: regex fallback for empty fields ──────────
    cl = c.lower()

    if not cd.tuition:
        # ── Tuition ────────────────────────────────────────────
        if re.search(r'(^partial|partial.*tuition|tuition.*(reduction|discount)|potongan.*biaya|diskon.*kuliah|top.up)', cl):
            cd.tuition = "Partial"
        elif re.search(r'(bebas\s+biaya\s+kuliah|tuition\s*(fee)?\s*(waiver|free|full)|full.*tuition|biaya\s+kuliah\s+\w*\s*penuh|biaya\s+kuliah\s+dan|\d+%\s*biaya\s+kuliah)', cl):
            cd.tuition = "Full"
        elif re.search(r'(no.*tuition|gratis|free.*tuition)', cl):
            cd.tuition = "Full"
        elif re.search(r'(hanya\s+biaya\s+kuliah|hanya.*tuition)', cl):
            cd.tuition = "Partial"
        # Fallback: "Full:" prefix without explicit "tuition" still implies full tuition
        if not cd.tuition and re.search(r'^(full|fully)', cl):
            cd.tuition = "Full"

    # ── Currency + monthly stipend (fallback) ─────────────────
    if not cd.currency or not cd.monthly_stipend:
        cur_codes = 'EUR|USD|GBP|JPY|KRW|NZD|AUD|CAD|MYR|SGD|PLN|TRY|CHF|SEK|DKK|NOK|TL|RM|KWD|CNY|CZK|RUB|HUF|BND|RON|INR|BRL|THB|VND|PKR|KZT|SAR|AED|QAR|AZN|IDR|TWD|HKD|ZAR|NGN|EGP|PEN|MXN|COP|CLP|ILS'
        amount_pat = f'([{chr(36)}{chr(8364)}{chr(163)}{chr(165)}]?)\\s*(\\d{{1,3}}(?:[\\s,.]\\d{{3}})*(?:[\\s,.]\\d+)?)\\s*(?:({cur_codes})\\b)?'
        cur_before_pat = f'\\b({cur_codes})\\s*(?:[{chr(36)}{chr(8364)}{chr(163)}{chr(165)}]\\s*)?(\\d{{1,3}}(?:[\\s,.]\\d{{3}})*(?:[\\s,.]\\d+)?)'
        amounts_after = list(re.finditer(amount_pat, c, re.IGNORECASE))
        amounts_before = list(re.finditer(cur_before_pat, c, re.IGNORECASE))
        for m in amounts_before:
            cur, val = m.groups()
            if not cd.currency:
                cd.currency = cur.upper()
            if not cd.monthly_stipend:
                _set_stipend(c, cd, "", val)
        for m in amounts_after:
            sym, val, cur = m.groups()
            if sym is None: sym = ""
            if cur is None: cur = ""
            if cur and not cd.currency:
                cd.currency = cur.upper()
            elif sym and sym in _CURRENCY_MAP and not cd.currency:
                cd.currency = _CURRENCY_MAP[sym]
            if not cd.monthly_stipend:
                _set_stipend(c, cd, sym, val)
        # Fallback: use first amount found
        if not cd.monthly_stipend:
            all_matches = list(re.finditer(r'\d{1,3}(?:[\s,.]\d{3})*(?:[\s,.]\d+)?', c))
            for m in all_matches:
                val = m.group()
                after = c[m.end():m.end()+8]
                if re.match(r'[\s,\-–]*%', after) or re.match(r'[\s,\-–]*\d+[\s,]*%', after):
                    continue
                context = c[max(0, m.start() - 80): m.end() + 80].lower()
                annual_kw = r'(annual|/year\b|per\s*year|/tahun\b|per\s*tahun|yearly|a\s*year)'
                monthly_kw = r'(monthly|/month\b|per\s*month|/bulan\b|per\s*bulan|bulanan)'
                fee_waiver = r'(fee\s*waiver|tuition\s*waiver|top.?up)'
                if re.search(annual_kw, context) and not re.search(monthly_kw, context) and not re.search(fee_waiver, context):
                    continue
                non_stipend_allowance = r'\b(relocation|book|thesis|research|settlement|establishment|meals|baggage)\s+allowance\b'
                strong_stipend = r'(stip[ae]nd?|living|tunjangan|biaya\s+hidup|monthly|/month\b|/bulan\b|per\s*month|per\s*bulan|/minggu|/week)'
                if re.search(non_stipend_allowance, context) and not re.search(strong_stipend, context):
                    continue
                stipend_kw = r'(stip[ae]nd?|allowance|tunjangan|living|biaya\s+hidup|maintenance|cost\s+of\s+living)'
                if not re.search(stipend_kw, context) and not re.search(r'(fee\s*waiver|tuition\s*waiver|top.?up)', context):
                    continue
                cd.monthly_stipend = val
                break

    if not cd.travel:
        travel_pat = r'(travel|flight|tiket\s*(pesawat|pp)|airfare|relokasi|relocation|transport|establishment\s*allowance|arrival\s*allowance|settling.in|subsistence|baggage\s*allowance|visa|mobilitas|biaya\s*perjalanan)'
        if re.search(travel_pat, cl) and not _keywords_negated(travel_pat, cl):
            cd.travel = "Covered"

    if not cd.accommodation:
        accom_pat = r'(accommodation|asrama|akomodasi|dormitory|housing|tempat\s*tinggal|asuransi\s*asrama|residence\s*support)'
        if re.search(accom_pat, cl) and not _keywords_negated(accom_pat, cl):
            cd.accommodation = "Covered"

    if not cd.insurance:
        ins_pat = r'(insurance|asuransi|health.*cover|\bihs\b|\boshc\b)'
        if re.search(ins_pat, cl) and not _keywords_negated(ins_pat, cl):
            cd.insurance = "Covered"

    if not cd.language_course:
        lang_pat = r'(language\s*course|kursus\s*bahasa|korean\s*course|bahasa\s*(turki|inggris|jerman|prancis|jepang|mandarin)|language\s*training|turkish\s*course|one.year\s*language|persiapan\s*bahasa|kelas\s*bahasa|bahasa.*lokal|bahasa.*setempat|german\s*course|french\s*course|japanese\s*course|mandarin\s*course|chinese\s*course|spanish\s*course|dana\s*bahasa|bipa\s*course|\blanguage\b(?!(?:,|\s+and\s+|\s+&\s+)?\s*(proficiency|requirement|test|score|exam|certificate|skills?|barrier)))'
        if re.search(lang_pat, cl) and not _keywords_negated(lang_pat, cl):
            cd.language_course = "Covered"

    # ── Stipend flagged but no amount found ────────────────
    if not cd.monthly_stipend:
        stipend_kw_pat = r'(stip[ae]nd?|allowance|biaya\s+hidup|tunjangan|living\s*(cost|allowance|expense|stip[ae]nd?)|living\s+costs|\bliving\b(?!\s+only)|cost\s+of\s+living)'
        stipend_kw_pat_no_living = r'(stip[ae]nd?|allowance|biaya\s+hidup|tunjangan|cost\s+of\s+living)'
        # Check if stipend keywords appear in non-negated context
        has_stipend_kw = re.search(stipend_kw_pat, cl) and not _keywords_negated(stipend_kw_pat_no_living, cl)
        # Also check for fee waiver patterns (implies remaining amount is living stipend)
        has_fee_waiver = re.search(r'(tuition\s*fee\s*waiver|fee\s*waiver|tuition\s*waiver|top.?up)', cl)
        if has_stipend_kw or has_fee_waiver:
            cd.monthly_stipend = "Included"

    # ── Currency inference from destination (fallback) ────
    if not cd.currency:
        dest_cur_map = {
            "Amerika Serikat": "USD", "Inggris": "GBP", "Australia": "AUD",
            "Jepang": "JPY", "China": "CNY", "Kanada": "CAD",
            "Swiss": "CHF", "Singapura": "SGD", "Malaysia": "MYR",
            "Korea Selatan": "KRW", "Belanda": "EUR", "Jerman": "EUR",
            "Prancis": "EUR", "Italia": "EUR", "Spanyol": "EUR",
            "Belgia": "EUR", "Austria": "EUR", "Finlandia": "EUR",
            "Swedia": "SEK", "Denmark": "DKK", "Norwegia": "NOK",
            "Turki": "TRY", "Indonesia": "IDR", "Dalam Negeri": "IDR",
            "Brunei": "BND", "Hongaria": "HUF", "Polandia": "PLN",
            "Romania": "RON", "Rusia": "RUB", "Russia": "RUB",
            "Republik Ceko": "CZK", "Thailand": "THB", "Vietnam": "VND",
            "Pakistan": "PKR", "Kazakhstan": "KZT", "Mesir": "EGP",
            "Arab Saudi": "SAR", "Uni Emirat Arab": "AED",
            "Qatar": "QAR", "Azerbaijan": "AZN",
        }
        # Map country names (from 'country' field) for entries with empty/generic destination
        country_cur_map = {
            "Jerman": "EUR", "Amerika Serikat": "USD", "Inggris": "GBP",
            "Australia": "AUD", "Jepang": "JPY", "China": "CNY",
            "Kanada": "CAD", "Swiss": "CHF", "Singapura": "SGD",
            "Malaysia": "MYR", "Korea Selatan": "KRW", "Belanda": "EUR",
            "Prancis": "EUR", "Italia": "EUR", "Spanyol": "EUR",
            "Belgia": "EUR", "Austria": "EUR", "Finlandia": "EUR",
            "Swedia": "SEK", "Denmark": "DKK", "Norwegia": "NOK",
            "Turki": "TRY", "Indonesia": "IDR", "Brunei Darussalam": "BND",
            "Hongaria": "HUF", "Polandia": "PLN", "Romania": "RON",
            "Russia": "RUB", "Rusia": "RUB", "Republik Ceko": "CZK",
            "Thailand": "THB", "Vietnam": "VND", "Pakistan": "PKR",
            "Kazakhstan": "KZT", "Mesir": "EGP", "Arab Saudi": "SAR",
            "Uni Emirat Arab": "AED", "Qatar": "QAR", "Azerbaijan": "AZN",
            "Irlandia": "EUR", "Siprus": "EUR", "Estonia": "EUR",
            "Latvia": "EUR", "Lithuania": "EUR", "Slowakia": "EUR",
            "Selandia Baru": "NZD", "Afrika Selatan": "ZAR",
            "Meksiko": "MXN", "Kolombia": "COP", "Israel": "ILS",
            "Taiwan": "TWD", "Hong Kong": "HKD", "India": "INR",
            "Brazil": "BRL", "Brasil": "BRL", "Argentina": "ARS",
            "Kroasia": "EUR", "Bulgaria": "BGN", "Siprus": "EUR",
            "Malta": "EUR", "Portugal": "EUR", "Yunani": "EUR",
            "Luksemburg": "EUR", "Slovenia": "EUR",
        }
        dest = getattr(s, "destination", "") or ""
        if dest in dest_cur_map:
            cd.currency = dest_cur_map[dest]
        elif not cd.currency:
            country = getattr(s, "country", "") or ""
            if country in country_cur_map:
                cd.currency = country_cur_map[country]

    # ── Other (additive: merge NER + regex results, with amounts) ──
    others = list(cd.other or [])
    seen_other = set(label.split(" (")[0] for label in others)
    for kw, label in [
            (r'(book|buku|library|research\s*grant|dana\s*penelitian|study\s*allowance)', "Book & research allowance"),
            (r'(visa)', "Visa fee covered"),
            (r'(settlement|relocation|establishment|settling|installation)', "Relocation allowance"),
            (r'(conference|seminar|workshop)', "Conference funding"),
            (r'(spouse|family|dependant|tanggungan)', "Family allowance"),
            (r'(computer|laptop)', "Laptop/equipment"),
            (r'(thesis|tesis|disertasi|dissertation)', "Thesis allowance"),
            (r'(publication|publikasi)', "Publication funding"),
            (r'(emergency|darurat)', "Emergency fund"),
            (r'(meal|makan|catering)', "Meal allowance"),
            (r'(training|pelatihan|professional\s*development)', "Training & development"),
            (r'(internship|magang)', "Internship / practicum"),
            (r'(baggage)', "Baggage allowance"),
            (r'(registration|pendaftaran|registrasi)\s*(fee|cost|biaya)?', "Registration fee"),
            (r'(\bgrant\b|hibah)', "Grant funding"),
            (r'(incidental\s*fees)', "Incidental fees"),
            (r'(certification|certifications)', "Certification fees"),
            (r'(career\s+development)', "Career development"),
            (r'(residence\s*permit|work\s*permit)', "Residence/work permit"),
        ]:
        m = re.search(kw, cl)
        if m:
            if label == "Registration fee" and re.search(r'pendaftaran\s+online', cl):
                continue
            if label not in seen_other:
                seen_other.add(label)
                # Try to extract nearby amount
                amt = None
                for am in re.finditer(r'[\$\u20ac\u00a3\u00a5]?\s*(\d{1,3}(?:[\s,.]\d{3})*(?:[\s,.]\d+)?)\s*(?:EUR|USD|GBP|JPY|KRW|AUD|NZD|CAD|MYR|SGD|IDR|THB|VND|PKR|EGP|TRY|SAR|CNY|INR)?', c):
                    if abs(am.start() - m.start()) <= 60:
                        amt = am.group().strip()
                        break
                entry = f"{label} ({amt})" if amt else label
                others.append(entry)
    if others:
        cd.other = others

    return cd


def _parse_requirements(s: Scholarship, force: bool = False) -> list[str]:
    if s.requirements and not force:
        return s.requirements
    combined = (s.description + " " + s.coverage).lower()
    found = []

    # Extract specific scores where possible
    ielts_m = re.search(r'ielts\s*(?:score\s*)?(?:of\s*)?(\d+\.?\d*)', combined)
    if ielts_m:
        found.append(f"IELTS {ielts_m.group(1)}")
    elif re.search(r'\bielts\b', combined):
        found.append("IELTS score")

    toefl_m = re.search(r'(?:toefl\s*i?b?t?|ibt|itp|pbt)\s*(?:score\s*)?(?:of\s*)?(\d+)', combined)
    if toefl_m:
        found.append(f"TOEFL {toefl_m.group(1)}")
    elif re.search(r'(?:toefl|ibt|itp|pbt)', combined):
        found.append("TOEFL score")

    gpa_m = re.search(r'(?:gpa|ipk)\s*(?:min(?:imal)?)?\s*[≥>=]?\s*(\d(?:[\.\d]*\d)?)', combined)
    if gpa_m:
        found.append(f"GPA {gpa_m.group(1)}")
    elif re.search(r'(?:gpa|ipk)\s*(?:min(?:imal)?)?\s*\d', combined):
        found.append("GPA minimum")

    age_m = re.search(r'\b(?:age|usia)\s*(?:limit|maksimal|max(?:imum)?)?.*?\b(\d+)', combined)
    if age_m:
        found.append(f"Age \u2264 {age_m.group(1)}")
    elif re.search(r'(?:age\s*limit|batas\s*usia|usia\s+maksimal|maksimal\s+usia)', combined):
        found.append("Age limit")

    # General document / skill requirement patterns
    for pat, label in [
            (r'(motivation\s*letter|personal\s*statement|statement\s*of\s*purpose|sop(\s|$))', "Motivation letter"),
            (r'(letter\s*of\s*recommendation|recommendation\s*letter|surat\s*rekomendasi|recommendation\b(?!\s*letter))', "Letter of recommendation"),
            (r'(research\s*proposal|proposal\s*penelitian)', "Research proposal"),
            (r'(cv|curriculum\s*vitae|resume)', "CV / Resume"),
            (r'(transcript|transkrip|academic\s*record)', "Academic transcript"),
            (r'(diploma|ijazah|certificate|sertifikat)', "Diploma / Certificate"),
            (r'(passport)', "Passport copy"),
            (r'(english\s*proficiency|language\s*proficiency|kemampuan\s*bahasa)', "English proficiency"),
            (r'(health\s*certificate|medical\s*check|surat\s*sehat)', "Health certificate"),
            (r'(portfolio)', "Portfolio"),
            (r'(interview|wawancara)', "Interview"),
            (r'(work\s*experience|pengalaman\s*kerja)', "Work experience"),
            (r'(essay|esai)', "Essay"),
            (r'(application\s*form|formulir\s*pendaftaran)', "Application form"),
        ]:
        if re.search(pat, combined):
            if label not in found:
                found.append(label)

    return found


def _apply_fixups(items: list[Scholarship]) -> list[Scholarship]:
    today = datetime.now()
    for s in items:
        # Only set tips if LLM didn't provide any, or use country tips as fallback
        if not s.tips:
            s.tips = _fix_tips(s)
        # Only parse coverage detail with regex/NER if LLM didn't populate it
        cd = s.coverage_detail
        if not cd.tuition and not cd.monthly_stipend and not cd.travel and not cd.accommodation and not cd.insurance and not cd.language_course:
            s.coverage_detail = _parse_coverage_detail(s)
        # Only extract requirements via regex if LLM didn't provide them
        if not s.requirements:
            s.requirements = _parse_requirements(s, force=True)
        else:
            s.requirements = _parse_requirements(s, force=False)
        if not s.deadline:
            for key, fallback in _DEADLINE_FALLBACKS.items():
                if key.lower() in s.title.lower():
                    s.deadline = fallback
                    break
            else:
                s.deadline = "Belum diumumkan - pantau website resmi"
        if (not s.opening_date or s.opening_date == "Belum diumumkan") and s.deadline:
            dl = s.deadline
            m = re.match(r'(Januari|Februari|Maret|April|Mei|Juni|Juli|Agustus|September|Oktober|November|Desember|January|February|March|April|May|June|July|August|September|October|November|December)-[A-Za-z]+\s+(\d{4})', dl)
            if m:
                s.opening_date = f"{m.group(1)} {m.group(2)}"
            elif re.search(r'(perkiraan|perkiraan - cek|estimated)', dl.lower()):
                m = re.match(r'(Januari|Februari|Maret|April|Mei|Juni|Juli|Agustus|September|Oktober|November|Desember|January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}', dl)
                if m:
                    s.opening_date = m.group(0)
            elif re.match(r'\d{1,2} ', dl):
                m = re.match(r'\d{1,2} (Januari|Februari|Maret|April|Mei|Juni|Juli|Agustus|September|Oktober|November|Desember|January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}', dl)
                if m:
                    month = m.group(1)
                    year = re.search(r'\d{4}', dl)
                    if year:
                        s.opening_date = f"{month} {year.group(0)}"
            elif 'rolling' in dl.lower():
                s.opening_date = 'Rolling - cek website resmi'
            elif 'varies' in dl.lower() or 'bervariasi' in dl.lower():
                s.opening_date = 'Cek website resmi'
        if not s.funding_type:
            c = s.coverage.lower().strip()
            starts_with_partial = c.startswith("partial")
            if not starts_with_partial and (
                c.startswith("full") or "full:" in c or "fully" in c or "full " in c or
                "fully funded" in c or "full tuition" in c or "fully" in c[:10]
            ):
                s.funding_type = "Fully Funded"
            elif starts_with_partial or "partial:" in c or "%" in c[:20] or \
                 "tuition reduction" in c or "tuition fee waiver" in c or \
                 "discount" in c or "reduction" in c or "tuition waiver" in c or \
                 "biaya hidup ditanggung mandiri" in c:
                s.funding_type = "Partial"
            elif re.search(r'[\$\u20ac\u00a3\u00a5]\s*\d{1,3}(?:[,.]\d{3})*(?:[,.]\d+)?', c):
                amounts = re.findall(r'[\$\u20ac\u00a3\u00a5]\s*\d{1,3}(?:[,.]\d{3})*(?:[,.]\d+)?', c)
                try:
                    max_val = max(float(a.replace('$','').replace('\u20ac','').replace('\u00a3','').replace('\u00a5','').replace(',','')) for a in amounts)
                    if max_val >= 50000:
                        s.funding_type = "Fully Funded"
                    else:
                        s.funding_type = "Partial"
                except Exception:
                    s.funding_type = "Bervariasi"
            else:
                s.funding_type = "Bervariasi"
        if not s.description:
            s.description = f"{s.title}. Provider: {s.provider}. Cek website resmi untuk informasi lengkap."
        for i, t in enumerate(s.tags):
            if t.lower() in ('s1', 's2', 's3', 'd3', 'd4', 'smp', 'sma'):
                s.tags[i] = t.upper()
        existing_tags = {t.lower() for t in s.tags}
        level_map = {"S1": "S1", "S2": "S2", "S3": "S3", "D4": "D4", "SMP": "SMP", "SMA": "SMA", "D3": "D3"}
        for lv in s.level:
            tag = level_map.get(lv)
            if tag and tag.lower() not in existing_tags:
                s.tags.append(tag)
                existing_tags.add(tag.lower())
        ft_tag = {"Fully Funded": "fully funded", "Partial": "partial", "Bervariasi": "bervariasi"}.get(s.funding_type)
        if ft_tag and ft_tag not in existing_tags:
            s.tags.append(ft_tag)
            existing_tags.add(ft_tag)
        if not s.field_of_study:
            combined = (s.title + " " + s.provider + " " + " ".join(s.tags)).lower()
            fields = []
            def wb(pat: str) -> bool:
                return bool(re.search(r'\b' + pat + r'\b', combined))
            if (wb('stem') or wb('engineering') or wb('science') or
                wb('technology') or wb('mathematics?') or wb('teknik') or
                wb('informatika') or wb('computer') or wb('cyber') or
                wb('sains') or wb('nanotech') or
                wb('robotics') or wb('physics') or wb('chemistry') or
                wb('biology') or wb('data') or wb('math') or
                wb('kaust') or wb('architecture') or wb('urban') or
                wb('materials?') or wb('informatics')):
                fields.append("STEM")
            if (wb('social') or wb('humaniora') or wb('humanities') or
                wb('public policy') or wb('sosial') or wb('kebijakan') or
                wb('leadership') or wb('governance') or wb('politik') or
                wb('political') or wb('sociology') or wb('psychology') or
                wb('anthropology') or wb('philosophy') or wb('linguistics') or
                wb('international relations')):
                fields.append("Social Sciences & Humanities")
            if (wb('development') or wb('pembangunan') or wb('developing') or
                wb('poverty') or wb('commonwealth') or wb('koica') or
                wb('manaaki') or wb('ofid') or wb('opec') or
                wb('world bank') or wb('adb') or wb('unesco')):
                fields.append("Development Studies")
            if (wb('business') or wb('economics') or wb('management') or
                wb('mba') or wb('ekonomi') or wb('bisnis') or
                wb('finance') or wb('accounting') or wb('marketing') or
                wb('entrepreneur') or wb('logistics') or wb('supply chain')):
                fields.append("Business & Economics")
            if (wb('medical') or wb('public health') or
                wb('medicine') or wb('kesehatan') or wb('kedokteran') or
                wb('nursing') or wb('clinical') or wb('pharmacy') or
                wb('biomedical') or wb('veterinary')):
                fields.append("Medical & Health Sciences")
            if (wb('agriculture') or wb('pertanian') or
                wb('food science') or wb('pangan') or wb('nutrition') or
                wb('forestry') or wb('perikanan') or wb('peternakan') or
                wb('life sciences') or wb('searca') or
                wb('fisheries') or wb('marine') or wb('kelautan')):
                fields.append("Agriculture & Life Sciences")
            if (wb('art') or wb('culture') or wb('performing arts') or
                wb('music') or wb('seni') or wb('budaya') or
                wb('creative') or wb('film') or wb('design') or
                wb('cultural heritage')):
                fields.append("Arts & Culture")
            if wb('law') or wb('hukum') or wb('legal'):
                fields.append("Law")
            if (wb('education') or wb('pendidikan') or wb('teaching') or
                wb('guru') or wb('dosen') or wb('teacher') or
                wb('pedagogy')):
                fields.append("Education")
            if (wb('islam') or wb('islamic') or wb('religious') or
                wb('agama') or wb('keagamaan') or wb('theology') or
                wb('paas')):
                fields.append("Islamic & Religious Studies")
            if (wb('peace') or wb('perdamaian') or wb('conflict') or
                wb('rotary')):
                fields.append("Peace & Conflict Studies")
            if (wb('environment') or wb('lingkungan') or wb('climate') or
                wb('energy') or wb('energi') or wb('sustainability') or
                wb('sustainable') or wb('blue economy') or wb('green') or
                wb('renewable')):
                fields.append("Environmental & Sustainability Studies")
            if fields:
                s.field_of_study = fields
            else:
                s.field_of_study = ["Multidisiplin (berbagai bidang studi)"]
    return items


def scrape_all() -> list[Scholarship]:
    total_before = len(_STATIC_SCHOLARSHIPS) + len(_AGGREGATOR_SCHOLARSHIPS)
    log.info("Loading %d static + %d aggregator scholarships", len(_STATIC_SCHOLARSHIPS), len(_AGGREGATOR_SCHOLARSHIPS))
    all_items: list[Scholarship] = list(_STATIC_SCHOLARSHIPS)
    all_items.extend(_AGGREGATOR_SCHOLARSHIPS)
    all_items.extend(_S2_FULLY_FUNDED)
    all_items.extend(_S2_ASIA_EUROPE_AFRICA)
    all_items.extend(_S2_AMERICAS_OCEANIA)

    # NEW: LLM enrichment step
    all_items = enrich(all_items)

    # Apply fixups as fallback (only fills fields LLM didn't populate)
    all_items = _apply_fixups(all_items)

    from beasiswa_scraper.storage import _recalc_checksums
    _recalc_checksums(all_items)
    log.info("After merging all sources: %d scholarships (was %d)", len(all_items), total_before)
    return all_items
