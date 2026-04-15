#!/usr/bin/env bash
# =============================================================================
# base.sh – Install prerequisite packages
# Author:   Phoenix Kern
 macbook-ubuntu-t2| macbook-ubuntu-t2
# Version:  1.0.0
# Purpose:  Installs all prerequisite packages for T2 driver installation
#           and post-install configuration.
# Path:     scripts/base.sh
# Status:   stable
#
# Usage:
#   sudo ./scripts/base.sh
# =============================================================================

set -euo pipefail
trap 'echo "[ERROR] base.sh failed at line ${LINENO}." >&2' ERR

LOG_FILE="/var/log/macbook-t2-setup.log"

log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# --- Root check ---
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root (sudo)." >&2
    exit 1
fi

log "Starting base.sh – prerequisite installation"

# =============================================================================
# Step 1: Update package index
# =============================================================================
log "Updating package index..."
apt update

# =============================================================================
# Step 2: Install prerequisite packages
# =============================================================================
PACKAGES=(
    curl
    git
    dkms
    build-essential
    linux-headers-"$(uname -r)"
    lm-sensors
    htop
    tmux
    wget
    mokutil
    efibootmgr
    pciutils
    usbutils
    inxi
)

log "Installing prerequisite packages: ${PACKAGES[*]}"
apt install -y "${PACKAGES[@]}"

# =============================================================================
# Step 3: Verify kernel headers
# =============================================================================
KERNEL_VERSION=$(uname -r)
HEADER_PATH="/usr/src/linux-headers-${KERNEL_VERSION}"

if [[ -d "${HEADER_PATH}" ]]; then
    log "[  OK  ] Kernel headers found: ${HEADER_PATH}"
else
    log "[ERROR] Kernel headers missing for ${KERNEL_VERSION} — DKMS builds will fail."
    exit 1
fi

log "base.sh completed successfully."
echo ""
echo "Next step: sudo ./scripts/setup_t2.sh"
