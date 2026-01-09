#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# Script: project-usage-score.sh
# Description: Calcule un score d'utilisation pour les projets GCP
#              Score de 0 (inutilisé) à 100 (très actif)
#
# Prérequis: gcloud CLI avec permissions de lecture sur les projets
#
# Usage: ./project-usage-score.sh [OPTIONS]
#
# Options:
#   --project PROJECT_ID  : Analyser un seul projet
#   --json                : Sortie JSON
#   --min-score N         : Afficher uniquement les projets avec score < N
#####################################################################

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options
SINGLE_PROJECT=""
MIN_SCORE=101  # Par défaut, afficher tous les projets

# Afficher l'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Calcule un score d'utilisation pour les projets GCP."
    echo "Score de 0 (inutilisé) à 100 (très actif)."
    echo ""
    echo "Options:"
    echo "  --project ID    Analyser un seul projet"
    echo "  --json          Sortie JSON"
    echo "  --min-score N   Afficher uniquement les projets avec score < N"
    echo "  --help          Affiche cette aide"
    echo ""
    echo "Critères de scoring:"
    echo "  - Ressources compute (VMs, GKE, Cloud Run): 0-30 pts"
    echo "  - Données (SQL, Buckets, BigQuery): 0-25 pts"
    echo "  - Activité récente (logs 30j): 0-25 pts"
    echo "  - Services activés: 0-20 pts"
}

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project) SINGLE_PROJECT="$2"; shift 2 ;;
        --json) JSON_MODE=true; shift ;;
        --min-score) MIN_SCORE="$2"; shift 2 ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "Option inconnue: $1" >&2; show_help; exit 1 ;;
    esac
done

# Vérifier que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2
    exit 1
fi

# Fonction pour calculer le score d'un projet
calculate_score() {
    local project_id=$1
    local score=0
    local details=""

    # === RESSOURCES COMPUTE (max 30 pts) ===
    local compute_score=0

    # VMs (max 15 pts)
    local vm_count=$(gcloud compute instances list --project="$project_id" --format="value(name)" --quiet 2>/dev/null | grep -c . 2>/dev/null) || vm_count=0
    if [[ $vm_count -gt 0 ]]; then
        if [[ $vm_count -ge 10 ]]; then
            compute_score=$((compute_score + 15))
        elif [[ $vm_count -ge 5 ]]; then
            compute_score=$((compute_score + 10))
        else
            compute_score=$((compute_score + 5))
        fi
        details="${details}VMs:$vm_count "
    fi

    # GKE clusters (max 10 pts)
    local gke_count=$(gcloud container clusters list --project="$project_id" --format="value(name)" --quiet 2>/dev/null | grep -c . 2>/dev/null) || gke_count=0
    if [[ $gke_count -gt 0 ]]; then
        if [[ $gke_count -ge 3 ]]; then
            compute_score=$((compute_score + 10))
        else
            compute_score=$((compute_score + 5))
        fi
        details="${details}GKE:$gke_count "
    fi

    # Cloud Run services (max 5 pts)
    local run_count=$(gcloud run services list --project="$project_id" --format="value(name)" --quiet 2>/dev/null | grep -c . 2>/dev/null) || run_count=0
    if [[ $run_count -gt 0 ]]; then
        compute_score=$((compute_score + 5))
        details="${details}CloudRun:$run_count "
    fi

    # Cap compute score at 30
    [[ $compute_score -gt 30 ]] && compute_score=30
    score=$((score + compute_score))

    # === DONNEES (max 25 pts) ===
    local data_score=0

    # Cloud SQL (max 10 pts)
    local sql_count=$(gcloud sql instances list --project="$project_id" --format="value(name)" --quiet 2>/dev/null | grep -c . 2>/dev/null) || sql_count=0
    if [[ $sql_count -gt 0 ]]; then
        data_score=$((data_score + 10))
        details="${details}SQL:$sql_count "
    fi

    # Buckets (max 10 pts)
    local bucket_count=$(gcloud storage buckets list --project="$project_id" --format="value(name)" --quiet 2>/dev/null | grep -c . 2>/dev/null) || bucket_count=0
    if [[ $bucket_count -gt 0 ]]; then
        if [[ $bucket_count -ge 5 ]]; then
            data_score=$((data_score + 10))
        else
            data_score=$((data_score + 5))
        fi
        details="${details}Buckets:$bucket_count "
    fi

    # BigQuery datasets (max 5 pts)
    local bq_count=$(bq ls --project_id="$project_id" --format=json 2>/dev/null | grep -c "datasetId" 2>/dev/null) || bq_count=0
    if [[ $bq_count -gt 0 ]]; then
        data_score=$((data_score + 5))
        details="${details}BQ:$bq_count "
    fi

    # Cap data score at 25
    [[ $data_score -gt 25 ]] && data_score=25
    score=$((score + data_score))

    # === ACTIVITE RECENTE (max 25 pts) ===
    local activity_score=0

    # Logs des 30 derniers jours
    local log_count=0
    if command -v gdate &> /dev/null; then
        # macOS avec coreutils
        log_count=$(gcloud logging read "timestamp>=\"$(gdate -d '30 days ago' +%Y-%m-%d)\"" \
            --project="$project_id" --limit=100 --format="value(timestamp)" --quiet 2>/dev/null | grep -c . 2>/dev/null) || log_count=0
    else
        # Linux ou fallback
        log_count=$(gcloud logging read "timestamp>=\"$(date -d '30 days ago' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)\"" \
            --project="$project_id" --limit=100 --format="value(timestamp)" --quiet 2>/dev/null | grep -c . 2>/dev/null) || log_count=0
    fi

    if [[ $log_count -gt 0 ]]; then
        if [[ $log_count -ge 100 ]]; then
            activity_score=25
        elif [[ $log_count -ge 50 ]]; then
            activity_score=20
        elif [[ $log_count -ge 10 ]]; then
            activity_score=15
        else
            activity_score=10
        fi
        details="${details}Logs30j:${log_count}+ "
    fi

    score=$((score + activity_score))

    # === SERVICES ACTIVES (max 20 pts) ===
    local services_score=0

    local services_count=$(gcloud services list --project="$project_id" --enabled --format="value(name)" --quiet 2>/dev/null | grep -c . 2>/dev/null) || services_count=0
    if [[ $services_count -gt 0 ]]; then
        if [[ $services_count -ge 20 ]]; then
            services_score=20
        elif [[ $services_count -ge 10 ]]; then
            services_score=15
        elif [[ $services_count -ge 5 ]]; then
            services_score=10
        else
            services_score=5
        fi
        details="${details}APIs:$services_count "
    fi

    score=$((score + services_score))

    # Retourner le résultat
    echo "$score|$details"
}

# Fonction pour afficher le niveau d'utilisation
get_usage_level() {
    local score=$1
    if [[ $score -ge 70 ]]; then
        echo -e "${GREEN}ACTIF${NC}"
    elif [[ $score -ge 40 ]]; then
        echo -e "${YELLOW}MODERE${NC}"
    elif [[ $score -ge 15 ]]; then
        echo -e "${YELLOW}FAIBLE${NC}"
    else
        echo -e "${RED}INUTILISE${NC}"
    fi
}

# Afficher l'en-tête
if [[ "$JSON_MODE" == false ]]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  SCORE D'UTILISATION DES PROJETS${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
fi

# Détermine la liste des projets
if [[ -n "$SINGLE_PROJECT" ]]; then
    projects="$SINGLE_PROJECT"
else
    projects=$(gcloud projects list --format="value(projectId)" --quiet 2>/dev/null)
fi

total_projects=0
results=()

if [[ "$JSON_MODE" == false ]]; then
    echo -e "${CYAN}Analyse des projets...${NC}"
    echo ""
fi

while read -r project_id; do
    [[ -z "$project_id" ]] && continue
    ((total_projects++)) || true

    # Afficher progression
    [[ "$JSON_MODE" == false ]] && echo -ne "\r${CYAN}Analyse: ${project_id}${NC}                              " >&2

    # Calculer le score
    result=$(calculate_score "$project_id")
    score=$(echo "$result" | cut -d'|' -f1)
    details=$(echo "$result" | cut -d'|' -f2)

    # Filtrer par score minimum si spécifié
    if [[ $score -lt $MIN_SCORE ]]; then
        results+=("$score|$project_id|$details")
    fi
done <<< "$projects"

# Effacer la ligne de progression
[[ "$JSON_MODE" == false ]] && echo -ne "\r                                                                        \r" >&2

# Trier les résultats par score (croissant)
IFS=$'\n' sorted_results=($(sort -t'|' -k1 -n <<< "${results[*]}")); unset IFS

if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo "  \"generated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"total_projects\": $total_projects,"
    echo "  \"projects\": ["
    first=true
    for result in "${sorted_results[@]}"; do
        score=$(echo "$result" | cut -d'|' -f1)
        project=$(echo "$result" | cut -d'|' -f2)
        details=$(echo "$result" | cut -d'|' -f3)

        [[ "$first" == false ]] && echo ","
        first=false
        echo -n "    {\"project\": \"$project\", \"score\": $score, \"details\": \"$details\"}"
    done
    echo ""
    echo "  ]"
    echo "}"
else
    # Afficher les résultats
    echo ""
    printf "%-35s %-8s %-12s %s\n" "PROJECT_ID" "SCORE" "NIVEAU" "DETAILS"
    printf "%-35s %-8s %-12s %s\n" "----------" "-----" "------" "-------"

    for result in "${sorted_results[@]}"; do
        score=$(echo "$result" | cut -d'|' -f1)
        project=$(echo "$result" | cut -d'|' -f2)
        details=$(echo "$result" | cut -d'|' -f3)
        level=$(get_usage_level "$score")

        printf "%-35s %-8s %-22b %s\n" "${project:0:33}" "$score/100" "$level" "$details"
    done

    # Résumé
    echo ""
    echo -e "${CYAN}========== Résumé ==========${NC}"
    echo -e "Total projets analysés: ${BLUE}$total_projects${NC}"
    echo -e "Projets affichés:       ${BLUE}${#sorted_results[@]}${NC}"
    echo ""
    echo -e "${CYAN}Légende des scores:${NC}"
    echo -e "  ${GREEN}70-100${NC} : ACTIF     - Projet très utilisé"
    echo -e "  ${YELLOW}40-69${NC}  : MODERE   - Utilisation moyenne"
    echo -e "  ${YELLOW}15-39${NC}  : FAIBLE   - Peu utilisé"
    echo -e "  ${RED}0-14${NC}   : INUTILISE - Candidat à la suppression"
fi
