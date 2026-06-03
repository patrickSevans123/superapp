"""Async helpers for the self-trade research reports HTTP API.

Thin wrappers over the shared `_client` that the MCP server uses to fetch
research reports. The self-trade service owns auth, caching, and data shape.
"""
from __future__ import annotations

from typing import Any

from mcp_trade._client import get_json

PATH = "/api/research-reports"


async def list_research_reports(source: str = "", limit: int = 20) -> Any:
    """List research reports, optionally filtered by source.

    Args:
        source: Source name to filter by (e.g. "samuel", "mandiri", "kiwoom", "rk", "revalue"). Empty for all.
        limit: Maximum number of reports to return (clamped to 1-200).
    """
    clamped = max(1, min(int(limit), 200))
    params: dict[str, Any] = {"limit": clamped}
    if source:
        params["source"] = source
    return await get_json(PATH, params=params)


async def get_research_report(report_id: str) -> Any:
    """Fetch a single research report by its ID.

    Args:
        report_id: The unique ID of the research report to fetch.
    """
    if not report_id:
        raise ValueError("report_id is required")
    return await get_json(f"{PATH}/{report_id}")
