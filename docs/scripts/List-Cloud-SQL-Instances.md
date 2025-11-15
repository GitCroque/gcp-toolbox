# 💾 List Cloud SQL Instances

**Script** : `list-cloud-sql-instances.sh`
**Priorité** : 🟢 UTILE
**Catégorie** : Inventaire & Monitoring

## 🎯 Objectif

Inventorie toutes vos instances Cloud SQL avec leurs **configurations, coûts, et statut de sécurité** (HA, backups, encryption).

## 💡 Pourquoi c'est UTILE ?

### Visibilité Complète

Vous devez savoir :

- 📊 **Combien** d'instances vous avez (éviter shadow IT)
- 💰 **Combien** elles coûtent (optimisation budget)
- 🛡️ **Lesquelles** sont protégées (HA, backups)
- 🔄 **Quelles versions** sont déployées (upgrade planning)
- 🌍 **Où** elles sont localisées (compliance, latence)

### Cas d'Usage Réels

**Audit de Sécurité** :
- "Quelles instances n'ont pas de backup ?" → Risque data loss
- "Lesquelles n'ont pas HA ?" → Risque downtime

**Optimisation Coûts** :
- "Combien coûtent nos bases ?" → Budget planning
- "Quelle instance dev a HA activée ?" → Waste detection

**Compliance** :
- "Toutes nos DBs sont en Europe ?" → RGPD
- "Quelle version PostgreSQL ?" → Security patching

## 📊 Que liste le script ?

### Informations Par Instance

1. ✅ **Projet** : GCP project ID
2. ✅ **Nom** : Instance name
3. ✅ **Type DB** : MySQL, PostgreSQL, SQL Server
4. ✅ **Version** : Ex: POSTGRES_14, MYSQL_8_0
5. ✅ **Tier** : db-n1-standard-1, db-f1-micro, etc.
6. ✅ **Région** : us-central1, europe-west1, etc.
7. ✅ **HA** : Activée ou non (REGIONAL availability)
8. ✅ **Backup** : Activé ou non
9. ✅ **Coût estimé** : Par mois en USD

### Résumé Global

- Total instances
- Breakdown par type (MySQL, PostgreSQL, SQL Server)
- Nombre avec HA activée
- Nombre avec backups
- Coût total estimé mensuel

## 🚀 Utilisation

### Basique

```bash
# Liste toutes les instances Cloud SQL
./scripts/list-cloud-sql-instances.sh

# Affiche table formatée avec couleurs
```

### Options

```bash
# Un seul projet
./scripts/list-cloud-sql-instances.sh --project mon-projet-prod

# Export JSON pour automatisation
./scripts/list-cloud-sql-instances.sh --json > cloudsql.json
```

### Analyse avec jq

```bash
# Instances SANS backup
./scripts/list-cloud-sql-instances.sh --json | \
  jq '.sql_instances[] | select(.backup_enabled == "No")'

# Instances les plus coûteuses
./scripts/list-cloud-sql-instances.sh --json | \
  jq '.sql_instances | sort_by(.estimated_monthly_cost_usd) | reverse | .[0:5]'

# Total coût PostgreSQL
./scripts/list-cloud-sql-instances.sh --json | \
  jq '[.sql_instances[] | select(.database_version | startswith("POSTGRES")) | .estimated_monthly_cost_usd | tonumber] | add'
```

## 📈 Exemple de Sortie

### Format Table

```
========================================
  💾 Cloud SQL Instances
========================================

Récupération des instances Cloud SQL...

PROJECT_ID                INSTANCE_NAME                  DB_VERSION   TIER                 REGION     HA         BACKUP     COST/MONTH
----------                -------------                  ----------   ----                 ------     --         ------     ----------
prod-app                  postgres-main                  POSTGRES_14  db-n1-standard-2     us-cent    Yes        Yes        $200
prod-app                  mysql-analytics                MYSQL_8_0    db-n1-standard-4     us-cent    No         No         $200
dev-env                   postgres-dev                   POSTGRES_13  db-f1-micro          us-cent    No         Yes        $10
staging                   mysql-staging                  MYSQL_8_0    db-g1-small          eu-west    No         Yes        $30

========== Résumé ==========
Total instances:           4
  - MySQL:                 2
  - PostgreSQL:            2
  - SQL Server:            0
HA activée:                1 / 4
Backup activé:             3 / 4
Coût estimé/mois:          $440 USD

⚠️  1 instance(s) sans backup automatique !

========== Recommandations ==========

Best Practices Cloud SQL :

1. Activer les backups automatiques (CRITICAL)
2. Activer High Availability pour production
3. Utiliser des versions récentes de DB
4. Configurer des maintenance windows
5. Activer SSL/TLS pour les connexions
6. Utiliser Private IP au lieu de Public IP
7. Monitorer les performances via Cloud Monitoring
```

### Format JSON

```json
{
  "generated_at": "2024-11-15T10:30:00Z",
  "sql_instances": [
    {
      "project_id": "prod-app",
      "name": "postgres-main",
      "database_version": "POSTGRES_14",
      "region": "us-central1",
      "tier": "db-n1-standard-2",
      "ha_enabled": "Yes",
      "backup_enabled": "Yes",
      "estimated_monthly_cost_usd": "200"
    }
  ],
  "summary": {
    "total_instances": 4,
    "mysql_instances": 2,
    "postgres_instances": 2,
    "sqlserver_instances": 0,
    "ha_enabled_count": 1,
    "backup_enabled_count": 3,
    "estimated_monthly_cost_usd": 440
  }
}
```

## 🔧 Actions Recommandées

### Si instances SANS backup

```bash
# Lister instances sans backup
./scripts/list-cloud-sql-instances.sh --json | \
  jq -r '.sql_instances[] | select(.backup_enabled == "No") | .name'

# Pour chaque instance : ACTIVER BACKUPS
INSTANCE_NAME="mysql-analytics"
PROJECT_ID="prod-app"

gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --backup-start-time=03:00 \
  --retained-backups-count=7 \
  --enable-bin-log

# ✅ Backups activés
```

➡️ Voir documentation détaillée : [Audit Database Backups](Audit-Database-Backups.md)

### Si instances prod SANS HA

```bash
# Lister instances sans HA
./scripts/list-cloud-sql-instances.sh --json | \
  jq -r '.sql_instances[] | select(.ha_enabled == "No") | .name'

# Activer HA (⚠️ Cause redémarrage !)
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --availability-type=REGIONAL

# ✅ HA activée (failover automatique)
```

**Note HA** :
- **Coût** : Double le prix de l'instance
- **Bénéfice** : 99.95% SLA (vs 99.50% sans HA)
- **Downtime** : Failover automatique en ~30 secondes
- **Recommandé** : Production uniquement

### Optimisation Coûts

```bash
# Instances dev/test avec config de prod
./scripts/list-cloud-sql-instances.sh --json | \
  jq '.sql_instances[] | select(.project_id | contains("dev") or contains("test")) | select(.ha_enabled == "Yes")'

# Désactiver HA sur dev/test
gcloud sql instances patch DEV_INSTANCE \
  --project=dev-project \
  --availability-type=ZONAL

# Économie : 50% sur cette instance
```

## 📊 Tiers Cloud SQL (Machine Types)

### Shared-Core (Dev/Test)

| Tier | vCPU | RAM | Coût/mois* | Usage |
|------|------|-----|------------|-------|
| db-f1-micro | Shared | 0.6 GB | $10 | Dev léger |
| db-g1-small | Shared | 1.7 GB | $30 | Dev/Test |

### Standard (Production)

| Tier | vCPU | RAM | Coût/mois* | Usage |
|------|------|-----|------------|-------|
| db-n1-standard-1 | 1 | 3.75 GB | $50 | Prod petit |
| db-n1-standard-2 | 2 | 7.5 GB | $100 | Prod moyen |
| db-n1-standard-4 | 4 | 15 GB | $200 | Prod gros |
| db-n1-standard-8 | 8 | 30 GB | $400 | Prod XL |

### High-Memory (Analytics, Cache)

| Tier | vCPU | RAM | Coût/mois* | Usage |
|------|------|-----|------------|-------|
| db-n1-highmem-2 | 2 | 13 GB | $150 | Analytics |
| db-n1-highmem-4 | 4 | 26 GB | $300 | Analytics++ |

**\* Coûts indicatifs us-central1, sans HA. Doubler si HA activé.**

## 🔄 Migrations & Upgrades

### Vérifier Versions Déployées

```bash
# Lister toutes les versions
./scripts/list-cloud-sql-instances.sh --json | \
  jq -r '.sql_instances[].database_version' | sort | uniq -c

# Exemple sortie:
#   2 MYSQL_8_0
#   1 POSTGRES_13
#   1 POSTGRES_14
```

### Upgrade de Version

```bash
# MySQL 5.7 → 8.0
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --database-version=MYSQL_8_0

# PostgreSQL 13 → 14
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --database-version=POSTGRES_14

# ⚠️ Teste en dev/staging d'abord !
# ⚠️ Backup avant upgrade !
# ⚠️ Maintenance window appropriée !
```

### Migration Cross-Region

**Scénario** : Migrer instance US → EU (compliance RGPD)

```bash
# 1. Créer replica en Europe
gcloud sql instances create $INSTANCE_NAME-eu \
  --project=$PROJECT_ID \
  --master-instance-name=$INSTANCE_NAME \
  --region=europe-west1

# 2. Attendre sync complet
gcloud sql instances describe $INSTANCE_NAME-eu \
  --project=$PROJECT_ID \
  --format="value(replicaConfiguration.failoverTarget)"

# 3. Promouvoir replica EU en master
gcloud sql instances promote-replica $INSTANCE_NAME-eu \
  --project=$PROJECT_ID

# 4. Migrer application vers nouvelle instance

# 5. Supprimer ancienne instance US
gcloud sql instances delete $INSTANCE_NAME \
  --project=$PROJECT_ID
```

## 🛡️ Sécurité

### Connexions Sécurisées

```bash
# Vérifier si SSL requis
gcloud sql instances describe $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --format="value(settings.ipConfiguration.requireSsl)"

# Activer SSL obligatoire
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --require-ssl
```

### Private IP (Recommandé)

```bash
# Désactiver Public IP, utiliser Private IP
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --network=projects/$PROJECT_ID/global/networks/default \
  --no-assign-ip

# ✅ Instance accessible uniquement via VPC (plus sécurisé)
```

### Authorized Networks (Si Public IP nécessaire)

```bash
# Limiter accès à IPs spécifiques
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --authorized-networks=203.0.113.0/24,198.51.100.42

# Eviter 0.0.0.0/0 (ouvert à Internet !)
```

## 📅 Fréquence Recommandée

| Action | Fréquence |
|--------|-----------|
| **Inventaire complet** | Mensuel |
| **Vérification backups** | Quotidien (via audit-database-backups.sh) |
| **Review coûts** | Mensuel |
| **Audit sécurité** | Trimestriel |
| **Version check** | Mensuel |

## 🔍 Troubleshooting

### "No instances found" mais j'ai des instances

**Causes** :
1. Permissions insuffisantes
2. Mauvais projet sélectionné

**Solution** :
```bash
# Vérifier permissions
gcloud sql instances list --project=PROJECT_ID

# Si erreur permission : demander rôle
# roles/cloudsql.viewer (lecture)
# roles/cloudsql.admin (admin)
```

### Coûts estimés différents de la facture

**Causes** :
1. Script utilise prix indicatifs us-central1
2. Votre région plus chère (ex: asia-northeast)
3. Coûts réseau/stockage non inclus
4. Snapshots non comptés

**Solution** :
```bash
# Coûts réels via Cloud Billing
gcloud billing accounts list
gcloud beta billing budgets list --billing-account=ACCOUNT_ID
```

### Instance très lente

**Debug** :
```bash
# Métriques CPU/RAM/Disk
gcloud sql instances describe $INSTANCE_NAME \
  --project=$PROJECT_ID

# Upgrade temporaire pour tester
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --tier=db-n1-standard-4

# Si amélioration : garder tier plus gros
```

## 📚 Ressources

- [Cloud SQL Overview](https://cloud.google.com/sql/docs)
- [Machine Types](https://cloud.google.com/sql/docs/mysql/instance-settings)
- [High Availability](https://cloud.google.com/sql/docs/mysql/high-availability)
- [Backups & Recovery](https://cloud.google.com/sql/docs/mysql/backup-recovery/backups)
- [Security Best Practices](https://cloud.google.com/sql/docs/mysql/security-best-practices)
- [Pricing Calculator](https://cloud.google.com/products/calculator)

## 🎯 Checklist Instances Production

Avant de mettre une instance en production :

- [ ] **Backup** : Activé (7-30 jours rétention)
- [ ] **HA** : Activé (REGIONAL availability)
- [ ] **SSL** : Requis (--require-ssl)
- [ ] **Private IP** : Configuré (pas de public IP)
- [ ] **Maintenance Window** : Définie (hors heures de pointe)
- [ ] **Monitoring** : Alertes CPU/RAM/Disk configurées
- [ ] **Version** : Récente et supportée
- [ ] **Sizing** : Tier approprié (load tested)
- [ ] **Encryption** : Customer-managed key (si requis compliance)
- [ ] **Authorized Networks** : Restreint (si public IP nécessaire)
- [ ] **Binary Logging** : Activé (point-in-time recovery)
- [ ] **Documentation** : Connection strings, runbooks

## 💰 Optimisation Coûts

### Quick Wins

1. **Désactiver HA sur non-prod**
   ```bash
   # Économie: 50% par instance
   gcloud sql instances patch DEV_INSTANCE --availability-type=ZONAL
   ```

2. **Downsize instances dev**
   ```bash
   # db-n1-standard-2 → db-g1-small
   # Économie: $70/mois par instance
   gcloud sql instances patch DEV_INSTANCE --tier=db-g1-small
   ```

3. **Supprimer instances inutilisées**
   ```bash
   # Vérifier connexions récentes
   gcloud sql operations list --instance=$INSTANCE_NAME --limit=10

   # Si aucune activité : supprimer
   gcloud sql instances delete OLD_INSTANCE
   ```

### Committed Use Discounts (CUDs)

```bash
# Engagement 1-3 ans pour économies 25-52%
# Via Console GCP > SQL > Committed Use Discounts
```

---

[⬅️ Audit Backups](Audit-Database-Backups.md) | [🏠 Wiki](../HOME.md) | [➡️ List GKE Clusters](List-GKE-Clusters.md)
