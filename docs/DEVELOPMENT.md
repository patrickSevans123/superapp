# Development Guide

## Setup

1. Install prerequisites:
   - Flutter SDK 3.24+
   - Go 1.23+
   - Python 3.12+
   - Docker + Docker Compose
   - [Optional] dart-define for API URL overrides

2. Clone the repo and install dependencies:
   ```bash
   git clone <repo-url>
   cd superapp
   make help          # Show all available make targets
   ```

3. Start backend services:
   ```bash
   make dev
   ```

4. Run the Flutter app:
   ```bash
   cd apps/superapp
   flutter run
   ```

## Common commands

| Command                | Purpose                                |
|------------------------|----------------------------------------|
| `make dev`             | Start all backend services             |
| `make dev-down`        | Stop all backend services              |
| `make dev-logs`        | Tail logs from all services            |
| `make lint`            | Lint Flutter, Python, Go               |
| `make test`            | Run Flutter, Python, Go tests          |
| `make codegen`         | Run build_runner for code generation   |
| `make codegen-watch`   | Watch + auto-regenerate                |
| `make build`           | Build all Docker images                |
| `make deploy`          | Deploy to production (see Makefile)    |

## Code style

- **Flutter**: `flutter_lints` + `analysis_options.yaml` rules; `make lint-flutter`
- **Python**: `ruff check`; `make lint-python`
- **Go**: `go vet ./...`; `make lint-go`

## Pre-commit checks (recommended)

Before opening a PR:
1. `make lint` passes
2. `make test` passes
3. `make codegen` produces no diff
4. New env vars are documented in `.env.example`
5. Public API changes are reflected in `docs/`

## Flutter app: first-time setup notes

After pulling changes that touch one of the following, run `flutter pub
get` from `apps/superapp/`:

- A new dependency was added to `pubspec.yaml` (currently:
  `flutter_secure_storage` for the JWT, `flutter_localizations` for i18n).
- A new dep was promoted to a path package.

### Localisation (l10n)

`flutter_localizations` is wired up, but the `AppLocalizations` class
that `MaterialApp.router` references is **generated at build time**:

```bash
cd apps/superapp
flutter pub get
flutter gen-l10n
```

If you skip the second command the app will fail to compile with
`Target of URI doesn't exist: 'l10n/generated/app_localizations.dart'`.
The generated files live in `apps/superapp/lib/l10n/generated/` —
they are intentionally git-ignored.

To add a new string, edit `apps/superapp/lib/l10n/app_en.arb` (and the
matching key in `app_id.arb`), then re-run `flutter gen-l10n`.

## Adding a new API endpoint

1. Add the handler in `services/api_gateway/`
2. Register it in `services/api_gateway/main.go` (or relevant handler file)
3. Add a corresponding method in the relevant Flutter `*_api_client.dart`
4. Add the typed exception in the same file
5. Map the exception to a user-friendly message at the call site (not in the API client)

## Adding a new scholarship data source

1. Add the source URL to the crawler's seed list (`services/beasiswa_crawler/src/scraper.py`)
2. Test with `cd services/beasiswa_crawler && python -m beasiswa_scraper scrape`
3. The scheduler runs scrape + crawl on a daily cadence
