.PHONY: help lint test dev prod clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Development ──────────────────────────────────────────────────────────────

dev: ## Start all services in development mode
	docker compose up -d

dev-down: ## Stop development services
	docker compose down

dev-logs: ## Tail all service logs
	docker compose logs -f

# ─── Lint ────────────────────────────────────────────────────────────────────

lint: lint-flutter lint-python lint-go ## Run all linters

lint-flutter: ## Lint Flutter app
	cd apps/superapp && flutter analyze

lint-python: ## Lint Python services
	cd services/mcp_trade && ruff check .
	cd services/mcp_scholarship && ruff check .
	cd services/beasiswa_crawler && ruff check .

lint-go: ## Lint Go API gateway
	cd services/api_gateway && go vet ./...

# ─── Test ────────────────────────────────────────────────────────────────────

test: test-flutter test-python test-go ## Run all tests

test-flutter: ## Run Flutter tests
	cd apps/superapp && flutter test

test-python: ## Run Python tests
	cd services/beasiswa_crawler && python -m pytest

test-go: ## Run Go tests
	cd services/api_gateway && go test ./...

# ─── Build ────────────────────────────────────────────────────────────────────

build: ## Build all Docker images
	docker compose build

build-flutter-web: ## Build Flutter for web
	cd apps/superapp && flutter build web

build-flutter-apk: ## Build Flutter for Android
	cd apps/superapp && flutter build apk

# ─── Deploy ───────────────────────────────────────────────────────────────────

deploy: ## Deploy to production
	scp -r docker-compose.prod.yml evans@100.110.59.78:~/Project/superapp/
	ssh evans@100.110.59.78 'cd ~/Project/superapp && docker compose -f docker-compose.prod.yml up -d --build'

# ─── Clean ────────────────────────────────────────────────────────────────────

clean: ## Clean all build artifacts
	cd apps/superapp && flutter clean
	docker compose down -v
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
