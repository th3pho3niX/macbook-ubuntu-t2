# Security Policy

## Scope

This repository contains installation documentation and scripts for Ubuntu 24.04 LTS on the MacBook Pro 2018 with Apple T2 chip.

## Firmware License Notice

> ⚠️ **The Broadcom firmware (`brcmfmac4364b2-pcie.apple,kauai*`) is subject to proprietary license terms and may not be distributed publicly.**
>
> This repository contains **no firmware files**. The firmware must be obtained independently from a licensed macOS installation. By running `scripts/install_wlan_firmware.sh`, the user confirms that the firmware was lawfully acquired.

## What is NOT in this Repository

The following content is intentionally excluded:

- Broadcom firmware files (`brcmfmac*`) — proprietary, not distributable
- Prebuilt `.deb` driver packages — source: [t2linux GitHub Releases](https://github.com/t2linux)
- Device-specific configuration files (hostnames, IP addresses, credentials)

## Reporting Security Vulnerabilities

If a security vulnerability is discovered in a script or configuration file in this repository, please **do not** open a public issue. Report the vulnerability confidentially via email to the project owner (contact via GitHub profile).

Please describe the issue as clearly as possible without including exploit code or proof-of-concept payloads. Acknowledgement will be sent within 72 hours.

## Script Security

All scripts in `scripts/` are designed to:
- Run with `set -euo pipefail` (immediate abort on errors)
- Validate root access before execution
- Write structured logs to `/var/log/macbook-t2-setup.log`
- Not transmit data to external systems
- Not store credentials in plaintext
