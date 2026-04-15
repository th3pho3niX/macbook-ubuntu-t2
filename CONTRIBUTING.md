# Contributing

Thank you for your interest in contributing to this project!

## Scope

This repository documents the installation of Ubuntu 24.04 LTS on the MacBook Pro 2018 with Apple T2 chip. Contributions should be limited to the following topics:

- T2 drivers and kernel compatibility (apple_bce, applesmc, brcmfmac)
- Installation documentation and scripts
- Hardware compatibility and troubleshooting
- Performance monitoring and power management

Contributions covering other topics are out of scope for this repository.

## How to Contribute

### Reporting Bugs

Please open a GitHub Issue using the `bug_report.md` template. Include the following:

- Ubuntu version and kernel version (`uname -r`)
- MacBook model and year
- Exact error message or unexpected behaviour
- Steps to reproduce

### Reporting Hardware Compatibility

Use the `hardware_report.md` issue template to document your hardware status. This helps other users with similar devices.

### Code Contributions

1. Fork the repository
2. Create a feature branch: `git checkout -b fix/description`
3. Follow the existing code style:
   - Bash scripts with `set -euo pipefail`
   - English comments and log messages
   - ShellCheck compliant (no warnings at `--severity=warning`)
4. Test your changes on a T2 MacBook running Ubuntu 24.04 LTS
5. Open a pull request with a clear description of the changes

### Improving Documentation

Corrections and additions to `docs/` are welcome — especially for:

- Newer kernel versions
- Additional T2 MacBook models (2019, 2020)
- Undocumented hardware quirks

## Code Quality

All scripts in `scripts/` are checked by GitHub Actions CI with ShellCheck. Pull requests must pass this check.

Local check before committing:

```bash
shellcheck --severity=warning --shell=bash scripts/*.sh
```

## Firmware Notice

Broadcom firmware files (`brcmfmac*`) must **not** be uploaded in pull requests or issues. They are subject to proprietary licenses and may not be distributed publicly.

## License

By contributing, you agree that your code will be published under the MIT license of this project.
