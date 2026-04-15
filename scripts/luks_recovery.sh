#!/usr/bin/env bash
# =============================================================================
# luks_recovery.sh – LUKS unlock and chroot recovery
# Author:   Phoenix Kern
 macbook-ubuntu-t2| macbook-ubuntu-t2
# Version:  1.1.0
# Purpose:  Unlocks a LUKS-encrypted LVM volume from a live environment and
#           mounts the installed system for chroot-based repair.
#           Designed for MacBook Pro 2018 NVMe layout post LUKS+LVM install.
# Path:     scripts/luks_recovery.sh
# Status:   stable
#
# Usage (from Ubuntu live USB):
#   sudo ./scripts/luks_recovery.sh [options]
#
# Options:
#   --disk <device>     NVMe disk device (default: /dev/nvme0n1)
#   --part <number>     LUKS partition number (default: 2)
#   --vg <name>         LVM Volume Group name (default: vg_ubuntu)
#   --lv-root <name>    Root Logical Volume name (default: lv_root)
#   --mapper <name>     LUKS mapper name (default: crypt_lvm)
#   --mount <path>      Chroot mount point (default: /mnt/recovery)
#   --help              Print this help and exit
#
# Example:
#   sudo ./scripts/luks_recovery.sh --disk /dev/nvme0n1 --vg vg_ubuntu
# =============================================================================

set -euo pipefail
trap 'cleanup; echo "[ERROR] luks_recovery.sh failed at line ${LINENO}." >&2' ERR

# --- Defaults ---
DISK="/dev/nvme0n1"
PART_NUM="2"
VG_NAME="vg_ubuntu"
LV_ROOT="lv_root"
MAPPER_NAME="crypt_lvm"
MOUNT_BASE="/mnt/recovery"
LOG_FILE="/tmp/luks_recovery.log"
MOUNTED=0

log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

usage() {
    sed -n '/^# Usage/,/^# ====/p' "$0" | grep '^#' | sed 's/^# \?//'
    exit 0
}

cleanup() {
    if [[ "${MOUNTED}" -eq 1 ]]; then
        log "Cleanup: unmounting bind mounts and target"
        for d in dev/pts dev proc sys run; do
            umount "${MOUNT_BASE}/${d}" 2>/dev/null || true
        done
        umount "${MOUNT_BASE}/boot/efi" 2>/dev/null || true
        umount "${MOUNT_BASE}" 2>/dev/null || true
        vgchange -an "${VG_NAME}" 2>/dev/null || true
        cryptsetup close "${MAPPER_NAME}" 2>/dev/null || true
        log "Cleanup complete"
    fi
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --disk)    DISK="$2";         shift 2 ;;
        --part)    PART_NUM="$2";     shift 2 ;;
        --vg)      VG_NAME="$2";      shift 2 ;;
        --lv-root) LV_ROOT="$2";      shift 2 ;;
        --mapper)  MAPPER_NAME="$2";  shift 2 ;;
        --mount)   MOUNT_BASE="$2";   shift 2 ;;
        --help)    usage ;;
        *) echo "[ERROR] Unknown argument: $1" >&2; exit 1 ;;
    esac
done

LUKS_PART="${DISK}p${PART_NUM}"
LV_PATH="/dev/${VG_NAME}/${LV_ROOT}"
EFI_PART="${DISK}p1"

# --- Root check ---
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root (sudo)." >&2
    exit 1
fi

log "Starting luks_recovery.sh"
log "LUKS partition : ${LUKS_PART}"
log "Volume Group   : ${VG_NAME}"
log "Root LV        : ${LV_PATH}"
log "Mount base     : ${MOUNT_BASE}"

# --- Verify partition exists ---
if [[ ! -b "${LUKS_PART}" ]]; then
    echo "[ERROR] Block device not found: ${LUKS_PART}" >&2
    echo "        Available block devices:" >&2
    lsblk -o NAME,SIZE,TYPE,FSTYPE >&2
    exit 1
fi

# --- Check required tools ---
for tool in cryptsetup vgchange mount chroot lsblk; do
    if ! command -v "${tool}" &>/dev/null; then
        echo "[ERROR] Required tool not found: ${tool}" >&2
        echo "        Install with: sudo apt install cryptsetup lvm2" >&2
        exit 1
    fi
done

# --- Open LUKS container ---
if cryptsetup status "${MAPPER_NAME}" &>/dev/null; then
    log "LUKS container already open: /dev/mapper/${MAPPER_NAME}"
else
    log "Opening LUKS container on ${LUKS_PART}"
    echo "[ INFO ] Enter the LUKS passphrase when prompted."
    cryptsetup open "${LUKS_PART}" "${MAPPER_NAME}"
fi

# --- Activate LVM Volume Group ---
log "Activating Volume Group: ${VG_NAME}"
vgchange -ay "${VG_NAME}"

# --- Verify LV exists ---
if [[ ! -b "${LV_PATH}" ]]; then
    echo "[ERROR] Logical volume not found: ${LV_PATH}" >&2
    echo "        Available LVs:" >&2
    lvs >&2
    exit 1
fi

# --- Create mount point ---
mkdir -p "${MOUNT_BASE}"

# --- Mount root filesystem ---
log "Mounting root LV: ${LV_PATH} → ${MOUNT_BASE}"
mount "${LV_PATH}" "${MOUNT_BASE}"
MOUNTED=1

# --- Mount EFI partition ---
if [[ -b "${EFI_PART}" ]]; then
    mkdir -p "${MOUNT_BASE}/boot/efi"
    mount "${EFI_PART}" "${MOUNT_BASE}/boot/efi"
    log "EFI partition mounted: ${EFI_PART} → ${MOUNT_BASE}/boot/efi"
else
    log "[WARN] EFI partition not found at ${EFI_PART} — skipping"
fi

# --- Bind mount virtual filesystems ---
log "Binding virtual filesystems"
for d in dev proc sys run; do
    mkdir -p "${MOUNT_BASE}/${d}"
    mount --bind "/${d}" "${MOUNT_BASE}/${d}"
done
mount --bind /dev/pts "${MOUNT_BASE}/dev/pts"

# --- Copy DNS resolver into chroot ---
cp /etc/resolv.conf "${MOUNT_BASE}/etc/resolv.conf" 2>/dev/null || true

# --- Enter chroot ---
log "Entering chroot environment at ${MOUNT_BASE}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  LUKS volume unlocked and mounted."
echo "  Entering chroot. Type 'exit' to leave and trigger cleanup."
echo ""
echo "  Common repair commands:"
echo "    grub-install --target=x86_64-efi --efi-directory=/boot/efi"
echo "    update-grub"
echo "    update-initramfs -u"
echo "    dpkg -i /path/to/apple-bce_*.deb"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

chroot "${MOUNT_BASE}" /bin/bash || true

# --- Cleanup on exit ---
cleanup
log "luks_recovery.sh session ended"
