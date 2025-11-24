#!/bin/bash

#####################################################################
# Script: list-cloud-sql-instances.sh
# Description: Liste toutes les instances Cloud SQL avec leurs
#              configurations de sécurité, backup, HA et coûts
# Prérequis: gcloud CLI configuré et authentifié
#            Permissions nécessaires:
#            - cloudsql.instances.list
#            - cloudsql.instances.get
# Usage: ./list-cloud-sql-instances.sh [OPTIONS]
#
# Options:
#   --json           : Sortie en format JSON
#   --project PROJECT: Lister un seul projet
#####################################################################

set -euo pipefail

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options
JSON_MODE=false
SINGLE_PROJECT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --project) SINGLE_PROJECT="$2"; shift 2 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

print_header() {
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  💾 Cloud SQL Instances${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
    fi
}

# Prix estimatifs Cloud SQL (USD/mois, us-central1)
declare -A SQL_COSTS=(
    ["db-f1-micro"]=10
    ["db-g1-small"]=30
    ["db-n1-standard-1"]=50
    ["db-n1-standard-2"]=100
    ["db-n1-standard-4"]=200
    ["db-n1-highmem-2"]=150
    ["db-n1-highmem-4"]=300
)

get_estimated_cost() {
    local tier=$1
    # Compatibilité Bash 3.2+ (macOS) - évite -v qui nécessite Bash 4.2+
    local cost="${SQL_COSTS[$tier]:-}"
    if [[ -n "$cost" ]]; then
        echo "$cost"
    else
        echo "?"
    fi
}

# Vérifications
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud CLI non installé${NC}" >&2
    exit 1
fi

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}Erreur: Non authentifié${NC}" >&2
    exit 1
fi

print_header

total_instances=0
mysql_instances=0
postgres_instances=0
sqlserver_instances=0
total_cost=0
ha_enabled=0
backup_enabled=0

if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "sql_instances": ['
    first_instance=true
else
    echo -e "${GREEN}Récupération des instances Cloud SQL...${NC}"
    echo ""
    printf "%-25s %-30s %-12s %-20s %-10s %-10s %-10s %-12s\n" \
        "PROJECT_ID" "INSTANCE_NAME" "DB_VERSION" "TIER" "REGION" "HA" "BACKUP" "COST/MONTH"
    printf "%-25s %-30s %-12s %-20s %-10s %-10s %-10s %-12s\n" \
        "----------" "-------------" "----------" "----" "------" "--" "------" "----------"
fi

# Liste projets
if [[ -n "$SINGLE_PROJECT" ]]; then
    project_list="$SINGLE_PROJECT"
else
    project_list=$(gcloud projects list --format="value(projectId)")
fi

while read -r project_id; do
    [[ -z "$project_id" ]] && continue

    instances=$(gcloud sql instances list \
        --project="$project_id" \
        --format="value(name,databaseVersion,region,settings.tier,settings.availabilityType,settings.backupConfiguration.enabled)" \
        2>/dev/null || echo "")

    if [[ -n "$instances" ]]; then
        while IFS=$'\t' read -r name db_version region tier availability backup; do
            [[ -z "$name" ]] && continue
            ((total_instances++))

            # Compte par type
            if [[ "$db_version" == MYSQL* ]]; then
                ((mysql_instances++))
            elif [[ "$db_version" == POSTGRES* ]]; then
                ((postgres_instances++))
            elif [[ "$db_version" == SQLSERVER* ]]; then
                ((sqlserver_instances++))
            fi

            # HA
            ha="No"
            if [[ "$availability" == "REGIONAL" ]]; then
                ha="Yes"
                ((ha_enabled++))
            fi

            # Backup
            backup_status="No"
            if [[ "$backup" == "True" ]] || [[ "$backup" == "true" ]]; then
                backup_status="Yes"
                ((backup_enabled++))
            fi

            # Coût
            cost=$(get_estimated_cost "$tier")
            if [[ "$cost" != "?" ]]; then
                if [[ "$ha" == "Yes" ]]; then
                    cost=$((cost * 2))
                fi
                ((total_cost+=cost))
            fi

            if [[ "$JSON_MODE" == true ]]; then
                [[ "$first_instance" == false ]] && echo ","
                first_instance=false
                cat <<EOF
    {
      "project_id": "$project_id",
      "name": "$name",
      "database_version": "$db_version",
      "region": "$region",
      "tier": "$tier",
      "ha_enabled": "$ha",
      "backup_enabled": "$backup_status",
      "estimated_monthly_cost_usd": "$cost"
    }
EOF
            else
                # Couleurs
                ha_display="$ha"
                backup_display="$backup_status"
                if [[ "$ha" == "No" ]]; then
                    ha_display="${YELLOW}No${NC}"
                else
                    ha_display="${GREEN}Yes${NC}"
                fi
                if [[ "$backup_status" == "No" ]]; then
                    backup_display="${RED}No${NC}"
                else
                    backup_display="${GREEN}Yes${NC}"
                fi

                printf "%-25s %-30s %-12s %-20s %-10s %-18s %-18s %-12s\n" \
                    "${project_id:0:23}" \
                    "${name:0:28}" \
                    "${db_version:0:10}" \
                    "${tier:0:18}" \
                    "${region:0:8}" \
                    "$ha_display" \
                    "$backup_display" \
                    "\$${cost}"
            fi
        done <<< "$instances"
    fi
done <<< "$project_list"

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "  ],"
    echo '  "summary": {'
    echo "    \"total_instances\": $total_instances,"
    echo "    \"mysql_instances\": $mysql_instances,"
    echo "    \"postgres_instances\": $postgres_instances,"
    echo "    \"sqlserver_instances\": $sqlserver_instances,"
    echo "    \"ha_enabled_count\": $ha_enabled,"
    echo "    \"backup_enabled_count\": $backup_enabled,"
    echo "    \"estimated_monthly_cost_usd\": $total_cost"
    echo "  }"
    echo "}"
else
    echo ""
    echo -e "${CYAN}========== Résumé ==========${NC}"
    echo -e "Total instances:           ${BLUE}$total_instances${NC}"
    echo -e "  - MySQL:                 ${BLUE}$mysql_instances${NC}"
    echo -e "  - PostgreSQL:            ${BLUE}$postgres_instances${NC}"
    echo -e "  - SQL Server:            ${BLUE}$sqlserver_instances${NC}"
    echo -e "HA activée:                ${GREEN}$ha_enabled${NC} / $total_instances"
    echo -e "Backup activé:             ${GREEN}$backup_enabled${NC} / $total_instances"
    echo -e "Coût estimé/mois:          ${CYAN}\$${total_cost} USD${NC}"
    echo ""

    if [[ $((total_instances - backup_enabled)) -gt 0 ]]; then
        echo -e "${RED}⚠️  $((total_instances - backup_enabled)) instance(s) sans backup automatique !${NC}"
        echo ""
    fi

    echo -e "${CYAN}========== Recommandations ==========${NC}"
    echo ""
    echo -e "${YELLOW}Best Practices Cloud SQL :${NC}"
    echo ""
    echo -e "1. ${GREEN}Activer les backups automatiques${NC} (CRITICAL)"
    echo -e "2. ${GREEN}Activer High Availability${NC} pour production"
    echo -e "3. ${GREEN}Utiliser des versions récentes${NC} de DB"
    echo -e "4. ${GREEN}Configurer des maintenance windows${NC}"
    echo -e "5. ${GREEN}Activer SSL/TLS${NC} pour les connexions"
    echo -e "6. ${GREEN}Utiliser Private IP${NC} au lieu de Public IP"
    echo -e "7. ${GREEN}Monitorer les performances${NC} via Cloud Monitoring"
fi
