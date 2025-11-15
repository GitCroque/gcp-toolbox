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

### 1. Liste des Projets GCP (Format Table)

**Script** : `scripts/list-gcp-projects.sh`

Liste tous les projets GCP avec les informations suivantes :
- ID du projet
- Nom du projet
- Date de création
- Propriétaire (rôle owner ou editor)

**Usage** :
```bash
./scripts/list-gcp-projects.sh
```

**Sortie exemple** :
```
========================================
  Liste des Projets GCP
========================================

Récupération de la liste des projets...

PROJECT_ID                     NAME                           CREATE_TIME               OWNER
----------                     ----                           -----------               -----
mon-projet-prod                Production Project             2024-01-15T10:30:00       user:admin@example.com
mon-projet-dev                 Development Project            2024-02-20T14:22:00       user:dev@example.com
mon-projet-staging             Staging Environment            2024-03-10T09:15:00       serviceAccount:sa@project.iam
```

### 2. Liste des Projets GCP (Format JSON)

**Script** : `scripts/list-gcp-projects-json.sh`

Export la liste des projets en format JSON pour faciliter l'automatisation et l'intégration avec d'autres outils.

**Usage** :
```bash
# Affichage dans le terminal
./scripts/list-gcp-projects-json.sh

# Export vers un fichier
./scripts/list-gcp-projects-json.sh > projects.json
```

**Sortie exemple** :
```json
{
  "generated_at": "2024-11-15T10:30:00Z",
  "projects": [
    {
      "project_id": "mon-projet-prod",
      "name": "Production Project",
      "project_number": "123456789012",
      "create_time": "2024-01-15T10:30:00",
      "owner": "user:admin@example.com"
    }
  ]
}
```

## Structure du Repository

```
carnet/
├── .gitignore                      # Fichiers à ignorer (credentials, logs, etc.)
├── README.md                       # Ce fichier
└── scripts/
    ├── README.md                   # Documentation des scripts
    ├── list-gcp-projects.sh        # Liste les projets GCP (format table)
    └── list-gcp-projects-json.sh   # Liste les projets GCP (format JSON)
```

## Contribution

Pour ajouter de nouveaux scripts de gestion GCP, placez-les dans le dossier `scripts/` et mettez à jour ce README.

## Notes

- Les scripts utilisent la CLI `gcloud` et nécessitent une authentification active
- Assurez-vous d'avoir les permissions appropriées pour accéder aux ressources GCP
- La récupération du propriétaire peut prendre quelques secondes par projet
