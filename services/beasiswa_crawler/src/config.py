import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
DATA_DIR = PROJECT_ROOT / "data"
LOG_DIR = PROJECT_ROOT / "log"
LOG_DIR.mkdir(parents=True, exist_ok=True)

# ── LLM enrichment via 9Router ───────────────────────────
LLM_ENABLED = os.environ.get("BEASISWA_LLM_ENABLED", "1") == "1"
LLM_ENDPOINT = os.environ.get("BEASISWA_LLM_ENDPOINT", "http://100.110.59.78:20128/v1")
LLM_API_KEY = os.environ.get("BEASISWA_LLM_API_KEY", "sk-6a21bcf6109b09f7-i0e8i4-b3be7fc7")
LLM_MODEL = os.environ.get("BEASISWA_LLM_MODEL", "ag/claude-sonnet-4-6")
LLM_BATCH_SIZE = int(os.environ.get("BEASISWA_LLM_BATCH_SIZE", "5"))
LLM_CONCURRENCY = int(os.environ.get("BEASISWA_LLM_CONCURRENCY", "3"))
LLM_TIMEOUT = int(os.environ.get("BEASISWA_LLM_TIMEOUT", "120"))
LLM_MAX_TOKENS = int(os.environ.get("BEASISWA_LLM_MAX_TOKENS", "2048"))
