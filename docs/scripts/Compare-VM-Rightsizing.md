# 💰 Compare VM Rightsizing

**Script** : `compare-vm-rightsizing.sh`
**Priorité** : 🟡 IMPORTANT
**Catégorie** : Optimisation Coûts

## 🎯 Objectif

Analyse l'utilisation réelle CPU/RAM de vos VMs et suggère du **rightsizing** pour économiser 15-30% sur vos coûts compute.

## 💸 Pourquoi c'est IMPORTANT ?

### Le Problème : Sur-Provisionnement

90% des entreprises sur-provisionnent leurs VMs :

- 🔴 **"On ne sait jamais"** : Équipes demandent des VMs trop grosses "au cas où"
- 🔴 **Copy-paste** : Nouvelle VM = copie de la précédente (sans analyse)
- 🔴 **Set & Forget** : VM créée il y a 2 ans, jamais revue
- 🔴 **Pics occasionnels** : VM dimensionnée pour Black Friday, utilisée 1 jour/an

### L'Impact Financier

**Exemple réel** :

```
VM actuelle:   n1-standard-8 (8 vCPU, 30 GB RAM)
Coût:          $243/mois
Utilisation:   CPU 15% | RAM 35%

VM suggérée:   n1-standard-4 (4 vCPU, 15 GB RAM)
Coût:          $121/mois
Économie:      $122/mois = $1,464/an
```

**À l'échelle** (100 VMs) :
- **15% économies** = $43,740/an
- **30% économies** = $87,480/an

## 📊 Que fait le script ?

### Analyse

Pour chaque VM en cours d'exécution :

1. ✅ **Récupère métriques** : CPU et RAM moyens (X derniers jours)
2. ✅ **Compare à des seuils** : Sur/sous-provisionnement
3. ✅ **Suggère action** : Downsize, Upsize, ou OK
4. ✅ **Estime économies** : Coût actuel vs. suggéré

### Niveaux de Recommandation

| CPU Moyen | RAM Moyen | Recommandation | Action |
|-----------|-----------|----------------|--------|
| < 30% | < 40% | 🟢 **Downsize** | Économies possibles |
| 30-80% | 40-85% | 🔵 **Right-sized** | Rien à faire |
| > 80% | > 85% | 🟡 **Upsize** | Risque de perf |

## 🚀 Utilisation

### Basique

```bash
# Analyse toutes les VMs (7 derniers jours)
./scripts/compare-vm-rightsizing.sh

# Affiche uniquement les VMs à optimiser
```

### Options

```bash
# Analyse sur 30 jours (plus précis)
./scripts/compare-vm-rightsizing.sh --days 30

# Un seul projet
./scripts/compare-vm-rightsizing.sh --project mon-projet-prod

# Export JSON pour automatisation
./scripts/compare-vm-rightsizing.sh --json > rightsizing.json
```

### Combinaisons

```bash
# Analyse 30j en JSON avec jq pour filtrer
./scripts/compare-vm-rightsizing.sh --days 30 --json | \
  jq '.vms[] | select(.recommendation | contains("over"))'
```

## 📈 Exemple de Sortie

### Format Table

```
======================================
  💰 VM Rightsizing Analysis
======================================

Analyse sur les 7 derniers jours

PROJECT                   VM_NAME                        CURRENT_TYPE         AVG_CPU         AVG_RAM         RECOMMENDATION
-------                   -------                        ------------         -------         -------         --------------
prod-app                  backend-1                      n1-standard-8        18%             32%             Downsize (over-provisioned)
prod-app                  database-primary               n1-highmem-4         85%             88%             Upsize (under-provisioned)
dev-env                   test-server                    n1-standard-2        12%             25%             Downsize (over-provisioned)

=== Résumé ===
Total VMs analysées:       42
Sur-provisionnées:         15
Sous-provisionnées:        3
Bien dimensionnées:        24
Économies potentielles:    $750/mois

Note: Basé sur simulation. En production, utiliser Cloud Monitoring pour métriques réelles.
```

### Format JSON

```json
{
  "generated_at": "2024-11-15T10:30:00Z",
  "analysis_days": 7,
  "vms": [
    {
      "project": "prod-app",
      "vm": "backend-1",
      "type": "n1-standard-8",
      "cpu": 18,
      "ram": 32,
      "recommendation": "Downsize (over-provisioned)",
      "savings": 50
    }
  ],
  "summary": {
    "total": 42,
    "over_provisioned": 15,
    "under_provisioned": 3,
    "right_sized": 24,
    "potential_monthly_savings_usd": 750
  }
}
```

## 🔧 Remédiation

### Downsize (Sur-provisionnement)

**⚠️ IMPORTANT** : Planifier en hors-pics, avoir rollback plan !

#### Étape 1 : Snapshot (Backup)

```bash
PROJECT_ID="votre-projet"
VM_NAME="vm-to-resize"
ZONE="us-central1-a"

# Créer snapshot du disque
gcloud compute disks snapshot DISK_NAME \
  --project=$PROJECT_ID \
  --snapshot-names=$VM_NAME-pre-resize-$(date +%Y%m%d) \
  --zone=$ZONE

# ✅ Rollback possible si problème
```

#### Étape 2 : Arrêter VM

```bash
# Arrêt gracieux
gcloud compute instances stop $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE

# Attendre confirmation
gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(status)"
# Doit afficher: TERMINATED
```

#### Étape 3 : Changer Machine Type

```bash
# Exemple: n1-standard-8 → n1-standard-4
NEW_TYPE="n1-standard-4"

gcloud compute instances set-machine-type $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=$NEW_TYPE

# ✅ Type changé
```

#### Étape 4 : Redémarrer et Tester

```bash
# Redémarrage
gcloud compute instances start $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE

# Monitorer (30 min à 2h)
watch -n 60 'gcloud compute instances describe $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --format="value(status)"'

# Vérifier métriques
# Console → Monitoring → VM Metrics
# Si CPU/RAM > 90% : rollback !
```

#### Étape 5 : Rollback si Problème

```bash
# Si problème détecté dans les 24-48h
gcloud compute instances stop $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE

gcloud compute instances set-machine-type $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=n1-standard-8  # Ancienne taille

gcloud compute instances start $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE
```

### Upsize (Sous-provisionnement)

**Symptômes** :
- Latence accrue
- Timeouts
- OOM (Out of Memory) errors
- Swap usage élevé

**Procédure identique**, mais vers machine type plus gros.

## 📊 Métriques Réelles (Production)

### Le script utilise des simulations

**⚠️ IMPORTANT** : En production, utilisez Cloud Monitoring API !

### Obtenir Métriques Réelles

```bash
# CPU moyen (7 derniers jours)
gcloud monitoring time-series list \
  --filter="metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.labels.instance_id=\"INSTANCE_ID\"" \
  --project=$PROJECT_ID \
  --format="table(point.value.doubleValue)" \
  --start-time=$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# RAM moyenne
gcloud monitoring time-series list \
  --filter="metric.type=\"agent.googleapis.com/memory/percent_used\"" \
  --project=$PROJECT_ID \
  --format="table(point.value.doubleValue)" \
  # Nécessite Cloud Monitoring Agent installé
```

### Installer Monitoring Agent

```bash
# Sur chaque VM (une fois)
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

# Vérifier
sudo systemctl status google-cloud-ops-agent
```

## 🎯 Stratégies Avancées

### 1. Rightsizing par Environnement

```bash
# Production: analyse 30 jours (plus stable)
./scripts/compare-vm-rightsizing.sh --project prod --days 30

# Dev/Test: analyse 7 jours (évolution rapide)
./scripts/compare-vm-rightsizing.sh --project dev --days 7
```

### 2. Approche Progressive

**Semaine 1** : VMs dev/test (risque faible)
**Semaine 2** : VMs staging
**Semaine 3** : VMs prod non-critiques
**Semaine 4** : VMs prod critiques (1 par 1)

### 3. Blue/Green Deployment

```bash
# Créer nouvelle VM avec taille optimisée
gcloud compute instances create backend-2-optimized \
  --machine-type=n1-standard-4 \
  --image-family=ubuntu-2004-lts \
  --image-project=ubuntu-os-cloud

# Migrer trafic progressivement
# Load Balancer: backend-1 (100%) → backend-2 (0%)
#                backend-1 (50%)  → backend-2 (50%)
#                backend-1 (0%)   → backend-2 (100%)

# Supprimer ancienne VM après validation
```

### 4. Autoscaling (Alternative)

Au lieu de rightsizing manuel, utilisez autoscaling :

```bash
# Instance Group Managed avec autoscaling
gcloud compute instance-groups managed set-autoscaling INSTANCE_GROUP \
  --max-num-replicas=10 \
  --min-num-replicas=2 \
  --target-cpu-utilization=0.6 \
  --cool-down-period=90

# VMs plus petites + scaling horizontal
# Plus résilient ET moins cher
```

## 📅 Fréquence Recommandée

| Action | Fréquence |
|--------|-----------|
| **Analyse** | Mensuelle |
| **Rightsizing dev** | Trimestriel |
| **Rightsizing prod** | Annuel (ou lors changement usage) |

### Automatisation

```bash
# Cron mensuel (1er du mois à 9h)
0 9 1 * * /path/to/compare-vm-rightsizing.sh --days 30 --json > /var/log/rightsizing-$(date +\%Y\%m).json

# Alerter si opportunités > $500/mois
0 9 1 * * /path/to/compare-vm-rightsizing.sh --days 30 --json | \
  jq -e '.summary.potential_monthly_savings_usd > 500' && \
  mail -s "💰 GCP: Économies possibles > $500/mois" finops@company.com
```

## 🛡️ Best Practices

### ✅ À FAIRE

1. **Baseline d'abord** : Analyser 30 jours minimum avant changement
2. **Tester en dev** : Valider nouveau sizing en dev/staging first
3. **Snapshot avant** : Toujours snapshot avant resize
4. **Fenêtre de maintenance** : Resize en hors-pics
5. **Monitorer après** : 48h de monitoring intensif post-resize
6. **Documentation** : Documenter raison du sizing
7. **Alerts** : Configurer alertes CPU/RAM > 90%

### ❌ À ÉVITER

1. ❌ Resize en production sans test
2. ❌ Downsize de plus de 50% d'un coup
3. ❌ Se baser sur 1-2 jours de métriques
4. ❌ Ignorer les pics saisonniers (Black Friday, etc.)
5. ❌ Resize sans backup
6. ❌ Oublier le rollback plan
7. ❌ Rightsizing pendant pics de trafic

## 🔍 Troubleshooting

### "No data available"

**Cause** : Monitoring agent pas installé ou VM arrêtée

**Solution** :
```bash
# Vérifier status VM
gcloud compute instances list --filter="name:VM_NAME"

# Installer agent
# SSH sur VM
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
```

### Métriques incohérentes

**Causes** :
- Période d'analyse trop courte
- Pics occasionnels (déploiements, batch jobs)
- Caching froid (démarrage récent)

**Solution** :
```bash
# Analyser 30 jours minimum
./scripts/compare-vm-rightsizing.sh --days 30

# Exclure VMs récentes (<30j)
gcloud compute instances list --format="table(name,creationTimestamp)"
```

### Après resize, VM lente

**Causes possibles** :
1. Downsizé trop agressivement
2. Workload a changé
3. Période d'analyse pas représentative

**Action** :
```bash
# Rollback immédiat
# (Voir procédure Étape 5 ci-dessus)

# Analyser avec période plus longue
./scripts/compare-vm-rightsizing.sh --days 90
```

## 📚 Ressources

- [Machine Types](https://cloud.google.com/compute/docs/machine-types)
- [Cloud Monitoring](https://cloud.google.com/monitoring/docs)
- [Rightsizing Recommender](https://cloud.google.com/compute/docs/instances/apply-machine-type-recommendations)
- [Cost Optimization Best Practices](https://cloud.google.com/architecture/cost-optimization)

## 🎯 Checklist Rightsizing

Avant de changer une VM :

- [ ] Métriques 30 jours analysées
- [ ] Pics saisonniers considérés
- [ ] Snapshot/backup créé
- [ ] Fenêtre de maintenance planifiée
- [ ] Équipe on-call notifiée
- [ ] Rollback plan documenté
- [ ] Monitoring dashboards ouverts
- [ ] Communication utilisateurs (si downtime)

Après changement :

- [ ] VM redémarrée correctement
- [ ] Application fonctionne
- [ ] Métriques < 80% (CPU/RAM)
- [ ] Latence inchangée
- [ ] Logs sans erreurs
- [ ] Monitoring 48h activé
- [ ] Documentation mise à jour

## 💡 Alternatives au Rightsizing

### 1. Committed Use Discounts (CUDs)

```bash
# Garder VMs actuelles, mais engager 1-3 ans
# Économie: 25-57% (sans risque technique)
./scripts/analyze-committed-use.sh
```

### 2. Spot VMs

```bash
# VMs préemptibles (jusqu'à 91% moins cher)
# Idéal pour: batch, CI/CD, dev
./scripts/check-preemptible-candidates.sh
```

### 3. Autoscaling

```bash
# Scale horizontal automatique
# Plus de VMs petites = moins cher + résilient
```

### 4. Serverless

```bash
# Cloud Run, Cloud Functions
# Pay-per-use (pas de VM idle)
# Idéal pour: APIs, microservices
```

## 📊 ROI Exemple

**Entreprise moyenne (100 VMs)** :

| Action | Économies/an |
|--------|--------------|
| Rightsizing 20 VMs (downsize 30%) | $26,000 |
| CUDs sur 50 VMs restantes | $45,000 |
| Migration 30 VMs vers Spot | $82,000 |
| **TOTAL** | **$153,000/an** |

**Effort** : 2-3 semaines d'ingénieur
**ROI** : 15x

---

[⬅️ Scan Public Buckets](Scan-Public-Buckets.md) | [🏠 Wiki](../HOME.md) | [➡️ Audit Database Backups](Audit-Database-Backups.md)
