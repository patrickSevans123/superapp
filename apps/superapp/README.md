# Superapp Flutter Client

Flutter app (Android, iOS, Web) for the Superapp monorepo. Combines Trade, Fashion, and Scholarship modules into a single UX with shared auth and design system.

## Features

- **Trade** — research reports, daily reports, trading plans, market news
- **Fashion** — wardrobe management, OOTD suggestions, virtual try-on
- **Scholarship** — browse, search, save scholarships (LPDP, international)
- **Profile / Settings** — account, notification preferences

## Running locally

Configuration is passed at build time via `--dart-define` (the app no longer reads a bundled `.env` file):

```bash
cd apps/superapp
flutter pub get

# Default API base URL is http://localhost:8080/api/v1
flutter run

# Or override the API base URL:
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8080/api/v1

# Web release build:
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

## Project structure

```
lib/
├── main.dart                  # App entry + runZonedGuarded error handlers
├── app.dart                   # MaterialApp.router + auth-gated router swap
├── core/
│   ├── network/               # Shared Dio + auth interceptor
│   ├── router/                # GoRouter config + route constants
│   ├── notifications/         # In-app notification banner
│   └── widgets/               # Shared app-level widgets
└── features/
    ├── auth/                  # Login, register, JWT storage
    ├── trade/                 # Trade research, plans, news
    ├── fashion/               # Wardrobe, OOTD, try-on
    ├── scholarship/           # Browse, search, save
    ├── lpdp/                  # LPDP-specific scholarship module
    ├── profile/               # User profile
    └── settings/              # App settings
```

## Code generation

Some models and providers use `freezed` / `json_serializable` / `riverpod_generator`. After pulling new generated code, run:

```bash
make codegen           # One-shot
make codegen-watch     # Watch mode
```

See the root [README.md](../../README.md) for the full monorepo overview.
