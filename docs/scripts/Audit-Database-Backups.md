# 💾 Audit Database Backups

**Script** : `audit-database-backups.sh`
**Priorité** : 🔴 CRITIQUE
**Catégorie** : Disaster Recovery

## 🎯 Objectif

Vérifie que **toutes vos bases de données Cloud SQL ont des backups actifs** pour éviter une perte de données catastrophique.

## ⚠️ Pourquoi c'est CRITIQUE ?

### Le Cauchemar : Pas de Backup

**Scénarios réels** :

1. 🔴 **Suppression accidentelle** :
   - Développeur exécute `DROP TABLE` sur mauvaise DB
   - Pas de backup → Données perdues DÉFINITIVEMENT

2. 🔴 **Corruption de données** :
   - Bug applicatif corrompt les données
   - Détecté 2 semaines plus tard
   - Pas de backup → Impossible de restaurer

3. 🔴 **Ransomware** :
   - Attaque chiffre la base de données
   - Demande rançon
   - Pas de backup → Obligé de payer ou perdre tout

4. 🔴 **Incident GCP** :
   - Très rare, mais arrive
   - Zone GCP down
   - Sans backup dans autre région → Downtime prolongé

### Impact Business

**Statistiques** :

- 60% des entreprises sans backup ferment dans les 6 mois après perte de données
- Coût moyen d'un incident : $5.9M (IBM 2023)
- 93% des entreprises sans DR plan font faillite dans l'année

**Conformité** :

- RGPD : Intégrité des données obligatoire
- SOC2 : Backups réguliers requis
- ISO27001 : Plan de reprise obligatoire

## 📊 Que vérifie le script ?

### Vérifications

Pour chaque instance Cloud SQL :

1. ✅ **Backup activé ?** (enabled/disabled)
2. ✅ **Date dernier backup** (quand ?)
3. ✅ **Fréquence** (quotidien recommandé)
4. ✅ **Fenêtre de backup** (heure)
5. ✅ **Rétention** (combien de jours gardés)

### Statuts

| Statut | Condition | Gravité |
|--------|-----------|---------|
| 🔴 **NO_BACKUP** | Backup désactivé | CRITIQUE |
| 🟡 **OLD_BACKUP** | Dernier backup > 7 jours | WARNING |
| 🟢 **OK** | Backup récent (< 24h) | OK |

## 🚀 Utilisation

### Basique

```bash
# Vérifier toutes les instances Cloud SQL
./scripts/audit-database-backups.sh

# Affiche statut backup de chaque instance
```

### Options

```bash
# Un seul projet
./scripts/audit-database-backups.sh --project mon-projet-prod

# Export JSON
./scripts/audit-database-backups.sh --json > db-backups.json
```

### Analyse avec jq

```bash
# Instances SANS backup
./scripts/audit-database-backups.sh --json | \
  jq '.instances[] | select(.status == "NO_BACKUP")'

# Compte instances sans backup
./scripts/audit-database-backups.sh --json | \
  jq '.summary.without_backup'
```

## 📈 Exemple de Sortie

### Format Table

```
======================================
  📦 Audit Database Backups
======================================

Vérification des backups Cloud SQL...

PROJECT                   INSTANCE                       BACKUP_ENABLED  LAST_BACKUP          STATUS
-------                   --------                       --------------  -----------          ------
prod-app                  postgres-prod                  True            2024-11-15T08:00     OK
prod-app                  mysql-analytics                False           N/A                  NO_BACKUP
dev-env                   postgres-dev                   True            2024-11-14T08:00     OK

=== Résumé ===
Total instances:        3
Avec backup:            2
SANS backup:            1

⚠️  1 instance(s) SANS BACKUP !
```

### Format JSON

```json
{
  "generated_at": "2024-11-15T10:30:00Z",
  "instances": [
    {
      "project": "prod-app",
      "instance": "postgres-prod",
      "backup_enabled": "True",
      "last_backup": "2024-11-15T08:00:00Z",
      "status": "OK"
    },
    {
      "project": "prod-app",
      "instance": "mysql-analytics",
      "backup_enabled": "False",
      "last_backup": "N/A",
      "status": "NO_BACKUP"
    }
  ],
  "summary": {
    "total": 3,
    "with_backup": 2,
    "without_backup": 1
  }
}
```

## 🔧 Remédiation URGENTE

### Si instance SANS backup détectée

#### Étape 1 : ACTIVER LES BACKUPS (< 5 min)

```bash
INSTANCE_NAME="votre-instance"
PROJECT_ID="votre-projet"

# Activer backups automatiques
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --backup-start-time=03:00 \
  --backup-location=us \
  --retained-backups-count=7 \
  --enable-bin-log  # Pour MySQL (point-in-time recovery)

# ✅ Backups activés !
```

**Explications** :
- `--backup-start-time=03:00` : Backup quotidien à 3h du matin (heure creuse)
- `--backup-location=us` : Région de stockage backups
- `--retained-backups-count=7` : Garde 7 backups (7 jours)
- `--enable-bin-log` : Active binary logs pour MySQL (restore précis)

#### Étape 2 : BACKUP IMMÉDIAT

```bash
# Ne pas attendre le backup automatique !
# Créer backup on-demand immédiatement
gcloud sql backups create \
  --instance=$INSTANCE_NAME \
  --project=$PROJECT_ID \
  --description="Emergency backup - $(date +%Y%m%d)"

# Vérifier backup créé
gcloud sql backups list \
  --instance=$INSTANCE_NAME \
  --project=$PROJECT_ID \
  --limit=1
```

#### Étape 3 : VÉRIFIER CONFIGURATION (< 10 min)

```bash
# Afficher config backup complète
gcloud sql instances describe $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --format="yaml(settings.backupConfiguration)"
```

**Sortie attendue** :
```yaml
settings:
  backupConfiguration:
    backupRetentionSettings:
      retainedBackups: 7
    binaryLogEnabled: true  # MySQL only
    enabled: true
    pointInTimeRecoveryEnabled: true
    startTime: '03:00'
    transactionLogRetentionDays: 7
```

## 📋 Configuration Recommandée

### Production (Critique)

```bash
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --backup-start-time=03:00 \
  --backup-location=us \
  --retained-backups-count=30 \
  --retained-transaction-log-days=7 \
  --enable-bin-log \
  --point-in-time-recovery

# High Availability (si pas déjà activé)
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --availability-type=REGIONAL
```

**Explications** :
- **30 backups** : 1 mois d'historique
- **7 jours de logs** : Point-in-time recovery précis
- **REGIONAL HA** : Failover automatique si zone down

### Staging

```bash
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --backup-start-time=04:00 \
  --retained-backups-count=7 \
  --enable-bin-log
```

### Dev/Test

```bash
gcloud sql instances patch $INSTANCE_NAME \
  --project=$PROJECT_ID \
  --backup-start-time=05:00 \
  --retained-backups-count=3
```

**Note** : Même en dev, TOUJOURS avoir des backups !

## 🔄 Restauration (Disaster Recovery)

### Scénario 1 : Restaurer Dernier Backup

```bash
# Restaurer instance complète depuis dernier backup
gcloud sql backups restore BACKUP_ID \
  --backup-instance=$INSTANCE_NAME \
  --backup-project=$PROJECT_ID \
  --restore-instance=$INSTANCE_NAME

# ⚠️ ATTENTION : Écrase l'instance actuelle !
```

### Scénario 2 : Restaurer vers Nouvelle Instance

**Plus sûr** : Restaurer vers nouvelle instance, vérifier, puis switcher

```bash
# 1. Créer nouvelle instance depuis backup
NEW_INSTANCE="${INSTANCE_NAME}-restored-$(date +%Y%m%d)"

gcloud sql backups restore BACKUP_ID \
  --backup-instance=$INSTANCE_NAME \
  --backup-project=$PROJECT_ID \
  --restore-instance=$NEW_INSTANCE

# 2. Vérifier données
gcloud sql connect $NEW_INSTANCE --user=postgres
# Exécuter requêtes de vérification

# 3. Switcher application vers nouvelle instance
# Update connection strings

# 4. Supprimer ancienne instance (après validation)
gcloud sql instances delete $INSTANCE_NAME --project=$PROJECT_ID
```

### Scénario 3 : Point-in-Time Recovery

**Restaurer à un moment précis** (ex: juste avant bug)

```bash
# Restaurer à 14h30 le 10 novembre
TARGET_TIME="2024-11-10T14:30:00Z"

gcloud sql instances clone $INSTANCE_NAME $NEW_INSTANCE \
  --project=$PROJECT_ID \
  --point-in-time=$TARGET_TIME

# ✅ Clone créé à l'état exact de 14h30
```

**Prérequis** :
- Binary logging activé
- Dans la fenêtre de rétention (7 jours par défaut)

## 📅 Stratégie de Backup Complète

### 3-2-1 Rule (Best Practice)

- **3** copies des données
- **2** types de media différents
- **1** copie off-site (autre région)

### Implémentation GCP

#### 1. Backup Automatique (Daily)

```bash
# Déjà configuré via script ci-dessus
# Backup quotidien, rétention 30 jours
```

#### 2. Export Mensuel (Archivage Long Terme)

```bash
#!/bin/bash
# monthly-export.sh

INSTANCE="postgres-prod"
PROJECT="prod-app"
BUCKET="gs://prod-backups-archive"
DATE=$(date +%Y%m)

# Export SQL vers Cloud Storage
gcloud sql export sql $INSTANCE "$BUCKET/monthly/dump-$DATE.sql" \
  --project=$PROJECT \
  --database=production

# ✅ Archive mensuelle dans GCS
```

**Cron** :
```bash
# 1er du mois à 2h
0 2 1 * * /path/to/monthly-export.sh
```

#### 3. Réplication Cross-Region (Disaster Recovery)

```bash
# Créer read replica dans autre région
gcloud sql instances create $INSTANCE-replica \
  --project=$PROJECT \
  --master-instance-name=$INSTANCE \
  --region=europe-west1  # Région différente

# Si région US down → promouvoir replica EU
gcloud sql instances promote-replica $INSTANCE-replica \
  --project=$PROJECT
```

## 🔍 Testing de Restauration

**CRITICAL** : Tester vos backups régulièrement !

### Test Mensuel (Recommandé)

```bash
#!/bin/bash
# test-restore.sh

INSTANCE="postgres-prod"
PROJECT="prod-app"
TEST_INSTANCE="restore-test-$(date +%Y%m%d)"

echo "=== Test de Restauration ==="

# 1. Obtenir dernier backup
LAST_BACKUP=$(gcloud sql backups list \
  --instance=$INSTANCE \
  --project=$PROJECT \
  --limit=1 \
  --format="value(id)")

echo "Backup ID: $LAST_BACKUP"

# 2. Restaurer vers instance test
gcloud sql backups restore $LAST_BACKUP \
  --backup-instance=$INSTANCE \
  --backup-project=$PROJECT \
  --restore-instance=$TEST_INSTANCE

# 3. Vérifier connectivité
gcloud sql connect $TEST_INSTANCE --user=postgres --quiet <<EOF
SELECT 'Backup OK' AS status, COUNT(*) as tables
FROM information_schema.tables
WHERE table_schema = 'public';
\q
EOF

# 4. Cleanup
gcloud sql instances delete $TEST_INSTANCE --project=$PROJECT --quiet

echo "✅ Test de restauration réussi"
```

**Planification** :
```bash
# 1er lundi du mois à 10h
0 10 1-7 * 1 /path/to/test-restore.sh | mail -s "GCP: Test Backup" ops@company.com
```

## 📊 Monitoring & Alerting

### Alertes Critiques

```bash
# Alerte si backup échoue
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Cloud SQL Backup Failed" \
  --condition-display-name="Backup Error" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=60s \
  --condition-filter='resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/backup/count" AND metric.label.state="FAILED"'
```

### Dashboard Monitoring

Métriques à suivre :

1. **Backup Success Rate** : 100% attendu
2. **Last Backup Time** : < 24h
3. **Backup Size** : Tendance (détecte corruption si chute soudaine)
4. **Restore Time** : Combien de temps pour restaurer ?

## 🛡️ Best Practices

### ✅ À FAIRE

1. **Backups activés** : 100% des instances, même dev
2. **Rétention appropriée** :
   - Prod : 30 jours minimum
   - Staging : 7 jours
   - Dev : 3 jours
3. **Binary logging** : Activé (point-in-time recovery)
4. **Cross-region** : Replica dans autre région (prod)
5. **Tests réguliers** : Restore test mensuel
6. **Monitoring** : Alertes backup failed
7. **Documentation** : Procédure DR écrite et testée
8. **Off-site** : Export mensuel vers GCS

### ❌ À ÉVITER

1. ❌ Instances sans backup (JAMAIS)
2. ❌ Backups jamais testés
3. ❌ Rétention trop courte (< 7 jours prod)
4. ❌ Tous backups dans même région
5. ❌ Pas de binary logs (MySQL/PostgreSQL)
6. ❌ Fenêtre backup en heures de pointe
7. ❌ Pas d'alerting sur échec backup

## 🔍 Troubleshooting

### Backup échoue systématiquement

**Causes** :

1. **Disk full** : Pas assez d'espace
   ```bash
   # Vérifier stockage
   gcloud sql instances describe $INSTANCE --format="value(settings.dataDiskSizeGb)"

   # Augmenter
   gcloud sql instances patch $INSTANCE --storage-size=200
   ```

2. **Longues transactions** : Backup ne peut pas compléter
   ```sql
   -- Identifier transactions longues
   SELECT pid, now() - pg_stat_activity.query_start AS duration, query
   FROM pg_stat_activity
   WHERE state != 'idle'
   ORDER BY duration DESC;
   ```

### Restore très long (> 2h)

**Causes** :
- Base de données trop grosse
- Réseau lent

**Solutions** :
```bash
# Export/Import plus rapide (compressed)
gcloud sql export sql $INSTANCE gs://bucket/dump.sql.gz \
  --gzip

# Utiliser plus de ressources pour instance de restore
gcloud sql instances create $NEW_INSTANCE \
  --tier=db-n1-standard-8  # Temporairement plus gros
```

### Point-in-time recovery échoue

**Causes** :
- Binary logging pas activé
- En dehors de la fenêtre de rétention

**Solution** :
```bash
# Vérifier config
gcloud sql instances describe $INSTANCE \
  --format="value(settings.backupConfiguration.binaryLogEnabled)"

# Doit afficher: true
```

## 📚 Ressources

- [Cloud SQL Backups](https://cloud.google.com/sql/docs/mysql/backup-recovery/backups)
- [Point-in-Time Recovery](https://cloud.google.com/sql/docs/mysql/backup-recovery/pitr)
- [High Availability](https://cloud.google.com/sql/docs/mysql/high-availability)
- [Disaster Recovery Planning](https://cloud.google.com/architecture/dr-scenarios-planning-guide)

## 🎯 Checklist DR (Disaster Recovery)

- [ ] Backups activés sur 100% instances
- [ ] Rétention >= 30 jours (prod)
- [ ] Binary logging activé
- [ ] Point-in-time recovery activé
- [ ] HA (REGIONAL) sur instances critiques
- [ ] Cross-region replica (instances critiques)
- [ ] Export mensuel vers GCS
- [ ] Test restore mensuel documenté
- [ ] Alerting backup failures configuré
- [ ] RTO/RPO définis et documentés
  - **RTO** (Recovery Time Objective) : Combien de temps max downtime ? Ex: 4h
  - **RPO** (Recovery Point Objective) : Combien de données max perdues ? Ex: 1h
- [ ] Runbook incident documenté
- [ ] Équipe formée (drill annuel)

---

[⬅️ VM Rightsizing](Compare-VM-Rightsizing.md) | [🏠 Wiki](../HOME.md) | [➡️ List Cloud SQL](List-Cloud-SQL-Instances.md)
