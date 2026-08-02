.PHONY: help run stop restart build clean install logs test shell db-shell \
       cache-clear setup dev prod backup restore lint deploy odoo-sync \
       health-check jwt-keys db-reset db-migrate db-seed

# ============================================================
# Nayo - Build & Deployment Automation
# ============================================================
# Usage: make <target>
# Run 'make help' for a list of available targets.
# ============================================================

# ---------- Configuration ----------

SERVICE         ?=
PROJECT_NAME    := nayo
COMPOSE_DIR     := docker
COMPOSE_FILE    := $(COMPOSE_DIR)/docker-compose.yml
COMPOSE_DEV     := $(COMPOSE_DIR)/docker-compose.dev.yml
COMPOSE_PROD    := $(COMPOSE_DIR)/docker-compose.prod.yml
BACKUP_DIR      := ./backups
TIMESTAMP       := $(shell date +%Y%m%d_%H%M%S)

# Detect if local override exists
DOCKER_COMPOSE_LOCAL = $(COMPOSE_DIR)/docker-compose.local.yml
ifeq ($(shell test -f $(DOCKER_COMPOSE_LOCAL) && echo yes),yes)
  COMPOSE_FILE := $(DOCKER_COMPOSE_LOCAL)
endif

DC = docker-compose -f $(COMPOSE_FILE)
DC_DEV = docker-compose -f $(COMPOSE_DEV)

# ---------- Help ----------

help: ## Show this help message
	@echo "Nayo - Loyalty Platform Makefile"
	@echo "================================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---------- Core Operations ----------

run: ## Start all services
	$(DC) up -d

stop: ## Stop all services
	$(DC) stop

restart: ## Restart services (or specific SERVICE=name)
	$(DC) restart $(SERVICE)

build: ## Build and start with fresh images
	$(DC) up -d --build --force-recreate

clean: ## Remove all containers, networks, and volumes
	-$(DC) down -v --remove-orphans

logs: ## Tail logs (follow mode)
	$(DC) logs --tail=100 -f

ps: ## Show running containers
	$(DC) ps

# ---------- Setup & Install ----------

setup: run ## Full first-time setup (start + init database)
	$(DC) exec -T php phing setup
	$(DC) exec -T php bin/console cache:clear
	$(DC) exec -T php chown -R www-data:www-data var/
	@echo ""
	@echo "Nayo is ready!"
	@echo "  Admin:    http://nayo.localhost:8182"
	@echo "  Customer: http://nayo.localhost:8183"
	@echo "  Merchant: http://nayo.localhost:8184"
	@echo "  API:      http://nayo.localhost"
	@echo "  API Docs: http://nayo.localhost/doc"

install: run ## Install dependencies and setup database
	$(DC) exec -T php composer install
	$(DC) exec -T php phing setup
	$(DC) exec -T php bin/console cache:clear
	$(DC) exec -T php chown -R www-data:www-data var/

# ---------- Development ----------

dev: ## Start development environment with live reload
	$(DC_DEV) up -d --build

dev-logs: ## Tail development logs
	$(DC_DEV) logs --tail=100 -f

dev-stop: ## Stop development environment
	$(DC_DEV) stop

dev-clean: ## Clean development environment
	-$(DC_DEV) down -v --remove-orphans

shell: run ## Open shell in PHP container
	$(DC) exec php bash

db-shell: run ## Open PostgreSQL shell
	$(DC) exec db psql -U nayo -d nayo

frontend-shell: run ## Open shell in frontend container
	$(DC) exec frontend bash

composer-install: run ## Run composer install
	$(DC) exec -T php composer install

composer-update: run ## Run composer update
	$(DC) exec -T php composer update

cache-clear: run ## Clear Symfony cache
	$(DC) exec -T php bin/console cache:clear
	$(DC) exec -T php chown -R www-data:www-data var/

jwt-keys: run ## Generate JWT keys
	$(DC) exec -T php phing generate-jwt-keys

# ---------- Testing ----------

test: run ## Run all tests
	$(DC) exec -T php phing generate-jwt-keys
	$(DC) exec -T php bin/console doctrine:schema:drop --env=test --force
	$(DC) exec -T php bin/console doctrine:schema:create --env=test
	$(DC) exec -T php bin/console oloy:user:projections:index:create --drop-old
	$(DC) exec -T php bin/console doctrine:schema:update --env=test -n --force
	$(DC) exec -T php bin/console broadway:event-store:schema:drop
	$(DC) exec -T php bin/console broadway:event-store:schema:init
	$(DC) exec -T php bin/console doctrine:fixtures:load --env=test -n
	$(DC) exec -T php bin/console assets:install --env=test
	$(DC) exec -T php bin/console doctrine:schema:validate --env=test --skip-sync
	$(DC) exec -T php bash -c "SYMFONY_DEPRECATIONS_HELPER=disabled vendor/phpunit/phpunit/phpunit -d memory_limit=-1"

test-security: run ## Run security tests
	$(DC) exec -T php phing test-security

ci-setup-test: run ## Setup CI test environment
	$(DC) exec -T php phing ci-setup-test

lint: ## Run PHP linting
	$(DC) exec -T php bash -c "find src/ -name '*.php' -exec php -l {} \;"

# ---------- Database ----------

db-reset: run ## Drop and recreate database
	$(DC) exec -T php bin/console doctrine:schema:drop --force --full-database
	$(DC) exec -T php bin/console doctrine:schema:create
	$(DC) exec -T php phing setup

db-migrate: run ## Run database migrations
	$(DC) exec -T php bin/console doctrine:migrations:migrate -n

db-seed: run ## Load fixtures / seed data
	$(DC) exec -T php bin/console doctrine:fixtures:load -n

backup: ## Backup PostgreSQL database
	@mkdir -p $(BACKUP_DIR)
	$(DC) exec -T db pg_dump -U nayo nayo > $(BACKUP_DIR)/nayo_$(TIMESTAMP).sql
	@echo "Backup saved: $(BACKUP_DIR)/nayo_$(TIMESTAMP).sql"

restore: ## Restore database from backup (BACKUP_FILE=path/to/file.sql)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "Usage: make restore BACKUP_FILE=path/to/backup.sql"; \
		exit 1; \
	fi
	$(DC) exec -T db psql -U nayo -d nayo < $(BACKUP_FILE)
	@echo "Database restored from: $(BACKUP_FILE)"

# ---------- Health & Monitoring ----------

health-check: ## Check service health
	@echo "Checking Nayo services..."
	@echo "---"
	@curl -sf http://nayo.localhost/api/healthcheck 2>/dev/null && echo " [OK] API" || echo " [FAIL] API"
	@curl -sf http://nayo.localhost:8182 2>/dev/null && echo " [OK] Admin Panel" || echo " [FAIL] Admin Panel"
	@curl -sf http://nayo.localhost:8183 2>/dev/null && echo " [OK] Customer Panel" || echo " [FAIL] Customer Panel"
	@curl -sf http://nayo.localhost:8184 2>/dev/null && echo " [OK] Merchant Panel" || echo " [FAIL] Merchant Panel"
	@curl -sf http://nayo.localhost:8186 2>/dev/null && echo " [OK] MailHog" || echo " [FAIL] MailHog"
	@echo "---"
	@echo "Container status:"
	@$(DC) ps

# ---------- Odoo Integration ----------

odoo-sync: ## Sync customers from Odoo to Nayo (requires ODOO_URL env var)
	@if [ -z "$(ODOO_URL)" ]; then \
		echo "Error: Set ODOO_URL environment variable"; \
		echo "Usage: ODOO_URL=http://odoo:8069 ODOO_DB=mydb make odoo-sync"; \
		exit 1; \
	fi
	@echo "Syncing customers from Odoo at $(ODOO_URL)..."
	@python3 scripts/odoo_sync.py \
		--odoo-url="$(ODOO_URL)" \
		--odoo-db="$(ODOO_DB)" \
		--odoo-user="$(ODOO_USER)" \
		--odoo-password="$(ODOO_PASSWORD)" \
		--nayo-url="http://nayo.localhost" \
		--nayo-api-key="$(NAYO_API_KEY)"

# ---------- Deployment ----------

deploy: ## Deploy to production (uses docker-compose.prod.yml)
	@echo "Deploying Nayo to production..."
	docker-compose -f $(COMPOSE_PROD) pull
	docker-compose -f $(COMPOSE_PROD) up -d --remove-orphans
	docker-compose -f $(COMPOSE_PROD) exec -T php bin/console cache:clear
	@echo "Deployment complete."

deploy-rollback: ## Rollback to previous images
	@echo "Rolling back..."
	docker-compose -f $(COMPOSE_PROD) up -d --remove-orphans
	@echo "Rollback complete."

prod: ## Start production environment
	docker-compose -f $(COMPOSE_PROD) up -d

prod-logs: ## Tail production logs
	docker-compose -f $(COMPOSE_PROD) logs --tail=100 -f

# ---------- Utility ----------

find-credentials: ## Scan for hardcoded credentials
	python3 FIND_DB_CREDENTIALS.py --project-dir . --include-env

update-hosts: ## Add nayo.localhost to /etc/hosts
	@grep -q "nayo.localhost" /etc/hosts 2>/dev/null && \
		echo "nayo.localhost already in /etc/hosts" || \
		echo "127.0.0.1 nayo.localhost" | sudo tee -a /etc/hosts

generate-api-docs: run ## Regenerate API documentation
	$(DC) exec -T php bin/console nelmio:apidoc:dump

# ---------- All Phony ----------

.DEFAULT: help
