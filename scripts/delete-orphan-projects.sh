#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# Script: delete-orphan-projects.sh
# Description: Supprime les projets GCP qui n'ont pas de propriétaire
#
# Prérequis: gcloud CLI avec permissions:
#            - resourcemanager.projects.list
#            - resourcemanager.projects.getIamPolicy
#            - resourcemanager.projects.delete
#
# Usage: ./delete-orphan-projects.sh [OPTIONS]
#
# Options:
#   --dry-run      : Liste les projets sans owner sans les supprimer
#   --force        : Supprime sans demander de confirmation
#   --project ID   : Vérifie un seul projet
#####################################################################

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options
DRY_RUN=false
FORCE_DELETE=false
SINGLE_PROJECT=""

# Afficher l'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Supprime les projets GCP qui n'ont pas de propriétaire (owner)."
    echo ""
    echo "Options:"
    echo "  --dry-run      Liste les projets sans owner sans les supprimer"
    echo "  --force        Supprime sans demander de confirmation"
    echo "  --project ID   Vérifie un seul projet"
    echo "  --help         Affiche cette aide"
}

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --force) FORCE_DELETE=true; shift ;;
        --project) SINGLE_PROJECT="$2"; shift 2 ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "Option inconnue: $1" >&2; show_help; exit 1 ;;
    esac
done

# Vérifier que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2
    exit 1
fi

# Fonction pour vérifier si un projet a un owner
has_owner() {
    local project_id=$1

    # Récupère les membres avec le rôle owner
    local owners=$(gcloud projects get-iam-policy "$project_id" \
        --flatten="bindings[].members" \
        --format="value(bindings.members)" \
        --filter="bindings.role:roles/owner" \
        --quiet 2>/dev/null || true)

    # Filtre les service accounts (on cherche des users/groups)
    local human_owners=$(echo "$owners" | grep -E "^(user:|group:)" || true)

    if [[ -n "$human_owners" ]]; then
        return 0  # A un owner humain
    else
        return 1  # Pas d'owner humain
    fi
}

# Afficher l'en-tête
echo -e "${RED}========================================${NC}"
echo -e "${RED}  PROJETS SANS PROPRIETAIRE${NC}"
echo -e "${RED}========================================${NC}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${CYAN}Mode: DRY RUN (aucune suppression)${NC}"
    echo ""
fi

# Liste des projets sans owner
orphan_projects=()

# Détermine la liste des projets
if [[ -n "$SINGLE_PROJECT" ]]; then
    projects="$SINGLE_PROJECT"
else
    projects=$(gcloud projects list --format="value(projectId)" --quiet 2>/dev/null)
fi

total_projects=0

echo -e "${CYAN}Analyse des projets...${NC}"
echo ""

while read -r project_id; do
    [[ -z "$project_id" ]] && continue
    ((total_projects++)) || true

    # Afficher progression
    echo -ne "\r${CYAN}Analyse: ${project_id}${NC}                              " >&2

    if ! has_owner "$project_id"; then
        orphan_projects+=("$project_id")
    fi
done <<< "$projects"

# Effacer la ligne de progression
echo -ne "\r                                                                        \r" >&2

orphan_count=${#orphan_projects[@]}

# Afficher les résultats
echo -e "${CYAN}========== Résultat ==========${NC}"
echo -e "Total projets analysés: ${BLUE}$total_projects${NC}"
echo -e "Projets sans owner:     ${RED}$orphan_count${NC}"
echo ""

if [[ $orphan_count -eq 0 ]]; then
    echo -e "${GREEN}Aucun projet orphelin trouvé.${NC}"
    exit 0
fi

# Afficher la liste des projets orphelins
echo -e "${YELLOW}Projets sans propriétaire:${NC}"
for project in "${orphan_projects[@]}"; do
    echo -e "  - $project"
done
echo ""

# Mode dry-run : on s'arrête là
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${CYAN}Mode DRY RUN - aucune suppression effectuée${NC}"
    echo ""
    echo -e "Pour supprimer ces projets, relancez sans --dry-run"
    exit 0
fi

# Demander confirmation (sauf si --force)
if [[ "$FORCE_DELETE" == false ]]; then
    echo -e "${RED}ATTENTION: Cette action est irréversible!${NC}"
    echo -n "Confirmez-vous la suppression de $orphan_count projet(s)? (oui/non): "
    read -r response
    if [[ "$response" != "oui" ]]; then
        echo -e "${YELLOW}Suppression annulée${NC}"
        exit 0
    fi
    echo ""
fi

# Compteurs
deleted=0
failed=0

# Supprimer chaque projet
for project in "${orphan_projects[@]}"; do
    echo -n "Suppression de $project... "
    if gcloud projects delete "$project" --quiet 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
        ((deleted++)) || true
    else
        echo -e "${RED}ECHEC${NC}"
        ((failed++)) || true
    fi
done

# Résumé
echo ""
echo -e "${CYAN}========== Résumé ==========${NC}"
echo -e "Projets supprimés: ${GREEN}$deleted${NC}"
echo -e "Échecs:            ${RED}$failed${NC}"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
