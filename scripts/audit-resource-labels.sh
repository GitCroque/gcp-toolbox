#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# Script: audit-resource-labels.sh
# Description: Audite le labeling des ressources GCP pour conformité
#              aux standards d'organisation (cost center, env, owner)
#
# Prérequis: gcloud CLI
#
# Usage: ./audit-resource-labels.sh [OPTIONS]
#
# Options:
#   --json           : Sortie JSON
#   --project PROJECT: Auditer un seul projet
#   --required-labels: Liste des labels obligatoires (ex: env,owner,cost-center)
#####################################################################

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options locales (JSON_MODE et SINGLE_PROJECT définis dans common.sh)
REQUIRED_LABELS="env,owner,cost-center"

while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --project) SINGLE_PROJECT="$2"; shift 2 ;;
        --required-labels) REQUIRED_LABELS="$2"; shift 2 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2; exit 1
fi

IFS=',' read -ra REQUIRED_ARRAY <<< "$REQUIRED_LABELS"

[[ "$JSON_MODE" == false ]] && {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  🏷️  Audit Resource Labels${NC}"
    echo -e "${BLUE}========================================${NC}\n"
    echo -e "${CYAN}Labels obligatoires: ${REQUIRED_LABELS}${NC}\n"
}

total_vms=0
compliant_vms=0
non_compliant_vms=0

[[ "$JSON_MODE" == true ]] && {
    echo '{"generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "required_labels": "'$REQUIRED_LABELS'",'
    echo '  "resources": ['
    first=true
} || {
    printf "%-25s %-30s %-15s %-20s %-15s\n" "PROJECT" "RESOURCE_NAME" "TYPE" "MISSING_LABELS" "STATUS"
    printf "%-25s %-30s %-15s %-20s %-15s\n" "-------" "-------------" "----" "--------------" "------"
}

project_list="${SINGLE_PROJECT:-$(gcloud projects list --format='value(projectId)')}"

while read -r proj; do
    [[ -z "$proj" ]] && continue

    # Audit VMs
    vms=$(gcloud compute instances list --project="$proj" \
        --format="value(name,zone,labels.list())" 2>/dev/null || echo "")

    while IFS=$'\t' read -r name zone labels; do
        [[ -z "$name" ]] && continue
        ((total_vms++))

        missing_labels=()
        for required_label in "${REQUIRED_ARRAY[@]}"; do
            if [[ ! "$labels" == *"$required_label"* ]]; then
                missing_labels+=("$required_label")
            fi
        done

        if [[ ${#missing_labels[@]} -eq 0 ]]; then
            status="COMPLIANT"
            ((compliant_vms++))
        else
            status="NON_COMPLIANT"
            ((non_compliant_vms++))
        fi

        missing_str=$(IFS=,; echo "${missing_labels[*]}")

        [[ "$JSON_MODE" == true ]] && {
            [[ "$first" == false ]] && echo ","
            first=false
            echo "    {\"project\":\"$proj\",\"name\":\"$name\",\"type\":\"VM\",\"missing_labels\":\"$missing_str\",\"status\":\"$status\"}"
        } || {
            # Only show non-compliant
            if [[ "$status" == "NON_COMPLIANT" ]]; then
                status_display="${RED}NON_COMPLIANT${NC}"
                printf "%-25s %-30s %-15s %-20s %-24s\n" \
                    "${proj:0:23}" "${name:0:28}" "VM" "${missing_str:0:18}" "$status_display"
            fi
        }
    done <<< "$vms"
done <<< "$project_list"

[[ "$JSON_MODE" == true ]] && {
    echo '\n  ],'
    echo '  "summary": {'
    echo "    \"total_resources\": $total_vms,"
    echo "    \"compliant\": $compliant_vms,"
    echo "    \"non_compliant\": $non_compliant_vms"
    echo '  }}'
} || {
    echo -e "\n${CYAN}=== Résumé ===${NC}"
    echo -e "Total ressources:      ${BLUE}$total_vms${NC}"
    echo -e "Conformes:             ${GREEN}$compliant_vms${NC}"
    echo -e "Non-conformes:         ${RED}$non_compliant_vms${NC}"

    [[ $non_compliant_vms -gt 0 ]] && {
        echo -e "\n${YELLOW}⚠️  $non_compliant_vms ressource(s) sans labels obligatoires${NC}"
        echo -e "\n${CYAN}Pour ajouter des labels:${NC}"
        echo -e "  gcloud compute instances add-labels VM_NAME --labels=env=prod,owner=team-a"
    }
}
