#!/usr/bin/env bash
# =============================================================================
# install_wlan_firmware.sh – Broadcom BCM4364 WLAN firmware installer
# Author:   Phoenix Kern
 macbook-ubuntu-t2| macbook-ubuntu-t2
# Version:  1.1.0
# Purpose:  Copies Broadcom WLAN firmware from a USB source to the correct
#           kernel firmware path and rebuilds initramfs. Does NOT download
#           firmware from the internet. Source must be provided locally
#           from a licensed macOS installation.
# Path:     scripts/install_wlan_firmware.sh
# Status:   stable
#
# Usage:
#   sudo ./scripts/install_wlan_firmware.sh /path/to/firmware/source
#
# The source directory must contain:
#   brcmfmac4364b2-pcie.apple,kauai.bin
#   brcmfmac4364b2-pcie.apple,kauai.clm_blob
#   brcmfmac4364b2-pcie.apple,kauai.txt
#
# Firmware origin: Licensed macOS installation or linux-firmware backport.
# Redistribution of these files is not permitted.
# =============================================================================

set -euo pipefail
trap 'echo "[ERROR] install_wlan_firmware.sh failed at line ${LINENO}. Exit code: $?" >&2' ERR

# --- Constants ---
FIRMWARE_DEST="/lib/firmware/brcm"
LOG_FILE="/var/log/macbook-t2-setup.log"
REQUIRED_FILES=(
    "brcmfmac4364b2-pcie.apple,kauai.bin"
    "brcmfmac4364b2-pcie.apple,kauai.clm_blob"
    "brcmfmac4364b2-pcie.apple,kauai.txt"
)

log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

ok()   { echo "[  OK  ] $*"; }
info() { echo "[ INFO ] $*"; }
warn() { echo "[ WARN ] $*"; }

usage() {
    echo "Usage: sudo $0 <firmware_source_directory>"
    echo ""
    echo "  <firmware_source_directory>  Path containing Broadcom firmware files."
    echo "                               Typically the root of a mounted USB stick."
    echo ""
    echo "Required files in source directory:"
    for f in "${REQUIRED_FILES[@]}"; do
        echo "  - ${f}"
    done
    exit 1
}

# --- Root check ---
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root (sudo)." >&2
    exit 1
fi

# --- Argument check ---
if [[ $# -lt 1 ]]; then
    usage
fi

FIRMWARE_SRC="${1}"

if [[ ! -d "${FIRMWARE_SRC}" ]]; then
    echo "[ERROR] Source directory does not exist: ${FIRMWARE_SRC}" >&2
    exit 1
fi

log "Starting install_wlan_firmware.sh | Source: ${FIRMWARE_SRC}"

# --- Verify all required firmware files are present ---
log "Verifying required firmware files"
MISSING=0
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "${FIRMWARE_SRC}/${file}" ]]; then
        echo "[ERROR] Missing firmware file: ${FIRMWARE_SRC}/${file}" >&2
        (( MISSING++ )) || true
    fi
done

if [[ "${MISSING}" -gt 0 ]]; then
    echo "[ERROR] ${MISSING} required firmware file(s) not found. Aborting." >&2
    exit 1
fi

# --- Compute checksums before copy (for audit log) ---
log "SHA256 checksums of source firmware files:"
for file in "${REQUIRED_FILES[@]}"; do
    sha256sum "${FIRMWARE_SRC}/${file}" | tee -a "${LOG_FILE}"
done

# --- Create destination if it does not exist ---
if [[ ! -d "${FIRMWARE_DEST}" ]]; then
    log "Creating firmware destination: ${FIRMWARE_DEST}"
    mkdir -p "${FIRMWARE_DEST}"
fi

# --- Copy firmware files ---
log "Copying firmware files to ${FIRMWARE_DEST}"
for file in "${REQUIRED_FILES[@]}"; do
    cp -v "${FIRMWARE_SRC}/${file}" "${FIRMWARE_DEST}/${file}"
    chmod 644 "${FIRMWARE_DEST}/${file}"
done

# --- Verify copied files ---
log "Verifying integrity of copied files"
for file in "${REQUIRED_FILES[@]}"; do
    SRC_HASH=$(sha256sum "${FIRMWARE_SRC}/${file}" | awk '{print $1}')
    DST_HASH=$(sha256sum "${FIRMWARE_DEST}/${file}" | awk '{print $1}')
    if [[ "${SRC_HASH}" != "${DST_HASH}" ]]; then
        echo "[ERROR] Hash mismatch after copy: ${file}" >&2
        echo "        Source: ${SRC_HASH}" >&2
        echo "        Dest:   ${DST_HASH}" >&2
        exit 1
    fi
    log "Verified: ${file} [${DST_HASH:0:16}...]"
done

ok "All firmware files copied and verified"

# --- Unload brcmfmac if currently active ---
if lsmod | grep -q brcmfmac; then
    log "Unloading brcmfmac module"
    modprobe -r brcmfmac || true
fi

# --- Rebuild initramfs ---
log "Rebuilding initramfs (update-initramfs -u)"
update-initramfs -u

# --- Reload module ---
log "Loading brcmfmac module"
modprobe brcmfmac || log "[WARN] brcmfmac load failed — reboot may be required"

# --- Verify interface appears ---
sleep 2
if ip link show | grep -qE 'wlp|wlan'; then
    IFACE=$(ip link show | grep -oE 'wlp[^ :]+|wlan[^ :]+' | head -1)
    log "WLAN interface detected: ${IFACE}"
    ok "WLAN interface active: ${IFACE}"
else
    log "[WARN] No WLAN interface detected — reboot required"
    warn "No WLAN interface detected. Reboot to apply firmware."
fi

log "install_wlan_firmware.sh completed successfully"
