# Ubuntu 24.04 LTS on MacBook Pro 2018 (T2 Chip)

> **Status:** Production stable | Tested on MacBook Pro 15″ (2018) | Ubuntu 24.04 LTS Noble Numbat

This repository documents the complete installation, driver setup and configuration of Ubuntu 24.04 LTS on a MacBook Pro 2018 with Apple T2 security chip. All steps are reproducible and transparent.

---

## Hardware Specifications

| Component | Specification |
|---|---|
| CPU | Intel Core i7-8750H, 6C/12T, 2.2–4.1 GHz |
| GPU | Intel UHD 630 + AMD Radeon Pro 560X (4 GB) |
| RAM | 16 GB DDR4-2400 MHz |
| Storage | 512 GB NVMe SSD |
| Network | Broadcom BCM4364 (WLAN), Bluetooth 5.0 |
| Security | Apple T2 Chip (embedded controller) |
| Target OS | Ubuntu 24.04 LTS Desktop (single-boot) |

---

## Repository Structure

```
macbook-ubuntu-t2/
├── docs/
│   ├── 01_preparation.md              # Firmware, Secure Boot, partition overview
│   ├── 02_installation.md             # Partitioning, LUKS, installer
│   ├── 03_post_install.md             # Drivers, WLAN firmware, fans, audio
│   ├── 04_troubleshooting.md          # Known issues and solutions
│   ├── hardware_compatibility.md      # Component status matrix
│   └── complete_installation_guide.md # Consolidated full guide
├── scripts/
│   ├── base.sh                        # Install prerequisite packages
│   ├── setup_t2.sh                    # T2 driver installation (prebuilt .deb)
│   ├── install_wlan_firmware.sh       # Broadcom BCM4364 firmware installer
│   ├── luks_recovery.sh               # LUKS unlock + chroot from live USB
│   ├── fix_suspend.sh                 # Suspend/resume stability fix
│   ├── health.sh                      # System diagnostics and module verification
│   ├── perf_log.sh                    # Periodic performance logging (CSV)
│   └── post_install.sh                # Post-install hardening and configuration
├── configs/
│   ├── t2.conf                        # /etc/modules-load.d/ – kernel modules
│   ├── macfanctld.conf.example        # Fan control reference configuration
│   └── perf-logger@.service           # systemd service unit for perf_log.sh
└── .github/
    ├── ISSUE_TEMPLATE/
    │   ├── bug_report.md              # Report a bug
    │   └── hardware_report.md         # Hardware compatibility report
    └── workflows/
        └── lint.yml                   # Shell script linting via ShellCheck
```

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/th3pho3niX/macbook-ubuntu-t2.git
cd macbook-ubuntu-t2

# 2. Install prerequisites
chmod +x scripts/base.sh
sudo ./scripts/base.sh

# 3. Install T2 drivers (prebuilt .deb required — see docs/03_post_install.md)
chmod +x scripts/setup_t2.sh
sudo ./scripts/setup_t2.sh

# 4. Install WLAN firmware (firmware USB required)
chmod +x scripts/install_wlan_firmware.sh
sudo ./scripts/install_wlan_firmware.sh /path/to/firmware

# 5. Verify system health
chmod +x scripts/health.sh
sudo ./scripts/health.sh

# 6. Start performance logging (optional)
chmod +x scripts/perf_log.sh
nohup ./scripts/perf_log.sh 60 > /dev/null 2>&1 &
```

> **Note:** WLAN firmware files (`brcmfmac4364b2-pcie.apple,kauai*`) are **not** included in this repository for licensing reasons. See [docs/03_post_install.md](docs/03_post_install.md) for acquisition instructions.

---

## Documentation

| Document | Description |
|---|---|
| [Full Guide](docs/complete_installation_guide.md) | Complete documentation for all phases |
| [01 – Preparation](docs/01_preparation.md) | Secure Boot, backup, partition overview |
| [02 – Installation](docs/02_installation.md) | Partitioning, LUKS encryption, installer |
| [03 – Post-Installation](docs/03_post_install.md) | T2 drivers, WLAN, audio, fan control |
| [04 – Troubleshooting](docs/04_troubleshooting.md) | Problem/cause/solution reference |
| [Hardware Compatibility](docs/hardware_compatibility.md) | Component status matrix |

---

## Security Notes

- LUKS full-disk encryption is active on the root partition.
- Secure Boot remains **enabled** during installation; external boot media is temporarily allowed.
- No proprietary firmware is stored in this repository.
- Sensitive configuration values (hostnames, credentials) must be provided via environment variables or a local `.env` file (excluded via `.gitignore`).

---

## CI

All scripts in `scripts/` are automatically checked with [ShellCheck](https://www.shellcheck.net/) on every push and pull request via GitHub Actions.

---

## License

MIT — see [LICENSE](LICENSE)
