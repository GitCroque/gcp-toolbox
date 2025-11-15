# Scripts GCP

Ce dossier contient les scripts pour la gestion de la plateforme GCP.

## Scripts disponibles

### list-gcp-projects.sh

Liste tous les projets GCP avec leurs informations détaillées.

**Fonctionnalités** :
- Liste tous les projets accessibles avec votre compte gcloud
- Affiche l'ID, le nom, la date de création
- Récupère le propriétaire (owner) de chaque projet via IAM policy
- Affichage coloré et formaté pour une meilleure lisibilité

**Utilisation** :
```bash
./list-gcp-projects.sh
```

**Options futures possibles** :
- Export en CSV/JSON
- Filtrage par propriétaire
- Tri par date de création
- Affichage des informations de facturation

**Code de retour** :
- 0 : Succès
- 1 : Erreur (gcloud non installé ou non authentifié)

## Développement

Pour créer de nouveaux scripts :

1. Créez votre script dans ce dossier
2. Ajoutez les permissions d'exécution : `chmod +x nom-du-script.sh`
3. Documentez-le dans ce README
4. Testez-le avant de commiter

## Bonnes pratiques

- Utilisez `set -euo pipefail` au début de chaque script bash
- Ajoutez des commentaires explicatifs
- Vérifiez les prérequis (commandes disponibles, authentification)
- Gérez les erreurs proprement
- Ajoutez des messages colorés pour améliorer la lisibilité
