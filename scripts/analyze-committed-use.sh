#!/usr/bin/env bash
set -euo pipefail

# Script: analyze-committed-use.sh
# Description: Analyse les Committed Use Discounts (CUD) et recommandations

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# JSON_MODE défini dans common.sh
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

[[ "$JSON_MODE" == false ]] && {
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  💎 Committed Use Discounts (CUD)${NC}"
    echo -e "${GREEN}======================================${NC}\n"
    echo -e "${YELLOW}Les CUDs offrent jusqu'à 57% d'économies sur compute${NC}\n"
}

total_commitments=0; active=0; expired=0

[[ "$JSON_MODE" == true ]] && {
    echo '{"generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "commitments": ['
    first=true
} || {
    printf "%-30s %-20s %-15s %-15s %-15s\n" "PROJECT" "TYPE" "REGION" "STATUS" "END_DATE"
    printf "%-30s %-20s %-15s %-15s %-15s\n" "-------" "----" "------" "------" "--------"
}

project_list=$(gcloud projects list --format='value(projectId)')

while read -r proj; do
    [[ -z "$proj" ]] && continue
    
    commitments=$(gcloud compute commitments list --project="$proj" --format='value(name,region,status,endTimestamp)' 2>/dev/null || echo "")
    
    while IFS=$'\t' read -r name region status end_date; do
        [[ -z "$name" ]] && continue
        ((total_commitments++))
        
        [[ "$status" == "ACTIVE" ]] && ((active++)) || ((expired++))
        
        [[ "$JSON_MODE" == true ]] && {
            [[ "$first" == false ]] && echo ","
            first=false
            echo "    {\"project\":\"$proj\",\"name\":\"$name\",\"region\":\"$region\",\"status\":\"$status\",\"end_date\":\"${end_date:0:10}\"}"
        } || {
            status_display="$status"
            [[ "$status" == "ACTIVE" ]] && status_display="${GREEN}ACTIVE${NC}" || status_display="${YELLOW}$status${NC}"
            printf "%-30s %-20s %-15s %-24s %-15s\n" "${proj:0:28}" "${name:0:18}" "${region:0:13}" "$status_display" "${end_date:0:10}"
        }
    done <<< "$commitments"
done <<< "$project_list"

[[ "$JSON_MODE" == true ]] && {
    echo '\n  ],'
    echo '  "summary": {'
    echo "    \"total\": $total_commitments, \"active\": $active, \"expired\": $expired"
    echo '  }}'
} || {
    echo -e "\n${CYAN}=== Résumé ===${NC}"
    echo -e "Total commitments:      ${BLUE}$total_commitments${NC}"
    echo -e "Actifs:                 ${GREEN}$active${NC}"
    echo -e "Expirés:                ${YELLOW}$expired${NC}"
    echo -e "\n${CYAN}=== Recommandations ===${NC}"
    echo -e "1. Analysez votre usage stable compute sur 1 an"
    echo -e "2. CUD 1 an: ${GREEN}~25% économies${NC}, 3 ans: ${GREEN}~57% économies${NC}"
    echo -e "3. Consultez: ${BLUE}gcloud compute commitments create${NC}"
}
