import json
import hashlib
import logging
import os
import random
import re
import asyncio
import time
from datetime import datetime, timedelta
from typing import Any

import aiohttp

from beasiswa_scraper.config import DATA_DIR

log = logging.getLogger(__name__)

CRAWL_FILE = DATA_DIR / "crawl_history.json"

TIMEOUT_SEC = int(os.environ.get("BEASISWA_CRAWL_TIMEOUT", "30"))
MAX_SNIPPET_LEN = 500
MAX_URLS_PER_RUN = int(os.environ.get("BEASISWA_MAX_URLS_PER_RUN", "50"))
RETRY_MAX = int(os.environ.get("BEASISWA_CRAWL_RETRY", "2"))
RETRY_DELAY_SEC = float(os.environ.get("BEASISWA_CRAWL_RETRY_DELAY", "2.0"))
CONCURRENCY = int(os.environ.get("BEASISWA_CRAWL_CONCURRENCY", "5"))

MONTHS_ID = {
    "Januari": 1, "Februari": 2, "Maret": 3, "April": 4, "Mei": 5, "Juni": 6,
    "Juli": 7, "Agustus": 8, "September": 9, "Oktober": 10, "November": 11, "Desember": 12,
}
MONTHS_EN = {
    "January": 1, "February": 2, "March": 3, "April": 4, "May": 5, "June": 6,
    "July": 7, "August": 8, "September": 9, "October": 10, "November": 11, "December": 12,
}
ALL_MONTHS = {**MONTHS_ID, **MONTHS_EN}

CHANGE_WEBHOOK_URL = os.environ.get("BEASISWA_CHANGE_WEBHOOK", "")


def _parse_deadline(text: str) -> tuple[int, int, int] | None:
    m = re.match(
        r'(\d{1,2})\s+(Januari|Februari|Maret|April|Mei|Juni|Juli|Agustus|September|Oktober|November|Desember|January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})',
        text
    )
    if m:
        day, month_name, year = int(m.group(1)), m.group(2), int(m.group(3))
        month = ALL_MONTHS.get(month_name)
        if month:
            return day, month, year
    m = re.match(
        r'(Januari|Februari|Maret|April|Mei|Juni|Juli|Agustus|September|Oktober|November|Desember|January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})',
        text
    )
    if m:
        month_name, year = m.group(1), int(m.group(2))
        month = ALL_MONTHS.get(month_name)
        if month:
            return 1, month, year
    return None


def days_until_deadline(deadline_str: str) -> int | None:
    parsed = _parse_deadline(deadline_str)
    if not parsed:
        return None
    day, month, year = parsed
    now = datetime.now()
    try:
        deadline = datetime(year, month, day)
        delta = (deadline - now).days
        return max(delta, 0)
    except (ValueError, OverflowError):
        return None


class CrawlerMonitor:
    def __init__(self):
        self.history: dict[str, dict] = {}
        self._load()
        self._session: aiohttp.ClientSession | None = None

    async def _get_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            timeout = aiohttp.ClientTimeout(total=TIMEOUT_SEC)
            self._session = aiohttp.ClientSession(
                timeout=timeout,
                headers={"User-Agent": "Mozilla/5.0 BeasiswaCrawler/1.0"},
            )
        return self._session

    async def close(self):
        if self._session and not self._session.closed:
            await self._session.close()

    def _load(self):
        if CRAWL_FILE.exists():
            try:
                raw = json.loads(CRAWL_FILE.read_text(encoding="utf-8"))
                self.history = raw
            except (json.JSONDecodeError, Exception) as e:
                log.warning("Failed to load crawl history: %s", e)
                self.history = {}

    def _save(self):
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        CRAWL_FILE.write_text(json.dumps(self.history, indent=2, ensure_ascii=False), encoding="utf-8")

    @staticmethod
    def _clean_html(html: str) -> str:
        stripped = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL | re.IGNORECASE)
        stripped = re.sub(r'<script[^>]*>.*?</script>', '', stripped, flags=re.DOTALL | re.IGNORECASE)
        stripped = re.sub(r'<[^>]+>', '', stripped)
        stripped = re.sub(r'\s+', ' ', stripped).strip()
        return stripped

    def _content_hash(self, html: str) -> str:
        text = self._clean_html(html)[:10000]
        return hashlib.sha256(text.encode()).hexdigest()[:16]

    def _content_snippet(self, html: str) -> str:
        text = self._clean_html(html)
        return text[:MAX_SNIPPET_LEN]

    def _structural_fingerprint(self, html: str) -> dict:
        headings = len(re.findall(r'<h[1-6][^>]*>', html))
        links = len(re.findall(r'<a\s+[^>]*href=', html))
        paragraphs = len(re.findall(r'<p[^>]*>', html))
        tables = len(re.findall(r'<table[^>]*>', html))
        images = len(re.findall(r'<img[^>]*>', html))
        forms = len(re.findall(r'<form[^>]*>', html))
        return {
            "headings": headings, "links": links, "paragraphs": paragraphs,
            "tables": tables, "images": images, "forms": forms,
        }

    async def _notify_change(self, url: str, title: str, old_hash: str, new_hash: str):
        if not CHANGE_WEBHOOK_URL:
            return
        try:
            payload = json.dumps({
                "url": url, "title": title,
                "old_hash": old_hash, "new_hash": new_hash,
                "detected_at": datetime.now().isoformat(),
            }).encode()
            session = await self._get_session()
            async with session.post(
                CHANGE_WEBHOOK_URL,
                data=payload,
                headers={"Content-Type": "application/json"},
            ) as resp:
                log.info("Webhook notification sent for %s", url[:80])
        except Exception as e:
            log.warning("Webhook failed for %s: %s", url[:80], e)

    async def visit(self, url: str) -> dict:
        result: dict[str, Any] = {"url": url, "ok": False, "hash": "", "snippet": "", "error": "", "status": 0}
        prev = self.history.get(url, {})
        headers = {}
        etag = prev.get("etag", "")
        last_modified = prev.get("last_modified", "")
        if etag:
            headers["If-None-Match"] = etag
        if last_modified:
            headers["If-Modified-Since"] = last_modified

        last_err = prev.get("last_error", "")
        attempts = RETRY_MAX if last_err else 1

        session = await self._get_session()

        for attempt in range(attempts):
            try:
                async with session.get(url, headers=headers) as resp:
                    result["status"] = resp.status
                    result["etag"] = resp.headers.get("ETag", "")
                    result["last_modified"] = resp.headers.get("Last-Modified", "")

                    if resp.status == 304:
                        result["ok"] = True
                        result["hash"] = prev.get("hash", "")
                        result["snippet"] = prev.get("snippet", "")
                        result["structure"] = prev.get("structure", {})
                        result["not_modified"] = True
                        return result

                    html = await resp.text(encoding="utf-8", errors="replace")
                    result["ok"] = True
                    result["hash"] = self._content_hash(html)
                    result["snippet"] = self._content_snippet(html)
                    result["structure"] = self._structural_fingerprint(html)
                    result["not_modified"] = False
                    return result

            except aiohttp.ClientResponseError as e:
                if e.status == 304:
                    prev = self.history.get(url, {})
                    result["ok"] = True
                    result["hash"] = prev.get("hash", "")
                    result["snippet"] = prev.get("snippet", "")
                    result["structure"] = prev.get("structure", {})
                    result["status"] = 304
                    result["not_modified"] = True
                    result["etag"] = str(e.headers.get("ETag", "")) if e.headers else ""
                    result["last_modified"] = str(e.headers.get("Last-Modified", "")) if e.headers else ""
                    return result
                result["error"] = f"HTTP {e.status}"
                result["status"] = e.status
            except (aiohttp.ClientError, asyncio.TimeoutError) as e:
                result["error"] = str(e)[:100]
            except Exception as e:
                result["error"] = str(e)[:100]

            if attempt < attempts - 1:
                delay = RETRY_DELAY_SEC * (attempt + 1) + random.uniform(0, 0.5)
                log.info("Retry %d/%d for %s in %.1fs", attempt + 1, attempts, url[:60], delay)
                await asyncio.sleep(delay)

        return result

    def record(self, url: str, result: dict, title: str = "") -> bool:
        now = datetime.now().isoformat()
        prev = self.history.get(url, {})
        is_first = bool(not prev or prev.get("total_crawls", 0) == 0)
        prev_hash = prev.get("hash", "")
        new_hash = result.get("hash", "")
        not_modified = result.get("not_modified", False)

        if is_first or not_modified:
            changed = False
        else:
            changed = bool(prev_hash and new_hash and prev_hash != new_hash)

        prev_struct = prev.get("structure", {})
        new_struct = result.get("structure", {})
        struct_changed = not is_first and bool(new_struct) and prev_struct != new_struct

        etag = result.get("etag", prev.get("etag", ""))
        last_modified = result.get("last_modified", prev.get("last_modified", ""))

        result["structure_changed"] = struct_changed

        entry = {
            "url": url,
            "last_crawled": now,
            "first_crawled": prev.get("first_crawled", now),
            "hash": new_hash,
            "prev_hash": prev_hash,
            "changed": bool(changed),
            "structure_changed": bool(struct_changed),
            "change_count": prev.get("change_count", 0) + (1 if changed else 0),
            "total_crawls": prev.get("total_crawls", 0) + 1,
            "snippet": result.get("snippet", ""),
            "structure": new_struct or prev_struct,
            "last_error": result.get("error", ""),
            "status": result.get("status", 0),
            "etag": etag,
            "last_modified": last_modified,
        }
        entry["change_history"] = prev.get("change_history", [])
        if changed:
            entry["change_history"].append({"at": now, "hash": new_hash})
            entry["change_history"] = entry["change_history"][-20:]

        self.history[url] = entry
        self._save()

        if changed and title:
            asyncio.create_task(self._notify_change(url, title, prev_hash, new_hash))
        return bool(changed or struct_changed)

    def _changes_per_week(self, entry: dict, now_dt: datetime | None = None) -> float:
        total_c = entry.get("change_count", 0)
        if total_c == 0:
            return 0.0
        first = entry.get("first_crawled", "")
        if not first:
            return 0.0
        try:
            now_dt = now_dt or datetime.now()
            days_alive = (now_dt - datetime.fromisoformat(first)).days
            if days_alive < 1:
                return float(total_c)
            return round(total_c / (days_alive / 7), 2)
        except (ValueError, TypeError):
            return 0.0

    def _crawl_interval_for(self, url: str) -> timedelta:
        entry = self.history.get(url, {})
        if entry.get("total_crawls", 0) == 0:
            return timedelta(seconds=0)
        if entry.get("last_error"):
            return timedelta(hours=1)
        cpw = self._changes_per_week(entry)
        if cpw >= 2.0:
            return timedelta(hours=6)
        elif cpw >= 0.5:
            return timedelta(hours=12)
        elif cpw >= 0.25:
            return timedelta(hours=24)
        elif cpw > 0:
            return timedelta(hours=48)
        else:
            return timedelta(hours=72)

    def get_stats(self) -> dict:
        total = len(self.history)
        now_dt = datetime.now()

        changed_recently = sum(
            1 for v in self.history.values()
            if v.get("changed") and v.get("last_crawled", "")
            and (now_dt - datetime.fromisoformat(v["last_crawled"])).days <= 7
        )

        total_changes_all_time = sum(v.get("change_count", 0) for v in self.history.values())
        total_crawls_all_time = sum(v.get("total_crawls", 0) for v in self.history.values())

        ranked = sorted(
            self.history.values(),
            key=lambda v: (v.get("change_count", 0), self._changes_per_week(v, now_dt)),
            reverse=True
        )[:20]

        not_crawled = sum(1 for v in self.history.values() if v.get("total_crawls", 0) == 0)
        errors = sum(1 for v in self.history.values() if v.get("last_error"))
        crawled_ok = sum(
            1 for v in self.history.values()
            if v.get("total_crawls", 0) > 0 and not v.get("last_error")
        )

        support_etag = sum(1 for v in self.history.values() if v.get("etag"))
        support_lastmod = sum(1 for v in self.history.values() if v.get("last_modified"))

        return {
            "total_urls_tracked": total,
            "total_crawls_all_time": total_crawls_all_time,
            "total_changes_all_time": total_changes_all_time,
            "changed_last_7_days": changed_recently,
            "urls_ok": crawled_ok,
            "urls_with_errors": errors,
            "urls_not_crawled_yet": not_crawled,
            "most_changed": [
                {
                    "url": v.get("url", ""),
                    "changes": v.get("change_count", 0),
                    "changes_per_week": self._changes_per_week(v, now_dt),
                    "total_crawls": v.get("total_crawls", 0),
                    "last_crawled": v.get("last_crawled", ""),
                    "crawl_interval_hours": self._crawl_interval_for(v.get("url", "")).total_seconds() / 3600,
                    "last_error": v.get("last_error", ""),
                    "etag": bool(v.get("etag")),
                    "last_modified": bool(v.get("last_modified")),
                }
                for v in ranked
            ],
            "interval_distribution": self._interval_distribution(now_dt),
            "support_conditional_get": {
                "etag": support_etag,
                "last_modified": support_lastmod,
                "total": support_etag + support_lastmod,
            },
        }

    def _interval_distribution(self, now_dt: datetime) -> dict:
        dist: dict[str, int] = {"1h (error)": 0, "6h": 0, "12h": 0, "24h": 0, "48h": 0, "72h": 0, "asap": 0}
        for url in self.history:
            iv = self._crawl_interval_for(url)
            h = iv.total_seconds() / 3600
            if h == 0:
                dist["asap"] += 1
            elif h <= 1:
                dist["1h (error)"] += 1
            elif h <= 6:
                dist["6h"] += 1
            elif h <= 12:
                dist["12h"] += 1
            elif h <= 24:
                dist["24h"] += 1
            elif h <= 48:
                dist["48h"] += 1
            else:
                dist["72h"] += 1
        return dist

    def priority_sort(self, urls_with_deadlines: list[tuple[str, str]]) -> list[tuple[str, int]]:
        scored: list[tuple[str, int]] = []
        now_dt = datetime.now()

        for url, deadline_str in urls_with_deadlines:
            score = 0
            entry = self.history.get(url, {})
            interval = self._crawl_interval_for(url)
            interval_hours = interval.total_seconds() / 3600

            last_crawled = entry.get("last_crawled", "")
            if last_crawled:
                last_dt = datetime.fromisoformat(last_crawled)
                elapsed_hours = (now_dt - last_dt).total_seconds() / 3600
                overdue_ratio = elapsed_hours / interval_hours if interval_hours > 0 else 999
                score += min(int(overdue_ratio * 30), 60)
            else:
                score += 80

            change_count = entry.get("change_count", 0)
            score += min(change_count * 10, 40)

            days = days_until_deadline(deadline_str)
            if days is not None:
                if days <= 30:
                    score += 100
                elif days <= 90:
                    score += 50
                elif days <= 180:
                    score += 20

            if entry.get("last_error"):
                score += 15

            scored.append((url, score))

        scored.sort(key=lambda x: -x[1])
        return scored

    async def _crawl_one(self, url: str, title: str, sem: asyncio.Semaphore, results: dict):
        async with sem:
            if not url.startswith("http"):
                results["skipped"] += 1
                return
            entry = self.history.get(url, {})
            interval = self._crawl_interval_for(url)
            last = entry.get("last_crawled", "")
            if last:
                last_dt = datetime.fromisoformat(last)
                elapsed = datetime.now() - last_dt
                if elapsed < interval:
                    results["skipped"] += 1
                    return

            interval_h = interval.total_seconds() / 3600
            log.info("Crawling [interval=%.1fh]: %s", interval_h, url[:80])
            result = await self.visit(url)
            changed = self.record(url, result, title=title)
            results["visited"] += 1
            if result["ok"]:
                if changed:
                    results["changed"] += 1
                    if result.get("structure_changed", False):
                        results["struct_changed"] += 1
                    log.info("CHANGED: %s", url[:80])
            else:
                results["errors"] += 1
                log.warning("ERROR: %s - %s", url[:80], result["error"])

            results["details"].append({
                "url": url[:100],
                "ok": result["ok"],
                "changed": bool(changed),
                "struct_changed": bool(result.get("struct_changed", False)),
                "error": result.get("error", ""),
            })

            await asyncio.sleep(random.uniform(0.1, 0.3))

    async def run_crawl_cycle(self, scholarships: list) -> dict:
        urls_seen: set[str] = set()
        url_items: list[tuple[str, str, str]] = []

        for s in scholarships:
            for u in (s.url, s.source_url):
                if u and u.strip() and u.strip() not in urls_seen:
                    urls_seen.add(u.strip())
                    url_items.append((u.strip(), s.deadline or "", s.title))

        priority = self.priority_sort([(u, d) for u, d, _ in url_items])
        to_crawl = priority[:MAX_URLS_PER_RUN]

        results: dict = {
            "visited": 0, "changed": 0, "errors": 0,
            "struct_changed": 0, "details": [], "skipped": 0,
        }

        sem = asyncio.Semaphore(CONCURRENCY)
        tasks = []
        for url, score in to_crawl:
            matched = [t for u, d, t in url_items if u == url]
            title = matched[0] if matched else ""
            tasks.append(self._crawl_one(url, title, sem, results))

        if tasks:
            await asyncio.gather(*tasks)

        results["stats"] = self.get_stats()
        return results


async def run_crawl_async(scholarships: list) -> dict:
    monitor = CrawlerMonitor()
    try:
        return await monitor.run_crawl_cycle(scholarships)
    finally:
        await monitor.close()


def run_crawl(scholarships: list) -> dict:
    return asyncio.run(run_crawl_async(scholarships))
