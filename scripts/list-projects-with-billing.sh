#!/usr/bin/env bash

#####################################################################
# Script: list-projects-with-billing.sh
# Description: Liste tous les projets GCP avec leurs informations de facturation
#              et compte de facturation associé
# Prérequis: gcloud CLI configuré et authentifié
#            Permissions nécessaires:
#            - resourcemanager.projects.get
#            - billing.accounts.get (optionnel, pour voir les détails de facturation)
# Usage: ./list-projects-with-billing.sh [--json]
#
# Note: Pour voir les coûts réels, vous devez activer l'export de facturation
#       vers BigQuery. Ce script montre uniquement les comptes de facturation liés.
#####################################################################

set -euo pipefail

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Mode JSON si argument --json (JSON_MODE défini dans common.sh)
if [[ "${1:-}" == "--json" ]]; then
    JSON_MODE=true
fi

# Fonction d'affichage de l'en-tête
print_header() {
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Projets GCP et Facturation${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
    fi
}

# Vérification que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud CLI n'est pas installé${NC}" >&2
    exit 1
fi

# Vérification de l'authentification
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}Erreur: Aucun compte gcloud actif trouvé${NC}" >&2
    exit 1
fi

print_header

# Compteurs
total_projects=0
projects_with_billing=0
projects_without_billing=0

if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "projects": ['
    first_project=true
else
    echo -e "${GREEN}Récupération des projets et de leurs informations de facturation...${NC}"
    echo ""
    printf "%-30s %-25s %-18s %-26s %-30s\n" \
        "PROJECT_ID" "NAME" "BILLING_ENABLED" "BILLING_ACCOUNT_ID" "BILLING_ACCOUNT_NAME"
    printf "%-30s %-25s %-18s %-26s %-30s\n" \
        "----------" "----" "---------------" "------------------" "--------------------"
fi

# Cache pour les noms des comptes de facturation
declare -A billing_account_names

# Liste tous les projets (substitution de processus pour éviter le sous-shell)
while IFS=$'\t' read -r project_id name project_number; do
    ((total_projects++)) || true

    # Récupère les informations de facturation pour ce projet
    billing_info=$(gcloud beta billing projects describe "$project_id" \
        --format="value(billingAccountName,billingEnabled)" 2>/dev/null || echo $'unknown\tunknown')

    IFS=$'\t' read -r billing_account billing_enabled <<< "$billing_info"

    # Extraction du nom du compte de facturation
    if [[ "$billing_account" != "unknown" && -n "$billing_account" ]]; then
        billing_account_id=$(basename "$billing_account")
        ((projects_with_billing++)) || true

        # Récupère le nom du compte de facturation (avec cache)
        if [[ -z "${billing_account_names[$billing_account_id]:-}" ]]; then
            billing_account_name=$(gcloud billing accounts describe "$billing_account_id" \
                --format="value(displayName)" 2>/dev/null || echo "N/A")
            billing_account_names[$billing_account_id]="$billing_account_name"
        else
            billing_account_name="${billing_account_names[$billing_account_id]}"
        fi
    else
        billing_account_id="none"
        billing_account_name="-"
        ((projects_without_billing++)) || true
    fi

    # Gestion du statut de facturation
    if [[ "$billing_enabled" == "True" || "$billing_enabled" == "true" ]]; then
        billing_status="enabled"
    elif [[ "$billing_enabled" == "False" || "$billing_enabled" == "false" ]]; then
        billing_status="disabled"
    else
        billing_status="unknown"
    fi

    if [[ "$JSON_MODE" == true ]]; then
        [[ "$first_project" == false ]] && echo ","
        first_project=false

        # Échapper les guillemets dans le nom
        safe_name=$(echo "$name" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

        safe_billing_name=$(echo "$billing_account_name" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        cat <<EOF
    {
      "project_id": "$project_id",
      "name": "$safe_name",
      "project_number": "$project_number",
      "billing_enabled": "$billing_status",
      "billing_account_id": "$billing_account_id",
      "billing_account_name": "$safe_billing_name"
    }
EOF
    else
        # Couleur selon le statut de facturation
        if [[ "$billing_status" == "enabled" ]]; then
            status_colored="${GREEN}enabled${NC}"
        elif [[ "$billing_status" == "disabled" ]]; then
            status_colored="${YELLOW}disabled${NC}"
        else
            status_colored="${RED}unknown${NC}"
        fi

        # Les codes ANSI ajoutent ~14 caractères invisibles, on compense
        printf "%-30s %-25s %-32b %-26s %-30s\n" \
            "${project_id:0:28}" \
            "${name:0:23}" \
            "$status_colored" \
            "${billing_account_id:0:24}" \
            "${billing_account_name:0:28}"
    fi
done < <(gcloud projects list --format="value(projectId,name,projectNumber)")

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "  ],"
    echo '  "summary": {'
    echo "    \"total_projects\": $total_projects,"
    echo "    \"projects_with_billing\": $projects_with_billing,"
    echo "    \"projects_without_billing\": $projects_without_billing"
    echo "  }"
    echo "}"
else
    echo ""
    echo -e "${CYAN}========== Résumé ==========${NC}"
    echo -e "Total projets:                ${BLUE}$total_projects${NC}"
    echo -e "Avec facturation activée:     ${GREEN}$projects_with_billing${NC}"
    echo -e "Sans facturation:             ${YELLOW}$projects_without_billing${NC}"
    echo ""
    echo -e "${YELLOW}Note: Pour voir les coûts réels, configurez l'export vers BigQuery${NC}"
    echo -e "${YELLOW}      Documentation: https://cloud.google.com/billing/docs/how-to/export-data-bigquery${NC}"
    echo ""
    echo -e "${CYAN}Pour voir les coûts par projet via BigQuery:${NC}"
    echo -e "  1. Activez l'export de facturation vers BigQuery"
    echo -e "  2. Utilisez des requêtes SQL pour analyser les coûts"
fi
