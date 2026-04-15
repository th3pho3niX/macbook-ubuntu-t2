# Ubuntu 24.04 LTS on MacBook Pro 2018 (T2 Chip) – Complete Installation Guide

---

**Author:** Phoenix Kern
**Date:** November 2025
**Kernel (tested):** 6.8.x (Ubuntu 24.04 HWE)
**Document status:** final

---

## Table of Contents

1. [Hardware Overview](#1-hardware-overview)
2. [Preparation](#2-preparation)
3. [Installation](#3-installation)
4. [Post-Installation – Drivers](#4-post-installation--drivers)
5. [Hardware Validation](#5-hardware-validation)
6. [Optimisations](#6-optimisations)
7. [Performance Logging](#7-performance-logging)
8. [Common Problems and Solutions](#8-common-problems-and-solutions)
9. [System State (Final Report)](#9-system-state-final-report)

---

## 1 Hardware Overview

| Component | Specification |
|---|---|
| Model | MacBook Pro 15″ (2018) |
| CPU | Intel Core i7-8750H, 6C/12T, 2.2–4.1 GHz |
| iGPU | Intel UHD Graphics 630 (`i915`) |
| dGPU | AMD Radeon Pro 560X, 4 GB (`amdgpu`) |
| RAM | 16 GB DDR4-2400 MHz |
| Storage | 512 GB NVMe SSD (internal) |
| WLAN | Broadcom BCM4364 (`brcmfmac`) |
| Bluetooth | Bluetooth 5.0 |
| Security chip | Apple T2 (embedded controller) |
| Target OS | Ubuntu 24.04 LTS Desktop (single-boot) |

---

## 2 Preparation

### 2.1 Backup and Power Supply

- Full backup of all macOS data (Time Machine or manual) completed before starting.
- Device connected to AC power throughout the entire installation.

### 2.2 Secure Boot and Boot Media Configuration

In macOS Recovery Mode (`Cmd + R` at startup):

1. Open **Startup Security Utility**.
2. **Secure Boot:** Leave at `Full Security`.
3. **Allowed Boot Media:** Enable `Allow booting from external or removable media`.

This configuration allows booting from the USB installation medium while retaining the T2 chip integrity check.

### 2.3 Check Partition Layout

```bash
diskutil list
```

Identify the internal NVMe drive (typically `/dev/disk0` or `/dev/disk1`) and available partition space.

### 2.4 Create Installation Medium

Download Ubuntu 24.04 LTS ISO (Noble Numbat) from [ubuntu.com](https://ubuntu.com/download/desktop).

Verify checksum:

```bash
echo "<expected_sha256>  ubuntu-24.04-desktop-amd64.iso" | shasum -a 256 --check
```

Write to USB stick (device identifier from `diskutil list`):

```bash
diskutil unmountDisk /dev/diskN
sudo dd if=ubuntu-24.04-desktop-amd64.iso of=/dev/rdiskN bs=4m status=progress
sync
```

### 2.5 Prepare Broadcom Firmware (second USB stick)

The T2 MacBook uses a Broadcom BCM4364 chip whose firmware is **not** included in the Ubuntu kernel. Required files:

```
brcmfmac4364b2-pcie.apple,kauai.bin
brcmfmac4364b2-pcie.apple,kauai.clm_blob
brcmfmac4364b2-pcie.apple,kauai.txt
```

Source: licensed macOS installation. Copy these files onto a second USB stick.

> ⚠️ **License notice:** The Broadcom firmware is subject to proprietary license terms and may not be distributed publicly. This repository contains no firmware files. By using `scripts/install_wlan_firmware.sh`, the user confirms that the firmware was lawfully acquired.

### 2.6 Disable FileVault

Before repartitioning in macOS:

`System Preferences → Security & Privacy → FileVault → Turn Off`

---

## 3 Installation

### 3.1 Boot from USB

Hold the Option key (`⌥`) at startup → Boot manager → Select Ubuntu medium → **Install Ubuntu**.

### 3.2 Partitioning and LUKS Encryption

Target layout for `/dev/nvme0n1` (manual partitioning in the installer):

| Partition | Size | Type | Mount Point |
|---|---|---|---|
| `nvme0n1p1` | 1024 MB | FAT32 | `/boot/efi` |
| `nvme0n1p2` | remaining | LUKS container (LVM) | — |

Inside the LUKS container (LVM):

| Logical Volume | Size | Filesystem | Mount Point |
|---|---|---|---|
| `lv_root` | remaining | ext4 | `/` |
| `lv_swap` | 8192 MB | swap | `[SWAP]` |

Manual setup via terminal in the live environment:

```bash
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 crypt_lvm
pvcreate /dev/mapper/crypt_lvm
vgcreate vg_ubuntu /dev/mapper/crypt_lvm
lvcreate -L 8G -n lv_swap vg_ubuntu
lvcreate -l 100%FREE -n lv_root vg_ubuntu
mkfs.ext4 /dev/vg_ubuntu/lv_root
mkswap /dev/vg_ubuntu/lv_swap
```

> The LUKS passphrase is entered at every boot. Loss of the passphrase results in complete data loss.

### 3.3 Installer Configuration

- Installation type: **Something else** (manual)
- `lv_root` → `/` with ext4, format
- `lv_swap` → enable swap
- EFI partition → `/boot/efi` (do not reformat)
- **Deselect "Install third-party software"** – no functional Broadcom driver available via this mechanism for the T2 MacBook

### 3.4 First Reboot: GRUB Issues

GRUB may not appear in the boot picker on the first reboot.

**Resolution:** Hold the Option key, manually select the Ubuntu EFI entry.

If no entry appears, boot from the live USB and reinstall GRUB via chroot:

```bash
# Open LUKS container and activate LVM
cryptsetup open /dev/nvme0n1p2 crypt_lvm
vgchange -ay vg_ubuntu

# Mount the system
mount /dev/vg_ubuntu/lv_root /mnt
mount /dev/nvme0n1p1 /mnt/boot/efi

# Bind virtual filesystems
for d in dev proc sys; do mount --bind /$d /mnt/$d; done
mount --bind /dev/pts /mnt/dev/pts

# Enter chroot and reinstall GRUB
chroot /mnt
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
update-grub
exit

# Cleanup
for d in dev/pts dev proc sys; do umount /mnt/$d; done
umount /mnt/boot/efi && umount /mnt
vgchange -an vg_ubuntu && cryptsetup close crypt_lvm
```

> `scripts/luks_recovery.sh` automates the complete chroot entry process.

---

## 4 Post-Installation – Drivers

### 4.1 Network Access Without WLAN

Since WLAN is not functional after initial installation:

**Option A – iPhone USB Tethering:**

```bash
# Connect iPhone via USB, enable Personal Hotspot
# The ipheth module is included in the Ubuntu kernel
ip link show  # interface usb0 or similar appears automatically
```

**Option B – USB Ethernet Adapter**

### 4.2 Install Base Packages

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git dkms build-essential \
    linux-headers-$(uname -r) lm-sensors htop tmux wget
```

### 4.3 Install Broadcom WLAN Firmware

Mount firmware from the second USB stick:

```bash
sudo mount /dev/sdX /mnt

sudo cp /mnt/brcmfmac4364b2-pcie.apple,kauai* /lib/firmware/brcm/

# Verify integrity (SHA-256 source vs. destination)
sha256sum /mnt/brcmfmac4364b2-pcie.apple,kauai.bin
sha256sum /lib/firmware/brcm/brcmfmac4364b2-pcie.apple,kauai.bin

sudo update-initramfs -u

sudo modprobe -r brcmfmac
sudo modprobe brcmfmac
```

After reboot, NetworkManager detects the WLAN interface (`wlp3s0`).

### 4.4 Install T2 Drivers (prebuilt .deb)

The PPA `ppa.t2linux.org` was unreachable. Solution: prebuilt `.deb` packages from [github.com/t2linux](https://github.com/t2linux).

Installation order (observe dependencies):

| Package | Function |
|---|---|
| `apple-bce` | Base communication with T2 chip (keyboard, trackpad bridge) |
| `applesmc-t2` | SMC sensors and fan control |
| `apple-touchbar` | Touch Bar integration |

```bash
sudo dpkg -i apple-bce_*.deb
sudo dpkg -i applesmc-t2_*.deb
sudo dpkg -i apple-touchbar_*.deb

sudo depmod -a

sudo modprobe apple_bce
sudo modprobe applesmc
sudo modprobe vhci_hcd
```

### 4.5 Load Kernel Modules Persistently

Create `/etc/modules-load.d/t2.conf`:

```
apple_bce
applesmc
vhci_hcd
```

These modules are loaded automatically at every boot.

### 4.6 Fan Control

```bash
sudo apt install -y macfanctld
sudo systemctl enable --now macfanctld
sudo systemctl status macfanctld
```

### 4.7 Audio

Internal speaker via `snd_hda_intel`. If no audio:

```bash
sudo modprobe snd_hda_intel
pactl set-default-sink alsa_output.pci-0000_02_00.3.Speakers
```

### 4.8 Firefox (apt instead of Snap)

```bash
sudo snap remove firefox
sudo add-apt-repository ppa:mozillateam/ppa

echo '
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
' | sudo tee /etc/apt/preferences.d/mozilla-firefox

sudo apt update && sudo apt install -y firefox
```

### 4.9 Bluetooth

Basic Bluetooth functionality is available after loading the T2 modules.

```bash
sudo systemctl status bluetooth

bluetoothctl
[bluetooth]# power on
[bluetooth]# scan on
[bluetooth]# pair <MAC>
[bluetooth]# connect <MAC>
[bluetooth]# trust <MAC>
[bluetooth]# exit
```

**Known limitations:** BCM4364 shares chip with WLAN (coexistence mode). Simultaneous use can affect WLAN stability. After kernel updates, reload `apple_bce` if needed:

```bash
sudo modprobe -r apple_bce && sudo modprobe apple_bce
```

### 4.10 Note: GPU Acceleration on Linux (T2 MacBook)

> **Note:** Browsers and many applications frequently do not use full GPU hardware acceleration on T2 MacBooks under Linux. This leads to increased CPU load — particularly with WebGL, video playback and AI-based upscaling. Individual CPU cores at 100% under such loads are inherent to the hardware configuration and not a defect.

Diagnostics:

```bash
sudo apt install -y vainfo
vainfo 2>&1 | grep -E 'driver|profile|error'
# Firefox: about:support → Graphics → WebRender
# Chromium: chrome://gpu → Graphics Feature Status
```

---

## 5 Hardware Validation

### 5.1 T2 Kernel Modules

```bash
lsmod | grep -E '^apple_bce|^applesmc|^vhci_hcd'
```

Expected output:

```
apple_bce             xxxxxx  0
applesmc              xxxxxx  0
vhci_hcd              xxxxxx  0
```

### 5.2 AMD GPU Driver (amdgpu / i915)

Both GPUs are supported by open-source kernel drivers — no manual driver installation required.

**Step 1 – Verify driver assignment via PCI:**

```bash
lspci -k | grep -EA3 'VGA|Display'
```

Expected output for MacBook Pro 2018:

```
Intel UHD 630       → Kernel driver in use: i915
AMD Radeon Pro 560X → Kernel driver in use: amdgpu
```

If `amdgpu` is not active, add boot parameters in `/etc/default/grub`:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash radeon.si_support=0 amdgpu.si_support=1"
```

```bash
sudo update-grub
# Reboot required
```

**Step 2 – Verify OpenGL and Vulkan:**

```bash
sudo apt install -y mesa-utils vulkan-tools

glxinfo | grep "OpenGL renderer"
# Expected: AMD Radeon Pro 560X (amdgpu)

vulkaninfo 2>/dev/null | grep "deviceName"
# Expected: AMD Radeon Pro 560X
```

**Step 3 – Monitor GPU load (radeontop):**

```bash
sudo apt install -y radeontop
sudo radeontop
```

Relevant idle metrics: GPU load < 5%, VRAM usage < 200 MB. Under graphics load, `gpu busy %` and clock frequency increase visibly.

**Step 4 – Monitor Intel iGPU:**

```bash
sudo apt install -y intel-gpu-tools
sudo intel_gpu_top
```

**Step 5 – Set up dual-GPU switching (switcheroo-control):**

`switcheroo-control` dynamically assigns applications to the power-efficient Intel GPU and only engages the AMD GPU under load.

```bash
sudo apt install -y switcheroo-control
sudo systemctl enable --now switcheroo-control

# List available GPUs
switcherooctl list
```

Launch an application explicitly on the AMD GPU:

```bash
switcherooctl launch --gpu 1 <application>
```

**GPU switching status (vgaswitcheroo):**

```bash
cat /sys/kernel/debug/vgaswitcheroo/switch 2>/dev/null
```

### 5.3 Sensors

```bash
sudo apt install -y lm-sensors
sudo sensors-detect --auto
sensors
```

Relevant sensor groups and expected output:

```
coretemp-isa-0000        ← Intel CPU core temperatures
Adapter: ISA adapter
Package id 0: +XX.X°C   ← total CPU temperature

amdgpu-pci-0100          ← AMD GPU temperature
Adapter: PCI adapter
edge:         +XX.X°C   ← GPU case temperature

applesmc-isa-0300        ← T2 chip SMC sensors
Adapter: ISA adapter
TC0P:         +XX.X°C   ← CPU proximity sensor
Ts0S:         +XX.X°C   ← palm rest sensor
Left side   : +XXXX RPM ← left fan
Right side  : +XXXX RPM ← right fan
```

Temperature thresholds (reference):

| Sensor | Normal | Warning threshold |
|---|---|---|
| TC0P (CPU) | 40–65 °C | > 85 °C |
| Ts0S (case) | 35–50 °C | > 70 °C |
| Fans | 1200–3000 RPM | > 5500 RPM (sustained load) |

### 5.4 WLAN Interface

```bash
ip link show wlp3s0
iwconfig wlp3s0 2>/dev/null
```

Connectivity test:

```bash
ping -c 4 1.1.1.1
```

### 5.5 Keyboard and Trackpad

```bash
# Check virtual USB bridge
lsusb | grep -i apple
cat /proc/bus/input/devices | grep -A5 -i 'apple\|trackpad\|keyboard'
```

### 5.6 DKMS Status

```bash
dkms status
```

Expected output for correctly installed T2 modules:

```
apple-bce/x.x.x, x.x.x-generic, x86_64: installed
applesmc-t2/x.x.x, x.x.x-generic, x86_64: installed
```

---

## 6 Optimisations

### 6.1 Power Management with TLP

TLP significantly reduces power consumption on battery.

```bash
sudo apt install -y tlp tlp-rdw
sudo systemctl enable --now tlp
sudo tlp-stat -s  # check status
```

Configuration file: `/etc/tlp.conf`

Relevant parameters for MacBook Pro 2018:

```ini
# CPU frequency scaling
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# PCIe power saving mode
PCIE_ASPM_ON_BAT=powersupersave

# USB autosuspend (exclude T2 devices)
USB_AUTOSUSPEND=1
USB_ALLOWLIST="05ac:*"   # exclude Apple devices (T2 bridge) from autosuspend
```

After configuration changes:

```bash
sudo tlp start
```

### 6.2 Fan Control with macfanctld / mbpfan

`macfanctld` reads temperature sensors via the `applesmc` module and regulates fan speed. `mbpfan` is a functionally equivalent alternative.

```bash
# Option A: macfanctld (recommended for T2 systems)
sudo apt install -y macfanctld
sudo systemctl enable --now macfanctld

# Option B: mbpfan (alternative)
sudo apt install -y mbpfan
sudo systemctl enable --now mbpfan
```

macfanctld configuration (reference: `configs/macfanctld.conf.example`):

```ini
[general]
poll_interval = 5

[fan0]
min_speed = 1200
max_speed = 6200

[temp_thresholds]
TC0P = 50 85
Ts0S = 45 75
```

```bash
sudo systemctl restart macfanctld
sudo systemctl status macfanctld
```

### 6.3 Disable Snap Repair Service

Disable the Snap repair service which generates unnecessary network activity:

```bash
sudo systemctl disable --now snapd.snap-repair.service
```

> **Note:** `apt-daily.timer` and `apt-daily-upgrade.timer` are **not** disabled. These control Ubuntu's automatic security updates (`unattended-upgrades`) and must remain active.

### 6.4 Suspend/Resume Stabilisation

T2 drivers occasionally cause hangs when waking from suspend.

**systemd sleep hook** (`/lib/systemd/system-sleep/t2-suspend.sh`):

```bash
#!/usr/bin/env bash
MODULES=(vhci_hcd apple_bce applesmc)

case "$1" in
    pre)
        for mod in "${MODULES[@]}"; do
            modprobe -r "${mod}" 2>/dev/null || true
        done
        ;;
    post)
        for mod in applesmc apple_bce vhci_hcd; do
            modprobe "${mod}" 2>/dev/null || true
        done
        ;;
esac
```

```bash
sudo chmod 755 /lib/systemd/system-sleep/t2-suspend.sh
```

**GRUB parameter for S3 deep sleep** in `/etc/default/grub`:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash mem_sleep_default=deep"
```

```bash
sudo update-grub
```

Check available sleep states:

```bash
cat /sys/power/mem_sleep
# Expected output: s2idle [deep]
```

---

## 7 Performance Logging

`perf_log.sh` periodically collects system metrics and writes structured CSV entries.

**CSV schema (v1.2.0):**

```
timestamp, cpu_user, cpu_system, cpu_iowait, cpu_steal, cpu_idle,
load1, load5, load15,
mem_used_mb, mem_free_mb, swap_used_mb,
cpu_temp_c, fan_left_rpm, fan_right_rpm,
gpu_temp_c, gpu_active
```

New in v1.2.0 vs v1.1.0: separate columns for `cpu_iowait` and `cpu_steal` from full `/proc/stat` evaluation. Sensor patterns more robust (`Package id 0|Tctl|Tdie|TC0P`).

**Manual start:**

```bash
chmod +x scripts/perf_log.sh

# Foreground (30-second interval)
./scripts/perf_log.sh 30

# Background
nohup ./scripts/perf_log.sh 60 > /dev/null 2>&1 &

# Watch data
tail -f ~/.local/share/perf-logs/perf.csv
```

**Automatic start via systemd:**

Service file `/etc/systemd/system/perf-logger@.service`:

```ini
[Unit]
Description=Performance Logger MacBook T2 (%i)
After=local-fs.target
Wants=local-fs.target

[Service]
Type=simple
User=%i
ExecStart=/home/%i/.local/share/perf-logs/perf_log.sh 60
Restart=on-failure
RestartSec=30
StandardOutput=append:/home/%i/.local/share/perf-logs/perf_logger.log
StandardError=append:/home/%i/.local/share/perf-logs/perf_logger.log

[Install]
WantedBy=multi-user.target
```

Installation:

```bash
sudo cp configs/perf-logger@.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now perf-logger@$(whoami).service

# Check status
systemctl status "perf-logger@$(whoami).service"
```

> **Note:** `perf_log.sh` runs as a daemon with its own infinite loop. A separate `.timer` is not required — the service starts automatically at boot and is restarted on failure.

**Simple analysis:**

```bash
# Average RAM usage
awk -F',' 'NR>1 {sum+=$8; n++} END {printf "RAM average: %.0f MB\n", sum/n}' \
    ~/.local/share/perf-logs/perf.csv

# Maximum CPU load (Load1)
awk -F',' 'NR>1 && $5>max {max=$5} END {print "Load1 max:", max}' \
    ~/.local/share/perf-logs/perf.csv

# Temperatures above 70°C
awk -F',' 'NR>1 && $11+0 > 70 {print $1, "CPU:", $11"°C"}' \
    ~/.local/share/perf-logs/perf.csv
```

---

## 8 Common Problems and Solutions

| Problem | Cause | Solution |
|---|---|---|
| WLAN not available | Broadcom firmware missing | Copy `brcmfmac4364b2-pcie.apple,kauai*` to `/lib/firmware/brcm/`, run `update-initramfs -u`, reboot |
| `applesmc` loads with error -5 | Outdated or incompatibly compiled driver | Use prebuilt `applesmc-t2` packages; restart `macfanctld` |
| `vhci_hcd` missing at boot | Module not in autoload config | Add entry to `/etc/modules-load.d/t2.conf`; immediate fix: `modprobe vhci_hcd` |
| T2 driver compilation fails | PPA `ppa.t2linux.org` unreachable or incompatible kernel | Use only prebuilt `.deb` packages from GitHub |
| GRUB not visible in boot picker | EFI entry not registered | Reinstall GRUB from live USB: `grub-install --target=x86_64-efi`, then `update-grub` |
| Firefox installed as snap | Ubuntu 24.04 snap priority | Add `ppa:mozillateam/ppa`, set apt priority, install via `apt install firefox` |
| Internal audio missing | `snd_hda_intel` not loaded or wrong sink | `modprobe snd_hda_intel`; set default sink to `alsa_output.pci-0000_02_00.3.Speakers` |
| Keyboard/trackpad not working | `apple_bce` or `vhci_hcd` not loaded | Check `lsmod \| grep apple_bce`; load manually or add to `modules-load.d` |
| High fan speed / no regulation | `macfanctld` not active or `applesmc` missing | Run `modprobe applesmc`; `systemctl enable --now macfanctld` |
| No sensor output in `sensors` | `applesmc` module not loaded | `sudo modprobe applesmc`; run `sudo sensors-detect --auto` |
| Hang after suspend/resume | T2 modules incompatible with S2idle | Install sleep hook (section 6.4); set `mem_sleep_default=deep` in GRUB |
| AMD GPU not detected | `amdgpu` not loaded | `lsmod \| grep amdgpu`; check kernel parameters `radeon.si_support=0 amdgpu.si_support=1` |

---

## 9 System State (Final Report)

The following checks confirm a fully functional system:

```bash
sudo ./scripts/health.sh
```

Expected result:

```
────────────────────────────────────────────────────────────
  health.sh – MacBook Pro 2018 T2 / Ubuntu 24.04 LTS
  2025-11-XX TXX:XX:XX
────────────────────────────────────────────────────────────

▶ Kernel Modules
[  OK  ] Module loaded: apple_bce
[  OK  ] Module loaded: applesmc
[  OK  ] Module loaded: vhci_hcd

▶ Services
[  OK  ] Service active: macfanctld
[  OK  ] Service active: NetworkManager

▶ Network
[  OK  ] WLAN interface detected: wlp3s0

▶ Audio
[  OK  ] Audio sink present

▶ DKMS
[  OK  ] DKMS modules installed

▶ Sensors
[  OK  ] Sensor data available
         TC0P:  +48.0°C
         Left side:  +1872 RPM
────────────────────────────────────────────────────────────
  Result: All checks passed (0 errors)
────────────────────────────────────────────────────────────
```

### Component Status (Final Validation)

| Component | Status | Notes |
|---|---|---|
| WLAN (BCM4364) | ✅ Functional | Manual firmware installation required |
| Bluetooth | ⚠️ Partial | Basic function available; pairing reliability varies |
| Keyboard | ✅ Functional | `apple_bce` + `vhci_hcd` |
| Trackpad | ✅ Functional | `apple_bce` + `vhci_hcd` |
| Touch Bar | ⚠️ Partial | Function keys active; dynamic display limited |
| Touch ID | ❌ Not supported | No Linux driver available |
| Audio (internal) | ✅ Functional | Manual sink selection required on first boot |
| iGPU (i915) | ✅ Functional | Automatic driver loading |
| dGPU (amdgpu) | ✅ Functional | Automatic driver loading |
| Fan control | ✅ Functional | `applesmc` + `macfanctld` |
| Sensors | ✅ Functional | Temperature and RPM via `sensors` |
| Suspend/Resume | ⚠️ Stable with fix | Sleep hook + `mem_sleep_default=deep` required |
| Thunderbolt 3 | ⚠️ Partial | USB and DisplayPort functional; hot-plug kernel-dependent |
| Power management | ✅ Functional | TLP active and configured |

---

*Created: November 2025 | Author: Phoenix Kern*
