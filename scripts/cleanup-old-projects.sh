#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# Script: cleanup-old-projects.sh
# Description: Identifie les projets inactifs candidats à la suppression
#              ou à l'archivage pour optimiser les coûts
#
# Prérequis: gcloud CLI avec permissions projects.get
#
# Usage: ./cleanup-old-projects.sh [OPTIONS]
#
# Options:
#   --json                : Sortie JSON
#   --inactive-days DAYS  : Seuil d'inactivité (défaut: 180 jours)
#   --dry-run             : Mode simulation (ne supprime rien)
#####################################################################

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options locales (JSON_MODE défini dans common.sh)
INACTIVE_DAYS=180
DRY_RUN=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --inactive-days) INACTIVE_DAYS="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2; exit 1
fi

[[ "$JSON_MODE" == false ]] && {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  🗑️  Cleanup Projets Inactifs${NC}"
    echo -e "${YELLOW}========================================${NC}\n"
    echo -e "${CYAN}Seuil d'inactivité: $INACTIVE_DAYS jours${NC}"
    echo -e "${CYAN}Mode: DRY RUN (aucune suppression)${NC}\n"
}

total_projects=0
inactive_projects=0
potential_deletion=0
total_estimated_savings=0

[[ "$JSON_MODE" == true ]] && {
    echo '{"generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo "  \"inactive_threshold_days\": $INACTIVE_DAYS,"
    echo '  "candidates": ['
    first=true
} || {
    printf "%-30s %-15s %-15s %-20s %-20s\n" "PROJECT_ID" "VM_COUNT" "SQL_COUNT" "STATUS" "RECOMMENDATION"
    printf "%-30s %-15s %-15s %-20s %-20s\n" "----------" "---------" "---------" "------" "--------------"
}

projects=$(gcloud projects list --format="value(projectId)" 2>/dev/null)

while read -r project_id; do
    [[ -z "$project_id" ]] && continue
    ((total_projects++))

    # Compte ressources
    vm_count=$(gcloud compute instances list --project="$project_id" 2>/dev/null | wc -l || echo 0)
    sql_count=$(gcloud sql instances list --project="$project_id" 2>/dev/null | wc -l || echo 0)
    gke_count=$(gcloud container clusters list --project="$project_id" 2>/dev/null | wc -l || echo 0)

    total_resources=$((vm_count + sql_count + gke_count))

    status="active"
    recommendation="KEEP"
    estimated_monthly_cost=0

    if [[ $total_resources -eq 0 ]]; then
        status="empty"
        recommendation="DELETE"
        ((potential_deletion++))
    elif [[ $vm_count -eq 0 && $sql_count -eq 0 && $gke_count -gt 0 ]]; then
        status="inactive"
        recommendation="REVIEW"
        ((inactive_projects++))
        estimated_monthly_cost=100
    fi

    ((total_estimated_savings+=estimated_monthly_cost))

    if [[ "$recommendation" != "KEEP" ]]; then
        [[ "$JSON_MODE" == true ]] && {
            [[ "$first" == false ]] && echo ","
            first=false
            echo "    {\"project\":\"$project_id\",\"vm_count\":$vm_count,\"sql_count\":$sql_count,\"status\":\"$status\",\"recommendation\":\"$recommendation\",\"monthly_cost\":$estimated_monthly_cost}"
        } || {
            rec_display="$recommendation"
            [[ "$recommendation" == "DELETE" ]] && rec_display="${RED}DELETE${NC}"
            [[ "$recommendation" == "REVIEW" ]] && rec_display="${YELLOW}REVIEW${NC}"

            printf "%-30s %-15s %-15s %-20s %-29s\n" \
                "${project_id:0:28}" "$vm_count" "$sql_count" "$status" "$rec_display"
        }
    fi
done <<< "$projects"

[[ "$JSON_MODE" == true ]] && {
    echo '\n  ],'
    echo '  "summary": {'
    echo "    \"total_projects\": $total_projects,"
    echo "    \"inactive_projects\": $inactive_projects,"
    echo "    \"deletion_candidates\": $potential_deletion,"
    echo "    \"estimated_monthly_savings\": $total_estimated_savings"
    echo '  }}'
} || {
    echo -e "\n${CYAN}=== Résumé ===${NC}"
    echo -e "Total projets:                    ${BLUE}$total_projects${NC}"
    echo -e "Projets inactifs (REVIEW):        ${YELLOW}$inactive_projects${NC}"
    echo -e "Candidats suppression (vides):    ${RED}$potential_deletion${NC}"
    echo -e "Économies estimées:               ${GREEN}\$${total_estimated_savings}/mois${NC}"

    [[ $potential_deletion -gt 0 ]] && {
        echo -e "\n${RED}⚠️  $potential_deletion projet(s) vide(s) peuvent être supprimés${NC}"
        echo -e "\n${CYAN}Pour supprimer un projet:${NC}"
        echo -e "  gcloud projects delete PROJECT_ID"
    }
}
