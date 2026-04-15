# 03 – Post-Installation

**Scope:** T2 driver installation, Broadcom WLAN firmware, fan control, audio configuration, and system hardening steps.

---

## 3.1 Initial Network Access (No WLAN Available)

The Broadcom BCM4364 chip requires proprietary firmware not included in the Ubuntu installer. Until WLAN is operational, use one of the following methods:

**Option A – iPhone USB Tethering:**

```bash
# Connect iPhone via USB, enable Personal Hotspot
# The ipheth kernel module is included in the Ubuntu kernel
ip link show  # verify usb0 or similar interface appears
```

**Option B – USB Ethernet Adapter** (if available)

---

## 3.2 Base Package Installation

Run `scripts/base.sh` or manually:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git dkms build-essential linux-headers-$(uname -r) \
    lm-sensors htop tmux wget
```

---

## 3.3 Broadcom WLAN Firmware

Copy the firmware files from the second USB stick:

```bash
# Mount the firmware USB stick (replace sdX with correct identifier)
sudo mount /dev/sdX /mnt

# Copy firmware files
sudo cp /mnt/brcmfmac4364b2-pcie.apple,kauai* /lib/firmware/brcm/

# Rebuild initramfs
sudo update-initramfs -u

# Reload wireless modules
sudo modprobe -r brcmfmac
sudo modprobe brcmfmac
```

After reboot, the WLAN interface (`wlp3s0`) should be detected by NetworkManager.

---

## 3.4 T2 Driver Installation

The PPA `ppa.t2linux.org` may be unreachable. Use prebuilt `.deb` packages sourced from the [t2linux GitHub releases](https://github.com/t2linux).

Required packages (in installation order):

| Package | Function |
|---|---|
| `apple-bce` | Base communication with T2 chip (keyboard, trackpad bridge) |
| `applesmc-t2` | SMC sensor and fan control interface |
| `apple-touchbar` | Touch Bar integration |

```bash
# Install in correct order
sudo dpkg -i apple-bce_*.deb
sudo dpkg -i applesmc-t2_*.deb
sudo dpkg -i apple-touchbar_*.deb

# Update module dependencies
sudo depmod -a

# Load modules immediately (without reboot)
sudo modprobe apple_bce
sudo modprobe applesmc
sudo modprobe vhci_hcd
```

Run `scripts/setup_t2.sh` to automate the above.

---

## 3.5 Kernel Module Persistence

Create `/etc/modules-load.d/t2.conf` (see `configs/t2.conf`):

```
apple_bce
applesmc
vhci_hcd
```

This ensures modules are loaded at every boot without manual intervention.

---

## 3.6 Fan Control

```bash
sudo apt install -y macfanctld

# Enable and start the service
sudo systemctl enable --now macfanctld

# Verify fan control is active
sudo systemctl status macfanctld

# Check sensor output
sensors
```

Reference configuration: `configs/macfanctld.conf.example`

---

## 3.7 Audio

Internal speakers use the `snd_hda_intel` driver. If audio is absent after boot:

```bash
sudo modprobe snd_hda_intel
pulseaudio --check || pulseaudio --start
```

The correct output sink for internal speakers:

```
alsa_output.pci-0000_02_00.3.Speakers
```

Set as default in PipeWire/PulseAudio:

```bash
pactl set-default-sink alsa_output.pci-0000_02_00.3.Speakers
```

---

## 3.8 Firefox (apt, non-snap)

Ubuntu 24.04 defaults to the snap-packaged Firefox. To use the apt version:

```bash
# Remove snap version
sudo snap remove firefox

# Add Mozilla PPA
sudo add-apt-repository ppa:mozillateam/ppa

# Set PPA priority
echo '
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
' | sudo tee /etc/apt/preferences.d/mozilla-firefox

sudo apt update
sudo apt install -y firefox
```

---

## 3.9 Disable Snap Repair Service

```bash
sudo systemctl disable --now snapd.snap-repair.service
```

> **Note:** `apt-daily.timer` and `apt-daily-upgrade.timer` are **not** disabled. These control Ubuntu's automatic security updates (`unattended-upgrades`) and must remain active.

---

## 3.10 Bluetooth

Basic Bluetooth functionality is available after loading the T2 modules. Pairing reliability varies — this is a known behaviour on T2 MacBooks under Linux.

```bash
# Check Bluetooth service
sudo systemctl status bluetooth

# Check Bluetooth controller and connections
bluetoothctl show
bluetoothctl devices
```

**Pairing a device:**

```bash
bluetoothctl
[bluetooth]# power on
[bluetooth]# scan on
# Wait for the device to appear, then:
[bluetooth]# pair <MAC>
[bluetooth]# connect <MAC>
[bluetooth]# trust <MAC>
[bluetooth]# exit
```

**Known limitations on T2 + Linux:**

- Bluetooth and WLAN share the same chip on the BCM4364 (coexistence mode). Simultaneous use can affect WLAN stability.
- After kernel updates, `apple_bce` may need to reinitialise the Bluetooth bridge (`sudo modprobe -r apple_bce && sudo modprobe apple_bce`).
- `brcm_patchram_plus` is not required for this chip on Ubuntu 24.04.

---

## 3.11 Note: GPU Acceleration on Linux (T2 MacBook)

Browsers and many desktop applications frequently do not use full GPU hardware acceleration on T2 MacBooks under Linux. This leads to increased CPU load — particularly with WebGL, video playback and AI-based upscaling.

**Cause:** DRM/KMS initialisation through the GPU switching architecture (i915 + amdgpu) combined with limited VA-API support in browsers.

**Diagnostics:**

```bash
# Check VA-API status
sudo apt install -y vainfo
vainfo 2>&1 | grep -E 'driver|profile|error'

# Firefox: check GPU acceleration
# about:support → Graphics → GPU #1 → WebRender enabled?

# Chromium: GPU status
# chrome://gpu → Graphics Feature Status
```

**Assessment for this setup:**

Increased CPU load on individual cores under browser load is inherent to the hardware configuration and not a defect.

---

## 3.12 System Health Verification

```bash
chmod +x scripts/health.sh
sudo ./scripts/health.sh
```

Expected output: all T2 modules loaded, `macfanctld` active, WLAN interface visible, audio sink present.

---

## Next Step

→ [04 – Troubleshooting](04_troubleshooting.md)
