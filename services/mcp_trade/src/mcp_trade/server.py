"""FastMCP stdio server exposing self-trade reports to MCP clients.

Tools exposed (all return JSON strings so the LLM can parse them):
  - list_research_reports(source, limit)
  - get_research_report(report_id)
  - list_daily_reports(limit)
  - get_daily_report(date)
"""
from __future__ import annotations

import json
from typing import Annotated, Any, Literal

from mcp.server.fastmcp import FastMCP
from pydantic import Field

from mcp_trade import daily_reports, research_reports

mcp = FastMCP("self-trade", json_response=True)

# Known research-report sources. Keep in sync with the upstream self-trade API
# and the Flutter `ResearchReportSource` enum used in the mobile app.
ResearchSource = Literal["samuel", "mandiri", "kiwoom", "rk", "revalue"]


# ─── Tool handlers ──────────────────────────────────────────────────────────


@mcp.tool()
async def list_research_reports(
    source: Annotated[
        ResearchSource | Literal[""],
        Field(
            description=(
                'Filter by report source (e.g. "samuel", "mandiri", "kiwoom", "rk", "revalue"). '
                'Empty string returns all sources.'
            )
        ),
    ] = "",
    limit: Annotated[
        int,
        Field(description="Maximum number of reports to return.", ge=1, le=200),
    ] = 20,
) -> str:
    """List research reports from the self-trade service, optionally filtered by source."""
    data: Any = await research_reports.list_research_reports(source=source, limit=limit)
    return json.dumps(data, indent=2, ensure_ascii=False)


@mcp.tool()
async def get_research_report(
    report_id: Annotated[str, Field(description="The unique ID of the research report to fetch.")],
) -> str:
    """Fetch a single research report by its ID."""
    data: Any = await research_reports.get_research_report(report_id)
    return json.dumps(data, indent=2, ensure_ascii=False)


@mcp.tool()
async def list_daily_reports(
    limit: Annotated[
        int,
        Field(description="Maximum number of daily reports to return.", ge=1, le=200),
    ] = 20,
) -> str:
    """List the most recent daily market reports from the self-trade service."""
    data: Any = await daily_reports.list_daily_reports(limit=limit)
    return json.dumps(data, indent=2, ensure_ascii=False)


@mcp.tool()
async def get_daily_report(
    date: Annotated[
        str,
        Field(description='Date in YYYY-MM-DD format (e.g. "2024-01-15").'),
    ],
) -> str:
    """Fetch the daily market report for a specific date."""
    data: Any = await daily_reports.get_daily_report(date)
    return json.dumps(data, indent=2, ensure_ascii=False)


# ─── Entry point ────────────────────────────────────────────────────────────


def main() -> None:
    """Run the FastMCP server over stdio."""
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
