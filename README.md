# Superapp: Trade + Fashion + Scholarship

Monorepo for the unified superapp combining self-trade (AI-powered trading), cloth-chooser (clothing management + virtual try-on), and beasiswa (scholarship database).

## Architecture

```
apps/superapp/           # Flutter app (Android, iOS, Web)
packages/
├── shared_ui/           # Glassmorphism design system
└── shared_models/       # Cross-cutting data models
services/
├── api_gateway/         # Go Fiber (← from self-trade/app/)
├── mcp_trade/           # Python MCP (← from self-trade/mcp_server/)
├── mcp_scholarship/     # Python MCP (← from beasiswa/mcp_server.py)
├── vton_proxy/          # VTON proxy → Replicate cloud GPU
├── beasiswa_crawler/    # Python scraper (← from beasiswa/src/)
└── trade_daemon/        # Python daemon (← from self-trade/daemon/)
```

## Repo Strategy (Opsi 2)

This is a **separate new repo** — it does NOT merge git history from existing repos.
It references them via:

- **Flutter path dependencies** → `apps/superapp/pubspec.yaml` references `~/project/cloth-chooser` for shared widgets
- **Docker volumes** → `docker-compose.yml` mounts `~/Projects/self-trade/datasets` and `~/Project/beasiswa/data`
- **Symlinks** → `packages/agentic_core → ~/Tools/agentic-core`

Each existing repo (`self-trade`, `cloth-chooser`, `beasiswa`) stays in its own GitHub repo with independent versioning.

## Quick Start

```bash
# Clone
git clone https://github.com/patrickSevans123/superapp.git ~/Project/superapp
cd ~/Project/superapp

# Set up symlinks to existing projects
ln -s ~/Tools/agentic-core packages/agentic_core

# Install Flutter dependencies
cd apps/superapp && flutter pub get

# Start all services
docker compose up -d

# Run Flutter app
flutter run -d chrome
```

## Commands

```bash
make help        # Show all commands
make dev         # Start all services
make lint        # Lint Flutter + Python + Go
make test        # Run all tests
make deploy      # Deploy to VPS
```

## See Also

- [Architecture Plan](./docs/ARCHITECTURE.md)
- [self-trade repo](https://github.com/patrickSevans123/self-trade)
- [cloth-chooser repo](https://github.com/patrickSevans123/cloth-chooser)
- [beasiswa repo](https://github.com/patrickSevans123/beasiswa)

## License

[MIT](./LICENSE)

## Security

See [SECURITY.md](./SECURITY.md) for how to report vulnerabilities.
