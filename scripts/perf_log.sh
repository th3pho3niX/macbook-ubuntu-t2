#!/usr/bin/env bash
# =============================================================================
# perf_log.sh – Periodic performance logging
# Author:   Phoenix Kern
 macbook-ubuntu-t2| macbook-ubuntu-t2
# Version:  1.2.0
# Changelog:
#   1.2.0 – CPU calculation extended to full /proc/stat fields (incl. iowait,
#            irq, steal); sensors parsing more robust (multi-pattern);
#            systemd dependency on network-online.target corrected
#   1.1.0 – Extended CSV schema, GPU temp, systemd timer
#   1.0.0 – Initial release
# =============================================================================

set -euo pipefail
trap 'echo "[INFO] perf_log.sh terminated."; exit 0' SIGINT SIGTERM

INTERVAL="${1:-60}"
LOGDIR="${HOME}/.local/share/perf-logs"
OUTFILE="${2:-${LOGDIR}/perf.csv}"

mkdir -p "${LOGDIR}"

log_info() {
    echo "[$(date '+%Y-%m-%dT%H:%M:%S')] $*"
}

# --- Write CSV header on first run ---
if [[ ! -f "${OUTFILE}" ]]; then
    echo "timestamp,cpu_user,cpu_system,cpu_iowait,cpu_steal,cpu_idle,load1,load5,load15,mem_used_mb,mem_free_mb,swap_used_mb,cpu_temp_c,fan_left_rpm,fan_right_rpm,gpu_temp_c,gpu_active" >> "${OUTFILE}"
    log_info "CSV file created: ${OUTFILE}"
fi

collect() {
    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S')

    # --- CPU utilization (full /proc/stat fields, 1s delta) ---
    # Fields: cpu user nice system idle iowait irq softirq steal guest guest_nice
    local u1 n1 s1 i1 iow1 irq1 soft1 steal1
    read -r _ u1 n1 s1 i1 iow1 irq1 soft1 steal1 _ _ < /proc/stat
    sleep 1
    local u2 n2 s2 i2 iow2 irq2 soft2 steal2
    read -r _ u2 n2 s2 i2 iow2 irq2 soft2 steal2 _ _ < /proc/stat

    local total_diff
    total_diff=$(( (u2+n2+s2+i2+iow2+irq2+soft2+steal2) - (u1+n1+s1+i1+iow1+irq1+soft1+steal1) ))

    local cpu_user cpu_system cpu_iowait cpu_steal cpu_idle
    if [[ "${total_diff}" -gt 0 ]]; then
        cpu_user=$(awk   "BEGIN {printf \"%.1f\", ((${u2}-${u1})+(${n2}-${n1}))/${total_diff}*100}")
        cpu_system=$(awk "BEGIN {printf \"%.1f\", (${s2}-${s1})/${total_diff}*100}")
        cpu_iowait=$(awk "BEGIN {printf \"%.1f\", (${iow2}-${iow1})/${total_diff}*100}")
        cpu_steal=$(awk  "BEGIN {printf \"%.1f\", (${steal2}-${steal1})/${total_diff}*100}")
        cpu_idle=$(awk   "BEGIN {printf \"%.1f\", (${i2}-${i1})/${total_diff}*100}")
    else
        cpu_user="N/A"; cpu_system="N/A"; cpu_iowait="N/A"
        cpu_steal="N/A"; cpu_idle="N/A"
    fi

    # --- Load average ---
    local load1 load5 load15
    read -r load1 load5 load15 _ < /proc/loadavg

    # --- RAM and swap ---
    local mem_used mem_free swap_used
    mem_used=$(free -m | awk '/^Mem:/{print $3}')
    mem_free=$(free -m | awk '/^Mem:/{print $4}')
    swap_used=$(free -m | awk '/^Swap:/{print $3}')

    # --- CPU temperature (robust multi-pattern matching) ---
    # Priority: coretemp Package id 0 → Tctl/Tdie (AMD) → TC0P (applesmc)
    local cpu_temp="N/A"
    if command -v sensors &>/dev/null; then
        cpu_temp=$(sensors 2>/dev/null \
            | grep -E 'Package id 0|Tctl|Tdie|TC0P' \
            | head -1 \
            | awk '{print $2}' \
            | tr -d '+°C')
        cpu_temp="${cpu_temp:-N/A}"
    fi

    # --- Fan speeds (left / right via applesmc) ---
    local fan_left="N/A"
    local fan_right="N/A"
    if command -v sensors &>/dev/null; then
        local fan_data
        fan_data=$(sensors 2>/dev/null | grep -i 'RPM' | awk '{print $2}')
        fan_left=$(echo "${fan_data}"  | sed -n '1p')
        fan_right=$(echo "${fan_data}" | sed -n '2p')
        fan_left="${fan_left:-N/A}"
        fan_right="${fan_right:-N/A}"
    fi

    # --- GPU temperature (amdgpu-pci edge sensor) ---
    local gpu_temp="N/A"
    if command -v sensors &>/dev/null; then
        gpu_temp=$(sensors 2>/dev/null \
            | grep -A5 'amdgpu' \
            | grep 'edge' \
            | awk '{print $2}' \
            | tr -d '+°C' \
            | head -1)
        gpu_temp="${gpu_temp:-N/A}"
    fi

    # --- Active GPU driver ---
    local gpu_active="N/A"
    if lsmod | grep -q '^amdgpu' && lsmod | grep -q '^i915'; then
        gpu_active="amdgpu+i915"
    elif lsmod | grep -q '^amdgpu'; then
        gpu_active="amdgpu"
    elif lsmod | grep -q '^i915'; then
        gpu_active="i915"
    fi

    echo "${ts},${cpu_user},${cpu_system},${cpu_iowait},${cpu_steal},${cpu_idle},${load1},${load5},${load15},${mem_used},${mem_free},${swap_used},${cpu_temp},${fan_left},${fan_right},${gpu_temp},${gpu_active}" >> "${OUTFILE}"
}

log_info "Performance logging started | Interval: ${INTERVAL}s | Output: ${OUTFILE}"
log_info "Stop with: Ctrl+C"

while true; do
    collect
    sleep $(( INTERVAL > 1 ? INTERVAL - 1 : 1 ))
done
