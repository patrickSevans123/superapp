FROM python:3.12-slim

WORKDIR /app

# `schedule` is already declared in pyproject.toml — no need to re-install.
# gcc/libc are NOT needed at runtime (we only run pure-Python code here).
COPY pyproject.toml ./
RUN pip install --no-cache-dir -e .

COPY src/ ./src/
COPY data/ ./data/

# Healthcheck-friendly: this process runs forever, so pgrep confirms liveness.
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
  CMD pgrep -f "beasiswa_scraper" >/dev/null || exit 1

# Run the consolidated scheduler module (was scheduler_entry.py, which was deleted).
CMD ["python", "-m", "beasiswa_scraper.scheduler"]
