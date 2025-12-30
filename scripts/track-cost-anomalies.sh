#!/usr/bin/env bash
set -euo pipefail

# Script: track-cost-anomalies.sh
# Description: Détecte les anomalies de coûts GCP (pics, croissance anormale)
# Nécessite: Export de facturation vers BigQuery configuré

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options locales (JSON_MODE défini dans common.sh)
THRESHOLD=20  # % d'augmentation pour alerter
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

[[ "$JSON_MODE" == false ]] && {
    echo -e "${RED}======================================${NC}"
    echo -e "${RED}  📊 Cost Anomalies Detection${NC}"
    echo -e "${RED}======================================${NC}\n"
    echo -e "${YELLOW}Seuil d'alerte: +${THRESHOLD}% vs mois précédent${NC}\n"
}

# Note: Ce script nécessite BigQuery avec export de facturation
# Pour la démo, on simule les données

total_projects=0; anomalies=0

[[ "$JSON_MODE" == true ]] && {
    echo '{"generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo "  \"threshold_percent\": $THRESHOLD,"
    echo '  "anomalies": ['
    first=true
} || {
    printf "%-30s %-15s %-15s %-15s %-15s\n" "PROJECT/SERVICE" "LAST_MONTH" "THIS_MONTH" "CHANGE" "STATUS"
    printf "%-30s %-15s %-15s %-15s %-15s\n" "---------------" "----------" "----------" "------" "------"
}

# Simulation de données
projects=("prod-app" "dev-env" "data-analytics" "ml-training")
services=("Compute Engine" "Cloud Storage" "BigQuery" "Cloud SQL")

for proj in "${projects[@]}"; do
    ((total_projects++))
    
    for svc in "${services[@]}"; do
        last_month=$((RANDOM % 1000 + 100))
        change_pct=$((RANDOM % 60 - 10))  # -10% à +50%
        this_month=$(( last_month + (last_month * change_pct / 100) ))
        
        status="OK"
        if [[ $change_pct -gt $THRESHOLD ]]; then
            status="ANOMALY"
            ((anomalies++))
            
            [[ "$JSON_MODE" == true ]] && {
                [[ "$first" == false ]] && echo ","
                first=false
                echo "    {\"project\":\"$proj\",\"service\":\"$svc\",\"last_month\":$last_month,\"this_month\":$this_month,\"change_percent\":$change_pct}"
            } || {
                status_display="${RED}ANOMALY${NC}"
                change_display="${RED}+${change_pct}%${NC}"
                printf "%-30s %-15s %-15s %-24s %-24s\n" \
                    "${proj}/${svc:0:15}" "\$${last_month}" "\$${this_month}" "$change_display" "$status_display"
            }
        fi
    done
done

[[ "$JSON_MODE" == true ]] && {
    echo '\n  ],'
    echo '  "summary": {'
    echo "    \"projects_analyzed\": $total_projects, \"anomalies_detected\": $anomalies"
    echo '  }}'
} || {
    echo -e "\n${CYAN}=== Résumé ===${NC}"
    echo -e "Projets analysés:       ${BLUE}$total_projects${NC}"
    echo -e "Anomalies détectées:    ${RED}$anomalies${NC}"
    echo -e "\n${YELLOW}Note: Ce script nécessite BigQuery avec export de facturation.${NC}"
    echo -e "${YELLOW}Configuration: ${BLUE}https://cloud.google.com/billing/docs/how-to/export-data-bigquery${NC}"
    echo -e "\n${CYAN}Requête BigQuery exemple:${NC}"
    echo -e "${BLUE}SELECT project.id, service.description, SUM(cost) as total"
    echo -e "FROM \`project.dataset.gcp_billing_export_v1_XXXXX\`"
    echo -e "WHERE _PARTITIONTIME >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)"
    echo -e "GROUP BY 1,2 ORDER BY total DESC${NC}"
}
