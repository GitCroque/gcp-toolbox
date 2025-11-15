# ⚡ Carnet - Scripts GCP

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![GCP](https://img.shields.io/badge/Cloud-Google%20Cloud-4285F4.svg)](https://cloud.google.com/)

**Collection de 17 scripts Bash pour auditer, sécuriser et optimiser votre plateforme Google Cloud.**

```bash
# Quick Start
git clone https://github.com/VOTRE-USERNAME/carnet.git
cd carnet
./scripts/list-gcp-projects.sh
```

## 🎯 Que fait Carnet ?

| Catégorie | Scripts | Bénéfices |
|-----------|---------|-----------|
| 🔐 **Sécurité** | 3 scripts | Détecte buckets publics, clés anciennes, permissions risquées |
| 💾 **Bases de Données** | 2 scripts | Inventaire SQL, vérification backups |
| ☁️ **Infrastructure** | 4 scripts | VMs, GKE, projets, ressources non utilisées |
| 💰 **Optimisation Coûts** | 5 scripts | Rightsizing, Spot VMs, CUDs, images, anomalies |
| 🔍 **Monitoring** | 2 scripts | Quotas, facturation |

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

### 🔴 PRIORITÉ CRITIQUE (Sécurité)

```bash
./scripts/audit-service-account-keys.sh    # Détecte clés anciennes/jamais utilisées
./scripts/scan-public-buckets.sh           # Trouve buckets exposés publiquement
./scripts/audit-database-backups.sh        # Vérifie backups Cloud SQL
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

### Audit Sécurité Quotidien (5 min)

```bash
./scripts/scan-public-buckets.sh
./scripts/audit-service-account-keys.sh --days 90
./scripts/check-quotas.sh
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

Voir [docs/Automation.md](docs/Automation.md) pour exemples complets.

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
