# Guide de Contribution

Merci de votre intérêt pour contribuer à Carnet ! 🎉

## Table des Matières

- [Code de Conduite](#code-de-conduite)
- [Comment Contribuer](#comment-contribuer)
- [Développer un Nouveau Script](#développer-un-nouveau-script)
- [Standards de Code](#standards-de-code)
- [Process de Review](#process-de-review)

## Code de Conduite

Ce projet adopte un code de conduite pour assurer un environnement accueillant pour tous. En participant, vous acceptez de respecter ce code.

**Comportements attendus :**
- Utiliser un langage accueillant et inclusif
- Respecter les points de vue et expériences différents
- Accepter les critiques constructives avec grâce
- Se concentrer sur ce qui est meilleur pour la communauté

## Comment Contribuer

### Signaler des Bugs

Si vous trouvez un bug :

1. Vérifiez que le bug n'a pas déjà été signalé dans les [Issues](../../issues)
2. Ouvrez une nouvelle issue avec le template "Bug Report"
3. Incluez :
   - Description claire du problème
   - Étapes pour reproduire
   - Comportement attendu vs comportement observé
   - Environnement (OS, version bash, version gcloud)
   - Logs pertinents (sans informations sensibles !)

### Proposer des Fonctionnalités

Pour proposer un nouveau script ou une amélioration :

1. Ouvrez une issue avec le template "Feature Request"
2. Décrivez :
   - Le problème que cela résout
   - La solution proposée
   - Des alternatives considérées
   - Impact potentiel

### Soumettre des Pull Requests

1. **Fork** le repository
2. **Clone** votre fork : `git clone https://github.com/VOTRE-USERNAME/carnet.git`
3. **Créez une branche** : `git checkout -b feature/description-courte`
4. **Committez** vos changements : `git commit -m "feat: description"`
5. **Push** : `git push origin feature/description-courte`
6. Ouvrez une **Pull Request**

## Développer un Nouveau Script

### Structure d'un Script

```bash
#!/bin/bash

#####################################################################
# Script: nom-du-script.sh
# Description: Description claire de ce que fait le script
# Prérequis: gcloud CLI configuré et authentifié
#            Permissions nécessaires: liste des permissions
# Usage: ./nom-du-script.sh [OPTIONS]
#
# Options:
#   --option1 VALUE  : Description
#   --json           : Sortie en format JSON
#####################################################################

set -euo pipefail

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse des arguments
# ...

# Vérification que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud CLI n'est pas installé${NC}" >&2
    exit 1
fi

# Vérification de l'authentification
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}Erreur: Aucun compte gcloud actif trouvé${NC}" >&2
    exit 1
fi

# Logique principale
# ...
```

### Checklist de Développement

Avant de soumettre votre PR, vérifiez :

- [ ] Le script utilise `set -euo pipefail`
- [ ] Vérification de gcloud installé et authentifié
- [ ] Support de l'option `--json` pour automatisation
- [ ] Gestion d'erreurs appropriée
- [ ] Messages colorés et informatifs
- [ ] Pas de secrets ou credentials en dur
- [ ] Documentation dans l'en-tête du script
- [ ] Script testé sur au moins 2 projets GCP
- [ ] Permissions GCP nécessaires documentées
- [ ] README mis à jour avec le nouveau script
- [ ] scripts/README.md mis à jour avec documentation détaillée

## Standards de Code

### Style Bash

```bash
# ✅ Bon
if [[ "$variable" == "value" ]]; then
    echo "Correct"
fi

# ❌ Mauvais
if [ $variable = "value" ]
then
echo "Incorrect"
fi
```

### Nommage

- **Scripts** : `kebab-case.sh` (ex: `list-all-vms.sh`)
- **Variables** : `snake_case` (ex: `project_id`)
- **Constantes** : `UPPER_SNAKE_CASE` (ex: `MAX_RETRIES`)
- **Fonctions** : `snake_case` (ex: `get_project_owner`)

### Messages

```bash
# Informations
echo -e "${GREEN}✓ Opération réussie${NC}"

# Avertissements
echo -e "${YELLOW}⚠ Attention: message${NC}"

# Erreurs (vers stderr)
echo -e "${RED}✗ Erreur: message${NC}" >&2
```

### Gestion d'Erreurs

```bash
# Toujours capturer les erreurs
result=$(gcloud compute instances list 2>&1) || {
    echo -e "${RED}Erreur lors de la récupération des VMs${NC}" >&2
    exit 1
}

# Vérifier les valeurs avant utilisation
if [[ -z "$variable" ]]; then
    echo -e "${RED}Erreur: variable vide${NC}" >&2
    exit 1
fi
```

### Support JSON

Tous les scripts doivent supporter l'export JSON :

```bash
JSON_MODE=false
if [[ "${1:-}" == "--json" ]]; then
    JSON_MODE=true
fi

if [[ "$JSON_MODE" == true ]]; then
    echo '{"key": "value"}'
else
    echo "Affichage formaté"
fi
```

## Process de Review

### Ce que nous vérifions

1. **Fonctionnalité** : Le script fait ce qu'il promet
2. **Sécurité** : Pas de risques de sécurité
3. **Performance** : Optimisé pour limiter les appels API
4. **Documentation** : Bien documenté et compréhensible
5. **Tests** : Testé sur différents environnements
6. **Style** : Respecte les standards de code

### Timeline

- **Première review** : Dans les 3-5 jours ouvrés
- **Feedback** : Discussion et ajustements si nécessaire
- **Merge** : Une fois approuvé par au moins 1 mainteneur

### Après le Merge

Votre contribution sera :
- Créditée dans les release notes
- Ajoutée à la liste des contributeurs
- Disponible pour toute la communauté GCP !

## Tests

### Tests Manuels

```bash
# 1. Test sur projet de dev
./scripts/votre-script.sh --project dev-project

# 2. Test du mode JSON
./scripts/votre-script.sh --json | jq .

# 3. Test de gestion d'erreurs
# Désauthentifiez-vous et vérifiez le message d'erreur
gcloud auth revoke
./scripts/votre-script.sh
```

### Tests avec ShellCheck

```bash
# Installer shellcheck
# macOS
brew install shellcheck

# Linux
apt-get install shellcheck

# Vérifier votre script
shellcheck scripts/votre-script.sh
```

## Documentation

### README Principal

Ajoutez une section pour votre script avec :
- Nom et description courte
- Usage de base
- Exemple de sortie

### scripts/README.md

Documentation détaillée avec :
- Objectif complet
- Permissions GCP requises
- Toutes les options disponibles
- Cas d'usage concrets
- Exemples avec `jq` si pertinent
- Temps d'exécution estimé
- Limites et considérations

## Questions ?

- 💬 Ouvrez une [Discussion](../../discussions) pour les questions générales
- 📧 Contactez les mainteneurs pour des questions spécifiques
- 📖 Consultez d'abord la [documentation](README.md)

---

Merci de contribuer à Carnet ! 🙏
