# ☸️ List GKE Clusters

**Script** : `list-gke-clusters.sh`
**Priorité** : 🟢 UTILE
**Catégorie** : Inventaire & Monitoring

## 🎯 Objectif

Inventorie tous vos clusters **Google Kubernetes Engine (GKE)** avec leur configuration, nombre de nodes, et mode (Autopilot vs Standard).

## 💡 Pourquoi c'est UTILE ?

### Visibilité GKE

Kubernetes est complexe. Vous devez savoir :

- 📊 **Combien** de clusters vous avez
- 🤖 **Lesquels** sont Autopilot (managed) vs Standard (self-managed)
- 💰 **Combien de nodes** (impacte coûts)
- 🔄 **Quelles versions** K8s (security patching)
- 🌍 **Où** ils sont déployés (latence, compliance)

### GKE Sprawl Problem

**Scénario classique** :

```
✅ Production:      1 cluster GKE (multi-tenant, bien géré)
⚠️  Staging:        1 cluster GKE
❌ Dev:             12 clusters GKE (un par dev qui teste...)
❌ CI/CD:           3 clusters GKE (pipelines)
❌ Oubliés:         5 clusters GKE (projets archivés)

Total: 22 clusters
Coût mensuel: $15,000
Coût optimal: $3,000
```

**Waste** : $12,000/mois = $144,000/an !

## 📊 Que liste le script ?

### Informations Par Cluster

1. ✅ **Projet** : GCP project ID
2. ✅ **Nom** : Cluster name
3. ✅ **Location** : Zone ou région
4. ✅ **Version K8s** : Ex: 1.28.3-gke.1286000
5. ✅ **Nombre de nodes** : Total nodes actifs
6. ✅ **Mode** : Autopilot ou Standard

### Résumé Global

- Total clusters
- Total nodes (toutes les machines)
- Nombre Autopilot vs Standard

## 🚀 Utilisation

### Basique

```bash
# Liste tous les clusters GKE
./scripts/list-gke-clusters.sh

# Affiche table formatée
```

### Options

```bash
# Un seul projet
./scripts/list-gke-clusters.sh --project mon-projet-prod

# Export JSON
./scripts/list-gke-clusters.sh --json > gke.json
```

### Analyse avec jq

```bash
# Clusters Standard uniquement
./scripts/list-gke-clusters.sh --json | \
  jq '.clusters[] | select(.mode == "Standard")'

# Total nodes par projet
./scripts/list-gke-clusters.sh --json | \
  jq 'group_by(.project) | map({project: .[0].project, total_nodes: map(.nodes) | add})'

# Clusters avec version K8s < 1.27
./scripts/list-gke-clusters.sh --json | \
  jq '.clusters[] | select(.version | startswith("1.26") or startswith("1.25"))'
```

## 📈 Exemple de Sortie

### Format Table

```
======================================
  ☸️  GKE Clusters
======================================

Récupération des clusters GKE...

PROJECT                   CLUSTER                   LOCATION        VERSION         NODES      MODE
-------                   -------                   --------        -------         -----      ----
prod-app                  prod-main                 us-central1     1.28.3-gke.1    12         Autopilot
staging                   staging-cluster           us-central1-a   1.27.5-gke.2    5          Standard
dev-env                   dev-test-1                us-west1-a      1.28.0-gke.0    3          Standard
dev-env                   dev-test-2                us-west1-b      1.26.8-gke.1    2          Standard

=== Résumé ===
Total clusters:         4
Total nodes:            22
Autopilot clusters:     1
Standard clusters:      3
```

### Format JSON

```json
{
  "generated_at": "2024-11-15T10:30:00Z",
  "clusters": [
    {
      "project": "prod-app",
      "name": "prod-main",
      "location": "us-central1",
      "version": "1.28.3-gke.1286000",
      "nodes": 12,
      "mode": "Autopilot"
    },
    {
      "project": "staging",
      "name": "staging-cluster",
      "location": "us-central1-a",
      "version": "1.27.5-gke.200",
      "nodes": 5,
      "mode": "Standard"
    }
  ],
  "summary": {
    "total": 4,
    "total_nodes": 22,
    "autopilot": 1,
    "standard": 3
  }
}
```

## 🤖 Autopilot vs Standard

### Autopilot (Recommandé)

**Google gère** :
- ✅ Nodes (sizing, upgrades, patching)
- ✅ Networking
- ✅ Security
- ✅ Scaling

**Vous gérez** :
- Déploiement workloads (pods)
- Configuration apps

**Pricing** :
- Pay-per-pod (vCPU/RAM utilisés)
- Plus cher par node, mais optimisé automatiquement
- **Généralement moins cher au total** (pas de waste)

**Quand utiliser** :
- ✅ 90% des cas
- ✅ Nouveaux clusters
- ✅ Équipes petites/moyennes
- ✅ Workloads standards

### Standard (Self-Managed)

**Vous gérez** :
- ⚙️ Nodes (machine types, upgrades)
- ⚙️ Node pools
- ⚙️ Autoscaling config
- ⚙️ Security hardening

**Pricing** :
- Pay-per-node (GCE instances)
- Contrôle total sur sizing

**Quand utiliser** :
- Workloads spécifiques (GPUs, high-mem)
- Contrôle fin requis
- Optimisation coûts avancée
- Équipes SRE matures

### Migration Standard → Autopilot

```bash
# Créer nouveau cluster Autopilot
gcloud container clusters create-auto my-cluster-autopilot \
  --project=$PROJECT_ID \
  --region=us-central1

# Migrer workloads (via kubectl)
kubectl config use-context OLD_CLUSTER
kubectl get all --all-namespaces -o yaml > backup.yaml

kubectl config use-context NEW_AUTOPILOT_CLUSTER
kubectl apply -f backup.yaml

# Valider, puis supprimer ancien cluster
gcloud container clusters delete OLD_STANDARD_CLUSTER --project=$PROJECT_ID
```

**Économie attendue** : 20-40% sur coûts GKE

## 🔧 Actions Recommandées

### Cleanup Clusters Inutilisés

```bash
# Identifier clusters sans pods actifs
for cluster in $(gcloud container clusters list --format='value(name)'); do
  echo "=== $cluster ==="
  gcloud container clusters get-credentials $cluster
  kubectl get pods --all-namespaces --no-headers | wc -l
done

# Si 0 pods ou seulement system pods : candidat suppression
```

### Upgrade Versions K8s

```bash
# Lister versions disponibles
gcloud container get-server-config \
  --region=us-central1 \
  --format="yaml(validMasterVersions)"

# Upgrade cluster
gcloud container clusters upgrade CLUSTER_NAME \
  --project=$PROJECT_ID \
  --master \
  --cluster-version=1.28.3-gke.1286000

# Upgrade nodes (après master)
gcloud container clusters upgrade CLUSTER_NAME \
  --project=$PROJECT_ID \
  --node-pool=default-pool

# ⚠️ Teste en staging d'abord !
```

**Best Practice** : Rester dans les **3 dernières versions** (support Google)

### Consolidation

**Avant** :
```
dev-cluster-1:  3 nodes (2 pods)   - $200/mois
dev-cluster-2:  3 nodes (1 pod)    - $200/mois
dev-cluster-3:  3 nodes (3 pods)   - $200/mois
Total:          9 nodes, 6 pods    - $600/mois
```

**Après** :
```
dev-cluster-multi-tenant: 3 nodes (6 pods) - $200/mois
Économie: $400/mois = $4,800/an
```

```bash
# Utiliser namespaces au lieu de clusters
kubectl create namespace team-alpha
kubectl create namespace team-beta
kubectl create namespace team-gamma

# Isolation via RBAC
kubectl create rolebinding team-alpha-admin \
  --clusterrole=admin \
  --user=dev@company.com \
  --namespace=team-alpha
```

## 📊 Coûts GKE

### Standard Mode

**Coût = Control Plane + Nodes**

```
Control Plane: $0.10/heure = $73/mois (cluster fee)
Nodes:         Prix GCE standard
  - n1-standard-1: $25/mois par node
  - n1-standard-4: $100/mois par node

Exemple (5 nodes n1-standard-1):
  $73 (control plane) + 5×$25 (nodes) = $198/mois
```

### Autopilot Mode

**Coût = vCPU/RAM utilisés par pods**

```
vCPU: $0.044/vCPU/hour = $32/vCPU/mois
RAM:  $0.005/GB/hour   = $3.6/GB/mois

Exemple (10 pods × 0.5 vCPU × 1 GB RAM):
  (10 × 0.5 × $32) + (10 × 1 × $3.6) = $160 + $36 = $196/mois
```

**Généralement moins cher** grâce à :
- Bin packing optimal
- Pas de nodes idle
- Scale-to-zero sur namespaces

## 🔄 Multi-Cluster Management

### Connecter à un Cluster

```bash
# Get credentials
gcloud container clusters get-credentials CLUSTER_NAME \
  --project=$PROJECT_ID \
  --region=us-central1

# Vérifier connexion
kubectl get nodes
```

### Switch Entre Clusters

```bash
# Lister contextes kubectl
kubectl config get-contexts

# Switcher
kubectl config use-context gke_PROJECT_CLUSTER_REGION

# Ou utiliser alias
alias k-prod='kubectl config use-context gke_prod-app_us-central1_prod-main'
alias k-dev='kubectl config use-context gke_dev-env_us-west1_dev-cluster'
```

### Multi-Cluster avec Anthos

```bash
# Gestion centralisée de plusieurs clusters
# Via Anthos Config Management, Service Mesh, etc.

# Enregistrer cluster dans Anthos fleet
gcloud container fleet memberships register CLUSTER_NAME \
  --gke-cluster=REGION/CLUSTER_NAME \
  --enable-workload-identity
```

## 🛡️ Sécurité GKE

### Hardening Checklist

```bash
# 1. Workload Identity (pas de service account keys!)
gcloud container clusters update CLUSTER_NAME \
  --workload-pool=$PROJECT_ID.svc.id.goog

# 2. Binary Authorization (seulement images signées)
gcloud container clusters update CLUSTER_NAME \
  --enable-binauthz

# 3. Private Cluster (nodes sans IP publiques)
gcloud container clusters create CLUSTER_NAME \
  --enable-private-nodes \
  --enable-private-endpoint \
  --master-ipv4-cidr=172.16.0.0/28

# 4. Network Policies (isolation pods)
gcloud container clusters update CLUSTER_NAME \
  --enable-network-policy

# 5. Shielded Nodes (secure boot, vTPM)
gcloud container clusters update CLUSTER_NAME \
  --enable-shielded-nodes
```

### RBAC Best Practices

```bash
# Principe du moindre privilège
# ❌ Pas de cluster-admin sauf SRE
# ✅ Namespaced roles

# Exemple: dev read-only sur namespace
kubectl create rolebinding dev-viewer \
  --clusterrole=view \
  --user=dev@company.com \
  --namespace=development
```

## 📅 Fréquence Recommandée

| Action | Fréquence |
|--------|-----------|
| **Inventaire** | Mensuel |
| **Version check** | Mensuel |
| **Upgrade K8s** | Trimestriel (rester < 3 versions derrière latest) |
| **Cleanup** | Trimestriel |
| **Security audit** | Trimestriel |
| **Cost review** | Mensuel |

## 🔍 Troubleshooting

### Cluster inaccessible

```bash
# Vérifier statut cluster
gcloud container clusters describe CLUSTER_NAME \
  --project=$PROJECT_ID \
  --region=us-central1

# Rafraîchir credentials
gcloud container clusters get-credentials CLUSTER_NAME \
  --project=$PROJECT_ID \
  --region=us-central1
```

### Nodes bloqués en "NotReady"

```bash
# Lister nodes
kubectl get nodes

# Détails sur node problématique
kubectl describe node NODE_NAME

# Logs system pods
kubectl logs -n kube-system POD_NAME

# Souvent: upgrade en cours, disk full, ou network issue
```

### Coûts GKE élevés

**Debug** :

```bash
# 1. Vérifier nombre de nodes
kubectl get nodes

# 2. Vérifier utilisation pods
kubectl top nodes
kubectl top pods --all-namespaces

# 3. Si nodes sous-utilisés → downsize ou consolidate
```

## 📚 Ressources

- [GKE Overview](https://cloud.google.com/kubernetes-engine/docs)
- [Autopilot vs Standard](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [GKE Security](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
- [GKE Pricing](https://cloud.google.com/kubernetes-engine/pricing)

## 🎯 Checklist Cluster Production

- [ ] **Mode** : Autopilot (sauf besoin spécifique)
- [ ] **Version** : K8s supporté (< 3 versions derrière latest)
- [ ] **Region** : Multi-zonal ou regional (HA)
- [ ] **Workload Identity** : Activé
- [ ] **Private Cluster** : Activé (nodes sans IP publiques)
- [ ] **Binary Authorization** : Activé
- [ ] **Network Policies** : Activées
- [ ] **Shielded Nodes** : Activés
- [ ] **Logging/Monitoring** : Cloud Logging + Monitoring activés
- [ ] **RBAC** : Configuré (least privilege)
- [ ] **Namespaces** : Organisés par env/team
- [ ] **Resource Quotas** : Définis par namespace
- [ ] **Pod Security Policies** : Configurées
- [ ] **Backup** : Velero ou équivalent configuré

## 💰 Optimisation Coûts GKE

### Quick Wins

**1. Migrer vers Autopilot**
```bash
# Économie: 20-40%
# Voir section "Migration Standard → Autopilot"
```

**2. Node Auto-Scaling (Standard mode)**
```bash
gcloud container clusters update CLUSTER_NAME \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=10

# Scale-down automatique la nuit/weekend
```

**3. Spot Nodes (Standard mode)**
```bash
# Jusqu'à 91% moins cher pour workloads tolerant interruptions
gcloud container node-pools create spot-pool \
  --cluster=CLUSTER_NAME \
  --spot \
  --num-nodes=3
```

**4. Bin Packing Optimization**
```bash
# Utiliser Cluster Autoscaler pour optimiser placement pods
# Activer priorities & preemption
```

**5. Cleanup Resources**
```bash
# Supprimer LoadBalancers inutilisés (coûtent cher!)
kubectl get svc --all-namespaces | grep LoadBalancer

# Supprimer PersistentVolumes non utilisés
kubectl get pv
```

---

[⬅️ List Cloud SQL](List-Cloud-SQL-Instances.md) | [🏠 Wiki](../HOME.md) | [➡️ Find Unused Resources](Find-Unused-Resources.md)
