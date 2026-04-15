# Changelog

All notable changes to this repository are documented in this file.
Format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

## [1.2.0] – 2025-11

### Changed
- `scripts/perf_log.sh` (v1.2.0) – CPU calculation extended to full `/proc/stat` fields (iowait, irq, steal); CSV schema extended with `cpu_iowait` and `cpu_steal`; sensors parsing switched to multi-pattern (`Package id 0|Tctl|Tdie|TC0P`)
- `configs/perf-logger@.service` – added `After=network-online.target` + `Wants=network-online.target` (race condition fix)
- `docs/02_installation.md` – GRUB recovery procedure extended to full chroot sequence (LUKS unlock, bind-mounts, chroot); simplified mount command removed
- `docs/03_post_install.md` – Bluetooth section and GPU acceleration note added; section numbering corrected
- `docs/complete_installation_guide.md` – all above corrections integrated; Bluetooth and GPU acceleration sections added
- `SECURITY.md` – firmware license warning added as prominent block notice

## [1.1.0] – 2025-11

### Added
- `scripts/install_wlan_firmware.sh` – Broadcom BCM4364 firmware installer with SHA-256 verification
- `scripts/luks_recovery.sh` – LUKS unlock and chroot recovery from live environment
- `scripts/fix_suspend.sh` – suspend/resume stabilisation via systemd hook, GRUB parameter and udev rule
- `scripts/perf_log.sh` (v1.1.0) – extended CSV schema with cpu_user/system/idle, load averages, GPU temperature
- `configs/perf-logger@.service` – systemd service unit for automatic perf_log start
- `docs/complete_installation_guide.md` – consolidated full guide (all phases)
- GPU validation via `lspci -k`, `glxinfo`, `vulkaninfo`, `radeontop`
- `switcheroo-control` for dual-GPU switching documented
- TLP power management configuration documented
- `mbpfan` as alternative to `macfanctld` documented

### Changed
- `docs/hardware_compatibility.md` – sensor groups (coretemp, amdgpu-pci, applesmc) documented separately
- README structure extended to include all new files

---

## [1.0.0] – 2025-11

### Added
- `docs/01_preparation.md` – Secure Boot, ISO creation, firmware preparation
- `docs/02_installation.md` – partitioning, LUKS+LVM, installer configuration
- `docs/03_post_install.md` – T2 drivers, WLAN firmware, audio, fan control, Firefox
- `docs/04_troubleshooting.md` – problem/cause/solution reference table
- `docs/hardware_compatibility.md` – component status matrix
- `scripts/base.sh` – base package installation
- `scripts/setup_t2.sh` – T2 drivers via prebuilt .deb (apple-bce, applesmc-t2, apple-touchbar)
- `scripts/health.sh` – system diagnostics and module verification
- `scripts/post_install.sh` – post-install hardening, Firefox, UFW firewall
- `configs/t2.conf` – kernel module autoload configuration
- `configs/macfanctld.conf.example` – fan control reference configuration
- `.github/workflows/lint.yml` – ShellCheck CI for all shell scripts
- `.github/ISSUE_TEMPLATE/bug_report.md` – bug report template
- `.github/ISSUE_TEMPLATE/hardware_report.md` – hardware compatibility report template
- `SECURITY.md` – security policy and firmware license notice
- `README.md`, `LICENSE` (MIT), `.gitignore`
