#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# Script: audit-firewall-rules.sh
# Description: Audite les règles de firewall VPC pour détecter
#              les configurations dangereuses (0.0.0.0/0, ports sensibles)
#
# Prérequis: gcloud CLI avec permissions compute.firewalls.list
#
# Usage: ./audit-firewall-rules.sh [OPTIONS]
#
# Options:
#   --json           : Sortie JSON
#   --project PROJECT: Auditer un seul projet
#####################################################################

# Charger bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh" || {
    echo "Erreur: Impossible de charger lib/common.sh" >&2
    exit 1
}

# Options (JSON_MODE et SINGLE_PROJECT définis dans common.sh)
while [[ $# -gt 0 ]]; do
    case $1 in
        --json) JSON_MODE=true; shift ;;
        --project) SINGLE_PROJECT="$2"; shift 2 ;;
        *) echo "Option inconnue: $1" >&2; exit 1 ;;
    esac
done

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Erreur: gcloud non installé${NC}" >&2; exit 1
fi

[[ "$JSON_MODE" == false ]] && {
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}  🔥 Audit Firewall Rules${NC}"
    echo -e "${MAGENTA}========================================${NC}\n"
}

# Ports sensibles à surveiller
declare -A SENSITIVE_PORTS=(
    ["22"]="SSH"
    ["3389"]="RDP"
    ["3306"]="MySQL"
    ["5432"]="PostgreSQL"
    ["6379"]="Redis"
    ["27017"]="MongoDB"
    ["9200"]="Elasticsearch"
    ["8080"]="HTTP-Alt"
    ["8443"]="HTTPS-Alt"
)

total_rules=0; critical_rules=0; high_risk_rules=0; medium_risk_rules=0; low_risk_rules=0

[[ "$JSON_MODE" == true ]] && {
    echo '{"generated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",'
    echo '  "firewall_rules": ['
    first=true
} || {
    printf "%-25s %-25s %-15s %-20s %-15s %-15s\n" "PROJECT" "RULE_NAME" "DIRECTION" "SOURCE_RANGES" "PORTS" "RISK_LEVEL"
    printf "%-25s %-25s %-15s %-20s %-15s %-15s\n" "-------" "---------" "---------" "-------------" "-----" "----------"
}

project_list="${SINGLE_PROJECT:-$(gcloud projects list --format='value(projectId)')}"

while read -r proj; do
    [[ -z "$proj" ]] && continue

    rules=$(gcloud compute firewall-rules list --project="$proj" \
        --format="value(name,direction,sourceRanges.list(),allowed[].map().firewall_rule().list(),disabled)" 2>/dev/null || echo "")

    while IFS=$'\t' read -r name direction source_ranges allowed disabled; do
        [[ -z "$name" ]] && continue
        [[ "$disabled" == "True" ]] && continue  # Skip disabled rules
        ((total_rules++))

        risk_level="LOW"
        risk_reasons=()

        # Check if rule allows from Internet (0.0.0.0/0)
        if [[ "$source_ranges" == *"0.0.0.0/0"* ]]; then
            # Parse ports
            ports_exposed=""
            if [[ "$allowed" == *"tcp"* ]]; then
                ports_exposed=$(echo "$allowed" | grep -oE 'tcp:[0-9,-]+' | sed 's/tcp://' || echo "all")
            elif [[ "$allowed" == *"udp"* ]]; then
                ports_exposed=$(echo "$allowed" | grep -oE 'udp:[0-9,-]+' | sed 's/udp://' || echo "all")
            elif [[ "$allowed" == *"all"* ]]; then
                ports_exposed="ALL"
            fi

            # Determine risk based on exposed ports
            if [[ "$ports_exposed" == "ALL" ]] || [[ "$allowed" == *"icmp"* && "$source_ranges" == *"0.0.0.0/0"* ]]; then
                risk_level="CRITICAL"
                risk_reasons+=("Exposed to Internet: ALL protocols")
                ((critical_rules++))
            else
                # Check for sensitive ports
                for port in "${!SENSITIVE_PORTS[@]}"; do
                    if [[ "$ports_exposed" == *"$port"* ]]; then
                        if [[ "$port" == "22" ]] || [[ "$port" == "3389" ]]; then
                            risk_level="CRITICAL"
                            risk_reasons+=("SSH/RDP exposed to Internet")
                            ((critical_rules++))
                        else
                            risk_level="HIGH"
                            risk_reasons+=("${SENSITIVE_PORTS[$port]} exposed")
                            ((high_risk_rules++))
                        fi
                        break
                    fi
                done

                if [[ "$risk_level" == "LOW" ]]; then
                    risk_level="MEDIUM"
                    risk_reasons+=("Open to Internet")
                    ((medium_risk_rules++))
                fi
            fi
        else
            ((low_risk_rules++))
        fi

        [[ "$JSON_MODE" == true ]] && {
            [[ "$first" == false ]] && echo ","
            first=false
            echo "    {\"project\":\"$proj\",\"rule\":\"$name\",\"direction\":\"$direction\",\"source_ranges\":\"$source_ranges\",\"allowed\":\"$allowed\",\"risk_level\":\"$risk_level\"}"
        } || {
            # Only show risky rules
            if [[ "$risk_level" != "LOW" ]]; then
                risk_display="$risk_level"
                [[ "$risk_level" == "CRITICAL" ]] && risk_display="${RED}CRITICAL${NC}"
                [[ "$risk_level" == "HIGH" ]] && risk_display="${MAGENTA}HIGH${NC}"
                [[ "$risk_level" == "MEDIUM" ]] && risk_display="${YELLOW}MEDIUM${NC}"

                printf "%-25s %-25s %-15s %-20s %-15s %-24s\n" \
                    "${proj:0:23}" "${name:0:23}" "$direction" "${source_ranges:0:18}" "${allowed:0:13}" "$risk_display"
            fi
        }
    done <<< "$rules"
done <<< "$project_list"

[[ "$JSON_MODE" == true ]] && {
    echo '\n  ],'
    echo '  "summary": {'
    echo "    \"total\": $total_rules, \"critical\": $critical_rules, \"high\": $high_risk_rules, \"medium\": $medium_risk_rules, \"low\": $low_risk_rules"
    echo '  }}'
} || {
    echo -e "\n${CYAN}=== Résumé ===${NC}"
    echo -e "Total règles:          ${BLUE}$total_rules${NC}"
    echo -e "Risque CRITICAL:       ${RED}$critical_rules${NC}"
    echo -e "Risque HIGH:           ${MAGENTA}$high_risk_rules${NC}"
    echo -e "Risque MEDIUM:         ${YELLOW}$medium_risk_rules${NC}"
    echo -e "Risque LOW:            ${GREEN}$low_risk_rules${NC}"

    [[ $critical_rules -gt 0 ]] && echo -e "\n${RED}⚠️  $critical_rules règle(s) CRITIQUES détectées !${NC}"

    echo -e "\n${CYAN}=== Recommandations ===${NC}"
    echo -e "1. ${RED}URGENT${NC}: Restreindre SSH/RDP (utiliser Cloud IAP ou VPN)"
    echo -e "2. ${YELLOW}Limiter${NC} les source ranges (utiliser IP spécifiques)"
    echo -e "3. ${GREEN}Utiliser${NC} Identity-Aware Proxy pour accès admin"
    echo -e "4. ${GREEN}Activer${NC} VPC Service Controls"
}
