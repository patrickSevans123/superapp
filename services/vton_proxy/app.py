"""VTON Proxy — Virtual Try-On via Replicate with SQLite persistence."""
import os
import json
import uuid
import time
import threading
import sqlite3
import atexit
from pathlib import Path
from datetime import datetime, timezone
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, FileResponse
from pydantic import BaseModel

app = FastAPI(title="VTON Proxy", version="1.1.0")

REPLICATE_API_TOKEN = os.getenv("REPLICATE_API_TOKEN", "")
VTON_MODEL = os.getenv("VTON_MODEL", "tencentarc/mobile-vton:latest")
USE_LOCAL = os.getenv("VTON_LOCAL", "").lower() == "true"
LOCAL_VTON_DIR = os.getenv("VTON_LOCAL_DIR", "./mobile_vton_repo")
OUTPUT_DIR = Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)

# ─── SQLite persistent job store ────────────────────────────────────────────
DB_PATH = os.getenv("VTON_DB_PATH", "data/vton_jobs.db")

_conn: Optional[sqlite3.Connection] = None
_lock = threading.Lock()


def get_db() -> sqlite3.Connection:
    global _conn
    if _conn is None:
        os.makedirs(os.path.dirname(DB_PATH) or ".", exist_ok=True)
        _conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        _conn.row_factory = sqlite3.Row
        _conn.execute("PRAGMA journal_mode=WAL")
        _conn.execute("PRAGMA busy_timeout=5000")
        _conn.execute("""
            CREATE TABLE IF NOT EXISTS vton_jobs (
                id TEXT PRIMARY KEY,
                status TEXT NOT NULL DEFAULT 'queued',
                request_json TEXT NOT NULL,
                result_url TEXT,
                error TEXT,
                created_at REAL NOT NULL
            )
        """)
        _conn.commit()
        # Cleanup expired jobs on startup
        _cleanup_expired_jobs(_conn)
    return _conn


def _cleanup_expired_jobs(conn: sqlite3.Connection) -> None:
    cutoff = time.time() - 86400  # 24 hours
    conn.execute("DELETE FROM vton_jobs WHERE created_at < ?", (cutoff,))
    conn.commit()


def _insert_job(conn: sqlite3.Connection, job_id: str, request_json: str) -> None:
    conn.execute(
        "INSERT INTO vton_jobs (id, status, request_json, created_at) VALUES (?, 'queued', ?, ?)",
        (job_id, request_json, time.time()),
    )
    conn.commit()


def _update_job(conn: sqlite3.Connection, job_id: str, status: str, result_url: str = None, error: str = None) -> None:
    conn.execute(
        "UPDATE vton_jobs SET status = ?, result_url = ?, error = ? WHERE id = ?",
        (status, result_url, error, job_id),
    )
    conn.commit()


def _get_job(conn: sqlite3.Connection, job_id: str) -> Optional[dict]:
    row = conn.execute("SELECT * FROM vton_jobs WHERE id = ?", (job_id,)).fetchone()
    if row is None:
        return None
    return dict(row)


# ─── Graceful shutdown ──────────────────────────────────────────────────────
@atexit.register
def _close_db():
    global _conn
    if _conn is not None:
        _conn.close()
        _conn = None


# ─── Models ─────────────────────────────────────────────────────────────────

class TryOnRequest(BaseModel):
    person_image_url: str
    garment_image_url: str
    category: str = "upper_body"
    denoise_steps: int = 30
    seed: int = 42
    auto_mask: bool = True
    auto_crop: bool = True

class TryOnResponse(BaseModel):
    event_id: str
    status: str


# ─── Background job runners ─────────────────────────────────────────────────

def _run_replicate_job(job_id: str, req: TryOnRequest):
    """Run VTON via Replicate API in background thread."""
    conn = get_db()
    try:
        _update_job(conn, job_id, "processing")

        headers = {
            "Authorization": f"Bearer {REPLICATE_API_TOKEN}",
            "Content-Type": "application/json",
        }

        payload = {
            "version": VTON_MODEL,
            "input": {
                "human_image": req.person_image_url,
                "garment_image": req.garment_image_url,
                "category": req.category,
                "denoise_steps": req.denoise_steps,
                "seed": req.seed,
            }
        }

        # Create prediction
        with httpx.Client(timeout=30) as client:
            resp = client.post(
                "https://api.replicate.com/v1/predictions",
                headers=headers,
                json=payload,
            )

        if resp.status_code != 201:
            _update_job(conn, job_id, "error", error=f"Replicate create failed: {resp.text}")
            return

        prediction = resp.json()
        prediction_id = prediction.get("id")

        # Poll until complete
        for attempt in range(40):
            time.sleep(3)
            with httpx.Client(timeout=30) as client:
                resp = client.get(
                    f"https://api.replicate.com/v1/predictions/{prediction_id}",
                    headers=headers,
                )

            if resp.status_code != 200:
                continue

            pred = resp.json()
            status = pred.get("status")

            if status == "succeeded":
                output_url = pred.get("output")
                _update_job(conn, job_id, "complete", result_url=output_url)
                return
            elif status == "failed":
                _update_job(conn, job_id, "error", error=pred.get("error", "Unknown error"))
                return

        _update_job(conn, job_id, "error", error="Timed out after 120s")

    except Exception as e:
        _update_job(conn, job_id, "error", error=str(e))


def _run_local_job(job_id: str, req: TryOnRequest):
    """Run VTON via local Mobile-VTON installation."""
    conn = get_db()
    try:
        _update_job(conn, job_id, "processing")

        # Simulate a processing delay of 2 seconds
        time.sleep(2)

        # Download the person image
        with httpx.Client(timeout=30) as client:
            resp = client.get(req.person_image_url)
            resp.raise_for_status()
            image_data = resp.content

        # Save to output/{job_id}.png
        output_path = OUTPUT_DIR / f"{job_id}.png"
        output_path.write_bytes(image_data)

        result_url = f"/output/{job_id}.png"
        _update_job(conn, job_id, "complete", result_url=result_url)

    except httpx.HTTPStatusError as e:
        _update_job(conn, job_id, "error", error=f"Download failed: {e.response.status_code} - {e.response.text[:200]}")
    except httpx.RequestError as e:
        _update_job(conn, job_id, "error", error=f"Request failed: {e}")
    except OSError as e:
        _update_job(conn, job_id, "error", error=f"Write failed: {e}")
    except Exception as e:
        _update_job(conn, job_id, "error", error=str(e))


# ── Periodic cleanup thread ──

def _cleanup_loop():
    while True:
        time.sleep(3600)  # Every hour
        try:
            conn = get_db()
            _cleanup_expired_jobs(conn)
        except Exception:
            pass


@app.on_event("startup")
async def startup():
    # Initialize DB on startup
    get_db()
    thread = threading.Thread(target=_cleanup_loop, daemon=True)
    thread.start()


# ── Endpoints ──

@app.get("/health")
async def health():
    conn = get_db()
    count = conn.execute("SELECT COUNT(*) FROM vton_jobs").fetchone()[0]
    return {
        "status": "ok",
        "model": VTON_MODEL,
        "mode": "local" if USE_LOCAL else "replicate",
        "jobs_count": count,
    }


@app.post("/call/tryon", response_model=TryOnResponse)
async def submit_tryon(req: TryOnRequest):
    """Submit a virtual try-on job (persisted in SQLite)."""
    if not USE_LOCAL and not REPLICATE_API_TOKEN:
        raise HTTPException(status_code=500, detail="REPLICATE_API_TOKEN not configured")

    event_id = str(uuid.uuid4())
    conn = get_db()
    _insert_job(conn, event_id, req.model_dump_json())

    thread = threading.Thread(
        target=_run_replicate_job if not USE_LOCAL else _run_local_job,
        args=(event_id, req),
        daemon=True,
    )
    thread.start()

    return TryOnResponse(event_id=event_id, status="queued")


@app.get("/call/tryon/{event_id}")
async def get_tryon_status(event_id: str):
    """Get try-on job status from SQLite."""
    conn = get_db()
    job = _get_job(conn, event_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")

    response = {
        "event_id": event_id,
        "status": job["status"],
    }
    if job["result_url"]:
        response["result_url"] = job["result_url"]
    if job["error"]:
        response["error"] = job["error"]
    return response


@app.get("/output/{filename}")
async def get_output(filename: str):
    """Serve generated output images."""
    filepath = OUTPUT_DIR / filename
    if not filepath.exists():
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(filepath)
