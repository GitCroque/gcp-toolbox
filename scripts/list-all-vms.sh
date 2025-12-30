#!/usr/bin/env bash

#####################################################################
# Script: list-all-vms.sh
# Description: Liste toutes les VMs dans tous les projets GCP
#              avec leurs détails (statut, zone, type de machine, coût estimé)
# Prérequis: gcloud CLI configuré et authentifié
#            Permissions nécessaires: compute.instances.list sur les projets
# Usage: ./list-all-vms.sh [--json]
#####################################################################

set -euo pipefail

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Mode JSON + sélection de projets via arguments/env
usage() {
    cat <<EOF
Usage: ./list-all-vms.sh [options]

Options:
  --json                Sortie JSON
  -p, --project ID      Ajoute un projet (répéter si besoin)
  --projects CSV        Liste de projets séparés par des virgules
  -h, --help            Affiche cette aide

Vous pouvez aussi définir la variable d'environnement GCP_PROJECTS
avec une liste de projets séparés par des virgules.
EOF
}

JSON_MODE=false
PROJECT_FILTERS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            ;;
        -p|--project)
            if [[ -z "${2:-}" ]]; then
                echo "Erreur: --project nécessite un identifiant" >&2
                exit 1
            fi
            PROJECT_FILTERS+=("$2")
            shift
            ;;
        --projects)
            if [[ -z "${2:-}" ]]; then
                echo "Erreur: --projects nécessite une liste CSV" >&2
                exit 1
            fi
            IFS=',' read -ra tmp_projects <<< "$2"
            for p in "${tmp_projects[@]}"; do
                p=${p//[[:space:]]/}
                [[ -n "$p" ]] && PROJECT_FILTERS+=("$p")
            done
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Option inconnue: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
done

if [[ ${#PROJECT_FILTERS[@]} -eq 0 && -n "${GCP_PROJECTS:-}" ]]; then
    IFS=',' read -ra tmp_env_projects <<< "$GCP_PROJECTS"
    for p in "${tmp_env_projects[@]}"; do
        p=${p//[[:space:]]/}
        [[ -n "$p" ]] && PROJECT_FILTERS+=("$p")
    done
fi

# Prix estimatifs pour les types de machines (USD/mois)
# Basé sur us-central1, à ajuster selon vos régions
MACHINE_COSTS_DATA=$'e2-micro|7\n'\
'e2-small|14\n'\
'e2-medium|28\n'\
'e2-standard-2|49\n'\
'e2-standard-4|98\n'\
'n1-standard-1|25\n'\
'n1-standard-2|50\n'\
'n1-standard-4|100\n'\
'n2-standard-2|68\n'\
'n2-standard-4|136\n'\
'c2-standard-4|180\n'\
'm1-ultramem-40|4000'

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
    local machine_type=${1:-}
    local key value

    # Cherche le type exact
    while IFS='|' read -r key value; do
        [[ -z "$key" ]] && continue
        if [[ "$machine_type" == "$key" ]]; then
            echo "$value"
            return
        fi
    done <<< "$MACHINE_COSTS_DATA"

    # Sinon essaie de trouver un type similaire
    while IFS='|' read -r key value; do
        [[ -z "$key" ]] && continue
        if [[ "$machine_type" == *"$key"* ]]; then
            echo "$value"
            return
        fi
    done <<< "$MACHINE_COSTS_DATA"

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

# Détermination des projets à interroger
project_ids=()

if [[ ${#PROJECT_FILTERS[@]} -gt 0 ]]; then
    for project_id in "${PROJECT_FILTERS[@]}"; do
        [[ -z "$project_id" ]] && continue
        project_ids+=("$project_id")
    done
else
    projects_output=$(gcloud projects list --format="value(projectId)" 2>/dev/null || true)
    while IFS= read -r project_id; do
        [[ -z "$project_id" ]] && continue
        project_ids+=("$project_id")
    done <<< "$projects_output"
fi

if [[ ${#project_ids[@]} -eq 0 ]]; then
    default_project=$(gcloud config get-value project 2>/dev/null || true)
    if [[ -n "$default_project" && "$default_project" != "(unset)" ]]; then
        project_ids+=("$default_project")
    fi
fi

if [[ ${#project_ids[@]} -eq 0 ]]; then
    echo -e "${RED}Erreur: Aucun projet trouvé. Utilisez --project ou GCP_PROJECTS.${NC}" >&2
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
for project_id in "${project_ids[@]}"; do
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
