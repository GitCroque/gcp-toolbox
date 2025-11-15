# Scripts GCP - Documentation Détaillée

Ce dossier contient tous les scripts pour la gestion de la plateforme GCP.

## Vue d'ensemble

| Script | Catégorie | Description | Supports JSON |
|--------|-----------|-------------|---------------|
| `list-gcp-projects.sh` | Projets | Liste tous les projets | Non |
| `list-gcp-projects-json.sh` | Projets | Liste tous les projets | Oui (uniquement) |
| `list-all-vms.sh` | Inventaire | Inventaire des VMs + coûts | Oui |
| `list-projects-with-billing.sh` | Facturation | Statut de facturation | Oui |
| `audit-iam-permissions.sh` | Sécurité | Audit des permissions IAM | Oui |
| `find-unused-resources.sh` | Optimisation | Ressources inutilisées | Oui |
| `check-quotas.sh` | Monitoring | Vérification des quotas | Oui |

---

## Scripts de Gestion des Projets

### list-gcp-projects.sh

**Objectif** : Lister tous vos projets GCP avec leurs métadonnées de base.

**Permissions requises** :
- `resourcemanager.projects.list`
- `resourcemanager.projects.getIamPolicy`

**Sortie** : Tableau formaté avec couleurs dans le terminal

**Temps d'exécution** : ~5-10 secondes pour 50 projets

**Cas d'usage** :
- Vue d'ensemble rapide de vos projets
- Identification des propriétaires
- Vérification des dates de création

**Exemple** :
```bash
./list-gcp-projects.sh
```

**Code de retour** :
- `0` : Succès
- `1` : Erreur (gcloud non installé ou non authentifié)

---

### list-gcp-projects-json.sh

**Objectif** : Même chose que ci-dessus mais en format JSON pour automatisation.

**Sortie** : JSON structuré

**Cas d'usage** :
- Intégration avec d'autres outils (jq, Python, etc.)
- Archivage de l'état des projets
- Génération de rapports automatisés

**Exemple** :
```bash
# Export vers fichier
./list-gcp-projects-json.sh > projects-$(date +%Y%m%d).json

# Filtrage avec jq
./list-gcp-projects-json.sh | jq '.projects[] | select(.owner | contains("admin"))'
```

---

## Scripts d'Inventaire

### list-all-vms.sh

**Objectif** : Inventaire complet de toutes les VMs avec calcul des coûts estimés.

**Permissions requises** :
- `compute.instances.list` sur tous les projets

**Options** :
- `--json` : Sortie en format JSON

**Informations collectées** :
- Nom et ID du projet
- Nom de la VM
- Statut (RUNNING, STOPPED, TERMINATED)
- Zone
- Type de machine (e2-micro, n1-standard-4, etc.)
- IP externe
- Coût mensuel estimé (basé sur des prix moyens)

**Temps d'exécution** : ~10-30 secondes selon le nombre de projets et VMs

**Cas d'usage** :
- Audit mensuel des ressources
- Estimation des coûts compute
- Identification des VMs arrêtées
- Inventaire pour la conformité

**Exemple** :
```bash
# Affichage standard
./list-all-vms.sh

# Export JSON pour analyse
./list-all-vms.sh --json > vms-inventory.json

# Analyse avec jq : VMs arrêtées
./list-all-vms.sh --json | jq '.vms[] | select(.status != "RUNNING")'
```

**Limites** :
- Les coûts sont des estimations basées sur us-central1
- N'inclut pas : disques persistants, réseau sortant, licences Windows
- Les prix peuvent varier selon la région

---

## Scripts de Facturation

### list-projects-with-billing.sh

**Objectif** : Vérifier quel compte de facturation est lié à chaque projet.

**Permissions requises** :
- `resourcemanager.projects.get`
- `billing.accounts.get` (optionnel)

**Options** :
- `--json` : Sortie en format JSON

**Informations collectées** :
- ID du projet
- Nom du projet
- Statut de facturation (enabled/disabled)
- ID du compte de facturation

**Temps d'exécution** : ~5-15 secondes selon le nombre de projets

**Cas d'usage** :
- Vérifier que tous les projets de prod ont la facturation activée
- Identifier les projets sans facturation
- Audit des comptes de facturation utilisés
- Préparation à la migration de compte de facturation

**Exemple** :
```bash
# Affichage standard
./list-projects-with-billing.sh

# Trouver les projets sans facturation
./list-projects-with-billing.sh --json | jq '.projects[] | select(.billing_enabled != "enabled")'
```

**Note importante** : Ce script montre uniquement les **comptes** de facturation liés, pas les coûts réels. Pour les coûts réels, configurez l'export vers BigQuery.

**Pour aller plus loin** :
1. Activez l'export de facturation vers BigQuery
2. Créez des requêtes SQL pour analyser les coûts
3. Utilisez Data Studio pour visualiser les dépenses

---

## Scripts de Sécurité

### audit-iam-permissions.sh

**Objectif** : Audit complet des permissions IAM pour identifier qui a accès à quoi.

**Permissions requises** :
- `resourcemanager.projects.getIamPolicy` sur tous les projets

**Options** :
- `--json` : Sortie en format JSON
- `--project PROJECT_ID` : Auditer un seul projet
- `--role ROLE` : Filtrer par rôle (ex: `roles/owner`)
- `--member EMAIL` : Filtrer par membre

**Informations collectées** :
- Projet
- Membre (email complet)
- Nom du membre
- Type (user, serviceAccount, group, domain)
- Rôle complet et raccourci

**Temps d'exécution** : ~20-60 secondes selon le nombre de projets

**Cas d'usage** :
- Audit de sécurité trimestriel
- Identifier tous les owners de la plateforme
- Trouver tous les accès d'un utilisateur
- Vérifier les service accounts et leurs permissions
- Conformité (SOC2, ISO27001)

**Exemples** :
```bash
# Audit complet
./audit-iam-permissions.sh

# Lister tous les owners
./audit-iam-permissions.sh --role roles/owner

# Trouver tous les accès d'un utilisateur
./audit-iam-permissions.sh --member john@example.com

# Auditer un seul projet
./audit-iam-permissions.sh --project production-app

# Export pour analyse
./audit-iam-permissions.sh --json > iam-audit-$(date +%Y%m%d).json

# Combiner les filtres (via jq)
./audit-iam-permissions.sh --json | jq '.permissions[] | select(.project_id == "prod" and .role == "roles/owner")'
```

**Recommandations de sécurité** :
- Exécutez cet audit au moins mensuellement
- Limitez le nombre de owners au strict minimum (2-3 par projet)
- Utilisez des groupes Google au lieu d'utilisateurs individuels
- Auditez les service accounts régulièrement
- Supprimez les accès inutilisés
- Préférez les rôles custom granulaires aux rôles predefined larges

**Drapeaux d'alerte** :
- Trop de owners (>5 par projet)
- Service accounts avec owner
- Utilisateurs externes avec editor/owner
- Groupes avec beaucoup de membres et permissions larges

---

## Scripts d'Optimisation

### find-unused-resources.sh

**Objectif** : Identifier les ressources GCP non utilisées pour réduire les coûts.

**Permissions requises** :
- `compute.instances.list`
- `compute.disks.list`
- `compute.addresses.list`
- `compute.snapshots.list`

**Options** :
- `--days N` : Seuil en jours (défaut: 7)
- `--json` : Sortie en format JSON

**Ressources détectées** :
1. **VMs arrêtées** depuis N+ jours
2. **Disques non attachés** (orphelins)
3. **IPs statiques** non utilisées (~$7/mois chacune)
4. **Snapshots** de plus de N jours

**Temps d'exécution** : ~30-90 secondes selon le nombre de projets et ressources

**Cas d'usage** :
- Revue mensuelle d'optimisation des coûts
- Nettoyage de printemps (cleanup)
- Calcul des économies potentielles
- Identification des ressources zombies

**Exemples** :
```bash
# Recherche standard (7 jours)
./find-unused-resources.sh

# Recherche plus conservative (30 jours)
./find-unused-resources.sh --days 30

# Export JSON
./find-unused-resources.sh --json > cleanup-$(date +%Y%m%d).json

# Voir uniquement les IPs inutilisées
./find-unused-resources.sh --json | jq '.unused_resources.unused_static_ips'
```

**Économies potentielles** :
- **IPs statiques** : ~$7/mois par IP
- **Disques non attachés** : $0.04/GB/mois (standard) ou $0.17/GB/mois (SSD)
- **Snapshots** : $0.026/GB/mois
- **VMs arrêtées** : Toujours des disques attachés qui coûtent

**Actions recommandées** :
1. **Avant de supprimer** : Vérifiez avec les équipes propriétaires
2. **VMs arrêtées** :
   - Si test/dev : supprimer après 7 jours
   - Si prod : créer snapshot puis supprimer après 30 jours
3. **Disques non attachés** :
   - Vérifier s'ils sont nécessaires
   - Créer snapshot si important
   - Supprimer sinon
4. **IPs statiques** :
   - Vérifier si vraiment nécessaires
   - Libérer immédiatement si inutilisées
5. **Snapshots** :
   - Établir une politique de rétention (30/60/90 jours)
   - Supprimer les snapshots au-delà de la rétention

**Workflow de nettoyage suggéré** :
```bash
# 1. Générer le rapport
./find-unused-resources.sh --days 30 > cleanup-report.txt

# 2. Partager avec les équipes (donner 1 semaine pour réagir)

# 3. Après validation, supprimer manuellement ou via script
# Exemple pour IPs (à faire manuellement) :
# gcloud compute addresses delete IP_NAME --region=REGION --project=PROJECT

# 4. Calculer les économies réalisées
```

---

## Scripts de Monitoring

### check-quotas.sh

**Objectif** : Surveiller l'utilisation des quotas GCP pour éviter les dépassements surprise.

**Permissions requises** :
- `compute.regions.get`
- `compute.projects.get`

**Options** :
- `--threshold N` : Seuil d'alerte en % (défaut: 80)
- `--project PROJECT` : Vérifier un seul projet
- `--json` : Sortie en format JSON

**Quotas surveillés** :
- `CPUS` : CPU cores (vCPUs)
- `DISKS_TOTAL_GB` : Taille totale des disques standard
- `SSD_TOTAL_GB` : Taille totale des disques SSD
- `INSTANCES` : Nombre d'instances (VMs)
- `IN_USE_ADDRESSES` : IPs en utilisation
- `STATIC_ADDRESSES` : IPs statiques réservées

**Temps d'exécution** : ~20-60 secondes selon le nombre de projets et régions

**Cas d'usage** :
- Monitoring hebdomadaire des quotas
- Alertes proactives avant dépassement
- Planification de capacité
- Préparation aux pics de charge
- Éviter les erreurs de déploiement dues aux quotas

**Exemples** :
```bash
# Vérification standard (seuil 80%)
./check-quotas.sh

# Alertes plus sensibles (seuil 70%)
./check-quotas.sh --threshold 70

# Vérifier un seul projet critique
./check-quotas.sh --project production-critical

# Export pour monitoring
./check-quotas.sh --json > quotas-$(date +%Y%m%d).json

# Trouver les quotas critiques (>90%)
./check-quotas.sh --json | jq '.quotas[] | select(.percentage != "N/A" and (.percentage | tonumber) > 90)'
```

**Codes couleur** :
- 🟢 Vert : < seuil défini (OK)
- 🟡 Jaune : ≥ seuil défini (Attention)
- 🔴 Rouge : ≥ 90% (Critique)

**Actions recommandées par niveau** :

**Vert (< 80%)** :
- Rien à faire, continuez à surveiller

**Jaune (80-89%)** :
- Surveillez de près
- Planifiez une augmentation si croissance prévue
- Revoyez si certaines ressources peuvent être libérées

**Rouge (≥ 90%)** :
- **Action immédiate requise**
- Demandez une augmentation de quota
- Libérez des ressources si possible
- Bloquez les nouveaux déploiements si nécessaire

**Comment demander une augmentation de quota** :
```bash
# Via la console
# 1. IAM & Admin > Quotas
# 2. Filtrer par métrique (ex: CPUS)
# 3. Sélectionner le quota
# 4. Click "Edit Quotas"
# 5. Justifier la demande

# Via gcloud (afficher les quotas)
gcloud compute project-info describe --project PROJECT_ID
gcloud compute regions describe REGION --project PROJECT_ID
```

**Automatisation recommandée** :
```bash
# Cron hebdomadaire
0 9 * * 1 /path/to/check-quotas.sh --threshold 75 > /var/log/gcp-quotas.log

# Avec alerte email si problème
0 9 * * 1 /path/to/check-quotas.sh --json | jq -e '.summary.quotas_over_threshold > 0' && mail -s "GCP Quotas Alert" admin@example.com < /var/log/gcp-quotas.log
```

---

## Développement et Bonnes Pratiques

### Pour créer un nouveau script

1. **Créez le fichier** dans ce dossier
   ```bash
   touch nouveau-script.sh
   chmod +x nouveau-script.sh
   ```

2. **Structure de base** :
   ```bash
   #!/bin/bash
   set -euo pipefail

   # En-tête de documentation
   # Description, prérequis, usage

   # Vérifications (gcloud installé, authentifié)

   # Logique principale

   # Gestion des erreurs
   ```

3. **Ajoutez** :
   - Vérification de gcloud installé
   - Vérification de l'authentification
   - Support de `--json` pour automatisation
   - Messages colorés pour lisibilité
   - Gestion d'erreurs propre
   - Documentation dans l'en-tête

4. **Testez** sur un petit projet d'abord

5. **Documentez** dans ce README

6. **Commitez** avec un message clair

### Bonnes pratiques

**Sécurité** :
- ✅ Utilisez `set -euo pipefail` (arrêt sur erreur)
- ✅ Ne loggez jamais de credentials
- ✅ Validez les entrées utilisateur
- ✅ Gérez les cas d'erreur proprement

**Performance** :
- ✅ Utilisez `--format` avec gcloud pour parsing
- ✅ Limitez les appels API quand possible
- ✅ Affichez la progression pour les scripts longs

**Maintenabilité** :
- ✅ Commentez le code complexe
- ✅ Utilisez des fonctions pour la réutilisation
- ✅ Nommage clair des variables
- ✅ Retours de codes standards (0=succès, 1=erreur)

**UX** :
- ✅ Messages clairs et informatifs
- ✅ Couleurs pour la lisibilité
- ✅ Support JSON pour automatisation
- ✅ Options `--help` si complexe

### Codes de retour standards

- `0` : Succès
- `1` : Erreur générale (gcloud absent, non authentifié)
- `2` : Erreur de paramètres

### Variables d'environnement utiles

```bash
# Projet par défaut
export GOOGLE_CLOUD_PROJECT="mon-projet-default"

# Région par défaut
export GOOGLE_CLOUD_REGION="us-central1"

# Format de sortie par défaut
export CLOUDSDK_CORE_FORMAT="json"
```

---

## Dépannage

### Problème : "gcloud: command not found"

**Solution** :
```bash
# macOS
brew install --cask google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

### Problème : "ERROR: (gcloud.auth.list) The access token has expired"

**Solution** :
```bash
gcloud auth login
gcloud auth application-default login
```

### Problème : "Permission denied"

**Solutions** :
1. Vérifiez vos IAM roles dans la console GCP
2. Assurez-vous d'avoir les permissions listées dans chaque script
3. Contactez votre admin GCP pour les permissions manquantes

### Problème : Script très lent

**Causes possibles** :
- Beaucoup de projets (>50)
- Beaucoup de ressources (>100 VMs)
- Connexion réseau lente

**Solutions** :
- Utilisez `--project` pour cibler un seul projet
- Exécutez hors heures de pointe
- Augmentez le timeout si nécessaire

---

## Support et Contribution

Pour toute question ou amélioration :

1. Vérifiez la documentation ci-dessus
2. Lisez le code source (bien commenté)
3. Consultez la documentation gcloud : `gcloud help`
4. Ouvrez une issue dans le repo

**Contributions bienvenues** pour :
- Nouveaux scripts utiles
- Optimisations de performance
- Améliorations de la documentation
- Corrections de bugs
