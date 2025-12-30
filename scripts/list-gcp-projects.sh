#!/usr/bin/env bash

#####################################################################
# Script: list-gcp-projects.sh
# Description: Liste tous les projets GCP avec leurs informations
#              (nom, date de création, propriétaire)
# Prérequis: gcloud CLI configuré et authentifié
#####################################################################

set -euo pipefail

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Fonction d'affichage
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Liste des Projets GCP${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Fonction pour obtenir le propriétaire d'un projet
get_project_owner() {
    local project_id=$1

    # Récupère le propriétaire via IAM policy (cherche le rôle owner)
    local owner=$(gcloud projects get-iam-policy "$project_id" \
        --flatten="bindings[].members" \
        --format="table(bindings.members)" \
        --filter="bindings.role:roles/owner" 2>/dev/null | \
        grep -v "MEMBERS" | head -n 1 | xargs)

    # Si pas de owner trouvé, essaie de trouver un editor
    if [ -z "$owner" ]; then
        owner=$(gcloud projects get-iam-policy "$project_id" \
            --flatten="bindings[].members" \
            --format="table(bindings.members)" \
            --filter="bindings.role:roles/editor" 2>/dev/null | \
            grep -v "MEMBERS" | head -n 1 | xargs)
    fi

    # Si toujours vide, retourne "N/A"
    if [ -z "$owner" ]; then
        echo "N/A"
    else
        echo "$owner"
    fi
}

# Vérification que gcloud est installé et configuré
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud CLI n'est pas installé${NC}"
    exit 1
fi

# Vérification de l'authentification
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}Erreur: Aucun compte gcloud actif trouvé${NC}"
    echo -e "${YELLOW}Veuillez vous authentifier avec: gcloud auth login${NC}"
    exit 1
fi

print_header

# Récupération de la liste des projets
echo -e "${GREEN}Récupération de la liste des projets...${NC}"
echo ""

# Format de sortie
printf "%-30s %-30s %-25s %-50s\n" "PROJECT_ID" "NAME" "CREATE_TIME" "OWNER"
printf "%-30s %-30s %-25s %-50s\n" "----------" "----" "-----------" "-----"

# Liste tous les projets
gcloud projects list --format="value(projectId,name,createTime)" | while IFS=$'\t' read -r project_id name create_time; do
    # Récupère le propriétaire
    owner=$(get_project_owner "$project_id")

    # Formatage de la date (supprime les microsecondes si présentes)
    formatted_date=$(echo "$create_time" | cut -d'.' -f1)

    # Affichage de la ligne
    printf "%-30s %-30s %-25s %-50s\n" \
        "$project_id" \
        "${name:0:28}" \
        "$formatted_date" \
        "$owner"
done

echo ""
echo -e "${GREEN}Terminé!${NC}"
