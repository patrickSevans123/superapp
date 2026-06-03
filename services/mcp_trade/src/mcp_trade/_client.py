"""Shared aiohttp client used by the daily and research report modules.

Centralises the upstream base URL, default timeout, and JSON GET helper so
the per-endpoint modules can stay tiny wrappers over the self-trade HTTP API.
"""
from __future__ import annotations

import os
from typing import Any

import aiohttp

DEFAULT_TIMEOUT = float(os.getenv("MCP_TRADE_HTTP_TIMEOUT", "30"))


def _base_url() -> str:
    """Return the configured base URL with any trailing slash stripped."""
    return os.getenv("TRADE_API_BASE_URL", "http://localhost:8081").rstrip("/")


async def get_json(path: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
    """GET request to the upstream self-trade service, returning parsed JSON.

    Raises aiohttp.ClientResponseError on non-2xx responses so the MCP tool
    surfaces a meaningful error to the LLM instead of silently returning None.
    """
    url = f"{_base_url()}{path}"
    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=DEFAULT_TIMEOUT)) as session:
        async with session.get(url, params=params) as resp:
            resp.raise_for_status()
            return await resp.json()
