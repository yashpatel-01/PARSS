# PAASS Installation Guide

## Prerequisites
- **Hardware:** UEFI-compatible system (x86_64).
- **Storage:** Minimum 71GB (1GB EFI + 50GB Root + 20GB Home).
- **Network:** Active internet connection (Ethernet preferred).
- **Media:** Latest Arch Linux ISO.

## Installation Steps

1. **Boot Arch ISO**
   Boot your machine using the Arch Linux installation media.

2. **Connect to Internet**
   ```bash
   iwctl  # For Wi-Fi
   # or
   dhcpcd # For Ethernet
   ```

3. **Clone Repository**
   ```bash
   pacman -Sy git
   git clone https://github.com/your-repo/PAASS.git
   cd PAASS/scripts
   ```

4. **Run Deployment Script**
   Run the enhanced v2 script:
   ```bash
   chmod +x arch-secure-deploy-v2.sh
   ./arch-secure-deploy-v2.sh
   ```

   **Optional Flags:**
   - `--dry-run`: Simulate installation without writing changes.
   - `--enable-tpm2`: Install TPM2 tools (enrollment required post-install).
   - `--disable-apparmor`: Skip AppArmor setup.

5. **Post-Install**
   - Reboot: `reboot`
   - Enter your **single passphrase** to unlock the system.
   - Login with your user.

## Troubleshooting
- **Network Failures:** The script retries connections. If it fails, check your physical connection.
- **Boot Issues:** If GRUB fails to load, boot the ISO, mount partitions, and run `grub-install --removable`.
