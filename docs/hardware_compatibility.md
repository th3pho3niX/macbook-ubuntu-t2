# Hardware Compatibility Matrix

**Target device:** MacBook Pro 15″ (2018) – A1990
**Tested with:** Ubuntu 24.04 LTS Noble Numbat | Kernel 6.8.x (HWE)

---

## Component Status

| Component | Status | Driver / Method | Notes |
|---|---|---|---|
| WLAN (BCM4364) | ✅ Functional | `brcmfmac` + proprietary firmware | Manual firmware installation required |
| Bluetooth | ⚠️ Partial | `btusb` via `apple_bce` | Basic function available; pairing reliability varies |
| Keyboard | ✅ Functional | `apple_bce` + `vhci_hcd` | All keys functional |
| Trackpad | ✅ Functional | `apple_bce` + `vhci_hcd` | Multi-touch and gestures functional |
| Touch Bar | ⚠️ Partial | `apple-touchbar` (.deb) | Function keys active; dynamic display limited |
| Touch ID | ❌ Not supported | — | No Linux driver available |
| Audio (internal) | ✅ Functional | `snd_hda_intel` | Manual sink selection required on first boot |
| Audio (headphone) | ✅ Functional | `snd_hda_intel` | 3.5mm jack functional |
| iGPU (Intel UHD 630) | ✅ Functional | `i915` (kernel built-in) | Loaded automatically |
| dGPU (AMD Radeon 560X) | ✅ Functional | `amdgpu` (kernel built-in) | Loaded automatically |
| GPU switching | ✅ Functional | `switcheroo-control` | `switcherooctl launch --gpu 1 <app>` |
| Hardware video decode | ⚠️ Limited | `vainfo` / VA-API | Browser GPU acceleration limited |
| Fan control | ✅ Functional | `applesmc` + `macfanctld` | Temperature-based regulation active |
| Temperature sensors | ✅ Functional | `applesmc` + `coretemp` | TC0P, Ts0S, GPU edge via `sensors` |
| Suspend / Resume | ⚠️ Stable with fix | Sleep hook + `mem_sleep_default=deep` | `fix_suspend.sh` required |
| Thunderbolt 3 | ⚠️ Partial | Kernel built-in | USB and DisplayPort functional; hot-plug kernel-dependent |
| USB-A / USB-C | ✅ Functional | Kernel built-in | All ports functional |
| SD card reader | ✅ Functional | `sdhci_pci` | Detected automatically |
| Camera (FaceTime HD) | ✅ Functional | `apple_bce` | Exposed as UVC device |
| Power management | ✅ Functional | TLP + `cpufreq` | MacBook-specific TLP config active |
| Secure Boot | ✅ Active (restricted) | T2 chip | External boot mode only |

---

## Sensor Groups (lm-sensors)

| Sensor Group | Description | Relevant Values |
|---|---|---|
| `coretemp-isa-0000` | Intel CPU core temperatures | `Package id 0`, `Core 0–5` |
| `amdgpu-pci-0100` | AMD GPU temperature | `edge` (case temperature) |
| `applesmc-isa-0300` | Apple T2 SMC sensors | `TC0P`, `Ts0S`, fan RPM |

**Temperature thresholds:**

| Sensor | Normal | Warning threshold |
|---|---|---|
| Package id 0 (CPU) | 40–65 °C | > 85 °C |
| TC0P (CPU Proximity) | 40–60 °C | > 85 °C |
| Ts0S (Palm Rest) | 35–50 °C | > 70 °C |
| amdgpu edge | 40–70 °C | > 90 °C |
| Fans | 1200–3500 RPM | > 5500 RPM (sustained load) |

---

## Kernel Module Overview

| Module | Function | Autoload via |
|---|---|---|
| `apple_bce` | T2 chip base communication (keyboard, trackpad, camera) | `/etc/modules-load.d/t2.conf` |
| `applesmc` | SMC sensors, fan control | `/etc/modules-load.d/t2.conf` |
| `vhci_hcd` | Virtual USB bridge for keyboard/trackpad | `/etc/modules-load.d/t2.conf` |
| `brcmfmac` | Broadcom WLAN | Automatic after firmware installation |
| `i915` | Intel iGPU | Kernel built-in |
| `amdgpu` | AMD dGPU | Kernel built-in |
| `snd_hda_intel` | Audio | Kernel built-in |

---

## Known Limitations

- **Touch ID:** No Linux support; hardware fingerprint reader is not accessible.
- **Bluetooth stability:** Simultaneous WLAN/BT use (coexistence) can reduce WLAN throughput.
- **Browser GPU acceleration:** WebGL and video decoding frequently do not use full GPU acceleration on T2 MacBooks under Linux — increased CPU load under such workloads is inherent to the hardware configuration.
- **Kernel updates:** After major kernel version updates (e.g. 6.8 → 6.11), T2 modules may temporarily fail to load; `dkms status` and manual `modprobe` can help.
- **Thunderbolt hot-plug:** Devices connected after boot are detected depending on kernel version.
