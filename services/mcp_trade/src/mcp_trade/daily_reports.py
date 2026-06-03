"""Async helpers for the self-trade daily reports HTTP API.

Thin wrappers over the shared `_client` that the MCP server uses to fetch
daily market reports. The self-trade service owns auth, caching, and data shape.
"""
from __future__ import annotations

from typing import Any

from mcp_trade._client import get_json

PATH = "/api/reports"


async def list_daily_reports(limit: int = 20) -> Any:
    """List the most recent daily market reports.

    Args:
        limit: Maximum number of reports to return (clamped to 1-200).
    """
    clamped = max(1, min(int(limit), 200))
    return await get_json(PATH, params={"limit": clamped})


async def get_daily_report(date: str) -> Any:
    """Fetch the daily market report for a specific date.

    Args:
        date: Date in YYYY-MM-DD format (e.g. "2024-01-15").
    """
    if not date:
        raise ValueError("date is required (format: YYYY-MM-DD)")
    return await get_json(PATH, params={"date": date})
