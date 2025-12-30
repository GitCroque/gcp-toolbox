#!/usr/bin/env bash
set -euo pipefail

# Script: check-preemptible-candidates.sh
# Description: Identifie les VMs candidates pour migration vers preemptible/spot
# Économies: jusqu'à 91% pour Spot VMs

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options (JSON_MODE et SINGLE_PROJECT définis dans common.sh)
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --project) SINGLE_PROJECT="$2"; shift 2 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

[[ "$JSON_MODE" == false ]] && {
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}  🎯 Preemptible/Spot Candidates${NC}"
    echo -e "${GREEN}======================================${NC}\n"
    echo -e "${YELLOW}Économies potentielles: jusqu'à 91%${NC}\n"
}

total=0; candidates=0; already_preemptible=0; potential_savings=0

[[ "$JSON_MODE" == true ]] && {
    echo '{"generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "candidates": ['
    first=true
} || {
    printf "%-25s %-30s %-20s %-15s %-20s\n" "PROJECT" "VM_NAME" "TYPE" "PREEMPTIBLE" "POTENTIAL_SAVING"
    printf "%-25s %-30s %-20s %-15s %-20s\n" "-------" "-------" "----" "-----------" "----------------"
}

project_list="${SINGLE_PROJECT:-$(gcloud projects list --format='value(projectId)')}"

while read -r proj; do
    [[ -z "$proj" ]] && continue
    
    vms=$(gcloud compute instances list --project="$proj" \
        --format='value(name,machineType,scheduling.preemptible,labels)' 2>/dev/null || echo "")
    
    while IFS=$'\t' read -r name machine_type is_preemptible labels; do
        [[ -z "$name" ]] && continue
        ((total++))
        
        machine_short=$(basename "$machine_type")
        
        if [[ "$is_preemptible" == "True" ]]; then
            ((already_preemptible++))
            continue
        fi
        
        # Critères pour candidat: pas de label "stateful", pas de "prod" stricte
        is_candidate=false
        saving=0
        
        if [[ ! "$labels" =~ stateful ]] && [[ ! "$labels" =~ critical ]]; then
            is_candidate=true
            ((candidates++))
            # Économie estimée: 80% du coût
            saving=80  # USD/mois (simulation)
            ((potential_savings+=saving))
        fi
        
        [[ "$is_candidate" == true ]] && {
            [[ "$JSON_MODE" == true ]] && {
                [[ "$first" == false ]] && echo ","
                first=false
                echo "    {\"project\":\"$proj\",\"vm\":\"$name\",\"type\":\"$machine_short\",\"preemptible\":false,\"savings\":$saving}"
            } || {
                printf "%-25s %-30s %-20s %-15s %-20s\n" \
                    "${proj:0:23}" "${name:0:28}" "${machine_short:0:18}" "${RED}No${NC}" "${GREEN}\$${saving}/mois${NC}"
            }
        }
    done <<< "$vms"
done <<< "$project_list"

[[ "$JSON_MODE" == true ]] && {
    echo '\n  ],'
    echo '  "summary": {'
    echo "    \"total\": $total, \"already_preemptible\": $already_preemptible,"
    echo "    \"candidates\": $candidates, \"potential_monthly_savings\": $potential_savings"
    echo '  }}'
} || {
    echo -e "\n${CYAN}=== Résumé ===${NC}"
    echo -e "Total VMs:                 ${BLUE}$total${NC}"
    echo -e "Déjà preemptible:          ${GREEN}$already_preemptible${NC}"
    echo -e "Candidates:                ${YELLOW}$candidates${NC}"
    echo -e "Économies potentielles:    ${GREEN}\$${potential_savings}/mois${NC}"
    echo -e "\n${CYAN}=== Migration ===${NC}"
    echo -e "Créer VM preemptible: ${BLUE}gcloud compute instances create VM --preemptible${NC}"
    echo -e "Ou Spot VM (>91% saving): ${BLUE}--provisioning-model=SPOT${NC}"
}
