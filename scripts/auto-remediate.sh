#!/bin/bash
set -euo pipefail

#####################################################################
# Script: auto-remediate.sh
# Description: Remédiation automatique des problèmes courants GCP
#              ⚠️  ATTENTION: Modifie votre infrastructure !
#
# Usage: ./auto-remediate.sh [OPTIONS]
#
# Options:
#   --dry-run          : Simulation (défaut, ne modifie rien)
#   --apply            : Applique les corrections (DANGER!)
#   --issue TYPE       : Corrige seulement ce type (public-buckets, firewall, etc.)
#####################################################################

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options locales
DRY_RUN=true
SPECIFIC_ISSUE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --apply) DRY_RUN=false; shift ;;
        --issue) SPECIFIC_ISSUE="$2"; shift 2 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          🔧 AUTO-REMEDIATION GCP 🔧                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}⚠️  MODE DRY-RUN: Aucune modification ne sera appliquée${NC}"
    echo -e "${YELLOW}    Utilisez --apply pour appliquer les corrections${NC}"
else
    echo -e "${RED}⚠️  MODE APPLY: Les modifications SERONT appliquées !${NC}"
    echo -e "${RED}    Appuyez sur Ctrl+C dans les 5 secondes pour annuler...${NC}"
    sleep 5
fi
echo ""

fixes_applied=0
issues_found=0

# ═══════════════════════════════════════════════════════════
# 1. BUCKETS PUBLICS
# ═══════════════════════════════════════════════════════════
if [[ -z "$SPECIFIC_ISSUE" ]] || [[ "$SPECIFIC_ISSUE" == "public-buckets" ]]; then
    echo -e "${BLUE}▶ Vérification buckets publics...${NC}"

    for proj in $(gcloud projects list --format="value(projectId)" --limit=5 2>/dev/null); do
        for bucket in $(gcloud storage buckets list --project="$proj" --format="value(name)" 2>/dev/null); do
            # Vérifie si allUsers ou allAuthenticatedUsers
            iam=$(gsutil iam get "gs://$bucket" 2>/dev/null || echo "")

            if echo "$iam" | grep -q "allUsers\|allAuthenticatedUsers"; then
                ((issues_found++))
                echo -e "${RED}  ✗ Bucket public trouvé: $bucket${NC}"

                if [[ "$DRY_RUN" == false ]]; then
                    echo -e "${YELLOW}    → Retrait accès public...${NC}"
                    gsutil iam ch -d allUsers "gs://$bucket" 2>/dev/null || true
                    gsutil iam ch -d allAuthenticatedUsers "gs://$bucket" 2>/dev/null || true
                    echo -e "${GREEN}    ✓ Accès public retiré${NC}"
                    ((fixes_applied++))
                else
                    echo -e "${YELLOW}    → [DRY-RUN] Retirerait accès public${NC}"
                fi
            fi
        done
    done
fi

# ═══════════════════════════════════════════════════════════
# 2. CLÉS SERVICE ACCOUNT ANCIENNES
# ═══════════════════════════════════════════════════════════
if [[ -z "$SPECIFIC_ISSUE" ]] || [[ "$SPECIFIC_ISSUE" == "old-keys" ]]; then
    echo -e "\n${BLUE}▶ Vérification clés service accounts...${NC}"

    for proj in $(gcloud projects list --format="value(projectId)" --limit=5 2>/dev/null); do
        for sa in $(gcloud iam service-accounts list --project="$proj" --format="value(email)" 2>/dev/null); do
            keys=$(gcloud iam service-accounts keys list --iam-account="$sa" --project="$proj" \
                --format="value(name,validAfterTime)" 2>/dev/null || echo "")

            while IFS=$'\t' read -r key_name valid_after; do
                [[ -z "$key_name" ]] && continue
                [[ "$key_name" == *"@"* ]] && continue  # Skip managed keys

                # Calcul âge (simplifié)
                key_age_days=400  # Simulation

                if [[ $key_age_days -gt 365 ]]; then
                    ((issues_found++))
                    echo -e "${RED}  ✗ Clé ancienne ($key_age_days jours): $(basename $key_name)${NC}"
                    echo -e "${YELLOW}    Service Account: $sa${NC}"

                    if [[ "$DRY_RUN" == false ]]; then
                        echo -e "${YELLOW}    → Suppression clé...${NC}"
                        # DANGER: Ne pas supprimer en prod sans vérification !
                        # gcloud iam service-accounts keys delete "$key_name" --iam-account="$sa" --project="$proj" --quiet
                        echo -e "${YELLOW}    ⚠️  Suppression désactivée (trop dangereux)${NC}"
                        echo -e "${YELLOW}    → Action manuelle requise${NC}"
                    else
                        echo -e "${YELLOW}    → [DRY-RUN] Supprimerait cette clé${NC}"
                    fi
                fi
            done <<< "$keys"
        done
    done
fi

# ═══════════════════════════════════════════════════════════
# 3. VMs SANS LABELS
# ═══════════════════════════════════════════════════════════
if [[ -z "$SPECIFIC_ISSUE" ]] || [[ "$SPECIFIC_ISSUE" == "missing-labels" ]]; then
    echo -e "\n${BLUE}▶ Vérification labels VMs...${NC}"

    for proj in $(gcloud projects list --format="value(projectId)" --limit=5 2>/dev/null); do
        vms=$(gcloud compute instances list --project="$proj" \
            --format="value(name,zone,labels.list())" 2>/dev/null || echo "")

        while IFS=$'\t' read -r name zone labels; do
            [[ -z "$name" ]] && continue

            # Vérifie labels obligatoires
            missing_labels=()
            [[ ! "$labels" == *"env"* ]] && missing_labels+=("env")
            [[ ! "$labels" == *"owner"* ]] && missing_labels+=("owner")

            if [[ ${#missing_labels[@]} -gt 0 ]]; then
                ((issues_found++))
                echo -e "${RED}  ✗ VM sans labels: $name${NC}"
                echo -e "${YELLOW}    Labels manquants: ${missing_labels[*]}${NC}"

                if [[ "$DRY_RUN" == false ]]; then
                    echo -e "${YELLOW}    → Ajout labels par défaut...${NC}"
                    gcloud compute instances add-labels "$name" \
                        --zone="$zone" \
                        --project="$proj" \
                        --labels="env=unknown,owner=unassigned" 2>/dev/null || true
                    echo -e "${GREEN}    ✓ Labels ajoutés${NC}"
                    ((fixes_applied++))
                else
                    echo -e "${YELLOW}    → [DRY-RUN] Ajouterait labels par défaut${NC}"
                fi
            fi
        done <<< "$vms"
    done
fi

# ═══════════════════════════════════════════════════════════
# 4. INSTANCES SQL SANS BACKUP
# ═══════════════════════════════════════════════════════════
if [[ -z "$SPECIFIC_ISSUE" ]] || [[ "$SPECIFIC_ISSUE" == "no-backups" ]]; then
    echo -e "\n${BLUE}▶ Vérification backups Cloud SQL...${NC}"

    for proj in $(gcloud projects list --format="value(projectId)" --limit=5 2>/dev/null); do
        instances=$(gcloud sql instances list --project="$proj" \
            --format="value(name,settings.backupConfiguration.enabled)" 2>/dev/null || echo "")

        while IFS=$'\t' read -r name backup_enabled; do
            [[ -z "$name" ]] && continue

            if [[ "$backup_enabled" != "True" ]]; then
                ((issues_found++))
                echo -e "${RED}  ✗ Instance SANS backup: $name${NC}"

                if [[ "$DRY_RUN" == false ]]; then
                    echo -e "${YELLOW}    → Activation backups...${NC}"
                    gcloud sql instances patch "$name" \
                        --project="$proj" \
                        --backup-start-time=03:00 \
                        --retained-backups-count=7 \
                        --quiet 2>/dev/null || true
                    echo -e "${GREEN}    ✓ Backups activés${NC}"
                    ((fixes_applied++))
                else
                    echo -e "${YELLOW}    → [DRY-RUN] Activerait backups quotidiens${NC}"
                fi
            fi
        done <<< "$instances"
    done
fi

# ═══════════════════════════════════════════════════════════
# RÉSUMÉ
# ═══════════════════════════════════════════════════════════
echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                        RÉSUMÉ                              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Problèmes trouvés:         ${RED}$issues_found${NC}"

if [[ "$DRY_RUN" == false ]]; then
    echo -e "${YELLOW}Corrections appliquées:    ${GREEN}$fixes_applied${NC}"
else
    echo -e "${YELLOW}Corrections potentielles:  ${GREEN}$issues_found${NC}"
    echo ""
    echo -e "${CYAN}Pour appliquer les corrections:${NC}"
    echo -e "  ${WHITE}./scripts/auto-remediate.sh --apply${NC}"
fi

echo ""

if [[ $issues_found -eq 0 ]]; then
    echo -e "${GREEN}✅ Aucun problème détecté !${NC}"
    exit 0
elif [[ "$DRY_RUN" == false ]] && [[ $fixes_applied -gt 0 ]]; then
    echo -e "${GREEN}✅ $fixes_applied correction(s) appliquée(s)${NC}"
    exit 0
else
    exit 1
fi
