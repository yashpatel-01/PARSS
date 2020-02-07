# PAASS Recovery Procedures

## Emergency Access
If you cannot boot into your system:

1. **Boot Arch ISO**
2. **Decrypt Volumes**
   ```bash
   cryptsetup luksOpen /dev/nvme0n1p2 root_crypt
   cryptsetup luksOpen /dev/nvme0n1p3 home_crypt
   # Enter your passphrase
   ```

3. **Mount Filesystems**
   ```bash
   mount -o subvol=@,compress=zstd /dev/mapper/root_crypt /mnt
   mount -o subvol=@home,compress=zstd /dev/mapper/root_crypt /mnt/home
   mount /dev/nvme0n1p1 /mnt/boot
   ```

4. **Chroot**
   ```bash
   arch-chroot /mnt
   ```

## Key Recovery
If you lose your LUKS header but have a backup:
```bash
cryptsetup luksHeaderRestore /dev/nvme0n1p2 --header-backup-file header-backup.img
```

## GRUB Repair
If the bootloader is corrupted:
1. Follow "Emergency Access" steps 1-4.
2. Reinstall GRUB:
   ```bash
   grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
   grub-mkconfig -o /boot/grub/grub.cfg
   ```
