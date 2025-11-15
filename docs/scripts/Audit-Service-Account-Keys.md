# 🔐 Audit Service Account Keys

**Script** : `audit-service-account-keys.sh`
**Priorité** : 🔴 CRITIQUE
**Catégorie** : Sécurité

## 🎯 Objectif

Détecte les clés de service accounts **anciennes** ou **jamais utilisées** qui représentent un **risque majeur de sécurité**.

## ⚠️ Pourquoi c'est CRITIQUE ?

Les clés de service accounts sont des **credentials permanents** :

- 🔴 **Pas d'expiration automatique** (contrairement aux tokens OAuth)
- 🔴 **Si volées** : Accès permanent à vos ressources
- 🔴 **Si oubliées** : Dormantes et exploitables
- 🔴 **Conformité** : RGPD, SOC2, ISO27001 exigent rotation régulière

**Statistiques** :
- 60% des entreprises ont des clés > 1 an
- 30% ont des clés jamais utilisées
- Principale source de compromission GCP

## 📊 Que détecte le script ?

### Niveaux de Risque

| Risque | Condition | Action |
|--------|-----------|--------|
| 🔴 **CRITICAL** | Clé > 365 jours OU jamais utilisée > 90j | Supprimer IMMÉDIATEMENT |
| 🟣 **HIGH** | Clé > 180 jours | Planifier rotation cette semaine |
| 🟡 **MEDIUM** | Clé > 90 jours (seuil par défaut) | Planifier rotation ce mois |
| 🟢 **LOW** | Clé < 90 jours | OK |

### Informations Collectées

Pour chaque clé :
- ✅ Projet
- ✅ Service Account
- ✅ ID de la clé
- ✅ Âge en jours
- ✅ Date de création
- ✅ Utilisation (si logs disponibles)
- ✅ Niveau de risque calculé

## 🚀 Utilisation

### Basique

```bash
# Audit tous les projets
./scripts/audit-service-account-keys.sh

# Affiche uniquement les clés à risque (MEDIUM et plus)
```

### Options Avancées

```bash
# Seuil personnalisé (60 jours au lieu de 90)
./scripts/audit-service-account-keys.sh --days 60

# Un seul projet
./scripts/audit-service-account-keys.sh --project mon-projet-prod

# Export JSON pour automatisation
./scripts/audit-service-account-keys.sh --json > sa-keys-audit.json
```

### Combinaisons

```bash
# Audit d'un projet spécifique en JSON
./scripts/audit-service-account-keys.sh --project prod --days 90 --json

# Filtrer les critiques avec jq
./scripts/audit-service-account-keys.sh --json | \
  jq '.service_account_keys[] | select(.risk_level == "CRITICAL")'
```

## 📈 Exemple de Sortie

### Format Table

```
========================================
  ⚠️  AUDIT CLÉS SERVICE ACCOUNTS
========================================
Seuil d'alerte: clés > 90 jours

Récupération des clés de service accounts...

PROJECT_ID                     SERVICE_ACCOUNT                                          KEY_TYPE     AGE_DAYS     LAST_USED       RISK_LEVEL
----------                     ---------------                                          --------     --------     ---------       ----------
prod-app                       app-backend@prod-app.iam...                             USER_MANAGED 456          unknown         CRITICAL
prod-app                       deploy-sa@prod-app.iam...                               USER_MANAGED 234          unknown         HIGH
dev-env                        test-sa@dev-env.iam...                                  USER_MANAGED 120          unknown         MEDIUM

========== Résumé ==========
Total clés (user-managed):     42
Risque CRITIQUE (rouge):       8
Risque ÉLEVÉ (magenta):        12
Risque MOYEN (jaune):          15
Risque FAIBLE (vert):          7

⚠️  ALERTE CRITIQUE !
8 clé(s) nécessite(nt) une action immédiate

========== Recommandations ==========
...
```

### Format JSON

```json
{
  "generated_at": "2024-11-15T10:30:00Z",
  "threshold_days": 90,
  "service_account_keys": [
    {
      "project_id": "prod-app",
      "service_account": "app-backend@prod-app.iam.gserviceaccount.com",
      "key_id": "a1b2c3d4e5f6",
      "key_type": "USER_MANAGED",
      "age_days": 456,
      "created_at": "2023-01-15T10:00:00Z",
      "never_used": "unknown",
      "risk_level": "CRITICAL"
    }
  ],
  "summary": {
    "total_keys": 42,
    "user_managed_keys": 42,
    "critical_risk": 8,
    "high_risk": 12,
    "medium_risk": 15,
    "low_risk": 7
  }
}
```

## 🔧 Remédiation

### Rotation de Clé (Procédure Sécurisée)

**⚠️ IMPORTANT** : Ne supprimez jamais une clé sans avoir déployé la nouvelle !

#### Étape 1 : Créer nouvelle clé

```bash
PROJECT_ID="votre-projet"
SA_EMAIL="service-account@${PROJECT_ID}.iam.gserviceaccount.com"

# Créer nouvelle clé
gcloud iam service-accounts keys create new-key.json \
  --iam-account=$SA_EMAIL \
  --project=$PROJECT_ID

# ✅ Clé sauvegardée dans new-key.json
```

#### Étape 2 : Déployer nouvelle clé

```bash
# Kubernetes Secret
kubectl delete secret gcp-key
kubectl create secret generic gcp-key --from-file=key.json=new-key.json

# Cloud Run
gcloud run services update SERVICE_NAME \
  --update-secrets=GCP_KEY=new-key:latest

# Cloud Functions
gcloud functions deploy FUNCTION_NAME \
  --set-env-vars GCP_KEY_PATH=/secrets/new-key.json

# Compute Engine
# Uploader via console ou gsutil, puis redémarrer app
```

#### Étape 3 : Tester (24-48h)

```bash
# Vérifier logs d'erreur
gcloud logging read "severity=ERROR AND textPayload=~'authentication'" \
  --limit=50 --format=json

# Si aucune erreur : OK, passez à l'étape 4
```

#### Étape 4 : Supprimer ancienne clé

```bash
# Lister les clés
gcloud iam service-accounts keys list \
  --iam-account=$SA_EMAIL \
  --format="table(name,validAfterTime)"

# Identifier l'ancienne clé (KEY_ID)
OLD_KEY_ID="a1b2c3d4e5f6..."

# Supprimer
gcloud iam service-accounts keys delete $OLD_KEY_ID \
  --iam-account=$SA_EMAIL \
  --quiet

# ✅ Rotation terminée
```

### Alternative : Workload Identity (Recommandé)

**Au lieu de clés, utilisez Workload Identity (GKE) :**

```bash
# Plus de clés à gérer !
# Le pod obtient automatiquement les credentials

gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[NAMESPACE/KSA_NAME]"
```

## 📅 Fréquence Recommandée

| Environnement | Fréquence Audit | Rotation Clés |
|---------------|-----------------|---------------|
| **Production** | Quotidien | 90 jours |
| **Staging** | Hebdomadaire | 180 jours |
| **Dev** | Mensuel | 365 jours |

### Automatisation

```bash
# Cron quotidien (8h du matin)
0 8 * * * /path/to/audit-service-account-keys.sh --days 90 --json > /var/log/sa-audit.json

# Alerter si clés critiques
0 8 * * * /path/to/audit-service-account-keys.sh --json | \
  jq -e '.summary.critical_risk > 0' && \
  mail -s "⚠️ GCP: Clés critiques détectées" security@company.com
```

## 🛡️ Best Practices

### ✅ À FAIRE

1. **Rotation automatique** : Tous les 90 jours
2. **Workload Identity** : Pour GKE (pas de clés !)
3. **Service Account Impersonation** : Pour accès temporaire
4. **Audit régulier** : Hebdomadaire minimum
5. **Logs activés** : Cloud Audit Logs pour traçabilité
6. **Principe du moindre privilège** : Permissions minimales
7. **Clés différentes** : Par environnement (dev/staging/prod)

### ❌ À ÉVITER

1. ❌ Clés commitées dans Git
2. ❌ Clés en clair dans fichiers de config
3. ❌ Même clé partagée entre environnements
4. ❌ Clés avec permissions Owner
5. ❌ Clés jamais renouvelées
6. ❌ Clés stockées en local sur laptops
7. ❌ Clés dans logs ou monitoring

## 🔍 Troubleshooting

### "Permission denied" sur certains projets

**Cause** : Vous n'avez pas `iam.serviceAccountKeys.list`

**Solution** :
```bash
# Demander le rôle Security Reviewer
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:VOTRE_EMAIL" \
  --role="roles/iam.securityReviewer"
```

### "0 keys found" mais j'ai des SA

**Cause** : Seulement les clés `USER_MANAGED` sont listées (pas SYSTEM_MANAGED)

**Explication** : Les clés SYSTEM_MANAGED sont gérées par Google (rotation auto), donc pas de risque.

### Script lent (>5 min)

**Causes** :
- Beaucoup de projets (>100)
- Beaucoup de service accounts (>500)

**Solutions** :
```bash
# Filtrer par projet
./scripts/audit-service-account-keys.sh --project critical-project

# Paralléliser (avancé)
for proj in $(gcloud projects list --format='value(projectId)'); do
  ./scripts/audit-service-account-keys.sh --project $proj --json > sa-$proj.json &
done
wait
```

## 📚 Ressources

- [Best Practices Service Accounts](https://cloud.google.com/iam/docs/best-practices-service-accounts)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Service Account Impersonation](https://cloud.google.com/iam/docs/impersonating-service-accounts)
- [Audit Logs](https://cloud.google.com/logging/docs/audit)

## 🎯 Checklist Conformité

Pour passer un audit de sécurité :

- [ ] Aucune clé > 90 jours en production
- [ ] Politique de rotation documentée
- [ ] Audit mensuel effectué
- [ ] Logs d'audit activés
- [ ] Workload Identity utilisé où possible
- [ ] Service accounts avec least privilege
- [ ] Alerting automatisé configuré
- [ ] Plan de réponse incident documenté

---

[⬅️ Retour Wiki](../HOME.md) | [➡️ Scan Public Buckets](Scan-Public-Buckets.md)
