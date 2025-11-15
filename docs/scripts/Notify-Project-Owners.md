# 📧 Notify Project Owners

**Script** : `notify-project-owners.sh`
**Priorité** : 🟡 IMPORTANT
**Catégorie** : Gestion & Gouvernance

## 🎯 Objectif

Génère un rapport pour **contacter les propriétaires de projets GCP** et vérifier si leurs projets sont toujours nécessaires à l'organisation. Optimise la gouvernance et réduit les coûts.

## 💡 Pourquoi c'est IMPORTANT ?

### Le Problème : Project Sprawl

**Scénario typique dans une entreprise** :

```
2019:  10 projets GCP
2020:  25 projets (nouveaux POCs, équipes)
2021:  48 projets (croissance, acquisitions)
2022:  87 projets (shadow IT, expérimentations)
2023: 156 projets ← Où on en est aujourd'hui

Question: Combien sont VRAIMENT utilisés ? 🤔
```

**Réalité** :
- 40% des projets sont des **POCs abandonnés**
- 25% sont des **projets dev/test oubliés**
- 15% sont des **duplicatas**
- Seulement 20% sont activement utilisés en production

### Impact Business

**Financier** :
- Projet inactif moyen : **$200-500/mois** (ressources dormantes, IPs réservées)
- 60 projets inactifs × $300/mois = **$18,000/mois** = $216,000/an gaspillés

**Sécurité** :
- Projets oubliés = **surface d'attaque** non monitorée
- Credentials orphelins
- Règles firewall obsolètes

**Conformité** :
- RGPD : Données personnelles dans projets abandonnés ?
- Audit trail incomplet
- Ownership non documenté

## 📊 Que fait le script ?

### Vérifications

Pour chaque projet GCP :

1. ✅ **Identifie les propriétaires** (rôle Owner IAM)
2. ✅ **Évalue l'activité** :
   - Compte ressources actives (VMs, SQL, GKE)
   - Détermine statut (active, inactive, unknown)
3. ✅ **Génère recommandation** :
   - KEEP : Projet actif
   - REVIEW : Projet à vérifier avec propriétaire
   - DELETE : Projet vide, candidat suppression
4. ✅ **Export multi-formats** :
   - Table console (affichage)
   - JSON (automatisation)
   - CSV (mailing)
   - Template email (communication)

### Statuts

| Statut | Critères | Action |
|--------|----------|--------|
| **active** | Ressources actives (VMs, SQL, GKE) | KEEP |
| **inactive** | Aucune ressource active | REVIEW |
| **unknown** | Impossible de déterminer | REVIEW |

## 🚀 Utilisation

### Basique

```bash
# Générer rapport de tous les projets
./scripts/notify-project-owners.sh

# Affiche table avec propriétaires et statuts
```

### Options Avancées

```bash
# Export CSV pour mailing
./scripts/notify-project-owners.sh --output-csv projects-review.csv

# JSON pour automatisation
./scripts/notify-project-owners.sh --json > projects-audit.json

# Générer template d'email
./scripts/notify-project-owners.sh --email-template

# Personnaliser seuil d'inactivité (120 jours au lieu de 90)
./scripts/notify-project-owners.sh --inactive-days 120
```

### Workflow Complet

```bash
#!/bin/bash
# quarterly-project-review.sh - Review trimestriel

# 1. Générer rapport
./scripts/notify-project-owners.sh --output-csv projects-q4-2024.csv

# 2. Générer template email
./scripts/notify-project-owners.sh --email-template

# 3. Analyser avec jq
./scripts/notify-project-owners.sh --json | \
  jq '.projects[] | select(.recommendation == "REVIEW")'

# 4. Envoyer emails (via outil de votre choix)
# Utiliser projects-q4-2024.csv avec merge fields
```

## 📈 Exemple de Sortie

### Format Table

```
========================================
  📧 Notification Propriétaires Projets
========================================

Seuil d'inactivité: 90 jours

PROJECT_ID                     PROJECT_NAME                             OWNER_EMAIL                    STATUS          ACTION
----------                     ------------                             -----------                    ------          ------
prod-app                       Production Application                   alice@company.com              active          KEEP
dev-poc-ml                     POC Machine Learning                     bob@company.com                inactive        REVIEW
staging-old                    Old Staging Environment                  unknown@example.com            inactive        REVIEW
test-2023-q1                   Test Project Q1 2023                     charlie@company.com            inactive        REVIEW

========== Résumé ==========
Total projets:             156
Projets actifs:            62
Projets inactifs:          87
Projets statut inconnu:    7

⚠️  87 projet(s) à REVIEW avec les propriétaires
```

### Format JSON

```json
{
  "generated_at": "2024-11-15T10:30:00Z",
  "inactive_threshold_days": 90,
  "projects": [
    {
      "project_id": "dev-poc-ml",
      "project_name": "POC Machine Learning",
      "owner_email": "bob@company.com",
      "status": "inactive",
      "vm_count": 0,
      "sql_count": 0,
      "gke_count": 0,
      "recommendation": "REVIEW"
    }
  ],
  "summary": {
    "total_projects": 156,
    "active_projects": 62,
    "inactive_projects": 87,
    "unknown_projects": 7
  }
}
```

### Format CSV

```csv
project_id,project_name,owner_email,status,vm_count,sql_count,gke_count,recommendation
dev-poc-ml,POC Machine Learning,bob@company.com,inactive,0,0,0,REVIEW
test-2023-q1,Test Project Q1 2023,charlie@company.com,inactive,0,0,0,REVIEW
```

### Template Email Généré

```
Objet: [ACTION REQUISE] Vérification annuelle de votre projet GCP: {{PROJECT_NAME}}

Bonjour {{OWNER_NAME}},

Dans le cadre de notre audit annuel de la plateforme Google Cloud Platform, nous revoyons tous les projets pour optimiser les coûts et la sécurité.

📊 Informations sur votre projet:
- Nom du projet: {{PROJECT_NAME}}
- ID du projet: {{PROJECT_ID}}
- Vous êtes identifié(e) comme propriétaire
- Statut actuel: {{STATUS}}
- Ressources actives:
  * VMs: {{VM_COUNT}}
  * Bases de données: {{SQL_COUNT}}
  * Clusters GKE: {{GKE_COUNT}}

❓ Action requise:
Merci de répondre aux questions suivantes avant le {{DEADLINE_DATE}}:

1. Ce projet est-il toujours nécessaire à l'organisation ? (Oui/Non)
2. Si oui, quelle est son utilisation principale ?
   [ ] Production
   [ ] Staging
   [ ] Développement
   [ ] POC/Expérimentation
   [ ] Archivé (peut être supprimé)

3. Pouvez-vous confirmer que toutes les ressources sont encore utilisées ?
4. Acceptez-vous d'être contacté pour une optimisation des coûts si opportunités détectées ?

⚠️  Important:
Les projets marqués "inactifs" sans réponse après 30 jours seront:
- Mis en "shutdown" temporaire (ressources arrêtées)
- Supprimés après 90 jours supplémentaires

💬 Pour répondre:
Merci de répondre directement à cet email ou via notre formulaire: https://forms.company.com/gcp-review

Cordialement,
L'équipe Platform Engineering
```

## 📋 Processus Complet de Review

### Phase 1 : Collecte (Semaine 1)

```bash
# 1. Générer rapport
./scripts/notify-project-owners.sh --output-csv projects-review-2024-q4.csv --json > projects-review-2024-q4.json

# 2. Analyser projets inactifs
cat projects-review-2024-q4.json | jq '.projects[] | select(.recommendation == "REVIEW")'

# 3. Préparer communication
./scripts/notify-project-owners.sh --email-template
```

### Phase 2 : Communication (Semaine 2)

**Utiliser outil mailing** (ex: SendGrid, Mailchimp, Google Workspace)

1. **Importer CSV** dans outil mailing
2. **Personnaliser email** avec merge fields:
   - `{{PROJECT_NAME}}` → Nom du projet
   - `{{OWNER_EMAIL}}` → Email propriétaire
   - `{{STATUS}}` → Statut (active/inactive)
   - etc.
3. **Définir deadline** : J+30 (4 semaines)
4. **Envoyer**

### Phase 3 : Suivi (Semaine 3-4)

**Tracking des réponses** :

```bash
# Créer fichier de suivi
cat > project-review-responses.csv <<EOF
project_id,owner_email,response,action,notes
dev-poc-ml,bob@company.com,DELETE,2024-12-01,POC terminé
test-2023-q1,charlie@company.com,KEEP,N/A,Utilisé pour CI/CD
EOF

# Analyser taux de réponse
response_count=$(wc -l < project-review-responses.csv)
total_inactive=$(cat projects-review-2024-q4.json | jq '.summary.inactive_projects')
response_rate=$((response_count * 100 / total_inactive))
echo "Taux de réponse: $response_rate%"
```

**Relance** (J+15 si pas de réponse) :

```
Objet: [RAPPEL] Vérification de votre projet GCP: {{PROJECT_NAME}}

Bonjour,

Nous n'avons pas encore reçu votre réponse concernant le projet {{PROJECT_NAME}}.

Merci de répondre avant le {{DEADLINE_DATE}} pour éviter la mise en pause automatique du projet.

[Même contenu que email initial]
```

### Phase 4 : Action (Semaine 5-6)

**Selon réponses** :

#### Réponse "DELETE" ✅

```bash
# 1. Vérifier qu'il n'y a vraiment aucune ressource critique
PROJECT_ID="dev-poc-ml"

gcloud compute instances list --project=$PROJECT_ID
gcloud sql instances list --project=$PROJECT_ID
gcloud storage buckets list --project=$PROJECT_ID

# 2. Export backup final (au cas où)
gcloud projects describe $PROJECT_ID > backup-$PROJECT_ID.json

# 3. Supprimer
gcloud projects delete $PROJECT_ID

# ✅ Économie: $300/mois
```

#### Réponse "KEEP" ✅

```bash
# 1. Vérifier labeling correct
gcloud projects add-labels $PROJECT_ID --labels=reviewed=2024-q4,status=active

# 2. Documenter dans wiki
echo "- $PROJECT_ID : Validé Q4 2024, Owner: alice@company.com" >> project-inventory.md
```

#### PAS DE RÉPONSE ❌

**Escalade** (J+30) :

```
Objet: [URGENT] Votre projet GCP {{PROJECT_NAME}} sera mis en pause dans 7 jours

Bonjour,

Malgré nos 2 rappels, nous n'avons pas reçu de confirmation pour le projet {{PROJECT_NAME}}.

🚨 Ce projet sera automatiquement mis en pause le {{SHUTDOWN_DATE}} (J+7)

Pour éviter cette action:
- Répondre immédiatement à cet email
- Ou contacter platform-team@company.com

Cordialement,
L'équipe Platform Engineering
```

**Mise en pause** (J+37) :

```bash
# Arrêter toutes les ressources (mais ne pas supprimer)
PROJECT_ID="non-responsive-project"

# VMs
for vm in $(gcloud compute instances list --project=$PROJECT_ID --format="value(name,zone)"); do
  gcloud compute instances stop $vm --project=$PROJECT_ID
done

# Ajouter label
gcloud projects update $PROJECT_ID --update-labels=status=paused,paused-date=$(date +%Y-%m-%d)

# Email notification
```

**Suppression définitive** (J+127 = 90 jours après pause) :

```bash
# Dernier email (J+120)
# Si toujours pas de réponse → Suppression J+127
gcloud projects delete $PROJECT_ID
```

## 💰 ROI Exemple

**Entreprise avec 150 projets** :

| Phase | Résultat | Économies |
|-------|----------|-----------|
| **Audit initial** | 150 projets | - |
| **Projets actifs** | 60 projets (40%) | - |
| **Projets inactifs** | 90 projets (60%) | - |
| **Réponses DELETE** | 45 projets (50% des inactifs) | $13,500/mois |
| **Réponses KEEP** | 30 projets (nettoyés) | $4,500/mois |
| **Pas de réponse → Pause** | 15 projets | $4,500/mois |
| **TOTAL ÉCONOMIES** | - | **$22,500/mois** |

**Annualisé** : $270,000/an 🎉

**Effort** : 1 personne × 2 semaines = ~$8,000

**ROI** : 3,375% !

## 🔄 Automatisation Récurrente

### Review Trimestriel Automatisé

```bash
#!/bin/bash
# Cron: 0 9 1 1,4,7,10 * (1er janvier, avril, juillet, octobre à 9h)

QUARTER="Q$(date +%q)-$(date +%Y)"
OUTPUT_DIR="/var/gcp-reviews/$QUARTER"
mkdir -p "$OUTPUT_DIR"

# 1. Générer rapport
./scripts/notify-project-owners.sh \
  --output-csv "$OUTPUT_DIR/projects.csv" \
  --json > "$OUTPUT_DIR/projects.json"

# 2. Générer template
./scripts/notify-project-owners.sh --email-template

# 3. Analyser
INACTIVE_COUNT=$(jq '.summary.inactive_projects' "$OUTPUT_DIR/projects.json")

# 4. Notifier équipe
if [[ $INACTIVE_COUNT -gt 50 ]]; then
  mail -s "GCP Project Review $QUARTER: $INACTIVE_COUNT projets inactifs" \
    platform-team@company.com < "$OUTPUT_DIR/projects.csv"
fi

# 5. Créer ticket Jira/GitHub
# (Votre outil de tracking)
```

## 📚 Ressources

- [GCP Project Management](https://cloud.google.com/resource-manager/docs/creating-managing-projects)
- [IAM Roles](https://cloud.google.com/iam/docs/understanding-roles)
- [Project Labeling](https://cloud.google.com/resource-manager/docs/creating-managing-labels)

## 🎯 Checklist Review Projet

- [ ] Rapport généré
- [ ] Propriétaires identifiés
- [ ] Templates emails personnalisés
- [ ] Deadline définie (J+30)
- [ ] Emails envoyés
- [ ] Suivi des réponses dans spreadsheet
- [ ] Relances programmées (J+15)
- [ ] Escalade pour non-répondants (J+30)
- [ ] Actions exécutées (DELETE/KEEP/PAUSE)
- [ ] Documentation mise à jour
- [ ] Économies calculées et reportées
- [ ] Next review planifié (Q+3 mois)

## 💡 Best Practices

### ✅ À FAIRE

1. **Communication claire** : Expliquer le "pourquoi" (coûts, sécurité)
2. **Deadline réaliste** : 30 jours minimum
3. **Processus graduel** : Review → Pause → Delete (pas direct)
4. **Documentation** : Tracer toutes les actions
5. **Backup avant delete** : Export config projet
6. **Labels** : Marquer projets reviewed
7. **Récurrence** : Review trimestriel ou annuel

### ❌ À ÉVITER

1. ❌ Supprimer sans notification
2. ❌ Deadline trop courte (< 14 jours)
3. ❌ Pas de backup avant suppression
4. ❌ Email générique sans contexte
5. ❌ Ignorer les non-répondants
6. ❌ Pas de process d'escalade
7. ❌ Review one-shot (doit être récurrent)

---

[⬅️ List GKE](List-GKE-Clusters.md) | [🏠 Wiki](../HOME.md) | [➡️ Cleanup Old Projects](Cleanup-Old-Projects.md)
