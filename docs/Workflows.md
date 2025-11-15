# 🔄 Workflows Recommandés

Workflows éprouvés pour différents besoins et profils.

## 📅 Workflow Quotidien (DevOps/SRE)

**Temps**: 5-10 minutes
**Objectif**: Sécurité et disponibilité

```bash
#!/bin/bash
# daily-check.sh

echo "=== Audit Quotidien GCP ==="
date

# 1. Sécurité critique
echo "\n🔐 Scan sécurité..."
./scripts/scan-public-buckets.sh
./scripts/audit-service-account-keys.sh --days 90

# 2. Backups
echo "\n💾 Vérification backups..."
./scripts/audit-database-backups.sh

# 3. Quotas
echo "\n📊 Check quotas..."
./scripts/check-quotas.sh --threshold 80

# Alerter si problèmes
echo "\n✅ Audit terminé"
```

**Automatisation**:
```bash
# Crontab: tous les jours à 8h
0 8 * * * /path/to/daily-check.sh | mail -s "GCP Daily Check" devops@company.com
```

## 📆 Workflow Hebdomadaire (Security Team)

**Temps**: 20-30 minutes
**Objectif**: Audit de sécurité complet

```bash
#!/bin/bash
# weekly-security-audit.sh

REPORT_DIR="./security-reports"
DATE=$(date +%Y%m%d)
mkdir -p "$REPORT_DIR"

echo "=== Audit Sécurité Hebdomadaire ==="

# 1. Clés de service accounts
echo "1/4 Audit clés SA..."
./scripts/audit-service-account-keys.sh --json > "$REPORT_DIR/sa-keys-$DATE.json"

# 2. Buckets publics
echo "2/4 Scan buckets..."
./scripts/scan-public-buckets.sh --json > "$REPORT_DIR/public-buckets-$DATE.json"

# 3. Permissions IAM
echo "3/4 Audit IAM..."
./scripts/audit-iam-permissions.sh --json > "$REPORT_DIR/iam-$DATE.json"

# 4. Bases de données
echo "4/4 Check Cloud SQL..."
./scripts/list-cloud-sql-instances.sh --json > "$REPORT_DIR/cloudsql-$DATE.json"

# Analyse avec jq
echo "\n📊 Analyse..."
echo "Clés critiques: $(cat $REPORT_DIR/sa-keys-$DATE.json | jq '.summary.critical_risk')"
echo "Buckets publics: $(cat $REPORT_DIR/public-buckets-$DATE.json | jq '.summary.public_buckets')"
echo "Owners total: $(cat $REPORT_DIR/iam-$DATE.json | jq '.summary.owner_count')"

echo "\n✅ Rapport sauvegardé dans $REPORT_DIR"
```

## 📊 Workflow Mensuel (FinOps)

**Temps**: 1-2 heures
**Objectif**: Optimisation des coûts

### Phase 1: Analyse (Semaine 1)

```bash
#!/bin/bash
# monthly-cost-analysis.sh

echo "=== Analyse Coûts Mensuelle ==="

# 1. Inventaire complet
./scripts/list-all-vms.sh --json > inventory-vms.json
./scripts/list-cloud-sql-instances.sh --json > inventory-sql.json
./scripts/list-gke-clusters.sh --json > inventory-gke.json

# 2. Détection gaspillage
./scripts/find-unused-resources.sh --days 30 --json > waste.json
./scripts/audit-container-images.sh --days 90 --json > old-images.json

# 3. Opportunités d'optimisation
./scripts/compare-vm-rightsizing.sh --days 30 --json > rightsizing.json
./scripts/check-preemptible-candidates.sh --json > spot-candidates.json
./scripts/analyze-committed-use.sh --json > cud-analysis.json

# 4. Anomalies
./scripts/track-cost-anomalies.sh --threshold 20 --json > anomalies.json

# Résumé
echo "\n💰 RÉSUMÉ ÉCONOMIES POTENTIELLES:"
echo "VMs unused: \$$(cat waste.json | jq '.summary.total_unused_ips * 7') (IPs statiques)"
echo "Rightsizing: \$$(cat rightsizing.json | jq '.summary.potential_monthly_savings_usd')"
echo "Spot VMs: \$$(cat spot-candidates.json | jq '.summary.potential_monthly_savings')"
echo "Images cleanup: \$$(cat old-images.json | jq '.summary.total_size_gb / 10')"
```

### Phase 2: Action (Semaine 2-3)

Créer des tickets pour chaque optimisation:

```markdown
## Ticket: Cleanup IPs Statiques Inutilisées

**Impact**: $210/mois économisés
**Effort**: 1h
**Risque**: Faible

**Actions**:
1. Vérifier avec teams que IPs non utilisées
2. Libérer via: `gcloud compute addresses delete IP_NAME --region=REGION`
3. Vérifier pas d'impact
```

### Phase 3: Reporting (Semaine 4)

```bash
# Génère un rapport exécutif
cat > executive-report.md << EOF
# Rapport Optimisation Coûts - $(date +"%B %Y")

## 📊 Métriques

- **Coûts actuels estimés**: \$XX,XXX/mois
- **Économies identifiées**: \$X,XXX/mois (XX%)
- **Économies réalisées**: \$XXX/mois

## 🎯 Actions Réalisées

1. ✅ Suppression 15 IPs statiques inutilisées (-\$105/mois)
2. ✅ Rightsizing 8 VMs sur-provisionnées (-\$400/mois)
3. ✅ Migration 12 VMs vers Spot (-\$1,200/mois)
4. ⏳ CUD 1 an en cours d'approbation (-\$3,500/mois estimé)

## 📈 Tendances

- Croissance coûts: +15% vs mois dernier
- Principale cause: Nouveau cluster GKE (data-analytics)
- Action: Monitorer de près

## 🎯 Prochaines Étapes

1. Finaliser CUD
2. Auditer containers images
3. Évaluer Cloud Run vs GKE pour microservices
EOF
```

## 🚨 Workflow Incident (Data Leak)

**Si `scan-public-buckets.sh` trouve des buckets publics:**

### Réponse Immédiate (< 1h)

```bash
# 1. Identifier le bucket
BUCKET_NAME="bucket-public-detecte"

# 2. Vérifier le contenu
gsutil ls -r gs://$BUCKET_NAME | head -20

# 3. Retirer accès public IMMÉDIATEMENT
gsutil iam ch -d allUsers gs://$BUCKET_NAME
gsutil iam ch -d allAuthenticatedUsers gs://$BUCKET_NAME

# 4. Vérifier
gsutil iam get gs://$BUCKET_NAME | grep -i "allUsers\|allAuthenticatedUsers"

# Si vide: OK, accès public retiré
```

### Investigation (< 4h)

```bash
# 5. Qui a rendu ce bucket public ?
gcloud logging read "resource.type=gcs_bucket AND \
  resource.labels.bucket_name=$BUCKET_NAME AND \
  protoPayload.methodName=storage.setIamPermissions" \
  --limit=50 --format=json

# 6. Quand ?
# Regarder les timestamps dans les logs

# 7. Quoi est exposé ?
gsutil ls -L gs://$BUCKET_NAME > bucket-inventory.txt

# 8. Qui a accédé aux données ?
# Logs d'accès (si activés)
gsutil logging get gs://$BUCKET_NAME
```

### Post-Mortem (< 24h)

1. **Documenter** l'incident
2. **Notifier** CISO / DPO si données sensibles
3. **Corriger** processus (IAM policy, alerting)
4. **Tester** détection (refaire l'incident en dev)

## 📈 Workflow Scaling Event

**Avant un événement majeur (Black Friday, lancement produit):**

### Préparation (J-7)

```bash
# 1. Check quotas actuels
./scripts/check-quotas.sh --threshold 60

# 2. Calculer besoins
# Trafic attendu: 10x normal
# Donc: demander quotas * 10

# 3. Demander augmentations
# IAM & Admin > Quotas dans Console GCP
# Délai: 2-5 jours ouvrés

# 4. Vérifier backup/DR
./scripts/audit-database-backups.sh
```

### Pendant l'événement (J)

```bash
# Monitoring continu
watch -n 300 './scripts/check-quotas.sh --threshold 70'

# Si quota critique (>90%):
# - Scaler horizontalement si possible
# - Demander augmentation urgente
```

### Post-événement (J+1)

```bash
# 1. Analyse coûts
./scripts/track-cost-anomalies.sh

# 2. Rightsizing
./scripts/compare-vm-rightsizing.sh

# 3. Cleanup
./scripts/find-unused-resources.sh --days 1
```

## 🔄 Workflow CI/CD Integration

### GitLab CI Example

```yaml
# .gitlab-ci.yml
gcp-audit:
  stage: audit
  image: google/cloud-sdk:alpine
  script:
    - gcloud auth activate-service-account --key-file=$GCP_SA_KEY
    - cd carnet
    - ./scripts/scan-public-buckets.sh --json > buckets.json
    - ./scripts/audit-service-account-keys.sh --json > sa-keys.json
    - |
      if [ $(cat buckets.json | jq '.summary.public_buckets') -gt 0 ]; then
        echo "❌ ÉCHEC: Buckets publics détectés!"
        exit 1
      fi
    - |
      if [ $(cat sa-keys.json | jq '.summary.critical_risk') -gt 0 ]; then
        echo "⚠️ WARNING: Clés critiques détectées"
      fi
  artifacts:
    reports:
      junit: audit-report.xml
    paths:
      - buckets.json
      - sa-keys.json
  only:
    - schedules
```

### GitHub Actions Example

```yaml
# .github/workflows/gcp-audit.yml
name: GCP Security Audit
on:
  schedule:
    - cron: '0 8 * * 1' # Lundi 8h
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: google-github-actions/setup-gcloud@v1
        with:
          service_account_key: ${{ secrets.GCP_SA_KEY }}

      - name: Security Scan
        run: |
          chmod +x scripts/*.sh
          ./scripts/scan-public-buckets.sh
          ./scripts/audit-service-account-keys.sh

      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: audit-results
          path: '*.json'
```

## 📱 Workflow Alerting (Slack)

```bash
#!/bin/bash
# slack-alert.sh

WEBHOOK_URL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Exécute audit
PUBLIC_BUCKETS=$(./scripts/scan-public-buckets.sh --json | jq '.summary.public_buckets')

if [ "$PUBLIC_BUCKETS" -gt 0 ]; then
    curl -X POST $WEBHOOK_URL -H 'Content-type: application/json' -d '{
      "text": "🚨 ALERTE GCP SÉCURITÉ",
      "attachments": [{
        "color": "danger",
        "fields": [{
          "title": "Buckets Publics Détectés",
          "value": "'"$PUBLIC_BUCKETS"' bucket(s) sont publiquement accessibles",
          "short": false
        }]
      }]
    }'
fi
```

## 💡 Tips & Astuces

### Combiner plusieurs scripts

```bash
# Audit complet en une commande
for script in audit-service-account-keys scan-public-buckets check-quotas; do
    echo "Running $script..."
    ./scripts/$script.sh
done
```

### Filtrer avec jq

```bash
# Projets de production uniquement
./scripts/list-gcp-projects-json.sh | jq '.projects[] | select(.name | contains("prod"))'

# VMs coûteuses (>100$/mois)
./scripts/list-all-vms.sh --json | jq '.vms[] | select(.estimated_monthly_cost_usd > 100)'
```

### Comparaisons temporelles

```bash
# Sauvegarder snapshot
./scripts/list-all-vms.sh --json > vms-$(date +%Y%m%d).json

# 30 jours plus tard, comparer
diff <(jq '.summary' vms-20241101.json) <(jq '.summary' vms-20241201.json)
```

---

[⬅️ Quick Start](Quick-Start.md) | [🏠 Wiki Home](HOME.md) | [➡️ Automation](Automation.md)
