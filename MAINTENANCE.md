# PAASS Maintenance Guide

## Weekly Tasks
- **System Update:**
  ```bash
  sudo pacman -Syu
  ```
- **Snapshot Check:**
  Verify snapshots are being created:
  ```bash
  sudo btrfs subvolume list /.snapshots
  ```

## Monthly Tasks
- **Integrity Check:**
  Run AIDE to check for unauthorized file changes:
  ```bash
  ./scripts/integrity-check.sh
  ```
- **Clean Cache:**
  ```bash
  sudo pacman -Sc
  ```

## Quarterly Tasks
- **Key Rotation (Optional):**
  Change your LUKS passphrase if required by policy:
  ```bash
  cryptsetup luksChangeKey /dev/nvme0n1p2
  ```
- **Backup Headers:**
  Backup LUKS headers to external storage:
  ```bash
  cryptsetup luksHeaderBackup /dev/nvme0n1p2 --header-backup-file root-header-$(date +%F).img
  ```
