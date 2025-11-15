# 📚 Documentation Carnet

Bienvenue dans la documentation complète de Carnet !

## 🗺️ Navigation Rapide

### 🚀 Démarrer

1. **[Quick Start](Quick-Start.md)** - Votre premier audit en 5 minutes ⭐
2. **[HOME](HOME.md)** - Page d'accueil du wiki avec navigation complète

### 📖 Guides

- **[Workflows](Workflows.md)** - Workflows quotidiens, hebdomadaires, mensuels
- **[FAQ](FAQ.md)** - 30+ questions/réponses

### 🔐 Documentation des Scripts

#### Scripts Sécurité (Documentation Complète) 🔐

- **[Audit Service Account Keys](scripts/Audit-Service-Account-Keys.md)** ⭐ - Détection clés anciennes
- **[Scan Public Buckets](scripts/Scan-Public-Buckets.md)** ⭐ - Détection data leaks
- **[Audit Database Backups](scripts/Audit-Database-Backups.md)** ⭐ - Vérification backups Cloud SQL
- **[Audit Firewall Rules](scripts/Audit-Firewall-Rules.md)** ⭐ - Détection règles dangereuses (0.0.0.0/0)
- **[Scan Exposed Services](scripts/Scan-Exposed-Services.md)** ⭐ - Services exposés publiquement

#### Scripts Coûts (Documentation Complète) 💰

- **[Compare VM Rightsizing](scripts/Compare-VM-Rightsizing.md)** - Optimisation sizing VMs (15-30% économies)
- **[Cleanup Old Projects](scripts/Cleanup-Old-Projects.md)** - Identification projets inactifs

#### Scripts Inventaire (Documentation Complète) 📦

- **[List Cloud SQL Instances](scripts/List-Cloud-SQL-Instances.md)** - Inventaire bases de données
- **[List GKE Clusters](scripts/List-GKE-Clusters.md)** - Inventaire clusters Kubernetes
- **[Generate Inventory Report](scripts/Generate-Inventory-Report.md)** - Rapport complet plateforme

#### Scripts Gouvernance (Documentation Complète) 🏛️

- **[Notify Project Owners](scripts/Notify-Project-Owners.md)** - Contact propriétaires pour validation
- **[Audit Resource Labels](scripts/Audit-Resource-Labels.md)** - Vérification labeling ressources

#### Autres Scripts

Pour les autres scripts, consultez la documentation inline dans chaque fichier `.sh` (en-tête détaillé) ou le [README des scripts](../scripts/README.md).

## 📊 Par Catégorie

### 🔴 Sécurité Critique

1. **[Audit Service Account Keys](scripts/Audit-Service-Account-Keys.md)** - Clés anciennes/compromises
2. **[Scan Public Buckets](scripts/Scan-Public-Buckets.md)** - Buckets publics = data leak
3. **[Audit Database Backups](scripts/Audit-Database-Backups.md)** - Backups manquants
4. **[Audit Firewall Rules](scripts/Audit-Firewall-Rules.md)** - Règles firewall dangereuses
5. **[Scan Exposed Services](scripts/Scan-Exposed-Services.md)** - Services publics

### 💰 Optimisation Coûts

- **[Compare VM Rightsizing](scripts/Compare-VM-Rightsizing.md)** - Rightsizing (15-30% économies)
- **[Cleanup Old Projects](scripts/Cleanup-Old-Projects.md)** - Projets inactifs ($2,400/mois économies)
- `check-preemptible-candidates.sh` - Spot VMs (jusqu'à 91%)
- `analyze-committed-use.sh` - CUDs (25-57%)
- `find-unused-resources.sh` - Cleanup ressources (5-15%)
- `track-cost-anomalies.sh` - Détection pics

### 📦 Inventaire

- `list-all-vms.sh` - Toutes les VMs + coûts
- **[List Cloud SQL Instances](scripts/List-Cloud-SQL-Instances.md)** - Bases de données
- **[List GKE Clusters](scripts/List-GKE-Clusters.md)** - Clusters Kubernetes
- **[Generate Inventory Report](scripts/Generate-Inventory-Report.md)** - Rapport complet
- `audit-container-images.sh` - Images containers
- `list-gcp-projects.sh` - Tous les projets

### 🏛️ Gouvernance

- **[Notify Project Owners](scripts/Notify-Project-Owners.md)** - Review annuel projets
- **[Audit Resource Labels](scripts/Audit-Resource-Labels.md)** - Vérification labels
- `check-quotas.sh` - Utilisation quotas
- `audit-iam-permissions.sh` - Permissions IAM
- `list-projects-with-billing.sh` - Statut facturation

## 🎯 Par Cas d'Usage

### Je veux sécuriser ma plateforme

1. [Scan Public Buckets](scripts/Scan-Public-Buckets.md)
2. [Audit Service Account Keys](scripts/Audit-Service-Account-Keys.md)
3. `audit-iam-permissions.sh`

Workflow : [Audit Quotidien](Workflows.md#-workflow-quotidien-devopssre)

### Je veux réduire mes coûts

1. `find-unused-resources.sh`
2. **[Compare VM Rightsizing](scripts/Compare-VM-Rightsizing.md)** - Guide complet
3. `check-preemptible-candidates.sh`
4. `analyze-committed-use.sh`

Workflow : [Rapport Mensuel FinOps](Workflows.md#-workflow-mensuel-finops)

### Je veux automatiser

Consultez : [Workflows - CI/CD Integration](Workflows.md#-workflow-cicd-integration)

Exemples :
- GitHub Actions
- GitLab CI
- Jenkins
- Cron
- Cloud Scheduler

## 📝 Comment Contribuer à la Doc

Vous voulez améliorer la documentation ?

1. **Créer une page de script** :
   - Copier le template depuis `scripts/Audit-Service-Account-Keys.md`
   - Adapter pour votre script
   - PR !

2. **Améliorer page existante** :
   - Fork le repo
   - Éditer le fichier `.md`
   - PR avec vos améliorations

3. **Ajouter un cas d'usage** :
   - Ajouter dans `Workflows.md`
   - Partager votre expérience réelle !

## 🔍 Recherche

**Cherchez** :
- `Ctrl+F` dans cette page pour trouver un script
- Utilisez l'index dans [HOME.md](HOME.md)
- Consultez la [FAQ](FAQ.md) pour questions courantes

## 📞 Besoin d'Aide ?

- 📖 Lisez d'abord la [FAQ](FAQ.md)
- 💬 [Discussions GitHub](https://github.com/VOTRE-REPO/discussions)
- 🐛 [Issues GitHub](https://github.com/VOTRE-REPO/issues)

---

**Dernière mise à jour** : 2024-11-15
