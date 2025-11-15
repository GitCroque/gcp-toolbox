# 🏷️ Audit Resource Labels

**Script** : `audit-resource-labels.sh`
**Priorité** : 🟡 IMPORTANT
**Catégorie** : Gouvernance & Coûts

## 🎯 Objectif

Audite le **labeling des ressources GCP** pour conformité aux standards d'organisation (env, owner, cost-center). Essentiel pour gouvernance et cost tracking.

## 💡 Pourquoi c'est IMPORTANT ?

### Le Problème Sans Labels

```
Question: "Combien coûte l'équipe Data Science ?"
Réponse: "Aucune idée, ressources non labellées"

Question: "Qui est propriétaire de cette VM ?"
Réponse: "Personne ne sait, créée il y a 2 ans"

Question: "Combien coûte l'env dev vs prod ?"
Réponse: "Impossible à déterminer"
```

### Avec Labels Standardisés

```yaml
labels:
  env: prod                    # prod, staging, dev
  owner: team-data-science     # Qui possède cette ressource
  cost-center: engineering-001 # Quel budget
  project: ml-pipeline         # Quel projet métier
```

**Bénéfices** :
- 💰 **Cost tracking** par équipe/env/projet
- 👤 **Ownership** clair
- 🔍 **Filtrage** facile (ex: toutes ressources prod)
- 📊 **Reporting** précis

## 📊 Que vérifie le script ?

1. ✅ Vérifie **labels obligatoires** sur toutes les VMs
2. ✅ Identifie ressources **non-conformes**
3. ✅ Liste **labels manquants**
4. ✅ Taux de **compliance**

## 🚀 Utilisation

```bash
# Audit avec labels par défaut (env,owner,cost-center)
./scripts/audit-resource-labels.sh

# Personnaliser labels obligatoires
./scripts/audit-resource-labels.sh --required-labels="env,team,application"

# Un projet spécifique
./scripts/audit-resource-labels.sh --project prod-app

# Export JSON
./scripts/audit-resource-labels.sh --json > labels-audit.json
```

## 📈 Exemple Sortie

```
========================================
  🏷️  Audit Resource Labels
========================================

Labels obligatoires: env,owner,cost-center

PROJECT                   RESOURCE_NAME                  TYPE            MISSING_LABELS       STATUS
-------                   -------------                  ----            --------------       ------
prod-app                  backend-vm-1                   VM              env,owner            NON_COMPLIANT
prod-app                  frontend-vm-2                  VM              cost-center          NON_COMPLIANT

=== Résumé ===
Total ressources:      42
Conformes:             28
Non-conformes:         14

⚠️  14 ressource(s) sans labels obligatoires

Pour ajouter des labels:
  gcloud compute instances add-labels VM_NAME --labels=env=prod,owner=team-a
```

## 🔧 Remédiation : Ajouter Labels

### Sur VM existante

```bash
# Ajouter labels
gcloud compute instances add-labels backend-vm-1 \
  --zone=us-central1-a \
  --labels=env=prod,owner=team-backend,cost-center=eng-001

# Vérifier
gcloud compute instances describe backend-vm-1 \
  --zone=us-central1-a \
  --format="value(labels)"
```

### Sur nouvelles ressources (automatique)

```bash
# Créer VM avec labels dès le début
gcloud compute instances create my-vm \
  --zone=us-central1-a \
  --labels=env=prod,owner=team-a,cost-center=eng-001
```

### Labeling en masse (script)

```bash
#!/bin/bash
# bulk-label.sh

# Toutes les VMs dev sans labels
for vm in $(gcloud compute instances list \
  --filter="name~'^dev-'" \
  --format="value(name,zone)"); do
  
  gcloud compute instances add-labels $vm \
    --labels=env=dev,owner=team-dev,cost-center=dev-001
done
```

## 📊 Cost Tracking avec Labels

### Billing Export + BigQuery

```sql
-- Coût par équipe (via label owner)
SELECT
  labels.value AS team,
  SUM(cost) AS total_cost
FROM `project.billing_export.gcp_billing_export`
WHERE labels.key = 'owner'
GROUP BY team
ORDER BY total_cost DESC;

-- Coût par environnement
SELECT
  labels.value AS environment,
  SUM(cost) AS total_cost
FROM `project.billing_export.gcp_billing_export`
WHERE labels.key = 'env'
GROUP BY environment;
```

## 🎯 Standards Labels Recommandés

| Label | Valeurs | Obligatoire | Usage |
|-------|---------|-------------|-------|
| **env** | prod, staging, dev, test | ✅ Oui | Environnement |
| **owner** | team-backend, team-data | ✅ Oui | Équipe propriétaire |
| **cost-center** | eng-001, marketing-002 | ✅ Oui | Budget/cost center |
| **application** | api, frontend, ml-pipeline | Recommandé | Application métier |
| **managed-by** | terraform, manual | Recommandé | Comment créé |

### Organisation Policy (Forcer labels)

```yaml
# Forcer labels au niveau org
constraint: constraints/gcp.resourceLabels
listPolicy:
  requireLabels:
    - env
    - owner
    - cost-center
```

## 💰 ROI

- **Avant labels** : "Coûts GCP = $50,000/mois" (global, inutile)
- **Avec labels** : 
  - Équipe Data: $18,000
  - Équipe Backend: $22,000
  - Équipe ML: $10,000
  
  → Chaque équipe peut optimiser !

---

[⬅️ Scan Exposed Services](Scan-Exposed-Services.md) | [🏠 Wiki](../HOME.md)
