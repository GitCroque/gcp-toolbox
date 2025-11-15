# 📚 Carnet - Wiki Complet

Bienvenue dans le wiki ultra documenté de Carnet !

## 🗺️ Navigation

### 🚀 Démarrage
- [Installation](Installation.md) - Guide complet d'installation
- [Configuration](Configuration.md) - Configuration initiale et permissions GCP
- [Premiers Pas](Quick-Start.md) - Votre premier script en 5 minutes

### 📖 Scripts par Catégorie

#### 🔐 Sécurité & Audit
- [Audit Service Account Keys](scripts/Audit-Service-Account-Keys.md) - ⚠️ CRITIQUE
- [Scan Public Buckets](scripts/Scan-Public-Buckets.md) - ⚠️ CRITIQUE
- [Audit IAM Permissions](scripts/Audit-IAM-Permissions.md)

#### 💾 Bases de Données
- [List Cloud SQL Instances](scripts/List-Cloud-SQL-Instances.md)
- [Audit Database Backups](scripts/Audit-Database-Backups.md) - ⚠️ IMPORTANT

#### ☁️ Infrastructure
- [List All VMs](scripts/List-All-VMs.md)
- [List GKE Clusters](scripts/List-GKE-Clusters.md)
- [List Projects](scripts/List-Projects.md)

#### 💰 Optimisation des Coûts
- [VM Rightsizing](scripts/Compare-VM-Rightsizing.md) - 💎 Économies importantes
- [Committed Use Discounts](scripts/Analyze-Committed-Use.md) - 💎 Jusqu'à 57%
- [Preemptible Candidates](scripts/Check-Preemptible-Candidates.md) - 💎 Jusqu'à 91%
- [Container Images Audit](scripts/Audit-Container-Images.md)
- [Cost Anomalies Tracking](scripts/Track-Cost-Anomalies.md)

#### 🔍 Monitoring
- [Check Quotas](scripts/Check-Quotas.md)
- [Find Unused Resources](scripts/Find-Unused-Resources.md)
- [Projects with Billing](scripts/List-Projects-Billing.md)

### 📘 Guides Pratiques

- [Workflows Recommandés](Workflows.md) - Audits hebdomadaires, rapports mensuels
- [Automation & CI/CD](Automation.md) - Intégration dans vos pipelines
- [Best Practices GCP](Best-Practices.md) - Bonnes pratiques et recommandations
- [Troubleshooting](Troubleshooting.md) - Résolution de problèmes courants
- [FAQ](FAQ.md) - Questions fréquentes

### 🛠️ Développement

- [Contributing](../CONTRIBUTING.md) - Guide de contribution
- [Architecture](Architecture.md) - Comment fonctionnent les scripts
- [Testing](Testing.md) - Tester vos scripts
- [Roadmap](Roadmap.md) - Futures fonctionnalités

## 🎯 Scripts par Priorité

### 🔴 Priorité CRITIQUE (Sécurité)

1. **audit-service-account-keys.sh** - Détecte les clés anciennes (risque de compromission)
2. **scan-public-buckets.sh** - Trouve les buckets publics (risque de data leak)

### 🟠 Priorité HAUTE (Fiabilité)

3. **audit-database-backups.sh** - Vérifie que toutes les DBs ont des backups
4. **list-cloud-sql-instances.sh** - Inventaire et configuration des bases de données
5. **check-quotas.sh** - Évite les dépassements de quotas

### 🟡 Priorité MOYENNE (Optimisation)

6. **compare-vm-rightsizing.sh** - Économies sur VMs sur-provisionnées
7. **find-unused-resources.sh** - Détecte ressources inutilisées
8. **check-preemptible-candidates.sh** - Migration vers Spot VMs

### 🟢 Priorité NORMALE (Visibilité)

9. **list-all-vms.sh** - Inventaire complet des VMs
10. **list-gke-clusters.sh** - Inventaire Kubernetes
11. **audit-iam-permissions.sh** - Qui a accès à quoi

## 💡 Cas d'Usage par Profil

### 👨‍💼 Manager IT / CTO

**Objectif**: Visibilité et contrôle des coûts

Scripts recommandés:
1. `list-all-vms.sh` - Inventaire infrastructure
2. `list-projects-with-billing.sh` - État facturation
3. `track-cost-anomalies.sh` - Détection pics de coûts
4. `compare-vm-rightsizing.sh` - Opportunités d'économies

**Fréquence**: Hebdomadaire

### 🔐 Security Engineer

**Objectif**: Sécurité et conformité

Scripts recommandés:
1. `audit-service-account-keys.sh` - Rotation des clés
2. `scan-public-buckets.sh` - Exposition données
3. `audit-iam-permissions.sh` - Contrôle d'accès
4. `list-cloud-sql-instances.sh` - Config sécurité DBs

**Fréquence**: Quotidien ou hebdomadaire

### 💰 FinOps / Cost Optimization

**Objectif**: Réduction des coûts cloud

Scripts recommandés:
1. `compare-vm-rightsizing.sh` - Rightsizing
2. `check-preemptible-candidates.sh` - Migration Spot
3. `analyze-committed-use.sh` - CUDs
4. `find-unused-resources.sh` - Waste elimination
5. `audit-container-images.sh` - Storage cleanup

**Fréquence**: Hebdomadaire + Mensuel

### 🚀 DevOps / SRE

**Objectif**: Fiabilité et automatisation

Scripts recommandés:
1. `audit-database-backups.sh` - DR readiness
2. `check-quotas.sh` - Capacity planning
3. `list-gke-clusters.sh` - K8s inventory
4. `list-cloud-sql-instances.sh` - DB health

**Fréquence**: Quotidien via CI/CD

## 📊 Métriques Clés

**Économies Potentielles**:
- Rightsizing VMs: **10-30%** des coûts compute
- Spot VMs: **Jusqu'à 91%** sur workloads compatibles
- CUDs: **25-57%** sur usage stable
- Cleanup ressources: **5-15%** coûts totaux

**Risques Couverts**:
- 🔴 Data Leaks (buckets publics)
- 🔴 Compromission (clés anciennes)
- 🔴 Perte de données (pas de backup)
- 🟠 Dépassement quotas
- 🟠 Coûts non contrôlés

## 🔄 Mises à Jour

- **Dernière version**: v1.0.0
- **Dernière mise à jour docs**: 2024-11-15
- **Prochaine release**: v1.1.0 (voir [Roadmap](Roadmap.md))

## 💬 Besoin d'Aide?

- 📖 Consultez la [FAQ](FAQ.md)
- 🐛 [Issues GitHub](https://github.com/VOTRE-REPO/carnet/issues)
- 💡 [Discussions](https://github.com/VOTRE-REPO/carnet/discussions)
- 📧 Email: support@votre-domaine.com

---

**Navigation rapide**: [⬆️ Retour en haut](#-carnet---wiki-complet) | [🏠 README Principal](../README.md)
