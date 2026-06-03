.PHONY: help lint test dev prod clean codegen codegen-watch codegen-clean

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
	cd services/beasiswa_crawler && ruff check .
	# services/mcp_scholarship is a stub (only .gitkeep); will be added when implemented

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

# Deploy target is configured via environment:
#   export DEPLOY_HOST=user@host.example.com
#   export DEPLOY_PATH=/home/user/Project/superapp
# Add to ~/.zshrc / ~/.bashrc, or use a .env.deploy file (gitignored).
#
# DEPLOY_SSH_KEY defaults to ~/.ssh/id_rsa; override with DEPLOY_SSH_KEY for non-default paths.
deploy: ## Deploy to production (requires DEPLOY_HOST, DEPLOY_PATH)
	@test -n "$$DEPLOY_HOST" || (echo "ERROR: DEPLOY_HOST not set (e.g., user@host.example.com)" && exit 1)
	@test -n "$$DEPLOY_PATH" || (echo "ERROR: DEPLOY_PATH not set (e.g., /home/user/Project/superapp)" && exit 1)
	scp -i $${DEPLOY_SSH_KEY:-~/.ssh/id_rsa} docker-compose.yml docker-compose.prod.yml $$DEPLOY_HOST:$$DEPLOY_PATH/
	ssh -i $${DEPLOY_SSH_KEY:-~/.ssh/id_rsa} $$DEPLOY_HOST 'cd $$DEPLOY_PATH && docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build'

# ─── Clean ────────────────────────────────────────────────────────────────────

clean: ## Clean all build artifacts
	cd apps/superapp && flutter clean
	docker compose down -v
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

# ─── Code generation ────────────────────────────────────────────────────────

codegen: ## Run build_runner for freezed/json_serializable
	cd apps/superapp && dart run build_runner build --delete-conflicting-outputs
	cd packages/shared_models && dart run build_runner build --delete-conflicting-outputs

codegen-watch: ## Watch and re-run build_runner on changes
	cd apps/superapp && dart run build_runner watch --delete-conflicting-outputs

codegen-clean: ## Clean build_runner outputs and rebuild
	cd apps/superapp && dart run build_runner clean
	cd packages/shared_models && dart run build_runner clean
