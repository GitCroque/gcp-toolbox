# 🌐 Scan Exposed Services

**Script** : `scan-exposed-services.sh`
**Priorité** : 🔴 CRITIQUE
**Catégorie** : Cybersécurité

## 🎯 Objectif

Scanner les **services exposés publiquement** (VMs avec IP publiques, Load Balancers) pour réduire la surface d'attaque et améliorer la sécurité.

## ⚠️ Pourquoi c'est CRITIQUE ?

### Le Problème

- **Chaque IP publique** = Point d'entrée potentiel pour attaquants
- **VM avec IP publique** = Target constant de scanners automatisés
- **Principe Zero Trust** : Minimiser exposition publique

### Best Practice

**❌ Mauvais** : Toutes les VMs ont IP publique
**✅ Bon** : VMs en Private IP + Cloud NAT pour sortie Internet

## 📊 Que détecte le script ?

1. ✅ **VMs avec IP publique** : Liste toutes les VMs exposées
2. ✅ **Load Balancers** : Inventaire LBs (normal qu'ils soient publics)
3. ✅ **Recommandations** : Utiliser Private IP, Cloud NAT, IAP

## 🚀 Utilisation

```bash
# Scanner tous les services exposés
./scripts/scan-exposed-services.sh

# Un projet spécifique
./scripts/scan-exposed-services.sh --project prod-app

# Export JSON
./scripts/scan-exposed-services.sh --json > exposed.json
```

## 📈 Exemple Sortie

```
========================================
  🌐 Scan Services Exposés
========================================

=== VMs avec IP Publique ===

PROJECT                   VM_NAME                        ZONE                 PUBLIC_IP
-------                   -------                        ----                 ---------
prod-app                  bastion                        us-central1-a        35.1.2.3
dev-env                   test-vm-1                      us-west1-a           34.2.3.4

=== Load Balancers ===

PROJECT                   LB_NAME                        IP_ADDRESS
-------                   -------                        ----------
prod-app                  web-lb                         35.200.1.2

=== Résumé ===
VMs avec IP publique:      2
Load Balancers:            1

⚠️  Recommandations:
- Utiliser Private Google Access quand possible
- Implémenter Cloud NAT pour VMs privées
- Utiliser Identity-Aware Proxy pour accès SSH
```

## 🔧 Remédiation : Migrer vers Private IP

### Étape 1 : Nouvelle VM sans IP publique

```bash
# Créer VM SANS IP publique
gcloud compute instances create my-private-vm \
  --zone=us-central1-a \
  --machine-type=n1-standard-1 \
  --network-interface=subnet=default,no-address \
  --metadata=enable-oslogin=true

# ✅ VM accessible uniquement via VPC interne
```

### Étape 2 : Cloud NAT (pour accès Internet sortant)

```bash
# Créer Cloud Router
gcloud compute routers create nat-router \
  --network=default \
  --region=us-central1

# Créer Cloud NAT
gcloud compute routers nats create nat-config \
  --router=nat-router \
  --region=us-central1 \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges

# ✅ VMs privées peuvent accéder Internet (sortie uniquement)
```

### Étape 3 : Accès SSH via IAP

```bash
# SSH sur VM SANS IP publique
gcloud compute ssh my-private-vm \
  --zone=us-central1-a \
  --tunnel-through-iap

# ✅ Pas besoin d'IP publique !
```

## 🛡️ Architecture Recommandée

```
Internet
    ↓
[Cloud Load Balancer] ← Seul point d'entrée public
    ↓
[VMs Backend - Private IP]
    ↓
[Cloud SQL - Private IP]

Accès admin:
[IAP Tunnel] → [VMs Private]
```

## 💰 Bénéfices

- 🛡️ **Sécurité** : Réduction surface d'attaque
- 💰 **Coûts** : IP publiques statiques = $7/mois chacune
- 🔒 **Compliance** : Meilleure posture sécurité

---

[⬅️ Audit Firewall](Audit-Firewall-Rules.md) | [🏠 Wiki](../HOME.md)
