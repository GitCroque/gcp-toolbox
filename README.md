# 🔧 GCP Toolbox

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![GCP](https://img.shields.io/badge/Cloud-Google%20Cloud-4285F4.svg)](https://cloud.google.com/)
[![Scripts](https://img.shields.io/badge/Scripts-27-brightgreen.svg)]()
[![Documentation](https://img.shields.io/badge/Docs-Wiki-blue.svg)](https://github.com/GitCroque/gcp-toolbox/wiki)

**Collection de 27 scripts Bash pour auditer, sécuriser et optimiser Google Cloud Platform.**

---

## 🎯 À quoi sert ce dépôt ?

Ce dépôt contient des **scripts shell pratiques** pour gérer votre infrastructure Google Cloud Platform :

- 🔐 **Sécurité** : détecter les buckets publics, clés anciennes, règles firewall dangereuses
- 💰 **Optimisation des coûts** : identifier les ressources inutilisées, opportunités de rightsizing
- 📦 **Inventaire** : lister VMs, bases de données, clusters Kubernetes
- 🏛️ **Gouvernance** : vérifier les labels, contacter les propriétaires de projets

**Philosophie** : exécution manuelle sur demande, vous gardez le contrôle total.

---

## 🚀 Installation rapide

```bash
# 1. Cloner le dépôt
git clone https://github.com/GitCroque/gcp-toolbox.git
cd gcp-toolbox

# 2. Configuration initiale
make setup

# 3. Authentification GCP
gcloud auth login

# 4. Lancer votre premier audit
./scripts/scan-public-buckets.sh
./scripts/list-all-vms.sh
```

---

## 📊 Scripts principaux

### 🔴 Sécurité critique

```bash
./scripts/scan-public-buckets.sh           # Buckets exposés publiquement
./scripts/audit-firewall-rules.sh          # Règles firewall dangereuses
./scripts/audit-service-account-keys.sh    # Clés anciennes (>365 jours)
./scripts/audit-database-backups.sh        # Backups Cloud SQL manquants
```

### 💰 Optimisation des coûts

```bash
./scripts/find-unused-resources.sh         # Ressources inutilisées
./scripts/compare-vm-rightsizing.sh        # Opportunités de rightsizing
./scripts/check-preemptible-candidates.sh  # Migration vers Spot VMs
```

### 📦 Inventaire

```bash
./scripts/list-all-vms.sh                  # Toutes les VMs + coûts
./scripts/list-cloud-sql-instances.sh      # Bases de données
./scripts/list-gke-clusters.sh             # Clusters Kubernetes
./scripts/list-gcp-projects.sh             # Tous les projets
```

### 🛠️ Commandes Makefile

```bash
make help          # Liste toutes les commandes
make security      # Audits sécurité
make costs         # Analyse coûts
make inventory     # Inventaire complet
```

---

## 📁 Structure du dépôt

```
gcp-toolbox/
├── scripts/           # 27 scripts Bash
│   ├── lib/          # Bibliothèque commune
│   └── *.sh          # Scripts individuels
├── config/           # Configuration (prix GCP)
├── archives/         # CI/CD optionnels
├── Makefile          # Commandes rapides
├── LICENSE           # MIT License
└── README.md         # Ce fichier
```

---

## 📚 Documentation complète

Toute la documentation est disponible sur le **[Wiki GitHub](https://github.com/GitCroque/gcp-toolbox/wiki)** :

- 🚀 [Quick Start](https://github.com/GitCroque/gcp-toolbox/wiki/Quick-Start)
- 📖 [Guide complet](https://github.com/GitCroque/gcp-toolbox/wiki/Home)
- 🔄 [Workflows recommandés](https://github.com/GitCroque/gcp-toolbox/wiki/Workflows)
- ❓ [FAQ](https://github.com/GitCroque/gcp-toolbox/wiki/FAQ)
- 📊 [Rapports d'audit technique](https://github.com/GitCroque/gcp-toolbox/wiki/AUDIT_REPORT)

---

## 🤝 Contribution

Les contributions sont bienvenues ! Consultez le [guide de contribution](https://github.com/GitCroque/gcp-toolbox/wiki/CONTRIBUTING) sur le wiki.

---

## 📝 Licence

MIT License - Voir [LICENSE](LICENSE)

---

## 📞 Support

- 📖 [Documentation](https://github.com/GitCroque/gcp-toolbox/wiki)
- 🐛 [Issues](https://github.com/GitCroque/gcp-toolbox/issues)
- 💬 [Discussions](https://github.com/GitCroque/gcp-toolbox/discussions)

---

**Développé avec ❤️ pour les équipes GCP qui veulent garder le contrôle**
