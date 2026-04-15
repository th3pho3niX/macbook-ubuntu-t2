#!/usr/bin/env bash
# =============================================================================
# fix_suspend.sh – Suspend/resume stability fix for MacBook Pro 2018 (T2)
# Author:   Phoenix Kern
 macbook-ubuntu-t2| macbook-ubuntu-t2
# Version:  1.1.0
# Purpose:  Applies kernel parameters and systemd hooks to reduce hang-on-
#           resume issues caused by T2-related drivers (apple_bce, vhci_hcd).
#           Unloads problematic modules before suspend, reloads on resume.
# Path:     scripts/fix_suspend.sh
# Status:   stable
#
# Mechanism:
#   1. Installs a systemd sleep hook that unloads T2 modules pre-suspend.
#   2. Reloads modules post-resume.
#   3. Applies GRUB kernel parameter for S3 deep sleep (mem_sleep_default=deep).
#   4. Disables USB autosuspend for the T2 bridge via udev.
#
# Usage:
#   sudo ./scripts/fix_suspend.sh [--dry-run]
#
# Options:
#   --dry-run   Print all changes without applying them
# =============================================================================

set -euo pipefail
trap 'echo "[ERROR] fix_suspend.sh failed at line ${LINENO}." >&2' ERR

LOG_FILE="/var/log/macbook-t2-setup.log"
DRY_RUN=0

SLEEP_HOOK="/lib/systemd/system-sleep/t2-suspend.sh"
GRUB_DEFAULT="/etc/default/grub"

log() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

ok()   { echo "[  OK  ] $*"; }
info() { echo "[ INFO ] $*"; }
warn() { echo "[ WARN ] $*"; }

# --- Parse arguments ---
for arg in "$@"; do
    case "${arg}" in
        --dry-run) DRY_RUN=1 ;;
        --help)
            grep '^# ' "$0" | sed 's/^# //'
            exit 0
            ;;
        *) echo "[ERROR] Unknown argument: ${arg}" >&2; exit 1 ;;
    esac
done

# --- Root check ---
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root (sudo)." >&2
    exit 1
fi

log "Starting fix_suspend.sh | dry-run=${DRY_RUN}"

# =============================================================================
# Step 1: systemd sleep hook – unload T2 modules before suspend
# =============================================================================
log "Installing systemd sleep hook: ${SLEEP_HOOK}"

HOOK_CONTENT='#!/usr/bin/env bash
# T2 module suspend/resume hook
# Managed by: scripts/fix_suspend.sh – DO NOT EDIT MANUALLY

MODULES=(vhci_hcd apple_bce applesmc)

case "$1" in
    pre)
        for mod in "${MODULES[@]}"; do
            if lsmod | grep -q "^${mod}"; then
                modprobe -r "${mod}" 2>/dev/null || true
            fi
        done
        ;;
    post)
        for mod in applesmc apple_bce vhci_hcd; do
            modprobe "${mod}" 2>/dev/null || true
        done
        ;;
esac
'

if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] Would write sleep hook to: ${SLEEP_HOOK}"
    echo "--- hook content ---"
    echo "${HOOK_CONTENT}"
    echo "---"
else
    echo "${HOOK_CONTENT}" > "${SLEEP_HOOK}"
    chmod 755 "${SLEEP_HOOK}"
    ok "Sleep hook installed and set executable"
fi

# =============================================================================
# Step 2: GRUB kernel parameter – enable deep sleep (S3)
# =============================================================================
log "Checking GRUB config for mem_sleep_default=deep"

if [[ ! -f "${GRUB_DEFAULT}" ]]; then
    warn "GRUB config not found at ${GRUB_DEFAULT} — skipping"
else
    CURRENT_LINE=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT' "${GRUB_DEFAULT}" || true)

    if echo "${CURRENT_LINE}" | grep -q "mem_sleep_default=deep"; then
        info "mem_sleep_default=deep already present in GRUB config — no change"
    else
        log "Adding mem_sleep_default=deep to GRUB_CMDLINE_LINUX_DEFAULT"
        NEW_LINE=$(echo "${CURRENT_LINE}" | \
            sed 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 mem_sleep_default=deep"/')

        if [[ "${DRY_RUN}" -eq 1 ]]; then
            echo "[DRY-RUN] Would replace: ${CURRENT_LINE}"
            echo "[DRY-RUN] With:         ${NEW_LINE}"
            echo "[DRY-RUN] Would run update-grub"
        else
            sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|${NEW_LINE}|" "${GRUB_DEFAULT}"
            update-grub
            ok "GRUB updated with mem_sleep_default=deep"
        fi
    fi
fi

# =============================================================================
# Step 3: Disable USB autosuspend for apple_bce interface
# =============================================================================
UDEV_RULE="/etc/udev/rules.d/99-t2-usb.rules"
log "Writing udev rule to disable autosuspend for T2 BCE interface"

USB_RULE='# Disable USB autosuspend for Apple T2 BCE virtual device
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", ATTR{power/autosuspend}="-1"
'

if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] Would write udev rule to: ${UDEV_RULE}"
    echo "${USB_RULE}"
else
    echo "${USB_RULE}" > "${UDEV_RULE}"
    udevadm control --reload-rules
    ok "udev rule written: ${UDEV_RULE}"
fi

# =============================================================================
# Step 4: Verify current sleep state availability
# =============================================================================
log "Available system sleep states:"

if [[ -f /sys/power/mem_sleep ]]; then
    SLEEP_STATES=$(cat /sys/power/mem_sleep)
    log "${SLEEP_STATES}"
    if echo "${SLEEP_STATES}" | grep -q '\[deep\]'; then
        ok "S3 deep sleep is the active sleep state"
    elif echo "${SLEEP_STATES}" | grep -q 'deep'; then
        warn "S3 deep sleep is available but not active — reboot required"
    else
        warn "S3 deep sleep not detected on this kernel/hardware"
    fi
else
    warn "/sys/power/mem_sleep not accessible"
fi

echo ""
log "fix_suspend.sh completed | Reboot required to apply GRUB changes"
echo "[ INFO ] Reboot required to activate GRUB kernel parameters."
echo "[ INFO ] After reboot, test with: systemctl suspend"
echo "[ INFO ] Check resume with:        dmesg | grep -i 'suspend\|resume\|apple\|bce'"
