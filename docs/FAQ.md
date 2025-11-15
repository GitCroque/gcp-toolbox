# ❓ FAQ - Questions Fréquentes

## 📦 Installation & Configuration

### Q: Quelle version de gcloud dois-je utiliser ?

**R:** La version la plus récente est recommandée. Minimum: **380.0.0**

```bash
# Vérifier version
gcloud version

# Mettre à jour
gcloud components update
```

### Q: Dois-je installer les scripts sur chaque machine ?

**R:** Non ! Clonez une fois, exécutez de n'importe où:

```bash
# Option 1: PATH
export PATH=$PATH:/path/to/carnet/scripts

# Option 2: Alias
alias gcp-audit='/path/to/carnet/scripts/scan-public-buckets.sh'

# Option 3: CI/CD (voir Automation.md)
```

### Q: Ça fonctionne sur Windows ?

**R:** Oui, via **WSL** (Windows Subsystem for Linux):

```powershell
# PowerShell (Admin)
wsl --install
wsl

# Dans WSL
curl https://sdk.cloud.google.com | bash
git clone https://github.com/VOTRE-REPO/carnet.git
```

## 🔐 Permissions & Sécurité

### Q: Quelles permissions GCP minimales ?

**R:** Dépend des scripts, mais en général:

**Niveau Organisation** (recommandé):
- `roles/viewer` - Lecture toutes ressources
- `roles/iam.securityReviewer` - Audits IAM
- `roles/billing.viewer` - Informations facturation

**Niveau Projet** (alternatif):
- Appliquer les mêmes rôles projet par projet

### Q: Les scripts modifient-ils mes ressources ?

**R:** **NON** ❌ Tous les scripts sont en **lecture seule**.

Aucun script ne:
- Supprime de ressources
- Modifie des configurations
- Change des IAM policies

C'est volontaire pour la sécurité.

### Q: Comment rotate mes clés de service account en sécurité ?

**R:** Procédure recommandée:

```bash
# 1. Créer nouvelle clé
gcloud iam service-accounts keys create new-key.json \
  --iam-account=SA_EMAIL@PROJECT.iam.gserviceaccount.com

# 2. Déployer nouvelle clé dans vos apps
# (Kubernetes secrets, Cloud Run, etc.)

# 3. Attendre propagation (24-48h)

# 4. Tester que ancienne clé n'est plus utilisée
# (Vérifier logs d'erreur)

# 5. Supprimer ancienne clé
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=SA_EMAIL@PROJECT.iam.gserviceaccount.com
```

### Q: Un bucket public, c'est grave ?

**R:** **OUI** 🔴 **TRÈS GRAVE**

Risques:
- **Data leak** - Données clients exposées
- **RGPD** - Violation possible, amendes
- **Réputation** - Perte de confiance
- **Coûts** - Bandwidth abuse possible

**Action immédiate** (< 5min):
```bash
gsutil iam ch -d allUsers gs://BUCKET_NAME
gsutil iam ch -d allAuthenticatedUsers gs://BUCKET_NAME
```

## 💰 Coûts & Optimisation

### Q: Les estimations de coûts sont-elles exactes ?

**R:** Non, ce sont des **approximations**:

- Basées sur prix **us-central1**
- N'incluent **PAS**: disques, réseau, licences
- Varient selon: région, usage réel, commits

**Pour coûts exacts**: Activez [export BigQuery](https://cloud.google.com/billing/docs/how-to/export-data-bigquery)

### Q: Combien puis-je vraiment économiser ?

**R:** Retours d'expérience moyens:

| Optimisation | Économies Typiques |
|---|---|
| Rightsizing VMs | 15-30% |
| Spot/Preemptible VMs | 60-91% |
| Committed Use Discounts (CUD) | 25-57% |
| Cleanup ressources inutilisées | 5-15% |
| Total combiné | **30-50%** 🎉 |

**Exemple réel**:
- Coûts initiaux: $10,000/mois
- Après optimisation: $6,000/mois
- **Économies: $4,000/mois = $48,000/an** 💰

### Q: Spot VMs vs Preemptible, quelle différence ?

**R:**

| Caractéristique | Preemptible | Spot |
|---|---|---|
| Économies | ~80% | **~91%** |
| Durée max | 24h | Aucune limite |
| Disponibilité | Bonne | Variable |
| Recommandation | Batch jobs | Workloads fault-tolerant |

Spot VMs = nouvelle génération de Preemptible

### Q: Comment implémenter CUD sans risque ?

**R:** Approche progressive:

**Mois 1**: Analyser usage
```bash
./scripts/list-all-vms.sh --json > vms.json
# Identifier VMs qui tournent 24/7 depuis >3 mois
```

**Mois 2**: CUD conservateur (50% de l'usage stable)
```bash
# Commit 1 an (25% saving)
gcloud compute commitments create my-commitment \
  --resources=vcpu=10,memory=40GB \
  --region=us-central1 \
  --plan=12-month
```

**Mois 3-6**: Ajuster si nécessaire

**Mois 7**: Évaluer CUD 3 ans (57% saving)

## 🔧 Troubleshooting

### Q: Script très lent (>5 min)

**R:** Causes possibles:

**1. Trop de projets** (>50)
```bash
# Solution: Filtrer
./scripts/SCRIPT.sh --project mon-projet
```

**2. Trop de ressources** (>500 VMs)
```bash
# Normal. Soyez patient ou:
# - Exécutez hors heures pointe
# - Utilisez mode JSON (plus rapide)
```

**3. Connexion lente**
```bash
# Vérifier latence GCP
ping -c 5 www.googleapis.com
```

### Q: "ERROR: (gcloud) You do not currently have an active account"

**R:**

```bash
# Ré-authentifier
gcloud auth login

# Vérifier
gcloud auth list

# Si service account
gcloud auth activate-service-account --key-file=key.json
```

### Q: "Permission denied" sur certains projets

**R:** Normal si:
- Vous n'avez pas accès à tous les projets de l'org
- Certains projets sont dans un autre org

**Solutions**:
```bash
# Option 1: Demander accès à l'admin
# Option 2: Filtrer les projets accessibles
gcloud projects list --filter="lifecycleState:ACTIVE"
```

### Q: Script retourne "0 results" mais j'ai des ressources

**R:** Vérifications:

```bash
# 1. Bon projet ?
gcloud config get-value project

# 2. Bonne région ?
gcloud compute instances list --zones=us-central1-a

# 3. API activée ?
gcloud services list --enabled | grep compute

# 4. Permissions ?
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:YOUR_EMAIL"
```

## 📊 Rapports & Exports

### Q: Comment créer un dashboard avec les données ?

**R:** Plusieurs options:

**Option 1: Google Sheets** (Simple)
```bash
# Export CSV
./scripts/list-all-vms.sh > vms.txt
# Import dans Sheets, créer graphiques
```

**Option 2: Data Studio** (Pro)
```bash
# 1. Export vers BigQuery
# 2. Connecter Data Studio à BigQuery
# 3. Créer dashboards interactifs
```

**Option 3: Grafana** (DevOps)
```bash
# 1. Scripts → Prometheus metrics
# 2. Grafana lit Prometheus
# 3. Dashboards temps réel
```

### Q: Format JSON vs format table ?

**R:**

**Format Table** (défaut):
- ✅ Lecture humaine facile
- ✅ Couleurs, résumés
- ❌ Difficile à parser

**Usage**: Audits manuels, debugging

**Format JSON** (`--json`):
- ✅ Facile à parser (`jq`, Python)
- ✅ Intégration CI/CD
- ❌ Moins lisible

**Usage**: Automatisation, analytics

**Exemple**:
```bash
# Table pour humain
./scripts/check-quotas.sh

# JSON pour machine
./scripts/check-quotas.sh --json | jq '.summary.quotas_over_threshold'
```

## 🔄 Automation & CI/CD

### Q: Comment intégrer dans Jenkins ?

**R:**

```groovy
// Jenkinsfile
pipeline {
    agent any
    triggers {
        cron('0 8 * * 1') // Lundi 8h
    }
    stages {
        stage('GCP Audit') {
            steps {
                sh '''
                    cd carnet
                    ./scripts/scan-public-buckets.sh > audit.log
                    if grep -q "CRITICAL" audit.log; then
                        exit 1
                    fi
                '''
            }
        }
    }
    post {
        failure {
            emailext (
                to: 'security@company.com',
                subject: 'GCP Security Alert',
                body: readFile('audit.log')
            )
        }
    }
}
```

### Q: Puis-je exécuter les scripts dans Cloud Run ?

**R:** **Oui !** Exemple:

```dockerfile
# Dockerfile
FROM google/cloud-sdk:alpine

WORKDIR /app
COPY scripts/ ./scripts/

# Endpoint HTTP qui exécute script
CMD ["sh", "-c", "./scripts/scan-public-buckets.sh"]
```

```bash
# Deploy
gcloud run deploy gcp-audit \
  --source . \
  --region us-central1 \
  --no-allow-unauthenticated

# Trigger avec Cloud Scheduler
gcloud scheduler jobs create http weekly-audit \
  --schedule="0 8 * * 1" \
  --uri=https://YOUR-SERVICE-url.run.app \
  --http-method=GET \
  --oidc-service-account-email=SA@PROJECT.iam.gserviceaccount.com
```

## 🌍 Multi-Organisation

### Q: J'ai plusieurs orgs GCP, comment gérer ?

**R:**

```bash
#!/bin/bash
# multi-org-audit.sh

ORGS=("org1" "org2" "org3")

for org in "${ORGS[@]}"; do
    echo "=== Audit $org ==="

    # Switch config
    gcloud config configurations activate $org

    # Audit
    ./scripts/scan-public-buckets.sh > report-$org.txt
done
```

### Q: Comment partager les scripts avec mon équipe ?

**R:** Plusieurs approches:

**1. Repository Git interne**
```bash
git clone https://github.com/VOTRE-COMPANY/carnet.git
```

**2. Docker image partagée**
```dockerfile
FROM google/cloud-sdk:alpine
RUN git clone https://github.com/VOTRE-COMPANY/carnet.git /carnet
WORKDIR /carnet
```

**3. GCS bucket partagé**
```bash
gsutil cp -r scripts/ gs://company-tools/carnet/
# Team télécharge depuis GCS
```

## 🚀 Contribution

### Q: Je veux ajouter un nouveau script, comment faire ?

**R:** Voir [CONTRIBUTING.md](../CONTRIBUTING.md), mais en résumé:

1. Fork le repo
2. Créer branche: `git checkout -b feature/mon-script`
3. Développer en suivant [structure standard](../CONTRIBUTING.md#structure-dun-script)
4. Tester sur dev project
5. Documenter dans wiki
6. Pull Request

### Q: J'ai trouvé un bug, quoi faire ?

**R:**

1. **Vérifier** que c'est reproductible
2. **Chercher** dans [Issues existantes](https://github.com/VOTRE-REPO/carnet/issues)
3. **Ouvrir nouvelle issue** avec:
   - Description du problème
   - Steps to reproduce
   - Environnement (OS, gcloud version)
   - Logs pertinents (sans secrets !)

## 📚 Ressources

### Q: Où apprendre plus sur GCP ?

**R:** Ressources officielles:

- [GCP Documentation](https://cloud.google.com/docs)
- [Best Practices](https://cloud.google.com/docs/enterprise/best-practices-for-enterprise-organizations)
- [Pricing Calculator](https://cloud.google.com/products/calculator)
- [Free Tier](https://cloud.google.com/free)

Cours:
- [Coursera - Google Cloud](https://www.coursera.org/googlecloud)
- [Qwiklabs](https://www.qwiklabs.com/)
- [Cloud Skills Boost](https://www.cloudskillsboost.google/)

### Q: Existe-t-il des alternatives à ces scripts ?

**R:** Oui, plusieurs outils:

| Outil | Type | Avantages | Inconvénients |
|---|---|---|---|
| **Carnet** (ces scripts) | CLI Open Source | Gratuit, personnalisable | Basique, manuel |
| Cloud Asset Inventory | GCP natif | Intégré, complet | Complexe à query |
| Forseti Security | Open Source | Complet, automatique | Setup complexe |
| Cloudhealth | Commercial | UI jolie, analytics | $$$ (~1% facture GCP) |
| CloudCheckr | Commercial | Multi-cloud | $$$ |
| Spot by NetApp | Commercial | Optimisation auto | $$$ |

**Carnet est idéal si**:
- Budget limité (gratuit !)
- Besoin de personnalisation
- Préférence pour scripts légers
- Learning opportunity

---

**Votre question n'est pas listée ?**

- 💬 [Ouvrir une Discussion GitHub](https://github.com/VOTRE-REPO/carnet/discussions)
- 📧 Email: support@votre-domaine.com
- 📖 [Documentation Complète](HOME.md)

---

[⬅️ Troubleshooting](Troubleshooting.md) | [🏠 Wiki Home](HOME.md)
