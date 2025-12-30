#!/usr/bin/env bash

#####################################################################
# Script: check-quotas.sh
# Description: Vérifie l'utilisation des quotas GCP dans tous les projets
#              pour identifier les risques de dépassement
# Quotas vérifiés:
#   - CPU cores (compute)
#   - Adresses IP externes
#   - Persistent disk size (SSD et standard)
#   - In-use IP addresses
#   - Instances (VMs)
# Prérequis: gcloud CLI configuré et authentifié
#            Permissions nécessaires: compute.* en lecture
# Usage: ./check-quotas.sh [--threshold N] [--json] [--project PROJECT_ID]
#
# Options:
#   --threshold N   : Alerter si utilisation > N% (défaut: 80)
#   --json          : Sortie en format JSON
#   --project P     : Vérifier un seul projet spécifique
#####################################################################

set -euo pipefail

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options locales (JSON_MODE et SINGLE_PROJECT définis dans common.sh)
THRESHOLD=80

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_MODE=true
            shift
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --project)
            SINGLE_PROJECT="$2"
            shift 2
            ;;
        *)
            echo "Option inconnue: $1" >&2
            exit 1
            ;;
    esac
done

# Fonction d'affichage de l'en-tête
print_header() {
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Vérification des Quotas GCP${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${YELLOW}Seuil d'alerte: ${THRESHOLD}% d'utilisation${NC}"
        echo ""
    fi
}

# Fonction pour calculer le pourcentage d'utilisation
calculate_percentage() {
    local usage=$1
    local limit=$2

    # Gère les cas particuliers
    if [[ "$limit" == "0" ]] || [[ "$limit" == "" ]]; then
        echo "N/A"
        return
    fi

    local percentage=$((usage * 100 / limit))
    echo "$percentage"
}

# Fonction pour déterminer la couleur selon le pourcentage
get_color_for_percentage() {
    local percentage=$1

    if [[ "$percentage" == "N/A" ]]; then
        echo "$NC"
    elif [[ "$percentage" -ge 90 ]]; then
        echo "$RED"
    elif [[ "$percentage" -ge "$THRESHOLD" ]]; then
        echo "$YELLOW"
    else
        echo "$GREEN"
    fi
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

# Compteurs
total_quotas_checked=0
quotas_over_threshold=0
quotas_critical=0  # > 90%

# Quotas importants à vérifier
IMPORTANT_QUOTAS=(
    "CPUS"
    "DISKS_TOTAL_GB"
    "SSD_TOTAL_GB"
    "INSTANCES"
    "IN_USE_ADDRESSES"
    "STATIC_ADDRESSES"
)

if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo "  \"threshold\": $THRESHOLD,"
    echo '  "quotas": ['
    first_quota=true
else
    echo -e "${GREEN}Vérification des quotas...${NC}"
    echo ""
    printf "%-25s %-20s %-25s %-12s %-12s %-10s\n" \
        "PROJECT_ID" "REGION" "METRIC" "USAGE" "LIMIT" "PERCENT"
    printf "%-25s %-20s %-25s %-12s %-12s %-10s\n" \
        "----------" "------" "------" "-----" "-----" "-------"
fi

# Détermine la liste des projets
if [[ -n "$SINGLE_PROJECT" ]]; then
    project_list="$SINGLE_PROJECT"
else
    project_list=$(gcloud projects list --format="value(projectId)")
fi

# Boucle sur les projets
while read -r project_id; do
    [[ -z "$project_id" ]] && continue

    # Récupère les régions pour ce projet
    regions=$(gcloud compute regions list \
        --project="$project_id" \
        --format="value(name)" 2>/dev/null || echo "")

    if [[ -z "$regions" ]]; then
        # Essaie au moins la région par défaut
        regions="us-central1"
    fi

    # Pour chaque région
    while read -r region; do
        [[ -z "$region" ]] && continue

        # Récupère les quotas pour cette région
        quotas=$(gcloud compute regions describe "$region" \
            --project="$project_id" \
            --format="value(quotas.metric,quotas.usage,quotas.limit)" 2>/dev/null || echo "")

        if [[ -n "$quotas" ]]; then
            while IFS=$'\t' read -r metric usage limit; do
                # Filtre pour ne garder que les quotas importants
                important=false
                for important_metric in "${IMPORTANT_QUOTAS[@]}"; do
                    if [[ "$metric" == "$important_metric" ]]; then
                        important=true
                        break
                    fi
                done

                if [[ "$important" == false ]]; then
                    continue
                fi

                ((total_quotas_checked++))

                # Calcule le pourcentage
                percentage=$(calculate_percentage "$usage" "$limit")

                # Vérifie si au-dessus du seuil
                if [[ "$percentage" != "N/A" ]]; then
                    if [[ "$percentage" -ge "$THRESHOLD" ]]; then
                        ((quotas_over_threshold++))
                    fi
                    if [[ "$percentage" -ge 90 ]]; then
                        ((quotas_critical++))
                    fi
                fi

                # Affiche seulement si au-dessus du seuil ou en mode JSON
                if [[ "$JSON_MODE" == true ]] || [[ "$percentage" != "N/A" && "$percentage" -ge "$THRESHOLD" ]] || [[ "$usage" != "0" ]]; then
                    if [[ "$JSON_MODE" == true ]]; then
                        [[ "$first_quota" == false ]] && echo ","
                        first_quota=false
                        cat <<EOF
    {
      "project_id": "$project_id",
      "region": "$region",
      "metric": "$metric",
      "usage": $usage,
      "limit": $limit,
      "percentage": "$percentage"
    }
EOF
                    else
                        # Détermine la couleur
                        color=$(get_color_for_percentage "$percentage")

                        # Formatte l'affichage
                        if [[ "$percentage" != "N/A" ]]; then
                            percent_display="${color}${percentage}%${NC}"
                        else
                            percent_display="N/A"
                        fi

                        printf "%-25s %-20s %-25s %-12s %-12s %-18s\n" \
                            "${project_id:0:23}" \
                            "${region:0:18}" \
                            "${metric:0:23}" \
                            "$usage" \
                            "$limit" \
                            "$percent_display"
                    fi
                fi
            done <<< "$quotas"
        fi
    done <<< "$regions"

    # Vérifie aussi les quotas globaux (non régionaux)
    global_quotas=$(gcloud compute project-info describe \
        --project="$project_id" \
        --format="value(quotas.metric,quotas.usage,quotas.limit)" 2>/dev/null || echo "")

    if [[ -n "$global_quotas" ]]; then
        while IFS=$'\t' read -r metric usage limit; do
            # Filtre pour ne garder que les quotas importants
            important=false
            for important_metric in "${IMPORTANT_QUOTAS[@]}"; do
                if [[ "$metric" == "$important_metric" ]]; then
                    important=true
                    break
                fi
            done

            if [[ "$important" == false ]]; then
                continue
            fi

            ((total_quotas_checked++))
            percentage=$(calculate_percentage "$usage" "$limit")

            if [[ "$percentage" != "N/A" ]]; then
                if [[ "$percentage" -ge "$THRESHOLD" ]]; then
                    ((quotas_over_threshold++))
                fi
                if [[ "$percentage" -ge 90 ]]; then
                    ((quotas_critical++))
                fi
            fi

            # Affiche seulement si au-dessus du seuil ou en mode JSON
            if [[ "$JSON_MODE" == true ]] || [[ "$percentage" != "N/A" && "$percentage" -ge "$THRESHOLD" ]] || [[ "$usage" != "0" ]]; then
                if [[ "$JSON_MODE" == true ]]; then
                    [[ "$first_quota" == false ]] && echo ","
                    first_quota=false
                    cat <<EOF
    {
      "project_id": "$project_id",
      "region": "global",
      "metric": "$metric",
      "usage": $usage,
      "limit": $limit,
      "percentage": "$percentage"
    }
EOF
                else
                    color=$(get_color_for_percentage "$percentage")

                    if [[ "$percentage" != "N/A" ]]; then
                        percent_display="${color}${percentage}%${NC}"
                    else
                        percent_display="N/A"
                    fi

                    printf "%-25s %-20s %-25s %-12s %-12s %-18s\n" \
                        "${project_id:0:23}" \
                        "global" \
                        "${metric:0:23}" \
                        "$usage" \
                        "$limit" \
                        "$percent_display"
                fi
            fi
        done <<< "$global_quotas"
    fi

done <<< "$project_list"

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "  ],"
    echo '  "summary": {'
    echo "    \"total_quotas_checked\": $total_quotas_checked,"
    echo "    \"quotas_over_threshold\": $quotas_over_threshold,"
    echo "    \"quotas_critical\": $quotas_critical"
    echo "  }"
    echo "}"
else
    echo ""
    echo -e "${CYAN}========== Résumé ==========${NC}"
    echo -e "Quotas vérifiés:           ${BLUE}$total_quotas_checked${NC}"
    echo -e "Au-dessus du seuil (${THRESHOLD}%):  ${YELLOW}$quotas_over_threshold${NC}"
    echo -e "Critiques (>90%):          ${RED}$quotas_critical${NC}"
    echo ""
    if [[ "$quotas_critical" -gt 0 ]]; then
        echo -e "${RED}ATTENTION: $quotas_critical quota(s) critique(s) détecté(s)!${NC}"
        echo -e "${YELLOW}Action recommandée: Augmentez les quotas ou réduisez l'utilisation${NC}"
    elif [[ "$quotas_over_threshold" -gt 0 ]]; then
        echo -e "${YELLOW}Avertissement: $quotas_over_threshold quota(s) approchent de la limite${NC}"
        echo -e "${YELLOW}Surveillez ces quotas de près${NC}"
    else
        echo -e "${GREEN}Tous les quotas sont dans les limites acceptables${NC}"
    fi
    echo ""
    echo -e "${CYAN}Pour demander une augmentation de quota:${NC}"
    echo -e "  Console: IAM & Admin > Quotas"
    echo -e "  Ou: gcloud compute project-info describe --project PROJECT_ID"
fi
