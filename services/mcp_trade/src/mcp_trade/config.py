"""Environment-driven configuration for the mcp_trade service.

The MCP server is a thin client over the self-trade HTTP API. All connection
details are sourced from environment variables with safe local defaults.
"""
from __future__ import annotations

import os

# Upstream self-trade HTTP API. In Docker this points to host.docker.internal:8081
# so the API gateway (also on the host) can be reached; in local dev it's localhost.
TRADE_API_BASE_URL = os.environ.get("TRADE_API_BASE_URL", "http://localhost:8081")

# Default request timeout (in seconds) for upstream HTTP calls.
MCP_TRADE_HTTP_TIMEOUT = float(os.environ.get("MCP_TRADE_HTTP_TIMEOUT", "30"))
