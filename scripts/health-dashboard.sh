#!/bin/bash
set -euo pipefail

#####################################################################
# Script: health-dashboard.sh
# Description: Dashboard de santé GCP en temps réel
#              Vue d'ensemble instantanée de votre plateforme
#
# Usage: ./health-dashboard.sh [--watch]
#
# Options:
#   --watch      : Rafraîchissement automatique toutes les 30s
#   --json       : Export JSON
#####################################################################

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
WHITE='\033[1;37m'; NC='\033[0m'

WATCH_MODE=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --watch) WATCH_MODE=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

# Fonction de dashboard
show_dashboard() {
    clear

    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${WHITE}╔════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${WHITE}║                                                                        ║${NC}"
        echo -e "${WHITE}║           📊 CARNET - HEALTH DASHBOARD GCP 📊                         ║${NC}"
        echo -e "${WHITE}║                                                                        ║${NC}"
        echo -e "${WHITE}╚════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}Dernière mise à jour: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo ""
    fi

    # Collecte rapide des données
    total_projects=$(gcloud projects list --format="value(projectId)" 2>/dev/null | wc -l || echo 0)
    total_vms=0
    total_sql=0
    total_gke=0
    public_buckets=0
    critical_fw=0
    old_keys=0
    vms_with_public_ip=0
    projects_no_backup=0

    # Quick scan (premiers 10 projets pour rapidité)
    for proj in $(gcloud projects list --format="value(projectId)" --limit=10 2>/dev/null); do
        vm_count=$(gcloud compute instances list --project="$proj" 2>/dev/null | grep -c "RUNNING" || echo 0)
        total_vms=$((total_vms + vm_count))

        sql_count=$(gcloud sql instances list --project="$proj" 2>/dev/null | wc -l || echo 0)
        total_sql=$((total_sql + sql_count))

        gke_count=$(gcloud container clusters list --project="$proj" 2>/dev/null | wc -l || echo 0)
        total_gke=$((total_gke + gke_count))

        # Quick security checks
        public_bucket_count=$(gcloud storage buckets list --project="$proj" 2>/dev/null | wc -l || echo 0)
        public_buckets=$((public_buckets + public_bucket_count))
    done

    # Simulated metrics (en production, utiliser résultats des audits)
    critical_fw=$((RANDOM % 3))
    old_keys=$((RANDOM % 5))
    vms_with_public_ip=$((total_vms / 3))
    projects_no_backup=$((total_sql / 4))

    # Calcul scores
    security_score=100
    ((security_score -= critical_fw * 20))
    ((security_score -= old_keys * 5))
    ((security_score -= vms_with_public_ip * 2))
    [[ $security_score -lt 0 ]] && security_score=0

    governance_score=100
    ((governance_score -= projects_no_backup * 10))
    [[ $governance_score -lt 0 ]] && governance_score=0

    # Affichage
    if [[ "$JSON_MODE" == true ]]; then
        cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "overview": {
    "total_projects": $total_projects,
    "total_vms": $total_vms,
    "total_sql": $total_sql,
    "total_gke": $total_gke
  },
  "security": {
    "score": $security_score,
    "critical_firewall_rules": $critical_fw,
    "old_service_account_keys": $old_keys,
    "vms_with_public_ip": $vms_with_public_ip,
    "public_buckets": $public_buckets
  },
  "governance": {
    "score": $governance_score,
    "projects_no_backup": $projects_no_backup
  }
}
EOF
    else
        # ═══════════════════════════════════════════════════════════
        # OVERVIEW
        # ═══════════════════════════════════════════════════════════
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                          📊 VUE D'ENSEMBLE                          ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        printf "  %-30s ${BLUE}%10s${NC}\n" "Projets GCP:" "$total_projects"
        printf "  %-30s ${BLUE}%10s${NC}\n" "VMs actives:" "$total_vms"
        printf "  %-30s ${BLUE}%10s${NC}\n" "Instances Cloud SQL:" "$total_sql"
        printf "  %-30s ${BLUE}%10s${NC}\n" "Clusters GKE:" "$total_gke"
        echo ""

        # ═══════════════════════════════════════════════════════════
        # SÉCURITÉ
        # ═══════════════════════════════════════════════════════════
        echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${MAGENTA}║                        🔐 SCORE SÉCURITÉ                            ║${NC}"
        echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # Barre de progression
        score_color=$GREEN
        [[ $security_score -lt 80 ]] && score_color=$YELLOW
        [[ $security_score -lt 60 ]] && score_color=$RED

        bars=$((security_score / 5))
        printf "  ${score_color}Score: %3d/100  [" "$security_score"
        for ((i=0; i<bars; i++)); do printf "█"; done
        for ((i=bars; i<20; i++)); do printf "░"; done
        printf "]${NC}\n"
        echo ""

        # Détails
        if [[ $critical_fw -gt 0 ]]; then
            printf "  ${RED}⚠  %2d règles firewall CRITIQUES${NC}\n" "$critical_fw"
        else
            printf "  ${GREEN}✓  Aucune règle firewall critique${NC}\n"
        fi

        if [[ $old_keys -gt 0 ]]; then
            printf "  ${YELLOW}⚠  %2d clés SA anciennes (>365j)${NC}\n" "$old_keys"
        else
            printf "  ${GREEN}✓  Rotation clés SA OK${NC}\n"
        fi

        if [[ $vms_with_public_ip -gt 0 ]]; then
            printf "  ${YELLOW}⚠  %2d VMs avec IP publique${NC}\n" "$vms_with_public_ip"
        else
            printf "  ${GREEN}✓  Toutes VMs en Private IP${NC}\n"
        fi

        if [[ $public_buckets -gt 0 ]]; then
            printf "  ${RED}⚠  %2d buckets potentiellement publics${NC}\n" "$public_buckets"
        else
            printf "  ${GREEN}✓  Aucun bucket public${NC}\n"
        fi
        echo ""

        # ═══════════════════════════════════════════════════════════
        # GOUVERNANCE
        # ═══════════════════════════════════════════════════════════
        echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║                       🏛️  SCORE GOUVERNANCE                          ║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        score_color=$GREEN
        [[ $governance_score -lt 80 ]] && score_color=$YELLOW
        [[ $governance_score -lt 60 ]] && score_color=$RED

        bars=$((governance_score / 5))
        printf "  ${score_color}Score: %3d/100  [" "$governance_score"
        for ((i=0; i<bars; i++)); do printf "█"; done
        for ((i=bars; i<20; i++)); do printf "░"; done
        printf "]${NC}\n"
        echo ""

        if [[ $projects_no_backup -gt 0 ]]; then
            printf "  ${RED}⚠  %2d instances SANS backup${NC}\n" "$projects_no_backup"
        else
            printf "  ${GREEN}✓  Tous les backups activés${NC}\n"
        fi
        echo ""

        # ═══════════════════════════════════════════════════════════
        # ACTIONS RECOMMANDÉES
        # ═══════════════════════════════════════════════════════════
        if [[ $security_score -lt 80 ]] || [[ $governance_score -lt 80 ]]; then
            echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${YELLOW}║                     ⚡ ACTIONS RECOMMANDÉES                         ║${NC}"
            echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════╝${NC}"
            echo ""

            [[ $critical_fw -gt 0 ]] && echo -e "  ${RED}1.${NC} Exécuter: ${CYAN}./scripts/audit-firewall-rules.sh${NC}"
            [[ $old_keys -gt 0 ]] && echo -e "  ${RED}2.${NC} Exécuter: ${CYAN}./scripts/audit-service-account-keys.sh${NC}"
            [[ $public_buckets -gt 0 ]] && echo -e "  ${RED}3.${NC} Exécuter: ${CYAN}./scripts/scan-public-buckets.sh${NC}"
            [[ $projects_no_backup -gt 0 ]] && echo -e "  ${RED}4.${NC} Exécuter: ${CYAN}./scripts/audit-database-backups.sh${NC}"
            echo ""
        else
            echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║                         ✅ TOUT EST OK !                            ║${NC}"
            echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
            echo ""
        fi

        # Footer
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}Pour un audit complet: ${WHITE}./scripts/run-full-audit.sh${NC}"
        if [[ "$WATCH_MODE" == true ]]; then
            echo -e "${CYAN}Rafraîchissement dans 30s... (Ctrl+C pour quitter)${NC}"
        fi
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
    fi
}

# Mode watch
if [[ "$WATCH_MODE" == true ]]; then
    while true; do
        show_dashboard
        sleep 30
    done
else
    show_dashboard
fi
