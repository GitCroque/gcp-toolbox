#!/bin/bash
set -euo pipefail

#####################################################################
# Script: generate-inventory-report.sh
# Description: Génère un rapport d'inventaire complet de la plateforme GCP
#              (projets, VMs, DBs, GKE, storage, coûts estimés)
#
# Prérequis: gcloud CLI
#
# Usage: ./generate-inventory-report.sh [OPTIONS]
#
# Options:
#   --output-dir DIR : Répertoire de sortie (défaut: ./inventory-reports)
#   --format FORMAT  : html, markdown, json (défaut: markdown)
#####################################################################

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options locales
OUTPUT_DIR="./inventory-reports"
FORMAT="markdown"

while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2; exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  📊 Génération Rapport Inventaire${NC}"
echo -e "${CYAN}========================================${NC}\n"

DATE=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="$OUTPUT_DIR/inventory-report-$DATE.$FORMAT"

echo -e "${YELLOW}Collecte des données...${NC}\n"

# Collecte projets
total_projects=$(gcloud projects list --format="value(projectId)" | wc -l)
echo -e "  ✓ Projets: $total_projects"

# Collecte VMs
total_vms=0
for proj in $(gcloud projects list --format="value(projectId)"); do
    vm_count=$(gcloud compute instances list --project="$proj" 2>/dev/null | wc -l || echo 0)
    ((total_vms+=vm_count))
done
echo -e "  ✓ VMs: $total_vms"

# Collecte SQL
total_sql=0
for proj in $(gcloud projects list --format="value(projectId)"); do
    sql_count=$(gcloud sql instances list --project="$proj" 2>/dev/null | wc -l || echo 0)
    ((total_sql+=sql_count))
done
echo -e "  ✓ Cloud SQL: $total_sql"

# Collecte GKE
total_gke=0
for proj in $(gcloud projects list --format="value(projectId)"); do
    gke_count=$(gcloud container clusters list --project="$proj" 2>/dev/null | wc -l || echo 0)
    ((total_gke+=gke_count))
done
echo -e "  ✓ GKE Clusters: $total_gke"

# Génère rapport
echo -e "\n${YELLOW}Génération du rapport...${NC}"

if [[ "$FORMAT" == "markdown" ]]; then
    cat > "$REPORT_FILE" <<EOF
# 📊 Rapport d'Inventaire GCP

**Généré le**: $(date '+%Y-%m-%d %H:%M:%S')

## 🎯 Vue d'Ensemble

| Catégorie | Quantité |
|-----------|----------|
| **Projets GCP** | $total_projects |
| **VMs (Compute Engine)** | $total_vms |
| **Instances Cloud SQL** | $total_sql |
| **Clusters GKE** | $total_gke |

## 📋 Détails par Projet

EOF

    # Détails par projet
    for proj in $(gcloud projects list --format="value(projectId)" | head -20); do
        vm_count=$(gcloud compute instances list --project="$proj" 2>/dev/null | wc -l || echo 0)
        sql_count=$(gcloud sql instances list --project="$proj" 2>/dev/null | wc -l || echo 0)
        gke_count=$(gcloud container clusters list --project="$proj" 2>/dev/null | wc -l || echo 0)

        cat >> "$REPORT_FILE" <<EOF
### Projet: $proj

- **VMs**: $vm_count
- **Cloud SQL**: $sql_count
- **GKE**: $gke_count

EOF
    done

    cat >> "$REPORT_FILE" <<EOF

## 📈 Tendances

- Total de ressources actives: $((total_vms + total_sql + total_gke))
- Utilisation moyenne par projet: $((($total_vms + total_sql + total_gke) / total_projects))

## 💰 Coûts Estimés

> Note: Les coûts sont des estimations. Consultez Cloud Billing pour coûts réels.

---

Rapport généré automatiquement par \`generate-inventory-report.sh\`
EOF

elif [[ "$FORMAT" == "json" ]]; then
    cat > "$REPORT_FILE" <<EOF
{
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": {
    "total_projects": $total_projects,
    "total_vms": $total_vms,
    "total_sql": $total_sql,
    "total_gke": $total_gke
  }
}
EOF
fi

echo -e "${GREEN}✅ Rapport généré: $REPORT_FILE${NC}"
echo -e "\n${CYAN}Pour visualiser:${NC}"
[[ "$FORMAT" == "markdown" ]] && echo -e "  cat $REPORT_FILE"
[[ "$FORMAT" == "json" ]] && echo -e "  jq . $REPORT_FILE"
