#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# Script: run-full-audit.sh
# Description: Exécute TOUS les audits de sécurité et gouvernance
#              en une seule commande et génère un rapport complet
#
# Usage: ./run-full-audit.sh [OPTIONS]
#
# Options:
#   --output-dir DIR  : Répertoire de sortie (défaut: ./audit-reports)
#   --email EMAIL     : Envoyer rapport par email
#   --slack-webhook URL : Poster sur Slack
#   --critical-only   : Seulement alertes critiques
#####################################################################

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options locales
OUTPUT_DIR="./audit-reports"
EMAIL=""
SLACK_WEBHOOK=""
CRITICAL_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --email) EMAIL="$2"; shift 2 ;;
        --slack-webhook) SLACK_WEBHOOK="$2"; shift 2 ;;
        --critical-only) CRITICAL_ONLY=true; shift ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

mkdir -p "$OUTPUT_DIR"
DATE=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="$OUTPUT_DIR/audit-$DATE"
mkdir -p "$REPORT_DIR"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}║         🔍 GCP TOOLBOX - AUDIT COMPLET GCP 🔍             ║${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Démarrage audit complet...${NC}"
echo -e "${YELLOW}Répertoire de sortie: $REPORT_DIR${NC}"
echo ""

# Initialisation compteurs
total_critical=0
total_high=0
total_medium=0
total_low=0
failed_scripts=0

# Fonction pour exécuter un script et capturer résultat
run_audit() {
    local script_name=$1
    local description=$2
    local category=$3

    echo -e "\n${BLUE}▶ $description...${NC}"

    if [[ ! -f "$SCRIPT_DIR/$script_name" ]]; then
        echo -e "${RED}  ✗ Script non trouvé: $script_name${NC}"
        ((failed_scripts++))
        return 1
    fi

    local output_file="$REPORT_DIR/${script_name%.sh}.json"

    if "$SCRIPT_DIR/$script_name" --json > "$output_file" 2>&1; then
        echo -e "${GREEN}  ✓ Terminé${NC}"

        # Analyse résultats (si JSON valide)
        if command -v jq &> /dev/null && jq empty "$output_file" 2>/dev/null; then
            # Extraction métriques selon le script
            case $script_name in
                audit-firewall-rules.sh)
                    local critical=$(jq -r '.summary.critical // 0' "$output_file")
                    local high=$(jq -r '.summary.high // 0' "$output_file")
                    ((total_critical+=critical))
                    ((total_high+=high))
                    [[ $critical -gt 0 ]] && echo -e "${RED}    ⚠️  $critical règles CRITIQUES${NC}"
                    ;;
                scan-public-buckets.sh)
                    local public=$(jq -r '.summary.public_buckets // 0' "$output_file")
                    ((total_critical+=public))
                    [[ $public -gt 0 ]] && echo -e "${RED}    ⚠️  $public buckets PUBLICS${NC}"
                    ;;
                audit-service-account-keys.sh)
                    local critical_keys=$(jq -r '[.service_accounts[]?.keys[]? | select(.risk_level == "CRITICAL")] | length' "$output_file" 2>/dev/null || echo 0)
                    ((total_critical+=critical_keys))
                    [[ $critical_keys -gt 0 ]] && echo -e "${RED}    ⚠️  $critical_keys clés CRITIQUES${NC}"
                    ;;
            esac
        fi
        return 0
    else
        echo -e "${RED}  ✗ Échec${NC}"
        ((failed_scripts++))
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# 🔴 SÉCURITÉ CRITIQUE
# ═══════════════════════════════════════════════════════════
echo -e "\n${RED}═══════════════════════════════════════════════════════════${NC}"
echo -e "${RED}🔴 AUDITS SÉCURITÉ CRITIQUE${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"

run_audit "scan-public-buckets.sh" "Scan buckets publics" "security"
run_audit "audit-firewall-rules.sh" "Audit règles firewall" "security"
run_audit "audit-service-account-keys.sh" "Audit clés service accounts" "security"
run_audit "scan-exposed-services.sh" "Scan services exposés" "security"
run_audit "audit-database-backups.sh" "Vérification backups DB" "security"

# ═══════════════════════════════════════════════════════════
# 🏛️ GOUVERNANCE
# ═══════════════════════════════════════════════════════════
if [[ "$CRITICAL_ONLY" == false ]]; then
    echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}🏛️ AUDITS GOUVERNANCE${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════${NC}"

    run_audit "notify-project-owners.sh" "Analyse propriétaires projets" "governance"
    run_audit "audit-resource-labels.sh" "Audit labels ressources" "governance"
    run_audit "cleanup-old-projects.sh" "Identification projets inactifs" "governance"
fi

# ═══════════════════════════════════════════════════════════
# 💰 COÛTS
# ═══════════════════════════════════════════════════════════
if [[ "$CRITICAL_ONLY" == false ]]; then
    echo -e "\n${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}💰 AUDITS COÛTS${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"

    run_audit "compare-vm-rightsizing.sh" "Analyse rightsizing VMs" "costs"
    run_audit "find-unused-resources.sh" "Détection ressources inutilisées" "costs"
    run_audit "check-preemptible-candidates.sh" "Candidats Spot VMs" "costs"
fi

# ═══════════════════════════════════════════════════════════
# 📊 GÉNÉRATION RAPPORT
# ═══════════════════════════════════════════════════════════
echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}📊 GÉNÉRATION RAPPORT FINAL${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"

# Génère rapport Markdown
REPORT_FILE="$REPORT_DIR/AUDIT-REPORT.md"

cat > "$REPORT_FILE" <<EOF
# 🔍 Rapport d'Audit GCP - GCP Toolbox

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Généré par**: \`run-full-audit.sh\`

---

## 📊 Résumé Exécutif

| Catégorie | Nombre |
|-----------|--------|
| 🔴 **Problèmes CRITIQUES** | **$total_critical** |
| 🟣 **Problèmes HIGH** | $total_high |
| 🟡 **Problèmes MEDIUM** | $total_medium |
| 🟢 **Problèmes LOW** | $total_low |
| ❌ **Scripts échoués** | $failed_scripts |

EOF

if [[ $total_critical -gt 0 ]]; then
    cat >> "$REPORT_FILE" <<EOF

## 🚨 ACTIONS IMMÉDIATES REQUISES

**$total_critical problème(s) CRITIQUE(S) détecté(s) !**

### Détails :

EOF

    # Analyse chaque fichier JSON pour problèmes critiques
    if [[ -f "$REPORT_DIR/scan-public-buckets.json" ]]; then
        public_buckets=$(jq -r '.summary.public_buckets // 0' "$REPORT_DIR/scan-public-buckets.json")
        if [[ $public_buckets -gt 0 ]]; then
            cat >> "$REPORT_FILE" <<EOF
#### 🔓 Buckets Publics ($public_buckets)
- **Risque**: Data leak, violation RGPD
- **Action**: Exécuter \`scripts/scan-public-buckets.sh\` et corriger immédiatement
- **Détails**: Voir \`scan-public-buckets.json\`

EOF
        fi
    fi

    if [[ -f "$REPORT_DIR/audit-firewall-rules.json" ]]; then
        critical_fw=$(jq -r '.summary.critical // 0' "$REPORT_DIR/audit-firewall-rules.json")
        if [[ $critical_fw -gt 0 ]]; then
            cat >> "$REPORT_FILE" <<EOF
#### 🔥 Règles Firewall Dangereuses ($critical_fw)
- **Risque**: SSH/RDP exposé à Internet, attaques brute-force
- **Action**: Implémenter Cloud IAP ou VPN
- **Détails**: Voir \`audit-firewall-rules.json\`

EOF
        fi
    fi
fi

cat >> "$REPORT_FILE" <<EOF

---

## 📁 Fichiers Générés

EOF

for file in "$REPORT_DIR"/*.json; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        echo "- \`$filename\`" >> "$REPORT_FILE"
    fi
done

cat >> "$REPORT_FILE" <<EOF

---

## 🔗 Liens Utiles

- [Documentation complète](https://github.com/GitCroque/gcp-toolbox/wiki/Home)
- [Quick Fix Guide](https://github.com/GitCroque/gcp-toolbox/wiki/Quick-Start)
- [Workflows](https://github.com/GitCroque/gcp-toolbox/wiki/Workflows)

---

**Prochaine étape**: Consulter les fichiers JSON détaillés et appliquer les remédiation recommandées.
EOF

echo -e "${GREEN}✓ Rapport généré: $REPORT_FILE${NC}"

# ═══════════════════════════════════════════════════════════
# 📧 NOTIFICATIONS
# ═══════════════════════════════════════════════════════════
if [[ -n "$EMAIL" ]]; then
    echo -e "\n${BLUE}📧 Envoi email à $EMAIL...${NC}"
    if command -v mail &> /dev/null; then
        mail -s "GCP Audit Report - $total_critical CRITIQUES" "$EMAIL" < "$REPORT_FILE"
        echo -e "${GREEN}✓ Email envoyé${NC}"
    else
        echo -e "${YELLOW}⚠️  Commande 'mail' non disponible${NC}"
    fi
fi

if [[ -n "$SLACK_WEBHOOK" ]]; then
    echo -e "\n${BLUE}💬 Notification Slack...${NC}"

    status_emoji="✅"
    [[ $total_critical -gt 0 ]] && status_emoji="🚨"

    curl -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"$status_emoji *GCP Audit Complet Terminé*\n\n• Problèmes CRITIQUES: *$total_critical*\n• Problèmes HIGH: $total_high\n• Rapport: \`$REPORT_FILE\`\"}" \
        2>/dev/null && echo -e "${GREEN}✓ Slack notifié${NC}" || echo -e "${YELLOW}⚠️  Échec notification Slack${NC}"
fi

# ═══════════════════════════════════════════════════════════
# 📊 RÉSUMÉ FINAL
# ═══════════════════════════════════════════════════════════
echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    AUDIT TERMINÉ                           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📊 Résumé:${NC}"
echo -e "  🔴 Problèmes CRITIQUES:  ${RED}$total_critical${NC}"
echo -e "  🟣 Problèmes HIGH:       ${MAGENTA}$total_high${NC}"
echo -e "  🟡 Problèmes MEDIUM:     ${YELLOW}$total_medium${NC}"
echo -e "  ❌ Scripts échoués:      ${RED}$failed_scripts${NC}"
echo ""
echo -e "${GREEN}📁 Rapport complet: $REPORT_FILE${NC}"
echo -e "${GREEN}📂 Détails JSON:    $REPORT_DIR/\*.json${NC}"
echo ""

if [[ $total_critical -gt 0 ]]; then
    echo -e "${RED}⚠️  ACTION IMMÉDIATE REQUISE: $total_critical problème(s) CRITIQUE(S) !${NC}"
    echo -e "${RED}   Consultez le rapport pour remédiation.${NC}"
    exit 1
elif [[ $total_high -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  $total_high problème(s) HIGH à traiter sous 24h.${NC}"
    exit 0
else
    echo -e "${GREEN}✅ Aucun problème critique ou high détecté.${NC}"
    exit 0
fi
