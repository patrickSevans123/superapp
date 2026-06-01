# api_gateway

Central Go Fiber API gateway for the superapp. Aggregates:
- **self-trade** Python API (`:8081`) — trading plans, news, market quotes, events
- **SQLite** (local file) — auth, user profiles, settings, JWT blacklist
- **DuckDB** (read-only, optional) — scholarship data via ZeroDB parquet files
- **Beasiswa frontend** (optional static mount)

Runs on port `:8080` by default. The Flutter app talks to this gateway only — it never reaches the upstream services directly.

## Environment

| Var | Required | Default | Purpose |
|-----|----------|---------|---------|
| `PORT` | no | `8080` | Listen port |
| `JWT_SECRET` | **yes** | — | HMAC key for JWT signing. Server refuses to start without it. |
| `SQLITE_PATH` | no | `data/superapp.db` | Local DB for auth + user data |
| `DUCKDB_PATH` | no | _(unset)_ | If set, scholarship queries enabled; else zero-coupling mode |
| `TRADE_API_BASE_URL` | no | `http://localhost:8081` | self-trade API root |
| `BEASISWA_DIR` | no | _(unset)_ | If set, the Beasiswa SPA is mounted at `/beasiswa/` |
| `CORS_ALLOWED_ORIGINS` | no | `http://localhost:3000,http://localhost:5173` | Comma-separated origins |

## Endpoints

### Health

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Liveness — always 200 if the process is up. |
| GET | `/health/ready` | Readiness — 200 only if every required dependency is reachable. Returns 503 otherwise. Optional deps are reported but never fail the check. |

`/health/ready` is what monitoring / load balancers should poll.

### Auth (rate-limited: 20 req/min/IP)

| Method | Path | Body | Returns |
|--------|------|------|---------|
| POST | `/api/v1/auth/register` | `{email, password, display_name}` | `{user, token}` |
| POST | `/api/v1/auth/login` | `{email, password}` | `{user, token}` |
| POST | `/api/v1/auth/refresh` | (Bearer token) | `{token}` |
| POST | `/api/v1/auth/logout` | (Bearer token) | `{ok}` |

The auth response uses the `token` field (not `access_token`):
```json
{"user": {"id": "...", "email": "...", "display_name": "..."}, "token": "<JWT>"}
```

### Trade (proxied to self-trade)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/plans` | Active + closed trading plans |
| GET | `/api/v1/plans/summary` | Plan counts + PnL aggregates |
| GET | `/api/v1/news` | Latest news articles (cross-source) |
| GET | `/api/v1/news/status` | **Per-source news freshness** (Bloomberg EN, Bloomberg Technoz, Reuters) |
| GET | `/api/v1/events` | Upcoming market events (dividends, earnings) |
| GET | `/api/v1/scrapers/health` | **Scraper health across all data sources** |

### Market

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/market/quote?ticker=AAPL` | Single ticker quote |
| GET | `/api/v1/market/quotes?tickers=AAPL,MSFT` | Batch quotes |

### LPDP (Indonesian scholarship data)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/lpdp/universities` | List of partner universities |
| GET | `/api/v1/lpdp/universities/:name` | University detail |
| GET | `/api/v1/lpdp/programs` | LPDP program list |
| GET | `/api/v1/lpdp/stats` | Aggregate stats |
| GET | `/api/v1/lpdp/search?q=...` | Search programs |

### Scholarship (DuckDB-backed, requires `DUCKDB_PATH`)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/scholarships` | List (with filters via query params) |
| GET | `/api/v1/scholarships/saved` | User's saved scholarships |
| GET | `/api/v1/scholarships/stats` | Statistics dashboard |
| GET | `/api/v1/scholarships/batch?ids=...` | Batch fetch |
| GET | `/api/v1/scholarships/:id` | Single scholarship |
| GET | `/api/v1/scholarships/:id/related` | Related scholarships |
| POST | `/api/v1/scholarships/:id/save` | Bookmark |
| DELETE | `/api/v1/scholarships/:id/save` | Unbookmark |

### Wardrobe (Supabase-backed)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/wardrobe/` | List user's wardrobe items |
| POST | `/api/v1/wardrobe/` | Add new item |
| GET | `/api/v1/wardrobe/insights` | Style analytics |
| GET/PATCH/DELETE | `/api/v1/wardrobe/:id` | CRUD on a single item |
| POST | `/api/v1/wardrobe/:id/worn` | Mark as worn today |

### Try-On + OOTD

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/tryon/history` | Past try-on sessions |
| POST | `/api/v1/tryon/` | Create new try-on |
| DELETE | `/api/v1/tryon/:id` | Remove a try-on result |
| GET | `/api/v1/ootd/` | OOTD logs |

### Profile + Settings + Upload

| Method | Path | Description |
|--------|------|-------------|
| GET/PATCH | `/api/v1/profile` | User profile CRUD |
| GET/PATCH | `/api/v1/settings` | User settings CRUD |
| POST | `/api/v1/upload/photo` | Multipart photo upload (max 10MB) |

### Static reference data (public, in-memory)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/reference/status` | Dataset load status |
| GET | `/api/v1/reference/universities` | University reference list |
| GET | `/api/v1/reference/universities/:id` | University detail |
| GET | `/api/v1/reference/country-tips` | Country tip list |
| GET | `/api/v1/reference/country-tips/:country` | Country-specific tips |
| GET | `/api/v1/reference/fashion/brands` | Brand list |
| GET | `/api/v1/reference/fashion/colors` | Color taxonomy |
| GET | `/api/v1/reference/fashion/ootd-rules` | OOTD rule list |
| GET | `/api/v1/reference/trade/idx` | IDX-listed tickers |
| GET | `/api/v1/reference/trade/watchlists` | Predefined watchlists |

## Degraded Response Envelope

When a proxied upstream (e.g. self-trade) returns 5xx or is unreachable, the gateway wraps the original response in a **degraded envelope** so the Flutter app can still parse it:

```json
{
  "degraded": true,
  "error": "upstream status 503",
  "upstream": "self-trade",
  "raw": "<original response body as a JSON-encoded string>"
}
```

**Status code is 503**. Clients should:

1. Check the top-level `degraded` field. If `true`, the request did not fully succeed.
2. If the original upstream returned a parseable body, the inner JSON lives in the `raw` field as a string — the Flutter app's `_unwrapDegraded()` helper decodes it transparently and the inner DTO is returned to the caller as if nothing happened.
3. If `raw` is missing or empty, surface the `error` field to the user.

Example — if self-trade's `/api/v1/scrapers/health` returns 503, the Flutter app still receives a typed `ScraperHealth` because the gateway preserves the original payload in `raw`.

This pattern is used for **all** proxied endpoints (news, plans, events, scraper health). It lets the UI continue to render "stale" data with a banner instead of crashing.

## News Status Response

`GET /api/v1/news/status` returns per-source freshness:

```json
{
  "sources": [
    {
      "name": "bloomberg_technoz",
      "last_updated": "2026-06-01T18:56:00Z",
      "age_seconds": 600,
      "is_stale": false,
      "threshold_seconds": 43200
    },
    {
      "name": "bloomberg_english",
      "last_updated": "2026-06-01T19:34:00Z",
      "age_seconds": 60,
      "is_stale": false,
      "threshold_seconds": 43200
    },
    {
      "name": "reuters",
      "last_updated": "2026-05-31T08:00:00Z",
      "age_seconds": 86400,
      "is_stale": true,
      "threshold_seconds": 43200
    }
  ]
}
```

The Flutter app uses this to show the in-line "Data stale — Reuters last updated 24h ago" banner.

## Scraper Health Response

`GET /api/v1/scrapers/health` aggregates freshness for all data sources (news + plans + MSCI):

```json
{
  "checked_at": "2026-06-01T19:30:00Z",
  "overall_healthy": false,
  "sources": [
    {
      "name": "bloomberg_technoz",
      "category": "news",
      "last_updated": "2026-06-01T18:56:00Z",
      "age_seconds": 2040,
      "is_stale": false,
      "threshold_seconds": 43200,
      "detail": ""
    },
    {
      "name": "trading_plans",
      "category": "trade",
      "last_updated": "2026-05-31T10:00:00Z",
      "age_seconds": 119400,
      "is_stale": true,
      "threshold_seconds": 86400,
      "detail": "no new plans in 33h"
    }
  ]
}
```

The gateway returns **503** if any source is stale, **200** if all are fresh. The Flutter `GlobalAppBanner` watches this endpoint via a 60s `FutureProvider.autoDispose` and pops a warning banner when new stalenesses appear (set-difference dedup, so users only see each warning once per state change).

## Run locally

```bash
cp .env.example .env       # then edit JWT_SECRET
go run .
# or
make dev
```

## Test

```bash
go test ./...
```

24 tests across the gateway (auth, trade proxy, scholarship, settings, profile, readiness).
