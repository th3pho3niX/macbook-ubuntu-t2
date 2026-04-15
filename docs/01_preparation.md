# 01 – Preparation


**Target Device:** MacBook Pro 15″ (2018) with Apple T2 Chip
**Target OS:** Ubuntu 24.04 LTS Noble Numbat (Single-Boot)

---

## 1.1 Data Backup and Power Supply

- Complete backup of all macOS data (Time Machine or manually) before starting.
- Keep device connected to AC power supply throughout the entire installation.

---

## 1.2 Configure Secure Boot and Boot Media

In macOS Recovery mode (hold `Cmd + R` during startup):

1. **Open Startup Security Utility**.
2. **Secure Boot:** Leave as `Full Security`.
3. **Allowed Boot Media:** Enable `Allow booting from external or removable media`.

> This configuration allows booting from the USB installation media without disabling the T2 chip integrity check.

---

## 1.3 Disable FileVault

Before repartitioning in macOS:

`System Settings → Security & Privacy → FileVault → Disable`

The internal SSD must be completely decrypted before it can be repartitioned. LUKS encryption will be configured during the Ubuntu installation.

---

## 1.4 Check Partition Overview

```bash
diskutil list
```

Identify the internal NVMe drive (typically `/dev/disk0` or `/dev/disk1`) and available partition space.

---

## 1.5 Create Ubuntu Installation Media

Download Ubuntu 24.04 LTS ISO (Noble Numbat) from [ubuntu.com](https://ubuntu.com/download/desktop).

**Verify checksum:**

```bash
echo "<expected_sha256>  ubuntu-24.04-desktop-amd64.iso" | shasum -a 256 --check
```

**Write to USB stick** (device identifier from `diskutil list`):

```bash
diskutil unmountDisk /dev/diskN
sudo dd if=ubuntu-24.04-desktop-amd64.iso of=/dev/rdiskN bs=4m status=progress
sync
```

> `rdiskN` (with `r` prefix) uses raw access on macOS and is significantly faster than `/dev/diskN`.

---

## 1.6 Prepare Broadcom Firmware (Second USB Stick)

The T2 MacBook uses a Broadcom BCM4364 chip whose firmware is **not** included in the Ubuntu kernel. The required files must come from an existing macOS installation.

**Required Files:**

```
brcmfmac4364b2-pcie.apple,kauai.bin
brcmfmac4364b2-pcie.apple,kauai.clm_blob
brcmfmac4364b2-pcie.apple,kauai.txt
```

**Source:** `/usr/share/firmware/` from a licensed macOS installation.

Place these three files on a second USB stick. The script `scripts/install_wlan_firmware.sh` automates the later installation including SHA-256 verification.

> ⚠️ **License Note:** The Broadcom firmware is subject to proprietary license terms and may not be distributed publicly. This repository does not contain firmware files.

---

## 1.7 Prerequisites Checklist

| Item | Done |
|---|---|
| Complete backup created | ☐ |
| Power supply secured | ☐ |
| Secure Boot: external boot allowed | ☐ |
| FileVault disabled | ☐ |
| Ubuntu ISO downloaded and checksum verified | ☐ |
| Bootable USB stick created | ☐ |
| Broadcom firmware on second USB stick | ☐ |

---

**Next:** [02_installation.md](02_installation.md)
