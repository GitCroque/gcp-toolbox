# 🔓 Scan Public Buckets

**Script** : `scan-public-buckets.sh`
**Priorité** : 🔴 CRITIQUE
**Catégorie** : Sécurité

## 🎯 Objectif

Scanne tous les buckets Cloud Storage pour détecter ceux qui sont **publiquement accessibles** et représentent un **risque majeur de data leak**.

## ⚠️ Pourquoi c'est CRITIQUE ?

Un bucket public = **Vos données accessibles à TOUS sur Internet** !

### Risques Réels

🔴 **Data Leaks** :
- Données clients exposées (RGPD !)
- Informations confidentielles accessibles
- Code source / secrets exposés
- Backups de bases de données publics

🔴 **Amendes & Légal** :
- RGPD : Jusqu'à 4% du CA mondial ou 20M€
- Perte de confiance clients
- Impact réputation

🔴 **Coûts** :
- Bandwidth abuse (bots qui téléchargent tout)
- Factures de plusieurs milliers de dollars

### Incidents Célèbres

- **Dow Jones** : 2.2M clients exposés
- **Verizon** : 14M clients exposés
- **Accenture** : 137 GB de données clients
- **Tesla** : Code source et credentials AWS

**Tous dus à des buckets S3/GCS publics !**

## 📊 Que détecte le script ?

### Types de Permissions Publiques

| Type | Niveau | Qui peut accéder ? |
|------|--------|-------------------|
| 🔴 **allUsers** | PUBLIC INTERNET | N'importe qui, même sans compte GCP |
| 🟡 **allAuthenticatedUsers** | TOUS GCP USERS | Tout utilisateur avec un compte Google |

### Informations Collectées

Pour chaque bucket public :
- ✅ Projet
- ✅ Nom du bucket
- ✅ Localisation
- ✅ Type d'accès public (allUsers / allAuthenticatedUsers)
- ✅ Classe de stockage
- ✅ Taille (optionnel, peut être lent)

## 🚀 Utilisation

### Basique

```bash
# Scanner tous les buckets
./scripts/scan-public-buckets.sh

# N'affiche QUE les buckets publics
```

### Options

```bash
# Un seul projet
./scripts/scan-public-buckets.sh --project mon-projet

# Export JSON
./scripts/scan-public-buckets.sh --json > public-buckets.json
```

### Analyse avec jq

```bash
# Combien de buckets publics ?
./scripts/scan-public-buckets.sh --json | jq '.summary.public_buckets'

# Lister les buckets allUsers (pire risque)
./scripts/scan-public-buckets.sh --json | \
  jq '.buckets[] | select(.public_type | contains("allUsers")) | .bucket_name'
```

## 📈 Exemple de Sortie

### Format Table

```
========================================
  🔓 SCAN BUCKETS PUBLICS
========================================

Scanning Cloud Storage buckets...

PROJECT_ID                     BUCKET_NAME                                  LOCATION        PUBLIC_ACCESS           SIZE
----------                     -----------                                  --------        -------------           ----
prod-app                       prod-backups-2023                           us-central1     PUBLIC (allUsers)       N/A
dev-env                        test-uploads                                us-east1        AUTH (allAuth*)         N/A

========== Résumé ==========
Total buckets scannés:         156
Buckets publics:               2
  - allUsers (Internet):       1
  - allAuthenticatedUsers:     1

⚠️  RISQUE CRITIQUE DE DATA LEAK !
2 bucket(s) sont publiquement accessibles

========== Recommandations ==========
...
```

### Format JSON

```json
{
  "generated_at": "2024-11-15T10:30:00Z",
  "buckets": [
    {
      "project_id": "prod-app",
      "bucket_name": "prod-backups-2023",
      "location": "us-central1",
      "storage_class": "STANDARD",
      "is_public": true,
      "public_type": "allUsers",
      "size": "N/A"
    }
  ],
  "summary": {
    "total_buckets_scanned": 156,
    "public_buckets": 2,
    "all_users_public": 1,
    "all_authenticated_public": 1
  }
}
```

## 🔧 Remédiation URGENTE

### Si vous trouvez un bucket public :

#### Étape 1 : IMMÉDIATE (< 5 minutes)

**Retirer l'accès public** :

```bash
BUCKET_NAME="votre-bucket-public"

# Retirer allUsers
gsutil iam ch -d allUsers gs://$BUCKET_NAME

# Retirer allAuthenticatedUsers
gsutil iam ch -d allAuthenticatedUsers gs://$BUCKET_NAME

# Vérifier
gsutil iam get gs://$BUCKET_NAME
# Ne devrait PAS contenir allUsers ou allAuthenticatedUsers
```

#### Étape 2 : SÉCURISER (< 15 minutes)

**Activer Uniform Bucket-Level Access** :

```bash
# Active la protection au niveau bucket (recommandé)
gsutil uniformbucketlevelaccess set on gs://$BUCKET_NAME

# Cela désactive les ACL au niveau objet
# Plus simple à gérer et plus sécurisé
```

#### Étape 3 : AUDITER (< 1 heure)

**Qui a rendu ce bucket public ?**

```bash
# Vérifier les logs (24h précédentes)
gcloud logging read "resource.type=gcs_bucket AND \
  resource.labels.bucket_name=$BUCKET_NAME AND \
  protoPayload.methodName=storage.setIamPermissions" \
  --limit=50 \
  --format=json
```

**Quelles données sont exposées ?**

```bash
# Lister le contenu
gsutil ls -r gs://$BUCKET_NAME | head -100

# Vérifier données sensibles
# - PII (Personally Identifiable Information) ?
# - Données financières ?
# - Secrets / credentials ?
# - Code source ?
```

**Qui a accédé aux données ?**

```bash
# Si logs d'accès activés
gsutil logging get gs://$BUCKET_NAME

# Analyser les logs
# Chercher IPs externes, patterns anormaux
```

#### Étape 4 : INCIDENT RESPONSE (< 24h)

Si données sensibles exposées :

1. **Notifier CISO / DPO**
2. **Notifier clients** (si RGPD applicable)
3. **Documenter** incident (5W: Who, What, When, Where, Why)
4. **Post-mortem** : Comment éviter à l'avenir ?
5. **Corriger** processus

## 🛡️ Prévention

### 1. Organization Policy (Meilleure défense)

**Bloquer au niveau org** :

```bash
# Créer policy qui bloque allUsers et allAuthenticatedUsers
cat > policy.yaml <<EOF
constraint: constraints/iam.allowedPolicyMemberDomains
listPolicy:
  deniedValues:
    - allUsers
    - allAuthenticatedUsers
EOF

# Appliquer à l'organisation
gcloud resource-manager org-policies set-policy policy.yaml \
  --organization=YOUR_ORG_ID
```

Maintenant **impossible** de rendre un bucket public !

### 2. Bucket Default Settings

```bash
# Template de bucket sécurisé
gsutil mb -l us-central1 \
  -c STANDARD \
  -b on \  # Uniform bucket-level access
  gs://nouveau-bucket

# Par défaut : PRIVÉ
```

### 3. Automatisation Continue

```bash
# Cron quotidien
0 8 * * * /path/to/scan-public-buckets.sh --json > scan.json

# Alerter si problème
0 8 * * * /path/to/scan-public-buckets.sh --json | \
  jq -e '.summary.public_buckets > 0' && \
  curl -X POST $SLACK_WEBHOOK -d '{"text":"🚨 BUCKET PUBLIC DÉTECTÉ!"}'
```

### 4. Partage Sécurisé Alternatif

**Au lieu de bucket public, utilisez** :

#### Signed URLs (Temporaire)

```bash
# URL valide 1 heure
gsutil signurl -d 1h service-account-key.json gs://bucket/file.pdf

# Client télécharge via URL signée (pas besoin d'auth GCP)
```

#### Cloud CDN + Cloud Armor

```bash
# Pour contenus publics légitimes (images, CSS, JS)
# Protégé contre DDoS, avec contrôle géo, rate limiting
```

#### IAM Conditions

```bash
# Accès conditionnel (IP, heure, etc.)
gcloud storage buckets add-iam-policy-binding gs://bucket \
  --member="user:partner@example.com" \
  --role="roles/storage.objectViewer" \
  --condition="expression=request.time < timestamp('2024-12-31T23:59:59Z'),title=expires-end-of-year"
```

## 📅 Fréquence Recommandée

| Environnement | Fréquence |
|---------------|-----------|
| **Production** | **Quotidien** |
| **Staging** | Hebdomadaire |
| **Dev** | Hebdomadaire |

## 🔍 Troubleshooting

### "No buckets found" mais j'ai des buckets

**Causes** :
1. Permissions insuffisantes
2. Mauvais projet sélectionné

**Solution** :
```bash
# Vérifier permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:$(gcloud config get-value account)"

# Lister manuellement
gsutil ls -p PROJECT_ID
```

### Script très lent

**Cause** : Beaucoup de buckets (>1000)

**Solution** :
```bash
# Filtrer par projet
./scripts/scan-public-buckets.sh --project critical-project

# Désactiver calcul de taille (ligne à commenter dans script)
```

### Faux positifs ?

Certains buckets **doivent** être publics (ex: site web statique).

**Solution** : Whitelist

```bash
# Modifier script ou filtrer en post-processing
./scripts/scan-public-buckets.sh --json | \
  jq '.buckets[] | select(.bucket_name != "public-website-bucket")'
```

## 📚 Ressources

- [Cloud Storage IAM](https://cloud.google.com/storage/docs/access-control/iam)
- [Uniform Bucket-Level Access](https://cloud.google.com/storage/docs/uniform-bucket-level-access)
- [Signed URLs](https://cloud.google.com/storage/docs/access-control/signed-urls)
- [Organization Policies](https://cloud.google.com/resource-manager/docs/organization-policy/overview)
- [RGPD Guide](https://gdpr.eu/)

## 🎯 Checklist Conformité

- [ ] Aucun bucket public en production
- [ ] Organization policy bloque allUsers
- [ ] Uniform bucket-level access activé
- [ ] Scan quotidien automatisé
- [ ] Alerting configuré (Slack/Email)
- [ ] Procédure incident documentée
- [ ] Équipe formée (que faire si bucket public)
- [ ] Audit logs activés

## 💡 Cas d'Usage Légitimes

**Quand un bucket public est OK** :

1. **Site web statique** (HTML/CSS/JS/Images)
   - Mais préférer Cloud CDN + IAM si possible
2. **Assets publics** (logos, documentation publique)
   - Considérer CDN avec cache
3. **Datasets open source**
   - S'assurer aucune donnée sensible

**Même dans ces cas** :
- ✅ Documentation claire (pourquoi public)
- ✅ Revue trimestrielle
- ✅ Monitoring accès
- ✅ Pas de données sensibles

---

[⬅️ Audit SA Keys](Audit-Service-Account-Keys.md) | [🏠 Wiki](../HOME.md) | [➡️ List Cloud SQL](List-Cloud-SQL-Instances.md)
