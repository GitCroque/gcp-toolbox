# Archives CI/CD

Ce dossier contient les fichiers de CI/CD automatique qui ont été archivés car l'utilisateur préfère une exécution manuelle.

## Contenu

- `.github/workflows/` - GitHub Actions workflows
- `.gitlab-ci.yml` - GitLab CI configuration

## Restauration

Si vous souhaitez réactiver l'automatisation :

```bash
# GitHub Actions
mv archives/ci-cd/.github .

# GitLab CI
mv archives/ci-cd/.gitlab-ci.yml .
```

## Note

Ces workflows ont été conçus pour :
- Audits de sécurité quotidiens automatiques
- Analyses de coûts mensuelles
- Création automatique d'issues GitHub
- Notifications Slack

Ils fonctionnent parfaitement mais nécessitent une configuration initiale (secrets, service accounts, etc.).
