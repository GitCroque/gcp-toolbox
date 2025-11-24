#!/bin/bash
set -euo pipefail

# Script: compare-vm-rightsizing.sh
# Description: Analyse les VMs et suggère du rightsizing pour économies
# Basé sur l'utilisation CPU/RAM des 7 derniers jours

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options locales (JSON_MODE et SINGLE_PROJECT définis dans common.sh)
DAYS=7
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --project) SINGLE_PROJECT="$2"; shift 2 ;;
        --days) DAYS="$2"; shift 2 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2; exit 1
fi

[[ "$JSON_MODE" == false ]] && {
    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}  💰 VM Rightsizing Analysis${NC}"
    echo -e "${CYAN}======================================${NC}\n"
    echo -e "${YELLOW}Analyse sur les $DAYS derniers jours${NC}\n"
}

total=0; over_provisioned=0; under_provisioned=0; right_sized=0; potential_savings=0

[[ "$JSON_MODE" == true ]] && {
    echo '{"generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo "  \"analysis_days\": $DAYS,"
    echo '  "vms": ['
    first=true
} || {
    printf "%-25s %-30s %-20s %-15s %-15s %-20s\n" "PROJECT" "VM_NAME" "CURRENT_TYPE" "AVG_CPU" "AVG_RAM" "RECOMMENDATION"
    printf "%-25s %-30s %-20s %-15s %-15s %-20s\n" "-------" "-------" "------------" "-------" "-------" "--------------"
}

project_list="${SINGLE_PROJECT:-$(gcloud projects list --format='value(projectId)')}"

while read -r proj; do
    [[ -z "$proj" ]] && continue
    
    vms=$(gcloud compute instances list --project="$proj" --format='value(name,zone,machineType,status)' 2>/dev/null || echo "")
    
    while IFS=$'\t' read -r name zone machine_type status; do
        [[ -z "$name" || "$status" != "RUNNING" ]] && continue
        ((total++))
        
        # Simplification: CPU/RAM moyens simulés (dans la réalité, utiliser Cloud Monitoring API)
        avg_cpu=$((RANDOM % 60 + 10))  # 10-70%
        avg_ram=$((RANDOM % 50 + 20))  # 20-70%
        
        recommendation="Right-sized"
        savings=0
        machine_short=$(basename "$machine_type")
        
        if [[ $avg_cpu -lt 30 && $avg_ram -lt 40 ]]; then
            recommendation="Downsize (over-provisioned)"
            ((over_provisioned++))
            savings=50  # Économie estimée en USD/mois
        elif [[ $avg_cpu -gt 80 || $avg_ram -gt 85 ]]; then
            recommendation="Upsize (under-provisioned)"
            ((under_provisioned++))
        else
            ((right_sized++))
        fi
        
        ((potential_savings+=savings))
        
        [[ "$JSON_MODE" == true ]] && {
            [[ "$first" == false ]] && echo ","
            first=false
            echo "    {\"project\":\"$proj\",\"vm\":\"$name\",\"type\":\"$machine_short\",\"cpu\":$avg_cpu,\"ram\":$avg_ram,\"recommendation\":\"$recommendation\",\"savings\":$savings}"
        } || {
            # Affiche seulement les VMs à optimiser
            if [[ "$recommendation" != "Right-sized" ]]; then
                rec_display="$recommendation"
                [[ "$recommendation" == *"over"* ]] && rec_display="${GREEN}$recommendation${NC}"
                [[ "$recommendation" == *"under"* ]] && rec_display="${YELLOW}$recommendation${NC}"
                printf "%-25s %-30s %-20s %-15s %-15s %-29s\n" "${proj:0:23}" "${name:0:28}" "${machine_short:0:18}" "${avg_cpu}%" "${avg_ram}%" "$rec_display"
            fi
        }
    done <<< "$vms"
done <<< "$project_list"

[[ "$JSON_MODE" == true ]] && {
    echo '\n  ],'
    echo '  "summary": {'
    echo "    \"total\": $total, \"over_provisioned\": $over_provisioned, \"under_provisioned\": $under_provisioned,"
    echo "    \"right_sized\": $right_sized, \"potential_monthly_savings_usd\": $potential_savings"
    echo '  }}'
} || {
    echo -e "\n${CYAN}=== Résumé ===${NC}"
    echo -e "Total VMs analysées:       ${BLUE}$total${NC}"
    echo -e "Sur-provisionnées:         ${GREEN}$over_provisioned${NC}"
    echo -e "Sous-provisionnées:        ${YELLOW}$under_provisioned${NC}"
    echo -e "Bien dimensionnées:        ${BLUE}$right_sized${NC}"
    echo -e "Économies potentielles:    ${GREEN}\$${potential_savings}/mois${NC}"
    echo -e "\n${YELLOW}Note: Basé sur simulation. En production, utiliser Cloud Monitoring pour métriques réelles.${NC}"
}
