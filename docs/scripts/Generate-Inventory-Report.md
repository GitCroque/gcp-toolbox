# 📊 Generate Inventory Report

**Script** : `generate-inventory-report.sh`
**Priorité** : 🟢 UTILE
**Catégorie** : Reporting & Documentation

## 🎯 Objectif

Génère un **rapport d'inventaire complet** de la plateforme GCP (projets, VMs, DBs, GKE) en format Markdown, JSON ou HTML pour exec/management.

## 💡 Pourquoi c'est UTILE ?

### Cas d'Usage

**1. Reporting Mensuel Executive**
- "Voici l'état de notre infrastructure GCP en novembre 2024"
- Format Markdown → PDF pour C-level

**2. Documentation**
- Inventaire à jour pour nouvelles recrues
- Onboarding technique

**3. Audit Compliance**
- "Liste de toutes les ressources GCP"
- ISO27001, SOC2, audit annuel

**4. Capacity Planning**
- Tendances croissance infrastructure
- "56 VMs ce mois vs 42 le mois dernier"

## 📊 Que génère le script ?

### Contenu Rapport

1. ✅ **Vue d'ensemble** :
   - Total projets
   - Total VMs
   - Total Cloud SQL
   - Total GKE clusters

2. ✅ **Détails par projet** (top 20) :
   - Ressources par projet
   - Breakdown (VMs, SQL, GKE)

3. ✅ **Tendances** :
   - Utilisation moyenne
   - Estimations coûts (si activé)

## 🚀 Utilisation

```bash
# Générer rapport Markdown (défaut)
./scripts/generate-inventory-report.sh

# Personnaliser format
./scripts/generate-inventory-report.sh --format json
./scripts/generate-inventory-report.sh --format markdown

# Répertoire de sortie personnalisé
./scripts/generate-inventory-report.sh --output-dir /var/reports
```

## 📈 Exemple Sortie Markdown

```markdown
# 📊 Rapport d'Inventaire GCP

**Généré le**: 2024-11-15 10:30:00

## 🎯 Vue d'Ensemble

| Catégorie | Quantité |
|-----------|----------|
| **Projets GCP** | 156 |
| **VMs (Compute Engine)** | 342 |
| **Instances Cloud SQL** | 28 |
| **Clusters GKE** | 12 |

## 📋 Détails par Projet

### Projet: prod-app

- **VMs**: 45
- **Cloud SQL**: 5
- **GKE**: 2

### Projet: staging

- **VMs**: 12
- **Cloud SQL**: 2
- **GKE**: 1

[... autres projets ...]

## 📈 Tendances

- Total de ressources actives: 382
- Utilisation moyenne par projet: 2.4

## 💰 Coûts Estimés

> Note: Les coûts sont des estimations. Consultez Cloud Billing pour coûts réels.

---

Rapport généré automatiquement par `generate-inventory-report.sh`
```

## 🔄 Automatisation Mensuelle

### Cron Job

```bash
#!/bin/bash
# monthly-inventory.sh

# 1er de chaque mois à 9h
# Crontab: 0 9 1 * * /path/to/monthly-inventory.sh

DATE=$(date +%Y-%m)
OUTPUT_DIR="/var/reports/inventory"
mkdir -p "$OUTPUT_DIR"

# Générer rapport
./scripts/generate-inventory-report.sh \
  --output-dir "$OUTPUT_DIR" \
  --format markdown

# Convertir Markdown → PDF (optionnel)
# pandoc "$OUTPUT_DIR/inventory-report-*.md" -o "$OUTPUT_DIR/report-$DATE.pdf"

# Envoyer par email
mail -s "GCP Inventory Report - $DATE" \
  -a "$OUTPUT_DIR/inventory-report-*.md" \
  exec@company.com < /dev/null
```

## 📊 Comparaison Temporelle

```bash
# Sauvegarder rapports mensuels
./scripts/generate-inventory-report.sh \
  --output-dir /var/reports/2024-10 \
  --format json

./scripts/generate-inventory-report.sh \
  --output-dir /var/reports/2024-11 \
  --format json

# Comparer
diff <(jq '.summary' /var/reports/2024-10/*.json) \
     <(jq '.summary' /var/reports/2024-11/*.json)

# Exemple résultat:
# VMs: 342 → 387 (+45 VMs ce mois)
```

## 💼 Usage Executive

### Présentation Board

1. **Générer rapport**
2. **Convertir en PDF** (pandoc, wkhtmltopdf)
3. **Ajouter graphs** (depuis Cloud Monitoring)
4. **Présenter** : "Voici notre infrastructure GCP"

### Metrics à Tracker

- **Croissance** : +X% VMs vs mois dernier
- **Optimisation** : -Y% projets inactifs nettoyés
- **Coûts** : Tendance mensuelle

---

[⬅️ Audit Labels](Audit-Resource-Labels.md) | [🏠 Wiki](../HOME.md)
