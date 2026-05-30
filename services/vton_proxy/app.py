"""VTON Proxy — Virtual Try-On via Replicate (production) or local Mobile-VTON (dev)."""
import os
import json
import uuid
import time
import threading
from pathlib import Path
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, StreamingResponse, FileResponse
from pydantic import BaseModel
import asyncio

app = FastAPI(title="VTON Proxy", version="1.0.0")

REPLICATE_API_TOKEN = os.getenv("REPLICATE_API_TOKEN", "")
VTON_MODEL = os.getenv("VTON_MODEL", "tencentarc/mobile-vton:latest")
USE_LOCAL = os.getenv("VTON_LOCAL", "").lower() == "true"
LOCAL_VTON_DIR = os.getenv("VTON_LOCAL_DIR", "./mobile_vton_repo")
OUTPUT_DIR = Path("output")
OUTPUT_DIR.mkdir(exist_ok=True)

# In-memory job store (use Redis/DB in production)
jobs: dict[str, dict] = {}

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

def _run_replicate_job(job_id: str, req: TryOnRequest):
    """Run VTON via Replicate API in background thread."""
    try:
        # Update status to processing
        jobs[job_id]["status"] = "processing"
        
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
            jobs[job_id] = {"status": "error", "error": f"Replicate create failed: {resp.text}"}
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
                jobs[job_id] = {
                    "status": "complete",
                    "result_url": output_url,
                }
                return
            elif status == "failed":
                jobs[job_id] = {
                    "status": "error", 
                    "error": pred.get("error", "Unknown error")
                }
                return
        
        jobs[job_id] = {"status": "error", "error": "Timed out after 120s"}
        
    except Exception as e:
        jobs[job_id] = {"status": "error", "error": str(e)}

def _run_local_job(job_id: str, req: TryOnRequest):
    """Run VTON via local Mobile-VTON installation."""
    try:
        jobs[job_id]["status"] = "processing"
        # TODO: Integrate local Mobile-VTON
        # For now, fall back to error
        jobs[job_id] = {"status": "error", "error": "Local VTON not yet implemented"}
    except Exception as e:
        jobs[job_id] = {"status": "error", "error": str(e)}

# ── Endpoints ──

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "model": VTON_MODEL,
        "mode": "local" if USE_LOCAL else "replicate",
        "jobs_count": len(jobs),
    }

@app.post("/call/tryon", response_model=TryOnResponse)
async def submit_tryon(req: TryOnRequest):
    """Submit a virtual try-on job."""
    if not USE_LOCAL and not REPLICATE_API_TOKEN:
        raise HTTPException(status_code=500, detail="REPLICATE_API_TOKEN not configured")
    
    event_id = str(uuid.uuid4())
    jobs[event_id] = {"status": "queued", "request": req.model_dump()}
    
    thread = threading.Thread(
        target=_run_replicate_job if not USE_LOCAL else _run_local_job,
        args=(event_id, req),
        daemon=True,
    )
    thread.start()
    
    return TryOnResponse(event_id=event_id, status="queued")

@app.get("/call/tryon/{event_id}")
async def get_tryon_status(event_id: str):
    """Get try-on job status (SSE stream or JSON)."""
    if event_id not in jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job = jobs[event_id]
    return {"event_id": event_id, "status": job["status"], **{k: v for k, v in job.items() if k != "status"}}

@app.get("/output/{filename}")
async def get_output(filename: str):
    """Serve generated output images."""
    filepath = OUTPUT_DIR / filename
    if not filepath.exists():
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(filepath)

# Cleanup old jobs periodically
@app.on_event("startup")
async def startup():
    def cleanup():
        while True:
            time.sleep(3600)  # Every hour
            now = time.time()
            to_remove = []
            for job_id, job in jobs.items():
                if now - job.get("created_at", now) > 86400:  # 24 hours
                    to_remove.append(job_id)
            for jid in to_remove:
                del jobs[jid]
    
    thread = threading.Thread(target=cleanup, daemon=True)
    thread.start()
