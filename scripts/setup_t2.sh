#!/usr/bin/env bash
# =============================================================================
# setup_t2.sh – T2 driver installation (prebuilt .deb)
# Author:   Phoenix Kern
 macbook-ubuntu-t2| macbook-ubuntu-t2
# Version:  1.0.0
# Purpose:  Installs apple-bce, applesmc-t2 and apple-touchbar drivers
#           from prebuilt .deb packages. No source compilation —
#           ppa.t2linux.org may be unreachable and kernel builds are
#           unreliable on Ubuntu 24.04 HWE kernels.
# Path:     scripts/setup_t2.sh
# Status:   stable
#
# Prerequisites:
#   - Prebuilt .deb packages in the same directory as this script:
#       apple-bce_*.deb
#       applesmc-t2_*.deb
#       apple-touchbar_*.deb
#   - Download: https://github.com/t2linux
#
# Usage:
#   sudo ./scripts/setup_t2.sh [--deb-dir <path>]
#
# Options:
#   --deb-dir <path>   Directory containing the .deb files (default: script directory)
# =============================================================================

set -euo pipefail
trap 'echo "[ERROR] setup_t2.sh failed at line ${LINENO}." >&2' ERR

LOG_FILE="/var/log/macbook-t2-setup.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEB_DIR="${SCRIPT_DIR}"

log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --deb-dir)
            DEB_DIR="$2"
            shift 2
            ;;
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

log "Starting setup_t2.sh | deb-dir=${DEB_DIR}"

# =============================================================================
# Step 1: Verify prerequisites
# =============================================================================
for pkg in dkms build-essential "linux-headers-$(uname -r)"; do
    if ! dpkg -s "${pkg}" &>/dev/null; then
        log "[ERROR] Missing package: ${pkg}. Run scripts/base.sh first."
        exit 1
    fi
done

# =============================================================================
# Step 2: Locate .deb packages
# =============================================================================
BCE_DEB=$(find "${DEB_DIR}" -maxdepth 1 -name 'apple-bce_*.deb' | head -1)
SMC_DEB=$(find "${DEB_DIR}" -maxdepth 1 -name 'applesmc-t2_*.deb' | head -1)
TB_DEB=$(find "${DEB_DIR}"  -maxdepth 1 -name 'apple-touchbar_*.deb' | head -1)

for deb in "${BCE_DEB}" "${SMC_DEB}" "${TB_DEB}"; do
    if [[ -z "${deb}" || ! -f "${deb}" ]]; then
        log "[ERROR] Required .deb package not found in ${DEB_DIR}"
        log "        Expected: apple-bce_*.deb, applesmc-t2_*.deb, apple-touchbar_*.deb"
        log "        Download: https://github.com/t2linux"
        exit 1
    fi
done

log "Packages found:"
log "  apple-bce:      ${BCE_DEB}"
log "  applesmc-t2:    ${SMC_DEB}"
log "  apple-touchbar: ${TB_DEB}"

# =============================================================================
# Step 3: Install packages in dependency order
# =============================================================================
log "Installing apple-bce (T2 base communication)..."
dpkg -i "${BCE_DEB}"

log "Installing applesmc-t2 (SMC sensors + fan control)..."
dpkg -i "${SMC_DEB}"

log "Installing apple-touchbar (Touch Bar integration)..."
dpkg -i "${TB_DEB}"

# =============================================================================
# Step 4: Update module dependencies
# =============================================================================
log "Running depmod -a..."
depmod -a

# =============================================================================
# Step 5: Load modules immediately (without reboot)
# =============================================================================
log "Loading T2 kernel modules..."
modprobe apple_bce && log "[  OK  ] apple_bce loaded"
modprobe applesmc  && log "[  OK  ] applesmc loaded"
modprobe vhci_hcd  && log "[  OK  ] vhci_hcd loaded"

# =============================================================================
# Step 6: Install persistent module configuration
# =============================================================================
T2_CONF="/etc/modules-load.d/t2.conf"
if [[ ! -f "${T2_CONF}" ]]; then
    log "Installing module autoload config: ${T2_CONF}"
    cp "$(dirname "${SCRIPT_DIR}")/configs/t2.conf" "${T2_CONF}" 2>/dev/null || \
    printf 'apple_bce\napplesmc\nvhci_hcd\n' > "${T2_CONF}"
    log "[  OK  ] ${T2_CONF} written"
else
    log "[INFO] ${T2_CONF} already exists — not overwritten"
fi

# =============================================================================
# Step 7: Install and enable macfanctld
# =============================================================================
log "Installing macfanctld..."
apt install -y macfanctld
systemctl enable --now macfanctld && log "[  OK  ] macfanctld enabled and started"

# =============================================================================
# Step 8: Verify DKMS status
# =============================================================================
log "DKMS status:"
dkms status | tee -a "${LOG_FILE}"

log "setup_t2.sh completed. Reboot recommended."
echo ""
echo "Recommended next steps:"
echo "  1. sudo reboot"
echo "  2. sudo ./scripts/install_wlan_firmware.sh <firmware-usb-mount-point>"
echo "  3. sudo ./scripts/health.sh"
