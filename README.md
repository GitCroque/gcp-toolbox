# Carnet - Gestion de Plateforme GCP

Ce repository contient des scripts et outils pour la gestion de notre plateforme Google Cloud Platform (GCP).

## Prérequis

- **gcloud CLI** : Doit être installé et configuré sur votre Mac
- **Authentification** : Vous devez être authentifié avec `gcloud auth login`
- **Permissions** : Vous devez avoir les permissions nécessaires pour lister les projets et consulter les IAM policies

### Installation de gcloud CLI

Si ce n'est pas déjà fait :
```bash
# Sur macOS
brew install --cask google-cloud-sdk

# Initialisation
gcloud init

# Authentification
gcloud auth login
```

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

## Contribution

Pour ajouter de nouveaux scripts de gestion GCP, placez-les dans le dossier `scripts/` et mettez à jour ce README.

## Notes

- Les scripts utilisent la CLI `gcloud` et nécessitent une authentification active
- Assurez-vous d'avoir les permissions appropriées pour accéder aux ressources GCP
- La récupération du propriétaire peut prendre quelques secondes par projet
