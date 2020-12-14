#!/usr/bin/env bash

################################################################################
# PARSS Desktop Setup Test Script
#
# This script helps you test phase_14 (desktop setup) without running
# the full installation. It checks if the system is already installed
# and mounted, then runs only the desktop setup phase.
#
# Usage:
#   From live ISO after installation (before reboot):
#     bash test-desktop-setup.sh
#
#   Or use the main script with --phase flag:
#     bash arch-secure-deploy.sh --phase 14
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

# Check if system is mounted at /mnt/root
if ! mountpoint -q /mnt/root 2>/dev/null; then
    error "System not mounted at /mnt/root"
    error ""
    error "You need to mount your installed system first:"
    error ""
    error "1. Open LUKS:"
    error "   cryptsetup luksOpen /dev/sdXY mahadev"
    error ""
    error "2. Mount root:"
    error "   mount -o subvol=@ /dev/mapper/mahadev /mnt/root"
    error ""
    error "3. Mount boot:"
    error "   mount /dev/sdX1 /mnt/root/boot"
    error ""
    error "4. Run this script again"
    exit 1
fi

info "System is mounted at /mnt/root"
info ""

# Check if desktop-setup.sh exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_SETUP="$SCRIPT_DIR/desktop-setup.sh"

if [[ ! -f "$DESKTOP_SETUP" ]]; then
    error "desktop-setup.sh not found at: $DESKTOP_SETUP"
    exit 1
fi

info "Found desktop-setup.sh at: $DESKTOP_SETUP"
info ""

# Get primary user from the installed system
PRIMARY_USER=$(arch-chroot /mnt/root bash -c "getent passwd 1000 | cut -d: -f1" 2>/dev/null || echo "")

if [[ -z "$PRIMARY_USER" ]]; then
    warn "Could not detect primary user (UID 1000)"
    read -p "Enter username: " PRIMARY_USER
    
    if ! arch-chroot /mnt/root id "$PRIMARY_USER" >/dev/null 2>&1; then
        error "User $PRIMARY_USER does not exist in the installed system"
        exit 1
    fi
fi

info "Primary user: $PRIMARY_USER"
info ""

# Copy desktop-setup.sh to chroot
info "Copying desktop-setup.sh to /mnt/root/tmp..."
cp "$DESKTOP_SETUP" /mnt/root/tmp/desktop-setup.sh
chmod +x /mnt/root/tmp/desktop-setup.sh

info "File size: $(stat -c%s /mnt/root/tmp/desktop-setup.sh) bytes"
info "Permissions: $(stat -c%a /mnt/root/tmp/desktop-setup.sh)"
info ""

# Test sudo
info "Testing sudo functionality..."
if ! arch-chroot /mnt/root /bin/bash -c "sudo -u $PRIMARY_USER whoami" >/dev/null 2>&1; then
    error "sudo test failed - cannot run as user $PRIMARY_USER"
    error "Check if user is in wheel group and sudo is configured"
    exit 1
fi
info "sudo test passed"
info ""

# Run desktop setup
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Starting desktop environment installation..."
info "This may take 10-30 minutes depending on network speed"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info ""

arch-chroot /mnt/root /bin/bash -c "
    export HOME=/home/$PRIMARY_USER
    export PARSS_CHROOT_INSTALL=1
    cd /home/$PRIMARY_USER
    sudo -u $PRIMARY_USER /bin/bash /tmp/desktop-setup.sh
"

if [[ $? -eq 0 ]]; then
    info ""
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "Desktop environment setup completed successfully!"
    info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info ""
    info "After reboot, login and run 'startx' to launch your environment"
else
    error ""
    error "Desktop setup encountered issues"
    error "Check the output above for details"
    exit 1
fi

# Cleanup
rm -f /mnt/root/tmp/desktop-setup.sh

info ""
info "Test completed!"
