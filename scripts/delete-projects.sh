#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# Script: delete-projects.sh
# Description: Supprime des projets GCP à partir d'un fichier texte
#
# Prérequis: gcloud CLI avec permissions resourcemanager.projects.delete
#
# Usage: ./delete-projects.sh --from FILE [OPTIONS]
#
# Options:
#   --from FILE    : Fichier contenant les project IDs (un par ligne)
#   --force        : Supprime sans demander de confirmation
#
# Format du fichier:
#   - Un project ID par ligne
#   - Les lignes vides sont ignorées
#   - Les lignes commençant par # sont des commentaires
#####################################################################

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options
DELETE_FROM_FILE=""
FORCE_DELETE=false

# Afficher l'aide
show_help() {
    echo "Usage: $0 --from FILE [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --from FILE    Fichier contenant les project IDs (un par ligne)"
    echo "  --force        Supprime sans demander de confirmation"
    echo "  --help         Affiche cette aide"
    echo ""
    echo "Exemple:"
    echo "  $0 --from projets-a-supprimer.txt"
    echo "  $0 --from projets.txt --force"
}

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --from) DELETE_FROM_FILE="$2"; shift 2 ;;
        --force) FORCE_DELETE=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "Option inconnue: $1" >&2; show_help; exit 1 ;;
    esac
done

# Vérifier que --from est spécifié
if [[ -z "$DELETE_FROM_FILE" ]]; then
    echo -e "${RED}Erreur: L'option --from FILE est requise${NC}" >&2
    echo ""
    show_help
    exit 1
fi

# Vérifier que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2
    exit 1
fi

# Vérifier que le fichier existe
if [[ ! -f "$DELETE_FROM_FILE" ]]; then
    echo -e "${RED}Erreur: Le fichier '$DELETE_FROM_FILE' n'existe pas${NC}" >&2
    exit 1
fi

# Lire les projets (ignorer lignes vides et commentaires)
projects=()
while IFS= read -r line || [[ -n "$line" ]]; do
    # Ignorer les lignes vides et les commentaires
    line=$(echo "$line" | xargs)
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    projects+=("$line")
done < "$DELETE_FROM_FILE"

count=${#projects[@]}

if [[ $count -eq 0 ]]; then
    echo -e "${YELLOW}Aucun projet à supprimer dans le fichier${NC}"
    exit 0
fi

# Afficher l'en-tête
echo -e "${RED}========================================${NC}"
echo -e "${RED}  SUPPRESSION DE PROJETS GCP${NC}"
echo -e "${RED}========================================${NC}"
echo ""

# Afficher la liste des projets
echo -e "${YELLOW}Projets à supprimer ($count):${NC}"
for project in "${projects[@]}"; do
    echo -e "  - $project"
done
echo ""

# Demander confirmation (sauf si --force)
if [[ "$FORCE_DELETE" == false ]]; then
    echo -e "${RED}ATTENTION: Cette action est irréversible!${NC}"
    echo -n "Confirmez-vous la suppression de $count projet(s)? (oui/non): "
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
for project in "${projects[@]}"; do
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
