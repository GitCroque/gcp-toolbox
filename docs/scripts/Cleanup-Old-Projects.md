# 🗑️ Cleanup Old Projects

**Script** : `cleanup-old-projects.sh`
**Priorité** : 🟡 IMPORTANT
**Catégorie** : Gouvernance & Coûts

## 🎯 Objectif

Identifie les **projets GCP inactifs** candidats à la suppression ou l'archivage pour optimiser les coûts et réduire la surface d'attaque.

## 💡 Pourquoi c'est IMPORTANT ?

### Le Problème

- **Projet inactif moyen** : $200-500/mois de waste
- **60 projets inactifs** × $300 = **$18,000/mois** gaspillés
- **Surface d'attaque** non monitorée
- **Compliance** : Données dans projets abandonnés ?

### Ce que fait le script

1. ✅ Identifie projets **vides** (0 ressources) → Candidats suppression
2. ✅ Identifie projets **inactifs** (peu de ressources) → À review
3. ✅ Calcule **économies potentielles**
4. ✅ Mode **dry-run** (aucune suppression automatique)

## 🚀 Utilisation

```bash
# Liste projets inactifs (dry-run par défaut)
./scripts/cleanup-old-projects.sh

# Personnaliser seuil (120 jours au lieu de 180)
./scripts/cleanup-old-projects.sh --inactive-days 120

# Export JSON
./scripts/cleanup-old-projects.sh --json > cleanup-candidates.json
```

## 📈 Exemple Sortie

```
========================================
  🗑️  Cleanup Projets Inactifs
========================================

Seuil d'inactivité: 180 jours
Mode: DRY RUN (aucune suppression)

PROJECT_ID                     VM_COUNT        SQL_COUNT       STATUS              RECOMMENDATION
----------                     ---------       ---------       ------              --------------
old-poc-2023                   0               0               empty               DELETE
test-abandoned                 0               0               empty               DELETE

=== Résumé ===
Total projets:                    156
Projets inactifs (REVIEW):        12
Candidats suppression (vides):    8
Économies estimées:               $2,400/mois

⚠️  8 projet(s) vide(s) peuvent être supprimés

Pour supprimer un projet:
  gcloud projects delete PROJECT_ID
```

## 🔧 Workflow Suppression Sécurisée

```bash
# 1. Identifier candidats
./scripts/cleanup-old-projects.sh --json > candidates.json

# 2. Review avec équipe
jq '.candidates[] | select(.recommendation == "DELETE")' candidates.json

# 3. Pour chaque projet à supprimer:
PROJECT_ID="old-poc-2023"

# Backup final
gcloud projects describe $PROJECT_ID > backup-$PROJECT_ID.json

# Vérifier vraiment vide
gcloud compute instances list --project=$PROJECT_ID
gcloud storage buckets list --project=$PROJECT_ID

# Supprimer
gcloud projects delete $PROJECT_ID

# 4. Documenter
echo "Deleted $PROJECT_ID on $(date)" >> cleanup-log.txt
```

## 💰 ROI

**Exemple** : 8 projets vides × $300/mois = **$2,400/mois** = $28,800/an économisés

---

[⬅️ Audit Firewall](Audit-Firewall-Rules.md) | [🏠 Wiki](../HOME.md)
