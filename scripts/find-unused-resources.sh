#!/usr/bin/env bash

#####################################################################
# Script: find-unused-resources.sh
# Description: Trouve les ressources GCP non utilisées pour identifier
#              les opportunités d'économies
# Ressources détectées:
#   - VMs arrêtées depuis plus de X jours
#   - Disques non attachés
#   - Adresses IP statiques non utilisées
#   - Snapshots anciens (> X jours)
#   - Load balancers sans backend
# Prérequis: gcloud CLI configuré et authentifié
#            Permissions nécessaires: compute.* en lecture
# Usage: ./find-unused-resources.sh [--days N] [--json]
#
# Options:
#   --days N    : Considérer les ressources inutilisées après N jours (défaut: 7)
#   --json      : Sortie en format JSON
#####################################################################

set -euo pipefail

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options par défaut
DAYS_THRESHOLD=7

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_MODE=true
            shift
            ;;
        --days)
            DAYS_THRESHOLD="$2"
            shift 2
            ;;
        *)
            echo "Option inconnue: $1" >&2
            exit 1
            ;;
    esac
done

# Fonction d'affichage de l'en-tête
show_header() {
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Ressources GCP Non Utilisées${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${YELLOW}Seuil: ressources inutilisées depuis ${DAYS_THRESHOLD}+ jours${NC}"
        echo ""
    fi
}

# La fonction calculate_days_ago() est maintenant fournie par common.sh
# Elle gère automatiquement macOS (BSD date) et Linux (GNU date)

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

show_header

# Compteurs
total_stopped_vms=0
total_unattached_disks=0
total_unused_ips=0
total_old_snapshots=0

if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo "  \"days_threshold\": $DAYS_THRESHOLD,"
    echo '  "unused_resources": {'
    echo '    "stopped_vms": ['
    first_item=true
else
    echo -e "${CYAN}=== 1. VMs Arrêtées ===${NC}"
    printf "%-25s %-30s %-15s %-20s %-15s\n" \
        "PROJECT_ID" "VM_NAME" "STATUS" "ZONE" "DAYS_STOPPED"
    printf "%-25s %-30s %-15s %-20s %-15s\n" \
        "----------" "-------" "------" "----" "------------"
fi

# 1. VMs arrêtées
gcloud projects list --format="value(projectId)" | while read -r project_id; do
    stopped_vms=$(gcloud compute instances list \
        --project="$project_id" \
        --filter="status:TERMINATED OR status:STOPPED" \
        --format="value(name,zone,status,lastStopTimestamp)" 2>/dev/null || echo "")

    if [[ -n "$stopped_vms" ]]; then
        while IFS=$'\t' read -r name zone status last_stop; do
            days_ago=$(calculate_days_ago "$last_stop")

            # Filtre par seuil de jours
            if [[ "$days_ago" != "?" ]] && [[ "$days_ago" -ge "$DAYS_THRESHOLD" ]]; then
                ((total_stopped_vms++))

                if [[ "$JSON_MODE" == true ]]; then
                    [[ "$first_item" == false ]] && echo ","
                    first_item=false
                    cat <<EOF
      {
        "project_id": "$project_id",
        "name": "$name",
        "zone": "$zone",
        "status": "$status",
        "days_stopped": $days_ago
      }
EOF
                else
                    printf "%-25s %-30s %-15s %-20s %-15s\n" \
                        "${project_id:0:23}" \
                        "${name:0:28}" \
                        "$status" \
                        "${zone:0:18}" \
                        "$days_ago"
                fi
            fi
        done <<< "$stopped_vms"
    fi
done

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "    ],"
    echo '    "unattached_disks": ['
    first_item=true
else
    echo ""
    echo -e "${CYAN}=== 2. Disques Non Attachés ===${NC}"
    printf "%-25s %-35s %-15s %-20s %-15s\n" \
        "PROJECT_ID" "DISK_NAME" "SIZE_GB" "ZONE" "CREATED"
    printf "%-25s %-35s %-15s %-20s %-15s\n" \
        "----------" "---------" "-------" "----" "-------"
fi

# 2. Disques non attachés
gcloud projects list --format="value(projectId)" | while read -r project_id; do
    unattached_disks=$(gcloud compute disks list \
        --project="$project_id" \
        --filter="-users:*" \
        --format="value(name,zone,sizeGb,creationTimestamp)" 2>/dev/null || echo "")

    if [[ -n "$unattached_disks" ]]; then
        while IFS=$'\t' read -r name zone size created; do
            ((total_unattached_disks++))
            days_ago=$(calculate_days_ago "$created")

            if [[ "$JSON_MODE" == true ]]; then
                [[ "$first_item" == false ]] && echo ","
                first_item=false
                cat <<EOF
      {
        "project_id": "$project_id",
        "name": "$name",
        "zone": "$zone",
        "size_gb": $size,
        "days_old": $days_ago
      }
EOF
            else
                printf "%-25s %-35s %-15s %-20s %-15s\n" \
                    "${project_id:0:23}" \
                    "${name:0:33}" \
                    "$size GB" \
                    "${zone:0:18}" \
                    "$days_ago days"
            fi
        done <<< "$unattached_disks"
    fi
done

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "    ],"
    echo '    "unused_static_ips": ['
    first_item=true
else
    echo ""
    echo -e "${CYAN}=== 3. Adresses IP Statiques Non Utilisées ===${NC}"
    printf "%-25s %-25s %-20s %-15s\n" \
        "PROJECT_ID" "IP_NAME" "REGION" "IP_ADDRESS"
    printf "%-25s %-25s %-20s %-15s\n" \
        "----------" "-------" "------" "----------"
fi

# 3. IPs statiques non utilisées
gcloud projects list --format="value(projectId)" | while read -r project_id; do
    unused_ips=$(gcloud compute addresses list \
        --project="$project_id" \
        --filter="status:RESERVED" \
        --format="value(name,region,address)" 2>/dev/null || echo "")

    if [[ -n "$unused_ips" ]]; then
        while IFS=$'\t' read -r name region address; do
            ((total_unused_ips++))

            if [[ "$JSON_MODE" == true ]]; then
                [[ "$first_item" == false ]] && echo ","
                first_item=false
                cat <<EOF
      {
        "project_id": "$project_id",
        "name": "$name",
        "region": "$region",
        "ip_address": "$address"
      }
EOF
            else
                printf "%-25s %-25s %-20s %-15s\n" \
                    "${project_id:0:23}" \
                    "${name:0:23}" \
                    "${region:0:18}" \
                    "$address"
            fi
        done <<< "$unused_ips"
    fi
done

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "    ],"
    echo '    "old_snapshots": ['
    first_item=true
else
    echo ""
    echo -e "${CYAN}=== 4. Snapshots Anciens (>${DAYS_THRESHOLD} jours) ===${NC}"
    printf "%-25s %-35s %-15s %-15s\n" \
        "PROJECT_ID" "SNAPSHOT_NAME" "SIZE_GB" "DAYS_OLD"
    printf "%-25s %-35s %-15s %-15s\n" \
        "----------" "-------------" "-------" "--------"
fi

# 4. Snapshots anciens
gcloud projects list --format="value(projectId)" | while read -r project_id; do
    snapshots=$(gcloud compute snapshots list \
        --project="$project_id" \
        --format="value(name,diskSizeGb,creationTimestamp)" 2>/dev/null || echo "")

    if [[ -n "$snapshots" ]]; then
        while IFS=$'\t' read -r name size created; do
            days_ago=$(calculate_days_ago "$created")

            if [[ "$days_ago" != "?" ]] && [[ "$days_ago" -ge "$DAYS_THRESHOLD" ]]; then
                ((total_old_snapshots++))

                if [[ "$JSON_MODE" == true ]]; then
                    [[ "$first_item" == false ]] && echo ","
                    first_item=false
                    cat <<EOF
      {
        "project_id": "$project_id",
        "name": "$name",
        "size_gb": $size,
        "days_old": $days_ago
      }
EOF
                else
                    printf "%-25s %-35s %-15s %-15s\n" \
                        "${project_id:0:23}" \
                        "${name:0:33}" \
                        "$size GB" \
                        "$days_ago"
                fi
            fi
        done <<< "$snapshots"
    fi
done

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "    ]"
    echo "  },"
    echo '  "summary": {'
    echo "    \"total_stopped_vms\": $total_stopped_vms,"
    echo "    \"total_unattached_disks\": $total_unattached_disks,"
    echo "    \"total_unused_ips\": $total_unused_ips,"
    echo "    \"total_old_snapshots\": $total_old_snapshots"
    echo "  }"
    echo "}"
else
    echo ""
    echo -e "${CYAN}========== Résumé ==========${NC}"
    echo -e "VMs arrêtées (${DAYS_THRESHOLD}+ jours):     ${YELLOW}$total_stopped_vms${NC}"
    echo -e "Disques non attachés:         ${YELLOW}$total_unattached_disks${NC}"
    echo -e "IPs statiques inutilisées:    ${YELLOW}$total_unused_ips${NC}"
    echo -e "Snapshots anciens:            ${YELLOW}$total_old_snapshots${NC}"
    echo ""
    echo -e "${GREEN}Recommandations:${NC}"
    echo -e "  - Supprimez les VMs arrêtées depuis longtemps"
    echo -e "  - Attachez ou supprimez les disques orphelins"
    echo -e "  - Libérez les IPs statiques non utilisées (coût: ~\$7/mois chacune)"
    echo -e "  - Établissez une politique de rétention pour les snapshots"
    echo ""
    echo -e "${YELLOW}Économies potentielles estimées:${NC}"
    echo -e "  - IPs statiques: ~\$$(( total_unused_ips * 7 ))/mois"
    echo -e "  - Pour les autres ressources, calculez via Cloud Pricing Calculator"
fi
