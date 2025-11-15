#!/bin/bash

#####################################################################
# Script: audit-iam-permissions.sh
# Description: Audit des permissions IAM dans tous les projets GCP
#              Liste qui a accès à quoi (owner, editor, viewer, etc.)
# Prérequis: gcloud CLI configuré et authentifié
#            Permissions nécessaires: resourcemanager.projects.getIamPolicy
# Usage: ./audit-iam-permissions.sh [--json] [--project PROJECT_ID]
#
# Options:
#   --json              : Sortie en format JSON
#   --project PROJECT   : Auditer un seul projet spécifique
#   --role ROLE         : Filtrer par rôle (ex: roles/owner, roles/editor)
#   --member EMAIL      : Filtrer par membre (ex: user@example.com)
#
# Exemples:
#   ./audit-iam-permissions.sh
#   ./audit-iam-permissions.sh --project mon-projet
#   ./audit-iam-permissions.sh --role roles/owner
#   ./audit-iam-permissions.sh --member user@example.com
#####################################################################

set -euo pipefail

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Options par défaut
JSON_MODE=false
SINGLE_PROJECT=""
FILTER_ROLE=""
FILTER_MEMBER=""

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
        --role)
            FILTER_ROLE="$2"
            shift 2
            ;;
        --member)
            FILTER_MEMBER="$2"
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
        echo -e "${BLUE}  Audit IAM - Permissions GCP${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
    fi
}

# Fonction pour simplifier l'affichage du type de membre
simplify_member_type() {
    local member=$1
    if [[ "$member" == user:* ]]; then
        echo "user"
    elif [[ "$member" == serviceAccount:* ]]; then
        echo "SA"
    elif [[ "$member" == group:* ]]; then
        echo "group"
    elif [[ "$member" == domain:* ]]; then
        echo "domain"
    else
        echo "other"
    fi
}

# Fonction pour extraire l'email/nom du membre
extract_member_name() {
    local member=$1
    echo "$member" | cut -d':' -f2
}

# Fonction pour obtenir un nom de rôle court
short_role_name() {
    local role=$1
    # Retire "roles/" et "projects/*/roles/"
    role=$(echo "$role" | sed 's|^roles/||' | sed 's|^projects/.*/roles/||')
    echo "$role"
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
total_bindings=0
owner_count=0
editor_count=0
viewer_count=0
custom_count=0

if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "filters": {'
    echo "    \"project\": \"${SINGLE_PROJECT:-all}\","
    echo "    \"role\": \"${FILTER_ROLE:-all}\","
    echo "    \"member\": \"${FILTER_MEMBER:-all}\""
    echo "  },"
    echo '  "permissions": ['
    first_binding=true
else
    if [[ -n "$SINGLE_PROJECT" ]]; then
        echo -e "${GREEN}Audit du projet: ${CYAN}$SINGLE_PROJECT${NC}"
    else
        echo -e "${GREEN}Audit de tous les projets...${NC}"
    fi
    [[ -n "$FILTER_ROLE" ]] && echo -e "${YELLOW}Filtre rôle: $FILTER_ROLE${NC}"
    [[ -n "$FILTER_MEMBER" ]] && echo -e "${YELLOW}Filtre membre: $FILTER_MEMBER${NC}"
    echo ""
    printf "%-30s %-40s %-25s %-10s\n" \
        "PROJECT_ID" "MEMBER" "ROLE" "TYPE"
    printf "%-30s %-40s %-25s %-10s\n" \
        "----------" "------" "----" "----"
fi

# Détermine la liste des projets à auditer
if [[ -n "$SINGLE_PROJECT" ]]; then
    project_list="$SINGLE_PROJECT"
else
    project_list=$(gcloud projects list --format="value(projectId)")
fi

# Boucle sur les projets
while read -r project_id; do
    [[ -z "$project_id" ]] && continue

    # Récupère la policy IAM du projet
    iam_policy=$(gcloud projects get-iam-policy "$project_id" \
        --flatten="bindings[].members" \
        --format="table[no-heading](bindings.role,bindings.members)" 2>/dev/null || echo "")

    if [[ -n "$iam_policy" ]]; then
        while IFS=$'\t' read -r role member; do
            # Applique les filtres si définis
            if [[ -n "$FILTER_ROLE" && "$role" != "$FILTER_ROLE" ]]; then
                continue
            fi
            if [[ -n "$FILTER_MEMBER" && "$member" != *"$FILTER_MEMBER"* ]]; then
                continue
            fi

            ((total_bindings++))

            # Compte les types de rôles
            if [[ "$role" == "roles/owner" ]]; then
                ((owner_count++))
            elif [[ "$role" == "roles/editor" ]]; then
                ((editor_count++))
            elif [[ "$role" == "roles/viewer" ]]; then
                ((viewer_count++))
            else
                ((custom_count++))
            fi

            member_type=$(simplify_member_type "$member")
            member_name=$(extract_member_name "$member")
            role_short=$(short_role_name "$role")

            if [[ "$JSON_MODE" == true ]]; then
                [[ "$first_binding" == false ]] && echo ","
                first_binding=false
                cat <<EOF
    {
      "project_id": "$project_id",
      "member": "$member",
      "member_name": "$member_name",
      "member_type": "$member_type",
      "role": "$role",
      "role_short": "$role_short"
    }
EOF
            else
                # Couleur selon le type de rôle
                if [[ "$role" == "roles/owner" ]]; then
                    role_colored="${RED}${role_short}${NC}"
                elif [[ "$role" == "roles/editor" ]]; then
                    role_colored="${YELLOW}${role_short}${NC}"
                elif [[ "$role" == "roles/viewer" ]]; then
                    role_colored="${GREEN}${role_short}${NC}"
                else
                    role_colored="${CYAN}${role_short}${NC}"
                fi

                # Couleur selon le type de membre
                if [[ "$member_type" == "SA" ]]; then
                    type_colored="${MAGENTA}${member_type}${NC}"
                else
                    type_colored="$member_type"
                fi

                printf "%-30s %-40s %-34s %-19s\n" \
                    "${project_id:0:28}" \
                    "${member_name:0:38}" \
                    "$role_colored" \
                    "$type_colored"
            fi
        done <<< "$iam_policy"
    fi
done <<< "$project_list"

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "  ],"
    echo '  "summary": {'
    echo "    \"total_bindings\": $total_bindings,"
    echo "    \"owner_count\": $owner_count,"
    echo "    \"editor_count\": $editor_count,"
    echo "    \"viewer_count\": $viewer_count,"
    echo "    \"custom_roles_count\": $custom_count"
    echo "  }"
    echo "}"
else
    echo ""
    echo -e "${CYAN}========== Résumé ==========${NC}"
    echo -e "Total permissions:     ${BLUE}$total_bindings${NC}"
    echo -e "Owners (rouge):        ${RED}$owner_count${NC}"
    echo -e "Editors (jaune):       ${YELLOW}$editor_count${NC}"
    echo -e "Viewers (vert):        ${GREEN}$viewer_count${NC}"
    echo -e "Rôles custom (cyan):   ${CYAN}$custom_count${NC}"
    echo ""
    echo -e "${YELLOW}Recommandations de sécurité:${NC}"
    echo -e "  - Minimisez le nombre de owners"
    echo -e "  - Utilisez des groupes plutôt que des utilisateurs individuels"
    echo -e "  - Préférez des rôles spécifiques aux rôles larges (editor/viewer)"
    echo -e "  - Auditez régulièrement les service accounts (SA)"
fi
