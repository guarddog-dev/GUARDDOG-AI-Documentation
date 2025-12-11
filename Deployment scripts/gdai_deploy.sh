#!/usr/bin/env bash
#
# GuardDog AI Sensor Deployment Helper (RHEL 9/10, Podman + systemd)
# -----------------------------------------------------------------
# This script automates:
#  - OS & resource validation (RHEL 9+)
#  - Podman installation (if needed)
#  - Network & firewall sanity checks
#  - Collection of DEVICE_NAME, USER_EMAIL, LICENSE_KEY
#  - SPAN/TAP/port-mirroring interface selection & traffic validation
#  - Safe creation of /etc/$DEVICE_NAME for persistent config
#  - podman run using the GuardDog AI image
#  - systemd unit generation for auto-restart (if systemd + podman support it)
#  - JSON execution report POSTed to a webhook with full log (base64)
#
# NOTES:
#   - WEBHOOK_URL can be overridden via environment variable.
#   - IMAGE_NAME can be overridden via environment variable.
#   - CUSTOMER_TAG, SITE_TAG, ENV_TAG can be used for correlation.
#   - NON_INTERACTIVE=true makes the script CI-safe (no prompts); required vars
#     must be provided via env or CLI.

set -euo pipefail

# ------------------------------
# Globals & defaults
# ------------------------------
LOG_FILE="/var/log/guarddog_deploy.log"
IMAGE_NAME="${IMAGE_NAME:-docker.io/guarddogai/prod:latest}"

DEVICE_NAME="${DEVICE_NAME:-}"
USER_EMAIL="${USER_EMAIL:-}"
LICENSE_KEY="${LICENSE_KEY:-}"

CUSTOMER_TAG="${CUSTOMER_TAG:-}"
SITE_TAG="${SITE_TAG:-}"
ENV_TAG="${ENV_TAG:-}"

NON_INTERACTIVE="${NON_INTERACTIVE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Whether to mask LICENSE_KEY input with asterisks (interactive mode only)
# Default: true (masked with *)
MASK_LICENSE_INPUT="${MASK_LICENSE_INPUT:-true}"

# Resource thresholds (configurable)
MIN_CPU_CORES="${MIN_CPU_CORES:-4}"
MIN_RAM_GB="${MIN_RAM_GB:-4}"       # 4 GB min; 8 GB recommended
MIN_DISK_GB="${MIN_DISK_GB:-10}"    # 10 GB min free on /

# Container startup / provisioning monitoring (configurable)
CONTAINER_MONITOR_TIMEOUT="${CONTAINER_MONITOR_TIMEOUT:-600}"     # total seconds to monitor startup/provisioning
CONTAINER_STABLE_SECONDS="${CONTAINER_STABLE_SECONDS:-60}"        # time container must stay running
CONTAINER_CHECK_INTERVAL="${CONTAINER_CHECK_INTERVAL:-5}"         # seconds between checks
CONTAINER_LOG_FOLLOW_SECS="${CONTAINER_LOG_FOLLOW_SECS:-600}"    # safety cap on log-follow duration

RHEL_VERSION=""
CONFIG_DIR=""
SPAN_INTERFACES="${SPAN_INTERFACES:-}"
SKIP_SPAN_VALIDATION="${SKIP_SPAN_VALIDATION:-false}"

SCRIPT_START_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
WEBHOOK_URL="${WEBHOOK_URL:-https://automation.askdanp.com/webhook/reportxxxyyyzzz}"
DEPLOYMENT_ID=""
EXIT_MESSAGE=""
CONTAINER_LOG_PID=""

# ------------------------------
# Pretty output (console only)
# ------------------------------
if [[ -t 1 ]]; then
  GREEN="\033[1;32m"
  YELLOW="\033[1;33m"
  RED="\033[1;31m"
  BLUE="\033[1;34m"
  NC="\033[0m"
else
  GREEN=""; YELLOW=""; RED=""; BLUE=""; NC=""
fi

status() { echo -e "${GREEN}[+] $1${NC}"; }
warn()   { echo -e "${YELLOW}[WARN] $1${NC}"; }
err_raw(){ echo -e "${RED}[ERROR] $1${NC}" >&2; }

# Generic error that integrates with EXIT trap
die() {
  local msg="$1"
  err_raw "$msg"
  EXIT_MESSAGE="${EXIT_MESSAGE:-$msg}"
  exit 1
}

usage() {
  cat <<EOF
GuardDog AI Sensor Deployment (RHEL 9/10, Podman + systemd)

Usage:
  sudo $0 [options]

Options:
  --device-name NAME       Sensor / container name (DEVICE_NAME)
  --email EMAIL            User email (same as dcx.guarddog.ai account)
  --license KEY            License key for this sensor
  --image IMAGE            Container image (default: $IMAGE_NAME)
  --customer-tag TAG       Tag to correlate with a customer/org
  --site-tag TAG           Tag to correlate with a site/branch
  --env-tag TAG            Tag to correlate with an environment (prod/dev/test)
  --non-interactive        Do not prompt (for automation/CI)
  --dry-run                Show commands but do not run them
  -h, --help               Show this help

Env vars:
  DEVICE_NAME, USER_EMAIL, LICENSE_KEY, IMAGE_NAME,
  WEBHOOK_URL, CUSTOMER_TAG, SITE_TAG, ENV_TAG,
  NON_INTERACTIVE=true/false, DRY_RUN=true/false,
  MIN_CPU_CORES, MIN_RAM_GB, MIN_DISK_GB,
  SPAN_INTERFACES, SKIP_SPAN_VALIDATION,
  CONTAINER_MONITOR_TIMEOUT, CONTAINER_STABLE_SECONDS,
  CONTAINER_CHECK_INTERVAL, CONTAINER_LOG_FOLLOW_SECS,
  MASK_LICENSE_INPUT=true/false

EOF
}

# ------------------------------
# Exit trap: send JSON report to webhook
# ------------------------------
on_exit() {
  local exit_code="$?"
  set +e

  sync || true

  if [[ ! -f "$LOG_FILE" ]]; then
    touch "$LOG_FILE" 2>/dev/null || true
  fi

  # Best-effort: stop any background log follower
  if [[ -n "${CONTAINER_LOG_PID:-}" ]]; then
    kill "$CONTAINER_LOG_PID" >/dev/null 2>&1 || true
    wait "$CONTAINER_LOG_PID" >/dev/null 2>&1 || true
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "[WARN] curl not available; cannot send JSON execution report to webhook: $WEBHOOK_URL" >> "$LOG_FILE" 2>/dev/null || true
    return
  fi

  local end_time
  end_time="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Determine final container status, if any
  local container_status="unknown"
  if command -v podman >/dev/null 2>&1 && [[ -n "${DEVICE_NAME:-}" ]]; then
    local ps_output
    ps_output="$(podman ps -a --format '{{.Names}} {{.Status}}' 2>/dev/null || true)"
    if [[ -n "$ps_output" ]]; then
      container_status=$(awk -v name="$DEVICE_NAME" '$1==name { $1=""; sub(/^ /,""); print; }' <<<"$ps_output")
      [[ -z "$container_status" ]] && container_status="none"
    fi
  fi

  # Base64-encode log safely (GNU and non-GNU)
  local log_b64=""
  if command -v base64 >/dev/null 2>&1; then
    if base64 --help 2>&1 | grep -q -- '-w'; then
      log_b64="$(base64 -w0 "$LOG_FILE" 2>/dev/null || true)"
    else
      log_b64="$(base64 "$LOG_FILE" 2>/dev/null | tr -d '\n' || true)"
    fi
  else
    log_b64="base64_not_available"
  fi

  local tmp_json="/tmp/guarddog_deploy_report.json"

  cat > "$tmp_json" <<EOF
{
  "deployment_id": "${DEPLOYMENT_ID:-unknown}",
  "customer_tag": "${CUSTOMER_TAG:-unset}",
  "site_tag": "${SITE_TAG:-unset}",
  "env_tag": "${ENV_TAG:-unset}",
  "host": "$(hostname 2>/dev/null || echo unknown)",
  "os_release": "$(cat /etc/redhat-release 2>/dev/null || echo unknown)",
  "rhel_version": "${RHEL_VERSION:-unknown}",
  "device_name": "${DEVICE_NAME:-unset}",
  "span_interfaces": "${SPAN_INTERFACES:-none}",
  "exit_code": $exit_code,
  "exit_message": "${EXIT_MESSAGE:-unset}",
  "container_status": "${container_status}",
  "script_start": "$SCRIPT_START_TIME",
  "script_end": "$end_time",
  "webhook_url": "$WEBHOOK_URL",
  "log_b64": "$log_b64"
}
EOF

  curl -sS -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    --data-binary "@$tmp_json" >/dev/null 2>&1 || true
}
trap on_exit EXIT

# ------------------------------
# Early helpers (no logging yet)
# ------------------------------
check_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "Required command '$cmd' not found in PATH."
  fi
}

validate_bool() {
  local name="$1" val="$2"
  case "$val" in
    true|false) ;;
    *)
      die "$name must be 'true' or 'false', got '$val'."
      ;;
  esac
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --device-name)
        DEVICE_NAME="$2"; shift 2 ;;
      --email)
        USER_EMAIL="$2"; shift 2 ;;
      --license)
        LICENSE_KEY="$2"; shift 2 ;;
      --image)
        IMAGE_NAME="$2"; shift 2 ;;
      --customer-tag)
        CUSTOMER_TAG="$2"; shift 2 ;;
      --site-tag)
        SITE_TAG="$2"; shift 2 ;;
      --env-tag)
        ENV_TAG="$2"; shift 2 ;;
      --non-interactive)
        NON_INTERACTIVE=true; shift ;;
      --dry-run)
        DRY_RUN=true; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1 ;;
    esac
  done
}

init_deployment_id() {
  if command -v uuidgen >/dev/null 2>&1; then
    DEPLOYMENT_ID="$(uuidgen)"
  else
    DEPLOYMENT_ID="$(date +%Y%m%d%H%M%S)-$RANDOM"
  fi
  status "Deployment ID: $DEPLOYMENT_ID"
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "This script must be run as root. Try: sudo $0 ..."
  fi
}

# ------------------------------
# Masked-input helper for LICENSE_KEY
# ------------------------------
read_masked() {
  local prompt="$1"
  local __var_name="$2"
  local password=""

  read -rs -p "$prompt" password
  printf '\n'
  printf -v "$__var_name" '%s' "$password"
}

# ------------------------------
# Main checks before logging
# ------------------------------
parse_args "$@"
validate_bool "NON_INTERACTIVE" "$NON_INTERACTIVE"
validate_bool "DRY_RUN" "$DRY_RUN"
validate_bool "SKIP_SPAN_VALIDATION" "$SKIP_SPAN_VALIDATION"
validate_bool "MASK_LICENSE_INPUT" "$MASK_LICENSE_INPUT"
require_root

# ------------------------------
# Initialize logging (after root)
# ------------------------------
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE" || die "Cannot write to log file: $LOG_FILE"
chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "-------------------------------------------------------"
echo " GuardDog AI Sensor Deployment (RHEL 9/10, Podman)"
echo "-------------------------------------------------------"
echo

# ------------------------------
# OS / dependency checks
# ------------------------------
check_os() {
  status "Checking OS compatibility..."

  if [[ ! -f /etc/redhat-release ]]; then
    die "This system does not look like RHEL (missing /etc/redhat-release)."
  fi

  if ! grep -Eqi "Red Hat Enterprise Linux" /etc/redhat-release; then
    die "This script is intended for Red Hat Enterprise Linux 9/10."
  fi

  if command -v rpm >/dev/null 2>&1; then
    RHEL_VERSION="$(rpm -E %{rhel} 2>/dev/null || true)"
  fi

  if [[ -z "$RHEL_VERSION" ]]; then
    RHEL_VERSION="$(awk '{for(i=1;i<=NF;i++){if($i ~ /^[0-9]+\.[0-9]+/){split($i,a,"."); print a[1]; exit}}}' /etc/redhat-release)"
  fi

  if [[ -z "$RHEL_VERSION" ]]; then
    die "Unable to determine RHEL major version."
  fi

  echo "Detected RHEL major version: $RHEL_VERSION"

  if [[ "$RHEL_VERSION" -lt 9 ]]; then
    die "GuardDog AI sensor is supported on RHEL 9 and later. Detected: $RHEL_VERSION"
  fi
}

check_resources() {
  status "Checking system resources (min CPU=${MIN_CPU_CORES}, RAM=${MIN_RAM_GB}GB, Disk=${MIN_DISK_GB}GB)..."

  local cpu ram_mb ram_gb disk_gb
  cpu="$(nproc)"
  ram_mb="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
  ram_gb=$(( (ram_mb + 1023) / 1024 ))
  disk_gb="$(df -Pm / | awk 'NR==2 {print int($4/1024)}')"

  echo "CPU cores : $cpu"
  echo "RAM (GB)  : $ram_gb"
  echo "Disk free : ${disk_gb} GB"

  if (( cpu < MIN_CPU_CORES )); then
    die "Requires at least ${MIN_CPU_CORES} CPU cores (have $cpu). Override via MIN_CPU_CORES if intentional."
  fi
  if (( ram_gb < MIN_RAM_GB )); then
    warn "Less than ${MIN_RAM_GB} GB RAM detected (have ${ram_gb} GB). This may impact performance."
  fi
  if (( disk_gb < MIN_DISK_GB )); then
    warn "Less than ${MIN_DISK_GB} GB free disk space on /. Consider freeing space."
  fi
}

ensure_podman() {
  status "Checking for Podman..."

  if ! command -v podman >/dev/null 2>&1; then
    status "Podman not found. Installing via dnf..."
    check_command dnf
    if ! dnf -y install podman; then
      die "Failed to install Podman with 'dnf -y install podman'. Check repos/subscription and network."
    fi
  fi

  podman --version || warn "Unable to show Podman version (non-fatal)."
}

check_network() {
  status "Performing basic network/DNS checks..."

  if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found; attempting to install for connectivity checks..."
    if command -v dnf >/dev/null 2>&1; then
      dnf -y install curl || warn "Failed to install curl; skipping connectivity checks."
    else
      warn "dnf not available; skipping connectivity checks."
    fi
  fi

  if command -v curl >/dev/null 2>&1; then
    if ! curl -s --max-time 5 https://dcx.guarddog.ai >/dev/null 2>&1; then
      warn "Unable to reach https://dcx.guarddog.ai. DNS/firewall may block sensor registration."
    else
      status "Connectivity to dcx.guarddog.ai looks OK."
    fi

    if ! curl -s --max-time 5 https://registry-1.docker.io/v2/ >/dev/null 2>&1; then
      warn "Unable to reach Docker Hub (registry-1.docker.io). Image pull may fail."
    else
      status "Connectivity to Docker Hub looks OK."
    fi
  fi
}

check_firewall() {
  status "Checking host firewall configuration..."

  if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
    local zone services ports
    zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo "unknown")
    services=$(firewall-cmd --zone="$zone" --list-services 2>/dev/null || echo "n/a")
    ports=$(firewall-cmd --zone="$zone" --list-ports 2>/dev/null || echo "n/a")

    echo "firewalld is active."
    echo "  Default zone : $zone"
    echo "  Services     : $services"
    echo "  Ports        : $ports"
    echo
    warn "This check is informational. Outbound 443/tcp is required for dcx.guarddog.ai and image pulls."
  else
    if systemctl is-active --quiet firewalld 2>/dev/null; then
      warn "firewalld appears active but firewall-cmd is not available."
    else
      warn "firewalld not active. System may rely on nftables or other tooling for packet filtering."
    fi

    if command -v nft >/dev/null 2>&1; then
      echo "nftables ruleset (first ~40 lines):"
      nft list ruleset | head -n 40 || true
      echo
    fi
  fi
}

# ------------------------------
# Config collection & validation
# ------------------------------
validate_device_name() {
  local name="$1"
  if [[ -z "$name" ]]; then
    die "DEVICE_NAME is required."
  fi

  if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
    die "DEVICE_NAME '$name' contains invalid characters. Use only letters, digits, '-' and '_'."
  fi

  local len=${#name}
  if (( len > 32 )); then
    die "DEVICE_NAME '$name' is too long ($len chars). Limit to 32 characters."
  fi
}

collect_config_interactive() {
  echo
  status "Collecting deployment parameters (interactive)..."

  while [[ -z "${DEVICE_NAME:-}" ]]; do
    read -rp "Enter DEVICE_NAME (sensor/container name): " DEVICE_NAME
  done
  while [[ -z "${USER_EMAIL:-}" ]]; do
    read -rp "Enter USER_EMAIL (same as dcx.guarddog.ai account): " USER_EMAIL
  done
  while [[ -z "${LICENSE_KEY:-}" ]]; do
    if [[ "$MASK_LICENSE_INPUT" == "true" ]]; then
      read_masked "Enter LICENSE_KEY (provided by GuardDog AI): " LICENSE_KEY
    else
      read -rp "Enter LICENSE_KEY (provided by GuardDog AI): " LICENSE_KEY
    fi
  done

  if [[ -z "${CUSTOMER_TAG:-}" ]]; then
    read -rp "Optional CUSTOMER_TAG (customer/org identifier): " CUSTOMER_TAG || true
  fi
  if [[ -z "${SITE_TAG:-}" ]]; then
    read -rp "Optional SITE_TAG (site/branch identifier): " SITE_TAG || true
  fi
  if [[ -z "${ENV_TAG:-}" ]]; then
    read -rp "Optional ENV_TAG (prod/dev/test, etc.): " ENV_TAG || true
  fi

  echo
  echo "Configuration summary:"
  echo "  DEVICE_NAME : $DEVICE_NAME"
  echo "  USER_EMAIL  : $USER_EMAIL"
  echo "  LICENSE_KEY : (hidden)"
  echo "  IMAGE_NAME  : $IMAGE_NAME"
  echo "  CUSTOMER_TAG: ${CUSTOMER_TAG:-unset}"
  echo "  SITE_TAG    : ${SITE_TAG:-unset}"
  echo "  ENV_TAG     : ${ENV_TAG:-unset}"
  echo

  read -rp "Proceed with these settings? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    die "User aborted deployment."
  fi
}

collect_config_non_interactive() {
  status "NON_INTERACTIVE=true; validating required variables..."

  local missing=()
  [[ -z "$DEVICE_NAME" ]]  && missing+=("DEVICE_NAME")
  [[ -z "$USER_EMAIL" ]]   && missing+=("USER_EMAIL")
  [[ -z "$LICENSE_KEY" ]]  && missing+=("LICENSE_KEY")

  if ((${#missing[@]} > 0)); then
    die "NON_INTERACTIVE is true but the following required variables are missing: ${missing[*]}. Provide them via env or CLI."
  fi

  echo
  echo "Configuration summary (non-interactive):"
  echo "  DEVICE_NAME : $DEVICE_NAME"
  echo "  USER_EMAIL  : $USER_EMAIL"
  echo "  LICENSE_KEY : (hidden)"
  echo "  IMAGE_NAME  : $IMAGE_NAME"
  echo "  CUSTOMER_TAG: ${CUSTOMER_TAG:-unset}"
  echo "  SITE_TAG    : ${SITE_TAG:-unset}"
  echo "  ENV_TAG     : ${ENV_TAG:-unset}"
  echo
}

list_interfaces() {
  status "Available network interfaces (excluding loopback):"

  check_command ip
  ip -o link show | awk -F': ' '{print $2}' | while read -r iface; do
    [[ "$iface" == "lo" ]] && continue
    local ips promisc
    ips=$(ip -o -4 addr show dev "$iface" 2>/dev/null | awk '{print $4}' | paste -sd "," -)
    if ip -o link show dev "$iface" | grep -qw PROMISC; then promisc="on"; else promisc="off"; fi
    echo "  - $iface (promisc=${promisc}, ipv4=${ips:-none})"
  done
}

select_span_interfaces() {
  if [[ -n "$SPAN_INTERFACES" ]]; then
    status "SPAN_INTERFACES preset to '$SPAN_INTERFACES'; skipping interactive SPAN/TAP selection."
    return
  fi

  echo
  status "SPAN/TAP / port-mirroring interface selection"

  list_interfaces

  echo
  echo "If you have one or more interfaces connected to a SPAN/TAP or port mirror,"
  echo "enter them as a comma-separated list (for example: ens224,ens256)."
  echo "If you do not use a dedicated SPAN interface, you can leave this blank."
  echo

  local span_input
  read -rp "SPAN/TAP interface(s) [optional]: " span_input || true

  span_input="${span_input// /}"

  if [[ -n "$span_input" ]]; then
    SPAN_INTERFACES="$span_input"
  else
    SPAN_INTERFACES=""
    warn "No SPAN/TAP interfaces specified. The sensor will still deploy, but"
    warn "you may want to verify traffic mirroring manually."
  fi
}

validate_span_interfaces() {
  if [[ "$SKIP_SPAN_VALIDATION" == "true" ]]; then
    status "SKIP_SPAN_VALIDATION=true; skipping SPAN/TAP interface checks."
    return 0
  fi

  [[ -z "$SPAN_INTERFACES" ]] && return 0

  status "Validating SPAN/TAP interfaces and traffic..."

  check_command ip

  local iface
  IFS=',' read -ra ifaces <<< "$SPAN_INTERFACES"
  for iface in "${ifaces[@]}"; do
    iface="${iface// /}"
    [[ -z "$iface" ]] && continue

    if ! ip link show dev "$iface" >/dev/null 2>&1; then
      die "Interface '$iface' does not exist."
    fi

    local ips promisc
    ips=$(ip -o -4 addr show dev "$iface" 2>/dev/null | awk '{print $4}' | paste -sd "," -)
    if ip -o link show dev "$iface" | grep -qw PROMISC; then promisc="on"; else promisc="off"; fi

    echo "Interface $iface: promisc=${promisc}, ipv4=${ips:-none}"

    if [[ "$promisc" == "off" ]]; then
      if [[ "$NON_INTERACTIVE" == "false" ]]; then
        read -rp "Enable promiscuous mode on $iface? [y/N]: " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
          ip link set dev "$iface" promisc on || warn "Failed to enable promiscuous mode on $iface"
        else
          warn "Promiscuous mode not enabled on $iface; mirrored traffic may be missed."
        fi
      else
        ip link set dev "$iface" promisc on || warn "Failed to enable promiscuous mode on $iface"
      fi
    fi

    local stats_file="/sys/class/net/$iface/statistics/rx_bytes"
    if [[ ! -r "$stats_file" ]]; then
      warn "Cannot read rx_bytes for $iface; skipping traffic check."
      continue
    fi

    local rx1 rx2 diff
    rx1=$(cat "$stats_file")
    sleep 5
    rx2=$(cat "$stats_file")
    diff=$((rx2 - rx1))

    if (( diff <= 0 )); then
      warn "No incoming traffic observed on $iface in the last 5 seconds."
      if [[ -z "$ips" ]]; then
        warn "This interface has no IP address and appears dedicated to mirroring."
        warn "If the upstream switch is not yet configured to mirror, you will see 0 bytes here."
      fi

      if [[ "$NON_INTERACTIVE" == "false" ]]; then
        read -rp "Continue deployment anyway? [y/N]: " ans2
        if [[ ! "$ans2" =~ ^[Yy]$ ]]; then
          die "Aborting due to lack of observed traffic on SPAN/TAP interface $iface."
        fi
      else
        warn "Continuing despite lack of observed traffic on $iface (NON_INTERACTIVE=true)."
      fi
    else
      status "Observed ${diff} bytes of incoming traffic on $iface over ~5s. Mirroring appears active."
    fi
  done
}

prepare_directories() {
  status "Preparing persistent configuration directory..."

  CONFIG_DIR="/etc/${DEVICE_NAME}"

  if [[ -d "$CONFIG_DIR" ]]; then
    status "Config directory ${CONFIG_DIR} already exists. Reusing it."
  else
    mkdir -p "$CONFIG_DIR" || die "Failed to create $CONFIG_DIR"
  fi

  chmod 755 "$CONFIG_DIR"

  if command -v restorecon >/dev/null 2>&1; then
    restorecon -R "$CONFIG_DIR" || true
  fi

  echo "Using host config directory: $CONFIG_DIR (mounted into container as /etc/guarddog)"
}

pull_image() {
  status "Pulling GuardDog AI container image: ${IMAGE_NAME}"

  if [[ "$DRY_RUN" == "true" ]]; then
    status "DRY_RUN=true; skipping image pull."
    return
  fi

  if ! podman pull "$IMAGE_NAME"; then
    die "Failed to pull image '${IMAGE_NAME}'. Check registry access, network, and credentials."
  fi
}

deploy_container() {
  status "Deploying GuardDog AI sensor container with Podman..."

  if podman ps -a --format '{{.Names}}' | grep -qw "$DEVICE_NAME"; then
    warn "A container named '$DEVICE_NAME' already exists."

    if [[ "$NON_INTERACTIVE" == "false" ]]; then
      read -rp "Stop and remove existing container before continuing? [y/N]: " ans
      if [[ "$ans" =~ ^[Yy]$ ]]; then
        podman stop "$DEVICE_NAME" >/dev/null 2>&1 || true
        podman rm "$DEVICE_NAME" >/dev/null 2>&1 || true
      else
        status "Reusing existing container; skipping 'podman run'."
        return
      fi
    else
      podman stop "$DEVICE_NAME" >/dev/null 2>&1 || true
      podman rm "$DEVICE_NAME" >/dev/null 2>&1 || true
    fi
  fi

  local run_cmd=(
    podman run -d
    --user root
    --cap-add NET_ADMIN
    --cap-add NET_RAW
    --net=host
    -v "${CONFIG_DIR}:/etc/guarddog:Z"
    --name "$DEVICE_NAME"
    "$IMAGE_NAME"
    gdai
    --device_name="$DEVICE_NAME"
    --email="$USER_EMAIL"
    --license="$LICENSE_KEY"
  )

  if [[ -n "$SPAN_INTERFACES" ]]; then
    run_cmd+=( --span-interfaces="$SPAN_INTERFACES" )
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    status "Dry-run mode: this is the podman command that would be executed:"
    printf '  %q ' "${run_cmd[@]}"; echo
    return
  fi

  status "Running container with command:"
  printf '  %q ' "${run_cmd[@]}"; echo

  local container_id
  if ! container_id=$("${run_cmd[@]}" 2>&1); then
    err_raw "podman run failed to start container '$DEVICE_NAME'."
    err_raw "Error: $container_id"
    local status_line
    status_line=$(podman ps -a --format '{{.Names}} {{.Status}}' 2>/dev/null | awk -v name="$DEVICE_NAME" '$1==name { $1=""; sub(/^ /,""); print; }')
    if [[ -n "$status_line" ]]; then
      err_raw "Detected container '$DEVICE_NAME' with status: $status_line"
      err_raw "Use: podman logs $DEVICE_NAME  (and see logs above, if any) for details."
    else
      err_raw "No container named '$DEVICE_NAME' was created. Image or entrypoint may be invalid."
    fi
    die "Container failed to start with Podman. See podman error output above."
  fi

  status "Container '$DEVICE_NAME' started in detached mode (ID: ${container_id:0:12})"
  
  # Give container a moment to initialize
  sleep 2
  
  local status_line
  status_line=$(podman ps -a --format '{{.Names}} {{.Status}}' | awk -v name="$DEVICE_NAME" '$1==name { $1=""; sub(/^ /,""); print; }')
  status "Container '$DEVICE_NAME' initial status: ${status_line:-unknown}"
}

start_log_follow_background() {
  local name="$1"

  if (( CONTAINER_LOG_FOLLOW_SECS <= 0 )); then
    status "Log follow disabled (CONTAINER_LOG_FOLLOW_SECS <= 0)."
    return
  fi

  status "Streaming logs from container '$name' during provisioning/startup (up to ${CONTAINER_LOG_FOLLOW_SECS}s)..."

  podman logs -f "$name" &
  CONTAINER_LOG_PID=$!

  (
    sleep "$CONTAINER_LOG_FOLLOW_SECS"
    if kill -0 "$CONTAINER_LOG_PID" >/dev/null 2>&1; then
      status "Stopping log stream after ${CONTAINER_LOG_FOLLOW_SECS}s (CONTAINER_LOG_FOLLOW_SECS)."
      kill "$CONTAINER_LOG_PID" >/dev/null 2>&1 || true
    fi
  ) &
}

stop_log_follow_background() {
  if [[ -n "${CONTAINER_LOG_PID:-}" ]]; then
    kill "$CONTAINER_LOG_PID" >/dev/null 2>&1 || true
    wait "$CONTAINER_LOG_PID" >/dev/null 2>&1 || true
    CONTAINER_LOG_PID=""
  fi
}

monitor_container_provisioning() {
  if [[ "$DRY_RUN" == "true" ]]; then
    status "DRY_RUN=true; skipping container log-follow and provisioning monitoring."
    return
  fi

  status "Monitoring container '$DEVICE_NAME' for startup/provisioning (timeout=${CONTAINER_MONITOR_TIMEOUT}s)..."
  echo "  Target: container stays in 'Up' state for at least ${CONTAINER_STABLE_SECONDS}s."
  echo "  Check interval: ${CONTAINER_CHECK_INTERVAL}s."

  start_log_follow_background "$DEVICE_NAME"

  local elapsed=0
  local running_since=-1

  while (( elapsed < CONTAINER_MONITOR_TIMEOUT )); do
    local ps_output status_line
    ps_output="$(podman ps -a --format '{{.Names}} {{.Status}}' 2>/dev/null || true)"
    status_line=""
    if [[ -n "$ps_output" ]]; then
      status_line=$(awk -v name="$DEVICE_NAME" '$1==name { $1=""; sub(/^ /,""); print; }' <<<"$ps_output")
    fi

    if [[ -z "$status_line" ]]; then
      err_raw "Container '$DEVICE_NAME' no longer exists."
      EXIT_MESSAGE="Container '$DEVICE_NAME' disappeared during monitoring."
      stop_log_follow_background
      die "Container '$DEVICE_NAME' was removed while monitoring startup/provisioning."
    fi

    if [[ "$status_line" =~ ^Exited ]]; then
      err_raw "Container '$DEVICE_NAME' exited during provisioning/startup. Status: $status_line"
      EXIT_MESSAGE="Container '$DEVICE_NAME' exited during provisioning/startup: $status_line"
      stop_log_follow_background
      die "Container '$DEVICE_NAME' exited: $status_line (see streaming logs above for provisioning errors)."
    fi

    if [[ "$status_line" =~ ^Up ]]; then
      if (( running_since < 0 )); then
        running_since=$elapsed
        status "Container '$DEVICE_NAME' is Up (observed at ~${elapsed}s). Monitoring for stable run..."
      fi

      local stable_for=$(( elapsed - running_since ))
      echo "  -> Container '$DEVICE_NAME' has been Up for ~${stable_for}s (target: ${CONTAINER_STABLE_SECONDS}s)."

      if (( stable_for >= CONTAINER_STABLE_SECONDS )); then
        status "Container '$DEVICE_NAME' has been running stably for at least ${CONTAINER_STABLE_SECONDS}s."
        stop_log_follow_background
        return 0
      fi
    else
      echo "  -> Container status: $status_line"
    fi

    sleep "$CONTAINER_CHECK_INTERVAL"
    elapsed=$(( elapsed + CONTAINER_CHECK_INTERVAL ))
  done

  warn "Container '$DEVICE_NAME' did not reach a stable running state within ${CONTAINER_MONITOR_TIMEOUT}s."
  EXIT_MESSAGE="Container '$DEVICE_NAME' did not reach a stable running state within ${CONTAINER_MONITOR_TIMEOUT}s."
  stop_log_follow_background
  die "Container '$DEVICE_NAME' did not reach a stable running state within ${CONTAINER_MONITOR_TIMEOUT}s. Review logs above."
}

create_systemd_service() {
  status "Generating systemd service for container auto-restart..."

  if ! command -v systemctl >/dev/null 2>&1; then
    warn "'systemctl' not found; skipping systemd unit creation. Container will not auto-start on boot, but it is deployed."
    return
  fi

  if ! podman help generate 2>/dev/null | grep -q systemd; then
    warn "'podman generate systemd' not available; skipping systemd unit creation. Container is deployed but not wired to systemd."
    return
  fi

  local unit_file="/etc/systemd/system/container-${DEVICE_NAME}.service"

  if [[ "$DRY_RUN" == "true" ]]; then
    status "DRY_RUN=true; not creating systemd unit."
    status "Would generate: $unit_file"
    return
  fi

  # Generate the systemd unit file
  status "Generating systemd unit: $unit_file"
  if ! podman generate systemd --new --name "$DEVICE_NAME" > "$unit_file" 2>&1; then
    warn "Failed to generate systemd unit at ${unit_file}. Container is deployed but will not auto-start via systemd."
    return
  fi

  # Reload systemd to recognize the new unit
  status "Reloading systemd daemon..."
  if ! systemctl daemon-reload; then
    warn "systemctl daemon-reload failed; systemd may not see the new unit. Container remains deployed and running."
    return
  fi

  # Enable the service for boot persistence
  status "Enabling service for automatic start on boot..."
  if ! systemctl enable "container-${DEVICE_NAME}.service"; then
    warn "Failed to enable container-${DEVICE_NAME}.service. It may not start automatically on reboot."
  fi

  # Start the service now
  status "Starting systemd service..."
  if ! systemctl start "container-${DEVICE_NAME}.service"; then
    warn "Failed to start container-${DEVICE_NAME}.service via systemd. Check 'journalctl -u container-${DEVICE_NAME}.service'."
  else
    status "Systemd service container-${DEVICE_NAME}.service enabled and started."
  fi

  echo
  echo "Service management commands:"
  echo "  systemctl status container-${DEVICE_NAME}.service"
  echo "  systemctl restart container-${DEVICE_NAME}.service"
  echo "  journalctl -u container-${DEVICE_NAME}.service -f"
}

show_summary() {
  echo
  echo "-------------------------------------------------------"
  echo " GuardDog AI sensor deployment completed"
  echo "-------------------------------------------------------"
  echo " Deployment ID : ${DEPLOYMENT_ID:-unknown}"
  echo " Container name: $DEVICE_NAME"
  echo " Image         : $IMAGE_NAME"
  echo " Config dir    : $CONFIG_DIR"
  echo " SPAN/TAP ifcs : ${SPAN_INTERFACES:-none}"
  echo " CUSTOMER_TAG  : ${CUSTOMER_TAG:-unset}"
  echo " SITE_TAG      : ${SITE_TAG:-unset}"
  echo " ENV_TAG       : ${ENV_TAG:-unset}"
  echo " Systemd unit  : container-${DEVICE_NAME}.service (if created)"
  echo " Log file      : $LOG_FILE"
  echo " Webhook URL   : $WEBHOOK_URL"
  echo
  echo "Useful commands:"
  echo "  systemctl status container-${DEVICE_NAME}.service"
  echo "  journalctl -u container-${DEVICE_NAME}.service -f"
  echo "  podman ps --filter name=${DEVICE_NAME}"
  echo "  podman logs ${DEVICE_NAME} -f"
  echo
  echo "Note: Initial provisioning and updates may take some time,"
  echo "depending on network bandwidth and load."
}

main() {
  init_deployment_id
  check_os
  check_resources
  ensure_podman
  check_network
  check_firewall

  if [[ "$NON_INTERACTIVE" == "true" ]]; then
    collect_config_non_interactive
  else
    collect_config_interactive
  fi
  validate_device_name "$DEVICE_NAME"

  select_span_interfaces
  validate_span_interfaces
  prepare_directories
  pull_image
  deploy_container
  monitor_container_provisioning

  if [[ "$DRY_RUN" == "false" ]]; then
    create_systemd_service
  else
    warn "Dry-run mode: systemd service was NOT created."
  fi

  EXIT_MESSAGE="Deployment completed successfully."
  show_summary
}

main "$@"