import sys
import json
import logging
from logging.handlers import RotatingFileHandler
from beasiswa_scraper.scraper import scrape_all
from beasiswa_scraper.crawler_monitor import CrawlerMonitor, run_crawl as crawl_run
from beasiswa_scraper.university_db import get_all, enrich_universities
from beasiswa_scraper.storage import load, save, merge, load_universities, save_universities, merge_universities
from beasiswa_scraper.config import LOG_DIR

_handler = RotatingFileHandler(LOG_DIR / "beasiswa.log", maxBytes=5 * 1024 * 1024, backupCount=3, encoding="utf-8")
_handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s"))

# Also keep console handler
_console = logging.StreamHandler()
_console.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s"))

logging.basicConfig(level=logging.INFO, handlers=[_handler, _console])
log = logging.getLogger("beasiswa_scraper")


def run_scrape():
    items = scrape_all()
    existing = load()
    merged = merge(existing, items)
    save(merged)
    log.info("Scraped %d scholarships, total in DB: %d", len(items), len(merged))


def run_mcp():
    from beasiswa_scraper.mcp_server import run
    run()


def run_scheduler():
    from beasiswa_scraper.scheduler import run as sched_run
    sched_run()


def run_uni_scrape():
    items = enrich_universities(get_all())
    existing = load_universities()
    merged = merge_universities(existing, items)
    save_universities(merged)
    log.info("Loaded %d universities, total in DB: %d", len(items), len(merged))


def run_uni_list():
    items = load_universities()
    if not items:
        log.info("No universities in DB. Run 'python -m beasiswa_scraper uni-scrape' first.")
        return
    for i, u in enumerate(items, 1):
        prog_count = len(u.programs)
        log.info("%d. %s (%s) — %d program", i, u.name, u.country, prog_count)


def run_crawl():
    scholarships = scrape_all()
    result = crawl_run(scholarships)
    log.info("Crawl complete: %d visited, %d changed, %d errors (skipped %d)",
             result["visited"], result["changed"], result["errors"], result.get("skipped", 0))
    stats = result.get("stats", {})
    log.info("Crawl stats: %d URLs tracked, %d changed last 7d, %d support conditional GET",
             stats.get("total_urls_tracked", 0), stats.get("changed_last_7_days", 0),
             stats.get("support_conditional_get", 0))
    dist = stats.get("interval_distribution", {})
    if dist:
        parts = [f"{k}={v}" for k, v in dist.items() if v > 0]
        log.info("Interval distribution: %s", ", ".join(parts))
    if result.get("details"):
        changed_now = [d for d in result["details"] if d.get("changed")]
        if changed_now:
            log.info("Changed in this cycle:")
            for d in changed_now[:10]:
                log.info("  CHANGED: %s", d["url"])
    most = stats.get("most_changed", [])
    if most:
        log.info("Most frequently changing URLs:")
        for item in most[:10]:
            rate = item.get("changes_per_week", 0)
            h = item.get("crawl_interval_hours", 0)
            log.info("  %dx (%.1f/wk, interval=%.0fh): %s", item["changes"], rate, h, item["url"][:80])


def run_crawl_stats():
    monitor = CrawlerMonitor()
    stats = monitor.get_stats()
    print(json.dumps(stats, indent=2, ensure_ascii=False))


def print_help():
    print("""
Beasiswa Scraper — Scholarship scraping & MCP server for Indonesian S2 students

USAGE:
  python -m beasiswa_scraper <command>

COMMANDS:
  scrape       Run all scrapers and merge results into data/scholarships.json
  uni-scrape   Load university database into data/universities.json
  uni-list     List all universities in the database
  crawl        Run change-detection crawler on all scholarship URLs
  crawl-stats  Show crawl history statistics
  mcp          Start MCP server (streamable-http)
  scheduler    Start daily scheduler (06:00 and 18:00)
  help         Show this help message

EXAMPLES:
  python -m beasiswa_scraper scrape
  python -m beasiswa_scraper crawl
  python -m beasiswa_scraper crawl-stats
  python -m beasiswa_scraper mcp

CONFIG:
  Data file:         data/scholarships.json
  Crawl history:     data/crawl_history.json
  University file:   data/universities.json
  Log file:          log/beasiswa.log (rotated, 5MB max, 3 backups)
  Stats via MCP:     beasiswa://list, beasiswa://json, beasiswa://search?q=
  Universities MCP:  univ://list, univ://search?q=
""")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    cmds = {"scrape": run_scrape, "uni-scrape": run_uni_scrape, "uni-list": run_uni_list,
            "crawl": run_crawl, "crawl-stats": run_crawl_stats,
            "mcp": run_mcp, "scheduler": run_scheduler, "help": print_help}
    if cmd == "--help" or cmd == "-h" or cmd not in cmds:
        print_help()
        sys.exit(0 if cmd in ("help", "--help", "-h") else 1)
    cmds[cmd]()


if __name__ == "__main__":
    main()
