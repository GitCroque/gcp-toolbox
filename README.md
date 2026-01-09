# 🔧 GCP Toolbox

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![GCP](https://img.shields.io/badge/Cloud-Google%20Cloud-4285F4.svg)](https://cloud.google.com/)
[![Scripts](https://img.shields.io/badge/Scripts-30-brightgreen.svg)]()
[![Documentation](https://img.shields.io/badge/Docs-Wiki-blue.svg)](https://github.com/GitCroque/gcp-toolbox/wiki)

**Collection of 30 Bash scripts to audit, secure, and optimize Google Cloud Platform.**

---

## 🎯 What is this repository for?

This repository contains **practical shell scripts** to manage your Google Cloud Platform infrastructure:

- 🔐 **Security**: detect public buckets, old keys, dangerous firewall rules
- 💰 **Cost optimization**: identify unused resources, rightsizing opportunities
- 📦 **Inventory**: list VMs, databases, Kubernetes clusters
- 🏛️ **Governance**: verify labels, contact project owners, manage project lifecycle

**Philosophy**: manual execution on demand, you keep full control.

---

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/GitCroque/gcp-toolbox.git
cd gcp-toolbox

# 2. Initial setup
make setup

# 3. GCP authentication
gcloud auth login

# 4. Run your first audit
./scripts/scan-public-buckets.sh
./scripts/list-all-vms.sh
```

---

## 📊 Main Scripts

### 🔴 Critical Security

```bash
./scripts/scan-public-buckets.sh           # Publicly exposed buckets
./scripts/audit-firewall-rules.sh          # Dangerous firewall rules
./scripts/audit-service-account-keys.sh    # Old keys (>365 days)
./scripts/audit-database-backups.sh        # Missing Cloud SQL backups
```

### 💰 Cost Optimization

```bash
./scripts/find-unused-resources.sh         # Unused resources
./scripts/compare-vm-rightsizing.sh        # Rightsizing opportunities
./scripts/check-preemptible-candidates.sh  # Migration to Spot VMs
./scripts/cleanup-old-projects.sh          # Identify inactive projects
```

### 📦 Inventory

```bash
./scripts/list-all-vms.sh                  # All VMs + costs
./scripts/list-cloud-sql-instances.sh      # Databases
./scripts/list-gke-clusters.sh             # Kubernetes clusters
./scripts/list-gcp-projects.sh             # All projects
```

### 🗑️ Governance

```bash
./scripts/delete-projects.sh               # Delete projects from file
./scripts/delete-orphan-projects.sh        # Delete projects without owner
./scripts/project-usage-score.sh           # Usage score (0-100) per project
```

### 🛠️ Makefile Commands

```bash
make help          # List all commands
make security      # Security audits
make costs         # Cost analysis
make inventory     # Full inventory
```

---

## 📁 Repository Structure

```
gcp-toolbox/
├── scripts/           # 30 Bash scripts
│   ├── lib/          # Common library
│   └── *.sh          # Individual scripts
├── config/           # Configuration (GCP prices)
├── archives/         # Optional CI/CD
├── Makefile          # Quick commands
├── LICENSE           # MIT License
└── README.md         # This file
```

---

## 📚 Full Documentation

All documentation is available on the **[GitHub Wiki](https://github.com/GitCroque/gcp-toolbox/wiki)**:

- 🚀 [Quick Start](https://github.com/GitCroque/gcp-toolbox/wiki/Quick-Start)
- 📖 [Complete Guide](https://github.com/GitCroque/gcp-toolbox/wiki/Home)
- 🔄 [Recommended Workflows](https://github.com/GitCroque/gcp-toolbox/wiki/Workflows)
- ❓ [FAQ](https://github.com/GitCroque/gcp-toolbox/wiki/FAQ)
- 📊 [Technical Audit Reports](https://github.com/GitCroque/gcp-toolbox/wiki/AUDIT_REPORT)

---

## 🤝 Contributing

Contributions are welcome! Check the [contribution guide](https://github.com/GitCroque/gcp-toolbox/wiki/CONTRIBUTING) on the wiki.

---

## 📝 License

MIT License - See [LICENSE](LICENSE)

---

## 📞 Support

- 📖 [Documentation](https://github.com/GitCroque/gcp-toolbox/wiki)
- 🐛 [Issues](https://github.com/GitCroque/gcp-toolbox/issues)
- 💬 [Discussions](https://github.com/GitCroque/gcp-toolbox/discussions)

---

**Built with ❤️ for GCP teams who want to stay in control**
