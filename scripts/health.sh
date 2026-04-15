#!/usr/bin/env bash
# =============================================================================
# health.sh – System diagnostics and module verification
# Author:   Phoenix Kern
 macbook-ubuntu-t2| macbook-ubuntu-t2
# Version:  1.1.0
# Purpose:  Verifies T2 kernel modules, services, sensors, WLAN, audio,
#           GPU drivers and DKMS components for correct operation.
# Path:     scripts/health.sh
# Status:   stable
#
# Usage:
#   sudo ./scripts/health.sh
# =============================================================================

set -euo pipefail
trap 'echo "[ERROR] health.sh: unexpected error at line ${LINENO}." >&2' ERR

ERRORS=0
WARNINGS=0
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')

SEPARATOR="────────────────────────────────────────────────────────────"

ok()  { echo "[  OK  ] $*"; }
err() { echo "[ ERR  ] $*"; (( ERRORS++ ))   || true; }
warn(){ echo "[ WARN ] $*"; (( WARNINGS++ )) || true; }
info(){ echo "[  --  ] $*"; }

# --- Root check ---
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root (sudo)." >&2
    exit 1
fi

echo "${SEPARATOR}"
echo "  health.sh – MacBook Pro 2018 T2 / Ubuntu 24.04 LTS"
echo "  ${TIMESTAMP}"
echo "${SEPARATOR}"
echo ""

# =============================================================================
# 1. Kernel modules
# =============================================================================
echo "▶ Kernel Modules"

for module in apple_bce applesmc vhci_hcd; do
    if lsmod | grep -q "^${module}"; then
        ok "Module loaded: ${module}"
    else
        err "Module NOT loaded: ${module} — run: modprobe ${module}"
    fi
done

if lsmod | grep -q "^brcmfmac"; then
    ok "Module loaded: brcmfmac"
else
    warn "brcmfmac not loaded — WLAN firmware may not be installed"
fi

echo ""

# =============================================================================
# 2. Services
# =============================================================================
echo "▶ Services"

for service in macfanctld NetworkManager; do
    if systemctl is-active --quiet "${service}"; then
        ok "Service active: ${service}"
    else
        err "Service NOT active: ${service} — run: systemctl start ${service}"
    fi
done

if systemctl is-active --quiet switcheroo-control 2>/dev/null; then
    ok "Service active: switcheroo-control"
else
    info "Service not active: switcheroo-control (optional)"
fi

echo ""

# =============================================================================
# 3. Network / WLAN
# =============================================================================
echo "▶ Network"

WLAN_IFACE=$(ip link show | awk -F': ' '/wl/{print $2}' | head -1)
if [[ -n "${WLAN_IFACE}" ]]; then
    ok "WLAN interface detected: ${WLAN_IFACE}"
else
    err "No WLAN interface found — check brcmfmac firmware in /lib/firmware/brcm/"
fi

if ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
    ok "Network connectivity: OK (1.1.1.1 reachable)"
else
    warn "No network connectivity (expected in offline environments)"
fi

echo ""

# =============================================================================
# 4. Audio
# =============================================================================
echo "▶ Audio"

if command -v pactl &>/dev/null; then
    SINK_COUNT=$(pactl list short sinks 2>/dev/null | wc -l)
    if [[ "${SINK_COUNT}" -gt 0 ]]; then
        ok "Audio output device(s) present: ${SINK_COUNT} found"
        pactl list short sinks 2>/dev/null | while read -r line; do
            info "  ${line}"
        done
    else
        err "No audio sinks found — check snd_hda_intel: modprobe snd_hda_intel"
    fi
else
    warn "pactl not found — audio check skipped (install pactl)"
fi

echo ""

# =============================================================================
# 5. DKMS status
# =============================================================================
echo "▶ DKMS"

if command -v dkms &>/dev/null; then
    DKMS_OUTPUT=$(dkms status 2>/dev/null)
    if [[ -n "${DKMS_OUTPUT}" ]]; then
        ok "DKMS modules registered:"
        echo "${DKMS_OUTPUT}" | while read -r line; do
            info "  ${line}"
        done
    else
        warn "No DKMS modules registered — T2 drivers may be prebuilt-only"
    fi
else
    warn "dkms not installed — DKMS check skipped"
fi

echo ""

# =============================================================================
# 6. Sensors
# =============================================================================
echo "▶ Sensors"

if command -v sensors &>/dev/null; then
    SENSOR_OUTPUT=$(sensors 2>/dev/null)
    if [[ -n "${SENSOR_OUTPUT}" ]]; then
        ok "Sensor data available"

        CPU_TEMP=$(echo "${SENSOR_OUTPUT}" | grep -E 'Package id 0|TC0P' | head -1 | awk '{print $3}' || true)
        [[ -n "${CPU_TEMP}" ]] && info "CPU temp:    ${CPU_TEMP}"

        FAN_LEFT=$(echo "${SENSOR_OUTPUT}"  | grep -i 'Left side'  | awk '{print $3, $4}' || true)
        FAN_RIGHT=$(echo "${SENSOR_OUTPUT}" | grep -i 'Right side' | awk '{print $3, $4}' || true)
        [[ -n "${FAN_LEFT}" ]]  && info "Fan left:    ${FAN_LEFT}"
        [[ -n "${FAN_RIGHT}" ]] && info "Fan right:   ${FAN_RIGHT}"

        GPU_TEMP=$(echo "${SENSOR_OUTPUT}" | grep -A5 'amdgpu' | grep 'edge' | awk '{print $2}' || true)
        [[ -n "${GPU_TEMP}" ]] && info "GPU temp:    ${GPU_TEMP}"
    else
        err "sensors returned no output — run: sudo sensors-detect --auto"
    fi
else
    err "lm-sensors not installed — run: apt install lm-sensors"
fi

echo ""

# =============================================================================
# 7. GPU drivers
# =============================================================================
echo "▶ GPU Drivers"

if lsmod | grep -q "^i915"; then
    ok "Intel iGPU driver (i915) loaded"
else
    warn "i915 not loaded — Intel GPU may be inactive"
fi

if lsmod | grep -q "^amdgpu"; then
    ok "AMD dGPU driver (amdgpu) loaded"
else
    warn "amdgpu not loaded — AMD GPU may be inactive (check GRUB parameters)"
fi

DRM_COUNT=$(find /dev/dri -maxdepth 1 -name 'card*' 2>/dev/null | wc -l)
if [[ "${DRM_COUNT}" -ge 1 ]]; then
    ok "DRM devices present: ${DRM_COUNT} found"
else
    err "No DRM devices in /dev/dri/ — GPU driver not functional"
fi

echo ""

# =============================================================================
# 8. Suspend/Resume
# =============================================================================
echo "▶ Suspend/Resume"

SLEEP_HOOK="/lib/systemd/system-sleep/t2-suspend.sh"
if [[ -f "${SLEEP_HOOK}" && -x "${SLEEP_HOOK}" ]]; then
    ok "T2 sleep hook installed and executable"
else
    warn "Sleep hook missing or not executable: ${SLEEP_HOOK}"
    warn "  Run: sudo ./scripts/fix_suspend.sh"
fi

if [[ -f /sys/power/mem_sleep ]]; then
    SLEEP_STATE=$(cat /sys/power/mem_sleep)
    if echo "${SLEEP_STATE}" | grep -q '\[deep\]'; then
        ok "S3 deep sleep active: ${SLEEP_STATE}"
    else
        warn "S3 deep sleep not active: ${SLEEP_STATE}"
        warn "  Add mem_sleep_default=deep to GRUB_CMDLINE_LINUX_DEFAULT"
    fi
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "${SEPARATOR}"
if [[ "${ERRORS}" -eq 0 && "${WARNINGS}" -eq 0 ]]; then
    echo "  Result: All checks passed ✓"
elif [[ "${ERRORS}" -eq 0 ]]; then
    echo "  Result: ${WARNINGS} warning(s), 0 errors — system operational"
else
    echo "  Result: ${ERRORS} error(s), ${WARNINGS} warning(s) — action required"
fi
echo "${SEPARATOR}"

exit "${ERRORS}"
