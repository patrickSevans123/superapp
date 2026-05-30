"""
LLM enrichment module for scholarship data.

Sends batches of scholarships to an LLM via agentic_core's create_llm
(``LLMProvider.ROUTER9``) to enrich descriptions, coverage details,
tips, requirements, etc.
"""

import asyncio
import json
import logging
import os
import re
from typing import Any

from agentic_core.llm_provider import LLMProvider, create_llm
from beasiswa_scraper.config import (
    LLM_API_KEY,
    LLM_BATCH_SIZE,
    LLM_CONCURRENCY,
    LLM_ENABLED,
    LLM_ENDPOINT,
    LLM_MODEL,
)
from beasiswa_scraper.models import CoverageDetail, Scholarship

logger = logging.getLogger(__name__)

# ── Set env vars for ROUTER9 provider (must happen before create_llm) ────

os.environ.setdefault("ROUTER9_API_KEY", LLM_API_KEY)
os.environ.setdefault("ROUTER9_BASE_URL", LLM_ENDPOINT)
os.environ.setdefault("ROUTER9_DEFAULT_MODEL", LLM_MODEL)

# ── Shared LLM (lazy-initialised singleton) ───────────────────────────────

_llm: Any = None


def _get_llm():
    """Return the shared LangChain chat model (``create_llm(ROUTER9)``)."""
    global _llm  # noqa: PLW0603
    if _llm is None:
        _llm = create_llm(
            LLMProvider.ROUTER9,
            model=LLM_MODEL,
            temperature=0.3,
        )
    return _llm


SYSTEM_PROMPT = """Kamu adalah asisten yang membantu memperkaya data beasiswa untuk mahasiswa Indonesia.

Tugasmu adalah menerima data beasiswa dalam format JSON dan mengembalikan versi yang diperkaya dengan informasi yang lebih detail dan terstruktur.

Untuk setiap beasiswa, kamu harus mengembalikan objek JSON dengan field-field berikut:
- title: judul asli (jangan diubah)
- description: deskripsi informatif 3-5 kalimat dalam Bahasa Indonesia yang mencakup: apa itu beasiswa, siapa penyedianya, apa yang dicakup, highlight eligibilitas, dan cara mendaftar
- coverage: ringkasan terstruktur tentang apa saja yang dicakup
- coverage_detail: objek dengan field tuition ("Full"/"Partial"/"Bervariasi"/""), monthly_stipend (string jumlah misalnya "EUR 934-1,300/bulan" atau ""), currency ("EUR"/"USD"/dll atau ""), travel ("Covered"/""), accommodation ("Covered"/""), insurance ("Covered"/""), language_course ("Covered"/""), other (list string untuk benefit lain)
- funding_type: "Fully Funded" atau "Partial" atau "Bervariasi"
- tips: 3-5 tips praktis untuk pelamar Indonesia (dalam Bahasa Indonesia)
- requirements: list persyaratan utama (dokumen, skor, dll.)
- field_of_study: list kategori bidang studi yang relevan dari: ["STEM", "Social Sciences & Humanities", "Business & Economics", "Medical & Health Sciences", "Agriculture & Life Sciences", "Arts & Culture", "Law", "Education", "Islamic & Religious Studies", "Peace & Conflict Studies", "Environmental & Sustainability Studies", "Development Studies"]
- deadline: jika kamu tahu deadline yang lebih akurat, berikan; jika tidak, biarkan sesuai aslinya

Kembalikan JSON dengan struktur: {"scholarships": [...]} dengan array yang panjangnya sama persis dengan input, dalam urutan yang sama."""


# ── Prompt builders ──────────────────────────────────────────────────────────


def _build_user_prompt(batch: list[Scholarship]) -> str:
    """Convert a batch of scholarships to a JSON prompt for the LLM."""
    items: list[dict[str, Any]] = []
    for s in batch:
        items.append({
            "title": s.title,
            "provider": s.provider,
            "description": s.description,
            "coverage": s.coverage,
            "coverage_detail": (
                s.coverage_detail.model_dump() if s.coverage_detail else {}
            ),
            "funding_type": s.funding_type,
            "tips": s.tips,
            "requirements": s.requirements,
            "field_of_study": s.field_of_study,
            "deadline": s.deadline,
        })
    return json.dumps(items, ensure_ascii=False, indent=2)


# ── Response parsing (fallback for when structured output fails) ────────────


def _extract_json_from_response(text: str) -> list[dict[str, Any]] | None:
    """Extract a JSON array from the LLM response text (fallback).

    Tries markdown code blocks first, then raw JSON parsing, then
    regex-based array extraction.  Handles both ``[...]`` and
    ``{"scholarships": [...]}`` shapes.

    Returns:
        A list of dicts if a valid JSON array was found, otherwise ``None``.
    """

    def _coerce_list(data: Any) -> list[dict[str, Any]] | None:
        """Return *data* if it is a list of dicts, or extract from wrapper."""
        if isinstance(data, list):
            return data
        if isinstance(data, dict) and "scholarships" in data:
            return data["scholarships"]
        return None

    # 1. Try ```json ... ``` or ``` ... ``` code blocks
    code_block_pattern = r"```(?:json)?\s*\n?(.*?)```"
    matches = re.findall(code_block_pattern, text, re.DOTALL)
    for match in matches:
        try:
            parsed = json.loads(match.strip())
            result = _coerce_list(parsed)
            if result is not None:
                return result
        except json.JSONDecodeError:
            continue

    # 2. Try parsing the entire text as raw JSON
    try:
        parsed = json.loads(text.strip())
        result = _coerce_list(parsed)
        if result is not None:
            return result
    except json.JSONDecodeError:
        pass

    # 3. Fallback: find the first [...] that parses
    array_pattern = r"\[[\s\S]*\]"
    match = re.search(array_pattern, text)
    if match:
        try:
            parsed = json.loads(match.group(0))
            result = _coerce_list(parsed)
            if result is not None:
                return result
        except json.JSONDecodeError:
            pass

    return None


def _merge_enrichment(
    original: Scholarship, enriched: dict[str, Any], index: int
) -> Scholarship:
    """Merge enriched fields from an LLM response dict into a Scholarship.

    Only fields present in *enriched* are updated; everything else keeps
    its original value.

    Args:
        original: The Scholarship object to update (modified in-place).
        enriched: Dict of fields returned by the LLM for this item.
        index: Position in the batch (for logging).

    Returns:
        The same Scholarship object for convenience.
    """
    if "title" in enriched:
        original.title = enriched["title"]

    if "description" in enriched:
        original.description = enriched["description"]

    if "coverage" in enriched:
        original.coverage = enriched["coverage"]

    if "coverage_detail" in enriched:
        cd_raw = enriched["coverage_detail"]
        if isinstance(cd_raw, dict):
            try:
                original.coverage_detail = CoverageDetail(**cd_raw)
            except Exception:
                logger.warning(
                    "Batch item %d: failed to parse coverage_detail, keeping original",
                    index,
                )

    if "funding_type" in enriched:
        original.funding_type = enriched["funding_type"]

    if "tips" in enriched and isinstance(enriched["tips"], list):
        original.tips = enriched["tips"]

    if "requirements" in enriched and isinstance(enriched["requirements"], list):
        original.requirements = enriched["requirements"]

    if "field_of_study" in enriched and isinstance(enriched["field_of_study"], list):
        original.field_of_study = enriched["field_of_study"]

    if "deadline" in enriched and enriched["deadline"]:
        original.deadline = enriched["deadline"]

    return original


# ── Batch enrichment ─────────────────────────────────────────────────────────


def _enrich_batch_sync(
    batch: list[Scholarship],
    batch_index: int,
    total_batches: int,
) -> None:
    """Send a single batch of scholarships to the LLM for enrichment.

    Runs synchronously (suitable for offloading to a thread-pool).
    Uses raw ``llm.invoke()`` + manual JSON parsing (``_extract_json_from_response``)
    since 9Router models tend to wrap JSON in markdown code blocks which
    breaks LangChain's ``with_structured_output``.

    On any unrecoverable failure the original data in the batch is left
    untouched and a warning is logged.

    Args:
        batch: Scholarships to enrich in this batch.
        batch_index: Zero-based index in the list of batches.
        total_batches: Total number of batches for logging.
    """
    llm = _get_llm()

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": _build_user_prompt(batch)},
    ]

    logger.info(
        "Batch %d/%d: %d items",
        batch_index + 1,
        total_batches,
        len(batch),
    )

    # ── Invoke LLM ────────────────────────────────────────────────────
    try:
        response = llm.invoke(messages)
        content = response.content if hasattr(response, "content") else str(response)
    except Exception as e:
        logger.warning(
            "Batch %d/%d: LLM invoke failed: %s: %s",
            batch_index + 1,
            total_batches,
            type(e).__name__,
            e,
        )
        return

    parsed = _extract_json_from_response(content)
    if parsed is None:
        logger.warning(
            "Batch %d/%d: could not parse JSON from response (first 300 chars: %s)",
            batch_index + 1,
            total_batches,
            content[:300],
        )
        return

    # ── Validate & merge ───────────────────────────────────────────────
    if len(parsed) != len(batch):
        logger.warning(
            "Batch %d/%d: expected %d items, got %d — merging what we can",
            batch_index + 1,
            total_batches,
            len(batch),
            len(parsed),
        )

    for i, enriched_dict in enumerate(parsed):
        if i < len(batch) and isinstance(enriched_dict, dict):
            _merge_enrichment(batch[i], enriched_dict, i)

    logger.info(
        "Batch %d/%d: done",
        batch_index + 1,
        total_batches,
    )


# ── Public API ───────────────────────────────────────────────────────────────


async def enrich_async(scholarships: list[Scholarship]) -> list[Scholarship]:
    """Enrich a list of scholarships using the LLM.

    Groups scholarships into batches of *LLM_BATCH_SIZE*, sends them
    concurrently (up to *LLM_CONCURRENCY* parallel calls) to the LLM via
    ``agentic_core``, and updates each ``Scholarship`` object in-place with
    enriched data.

    Args:
        scholarships: List of Scholarship objects to enrich.

    Returns:
        The same list of Scholarship objects (modified in-place).
    """
    if not scholarships:
        return scholarships

    if not LLM_ENABLED:
        logger.info("LLM enrichment is disabled (BEASISWA_LLM_ENABLED=0)")
        return scholarships

    batch_size = LLM_BATCH_SIZE
    batches = [
        scholarships[i : i + batch_size]
        for i in range(0, len(scholarships), batch_size)
    ]

    logger.info(
        "Enriching %d scholarships in %d batches...",
        len(scholarships),
        len(batches),
    )

    semaphore = asyncio.Semaphore(LLM_CONCURRENCY)

    async def _run_batch(
        batch: list[Scholarship],
        batch_index: int,
        total_batches: int,
    ) -> None:
        """Run a single batch in the default thread-pool under the semaphore."""
        async with semaphore:
            loop = asyncio.get_running_loop()
            await loop.run_in_executor(
                None,
                _enrich_batch_sync,
                batch,
                batch_index,
                total_batches,
            )

    tasks = [
        _run_batch(batch, i, len(batches))
        for i, batch in enumerate(batches)
    ]
    await asyncio.gather(*tasks)

    return scholarships


def enrich(scholarships: list[Scholarship]) -> list[Scholarship]:
    """Synchronous wrapper for :func:`enrich_async`.

    Args:
        scholarships: List of Scholarship objects to enrich.

    Returns:
        The same list of Scholarship objects (modified in-place).
    """
    return asyncio.run(enrich_async(scholarships))


async def validate_llm_connection() -> bool:
    """Check connectivity to the LLM endpoint via agentic_core.

    Sends a minimal test request to verify the endpoint is reachable and the
    API key is valid.

    Returns:
        ``True`` if the LLM endpoint responds successfully, ``False`` otherwise.
    """
    try:
        llm = _get_llm()
        loop = asyncio.get_running_loop()

        response = await loop.run_in_executor(
            None,
            llm.invoke,
            [{"role": "user", "content": "Respond with the word 'ok' only."}],
        )
        content = response.content if hasattr(response, "content") else str(response)

        if "ok" in content.strip().lower():
            logger.info("LLM connection validated successfully")
            return True

        logger.warning(
            "LLM connection validation failed: unexpected response: %s",
            content[:200],
        )
        return False

    except Exception as e:
        logger.warning(
            "LLM connection validation error: %s: %s",
            type(e).__name__,
            e,
        )
        return False
