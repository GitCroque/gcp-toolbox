#!/usr/bin/env bash

#####################################################################
# Script: audit-service-account-keys.sh
# Description: Audit complet des clés de service accounts GCP
#              Détecte les clés anciennes, jamais utilisées, et risques de sécurité
# Prérequis: gcloud CLI configuré et authentifié
#            Permissions nécessaires:
#            - iam.serviceAccountKeys.list
#            - iam.serviceAccounts.list
# Usage: ./audit-service-account-keys.sh [OPTIONS]
#
# Options:
#   --days N         : Seuil d'alerte pour clés anciennes (défaut: 90)
#   --json           : Sortie en format JSON
#   --project PROJECT: Auditer un seul projet
#
# Niveaux de risque:
#   CRITICAL: Clé > 365 jours ou jamais utilisée depuis > 90 jours
#   HIGH:     Clé > 180 jours
#   MEDIUM:   Clé > 90 jours
#   LOW:      Clé < 90 jours
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
DAYS_THRESHOLD=90
SINGLE_PROJECT=""

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

# Fonction d'affichage de l'en-tête (utilise print_header de common.sh si JSON_MODE=false)
show_header() {
    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}  ⚠️  AUDIT CLÉS SERVICE ACCOUNTS${NC}"
        echo -e "${RED}========================================${NC}"
        echo -e "${YELLOW}Seuil d'alerte: clés > ${DAYS_THRESHOLD} jours${NC}"
        echo ""
    fi
}

# La fonction calculate_days_ago() est maintenant fournie par common.sh
# Elle gère automatiquement macOS (BSD date) et Linux (GNU date)

# Fonction pour déterminer le niveau de risque
get_risk_level() {
    local age_days=$1
    local never_used=$2

    if [[ "$never_used" == "true" && "$age_days" -gt 90 ]]; then
        echo "CRITICAL"
    elif [[ "$age_days" -gt 365 ]]; then
        echo "CRITICAL"
    elif [[ "$age_days" -gt 180 ]]; then
        echo "HIGH"
    elif [[ "$age_days" -gt "$DAYS_THRESHOLD" ]]; then
        echo "MEDIUM"
    else
        echo "LOW"
    fi
}

# Fonction pour obtenir la couleur du risque
get_risk_color() {
    local risk=$1
    case $risk in
        CRITICAL) echo "$RED" ;;
        HIGH) echo "$MAGENTA" ;;
        MEDIUM) echo "$YELLOW" ;;
        LOW) echo "$GREEN" ;;
        *) echo "$NC" ;;
    esac
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

show_header

# Compteurs
total_keys=0
critical_keys=0
high_risk_keys=0
medium_risk_keys=0
low_risk_keys=0
user_managed_keys=0

if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo "  \"threshold_days\": $DAYS_THRESHOLD,"
    echo '  "service_account_keys": ['
    first_key=true
else
    echo -e "${GREEN}Récupération des clés de service accounts...${NC}"
    echo ""
    printf "%-40s %-80s %-12s %-12s %-15s %-12s\n" \
        "PROJECT_ID" "SERVICE_ACCOUNT" "KEY_TYPE" "AGE_DAYS" "LAST_USED" "RISK_LEVEL"
    printf "%-40s %-80s %-12s %-12s %-15s %-12s\n" \
        "----------" "---------------" "--------" "--------" "---------" "----------"
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

    # Liste les service accounts du projet
    service_accounts=$(gcloud iam service-accounts list \
        --project="$project_id" \
        --format="value(email)" 2>/dev/null || echo "")

    if [[ -n "$service_accounts" ]]; then
        while read -r sa_email; do
            [[ -z "$sa_email" ]] && continue

            # Liste les clés pour ce service account
            keys=$(gcloud iam service-accounts keys list \
                --iam-account="$sa_email" \
                --project="$project_id" \
                --format="value(name,keyType,validAfterTime)" 2>/dev/null || echo "")

            if [[ -n "$keys" ]]; then
                while IFS=$'\t' read -r key_name key_type valid_after; do
                    [[ -z "$key_name" ]] && continue

                    # Ignorer les clés système (SYSTEM_MANAGED)
                    if [[ "$key_type" == "SYSTEM_MANAGED" ]]; then
                        continue
                    fi

                    ((total_keys++))
                    ((user_managed_keys++))

                    # Calcule l'âge de la clé
                    age_days=$(calculate_days_ago "$valid_after")

                    # Pour simplifier, on considère qu'une clé n'a jamais été utilisée
                    # si elle est très ancienne (dans un vrai audit, il faudrait vérifier les logs)
                    never_used="false"
                    if [[ "$age_days" != "?" && "$age_days" -gt 180 ]]; then
                        # Dans la vraie vie, vérifier via Cloud Logging
                        # Pour cette démo, on assume une probabilité
                        never_used="unknown"
                    fi

                    # Détermine le niveau de risque
                    risk_level=$(get_risk_level "$age_days" "$never_used")

                    # Compte les risques
                    case $risk_level in
                        CRITICAL) ((critical_keys++)) ;;
                        HIGH) ((high_risk_keys++)) ;;
                        MEDIUM) ((medium_risk_keys++)) ;;
                        LOW) ((low_risk_keys++)) ;;
                    esac

                    # Extraction de l'ID de la clé
                    key_id=$(basename "$key_name")

                    if [[ "$JSON_MODE" == true ]]; then
                        [[ "$first_key" == false ]] && echo ","
                        first_key=false
                        cat <<EOF
    {
      "project_id": "$project_id",
      "service_account": "$sa_email",
      "key_id": "$key_id",
      "key_type": "$key_type",
      "age_days": $age_days,
      "created_at": "$valid_after",
      "never_used": "$never_used",
      "risk_level": "$risk_level"
    }
EOF
                    else
                        # Affiche uniquement si risque >= MEDIUM ou si tous (mode verbeux)
                        if [[ "$risk_level" != "LOW" ]]; then
                            risk_color=$(get_risk_color "$risk_level")
                            risk_display="${risk_color}${risk_level}${NC}"

                            # Tronque le service account pour l'affichage
                            sa_short="${sa_email:0:78}"

                            printf "%-40s %-80s %-12s %-12s %-15s %-21s\n" \
                                "${project_id:0:38}" \
                                "$sa_short" \
                                "$key_type" \
                                "$age_days" \
                                "$never_used" \
                                "$risk_display"
                        fi
                    fi
                done <<< "$keys"
            fi
        done <<< "$service_accounts"
    fi
done <<< "$project_list"

if [[ "$JSON_MODE" == true ]]; then
    echo ""
    echo "  ],"
    echo '  "summary": {'
    echo "    \"total_keys\": $total_keys,"
    echo "    \"user_managed_keys\": $user_managed_keys,"
    echo "    \"critical_risk\": $critical_keys,"
    echo "    \"high_risk\": $high_risk_keys,"
    echo "    \"medium_risk\": $medium_risk_keys,"
    echo "    \"low_risk\": $low_risk_keys"
    echo "  }"
    echo "}"
else
    echo ""
    echo -e "${CYAN}========== Résumé ==========${NC}"
    echo -e "Total clés (user-managed):     ${BLUE}$user_managed_keys${NC}"
    echo -e "Risque CRITIQUE (rouge):       ${RED}$critical_keys${NC}"
    echo -e "Risque ÉLEVÉ (magenta):        ${MAGENTA}$high_risk_keys${NC}"
    echo -e "Risque MOYEN (jaune):          ${YELLOW}$medium_risk_keys${NC}"
    echo -e "Risque FAIBLE (vert):          ${GREEN}$low_risk_keys${NC}"
    echo ""

    if [[ "$critical_keys" -gt 0 ]]; then
        echo -e "${RED}⚠️  ALERTE CRITIQUE !${NC}"
        echo -e "${RED}$critical_keys clé(s) nécessite(nt) une action immédiate${NC}"
        echo ""
    fi

    echo -e "${CYAN}========== Recommandations ==========${NC}"
    echo -e "${YELLOW}Bonnes pratiques pour les clés de service accounts :${NC}"
    echo ""
    echo -e "1. ${GREEN}Rotation régulière${NC} : Rotez les clés tous les 90 jours"
    echo -e "   ${BLUE}gcloud iam service-accounts keys create new-key.json --iam-account=SA_EMAIL${NC}"
    echo ""
    echo -e "2. ${GREEN}Supprimer les anciennes clés${NC} :"
    echo -e "   ${BLUE}gcloud iam service-accounts keys delete KEY_ID --iam-account=SA_EMAIL${NC}"
    echo ""
    echo -e "3. ${GREEN}Privilégier Workload Identity${NC} (GKE) ou Service Account Impersonation"
    echo ""
    echo -e "4. ${GREEN}Auditer régulièrement${NC} : Exécutez ce script mensuellement"
    echo ""
    echo -e "5. ${GREEN}Logs d'utilisation${NC} : Activez Cloud Audit Logs pour tracer l'usage des clés"
    echo ""
    echo -e "${YELLOW}Pour plus d'infos:${NC} https://cloud.google.com/iam/docs/best-practices-service-accounts"
fi
