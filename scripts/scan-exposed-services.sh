#!/bin/bash
set -euo pipefail

#####################################################################
# Script: scan-exposed-services.sh
# Description: Scanner les services exposés publiquement
#              (VMs avec IP publiques, Load Balancers, etc.)
#
# Prérequis: gcloud CLI avec permissions compute.*
#
# Usage: ./scan-exposed-services.sh [OPTIONS]
#
# Options:
#   --json           : Sortie JSON
#   --project PROJECT: Scanner un seul projet
#####################################################################

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

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2; exit 1
fi

[[ "$JSON_MODE" == false ]] && {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  🌐 Scan Services Exposés${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

total_vms_with_public_ip=0
total_lb=0
total_cloud_run_public=0

[[ "$JSON_MODE" == true ]] && {
    echo '{"generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "exposed_services": {'
    echo '    "vms": ['
    first_vm=true
} || {
    echo -e "${YELLOW}=== VMs avec IP Publique ===${NC}\n"
    printf "%-25s %-30s %-20s %-20s\n" "PROJECT" "VM_NAME" "ZONE" "PUBLIC_IP"
    printf "%-25s %-30s %-20s %-20s\n" "-------" "-------" "----" "---------"
}

project_list="${SINGLE_PROJECT:-$(gcloud projects list --format='value(projectId)')}"

# Scan VMs
while read -r proj; do
    [[ -z "$proj" ]] && continue

    vms=$(gcloud compute instances list --project="$proj" \
        --format="value(name,zone,networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || echo "")

    while IFS=$'\t' read -r name zone public_ip; do
        [[ -z "$name" ]] && continue
        [[ -z "$public_ip" ]] && continue  # Skip VMs without public IP
        ((total_vms_with_public_ip++))

        [[ "$JSON_MODE" == true ]] && {
            [[ "$first_vm" == false ]] && echo ","
            first_vm=false
            echo "      {\"project\":\"$proj\",\"vm\":\"$name\",\"zone\":\"$zone\",\"public_ip\":\"$public_ip\"}"
        } || {
            printf "%-25s %-30s %-20s %-20s\n" "${proj:0:23}" "${name:0:28}" "${zone:0:18}" "$public_ip"
        }
    done <<< "$vms"
done <<< "$project_list"

[[ "$JSON_MODE" == true ]] && {
    echo '\n    ],'
    echo '    "load_balancers": ['
    first_lb=true
}

# Scan Load Balancers
[[ "$JSON_MODE" == false ]] && {
    echo -e "\n${YELLOW}=== Load Balancers ===${NC}\n"
    printf "%-25s %-30s %-20s\n" "PROJECT" "LB_NAME" "IP_ADDRESS"
    printf "%-25s %-30s %-20s\n" "-------" "-------" "----------"
}

while read -r proj; do
    [[ -z "$proj" ]] && continue

    lbs=$(gcloud compute forwarding-rules list --project="$proj" \
        --format="value(name,IPAddress)" 2>/dev/null || echo "")

    while IFS=$'\t' read -r name ip_address; do
        [[ -z "$name" ]] && continue
        ((total_lb++))

        [[ "$JSON_MODE" == true ]] && {
            [[ "$first_lb" == false ]] && echo ","
            first_lb=false
            echo "      {\"project\":\"$proj\",\"lb_name\":\"$name\",\"ip\":\"$ip_address\"}"
        } || {
            printf "%-25s %-30s %-20s\n" "${proj:0:23}" "${name:0:28}" "$ip_address"
        }
    done <<< "$lbs"
done <<< "$project_list"

[[ "$JSON_MODE" == true ]] && {
    echo '\n    ]'
    echo '  },'
    echo '  "summary": {'
    echo "    \"vms_with_public_ip\": $total_vms_with_public_ip,"
    echo "    \"load_balancers\": $total_lb"
    echo '  }}'
} || {
    echo -e "\n${CYAN}=== Résumé ===${NC}"
    echo -e "VMs avec IP publique:      ${BLUE}$total_vms_with_public_ip${NC}"
    echo -e "Load Balancers:            ${BLUE}$total_lb${NC}"

    [[ $total_vms_with_public_ip -gt 0 ]] && {
        echo -e "\n${YELLOW}⚠️  Recommandations:${NC}"
        echo -e "- Utiliser Private Google Access quand possible"
        echo -e "- Implémenter Cloud NAT pour VMs privées"
        echo -e "- Utiliser Identity-Aware Proxy pour accès SSH"
    }
}
