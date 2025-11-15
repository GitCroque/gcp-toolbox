# ⚡ Carnet - Scripts GCP

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![GCP](https://img.shields.io/badge/Cloud-Google%20Cloud-4285F4.svg)](https://cloud.google.com/)

**Collection de 23+ scripts Bash pour auditer, sécuriser et optimiser votre plateforme Google Cloud.**

```bash
# Quick Start - Audit complet en une commande !
git clone https://github.com/GitCroque/carnet.git
cd carnet
./scripts/setup-carnet.sh        # Vérification prérequis
./scripts/run-full-audit.sh      # Audit complet de votre plateforme
```

## 🎯 Que fait Carnet ?

| Catégorie | Scripts | Bénéfices |
|-----------|---------|-----------|
| 🔐 **Cybersécurité** | 6 scripts | Firewall, buckets publics, clés anciennes, services exposés, backups |
| 🏛️ **Gouvernance** | 6 scripts | Projets inactifs, labels, propriétaires, inventaire, reporting |
| 💰 **Optimisation Coûts** | 6 scripts | Rightsizing, cleanup, Spot VMs, CUDs, anomalies |
| 📦 **Inventaire** | 5 scripts | VMs, SQL, GKE, projets, containers |

**Économies potentielles** : 30-50% de vos coûts cloud 💰

**Risques détectés** : Data leaks, clés compromises, backups manquants ⚠️

## 🚀 Installation (< 2 min)

### Prérequis

- ✅ macOS, Linux, ou WSL (Windows)
- ✅ [gcloud CLI](https://cloud.google.com/sdk/docs/install) installé
- ✅ Authentifié : `gcloud auth login`
- ✅ Permissions GCP : Viewer + Security Reviewer + Billing Viewer

### Lancement

```bash
# Cloner
git clone https://github.com/VOTRE-USERNAME/carnet.git
cd carnet

# Tester
./scripts/scan-public-buckets.sh        # Trouve buckets publics
./scripts/list-all-vms.sh               # Inventaire VMs + coûts
./scripts/find-unused-resources.sh      # Ressources inutilisées
```

## 📊 Scripts Disponibles

### 🚀 AUDIT COMPLET (NOUVEAU !)

```bash
./scripts/setup-carnet.sh           # ✨ Vérification prérequis & setup initial
./scripts/run-full-audit.sh         # ✨ Exécute TOUS les audits en une commande
```

### 🔴 PRIORITÉ CRITIQUE (Cybersécurité)

```bash
./scripts/scan-public-buckets.sh           # Buckets exposés publiquement
./scripts/audit-firewall-rules.sh          # ✨ Règles firewall dangereuses (0.0.0.0/0)
./scripts/scan-exposed-services.sh         # ✨ VMs avec IP publiques
./scripts/audit-service-account-keys.sh    # Clés anciennes (>365 jours)
./scripts/audit-database-backups.sh        # Backups Cloud SQL manquants
```

### 🏛️ GOUVERNANCE & GESTION

```bash
./scripts/notify-project-owners.sh         # ✨ Contact propriétaires (review annuel)
./scripts/cleanup-old-projects.sh          # ✨ Projets inactifs à supprimer
./scripts/audit-resource-labels.sh         # ✨ Vérification labels (cost tracking)
./scripts/generate-inventory-report.sh     # ✨ Rapport complet (Markdown/JSON)
```

### 💎 TOP ÉCONOMIES (FinOps)

```bash
./scripts/compare-vm-rightsizing.sh        # Rightsizing (15-30% économies)
./scripts/check-preemptible-candidates.sh  # Migration Spot (jusqu'à 91%)
./scripts/analyze-committed-use.sh         # CUDs (25-57% économies)
./scripts/find-unused-resources.sh         # Cleanup (5-15% économies)
./scripts/track-cost-anomalies.sh          # Détection pics de coûts
```

### 📦 INVENTAIRE COMPLET

```bash
./scripts/list-gcp-projects.sh             # Tous les projets
./scripts/list-all-vms.sh                  # Toutes les VMs + coûts
./scripts/list-cloud-sql-instances.sh      # Bases de données
./scripts/list-gke-clusters.sh             # Clusters Kubernetes
./scripts/audit-container-images.sh        # Images containers
```

### 🔍 MONITORING & AUDIT

```bash
./scripts/check-quotas.sh                  # Utilisation des quotas
./scripts/audit-iam-permissions.sh         # Qui a accès à quoi
./scripts/list-projects-with-billing.sh    # Statut facturation
```

## 📚 Documentation Complète

👉 **[WIKI COMPLET](docs/HOME.md)** - Tout ce que vous devez savoir !

- 🚀 [Quick Start (5 min)](docs/Quick-Start.md) - Votre premier audit
- 🔄 [Workflows](docs/Workflows.md) - Quotidien, hebdomadaire, mensuel
- ❓ [FAQ](docs/FAQ.md) - Questions fréquentes
- 🤝 [Contributing](CONTRIBUTING.md) - Guide de contribution

## ⚡ Exemples d'Utilisation

### 🔍 Audit Complet en Une Commande (10 min)

```bash
# Nouveau ! Exécute TOUS les audits critiques
./scripts/run-full-audit.sh --output-dir ./audit-results

# Avec notifications Slack
./scripts/run-full-audit.sh --slack-webhook https://hooks.slack.com/...

# Seulement alertes critiques
./scripts/run-full-audit.sh --critical-only
```

### Audit Sécurité Quotidien (5 min)

```bash
./scripts/scan-public-buckets.sh
./scripts/audit-firewall-rules.sh
./scripts/audit-service-account-keys.sh --days 90
```

### Rapport Mensuel Coûts (15 min)

```bash
# Analyse
./scripts/list-all-vms.sh > rapport-vms.txt
./scripts/find-unused-resources.sh --days 30 > cleanup.txt
./scripts/compare-vm-rightsizing.sh > rightsizing.txt

# Économies potentielles affichées dans les résumés !
```

### Export JSON pour Automatisation

```bash
# Tous les scripts supportent --json
./scripts/list-all-vms.sh --json > vms.json
./scripts/audit-iam-permissions.sh --json > iam.json

# Analyse avec jq
cat vms.json | jq '.summary.estimated_monthly_cost_usd'
```

## 🔧 Automatisation

### Cron (Audit quotidien)

```bash
# Ajouter à crontab -e
0 8 * * * /path/to/carnet/scripts/scan-public-buckets.sh >> /var/log/gcp-audit.log
```

### CI/CD (GitHub Actions, GitLab CI)

**GitHub Actions** - Prêt à l'emploi !

```yaml
# .github/workflows/gcp-security-audit.yml déjà inclus !
# Audit quotidien automatique + notifications
```

**GitLab CI** - Prêt à l'emploi !

```yaml
# .gitlab-ci.yml déjà inclus !
# Pipelines sécurité et coûts
```

Voir [docs/Workflows.md](docs/Workflows.md) pour configuration complète.

## 💡 ROI Typique

**Entreprise moyenne (100 VMs, 20 DBs)**:
- **Temps d'installation**: 30 min
- **Temps audit initial**: 1h
- **Économies identifiées**: $3,000-5,000/mois
- **ROI**: ∞ (scripts gratuits !) 🎉

## 🤝 Contribution

Les contributions sont les bienvenues !

1. Fork le repo
2. Créez votre branche : `git checkout -b feature/nouveau-script`
3. Développez en suivant les [standards](CONTRIBUTING.md)
4. Ouvrez une Pull Request

**Idées de scripts** : Cloud SQL, Cloud Run, Firestore, VPC, DNS, etc.

## 📝 Licence

MIT License - Utilisez librement dans vos projets commerciaux !

## ⭐ Support

- 📖 [Documentation Complète](docs/HOME.md)
- 🐛 [Rapporter un Bug](../../issues)
- 💡 [Demander une Fonctionnalité](../../issues)
- 💬 [Discussions](../../discussions)

## 🙏 Remerciements

Merci à tous les contributeurs ! Si Carnet vous aide à économiser de l'argent ou à sécuriser votre plateforme, n'hésitez pas à ⭐ starred le repo !

---

**Développé avec ❤️ pour la communauté GCP** | [📚 Wiki Complet](docs/HOME.md)
