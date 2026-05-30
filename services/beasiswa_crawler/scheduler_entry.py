"""Entry point for the beasiswa scheduler (Docker)."""
import schedule
import time
import subprocess
import sys
import os

def run_scrape():
    """Run the scholarship scraper."""
    print("[scheduler] Running scholarship scrape...")
    try:
        subprocess.run([sys.executable, "-m", "beasiswa_scraper", "scrape"], 
                       cwd=os.path.dirname(__file__), check=True)
        print("[scheduler] Scrape completed successfully")
    except Exception as e:
        print(f"[scheduler] Scrape failed: {e}")

def main():
    # Run immediately on startup
    run_scrape()
    
    # Schedule daily at 3 AM
    schedule.every().day.at("03:00").do(run_scrape)
    
    print("[scheduler] Beasiswa scheduler started. Daily scrape at 03:00 UTC.")
    while True:
        schedule.run_pending()
        time.sleep(60)

if __name__ == "__main__":
    main()
