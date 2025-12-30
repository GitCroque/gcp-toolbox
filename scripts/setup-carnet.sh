#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# Script: setup-carnet.sh
# Description: Vérifie les prérequis et configure GCP Toolbox
#              pour la première utilisation
#
# Usage: ./setup-carnet.sh
#####################################################################

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}║         🚀 GCP TOOLBOX - SETUP & VÉRIFICATION 🚀          ║${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

errors=0
warnings=0

# ═══════════════════════════════════════════════════════════
# Vérification gcloud CLI
# ═══════════════════════════════════════════════════════════
echo -e "${BLUE}▶ Vérification gcloud CLI...${NC}"

if command -v gcloud &> /dev/null; then
    version=$(gcloud version --format="value(core)" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}  ✓ gcloud CLI installé (version: $version)${NC}"

    # Vérification authentification
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1)
        echo -e "${GREEN}  ✓ Authentifié en tant que: $account${NC}"
    else
        echo -e "${RED}  ✗ Non authentifié${NC}"
        echo -e "${YELLOW}    → Exécutez: gcloud auth login${NC}"
        ((errors++))
    fi

    # Vérification projet par défaut
    default_project=$(gcloud config get-value project 2>/dev/null || echo "")
    if [[ -n "$default_project" ]]; then
        echo -e "${GREEN}  ✓ Projet par défaut: $default_project${NC}"
    else
        echo -e "${YELLOW}  ⚠ Aucun projet par défaut configuré${NC}"
        echo -e "${YELLOW}    → Exécutez: gcloud config set project YOUR_PROJECT_ID${NC}"
        ((warnings++))
    fi
else
    echo -e "${RED}  ✗ gcloud CLI non installé${NC}"
    echo -e "${YELLOW}    → Installation: https://cloud.google.com/sdk/docs/install${NC}"
    ((errors++))
fi

# ═══════════════════════════════════════════════════════════
# Vérification outils optionnels
# ═══════════════════════════════════════════════════════════
echo -e "\n${BLUE}▶ Vérification outils optionnels...${NC}"

# jq
if command -v jq &> /dev/null; then
    echo -e "${GREEN}  ✓ jq installé (analyse JSON)${NC}"
else
    echo -e "${YELLOW}  ⚠ jq non installé (recommandé pour analyse JSON)${NC}"
    echo -e "${YELLOW}    → Installation: sudo apt install jq (Ubuntu) ou brew install jq (Mac)${NC}"
    ((warnings++))
fi

# curl
if command -v curl &> /dev/null; then
    echo -e "${GREEN}  ✓ curl installé${NC}"
else
    echo -e "${YELLOW}  ⚠ curl non installé (requis pour webhooks)${NC}"
    ((warnings++))
fi

# mail (optionnel)
if command -v mail &> /dev/null; then
    echo -e "${GREEN}  ✓ mail installé (notifications email)${NC}"
else
    echo -e "${YELLOW}  ⚠ mail non installé (optionnel, pour notifications email)${NC}"
fi

# ═══════════════════════════════════════════════════════════
# Vérification permissions GCP
# ═══════════════════════════════════════════════════════════
echo -e "\n${BLUE}▶ Vérification permissions GCP...${NC}"

if command -v gcloud &> /dev/null && gcloud auth list --filter=status:ACTIVE &> /dev/null; then
    # Test lecture projets
    if gcloud projects list --limit=1 &>/dev/null; then
        echo -e "${GREEN}  ✓ Permission: projects.list${NC}"
    else
        echo -e "${RED}  ✗ Permission manquante: projects.list${NC}"
        ((errors++))
    fi

    # Test lecture VMs (si projet configuré)
    if [[ -n "$default_project" ]]; then
        if gcloud compute instances list --project="$default_project" --limit=1 &>/dev/null 2>&1; then
            echo -e "${GREEN}  ✓ Permission: compute.instances.list${NC}"
        else
            echo -e "${YELLOW}  ⚠ Permission manquante: compute.instances.list${NC}"
            echo -e "${YELLOW}    → Rôle minimum requis: roles/viewer${NC}"
            ((warnings++))
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════
# Vérification structure repository
# ═══════════════════════════════════════════════════════════
echo -e "\n${BLUE}▶ Vérification structure repository...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

required_dirs=("scripts" "docs")
for dir in "${required_dirs[@]}"; do
    if [[ -d "$REPO_ROOT/$dir" ]]; then
        echo -e "${GREEN}  ✓ Répertoire $dir/ existe${NC}"
    else
        echo -e "${RED}  ✗ Répertoire $dir/ manquant${NC}"
        ((errors++))
    fi
done

# Compte scripts
script_count=$(find "$SCRIPT_DIR" -name "*.sh" -type f | wc -l)
echo -e "${GREEN}  ✓ $script_count scripts trouvés${NC}"

# Vérification exécutables
non_executable=$(find "$SCRIPT_DIR" -name "*.sh" -type f ! -executable | wc -l)
if [[ $non_executable -gt 0 ]]; then
    echo -e "${YELLOW}  ⚠ $non_executable script(s) non exécutable(s)${NC}"
    echo -e "${YELLOW}    → Exécutez: chmod +x scripts/*.sh${NC}"
    ((warnings++))
fi

# ═══════════════════════════════════════════════════════════
# Création répertoires de travail
# ═══════════════════════════════════════════════════════════
echo -e "\n${BLUE}▶ Création répertoires de travail...${NC}"

work_dirs=("audit-reports" "inventory-reports" "exports")
for dir in "${work_dirs[@]}"; do
    mkdir -p "$REPO_ROOT/$dir"
    echo -e "${GREEN}  ✓ $dir/ créé${NC}"
done

# Ajoute au .gitignore
if [[ -f "$REPO_ROOT/.gitignore" ]]; then
    for dir in "${work_dirs[@]}"; do
        if ! grep -q "^$dir/" "$REPO_ROOT/.gitignore" 2>/dev/null; then
            echo "$dir/" >> "$REPO_ROOT/.gitignore"
        fi
    done
    echo -e "${GREEN}  ✓ .gitignore mis à jour${NC}"
fi

# ═══════════════════════════════════════════════════════════
# Test rapide
# ═══════════════════════════════════════════════════════════
echo -e "\n${BLUE}▶ Test rapide (listing projets)...${NC}"

if command -v gcloud &> /dev/null && gcloud auth list --filter=status:ACTIVE &> /dev/null; then
    project_count=$(gcloud projects list --format="value(projectId)" 2>/dev/null | wc -l)
    if [[ $project_count -gt 0 ]]; then
        echo -e "${GREEN}  ✓ $project_count projet(s) GCP accessible(s)${NC}"
    else
        echo -e "${YELLOW}  ⚠ Aucun projet accessible${NC}"
        ((warnings++))
    fi
else
    echo -e "${YELLOW}  ⚠ Test ignoré (authentification requise)${NC}"
fi

# ═══════════════════════════════════════════════════════════
# Résumé
# ═══════════════════════════════════════════════════════════
echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  RÉSUMÉ VÉRIFICATION                       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
    echo -e "${GREEN}✅ TOUT EST OK !${NC}"
    echo -e "${GREEN}   GCP Toolbox est prêt à l'emploi.${NC}"
    echo ""
    echo -e "${CYAN}🚀 Prochaines étapes:${NC}"
    echo -e "  1. Exécuter votre premier audit:"
    echo -e "     ${YELLOW}./scripts/run-full-audit.sh${NC}"
    echo ""
    echo -e "  2. Ou tester un script individuel:"
    echo -e "     ${YELLOW}./scripts/list-gcp-projects.sh${NC}"
    echo ""
    echo -e "  3. Consulter la documentation:"
    echo -e "     ${YELLOW}open https://github.com/GitCroque/gcp-toolbox/wiki/Quick-Start${NC}"
    exit 0
elif [[ $errors -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  $warnings avertissement(s)${NC}"
    echo -e "${YELLOW}   GCP Toolbox est fonctionnel mais certaines fonctionnalités peuvent être limitées.${NC}"
    echo ""
    echo -e "${CYAN}🚀 Vous pouvez commencer:${NC}"
    echo -e "   ${YELLOW}./scripts/run-full-audit.sh${NC}"
    exit 0
else
    echo -e "${RED}❌ $errors erreur(s) | $warnings avertissement(s)${NC}"
    echo -e "${RED}   Corrigez les erreurs ci-dessus avant d'utiliser GCP Toolbox.${NC}"
    echo ""
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo -e "   ${YELLOW}https://github.com/GitCroque/gcp-toolbox/wiki/Quick-Start${NC}"
    exit 1
fi
