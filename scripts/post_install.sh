#!/usr/bin/env bash
# =============================================================================
# post_install.sh – Post-install hardening and configuration
# Author:   Phoenix Kern
 macbook-ubuntu-t2| macbook-ubuntu-t2
# Version:  1.1.0
# Purpose:  Configures Firefox via apt, UFW firewall (SSH only),
#           Snap cleanup, TLP power management.
# Path:     scripts/post_install.sh
# Status:   stable
#
# Usage:
#   sudo ./scripts/post_install.sh [--no-firefox] [--no-ufw] [--no-tlp]
# =============================================================================

set -euo pipefail
trap 'echo "[ERROR] post_install.sh failed at line ${LINENO}." >&2' ERR

LOG_FILE="/var/log/macbook-t2-setup.log"

NO_FIREFOX=0
NO_UFW=0
NO_TLP=0

log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

ok()   { echo "[  OK  ] $*"; }
info() { echo "[ INFO ] $*"; }
warn() { echo "[ WARN ] $*"; }

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-firefox) NO_FIREFOX=1; shift ;;
        --no-ufw)     NO_UFW=1;     shift ;;
        --no-tlp)     NO_TLP=1;     shift ;;
        --help)
            grep '^# ' "$0" | sed 's/^# //'
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# --- Root check ---
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root (sudo)." >&2
    exit 1
fi

CALLING_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
log "Starting post_install.sh | user=${CALLING_USER}"

# =============================================================================
# Step 1: Disable Snap repair service
# =============================================================================
log "Disabling Snap repair service..."

SNAP_UNITS=(snapd.snap-repair.service)

for unit in "${SNAP_UNITS[@]}"; do
    if systemctl list-unit-files "${unit}" &>/dev/null; then
        systemctl disable --now "${unit}" 2>/dev/null || true
        ok "Disabled: ${unit}"
    else
        info "Unit not found (skipped): ${unit}"
    fi
done

# NOTE: apt-daily.timer and apt-daily-upgrade.timer are NOT disabled.
# These control Ubuntu's automatic security updates (unattended-upgrades).
# Disabling them would prevent automatic security patches — not recommended.

# =============================================================================
# Step 2: Firefox via apt (replace Snap version)
# =============================================================================
if [[ "${NO_FIREFOX}" -eq 0 ]]; then
    log "Installing Firefox via apt (replacing Snap)..."

    if snap list firefox &>/dev/null 2>&1; then
        snap remove firefox && ok "Snap Firefox removed"
    else
        info "Snap Firefox not installed — removal skipped"
    fi

    add-apt-repository -y ppa:mozillateam/ppa

    cat > /etc/apt/preferences.d/mozilla-firefox <<'EOF'
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF

    apt update
    apt install -y firefox
    ok "Firefox installed via apt (ppa:mozillateam/ppa)"
else
    info "Firefox installation skipped (--no-firefox)"
fi

# =============================================================================
# Step 3: UFW firewall (SSH only)
# =============================================================================
if [[ "${NO_UFW}" -eq 0 ]]; then
    log "Configuring UFW firewall..."

    apt install -y ufw

    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh

    ufw --force enable
    ufw status numbered
    ok "UFW configured and enabled (SSH only)"
    info "Open additional ports as needed: ufw allow <port>/tcp"
else
    info "UFW configuration skipped (--no-ufw)"
fi

# =============================================================================
# Step 4: TLP power management
# =============================================================================
if [[ "${NO_TLP}" -eq 0 ]]; then
    log "Installing and configuring TLP..."

    apt install -y tlp tlp-rdw

    TLP_CONF="/etc/tlp.conf"
    if [[ -f "${TLP_CONF}" ]]; then
        if ! grep -q "USB_ALLOWLIST.*05ac" "${TLP_CONF}"; then
            cat >> "${TLP_CONF}" <<'EOF'

# ── MacBook Pro 2018 T2 Overrides (added by post_install.sh) ─────────────────
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
PCIE_ASPM_ON_BAT=powersupersave
USB_AUTOSUSPEND=1
# Exclude Apple T2 BCE bridge from USB autosuspend
USB_ALLOWLIST="05ac:*"
EOF
            ok "TLP: MacBook-specific overrides added to ${TLP_CONF}"
        else
            info "TLP config already contains T2 overrides — not modified"
        fi
    fi

    systemctl enable --now tlp
    tlp start
    ok "TLP enabled and started"
else
    info "TLP installation skipped (--no-tlp)"
fi

# =============================================================================
# Step 5: switcheroo-control for dual-GPU switching
# =============================================================================
log "Installing switcheroo-control..."
apt install -y switcheroo-control
systemctl enable --now switcheroo-control
ok "switcheroo-control enabled"

# =============================================================================
# Step 6: Performance monitoring tools
# =============================================================================
log "Installing performance monitoring tools..."
apt install -y vainfo mesa-utils vulkan-tools radeontop intel-gpu-tools
ok "GPU monitoring tools installed"

log "post_install.sh completed successfully."
echo ""
echo "Recommended next steps:"
echo "  1. sudo ./scripts/health.sh"
echo "  2. Reboot to apply all changes"
