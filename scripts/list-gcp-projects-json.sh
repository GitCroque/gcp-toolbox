#!/usr/bin/env bash

#####################################################################
# Script: list-gcp-projects-json.sh
# Description: Liste tous les projets GCP en format JSON
# Prérequis: gcloud CLI configuré et authentifié
# Usage: ./list-gcp-projects-json.sh [output-file.json]
#####################################################################

set -euo pipefail

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

OUTPUT_FILE="${1:-}"

# Vérification que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    echo '{"error": "gcloud CLI is not installed"}' >&2
    exit 1
fi

# Vérification de l'authentification
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo '{"error": "No active gcloud account found"}' >&2
    exit 1
fi

# Fonction pour obtenir le propriétaire d'un projet
get_project_owner() {
    local project_id=$1

    local owner=$(gcloud projects get-iam-policy "$project_id" \
        --flatten="bindings[].members" \
        --format="value(bindings.members)" \
        --filter="bindings.role:roles/owner" 2>/dev/null | head -n 1)

    if [ -z "$owner" ]; then
        owner=$(gcloud projects get-iam-policy "$project_id" \
            --flatten="bindings[].members" \
            --format="value(bindings.members)" \
            --filter="bindings.role:roles/editor" 2>/dev/null | head -n 1)
    fi

    if [ -z "$owner" ]; then
        echo "null"
    else
        # Échapper les guillemets pour JSON
        echo "\"$owner\""
    fi
}

# Début du JSON
echo "{"
echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
echo '  "projects": ['

first=true

# Liste tous les projets
gcloud projects list --format="value(projectId,name,projectNumber,createTime)" | while IFS=$'\t' read -r project_id name project_number create_time; do
    # Virgule entre les éléments (sauf pour le premier)
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi

    # Récupère le propriétaire
    owner=$(get_project_owner "$project_id")

    # Formatage de la date
    formatted_date=$(echo "$create_time" | cut -d'.' -f1)

    # Échapper les guillemets et backslashes dans les chaînes
    safe_name=$(echo "$name" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

    # Génère l'objet JSON pour ce projet
    cat <<EOF
    {
      "project_id": "$project_id",
      "name": "$safe_name",
      "project_number": "$project_number",
      "create_time": "$formatted_date",
      "owner": $owner
    }
EOF
done

# Fin du JSON
echo ""
echo "  ]"
echo "}"
