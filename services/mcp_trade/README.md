# mcp-trade

FastMCP stdio server that exposes the self-trade report APIs (daily + research)
to MCP-aware clients (Claude Desktop, Cursor, custom agents, etc.).

## What it does

The self-trade Python service publishes daily market reports and research
reports over HTTP at `/api/reports` and `/api/research-reports`. This MCP
server wraps those endpoints as MCP tools so an LLM can query them directly.

## Install

```bash
cd services/mcp_trade
pip install -e .
```

## Run

```bash
python -m mcp_trade
```

The server speaks MCP over stdio. Point your MCP client at the
`python -m mcp_trade` command.

## Environment variables

| Var                       | Default                  | Description                                |
| ------------------------- | ------------------------ | ------------------------------------------ |
| `TRADE_API_BASE_URL`      | `http://localhost:8081`  | Base URL of the self-trade HTTP API        |
| `MCP_TRADE_HTTP_TIMEOUT`  | `30`                     | Upstream request timeout, in seconds        |

For local Docker setups the API gateway lives on the host, so set
`TRADE_API_BASE_URL=http://host.docker.internal:8081` if the MCP server runs
in a container.

## Tools exposed

| Tool name                  | Description                                                   |
| -------------------------- | ------------------------------------------------------------- |
| `list_research_reports`    | List research reports; optional `source` filter, `limit` 1-200 |
| `get_research_report`      | Fetch one research report by ID                                |
| `list_daily_reports`       | List the most recent daily market reports; `limit` 1-200        |
| `get_daily_report`         | Fetch the daily market report for a specific date (YYYY-MM-DD) |

All tools return JSON strings.

## File layout

```
services/mcp_trade/
├── pyproject.toml
├── README.md
└── src/
    └── mcp_trade/
        ├── __init__.py
        ├── __main__.py          # entry point for `python -m mcp_trade`
        ├── config.py            # env-driven configuration
        ├── daily_reports.py     # async client + helpers for /api/reports
        ├── research_reports.py  # async client + helpers for /api/research-reports
        └── server.py            # FastMCP tool registration
```
