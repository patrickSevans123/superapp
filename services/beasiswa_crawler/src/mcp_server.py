import json
import sys
from pathlib import Path

from mcp.server.fastmcp import FastMCP

from beasiswa_scraper.scraper import scrape_all
from beasiswa_scraper.crawler_monitor import CrawlerMonitor, run_crawl
from beasiswa_scraper.storage import load, save, merge, load_universities

mcp = FastMCP("Beasiswa Scraper", json_response=True)

DATA_DIR = Path(__file__).resolve().parent.parent.parent / "data"
SCHOLARSHIPS_FILE = DATA_DIR / "scholarships.json"
UNIVERSITY_FILE = DATA_DIR / "universities.json"

_cache = {"items": None, "mtime": 0.0}
_uni_cache = {"items": None, "mtime": 0.0}


def _get_data():
    mtime = SCHOLARSHIPS_FILE.stat().st_mtime if SCHOLARSHIPS_FILE.exists() else 0
    if _cache["items"] is None or mtime > _cache["mtime"]:
        _cache["items"] = load()
        _cache["mtime"] = mtime
    return _cache["items"] or []


def _get_uni_data():
    mtime = UNIVERSITY_FILE.stat().st_mtime if UNIVERSITY_FILE.exists() else 0
    if _uni_cache["items"] is None or mtime > _uni_cache["mtime"]:
        _uni_cache["items"] = load_universities()
        _uni_cache["mtime"] = mtime
    return _uni_cache["items"] or []


def _invalidate_cache():
    _cache["items"] = None


@mcp.resource("beasiswa://list")
def list_scholarships() -> str:
    items = _get_data()
    if not items:
        return "No scholarships found. Run the scraper first."
    lines = []
    for i, s in enumerate(items, 1):
        lines.append(
            f"{i}. {s.title}\n"
            f"   Provider : {s.provider}\n"
            f"   Level    : {', '.join(s.level)}\n"
            f"   Destinasi: {s.destination}\n"
            f"   Deadline : {s.deadline}\n"
            f"   URL      : {s.url}\n"
        )
    return "\n".join(lines)


@mcp.resource("beasiswa://json")
def scholarships_json() -> str:
    items = _get_data()
    return json.dumps([s.model_dump() for s in items], indent=2, ensure_ascii=False)


@mcp.resource("beasiswa://search?q={query}")
def search_scholarships(query: str) -> str:
    items = _get_data()
    q = query.lower()
    matched = [
        s for s in items
        if q in s.title.lower()
        or q in s.provider.lower()
        or q in s.description.lower()
        or q in s.country.lower()
        or q in s.destination.lower()
        or any(q in t.lower() for t in s.tags)
    ]
    if not matched:
        return f"No scholarships matching '{query}'."
    lines = []
    for s in matched:
        lines.append(
            f"- {s.title} ({s.provider})\n"
            f"  Level: {', '.join(s.level)} | {s.destination}\n"
            f"  Deadline: {s.deadline}\n"
        )
    return "\n".join(lines)


@mcp.tool()
def scrape_scholarships() -> str:
    items = scrape_all()
    existing = load()
    merged = merge(existing, items)
    save(merged)
    _invalidate_cache()
    return f"Scraped {len(items)} scholarships. Total in DB: {len(merged)}."


@mcp.tool()
def search(query: str) -> str:
    q = query.lower()
    items = _get_data()
    matched = [
        s for s in items
        if q in s.title.lower()
        or q in s.provider.lower()
        or q in s.description.lower()
        or q in s.country.lower()
        or any(q in t.lower() for t in s.tags)
    ]
    if not matched:
        return f"No results for '{query}'."
    out = []
    for s in matched:
        out.append(f"{s.title} | {s.provider} | {s.destination} | Deadline: {s.deadline}")
    return "\n".join(out)


@mcp.tool()
def get_stats() -> str:
    items = _get_data()
    if not items:
        return "No data yet."
    by_country: dict[str, int] = {}
    by_level: dict[str, int] = {}
    for s in items:
        by_country[s.country] = by_country.get(s.country, 0) + 1
        for lv in s.level:
            by_level[lv] = by_level.get(lv, 0) + 1
    return (
        f"Total scholarships: {len(items)}\n\n"
        f"By country:\n" + "\n".join(f"  {k}: {v}" for k, v in sorted(by_country.items())) + "\n\n"
        f"By level:\n" + "\n".join(f"  {k}: {v}" for k, v in sorted(by_level.items()))
    )


# ── University MCP Resources ──

@mcp.resource("univ://list")
def list_universities() -> str:
    items = _get_uni_data()
    if not items:
        return "No universities found. Run 'uni-scrape' first."
    lines = []
    for i, u in enumerate(items, 1):
        lines.append(
            f"{i}. {u.name}\n"
            f"   Country: {u.country} | City: {u.city}\n"
            f"   Ranking: #{u.ranking} | Programs: {len(u.programs)}\n"
            f"   Tuition: {u.avg_tuition_s2}\n"
            f"   Website: {u.website}\n"
        )
    return "\n".join(lines)


@mcp.resource("univ://json")
def universities_json() -> str:
    items = _get_uni_data()
    return json.dumps([u.model_dump() for u in items], indent=2, ensure_ascii=False)


@mcp.resource("univ://search?q={query}")
def search_universities(query: str) -> str:
    items = _get_uni_data()
    q = query.lower()
    matched = [
        u for u in items
        if q in u.name.lower()
        or q in u.country.lower()
        or q in u.city.lower()
        or any(q in p.name.lower() for p in u.programs)
        or any(q in t.lower() for t in u.tags)
    ]
    if not matched:
        return f"No universities matching '{query}'."
    lines = []
    for u in matched:
        prog_names = ", ".join(p.name for p in u.programs[:3])
        lines.append(
            f"- {u.name} ({u.country})\n"
            f"  Rank: #{u.ranking} | Programs: {prog_names}{'...' if len(u.programs) > 3 else ''}\n"
            f"  Tuition: {u.avg_tuition_s2}\n"
        )
    return "\n".join(lines)


@mcp.tool()
def search_universities_tool(query: str) -> str:
    q = query.lower()
    items = _get_uni_data()
    matched = [
        u for u in items
        if q in u.name.lower()
        or q in u.country.lower()
        or any(q in p.name.lower() for p in u.programs)
    ]
    if not matched:
        return f"No universities for '{query}'."
    out = []
    for u in matched:
        out.append(f"{u.name} | {u.country} | #{u.ranking} | Programs: {len(u.programs)}")
    return "\n".join(out)


@mcp.tool()
def get_university_stats() -> str:
    items = _get_uni_data()
    if not items:
        return "No university data yet."
    by_country: dict[str, int] = {}
    total_programs = 0
    for u in items:
        by_country[u.country] = by_country.get(u.country, 0) + 1
        total_programs += len(u.programs)
    return (
        f"Total universities: {len(items)}\n"
        f"Total programs: {total_programs}\n\n"
        f"By country:\n" + "\n".join(f"  {k}: {v}" for k, v in sorted(by_country.items()))
    )


# ── Crawl Monitor MCP Tools ──

@mcp.tool()
def get_crawl_stats() -> str:
    monitor = CrawlerMonitor()
    stats = monitor.get_stats()
    return json.dumps(stats, indent=2, ensure_ascii=False)


@mcp.tool()
def run_crawler() -> str:
    items = load()
    if not items:
        return "No scholarships loaded. Run scrape first."
    result = run_crawl(items)
    return json.dumps({"visited": result["visited"], "changed": result["changed"],
                       "errors": result["errors"], "stats": result.get("stats", {})},
                      indent=2, ensure_ascii=False)


@mcp.resource("crawl://stats")
def crawl_stats_resource() -> str:
    monitor = CrawlerMonitor()
    stats = monitor.get_stats()
    lines = [f"URLs tracked: {stats['total_urls_tracked']}",
             f"Changed last 7 days: {stats['changed_last_7_days']}",
             f"Errors: {stats['errors']}",
             f"Never crawled: {stats['not_crawled_yet']}",
             f"Support conditional GET: {stats['support_conditional_get']}",
             ""]
    dist = stats.get("interval_distribution", {})
    if dist:
        parts = [f"{k}={v}" for k, v in dist.items() if v > 0]
        lines.append("Crawl intervals: " + ", ".join(parts))
        lines.append("")
    if stats.get("most_changed"):
        lines.append("Most frequently changing URLs (total / per week / interval):")
        for item in stats["most_changed"][:15]:
            h = item.get("crawl_interval_hours", 0)
            lines.append(f"  {item['changes']}x ({item['changes_per_week']:.1f}/wk, every {h:.0f}h) — {item['url'][:80]}")
    return "\n".join(lines)


# ── Prompts ──

@mcp.prompt()
def scholarship_advisor() -> str:
    return """You are a scholarship advisor. You have access to a database of scholarships 
via the `beasiswa://list` resource and `search` tool. 

Help the user find suitable scholarships based on:
- Education level (S1/D4, S2, S3)
- Destination (domestic/abroad)
- Field of study
- Deadline urgency

Use `get_stats()` for a quick overview. Use `search(query)` for specific lookups."""


@mcp.prompt()
def university_advisor() -> str:
    return """You are a university admissions advisor for Indonesian students seeking S2 abroad. 
You have access to a database of universities via the `univ://list` resource and `search_universities_tool` tool.

Help the user find suitable universities and programs based on:
- Country preference
- Field of study
- Budget
- Language requirements

Use `get_university_stats()` for overview. Use `search_universities_tool(query)` for lookups."""


def run():
    transport = sys.argv[2] if len(sys.argv) > 2 else "stdio"
    mcp.run(transport=transport)
