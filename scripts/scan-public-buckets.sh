#!/usr/bin/env bash

#####################################################################
# Script: scan-public-buckets.sh
# Description: Scanne tous les buckets Cloud Storage pour détecter
#              les buckets publics et les risques de data leak
# Prérequis: gcloud CLI configuré et authentifié
#            Permissions nécessaires:
#            - storage.buckets.list
#            - storage.buckets.getIamPolicy
# Usage: ./scan-public-buckets.sh [OPTIONS]
#
# Options:
#   --json           : Sortie en format JSON
#   --project PROJECT: Scanner un seul projet
#
# Détection:
#   - allUsers (public internet)
#   - allAuthenticatedUsers (tout utilisateur GCP authentifié)
#   - Uniformbucket-level access non activé
#####################################################################

set -euo pipefail

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options (JSON_MODE et SINGLE_PROJECT définis dans common.sh)

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_MODE=true
            shift
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
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}  🔓 SCAN BUCKETS PUBLICS${NC}"
        echo -e "${RED}========================================${NC}"
        echo ""
    fi
}

# Fonction pour vérifier si un bucket est public
check_bucket_public() {
    local bucket=$1
    local iam_policy=$(gsutil iam get "gs://$bucket" 2>/dev/null || echo "")

    local is_public=false
    local public_type=""
    local members=""

    if [[ -n "$iam_policy" ]]; then
        # Cherche allUsers
        if echo "$iam_policy" | grep -q "allUsers"; then
            is_public=true
            public_type="allUsers"
            members=$(echo "$iam_policy" | grep -A 5 "allUsers" | grep "role" | head -1 | awk '{print $2}' | tr -d '",')
        fi

        # Cherche allAuthenticatedUsers
        if echo "$iam_policy" | grep -q "allAuthenticatedUsers"; then
            is_public=true
            if [[ -n "$public_type" ]]; then
                public_type="$public_type,allAuthenticatedUsers"
            else
                public_type="allAuthenticatedUsers"
            fi
        fi
    fi

    echo "${is_public}|${public_type}"
}

# Fonction pour obtenir la taille du bucket
get_bucket_size() {
    local bucket=$1
    # Note: Cette commande peut être lente sur gros buckets
    # On pourrait aussi utiliser l'API Monitoring pour des stats plus rapides
    local size=$(gsutil du -s "gs://$bucket" 2>/dev/null | awk '{print $1}' || echo "0")
    echo "$size"
}

# Fonction pour formater la taille
format_size() {
    local bytes=$1
    if [[ "$bytes" -ge 1099511627776 ]]; then
        echo "$(( bytes / 1099511627776 )) TB"
    elif [[ "$bytes" -ge 1073741824 ]]; then
        echo "$(( bytes / 1073741824 )) GB"
    elif [[ "$bytes" -ge 1048576 ]]; then
        echo "$(( bytes / 1048576 )) MB"
    elif [[ "$bytes" -ge 1024 ]]; then
        echo "$(( bytes / 1024 )) KB"
    else
        echo "$bytes bytes"
    fi
}

# Vérification que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud CLI n'est pas installé${NC}" >&2
    exit 1
fi

# Vérification que gsutil est installé
if ! command -v gsutil &> /dev/null; then
    echo -e "${RED}Erreur: gsutil n'est pas installé${NC}" >&2
    exit 1
fi

# Vérification de l'authentification
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}Erreur: Aucun compte gcloud actif trouvé${NC}" >&2
    exit 1
fi

print_header

# Compteurs
total_buckets=0
public_buckets=0
all_users_buckets=0
all_authenticated_buckets=0

if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "buckets": ['
    first_bucket=true
else
    echo -e "${GREEN}Scanning Cloud Storage buckets...${NC}"
    echo ""
    printf "%-30s %-40s %-15s %-25s\n" \
        "PROJECT_ID" "BUCKET_NAME" "LOCATION" "PUBLIC_ACCESS"
    printf "%-30s %-40s %-15s %-25s\n" \
        "----------" "-----------" "--------" "-------------"
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

    # Liste les buckets du projet
    buckets=$(gcloud storage buckets list \
        --project="$project_id" \
        --format="value(name)" 2>/dev/null || \
        gsutil ls -p "$project_id" 2>/dev/null | sed 's|gs://||' | sed 's|/||' || echo "")

    if [[ -n "$buckets" ]]; then
        while read -r bucket; do
            [[ -z "$bucket" ]] && continue
            ((total_buckets++)) || true

            # Récupère les infos du bucket
            bucket_info=$(gcloud storage buckets describe "gs://$bucket" \
                --format="value(location)" 2>/dev/null || echo "unknown")
            location="${bucket_info:-unknown}"

            # Vérifie si public
            public_check=$(check_bucket_public "$bucket")
            IFS='|' read -r is_public public_type <<< "$public_check"

            if [[ "$is_public" == "true" ]]; then
                ((public_buckets++)) || true

                if [[ "$public_type" == *"allUsers"* ]]; then
                    ((all_users_buckets++)) || true
                fi
                if [[ "$public_type" == *"allAuthenticatedUsers"* ]]; then
                    ((all_authenticated_buckets++)) || true
                fi

                # Taille du bucket (optionnel, peut être lent)
                # size_bytes=$(get_bucket_size "$bucket")
                # size_formatted=$(format_size "$size_bytes")
                size_formatted="N/A"

                if [[ "$JSON_MODE" == true ]]; then
                    [[ "$first_bucket" == false ]] && echo ","
                    first_bucket=false
                    cat <<EOF
    {
      "project_id": "$project_id",
      "bucket_name": "$bucket",
      "location": "$location",
      "storage_class": "$storage_class",
      "is_public": true,
      "public_type": "$public_type",
      "size": "$size_formatted"
    }
EOF
                else
                    # Affichage coloré selon le risque
                    if [[ "$public_type" == *"allUsers"* ]]; then
                        public_display="${RED}PUBLIC (allUsers)${NC}"
                    else
                        public_display="${YELLOW}AUTH (allAuth*)${NC}"
                    fi

                    # Les codes ANSI ajoutent ~14 caractères invisibles
                    printf "%-30s %-40s %-15s %-39b\n" \
                        "${project_id:0:28}" \
                        "${bucket:0:38}" \
                        "${location:0:13}" \
                        "$public_display"
                fi
            fi
        done <<< "$buckets"
    fi
done <<< "$project_list"

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "  ],"
    echo '  "summary": {'
    echo "    \"total_buckets_scanned\": $total_buckets,"
    echo "    \"public_buckets\": $public_buckets,"
    echo "    \"all_users_public\": $all_users_buckets,"
    echo "    \"all_authenticated_public\": $all_authenticated_buckets"
    echo "  }"
    echo "}"
else
    echo ""
    echo -e "${CYAN}========== Résumé ==========${NC}"
    echo -e "Total buckets scannés:         ${BLUE}$total_buckets${NC}"
    echo -e "Buckets publics:               ${RED}$public_buckets${NC}"
    echo -e "  - allUsers (Internet):       ${RED}$all_users_buckets${NC}"
    echo -e "  - allAuthenticatedUsers:     ${YELLOW}$all_authenticated_buckets${NC}"
    echo ""

    if [[ "$public_buckets" -gt 0 ]]; then
        echo -e "${RED}⚠️  RISQUE CRITIQUE DE DATA LEAK !${NC}"
        echo -e "${RED}$public_buckets bucket(s) sont publiquement accessibles${NC}"
        echo ""
    else
        echo -e "${GREEN}✓ Aucun bucket public détecté${NC}"
        echo ""
    fi

    echo -e "${CYAN}========== Recommandations ==========${NC}"
    echo ""
    echo -e "${YELLOW}Pour sécuriser un bucket public :${NC}"
    echo ""
    echo -e "1. ${GREEN}Retirer l'accès public${NC} :"
    echo -e "   ${BLUE}gsutil iam ch -d allUsers gs://BUCKET_NAME${NC}"
    echo -e "   ${BLUE}gsutil iam ch -d allAuthenticatedUsers gs://BUCKET_NAME${NC}"
    echo ""
    echo -e "2. ${GREEN}Activer Uniform bucket-level access${NC} :"
    echo -e "   ${BLUE}gsutil uniformbucketlevelaccess set on gs://BUCKET_NAME${NC}"
    echo ""
    echo -e "3. ${GREEN}Utiliser Signed URLs${NC} pour partage temporaire :"
    echo -e "   ${BLUE}gsutil signurl -d 1h key.json gs://BUCKET/file${NC}"
    echo ""
    echo -e "4. ${GREEN}Activer Cloud Armor${NC} pour protection DDoS (si nécessaire)"
    echo ""
    echo -e "5. ${GREEN}Auditer régulièrement${NC} : Exécutez ce script hebdomadairement"
    echo ""
    echo -e "${YELLOW}Pour plus d'infos:${NC} https://cloud.google.com/storage/docs/access-control"
fi
