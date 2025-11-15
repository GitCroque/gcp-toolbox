# 🔥 Audit Firewall Rules

**Script** : `audit-firewall-rules.sh`
**Priorité** : 🔴 CRITIQUE
**Catégorie** : Cybersécurité

## 🎯 Objectif

Audite les **règles de firewall VPC** pour détecter les configurations dangereuses qui exposent votre infrastructure à des attaques (0.0.0.0/0, ports sensibles ouverts).

## ⚠️ Pourquoi c'est CRITIQUE ?

### Le Danger : Firewall Trop Permissif

**Une seule règle mal configurée = Porte d'entrée pour attaquants**

### Incidents Réels

**Cas 1 : Capital One (2019)**
- Firewall mal configuré sur AWS
- **Donnée exposée** : 100M clients
- **Amende** : $80M
- **Cause** : Règle firewall trop permissive

**Cas 2 : Uber (2016)**
- Port MongoDB exposé à Internet
- **Donnée volée** : 57M utilisateurs
- **Coût** : $148M settlement
- **Cause** : Firewall 0.0.0.0/0 sur port 27017

**Cas 3 : Attaques Ransomware**
- RDP (port 3389) exposé → Entrée ransomware
- 90% des ransomwares entrent par RDP/SSH exposés

### Vecteurs d'Attaque Courants

| Port | Service | Risque si exposé 0.0.0.0/0 |
|------|---------|----------------------------|
| **22** | SSH | Brute force, credential stuffing |
| **3389** | RDP | Ransomware, brute force |
| **3306** | MySQL | Data exfiltration, injection SQL |
| **5432** | PostgreSQL | Data breach |
| **6379** | Redis | RCE (Remote Code Execution) |
| **27017** | MongoDB | Data leak |
| **9200** | Elasticsearch | Data exposure |

## 📊 Que détecte le script ?

### Niveaux de Risque

| Risque | Condition | Gravité |
|--------|-----------|---------|
| 🔴 **CRITICAL** | SSH/RDP exposé à Internet (0.0.0.0/0) | Immediate action |
| 🔴 **CRITICAL** | ALL protocols exposés (0.0.0.0/0) | Immediate action |
| 🟣 **HIGH** | DB ports exposés à Internet | Action < 24h |
| 🟡 **MEDIUM** | Autres ports exposés à Internet | Review |
| 🟢 **LOW** | Règles restreintes (IP spécifiques) | OK |

### Détection

Pour chaque règle firewall :

1. ✅ **Source ranges** : Vérifie si 0.0.0.0/0 (Internet)
2. ✅ **Ports exposés** : Identifie ports sensibles
3. ✅ **Direction** : Ingress (entrant) vs Egress
4. ✅ **Calcule risque** : CRITICAL, HIGH, MEDIUM, LOW
5. ✅ **Alerte** : Liste règles dangereuses

## 🚀 Utilisation

### Basique

```bash
# Auditer toutes les règles firewall
./scripts/audit-firewall-rules.sh

# Affiche UNIQUEMENT les règles à risque
```

### Options

```bash
# Un seul projet
./scripts/audit-firewall-rules.sh --project mon-projet-prod

# Export JSON
./scripts/audit-firewall-rules.sh --json > firewall-audit.json
```

### Analyse avec jq

```bash
# Règles CRITICAL uniquement
./scripts/audit-firewall-rules.sh --json | \
  jq '.firewall_rules[] | select(.risk_level == "CRITICAL")'

# Compter par niveau de risque
./scripts/audit-firewall-rules.sh --json | \
  jq '.summary'
```

## 📈 Exemple de Sortie

### Format Table

```
========================================
  🔥 Audit Firewall Rules
========================================

PROJECT                   RULE_NAME                 DIRECTION       SOURCE_RANGES        PORTS           RISK_LEVEL
-------                   ---------                 ---------       -------------        -----           ----------
prod-app                  allow-ssh-all             INGRESS         0.0.0.0/0            tcp:22          CRITICAL
prod-app                  allow-db-public           INGRESS         0.0.0.0/0            tcp:3306        HIGH
dev-env                   allow-all                 INGRESS         0.0.0.0/0            all             CRITICAL

=== Résumé ===
Total règles:          42
Risque CRITICAL:       8
Risque HIGH:           5
Risque MEDIUM:         12
Risque LOW:            17

⚠️  8 règle(s) CRITIQUES détectées !

=== Recommandations ===
1. URGENT: Restreindre SSH/RDP (utiliser Cloud IAP ou VPN)
2. Limiter les source ranges (utiliser IP spécifiques)
3. Utiliser Identity-Aware Proxy pour accès admin
4. Activer VPC Service Controls
```

### Format JSON

```json
{
  "generated_at": "2024-11-15T10:30:00Z",
  "firewall_rules": [
    {
      "project": "prod-app",
      "rule": "allow-ssh-all",
      "direction": "INGRESS",
      "source_ranges": "0.0.0.0/0",
      "allowed": "tcp:22",
      "risk_level": "CRITICAL"
    }
  ],
  "summary": {
    "total": 42,
    "critical": 8,
    "high": 5,
    "medium": 12,
    "low": 17
  }
}
```

## 🔧 Remédiation URGENTE

### Si règle CRITICAL détectée (SSH/RDP exposé)

#### Option 1 : Identity-Aware Proxy (IAP) - RECOMMANDÉ ✅

**Remplace** : SSH direct depuis Internet
**Par** : Accès via IAP (authentification Google)

```bash
PROJECT_ID="prod-app"
RULE_NAME="allow-ssh-all"

# 1. SUPPRIMER règle dangereuse
gcloud compute firewall-rules delete $RULE_NAME \
  --project=$PROJECT_ID \
  --quiet

# 2. CRÉER règle IAP (source = IAP IP ranges)
gcloud compute firewall-rules create allow-ssh-from-iap \
  --project=$PROJECT_ID \
  --direction=INGRESS \
  --priority=1000 \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=35.235.240.0/20 \
  --description="Allow SSH via Cloud IAP"

# 3. Se connecter via IAP
gcloud compute ssh VM_NAME \
  --project=$PROJECT_ID \
  --zone=us-central1-a \
  --tunnel-through-iap

# ✅ Authentification Google requise !
```

**Avantages IAP** :
- ✅ Pas de VPN à gérer
- ✅ Authentification Google (MFA)
- ✅ Logs d'accès dans Cloud Logging
- ✅ Pas d'IP publique requise sur VM

#### Option 2 : VPN

```bash
# Créer Cloud VPN
gcloud compute vpn-tunnels create office-vpn \
  --project=$PROJECT_ID \
  --region=us-central1 \
  --peer-address=OFFICE_PUBLIC_IP \
  --shared-secret="SECRET"

# Firewall: Autoriser UNIQUEMENT depuis VPN subnet
gcloud compute firewall-rules create allow-ssh-from-vpn \
  --project=$PROJECT_ID \
  --direction=INGRESS \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=10.0.0.0/24 \
  --description="SSH via VPN only"
```

#### Option 3 : IP Whitelisting (Temporaire)

```bash
# Autoriser UNIQUEMENT IPs de bureau
OFFICE_IP="203.0.113.0/24"

gcloud compute firewall-rules update allow-ssh-all \
  --project=$PROJECT_ID \
  --source-ranges=$OFFICE_IP \
  --description="SSH from office only"

# ⚠️ Moins sécurisé qu'IAP, mais mieux que 0.0.0.0/0
```

### Si DB port exposé (MySQL/PostgreSQL)

```bash
# CRITIQUE : DB JAMAIS exposée à Internet !

# 1. Supprimer règle
gcloud compute firewall-rules delete allow-db-public \
  --project=$PROJECT_ID \
  --quiet

# 2. Utiliser Private IP
# Configurer Cloud SQL avec Private IP uniquement
gcloud sql instances patch DB_INSTANCE \
  --project=$PROJECT_ID \
  --network=projects/$PROJECT_ID/global/networks/default \
  --no-assign-ip

# 3. Si accès externe nécessaire : Cloud SQL Proxy
gcloud compute ssh bastion-vm \
  --project=$PROJECT_ID \
  --command="cloud_sql_proxy -instances=$PROJECT_ID:us-central1:DB_INSTANCE=tcp:3306"
```

## 🛡️ Best Practices Firewall

### ✅ À FAIRE

1. **Deny by Default** : Bloquer tout, autoriser seulement nécessaire
   ```bash
   # Créer règle deny-all en priorité basse
   gcloud compute firewall-rules create deny-all-ingress \
     --direction=INGRESS \
     --priority=65534 \
     --network=default \
     --action=DENY \
     --rules=all
   ```

2. **Identity-Aware Proxy** : Pour SSH/RDP
3. **Private IP** : VMs sans IP publique
4. **Source Tags/Service Accounts** : Au lieu de source ranges
   ```bash
   # Autoriser seulement VMs avec tag "web"
   gcloud compute firewall-rules create allow-web-to-db \
     --direction=INGRESS \
     --network=default \
     --action=ALLOW \
     --rules=tcp:3306 \
     --source-tags=web-tier \
     --target-tags=db-tier
   ```

5. **VPC Service Controls** : Périmètre de sécurité
6. **Logs activés** : Pour audit
   ```bash
   gcloud compute firewall-rules update RULE_NAME \
     --enable-logging
   ```

7. **Review régulier** : Mensuel minimum

### ❌ À ÉVITER

1. ❌ **0.0.0.0/0** sur ports sensibles (SSH, RDP, DB)
2. ❌ **allow-all** en production
3. ❌ Firewall rules sans description
4. ❌ Règles jamais revues depuis création
5. ❌ Utiliser IP publiques quand pas nécessaire
6. ❌ Désactiver logs (économie minime, visibilité perdue)
7. ❌ Copier-coller règles sans comprendre

## 🔍 Règles Firewall par Cas d'Usage

### Web Application (Public)

```bash
# Load Balancer → Web Tier (OK d'être public)
gcloud compute firewall-rules create allow-http-https \
  --direction=INGRESS \
  --network=default \
  --action=ALLOW \
  --rules=tcp:80,tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=web-tier \
  --description="Allow HTTP/HTTPS from Internet"

# Web Tier → App Tier (INTERNE uniquement)
gcloud compute firewall-rules create allow-web-to-app \
  --direction=INGRESS \
  --network=default \
  --action=ALLOW \
  --rules=tcp:8080 \
  --source-tags=web-tier \
  --target-tags=app-tier \
  --description="Web to App internal"

# App Tier → DB Tier (INTERNE uniquement)
gcloud compute firewall-rules create allow-app-to-db \
  --direction=INGRESS \
  --network=default \
  --action=ALLOW \
  --rules=tcp:3306 \
  --source-tags=app-tier \
  --target-tags=db-tier \
  --description="App to DB internal"
```

### Administration (SSH/RDP)

```bash
# Via IAP (RECOMMANDÉ)
gcloud compute firewall-rules create allow-ssh-iap \
  --direction=INGRESS \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=35.235.240.0/20 \
  --description="SSH via IAP"

# Via Bastion (Alternatif)
gcloud compute firewall-rules create allow-ssh-to-bastion \
  --direction=INGRESS \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=OFFICE_IP/32 \
  --target-tags=bastion \
  --description="SSH to bastion from office"

gcloud compute firewall-rules create allow-bastion-to-all \
  --direction=INGRESS \
  --network=default \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-tags=bastion \
  --description="Bastion can SSH to all VMs"
```

## 📅 Fréquence Recommandée

| Action | Fréquence |
|--------|-----------|
| **Audit complet** | Mensuel |
| **Review règles CRITICAL** | Immédiat (dès détection) |
| **Cleanup règles obsolètes** | Trimestriel |
| **Formation équipe** | Annuel |

## 📚 Ressources

- [VPC Firewall Rules](https://cloud.google.com/vpc/docs/firewalls)
- [Identity-Aware Proxy](https://cloud.google.com/iap/docs)
- [VPC Service Controls](https://cloud.google.com/vpc-service-controls/docs)
- [Firewall Best Practices](https://cloud.google.com/architecture/best-practices-vpc-design)

## 🎯 Checklist Sécurité Firewall

- [ ] Aucune règle SSH/RDP avec 0.0.0.0/0
- [ ] IAP configuré pour accès admin
- [ ] Aucun port DB exposé à Internet
- [ ] Logs activés sur règles critiques
- [ ] Tags utilisés (pas seulement IP ranges)
- [ ] Descriptions sur toutes les règles
- [ ] Deny-all rule en priorité basse
- [ ] Review mensuel planifié
- [ ] Alerting configuré (Cloud Monitoring)
- [ ] VPC Service Controls (si applicable)

---

[⬅️ Notify Project Owners](Notify-Project-Owners.md) | [🏠 Wiki](../HOME.md) | [➡️ Scan Exposed Services](Scan-Exposed-Services.md)
