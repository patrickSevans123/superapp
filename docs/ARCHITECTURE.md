# Superapp Plan: Trade + Fashion + Scholarship

## Vision
Satu superapp yang menggabungkan **self-trade** (trading/investasi AI-powered), **cloth-chooser** (manajemen pakaian + virtual try-on), dan **beasiswa** (database & rekomendasi beasiswa) dalam satu platform terpadu untuk Gen-Z & milenial Indonesia.

---

## 1. Current State Assessment

### Server: `evans@100.110.59.78` (US VPS)
| Resource | Detail |
|----------|--------|
| OS | Ubuntu 24.04 |
| CPU/RAM | 14GB RAM |
| Disk | 233GB (185GB free) |
| Python | 3.14.4 |
| Go | ✓ |
| Docker | ✓ |
| Node.js | ✗ (optional) |

### Existing Deployments
```
/home/evans/
├── Project/beasiswa/       # Beasiswa scraper (Python MCP server)
├── Project/omniroute/      # (existing, unrelated)
├── Projects/self-trade/    # Self-trade platform (Python + Go + Flutter)
├── project/cloth-chooser/  # Cloth chooser (Flutter app)
└── Tools/agentic-core/     # Shared LLM agent framework
```

### Individual Project Analysis

| Aspect | self-trade | cloth-chooser | beasiswa |
|--------|-----------|---------------|----------|
| **Backend** | Python (MCP tools, AI agents, FastAPI) + Go (API gateway) | Supabase BaaS + Python (VTON server) | Python (MCP server) |
| **Frontend** | Flutter (mobile) + Rich TUI | Flutter (mobile + web) | Static HTML |
| **State Mgmt** | Provider | Riverpod | N/A |
| **Auth** | N/A | Supabase Auth | N/A |
| **AI** | LangChain LangGraph (12+ agents) | Mobile-VTON (PyTorch) | LangChain (LLM enrichment) |
| **DB** | DuckDB + Parquet + ArcticDB | Supabase PostgreSQL | JSON files |
| **Shared** | agentic_core | — | agentic_core |
| **Key Strength** | 200+ MCP tools, 150+ strategies, IBKR execution | Glassmorphism UI, OOTD engine, color detection | 50+ tests, bilingual NER, change-detection crawler |

---

## 2. Architecture Decision: Monorepo + Modular Feature Architecture

### Why Monorepo?
- **Shared `agentic_core`** — Already shared between self-trade & beasiswa
- **Shared UI design system** — Glassmorphism from cloth-chooser becomes the superapp design language
- **Shared auth** — One Supabase project for all three
- **Single CI/CD pipeline** — One deploy, one monitoring, one domain
- **Unified API gateway** — All Flutter data requests routed through Go API (single auth layer, caching, rate limiting)

> **Note on tradeoffs:** Monorepo couples CI/CD — a lint error in scholarship blocks trade deploys. Mitigate with CI path filtering (skip unchanged modules). Alternative: three repos + shared packages (publish `agentic_core`, `shared_ui`, `shared_models` as internal packages). Current choice: monorepo with Makefile targets per module.

### Architecture Diagram
```
┌─────────────────────────────────────────────────────┐
│              SUPERAPP FLUTTER (Mobile + Web)          │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │  Trade   │  │ Fashion  │  │   Scholarship    │   │
│  │ Module   │  │ Module   │  │     Module        │   │
│  └────┬─────┘  └────┬─────┘  └───────┬──────────┘   │
│       │              │                │               │
│  Shared: Auth · Router · Design System · Analytics    │
└───────┼──────────────┼────────────────┼──────────────┘
        │              │                │
        └──────────────┼────────────────┘
                       │
                  ┌────▼─────────────┐
                  │   Go API Gateway │  ← SINGLE ENTRY POINT
                  │    (Fiber :8080) │    All Flutter data goes here
                  └────┬──────┬──────┘
                       │      │
          ┌────────────┘      └────────────┐
          │                                │
     ┌────▼─────┐                    ┌─────▼──────┐
     │ Supabase │                    │  DuckDB    │
     │  (Auth,  │                    │ (Trade +   │
     │ Fashion, │                    │Scholarship)│
     │User Data)│                    └─────┬──────┘
     └──────────┘                          │
                                      ┌────▼──────────┐
                                      │ Python MCP Hub │
                                      │  (AI Agents)   │
                                      │  :20128        │
                                      └────────────────┘

Docker Compose Services (Single VPS):
  · Go API Gateway :8080           (all data, proxied to Supabase + DuckDB)
  · Python MCP Servers :20128      (trade + scholarship tools, per-service)
  · VTON Proxy :8001               (→ Replicate cloud GPU for inference)
  · Beasiswa Scheduler             (daily cron: scrape + crawl)
  · Trade Daemon                   (24/7: market data, IBKR, alerts)
```

### Data Flow Principle
**ALL Flutter ↔ backend communication goes through Go API Gateway.** No direct Supabase client in Flutter. This gives:
- Single auth enforcement point
- Centralized rate limiting, caching, and request logging
- Migration path off any backend without touching Flutter code
- DuckDB (not JSON files) for scholarship data — indexed, concurrent-safe

---

## 3. Proposed Directory Structure

```
Project/superapp/
│
├── README.md                    # Overview + setup instructions
├── docker-compose.yml           # All services orchestrated
├── docker-compose.prod.yml      # Production overrides
├── Makefile                     # Common commands
├── .github/                     # CI/CD
│   └── workflows/
│       ├── ci.yml               # Lint + test all modules
│       └── deploy.yml           # Deploy to VPS
│
├── packages/                    # Shared packages
│   ├── agentic_core/            # → symlink to Tools/agentic-core
│   ├── shared_ui/               # Extracted glassmorphism design system
│   │   ├── lib/
│   │   │   ├── glass.dart           # GlassBox, GlassCard, GlassButton, etc.
│   │   │   ├── theme.dart           # Midnight Zinc theme
│   │   │   ├── widgets/
│   │   │   └── utils/
│   │   └── pubspec.yaml
│   └── shared_models/           # Cross-cutting data models
│       ├── user_model.dart
│       └── analytics_event.dart
│
├── apps/
│   └── superapp/                # Unified Flutter app
│       ├── pubspec.yaml
│       ├── lib/
│       │   ├── main.dart
│       │   ├── app.dart
│       │   ├── core/
│       │   │   ├── router/          # GoRouter with feature-based routes
│       │   │   ├── theme/           # Midnight Zinc theme
│       │   │   ├── auth/            # Supabase auth (shared)
│       │   │   ├── analytics/       # Unified analytics
│       │   │   └── widgets/         # Shared app-level widgets
│       │   │
│       │   └── features/
│       │       ├── trade/           # ± self-trade mobile
│       │       │   ├── data/        # API client, models, repos
│       │       │   ├── domain/      # Use cases
│       │       │   └── presentation/
│       │       │       ├── providers/
│       │       │       └── screens/
│       │       │           ├── portfolio_screen.dart
│       │       │           ├── market_screen.dart
│       │       │           ├── trade_screen.dart
│       │       │           └── ai_advisor_screen.dart
│       │       │
│       │       ├── fashion/         # ± cloth-chooser
│       │       │   ├── data/
│       │       │   ├── domain/
│       │       │   └── presentation/
│       │       │       ├── providers/
│       │       │       └── screens/
│       │       │           ├── wardrobe_screen.dart
│       │       │           ├── ootd_screen.dart
│       │       │           ├── tryon_screen.dart
│       │       │           └── insights_screen.dart
│       │       │
│       │       └── scholarship/     # ± beasiswa
│       │           ├── data/
│       │           ├── domain/
│       │           └── presentation/
│       │               ├── providers/
│       │               └── screens/
│       │                   ├── browse_screen.dart
│       │                   ├── detail_screen.dart
│       │                   ├── search_screen.dart
│       │                   └── ai_advisor_screen.dart
│       │
│       ├── test/
│       └── assets/
│
  ├── services/                    # Backend services
  │   ├── api_gateway/             # Go Fiber API gateway (from self-trade/app/)
  │   │   ├── main.go
  │   │   ├── handlers/
  │   │   ├── middleware/
  │   │   └── go.mod
  │   │
  │   ├── mcp_trade/               # Trade MCP server (from self-trade/mcp_server/)
  │   │   ├── server.py
  │   │   └── tools/               # 200+ trading tools
  │   │
  │   ├── mcp_scholarship/         # Scholarship MCP server (from beasiswa/mcp_server.py)
  │   │   ├── server.py
  │   │   └── tools/
  │   │
  │   ├── vton_proxy/              # VTON proxy → Replicate/fal.ai (prod), local server (dev)
  │   │   ├── app.py               # Thin proxy: receives image, calls Replicate, returns result
  │   │   └── requirements.txt
  │   │
  │   ├── beasiswa_crawler/        # Beasiswa scraper (from beasiswa/)
  │   │   ├── src/
  │   │   ├── scheduler.py
  │   │   ├── data/                # → DuckDB (migrated from JSON)
  │   │   └── pyproject.toml
  │   │
  │   └── trade_daemon/            # Self-trade daemon (from self-trade/daemon/)
  │       ├── scheduler.py
  │       ├── jobs.py
  │       └── services.py
│
├── infra/                       # Infrastructure config
│   ├── nginx/
│   │   └── superapp.conf
│   ├── systemd/
│   │   ├── superapp-api.service
│   │   ├── superapp-mcp.service
│   │   ├── superapp-vton.service
│   │   ├── superapp-beasiswa.service
│   │   └── superapp-daemon.service
│   └── scripts/
│       ├── deploy.sh
│       ├── backup.sh
│       └── healthcheck.sh
│
└── docs/
    ├── architecture.md
    ├── api.md
    ├── development.md
    └── deployment.md
```

---

## 4. Phase-by-Phase Implementation Plan

> **Timeline:** 16-20 weeks (realistic). The principle: get each module working independently in the monorepo before integrating cross-feature work. Scholarship first (simplest) validates the entire stack; trade last (hardest, highest risk).

### Phase 0: Foundation (Week 1-2)

**Goal:** Monorepo setup + shared infrastructure + auth + prove the template with one module

| Task | Detail | Priority |
|------|--------|----------|
| 0.1 | Create `Project/superapp/` monorepo with Makefile | P0 |
| 0.2 | Symlink `agentic_core` from `Tools/` | P0 |
| 0.3 | Create single Supabase project for superapp (auth + user data) | P0 |
| 0.4 | Extract `shared_ui` package (glassmorphism design system from cloth-chooser) | P0 |
| 0.5 | Extract `shared_models` package (User, SavedItem, AnalyticsEvent) | P0 |
| 0.6 | Scaffold `apps/superapp/` Flutter app with Riverpod | P0 |
| 0.7 | Set up GoRouter with 4 tabs (Scholarship, Fashion, Trade, Profile) | P0 |
| 0.8 | Set up Supabase Auth (login/register — shared by all features) | P0 |
| 0.9 | Deploy Go API Gateway skeleton (Fiber, health check, auth middleware) | P0 |
| 0.10 | Docker Compose scaffold (Go API + placeholder services) | P1 |
| 0.11 | CI/CD pipeline (GitHub Actions with path filtering: lint + test per module) | P1 |

### Phase 1: Scholarship Module (Week 3-5) ← SIMPLEST FIRST

**Goal:** Port beasiswa → proves entire stack end-to-end (Flutter + Go API + DuckDB + MCP + Docker)

| Task | Detail | Priority |
|------|--------|----------|
| 1.1 | **Migrate scholarship data from JSON to DuckDB** (indexed, concurrent-safe) | P0 |
| 1.2 | Build Go API endpoints: `GET /api/v1/scholarships`, `GET /api/v1/scholarships/:id` | P0 |
| 1.3 | Build browse screen (card grid + filters: country, level, funding) | P0 |
| 1.4 | Build detail screen (rich markdown, deadline, requirements) | P0 |
| 1.5 | Build saved scholarships (bookmark + status tracking in Supabase) | P0 |
| 1.6 | Build AI scholarship advisor chat (MCP integration via Go API) | P1 |
| 1.7 | Set up beasiswa scheduler in Docker (daily scrape + crawl) | P1 |

### Phase 2: Fashion Module (Week 6-9) ← MEDIUM COMPLEXITY

**Goal:** Port cloth-chooser → validates VTON integration, Supabase Storage, image handling

| Task | Detail | Priority |
|------|--------|----------|
| 2.1 | Set up Go API proxy to Supabase for fashion data (wardrobe CRUD, storage URLs) | P0 |
| 2.2 | Port wardrobe screens (grid, add, detail, insights) using Riverpod | P0 |
| 2.3 | Port OOTD engine (weather + color harmony + season) | P0 |
| 2.4 | Set up VTON integration via Replicate/cloud GPU (NOT local PyTorch on VPS) | P0 |
| 2.5 | Keep local VTON server as dev-only; use API call to serverless GPU in prod | P0 |
| 2.6 | Port color detection (palette_generator — on-device, no backend needed) | P1 |
| 2.7 | Set up Supabase Storage for clothing images + person photos | P0 |
| 2.8 | Adapt Supabase schema (merge with superapp auth, add RLS policies) | P0 |

### Phase 3: Trade Module (Week 10-13) ← HIGHEST RISK

**Goal:** Port self-trade → done last when infrastructure is proven

| Task | Detail | Priority |
|------|--------|----------|
| 3.1 | Port portfolio screen (holdings, P&L) — **keep Provider state management, wrap in ProviderScope** | P0 |
| 3.2 | Port market screen (watchlist, charts) — keep Provider | P0 |
| 3.3 | Port AI advisor chat (LangGraph agents via MCP) | P0 |
| 3.4 | Port trade execution UI (paper trading first, IBKR bridge later) | P1 |
| 3.5 | Integrate Go API gateway for OHLCV, portfolio data from DuckDB | P0 |
| 3.6 | Adapt trade daemon to superapp Docker setup (systemd → Docker) | P1 |
| 3.7 | Add broker integration: IBKR connection, risk checks, audit trail, trade limits | P1 |
| 3.8 | Add trading security: API key vault, rate limiting on orders, transaction logging | P1 |

> **⚠️ State management note:** Do NOT migrate Provider → Riverpod for existing trade screens. Let them coexist. Wrap trade's `ChangeNotifierProvider` tree in Riverpod's `ProviderScope`. Migrate individual screens to Riverpod only when adding new features to them. This avoids a risk-heavy rewrite with zero user-facing value.

### Phase 4: Cross-Feature Integration (Week 14-16)

**Goal:** Features that span modules — only after all three work independently

| Task | Detail | Priority |
|------|--------|----------|
| 4.1 | Unified home dashboard (OOTD suggestion + scholarship deadline + portfolio snapshot) | P0 |
| 4.2 | Unified notification center (FCM: price alerts + outfit suggestions + deadline reminders) | P1 |
| 4.3 | Shared AI assistant that can discuss all three domains (MCP tool routing) | P2 |
| 4.4 | Unified analytics dashboard (app usage across modules, per-user stats) | P3 |

### Phase 5: Polish & Launch (Week 17-20)

| Task | Detail | Priority |
|------|--------|----------|
| 5.1 | Performance optimization (lazy loading, image caching, code splitting) | P0 |
| 5.2 | End-to-end testing (integration tests across modules) | P0 |
| 5.3 | Push notification infrastructure (FCM setup, channel config) | P0 |
| 5.4 | Backup strategy: hourly DuckDB snapshots, daily Supabase pg_dump, off-VPS storage | P0 |
| 5.5 | Monitoring & alerting (per-service health checks, Uptime Kuma, Sentry, log aggregation) | P1 |
| 5.6 | Accessibility audit + i18n setup (Indonesian primary, English secondary) | P1 |
| 5.7 | App store screenshots & metadata | P1 |
| 5.8 | Documentation (user guide, API docs, developer onboarding) | P1 |

### Explicitly Deferred / Cut
| Feature | Reason |
|---------|--------|
| Gamification (XP, badges) | Premature for launch |
| Cross-module analytics ("Save on clothes → invest") | Novelty, not core value |
| Unified search across all modules | Unused surface area |
| Remove.bg integration | Redundant with VTON |
| Country tips & university DB | Content work, not engineering; defer |

---

## 5. Technology Choices & Rationale

### Frontend
| Choice | Rationale |
|--------|-----------|
| **Flutter** (single codebase) | Both existing apps are Flutter; cross-platform (Android, iOS, Web) |
| **Riverpod** (new code) + **Provider** (existing trade screens) | Coexist — don't force migration. New features in Riverpod; trade screens stay Provider until touched for new work |
| **GoRouter** | Both apps use it; ShellRoute for tab navigation; auth guards |
| **Supabase** | Cloth-chooser already uses it; managed PostgreSQL + Auth + Storage; accessed ONLY through Go API (no direct client in Flutter) |

### Backend
| Choice | Rationale |
|--------|-----------|
| **Go Fiber** API Gateway | From self-trade; fast, low memory; ALL Flutter data routed through it (single auth, caching, rate limiting) |
| **Python MCP Servers** (per-service) | Keep per-service MCP servers (trade, scholarship); add thin proxy/registrar. No unified hub — avoid coupling |
| **DuckDB** | From self-trade; embedded analytics, zero-config, parquet-native. Now also serves scholarship data (migrated from JSON) |
| **9Router** (LLM proxy) | Already running on `:20128`; multi-provider LLM access |
| **Replicate / fal.ai** (VTON) | Serverless GPU for virtual try-on in production. Local FastAPI server for development only. Saves 3+ GB RAM |
| **Docker Compose** | Single VPS deployment; service isolation; easy scaling |

### Why NOT Local VTON on VPS?
14GB RAM shared across 5+ containers. PyTorch VTON model needs 4-8GB VRAM on GPU or 2-5 min on CPU. Concurrent requests infeasible. Serverless GPU gives <10s generation times and frees 3GB RAM.

### Why DuckDB for Scholarship Data?
JSON files are not indexed, not concurrent-safe, and every API request forces a full parse. DuckDB provides SQL queries on the same JSON data with zero migration — just `CREATE VIEW scholarships AS SELECT * FROM read_json_auto('scholarships.json')`. Full-text search, filtering, and pagination become trivial.

### Why NOT Microservices?
Single VPS with 14GB RAM → monolith-with-modules is the right call. Docker Compose gives service isolation without the operational overhead of Kubernetes. If the app grows, extract services one at a time.

### Why NOT Separate Apps?
Separate apps = 3x App Store reviews, 3x CI/CD, 3x auth, no cross-selling, no unified analytics.

---

## 6. Supabase Schema (Unified)

```sql
-- Shared across all modules
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trade module
CREATE TABLE public.watchlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  symbol TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Fashion module (from cloth-chooser)
CREATE TABLE public.clothing_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  name TEXT NOT NULL,
  category TEXT,
  brand TEXT,
  cost DECIMAL,
  times_worn INT DEFAULT 0,
  dominant_colors JSONB,
  season_tags TEXT[],
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.ootd_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  outfit JSONB,
  weather_snapshot JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Scholarship module
CREATE TABLE public.saved_scholarships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  scholarship_id TEXT NOT NULL,
  notes TEXT,
  deadline DATE,
  status TEXT DEFAULT 'interested', -- interested, applying, applied, rejected, accepted
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- All tables: RLS enabled, auth.uid() = user_id
```

---

## 7. API Design

### Go API Gateway (`:8080`) — Single Entry Point for ALL Flutter Requests

```
# Health
GET  /api/v1/health

# Auth (proxied to Supabase)
POST /api/v1/auth/signup
POST /api/v1/auth/signin
POST /api/v1/auth/signout

# Trade
GET  /api/v1/market/quote?symbols=AAPL,BBRI
GET  /api/v1/market/ohlcv?symbol=BBRI&range=1mo
GET  /api/v1/portfolio
POST /api/v1/trade/order              (paper trading)

# Fashion (proxied to Supabase)
GET    /api/v1/wardrobe?page=&filters=
POST   /api/v1/wardrobe               (multipart: image + metadata)
GET    /api/v1/wardrobe/:id
DELETE /api/v1/wardrobe/:id
POST   /api/v1/wardrobe/:id/worn
GET    /api/v1/ootd                    (weather-aware recommendation)
POST   /api/v1/ootd/wear               (log outfit worn)
POST   /api/v1/tryon                   (submit VTON job → Replicate)
GET    /api/v1/tryon/:id               (poll result)
GET    /api/v1/tryon/history
GET    /api/v1/wardrobe/insights       (CPW, category breakdown)
GET    /api/v1/weather?lat=&lon=

# Scholarship (from DuckDB)
GET  /api/v1/scholarships?q=&country=&level=&page=
GET  /api/v1/scholarships/:id
GET  /api/v1/scholarships/saved        (user's bookmarked)
POST /api/v1/scholarships/:id/save
GET  /api/v1/universities?q=

# AI (proxied to MCP servers)
POST /api/v1/ai/trade/analyze
POST /api/v1/ai/scholarship/advise
```

### Python MCP Servers — Per-Service, Not Unified

```
Trade MCP Server (from self-trade/mcp_server/):
  - trade.analyze(symbol, depth)
  - trade.backtest(strategy, symbol, start, end)
  - trade.portfolio_optimize(holdings)
  - trade.sentiment(symbol)
  ... (200+ tools)

Scholarship MCP Server (from beasiswa/mcp_server.py):
  - scholarship.search(query, filters)
  - scholarship.get_stats()
  - scholarship.ai_advisor(profile, preferences)
  - scholarship.crawl_stats()

Fashion MCP Server (new, lightweight):
  - fashion.analyze_colors(image_base64)
  - fashion.recommend_outfit(user_id, weather_context)
```

> **Principle:** Per-service MCP servers avoid coupling. Go API acts as thin proxy/registrar that routes AI requests to the correct MCP server. No unified hub that would need changes when any service changes.

---

## 8. State Management Strategy (Provider + Riverpod Coexistence)

> **Policy:** New code uses Riverpod. Existing trade screens keep Provider. They coexist safely — wrapping `ChangeNotifierProvider` in `ProviderScope` works. Migrate individual screens to Riverpod only when adding new features.

```
providers/
├── auth/                              # Riverpod (shared)
│   ├── auth_state_provider.dart       # StreamProvider<AuthState>
│   └── current_user_provider.dart     # Provider<User?>
│
├── trade/                             # Provider (existing, from self-trade)
│   ├── trade_providers.dart           # ChangeNotifierProvider tree — wrapped in ProviderScope
│   └── (migrate to Riverpod per-screen as features added)
│
├── fashion/                           # Riverpod (from cloth-chooser)
│   ├── wardrobe_provider.dart         # StateNotifierProvider
│   ├── ootd_provider.dart             # FutureProvider
│   ├── tryon_provider.dart            # StateNotifierProvider
│   └── weather_provider.dart          # FutureProvider
│
└── scholarship/                       # Riverpod (new)
    ├── scholarship_list_provider.dart # FutureProvider
    ├── saved_scholarship_provider.dart# StateNotifierProvider
    └── ai_advisor_provider.dart       # StateNotifierProvider (chat)
```

---

## 9. CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  lint-flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: cd apps/superapp && flutter analyze
      - run: cd apps/superapp && flutter test

  lint-python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
      - run: pip install ruff
      - run: ruff check services/

  lint-go:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
      - run: cd services/api_gateway && go vet ./...

deploy:
  needs: [lint-flutter, lint-python, lint-go]
  if: github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - run: |
        rsync -avz --exclude='.git' --exclude='venv' --exclude='__pycache__' \
          ./ evans@100.110.59.78:~/Project/superapp/
    - run: |
        ssh evans@100.110.59.78 '
          cd ~/Project/superapp &&
          docker compose -f docker-compose.prod.yml up -d --build
        '
```

---

## 10. Deployment Configuration

### `docker-compose.yml`
```yaml
version: '3.8'
services:
  api-gateway:
    build: ./services/api_gateway
    ports: ["8080:8080"]
    environment:
      - DUCKDB_PATH=/data/self-trade.duckdb
      - SCHOLARSHIP_DB_PATH=/data/scholarships.duckdb
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_SERVICE_KEY=${SUPABASE_SERVICE_KEY}
      - REPLICATE_API_TOKEN=${REPLICATE_API_TOKEN}
    volumes:
      - trade_data:/data
      - ../Projects/self-trade/datasets:/datasets:ro
    restart: unless-stopped

  mcp-trade:
    build: ./services/mcp_trade
    environment:
      - LLM_ENDPOINT=http://9router:20128/v1
    volumes:
      - trade_data:/data
      - ../Projects/self-trade/datasets:/datasets:ro
    restart: unless-stopped

  mcp-scholarship:
    build: ./services/mcp_scholarship
    environment:
      - LLM_ENDPOINT=http://9router:20128/v1
    volumes:
      - beasiswa_data:/app/data
    restart: unless-stopped

  vton-proxy:
    build: ./services/vton_proxy
    ports: ["8001:8001"]
    environment:
      - REPLICATE_API_TOKEN=${REPLICATE_API_TOKEN}
      - VTON_MODEL=tencentarc/mobile-vton:latest
    restart: unless-stopped

  beasiswa-scheduler:
    build: ./services/beasiswa_crawler
    environment:
      - BEASISWA_LLM_ENDPOINT=http://9router:20128/v1
    volumes:
      - beasiswa_data:/app/data
    restart: unless-stopped

  trade-daemon:
    build: ./services/trade_daemon
    volumes:
      - trade_data:/data
      - ../Projects/self-trade/datasets:/datasets:ro
    restart: unless-stopped

volumes:
  trade_data:
  beasiswa_data:
```

### `docker-compose.dev.yml` (override for local dev)
```yaml
version: '3.8'
services:
  vton-proxy:
    build: ../project/cloth-chooser/server  # Local PyTorch server for dev
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

---

## 11. Risk Assessment & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| **State management split** (Provider vs Riverpod) | Medium | Let them coexist in same widget tree. Migrate only when touching screens for features. Wrapping `ChangeNotifierProvider` in `ProviderScope` is safe |
| **Supabase vendor lock-in** | Medium | All Supabase access through Go API proxy — swap backend without touching Flutter |
| **VTON GPU unavailable on VPS** | High | **Use Replicate/fal.ai for production inference.** Local FastAPI server for development only |
| **Single VPS failure** | High | Hourly DuckDB snapshots + daily Supabase pg_dump to off-VPS storage (S3-compatible). Restore script tested |
| **Trading data loss (24h+)** | Critical | Hourly DuckDB snapshots (RPO: 1 hour, not 24). Parquet files are read-only copies of scraped data — recoverable |
| **DuckDB file locking across containers** | Medium | Single-writer (trade daemon), multiple readers (Go API). Use `ACCESS_MODE=READ_ONLY` for API connections |
| **Trading security** | Critical | API key vault (env secrets, not code), order rate limiting, audit trail for all trade actions, paper-only until IBKR bridge audited |
| **MCP protocol churn** | Low | Pin MCP version; keep adapter layer thin |
| **Flutter web performance** | Medium | Code splitting; lazy load feature modules with `deferred as` |
| **LLM cost (trading AI agents)** | Medium | Dual-tier: cheap model for data extraction (`gemini-flash`), expensive for reasoning (`claude-sonnet`) |
| **Offline/mobile connectivity** | Medium | Local caching (Hive/Isar) for scholarship data. Offline wardrobe browse. Trading requires connectivity (accept) |
| **No user migration path** | Medium | Existing cloth-chooser users: re-register in superapp or export/import. Plan migration script if user base > 100 |
| **i18n not set up early** | Low | Set up `flutter_localizations` in Phase 0; Indonesian primary, English secondary. Add translations incrementally |

---

## 12. Key Success Metrics

| Metric | Target |
|--------|--------|
| App cold start time | < 3 seconds |
| Feature module load time (lazy) | < 500ms |
| API response time (p95) | < 200ms |
| Virtual try-on generation (Replicate) | < 15 seconds |
| Scholarship data freshness | < 6 hours |
| Trading data backup RPO | < 1 hour |
| CI pipeline duration | < 10 minutes |
| Test coverage (Flutter) | > 70% |
| Test coverage (Python) | > 80% |

---

## 13. Quick Start Commands

```bash
# Clone & setup
git clone <repo-url> ~/Project/superapp
cd ~/Project/superapp

# Symlink shared packages
ln -s ~/Tools/agentic-core packages/agentic_core
ln -s ~/Project/beasiswa/data services/beasiswa_crawler/data
ln -s ~/Projects/self-trade/datasets services/trade_daemon/datasets

# Start all services
docker compose up -d

# Run Flutter app locally
cd apps/superapp
flutter pub get
flutter run -d chrome  # or android/ios

# Lint all
make lint          # ruff + flutter analyze + go vet

# Test all
make test          # flutter test + pytest + go test
```

---

## 14. File Migration Map

| Source | Destination |
|--------|-------------|
| `project/cloth-chooser/lib/` | `apps/superapp/lib/features/fashion/` |
| `project/cloth-chooser/server/` | `services/vton_proxy/` (dev-only reference) |
| `project/cloth-chooser/lib/core/widgets/glass.dart` | `packages/shared_ui/lib/glass.dart` |
| `project/cloth-chooser/lib/core/theme/` | `packages/shared_ui/lib/theme.dart` |
| `Projects/self-trade/mobile/` | `apps/superapp/lib/features/trade/` (keep Provider) |
| `Projects/self-trade/app/` | `services/api_gateway/` |
| `Projects/self-trade/mcp_server/` | `services/mcp_trade/` |
| `Projects/self-trade/daemon/` | `services/trade_daemon/` |
| `Projects/self-trade/models/agentic/` | `services/mcp_trade/agents/` |
| `Project/beasiswa/src/beasiswa_scraper/` | `services/beasiswa_crawler/src/` |
| `Project/beasiswa/mcp_server.py` | `services/mcp_scholarship/server.py` |
| `Project/beasiswa/data/` | → **Migrate to DuckDB** (not copied as JSON) |
| `Tools/agentic-core/` | `packages/agentic_core/` (symlink) |

---

*Last updated: 2026-05-30*
*Target completion: 16-20 weeks*
*Review: Oracle-validated architecture*
