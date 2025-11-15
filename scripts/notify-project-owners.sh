#!/bin/bash
set -euo pipefail

#####################################################################
# Script: notify-project-owners.sh
# Description: Génère un rapport pour contacter les propriétaires de projets
#              afin de vérifier si leurs projets sont encore nécessaires
#
# Prérequis:
#   - gcloud CLI configuré et authentifié
#   - Permissions: resourcemanager.projects.get, iam.serviceAccounts.list
#
# Usage: ./notify-project-owners.sh [OPTIONS]
#
# Options:
#   --json                : Sortie JSON
#   --email-template      : Génère template d'email
#   --inactive-days DAYS  : Seuil d'inactivité (défaut: 90 jours)
#   --output-csv FILE     : Export CSV pour mailing
#####################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# Options
JSON_MODE=false
EMAIL_TEMPLATE=false
INACTIVE_DAYS=90
OUTPUT_CSV=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --email-template) EMAIL_TEMPLATE=true; shift ;;
        --inactive-days) INACTIVE_DAYS="$2"; shift 2 ;;
        --output-csv) OUTPUT_CSV="$2"; shift 2 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2; exit 1
fi

[[ "$JSON_MODE" == false ]] && {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  📧 Notification Propriétaires Projets${NC}"
    echo -e "${CYAN}========================================${NC}\n"
    echo -e "${YELLOW}Seuil d'inactivité: $INACTIVE_DAYS jours${NC}\n"
}

# Fonction pour obtenir la dernière activité d'un projet
get_last_activity() {
    local project_id=$1
    local cutoff_date=$(date -u -d "$INACTIVE_DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-${INACTIVE_DAYS}d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "2024-08-15T00:00:00Z")

    # Vérifie logs d'activité récente (simplifié - en prod utiliser Cloud Logging)
    local has_recent_activity="unknown"

    # Vérifie si des ressources actives existent
    local vm_count=$(gcloud compute instances list --project="$project_id" --format="value(name)" 2>/dev/null | wc -l || echo 0)
    local sql_count=$(gcloud sql instances list --project="$project_id" --format="value(name)" 2>/dev/null | wc -l || echo 0)
    local gke_count=$(gcloud container clusters list --project="$project_id" --format="value(name)" 2>/dev/null | wc -l || echo 0)

    local total_resources=$((vm_count + sql_count + gke_count))

    if [[ $total_resources -gt 0 ]]; then
        has_recent_activity="active"
    else
        has_recent_activity="inactive"
    fi

    echo "$has_recent_activity"
}

total_projects=0
active_projects=0
inactive_projects=0
unknown_projects=0

if [[ "$JSON_MODE" == true ]]; then
    echo '{'
    echo '  "generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "inactive_threshold_days": '$INACTIVE_DAYS','
    echo '  "projects": ['
    first=true
elif [[ -n "$OUTPUT_CSV" ]]; then
    echo "project_id,project_name,owner_email,status,vm_count,sql_count,gke_count,recommendation" > "$OUTPUT_CSV"
else
    printf "%-30s %-40s %-30s %-15s %-15s\n" "PROJECT_ID" "PROJECT_NAME" "OWNER_EMAIL" "STATUS" "ACTION"
    printf "%-30s %-40s %-30s %-15s %-15s\n" "----------" "------------" "-----------" "------" "------"
fi

# Liste tous les projets
projects=$(gcloud projects list --format="value(projectId,name)" 2>/dev/null)

while IFS=$'\t' read -r project_id project_name; do
    [[ -z "$project_id" ]] && continue
    ((total_projects++))

    # Récupère les propriétaires (owners)
    owners=$(gcloud projects get-iam-policy "$project_id" \
        --flatten="bindings[].members" \
        --filter="bindings.role:roles/owner" \
        --format="value(bindings.members)" 2>/dev/null | grep -E "^user:" | sed 's/^user://' | head -1 || echo "unknown@example.com")

    [[ -z "$owners" ]] && owners="unknown@example.com"

    # Vérifie activité
    activity_status=$(get_last_activity "$project_id")

    # Compte ressources
    vm_count=$(gcloud compute instances list --project="$project_id" --format="value(name)" 2>/dev/null | wc -l || echo 0)
    sql_count=$(gcloud sql instances list --project="$project_id" --format="value(name)" 2>/dev/null | wc -l || echo 0)
    gke_count=$(gcloud container clusters list --project="$project_id" --format="value(name)" 2>/dev/null | wc -l || echo 0)

    recommendation="KEEP"
    if [[ "$activity_status" == "inactive" ]]; then
        recommendation="REVIEW"
        ((inactive_projects++))
    elif [[ "$activity_status" == "active" ]]; then
        recommendation="KEEP"
        ((active_projects++))
    else
        recommendation="UNKNOWN"
        ((unknown_projects++))
    fi

    if [[ "$JSON_MODE" == true ]]; then
        [[ "$first" == false ]] && echo ","
        first=false
        cat <<EOF
    {
      "project_id": "$project_id",
      "project_name": "$project_name",
      "owner_email": "$owners",
      "status": "$activity_status",
      "vm_count": $vm_count,
      "sql_count": $sql_count,
      "gke_count": $gke_count,
      "recommendation": "$recommendation"
    }
EOF
    elif [[ -n "$OUTPUT_CSV" ]]; then
        echo "$project_id,$project_name,$owners,$activity_status,$vm_count,$sql_count,$gke_count,$recommendation" >> "$OUTPUT_CSV"
    else
        status_display="$activity_status"
        rec_display="$recommendation"

        [[ "$activity_status" == "active" ]] && status_display="${GREEN}active${NC}"
        [[ "$activity_status" == "inactive" ]] && status_display="${RED}inactive${NC}"
        [[ "$activity_status" == "unknown" ]] && status_display="${YELLOW}unknown${NC}"

        [[ "$recommendation" == "REVIEW" ]] && rec_display="${YELLOW}REVIEW${NC}"
        [[ "$recommendation" == "KEEP" ]] && rec_display="${GREEN}KEEP${NC}"

        printf "%-30s %-40s %-30s %-24s %-24s\n" \
            "${project_id:0:28}" \
            "${project_name:0:38}" \
            "${owners:0:28}" \
            "$status_display" \
            "$rec_display"
    fi
done <<< "$projects"

if [[ "$JSON_MODE" == true ]]; then
    echo ''
    echo '  ],'
    echo '  "summary": {'
    echo "    \"total_projects\": $total_projects,"
    echo "    \"active_projects\": $active_projects,"
    echo "    \"inactive_projects\": $inactive_projects,"
    echo "    \"unknown_projects\": $unknown_projects"
    echo '  }'
    echo '}'
elif [[ -z "$OUTPUT_CSV" ]]; then
    echo ""
    echo -e "${CYAN}========== Résumé ==========${NC}"
    echo -e "Total projets:             ${BLUE}$total_projects${NC}"
    echo -e "Projets actifs:            ${GREEN}$active_projects${NC}"
    echo -e "Projets inactifs:          ${RED}$inactive_projects${NC}"
    echo -e "Projets statut inconnu:    ${YELLOW}$unknown_projects${NC}"

    [[ $inactive_projects -gt 0 ]] && {
        echo ""
        echo -e "${YELLOW}⚠️  $inactive_projects projet(s) à REVIEW avec les propriétaires${NC}"
    }
fi

# Génère template email si demandé
if [[ "$EMAIL_TEMPLATE" == true ]]; then
    template_file="email-template-project-review.txt"
    cat > "$template_file" <<'EOF'
Objet: [ACTION REQUISE] Vérification annuelle de votre projet GCP: {{PROJECT_NAME}}

Bonjour {{OWNER_NAME}},

Dans le cadre de notre audit annuel de la plateforme Google Cloud Platform, nous revoyons tous les projets pour optimiser les coûts et la sécurité.

📊 Informations sur votre projet:
- Nom du projet: {{PROJECT_NAME}}
- ID du projet: {{PROJECT_ID}}
- Vous êtes identifié(e) comme propriétaire
- Statut actuel: {{STATUS}}
- Ressources actives:
  * VMs: {{VM_COUNT}}
  * Bases de données: {{SQL_COUNT}}
  * Clusters GKE: {{GKE_COUNT}}

❓ Action requise:
Merci de répondre aux questions suivantes avant le {{DEADLINE_DATE}}:

1. Ce projet est-il toujours nécessaire à l'organisation ? (Oui/Non)
2. Si oui, quelle est son utilisation principale ?
   [ ] Production
   [ ] Staging
   [ ] Développement
   [ ] POC/Expérimentation
   [ ] Archivé (peut être supprimé)

3. Pouvez-vous confirmer que toutes les ressources sont encore utilisées ?
4. Acceptez-vous d'être contacté pour une optimisation des coûts si opportunités détectées ?

⚠️  Important:
Les projets marqués "inactifs" sans réponse après {{GRACE_PERIOD}} jours seront:
- Mis en "shutdown" temporaire (ressources arrêtées)
- Supprimés après {{DELETION_DAYS}} jours supplémentaires

💬 Pour répondre:
Merci de répondre directement à cet email ou via notre formulaire: {{FORM_URL}}

Cordialement,
L'équipe Platform Engineering

---
Cet email est généré automatiquement par le script notify-project-owners.sh
Date: {{GENERATION_DATE}}
EOF
    echo ""
    echo -e "${GREEN}✅ Template email généré: $template_file${NC}"
    echo ""
    echo -e "${CYAN}Variables à remplacer:${NC}"
    echo "  {{PROJECT_NAME}}, {{PROJECT_ID}}, {{OWNER_NAME}}, {{STATUS}}"
    echo "  {{VM_COUNT}}, {{SQL_COUNT}}, {{GKE_COUNT}}"
    echo "  {{DEADLINE_DATE}}, {{GRACE_PERIOD}}, {{DELETION_DAYS}}, {{FORM_URL}}"
fi

[[ -n "$OUTPUT_CSV" ]] && {
    echo ""
    echo -e "${GREEN}✅ Export CSV généré: $OUTPUT_CSV${NC}"
    echo -e "${CYAN}Utilisable pour mailing avec merge fields${NC}"
}

exit 0
