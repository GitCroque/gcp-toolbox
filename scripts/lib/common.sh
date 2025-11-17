#!/bin/bash

#####################################################################
# Bibliothèque commune pour tous les scripts GCP Toolbox
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
#####################################################################

# ═══════════════════════════════════════════════════════════
# COULEURS
# ═══════════════════════════════════════════════════════════

declare -g RED='\033[0;31m'
declare -g GREEN='\033[0;32m'
declare -g YELLOW='\033[1;33m'
declare -g BLUE='\033[0;34m'
declare -g CYAN='\033[0;36m'
declare -g MAGENTA='\033[0;35m'
declare -g WHITE='\033[1;37m'
declare -g NC='\033[0m'

# ═══════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════

# Variables globales par défaut
declare -g JSON_MODE=false
declare -g SINGLE_PROJECT=""
declare -g LOG_FILE="${LOG_FILE:-/tmp/gcp-toolbox.log}"
declare -g LOG_LEVEL="${LOG_LEVEL:-INFO}"
declare -g GCLOUD_TIMEOUT="${GCLOUD_TIMEOUT:-300}"

# Détection OS
declare -g IS_MACOS=false
[[ "$OSTYPE" == "darwin"* ]] && IS_MACOS=true

# ═══════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp

    # Date compatible macOS/Linux
    if [[ "$IS_MACOS" == true ]]; then
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    else
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    # Log vers fichier (JSON)
    if [[ -w "$(dirname "$LOG_FILE")" ]]; then
        printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' \
            "$timestamp" "$level" "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi

    # Affichage console
    case $level in
        ERROR) echo -e "${RED}[ERROR] $message${NC}" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN] $message${NC}" >&2 ;;
        INFO)  [[ "$LOG_LEVEL" != "QUIET" ]] && echo -e "${GREEN}[INFO] $message${NC}" ;;
        DEBUG) [[ "$LOG_LEVEL" == "DEBUG" ]] && echo -e "${CYAN}[DEBUG] $message${NC}" ;;
    esac
}

log_error() { log ERROR "$@"; }
log_warn()  { log WARN "$@"; }
log_info()  { log INFO "$@"; }
log_debug() { log DEBUG "$@"; }

# ═══════════════════════════════════════════════════════════
# VALIDATION
# ═══════════════════════════════════════════════════════════

# Valide un nom de ressource GCP
validate_gcp_name() {
    local name=$1
    local type=${2:-"resource"}

    if [[ -z "$name" ]]; then
        log_error "Nom $type vide"
        return 1
    fi

    # Noms GCP: lowercase, chiffres, hyphens
    if [[ ! "$name" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
        log_error "Nom $type invalide: $name (doit être [a-z0-9-], max 63 caractères)"
        return 1
    fi

    return 0
}

# Valide un nombre entier positif
validate_positive_int() {
    local value=$1
    local name=${2:-"valeur"}
    local min=${3:-1}
    local max=${4:-999999}

    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        log_error "$name doit être un nombre entier positif"
        return 1
    fi

    if [[ "$value" -lt "$min" ]] || [[ "$value" -gt "$max" ]]; then
        log_error "$name doit être entre $min et $max"
        return 1
    fi

    return 0
}

# Valide un Project ID GCP
validate_project_id() {
    local project_id=$1

    if [[ -z "$project_id" ]]; then
        log_error "Project ID vide"
        return 1
    fi

    # Project IDs: 6-30 caractères, lowercase, chiffres, hyphens
    if [[ ! "$project_id" =~ ^[a-z]([a-z0-9-]{4,28}[a-z0-9])?$ ]]; then
        log_error "Project ID invalide: $project_id"
        return 1
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════
# VÉRIFICATIONS PRÉREQUIS
# ═══════════════════════════════════════════════════════════

check_command() {
    local cmd=$1
    local package=${2:-$cmd}

    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd n'est pas installé"
        echo -e "${YELLOW}Installation: ${NC}" >&2
        if [[ "$IS_MACOS" == true ]]; then
            echo -e "${CYAN}  brew install $package${NC}" >&2
        else
            echo -e "${CYAN}  apt-get install $package${NC}" >&2
        fi
        return 1
    fi
    return 0
}

check_gcloud() {
    if ! check_command gcloud "google-cloud-sdk"; then
        echo -e "${YELLOW}Voir: https://cloud.google.com/sdk/docs/install${NC}" >&2
        exit 1
    fi

    # Vérification authentification
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        log_error "Aucun compte gcloud actif"
        echo -e "${YELLOW}Exécutez: ${CYAN}gcloud auth login${NC}" >&2
        exit 1
    fi

    log_debug "gcloud OK, compte actif: $(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -1)"
    return 0
}

check_gsutil() {
    if ! check_command gsutil "google-cloud-sdk"; then
        exit 1
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════
# GCLOUD WRAPPER AVEC TIMEOUT
# ═══════════════════════════════════════════════════════════

gcloud_with_timeout() {
    local timeout=${GCLOUD_TIMEOUT:-300}

    if command -v timeout &> /dev/null; then
        timeout "$timeout" gcloud "$@"
    else
        # Fallback sans timeout (macOS par défaut n'a pas timeout)
        gcloud "$@"
    fi
}

# ═══════════════════════════════════════════════════════════
# GESTION DE DATES (compatible macOS/Linux)
# ═══════════════════════════════════════════════════════════

# Calcule le nombre de jours depuis un timestamp ISO
calculate_days_ago() {
    local timestamp=$1
    local current_time
    local resource_time

    # Obtient timestamp actuel
    current_time=$(date +%s)

    # Parse timestamp selon OS
    if [[ "$IS_MACOS" == true ]]; then
        # macOS (BSD date)
        # Format attendu: 2024-01-15T10:30:45Z ou 2024-01-15T10:30:45.123456Z
        local clean_timestamp="${timestamp%%.*}"  # Retire microsecondes
        clean_timestamp="${clean_timestamp%Z}"     # Retire Z

        resource_time=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$clean_timestamp" +%s 2>/dev/null || echo "0")
    else
        # Linux (GNU date)
        resource_time=$(date -d "$timestamp" +%s 2>/dev/null || echo "0")
    fi

    if [[ "$resource_time" == "0" ]]; then
        echo "?"
        return 1
    fi

    local diff_seconds=$((current_time - resource_time))
    local diff_days=$((diff_seconds / 86400))

    echo "$diff_days"
    return 0
}

# Calcule une date N jours dans le passé
calculate_past_date() {
    local days=$1

    if [[ "$IS_MACOS" == true ]]; then
        # macOS (BSD date)
        date -u -v -"${days}"d +"%Y-%m-%dT%H:%M:%SZ"
    else
        # Linux (GNU date)
        date -u -d "$days days ago" +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# Timestamp actuel ISO
get_current_timestamp() {
    if [[ "$IS_MACOS" == true ]]; then
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    else
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# ═══════════════════════════════════════════════════════════
# GÉNÉRATION JSON
# ═══════════════════════════════════════════════════════════

declare -g FIRST_JSON_ITEM=true

json_start() {
    local script_name=${1:-"gcp-toolbox"}
    cat <<EOF
{
  "generated_at": "$(get_current_timestamp)",
  "generated_by": "$script_name",
  "items": [
EOF
    FIRST_JSON_ITEM=true
}

json_item() {
    local item_json=$1

    if [[ "$FIRST_JSON_ITEM" == false ]]; then
        echo ","
    fi
    FIRST_JSON_ITEM=false

    echo "$item_json"
}

json_end() {
    local summary_json=${1:-"{}"}

    cat <<EOF

  ],
  "summary": $summary_json
}
EOF
}

# Échappe une chaîne pour JSON (compatible avec jq si disponible)
json_escape() {
    local str=$1

    if command -v jq &> /dev/null; then
        jq -n --arg str "$str" '$str'
    else
        # Fallback manuel
        str="${str//\\/\\\\}"  # \ -> \\
        str="${str//\"/\\\"}"  # " -> \"
        str="${str//$'\n'/\\n}"  # newline -> \n
        str="${str//$'\r'/\\r}"  # carriage return -> \r
        str="${str//$'\t'/\\t}"  # tab -> \t
        echo "\"$str\""
    fi
}

# ═══════════════════════════════════════════════════════════
# FORMATAGE
# ═══════════════════════════════════════════════════════════

# Formate une taille en bytes vers human-readable
format_bytes() {
    local bytes=$1

    if [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
        echo "$bytes"
        return
    fi

    if [[ "$bytes" -ge 1099511627776 ]]; then
        printf "%.2f TB" "$(bc <<< "scale=2; $bytes / 1099511627776")"
    elif [[ "$bytes" -ge 1073741824 ]]; then
        printf "%.2f GB" "$(bc <<< "scale=2; $bytes / 1073741824")"
    elif [[ "$bytes" -ge 1048576 ]]; then
        printf "%.2f MB" "$(bc <<< "scale=2; $bytes / 1048576")"
    elif [[ "$bytes" -ge 1024 ]]; then
        printf "%.2f KB" "$(bc <<< "scale=2; $bytes / 1024")"
    else
        echo "$bytes bytes"
    fi
}

# ═══════════════════════════════════════════════════════════
# PARSING D'ARGUMENTS COMMUNS
# ═══════════════════════════════════════════════════════════

# Parse les arguments communs à tous les scripts
# Retourne 0 si argument reconnu, 1 sinon (pour permettre au script de gérer)
parse_common_arg() {
    case $1 in
        --json)
            JSON_MODE=true
            return 0
            ;;
        --project)
            if [[ -z "${2:-}" ]]; then
                log_error "--project requiert un argument"
                exit 1
            fi
            if validate_project_id "$2"; then
                SINGLE_PROJECT="$2"
                return 0
            else
                exit 1
            fi
            ;;
        --help|-h)
            return 0  # Le script doit gérer l'affichage de l'aide
            ;;
        --debug)
            LOG_LEVEL="DEBUG"
            log_debug "Mode debug activé"
            return 0
            ;;
        --quiet|-q)
            LOG_LEVEL="QUIET"
            return 0
            ;;
        *)
            return 1  # Argument non reconnu, laisser le script le gérer
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════
# EN-TÊTES ET AFFICHAGES
# ═══════════════════════════════════════════════════════════

print_header() {
    local title=$1
    local color=${2:-$CYAN}

    if [[ "$JSON_MODE" == false ]]; then
        echo -e "${color}========================================${NC}"
        echo -e "${color}  $title${NC}"
        echo -e "${color}========================================${NC}"
        echo ""
    fi
}

print_summary() {
    local title=$1
    shift
    local items=("$@")

    if [[ "$JSON_MODE" == false ]]; then
        echo ""
        echo -e "${CYAN}========== $title ==========${NC}"
        for item in "${items[@]}"; do
            echo -e "$item"
        done
        echo ""
    fi
}

# ═══════════════════════════════════════════════════════════
# CACHE DE PROJETS
# ═══════════════════════════════════════════════════════════

# Récupère la liste des projets (avec cache si disponible)
get_projects_list() {
    local cache_file="${PROJECTS_CACHE_FILE:-}"

    if [[ -n "$cache_file" ]] && [[ -f "$cache_file" ]]; then
        log_debug "Utilisation du cache projets: $cache_file"
        cat "$cache_file"
    else
        log_debug "Récupération liste projets via gcloud"
        gcloud_with_timeout projects list --format="value(projectId)"
    fi
}

# Crée un cache de projets
create_projects_cache() {
    local cache_file=$1

    log_info "Création cache projets..."
    gcloud_with_timeout projects list --format="value(projectId)" > "$cache_file"
    log_debug "Cache créé: $cache_file ($(wc -l < "$cache_file") projets)"
}

# ═══════════════════════════════════════════════════════════
# FICHIERS TEMPORAIRES SÉCURISÉS
# ═══════════════════════════════════════════════════════════

# Crée un fichier temporaire sécurisé
create_temp_file() {
    local prefix=${1:-"gcp-toolbox"}
    mktemp "/tmp/${prefix}.XXXXXX"
}

# Crée un répertoire temporaire sécurisé
create_temp_dir() {
    local prefix=${1:-"gcp-toolbox"}
    mktemp -d "/tmp/${prefix}.XXXXXX"
}

# ═══════════════════════════════════════════════════════════
# RATE LIMITING
# ═══════════════════════════════════════════════════════════

declare -g LAST_API_CALL=0

rate_limit() {
    local min_interval=${1:-0.1}  # 100ms par défaut

    if command -v bc &> /dev/null; then
        local now
        now=$(date +%s.%N 2>/dev/null || date +%s)
        local elapsed
        elapsed=$(bc <<< "$now - $LAST_API_CALL" 2>/dev/null || echo "999")

        if (( $(bc <<< "$elapsed < $min_interval" 2>/dev/null || echo 0) )); then
            local sleep_time
            sleep_time=$(bc <<< "$min_interval - $elapsed")
            sleep "$sleep_time" 2>/dev/null || sleep 1
        fi

        LAST_API_CALL=$(date +%s.%N 2>/dev/null || date +%s)
    else
        # Fallback sans bc (moins précis)
        sleep "$min_interval" 2>/dev/null || :
    fi
}

# ═══════════════════════════════════════════════════════════
# PRIX GCP (USD/mois estimés)
# ═══════════════════════════════════════════════════════════

# Charge les prix depuis config ou utilise valeurs par défaut
load_pricing() {
    local config_file="${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/../config/pricing.conf"

    if [[ -f "$config_file" ]]; then
        log_debug "Chargement prix depuis: $config_file"
        # shellcheck source=/dev/null
        source "$config_file"
    else
        log_debug "Fichier pricing.conf non trouvé, utilisation valeurs par défaut"
    fi
}

# Prix par défaut (peuvent être overridden par pricing.conf)
declare -gA COMPUTE_COSTS=(
    ["f1-micro"]=5
    ["g1-small"]=15
    ["e2-micro"]=7
    ["e2-small"]=14
    ["e2-medium"]=28
    ["n1-standard-1"]=25
    ["n1-standard-2"]=50
    ["n1-standard-4"]=100
)

declare -gA SQL_COSTS=(
    ["db-f1-micro"]=10
    ["db-g1-small"]=30
    ["db-n1-standard-1"]=60
    ["db-n1-standard-2"]=120
    ["db-n1-standard-4"]=240
)

# Récupère le coût estimé d'une machine type
get_vm_cost() {
    local machine_type=$1
    echo "${COMPUTE_COSTS[$machine_type]:-50}"  # 50 par défaut si inconnu
}

get_sql_cost() {
    local tier=$1
    echo "${SQL_COSTS[$tier]:-60}"  # 60 par défaut si inconnu
}

# ═══════════════════════════════════════════════════════════
# INITIALISATION
# ═══════════════════════════════════════════════════════════

# Appelée automatiquement au source de ce fichier
_init_common() {
    log_debug "Bibliothèque commune chargée (OS: $OSTYPE, macOS: $IS_MACOS)"
}

_init_common
