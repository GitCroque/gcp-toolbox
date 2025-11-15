# 🚀 Quick Start - Premiers Pas

Démarrez avec Carnet en moins de 5 minutes !

## ⚡ Installation Express

```bash
# 1. Cloner le repository
git clone https://github.com/VOTRE-USERNAME/carnet.git
cd carnet

# 2. Vérifier gcloud
gcloud version

# 3. S'authentifier
gcloud auth login

# 4. Lancer votre premier script
./scripts/list-gcp-projects.sh
```

## 📋 Votre Premier Audit

### 1. Vérifier vos projets

```bash
./scripts/list-gcp-projects.sh
```

**Ce script affiche**:
- Tous vos projets GCP
- Dates de création
- Propriétaires

### 2. Scanner la sécurité (IMPORTANT !)

```bash
# Trouver les buckets publics
./scripts/scan-public-buckets.sh

# Auditer les clés de service accounts
./scripts/audit-service-account-keys.sh
```

**Si vous voyez des alertes rouges** : Agissez immédiatement !

### 3. Inventorier vos VMs

```bash
./scripts/list-all-vms.sh
```

**Vous obtenez**:
- Liste de toutes les VMs
- États (running/stopped)
- Coûts estimés mensuels

### 4. Trouver des économies

```bash
./scripts/find-unused-resources.sh
```

**Détecte**:
- VMs arrêtées depuis longtemps
- Disques non attachés
- IPs statiques inutilisées (7$/mois chacune !)

## 💾 Export JSON pour Analyse

Tous les scripts supportent `--json` :

```bash
# Export projets
./scripts/list-gcp-projects-json.sh > projets.json

# Export VMs
./scripts/list-all-vms.sh --json > vms.json

# Analyser avec jq
cat vms.json | jq '.summary'
```

## 🔄 Automatisation Simple

### Cron Job pour Audit Quotidien

```bash
# Éditer crontab
crontab -e

# Ajouter (exécution tous les jours à 9h)
0 9 * * * /path/to/carnet/scripts/scan-public-buckets.sh >> /var/log/gcp-audit.log 2>&1
0 9 * * * /path/to/carnet/scripts/audit-service-account-keys.sh >> /var/log/gcp-audit.log 2>&1
```

### Script de Rapport Hebdomadaire

Créez `weekly-report.sh`:

```bash
#!/bin/bash
REPORT_DIR="/path/to/reports"
DATE=$(date +%Y%m%d)

cd /path/to/carnet

# Génère les rapports
./scripts/list-all-vms.sh > "$REPORT_DIR/vms-$DATE.txt"
./scripts/list-projects-with-billing.sh > "$REPORT_DIR/billing-$DATE.txt"
./scripts/find-unused-resources.sh --days 7 > "$REPORT_DIR/cleanup-$DATE.txt"

# Envoi par email (optionnel)
cat "$REPORT_DIR/cleanup-$DATE.txt" | mail -s "GCP Weekly Report" admin@example.com
```

## 🎯 Workflows par Besoin

### Je veux sécuriser ma plateforme

```bash
# Audit complet sécurité
./scripts/scan-public-buckets.sh
./scripts/audit-service-account-keys.sh
./scripts/audit-iam-permissions.sh --role roles/owner
```

### Je veux réduire mes coûts

```bash
# Analyse optimisation coûts
./scripts/find-unused-resources.sh
./scripts/compare-vm-rightsizing.sh
./scripts/check-preemptible-candidates.sh
./scripts/analyze-committed-use.sh
```

### Je veux un inventaire complet

```bash
# Inventaire infrastructure
./scripts/list-all-vms.sh
./scripts/list-cloud-sql-instances.sh
./scripts/list-gke-clusters.sh
./scripts/audit-container-images.sh
```

## 🔍 Interpréter les Résultats

### Codes Couleur

- 🟢 **Vert** : OK, aucune action requise
- 🟡 **Jaune** : Attention, à surveiller
- 🔴 **Rouge** : CRITIQUE, action immédiate requise

### Priorités d'Action

**1. CRITIQUE (Agir aujourd'hui)**
- Buckets publics détectés
- Clés de service account > 365 jours
- Bases de données sans backup

**2. IMPORTANT (Agir cette semaine)**
- Quotas > 90%
- Clés > 180 jours
- Ressources inutilisées coûteuses

**3. RECOMMANDÉ (Planifier)**
- Optimisation rightsizing
- Migration vers spot VMs
- Nettoyage images containers

## ❓ Problèmes Courants

### "gcloud: command not found"

```bash
# macOS
brew install --cask google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
```

### "Permission denied"

Vous n'avez pas les permissions GCP nécessaires.

```bash
# Vérifier vos rôles
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$(gcloud config get-value account)"
```

Demandez à votre admin GCP les rôles:
- **Viewer** (minimum)
- **Security Reviewer** (pour audits IAM)
- **Billing Viewer** (pour coûts)

### Script lent

Normal si vous avez beaucoup de projets/ressources.

**Solutions**:
```bash
# Cibler un seul projet
./scripts/SCRIPT.sh --project mon-projet

# Exécuter hors heures de pointe
```

## 📚 Étapes Suivantes

1. ✅ Vous avez fait votre premier audit
2. 📖 Consultez les [Workflows Recommandés](Workflows.md)
3. 🔄 Configurez l'[Automation](Automation.md)
4. 🎓 Lisez les [Best Practices](Best-Practices.md)

## 💬 Besoin d'Aide ?

- [FAQ complète](FAQ.md)
- [Guide de troubleshooting](Troubleshooting.md)
- [Ouvrir une issue](https://github.com/VOTRE-REPO/issues)

---

[⬅️ Retour au Wiki](HOME.md) | [➡️ Workflows Recommandés](Workflows.md)
