#!/bin/bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

JSON_MODE=false; SINGLE_PROJECT=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --project) SINGLE_PROJECT="$2"; shift 2 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2; exit 1
fi

[[ "$JSON_MODE" == false ]] && {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  ☸️  GKE Clusters${NC}"
    echo -e "${BLUE}======================================${NC}\n"
}

total=0; total_nodes=0; autopilot=0; standard=0

[[ "$JSON_MODE" == true ]] && {
    echo '{"generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "clusters": ['
    first=true
} || {
    echo -e "${GREEN}Récupération des clusters GKE...${NC}\n"
    printf "%-25s %-25s %-15s %-15s %-10s %-15s\n" "PROJECT" "CLUSTER" "LOCATION" "VERSION" "NODES" "MODE"
    printf "%-25s %-25s %-15s %-15s %-10s %-15s\n" "-------" "-------" "--------" "-------" "-----" "----"
}

project_list="${SINGLE_PROJECT:-$(gcloud projects list --format='value(projectId)')}"

while read -r proj; do
    [[ -z "$proj" ]] && continue
    clusters=$(gcloud container clusters list --project="$proj" --format='value(name,location,currentMasterVersion,currentNodeCount,autopilot.enabled)' 2>/dev/null || echo "")
    
    while IFS=$'\t' read -r name location version node_count is_autopilot; do
        [[ -z "$name" ]] && continue
        ((total++))
        ((total_nodes+=node_count))
        
        mode="Standard"
        [[ "$is_autopilot" == "True" ]] && { mode="Autopilot"; ((autopilot++)); } || ((standard++))
        
        [[ "$JSON_MODE" == true ]] && {
            [[ "$first" == false ]] && echo ","
            first=false
            echo "    {\"project\":\"$proj\",\"name\":\"$name\",\"location\":\"$location\",\"version\":\"$version\",\"nodes\":$node_count,\"mode\":\"$mode\"}"
        } || {
            mode_display="$mode"
            [[ "$mode" == "Autopilot" ]] && mode_display="${GREEN}Autopilot${NC}" || mode_display="${BLUE}Standard${NC}"
            printf "%-25s %-25s %-15s %-15s %-10s %-24s\n" "${proj:0:23}" "${name:0:23}" "${location:0:13}" "${version:0:13}" "$node_count" "$mode_display"
        }
    done <<< "$clusters"
done <<< "$project_list"

[[ "$JSON_MODE" == true ]] && {
    echo '\n  ],'
    echo '  "summary": {'
    echo "    \"total\": $total, \"total_nodes\": $total_nodes, \"autopilot\": $autopilot, \"standard\": $standard"
    echo '  }}'
} || {
    echo -e "\n${CYAN}=== Résumé ===${NC}"
    echo -e "Total clusters:         ${BLUE}$total${NC}"
    echo -e "Total nodes:            ${BLUE}$total_nodes${NC}"
    echo -e "Autopilot clusters:     ${GREEN}$autopilot${NC}"
    echo -e "Standard clusters:      ${BLUE}$standard${NC}"
}
