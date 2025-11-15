# Carnet - Scripts de Gestion GCP

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![GCP](https://img.shields.io/badge/Cloud-Google%20Cloud-4285F4.svg)](https://cloud.google.com/)

Collection de scripts Bash pour la gestion, l'audit et l'optimisation de plateformes Google Cloud Platform (GCP).

## 📋 À propos

**Carnet** est un ensemble de scripts shell qui vous aide à :

- **Inventorier** vos ressources GCP (projets, VMs, disques, IPs)
- **Auditer** vos permissions IAM et votre sécurité
- **Optimiser** vos coûts en détectant les ressources inutilisées
- **Surveiller** vos quotas pour éviter les dépassements
- **Automatiser** vos rapports et exports grâce au support JSON

Tous les scripts sont conçus pour être **simples, sécurisés et réutilisables** dans vos workflows CI/CD ou vos tâches cron.

## 🎯 Pour qui ?

- **DevOps / SREs** : Automatisation des audits et rapports
- **FinOps Teams** : Optimisation des coûts cloud
- **Cloud Architects** : Inventaire et conformité
- **Security Teams** : Audits IAM réguliers
- **Managers IT** : Rapports de gestion et visibilité

## 🚀 Démarrage Rapide

```bash
# 1. Cloner le repository
git clone https://github.com/VOTRE-USERNAME/carnet.git
cd carnet

# 2. Rendre les scripts exécutables (si nécessaire)
chmod +x scripts/*.sh

# 3. Lancer votre premier script
./scripts/list-gcp-projects.sh
```

## 📦 Prérequis

### Environnement

- **OS** : macOS, Linux, ou WSL (Windows Subsystem for Linux)
- **Shell** : Bash 4.0+
- **gcloud CLI** : Version récente recommandée

### Installation de gcloud CLI

**macOS** :
```bash
brew install --cask google-cloud-sdk
```

**Linux (Debian/Ubuntu)** :
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Windows (WSL)** :
```bash
# Suivre les instructions Linux ci-dessus dans WSL
```

Voir la [documentation officielle](https://cloud.google.com/sdk/docs/install) pour d'autres méthodes.

### Configuration initiale

```bash
# Initialisation
gcloud init

# Authentification
gcloud auth login

# Vérifier la configuration
gcloud config list
```

### Permissions GCP

Les scripts nécessitent différentes permissions selon leurs fonctions. Au minimum :

- **Viewer** : Pour les scripts de listing (projets, VMs)
- **Security Reviewer** : Pour les audits IAM
- **Billing Viewer** : Pour les informations de facturation

Consultez le [README des scripts](scripts/README.md) pour les permissions détaillées par script.

## Scripts Disponibles

### Gestion des Projets

#### 1. Liste des Projets GCP (Format Table)

**Script** : `scripts/list-gcp-projects.sh`

Liste tous les projets GCP avec leurs informations détaillées.

**Informations affichées** :
- ID du projet
- Nom du projet
- Date de création
- Propriétaire (rôle owner ou editor)

**Usage** :
```bash
./scripts/list-gcp-projects.sh
```

#### 2. Liste des Projets GCP (Format JSON)

**Script** : `scripts/list-gcp-projects-json.sh`

Export la liste des projets en format JSON pour automatisation.

**Usage** :
```bash
./scripts/list-gcp-projects-json.sh > projects.json
```

---

### Inventaire des Ressources

#### 3. Inventaire Complet des VMs

**Script** : `scripts/list-all-vms.sh`

Liste toutes les VMs dans tous vos projets avec leurs détails et coûts estimés.

**Informations affichées** :
- ID du projet
- Nom de la VM
- Statut (RUNNING, STOPPED)
- Zone
- Type de machine
- IP externe
- Coût mensuel estimé

**Usage** :
```bash
# Affichage formaté
./scripts/list-all-vms.sh

# Export JSON
./scripts/list-all-vms.sh --json > vms.json
```

**Exemple de sortie** :
```
Total VMs:           15
En cours (RUNNING):  12
Arrêtées:            3
Coût estimé/mois:    $450 USD
```

**Note** : Les coûts sont des estimations basées sur us-central1 et n'incluent pas les disques, réseau, licences.

---

### Coûts et Facturation

#### 4. Projets avec Facturation

**Script** : `scripts/list-projects-with-billing.sh`

Liste tous les projets avec leur statut de facturation et compte associé.

**Informations affichées** :
- ID du projet
- Nom
- Statut de facturation (enabled/disabled)
- ID du compte de facturation

**Usage** :
```bash
# Affichage formaté
./scripts/list-projects-with-billing.sh

# Export JSON
./scripts/list-projects-with-billing.sh --json
```

**À savoir** : Pour voir les coûts réels, configurez l'export de facturation vers BigQuery (voir documentation GCP).

---

### Sécurité et Conformité

#### 5. Audit des Permissions IAM

**Script** : `scripts/audit-iam-permissions.sh`

Audit complet des permissions IAM : qui a accès à quoi dans vos projets.

**Informations affichées** :
- Projet
- Membre (utilisateur, service account, groupe)
- Rôle (owner, editor, viewer, custom)
- Type de membre

**Usage** :
```bash
# Audit complet
./scripts/audit-iam-permissions.sh

# Audit d'un seul projet
./scripts/audit-iam-permissions.sh --project mon-projet

# Filtrer par rôle
./scripts/audit-iam-permissions.sh --role roles/owner

# Filtrer par membre
./scripts/audit-iam-permissions.sh --member user@example.com

# Export JSON
./scripts/audit-iam-permissions.sh --json
```

**Recommandations de sécurité** :
- Minimisez le nombre de owners
- Utilisez des groupes plutôt que des utilisateurs individuels
- Préférez des rôles spécifiques aux rôles larges
- Auditez régulièrement les service accounts

---

### Optimisation des Coûts

#### 6. Détection de Ressources Inutilisées

**Script** : `scripts/find-unused-resources.sh`

Identifie les ressources non utilisées pour optimiser vos coûts.

**Ressources détectées** :
- VMs arrêtées depuis X jours
- Disques non attachés
- Adresses IP statiques non utilisées (~$7/mois chacune)
- Snapshots anciens

**Usage** :
```bash
# Recherche avec seuil par défaut (7 jours)
./scripts/find-unused-resources.sh

# Seuil personnalisé (30 jours)
./scripts/find-unused-resources.sh --days 30

# Export JSON
./scripts/find-unused-resources.sh --json
```

**Économies potentielles** : Le script calcule les économies possibles pour les IPs inutilisées.

---

### Monitoring et Quotas

#### 7. Vérification des Quotas

**Script** : `scripts/check-quotas.sh`

Vérifie l'utilisation des quotas GCP pour éviter les dépassements.

**Quotas surveillés** :
- CPU cores
- Adresses IP externes
- Taille des disques (SSD et standard)
- Nombre d'instances
- IPs en utilisation

**Usage** :
```bash
# Vérification avec seuil par défaut (80%)
./scripts/check-quotas.sh

# Seuil personnalisé (90%)
./scripts/check-quotas.sh --threshold 90

# Vérifier un seul projet
./scripts/check-quotas.sh --project mon-projet

# Export JSON
./scripts/check-quotas.sh --json
```

**Alertes** :
- Jaune : utilisation > seuil défini
- Rouge : utilisation > 90% (critique)

---

## Workflows Recommandés

### Audit Hebdomadaire

```bash
# 1. Vérifier les quotas
./scripts/check-quotas.sh

# 2. Identifier les ressources inutilisées
./scripts/find-unused-resources.sh --days 7

# 3. Vérifier les permissions
./scripts/audit-iam-permissions.sh --role roles/owner
```

### Rapport Mensuel

```bash
# 1. Inventaire complet
./scripts/list-all-vms.sh > rapport-vms-$(date +%Y-%m).txt

# 2. État de la facturation
./scripts/list-projects-with-billing.sh > rapport-billing-$(date +%Y-%m).txt

# 3. Ressources à nettoyer
./scripts/find-unused-resources.sh --days 30 > nettoyage-$(date +%Y-%m).txt
```

### Export pour Analyse

```bash
# Export JSON de toutes les ressources
./scripts/list-all-vms.sh --json > vms.json
./scripts/audit-iam-permissions.sh --json > permissions.json
./scripts/check-quotas.sh --json > quotas.json
```

## Structure du Repository

```
carnet/
├── .gitignore                          # Fichiers à ignorer (credentials, logs, etc.)
├── README.md                           # Documentation principale
└── scripts/
    ├── README.md                       # Documentation des scripts
    ├── list-gcp-projects.sh            # Liste les projets (format table)
    ├── list-gcp-projects-json.sh       # Liste les projets (format JSON)
    ├── list-all-vms.sh                 # Inventaire des VMs avec coûts
    ├── list-projects-with-billing.sh   # Projets et facturation
    ├── audit-iam-permissions.sh        # Audit des permissions IAM
    ├── find-unused-resources.sh        # Détection ressources inutilisées
    └── check-quotas.sh                 # Vérification des quotas
```

## 🤝 Contribution

Les contributions sont les bienvenues ! Voici comment contribuer :

### Proposer un nouveau script

1. **Fork** le repository
2. Créez une **branche** : `git checkout -b feature/mon-nouveau-script`
3. **Développez** votre script en suivant les [bonnes pratiques](scripts/README.md#bonnes-pratiques)
4. **Testez** sur un environnement de développement
5. **Documentez** dans les READMEs
6. **Commit** : `git commit -m "feat: ajout script pour..."`
7. **Push** : `git push origin feature/mon-nouveau-script`
8. Ouvrez une **Pull Request**

### Standards de qualité

- ✅ Bash avec `set -euo pipefail`
- ✅ Support JSON pour l'automatisation
- ✅ Gestion d'erreurs propre
- ✅ Documentation claire (en-tête du script + README)
- ✅ Pas de secrets en dur
- ✅ Messages informatifs et colorés

### Idées de contributions

Consultez les [Issues](../../issues) pour voir les scripts demandés ou proposez les vôtres :

- Scripts pour Cloud SQL, Cloud Run, GKE
- Automatisation de backup/restore
- Rapports de conformité (SOC2, ISO27001)
- Intégrations avec Slack, email, etc.
- Scripts Terraform pour automatiser les déploiements

## 🔒 Sécurité

### Bonnes pratiques

- **Ne committez jamais** de credentials, tokens ou clés API
- Les scripts **ne modifient pas** vos ressources (lecture seule)
- Utilisez des **service accounts** avec permissions minimales pour l'automatisation
- Auditez les scripts avant de les exécuter sur production
- Testez d'abord sur des projets de développement

### Signaler une vulnérabilité

Si vous découvrez une faille de sécurité, merci de **ne pas** ouvrir une issue publique. Contactez-nous directement à [VOTRE-EMAIL] ou via la fonctionnalité [Security Advisories](../../security/advisories) de GitHub.

## 📝 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

Vous êtes libre de :
- ✅ Utiliser ces scripts dans vos projets commerciaux
- ✅ Modifier et adapter à vos besoins
- ✅ Distribuer et partager

## 📚 Ressources

- [Documentation Google Cloud](https://cloud.google.com/docs)
- [gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference)
- [Best Practices GCP](https://cloud.google.com/docs/enterprise/best-practices-for-enterprise-organizations)
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)

## 💬 Support

- 📖 Consultez d'abord la [documentation des scripts](scripts/README.md)
- 🐛 Pour les bugs, ouvrez une [Issue](../../issues)
- 💡 Pour les questions, utilisez les [Discussions](../../discussions)
- ⭐ Si ce projet vous est utile, n'hésitez pas à lui donner une étoile !

## 🙏 Remerciements

Merci à tous les contributeurs qui améliorent ce projet !

## ⚠️ Disclaimer

Ces scripts sont fournis "tels quels" sans garantie. Les estimations de coûts sont approximatives et peuvent varier selon votre configuration GCP. Testez toujours dans un environnement de développement avant utilisation en production.

---

**Développé avec ❤️ pour la communauté GCP**
