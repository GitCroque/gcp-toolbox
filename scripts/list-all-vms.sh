#!/bin/bash

#####################################################################
# Script: list-all-vms.sh
# Description: Liste toutes les VMs dans tous les projets GCP
#              avec leurs détails (statut, zone, type de machine, coût estimé)
# Prérequis: gcloud CLI configuré et authentifié
#            Permissions nécessaires: compute.instances.list sur les projets
# Usage: ./list-all-vms.sh [--json]
#####################################################################

set -euo pipefail

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Mode JSON si argument --json
JSON_MODE=false
if [[ "${1:-}" == "--json" ]]; then
    JSON_MODE=true
fi

# Prix estimatifs pour les types de machines (USD/mois)
# Basé sur us-central1, à ajuster selon vos régions
declare -A MACHINE_COSTS=(
    ["e2-micro"]=7
    ["e2-small"]=14
    ["e2-medium"]=28
    ["e2-standard-2"]=49
    ["e2-standard-4"]=98
    ["n1-standard-1"]=25
    ["n1-standard-2"]=50
    ["n1-standard-4"]=100
    ["n2-standard-2"]=68
    ["n2-standard-4"]=136
    ["c2-standard-4"]=180
    ["m1-ultramem-40"]=4000
)

# Fonction d'affichage de l'en-tête
print_header() {
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Inventaire des VMs GCP${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
    fi
}

# Fonction pour obtenir le coût estimé d'une machine
get_estimated_cost() {
    local machine_type=$1

    # Cherche le type exact
    if [[ -v "MACHINE_COSTS[$machine_type]" ]]; then
        echo "${MACHINE_COSTS[$machine_type]}"
        return
    fi

    # Sinon essaie de trouver un type similaire
    for key in "${!MACHINE_COSTS[@]}"; do
        if [[ "$machine_type" == *"$key"* ]]; then
            echo "${MACHINE_COSTS[$key]}"
            return
        fi
    done

    echo "?"
}

# Vérification que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud CLI n'est pas installé${NC}" >&2
    exit 1
fi

# Vérification de l'authentification
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}Erreur: Aucun compte gcloud actif trouvé${NC}" >&2
    exit 1
fi

print_header

# Variables pour les statistiques
total_vms=0
total_running=0
total_stopped=0
total_cost=0

if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "vms": ['
    first_vm=true
else
    echo -e "${GREEN}Récupération des VMs dans tous les projets...${NC}"
    echo ""
    printf "%-25s %-35s %-15s %-20s %-25s %-10s %-10s\n" \
        "PROJECT_ID" "VM_NAME" "STATUS" "ZONE" "MACHINE_TYPE" "EXTERNAL_IP" "COST/MONTH"
    printf "%-25s %-35s %-15s %-20s %-25s %-10s %-10s\n" \
        "----------" "-------" "------" "----" "------------" "-----------" "----------"
fi

# Boucle sur tous les projets
gcloud projects list --format="value(projectId)" | while read -r project_id; do
    # Liste les VMs dans ce projet
    vms=$(gcloud compute instances list \
        --project="$project_id" \
        --format="value(name,zone,status,machineType,networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || echo "")

    if [[ -n "$vms" ]]; then
        while IFS=$'\t' read -r name zone status machine_type external_ip; do
            ((total_vms++))

            # Compte les statuts
            if [[ "$status" == "RUNNING" ]]; then
                ((total_running++))
            else
                ((total_stopped++))
            fi

            # Extrait juste le type de machine (retire le chemin complet)
            machine_type_short=$(basename "$machine_type")

            # Calcule le coût estimé
            cost=$(get_estimated_cost "$machine_type_short")
            if [[ "$cost" != "?" && "$status" == "RUNNING" ]]; then
                ((total_cost+=cost))
            fi

            # Gère l'IP externe vide
            [[ -z "$external_ip" ]] && external_ip="none"

            if [[ "$JSON_MODE" == true ]]; then
                [[ "$first_vm" == false ]] && echo ","
                first_vm=false
                cat <<EOF
    {
      "project_id": "$project_id",
      "name": "$name",
      "zone": "$zone",
      "status": "$status",
      "machine_type": "$machine_type_short",
      "external_ip": "$external_ip",
      "estimated_monthly_cost_usd": "$cost"
    }
EOF
            else
                # Couleur selon le statut
                if [[ "$status" == "RUNNING" ]]; then
                    status_colored="${GREEN}${status}${NC}"
                else
                    status_colored="${YELLOW}${status}${NC}"
                fi

                printf "%-25s %-35s %-24s %-20s %-25s %-10s %-10s\n" \
                    "${project_id:0:23}" \
                    "${name:0:33}" \
                    "$status_colored" \
                    "${zone:0:18}" \
                    "${machine_type_short:0:23}" \
                    "${external_ip:0:8}" \
                    "\$${cost}"
            fi
        done <<< "$vms"
    fi
done

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "  ],"
    echo '  "summary": {'
    echo "    \"total_vms\": $total_vms,"
    echo "    \"running\": $total_running,"
    echo "    \"stopped\": $total_stopped,"
    echo "    \"estimated_monthly_cost_usd\": $total_cost"
    echo "  }"
    echo "}"
else
    echo ""
    echo -e "${CYAN}========== Résumé ==========${NC}"
    echo -e "Total VMs:           ${BLUE}$total_vms${NC}"
    echo -e "En cours (RUNNING):  ${GREEN}$total_running${NC}"
    echo -e "Arrêtées:            ${YELLOW}$total_stopped${NC}"
    echo -e "Coût estimé/mois:    ${CYAN}\$${total_cost} USD${NC} (VMs en cours uniquement)"
    echo ""
    echo -e "${YELLOW}Note: Les coûts sont des estimations basées sur us-central1${NC}"
    echo -e "${YELLOW}      N'inclut pas: disques, réseau, licences Windows, etc.${NC}"
fi
