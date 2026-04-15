# 02 – Installation

**Scope:** Booting the Ubuntu installer, partitioning the NVMe disk with LUKS encryption, and completing the base installation.

---

## 2.1 Boot from USB

1. Insert the Ubuntu installer USB stick.
2. Power on the MacBook while holding the **Option (⌥)** key.
3. In the boot picker, select the EFI entry corresponding to the Ubuntu USB medium.
4. Choose **Try or Install Ubuntu** from the GRUB menu.

---

## 2.2 Partitioning Layout

The internal NVMe disk is partitioned manually. Open **GParted** or use the installer's manual partitioning option.

Target layout for `/dev/nvme0n1`:

| Partition | Size | Type | Mount Point | Notes |
|---|---|---|---|---|
| `nvme0n1p1` | 1024 MB | FAT32 | `/boot/efi` | EFI System Partition |
| `nvme0n1p2` | remaining | LUKS container | — | Contains LVM PVs |

Inside the LUKS container (LVM):

| Logical Volume | Size | Filesystem | Mount Point |
|---|---|---|---|
| `lv_root` | remaining | ext4 | `/` |
| `lv_swap` | 8192 MB | swap | `[SWAP]` |

---

## 2.3 LUKS Encryption Setup

If configuring manually via terminal in the live environment:

```bash
# Create LUKS container on the second partition
cryptsetup luksFormat /dev/nvme0n1p2

# Open the container
cryptsetup open /dev/nvme0n1p2 crypt_lvm

# Create Physical Volume
pvcreate /dev/mapper/crypt_lvm

# Create Volume Group
vgcreate vg_ubuntu /dev/mapper/crypt_lvm

# Create Logical Volumes
lvcreate -L 8G -n lv_swap vg_ubuntu
lvcreate -l 100%FREE -n lv_root vg_ubuntu

# Format
mkfs.ext4 /dev/vg_ubuntu/lv_root
mkswap /dev/vg_ubuntu/lv_swap
```

> The LUKS passphrase is entered at every boot. Use a strong, memorised passphrase. It cannot be recovered if lost.

---

## 2.4 Ubuntu Installer Configuration

In the graphical installer:

- **Installation type:** Something else (manual partitioning)
- Assign EFI partition to `/boot/efi` (do not format if already FAT32)
- Assign `lv_root` to `/` with ext4 and format
- Enable swap on `lv_swap`
- **Do not select** "Install third-party software for graphics and Wi-Fi" — drivers are not available for the T2 Broadcom chip via this mechanism
- Set hostname, username, and password

---

## 2.5 Post-Install Reboot Issues

After the first reboot, GRUB may not appear in the macOS boot picker automatically.

**Resolution:**

1. Hold **Option (⌥)** at startup.
2. Select the EFI boot entry for Ubuntu.
3. If no entry appears, boot back into the live USB and re-run:

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

## Next Step

→ [03 – Post-Installation](03_post_install.md)
