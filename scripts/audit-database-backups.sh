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
    echo -e "${BLUE}  📦 Audit Database Backups${NC}"
    echo -e "${BLUE}======================================${NC}\n"
}

total=0; with_backup=0; without_backup=0; old_backup=0

[[ "$JSON_MODE" == true ]] && {
    echo '{"generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "instances": ['
    first=true
} || {
    echo -e "${GREEN}Vérification des backups Cloud SQL...${NC}\n"
    printf "%-25s %-30s %-15s %-20s %-15s\n" "PROJECT" "INSTANCE" "BACKUP_ENABLED" "LAST_BACKUP" "STATUS"
    printf "%-25s %-30s %-15s %-20s %-15s\n" "-------" "--------" "--------------" "-----------" "------"
}

project_list="${SINGLE_PROJECT:-$(gcloud projects list --format='value(projectId)')}"

while read -r proj; do
    [[ -z "$proj" ]] && continue
    instances=$(gcloud sql instances list --project="$proj" --format='value(name,settings.backupConfiguration.enabled)' 2>/dev/null || echo "")
    
    while IFS=$'\t' read -r name backup_enabled; do
        [[ -z "$name" ]] && continue
        ((total++))
        
        status="OK"; last_backup="N/A"
        if [[ "$backup_enabled" == "True" ]]; then
            ((with_backup++))
            # Récupère dernière backup
            last_backup=$(gcloud sql backups list --instance="$name" --project="$proj" --limit=1 --format='value(windowStartTime)' 2>/dev/null | head -1 || echo "Never")
        else
            ((without_backup++))
            status="NO_BACKUP"
        fi
        
        [[ "$JSON_MODE" == true ]] && {
            [[ "$first" == false ]] && echo ","
            first=false
            echo "    {\"project\":\"$proj\",\"instance\":\"$name\",\"backup_enabled\":\"$backup_enabled\",\"last_backup\":\"$last_backup\",\"status\":\"$status\"}"
        } || {
            status_display="$status"
            [[ "$status" == "NO_BACKUP" ]] && status_display="${RED}NO_BACKUP${NC}" || status_display="${GREEN}OK${NC}"
            printf "%-25s %-30s %-15s %-20s %-24s\n" "${proj:0:23}" "${name:0:28}" "$backup_enabled" "${last_backup:0:18}" "$status_display"
        }
    done <<< "$instances"
done <<< "$project_list"

[[ "$JSON_MODE" == true ]] && {
    echo '\n  ],'
    echo '  "summary": {'
    echo "    \"total\": $total, \"with_backup\": $with_backup, \"without_backup\": $without_backup"
    echo '  }}'
} || {
    echo -e "\n${CYAN}=== Résumé ===${NC}"
    echo -e "Total instances:        ${BLUE}$total${NC}"
    echo -e "Avec backup:            ${GREEN}$with_backup${NC}"
    echo -e "SANS backup:            ${RED}$without_backup${NC}"
    [[ $without_backup -gt 0 ]] && echo -e "\n${RED}⚠️  $without_backup instance(s) SANS BACKUP !${NC}"
}
