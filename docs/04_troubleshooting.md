# 04 – Troubleshooting

**Target device:** MacBook Pro 15″ (2018) with Apple T2 chip

---

## Quick Reference

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
| High fan speed / no regulation | `macfanctld` not active or `applesmc` missing | `modprobe applesmc`; `systemctl enable --now macfanctld` |
| No sensor output from `sensors` | `applesmc` module not loaded | `sudo modprobe applesmc`; run `sudo sensors-detect --auto` |
| Hang after suspend/resume | T2 modules incompatible with S2idle | Install sleep hook (see below); set `mem_sleep_default=deep` in GRUB |
| AMD GPU not detected | `amdgpu` not loaded | `lsmod \| grep amdgpu`; check kernel parameter `amdgpu.si_support=1` |

---

## Detailed Solutions

### GRUB not visible after new kernel

```bash
# Boot from live USB, then:
cryptsetup open /dev/nvme0n1p2 crypt_lvm
vgchange -ay vg_ubuntu
mount /dev/vg_ubuntu/lv_root /mnt
mount /dev/nvme0n1p1 /mnt/boot/efi
for d in dev proc sys; do mount --bind /$d /mnt/$d; done
mount --bind /dev/pts /mnt/dev/pts
chroot /mnt
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
update-grub
exit
for d in dev/pts dev proc sys; do umount /mnt/$d; done
umount /mnt/boot/efi && umount /mnt
```

> Automated via `scripts/luks_recovery.sh`

---

### Suspend/Resume hangs

```bash
# Check sleep hook
ls -la /lib/systemd/system-sleep/t2-suspend.sh

# Reinstall if missing
sudo ./scripts/fix_suspend.sh

# Check deep sleep status
cat /sys/power/mem_sleep
# Expected output: s2idle [deep]
```

---

### Install WLAN firmware manually

```bash
# Mount firmware USB
sudo mount /dev/sdX /mnt

# Copy files
sudo cp /mnt/brcmfmac4364b2-pcie.apple,kauai* /lib/firmware/brcm/

# Update initramfs
sudo update-initramfs -u

# Reload module
sudo modprobe -r brcmfmac && sudo modprobe brcmfmac
```

> Automated with SHA-256 verification via `scripts/install_wlan_firmware.sh`

---

### Reload apple_bce after kernel update

```bash
sudo modprobe -r apple_bce && sudo modprobe apple_bce

# If keyboard/trackpad not responding:
sudo modprobe -r vhci_hcd && sudo modprobe vhci_hcd
```

---

### Set audio sink manually

```bash
# List available sinks
pactl list short sinks

# Set default sink
pactl set-default-sink alsa_output.pci-0000_02_00.3.Speakers

# Load snd_hda_intel if no sink visible
sudo modprobe snd_hda_intel
```

---

### Full system diagnostics

```bash
sudo ./scripts/health.sh
```

---

**Back:** [03_post_install.md](03_post_install.md)
