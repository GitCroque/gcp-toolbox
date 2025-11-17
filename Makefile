# Makefile pour Carnet GCP
# Simplifie l'utilisation des scripts avec des commandes courtes

.PHONY: help setup audit security costs governance inventory dashboard watch clean

# Couleurs
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

help: ## Affiche cette aide
	@echo "$(CYAN)╔════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║          Carnet GCP - Makefile Commands               ║$(NC)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Exemples:$(NC)"
	@echo "  make setup      # Configuration initiale"
	@echo "  make audit      # Audit complet"
	@echo "  make dashboard  # Dashboard en temps réel"
	@echo ""

setup: ## Vérification prérequis et setup initial
	@echo "$(CYAN)🚀 Setup Carnet...$(NC)"
	@chmod +x scripts/*.sh
	@./scripts/setup-carnet.sh

audit: ## Exécute audit complet (sécurité + gouvernance + coûts)
	@echo "$(CYAN)🔍 Audit complet...$(NC)"
	@./scripts/run-full-audit.sh --output-dir ./audit-reports/audit-$(shell date +%Y%m%d-%H%M%S)

audit-critical: ## Audit rapide (seulement critiques)
	@echo "$(CYAN)🔍 Audit critique...$(NC)"
	@./scripts/run-full-audit.sh --critical-only

security: ## Audits de sécurité uniquement
	@echo "$(CYAN)🔐 Audits sécurité...$(NC)"
	@./scripts/scan-public-buckets.sh
	@./scripts/audit-firewall-rules.sh
	@./scripts/audit-service-account-keys.sh
	@./scripts/scan-exposed-services.sh
	@./scripts/audit-database-backups.sh

costs: ## Analyse des coûts et optimisations
	@echo "$(CYAN)💰 Analyse coûts...$(NC)"
	@./scripts/compare-vm-rightsizing.sh
	@./scripts/cleanup-old-projects.sh
	@./scripts/find-unused-resources.sh
	@./scripts/check-preemptible-candidates.sh

governance: ## Audits de gouvernance
	@echo "$(CYAN)🏛️  Audits gouvernance...$(NC)"
	@./scripts/notify-project-owners.sh --json > project-owners.json
	@./scripts/audit-resource-labels.sh
	@./scripts/generate-inventory-report.sh

inventory: ## Génère inventaire complet
	@echo "$(CYAN)📦 Inventaire...$(NC)"
	@./scripts/list-gcp-projects.sh
	@./scripts/list-all-vms.sh
	@./scripts/list-cloud-sql-instances.sh
	@./scripts/list-gke-clusters.sh

dashboard: ## Affiche dashboard de santé
	@./scripts/health-dashboard.sh

watch: ## Dashboard en mode watch (rafraîchit toutes les 30s)
	@./scripts/health-dashboard.sh --watch

# Exports JSON
export-json: ## Exporte tous les audits en JSON
	@echo "$(CYAN)📤 Export JSON...$(NC)"
	@mkdir -p exports
	@./scripts/scan-public-buckets.sh --json > exports/public-buckets.json
	@./scripts/audit-firewall-rules.sh --json > exports/firewall-rules.json
	@./scripts/list-all-vms.sh --json > exports/vms.json
	@./scripts/list-cloud-sql-instances.sh --json > exports/sql.json
	@./scripts/list-gke-clusters.sh --json > exports/gke.json
	@echo "$(GREEN)✓ Exports disponibles dans exports/$(NC)"

# Rapports
report: ## Génère rapport complet Markdown
	@./scripts/generate-inventory-report.sh --format markdown

report-html: ## Génère rapport HTML (nécessite pandoc)
	@./scripts/generate-inventory-report.sh --format markdown
	@echo "$(CYAN)Converting to HTML...$(NC)"
	@if command -v pandoc >/dev/null 2>&1; then \
		pandoc inventory-reports/inventory-report-*.md -o inventory-reports/report.html --standalone; \
		echo "$(GREEN)✓ Rapport HTML généré$(NC)"; \
	else \
		echo "$(YELLOW)⚠  pandoc non installé. Installez avec: apt install pandoc$(NC)"; \
	fi

# Nettoyage
clean: ## Nettoie les fichiers temporaires
	@echo "$(CYAN)🧹 Nettoyage...$(NC)"
	@rm -rf audit-reports/* inventory-reports/* exports/*
	@echo "$(GREEN)✓ Nettoyé$(NC)"

clean-all: clean ## Nettoyage complet (y compris caches)
	@rm -rf .cache/

# Tests
test: setup ## Teste que tous les scripts s'exécutent
	@echo "$(CYAN)🧪 Tests...$(NC)"
	@for script in scripts/*.sh; do \
		echo "Testing $$script..."; \
		bash -n $$script || exit 1; \
	done
	@echo "$(GREEN)✓ Tous les scripts sont valides$(NC)"

# Installation
install: setup ## Installe Carnet dans /usr/local/bin (nécessite sudo)
	@echo "$(CYAN)📦 Installation...$(NC)"
	@sudo mkdir -p /usr/local/bin/carnet
	@sudo cp -r scripts /usr/local/bin/carnet/
	@sudo cp -r docs /usr/local/bin/carnet/
	@echo "$(GREEN)✓ Installé dans /usr/local/bin/carnet$(NC)"
	@echo "$(YELLOW)Ajoutez au PATH: export PATH=\$$PATH:/usr/local/bin/carnet/scripts$(NC)"

# Version & Info
version: ## Affiche la version
	@echo "Carnet GCP v2.0.0 - Professional Edition"
	@echo "Scripts: $(shell ls -1 scripts/*.sh | wc -l)"
	@echo "Documentation: $(shell find docs -name '*.md' | wc -l) pages"

info: ## Informations sur le repository
	@echo "$(CYAN)╔════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║              Carnet GCP - Repository Info             ║$(NC)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Scripts:$(NC)         $(shell ls -1 scripts/*.sh | wc -l)"
	@echo "$(GREEN)Documentation:$(NC)   $(shell find docs -name '*.md' | wc -l) pages"
	@echo "$(GREEN)Workflows:$(NC)       $(shell ls -1 .github/workflows/*.yml 2>/dev/null | wc -l) GitHub Actions"
	@echo "$(GREEN)Dernière modif:$(NC) $(shell git log -1 --format=%cd --date=short 2>/dev/null || echo 'N/A')"
	@echo ""
