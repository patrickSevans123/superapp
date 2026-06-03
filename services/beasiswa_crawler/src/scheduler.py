import random
import time
import logging
import schedule

from beasiswa_scraper.scraper import scrape_all
from beasiswa_scraper.crawler_monitor import run_crawl
from beasiswa_scraper.storage import load, save, merge

log = logging.getLogger("beasiswa_scraper.scheduler")

JITTER_MINUTES = 5


def with_jitter(base_minute: int) -> str:
    offset = random.randint(0, JITTER_MINUTES * 2) - JITTER_MINUTES
    minute = max(0, min(59, base_minute + offset))
    return f"{minute:02d}"


def scrape_job():
    log.info("Scheduled scrape started")
    try:
        items = scrape_all()
        existing = load()
        merged = merge(existing, items)
        save(merged)
        log.info("Scheduled scrape done: %d new, %d total", len(items), len(merged))
    except Exception as e:
        log.error("Scheduled scrape failed: %s", e)


def crawl_job():
    log.info("Scheduled crawl started")
    try:
        items = scrape_all()
        result = run_crawl(items)
        stats = result.get("stats", {})
        log.info("Crawl: %d visited, %d changed, %d errors | Total tracked: %d",
                 result["visited"], result["changed"], result["errors"],
                 stats.get("total_urls_tracked", 0))
    except Exception as e:
        log.error("Scheduled crawl failed: %s", e)


def run():
    scrape_1 = f"06:{with_jitter(0)}"
    crawl_1 = f"06:{with_jitter(30)}"
    scrape_2 = f"18:{with_jitter(0)}"
    crawl_2 = f"18:{with_jitter(30)}"

    schedule.every().day.at(scrape_1).do(scrape_job)
    schedule.every().day.at(crawl_1).do(crawl_job)
    schedule.every().day.at(scrape_2).do(scrape_job)
    schedule.every().day.at(crawl_2).do(crawl_job)

    log.info("Scheduler started. Scrape: %s & %s. Crawl: %s & %s.",
             scrape_1, scrape_2, crawl_1, crawl_2)

    scrape_job()
    crawl_job()

    try:
        while True:
            schedule.run_pending()
            time.sleep(60)
    except KeyboardInterrupt:
        log.info("Scheduler stopped.")


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )
    run()
