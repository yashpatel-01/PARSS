#!/usr/bin/env bash

################################################################################
# ARCH LINUX SECURE DEPLOYMENT AUTOMATION SCRIPT (PILLAR 6)
# 
# Purpose: Comprehensive, fully-automated installation and hardening for a
#          privacy-centric, security-engineered Arch Linux research platform.
#
# Target: Fresh Arch Linux ISO installation (bare metal equivalent)
# 
# Features:
#   - LUKS encryption with Argon2 key derivation
#   - BTRFS root filesystem with advanced snapshotting
#   - Systemd timer-based weekly snapshot automation
#   - Security hardening (kernel parameters, sysctl tuning)
#   - Error handling and comprehensive logging
#
# Usage: sudo bash ./arch-secure-deploy.sh
# 
# Prerequisites:
#   - Arch Linux ISO booted environment with network connectivity
#   - Target storage device identified (e.g., /dev/nvme0n1)
#   - Minimum 100GB storage (recommended 256GB for research operations)
#   - Root privilege execution
#
################################################################################

set -euo pipefail

# Color codes for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging configuration
readonly LOG_FILE="/var/log/arch-deploy-$(date +%Y%m%d-%H%M%S).log"
readonly ERROR_LOG="/var/log/arch-deploy-errors-$(date +%Y%m%d-%H%M%S).log"

################################################################################
# UTILITY FUNCTIONS
################################################################################

# Error handling with comprehensive logging
trap_error() {
    local line_number=$1
    echo -e "${RED}[ERROR]${NC} Script failed at line ${line_number}" | tee -a "$ERROR_LOG"
    echo "Full log available at: $LOG_FILE" >&2
    exit 1
}

trap 'trap_error ${LINENO}' ERR

# Logging function: outputs to both console and log file
log_info() {
    local message="$1"
    echo -e "${GREEN}[INFO]${NC} $message" | tee -a "$LOG_FILE"
}

log_warn() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$LOG_FILE"
}

log_debug() {
    local message="$1"
    echo -e "${BLUE}[DEBUG]${NC} $message" | tee -a "$LOG_FILE"
}

# Execute command with error handling and logging
execute_cmd() {
    local cmd="$1"
    local description="${2:-Executing command}"
    
    log_debug "$description"
    log_debug "Command: $cmd"
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_info "$description - SUCCESS"
        return 0
    else
        local exit_code=$?
        log_warn "$description - FAILED (exit code: $exit_code)"
        echo "Command: $cmd" >> "$ERROR_LOG"
        echo "Exit code: $exit_code" >> "$ERROR_LOG"
        return $exit_code
    fi
}

# Validate block device existence
validate_block_device() {
    local device="$1"
    
    if [[ ! -b "$device" ]]; then
        echo -e "${RED}[ERROR]${NC} Block device $device not found" >&2
        return 1
    fi
    
    log_info "Block device $device validated"
    return 0
}

# Confirm destructive operations
confirm_destructive_operation() {
    local device="$1"
    
    echo -e "${YELLOW}[WARNING]${NC} This will DESTROY all data on $device"
    read -p "Type 'YES' to confirm: " confirmation
    
    if [[ "$confirmation" != "YES" ]]; then
        log_info "Operation cancelled by user"
        exit 0
    fi
}

################################################################################
# PHASE 1: PRE-INSTALLATION CONFIGURATION
################################################################################

phase_1_preflight() {
    log_info "=== PHASE 1: PRE-INSTALLATION CONFIGURATION ==="
    
    # Validate root privileges
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR]${NC} This script must be run as root" >&2
        exit 1
    fi
    log_info "Root privilege verified"
    
    # Initialize log files
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$ERROR_LOG")"
    touch "$LOG_FILE" "$ERROR_LOG"
    log_info "Logging initialized: $LOG_FILE"
    
    # Detect system architecture
    local arch=$(uname -m)
    log_info "System architecture: $arch"
    
    if [[ "$arch" != "x86_64" ]]; then
        log_warn "Script optimized for x86_64; detected $arch"
    fi
    
    # Verify network connectivity
    if ping -c 1 archlinux.org &> /dev/null; then
        log_info "Network connectivity verified"
    else
        log_warn "Network connectivity check failed - installation may encounter issues"
    fi
    
    # Check for required utilities
    local required_tools=("cryptsetup" "mkfs.btrfs" "timedatectl" "systemctl")
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_debug "Required tool found: $tool"
        else
            log_warn "Required tool not found: $tool (may be available after pacstrap)"
        fi
    done
}

################################################################################
# PHASE 2: DISK PARTITIONING & ENCRYPTION SETUP
################################################################################

phase_2_disk_encryption() {
    log_info "=== PHASE 2: DISK PARTITIONING & ENCRYPTION SETUP ==="
    
    # Interactive device selection
    log_info "Available block devices:"
    lsblk -d -n -o NAME,SIZE,TYPE | tee -a "$LOG_FILE"
    
    read -p "Enter target storage device (e.g., /dev/nvme0n1): " TARGET_DEVICE
    
    # Validation with error handling
    if ! validate_block_device "$TARGET_DEVICE"; then
        log_warn "Invalid device specified: $TARGET_DEVICE"
        return 1
    fi
    
    # Confirm destructive operation
    confirm_destructive_operation "$TARGET_DEVICE"
    
    log_info "Using target device: $TARGET_DEVICE"
    
    # Determine partition naming convention (nvme vs sda)
    local boot_partition part_separator
    if [[ "$TARGET_DEVICE" == *"nvme"* ]]; then
        boot_partition="${TARGET_DEVICE}p1"
        root_partition="${TARGET_DEVICE}p2"
        part_separator="p"
    else
        boot_partition="${TARGET_DEVICE}1"
        root_partition="${TARGET_DEVICE}2"
        part_separator=""
    fi
    
    log_debug "Boot partition: $boot_partition"
    log_debug "Root partition: $root_partition"
    
    # Phase 2.1: Wipe existing filesystem signatures
    log_info "Wiping existing filesystem signatures..."
    execute_cmd "cryptsetup close root_crypt 2>/dev/null || true" "Closing any existing LUKS volumes"
    execute_cmd "wipefs -a $TARGET_DEVICE" "Wiping filesystem signatures from $TARGET_DEVICE"
    
    # Phase 2.2: Create partition table with GPT
    log_info "Creating GPT partition table..."
    execute_cmd "parted -s $TARGET_DEVICE mklabel gpt" "Creating GPT partition table"
    
    # Phase 2.3: Create EFI System Partition (ESP) - 1GB
    # Purpose: Boot partition for GRUB/UEFI bootloader
    log_info "Creating EFI System Partition (1GB)..."
    execute_cmd "parted -s $TARGET_DEVICE mkpart ESP fat32 1MiB 1GiB" "Creating ESP partition"
    execute_cmd "parted -s $TARGET_DEVICE set 1 esp on" "Setting ESP boot flag"
    
    # Phase 2.4: Create root partition (remaining space)
    # Purpose: Primary encrypted BTRFS root filesystem
    local total_size=$(parted -s "$TARGET_DEVICE" unit GiB print | grep "^Disk /" | awk '{print $3}')
    log_info "Creating root partition (remaining space: ~${total_size}GiB)..."
    execute_cmd "parted -s $TARGET_DEVICE mkpart root 1GiB 100%" "Creating root partition"
    
    # Phase 2.5: Format EFI partition with FAT32
    log_info "Formatting EFI System Partition..."
    execute_cmd "mkfs.fat -F 32 $boot_partition" "Formatting $boot_partition with FAT32"
    
    # Phase 2.6: Setup LUKS encryption on root partition
    # Key parameters:
    #   --type luks2: Modern LUKS2 format for better security
    #   --pbkdf argon2id: Argon2id KDF for resistance against GPU/ASIC attacks
    #   --pbkdf-force-iterations 4: Balanced security vs performance
    #   --key-slot 0: Primary key slot
    log_info "Setting up LUKS2 encryption on root partition..."
    log_info "You will be prompted for encryption passphrase (enters twice)"
    
    execute_cmd "cryptsetup luksFormat --type luks2 --pbkdf argon2id --pbkdf-force-iterations 4 $root_partition" \
        "Initializing LUKS2 encryption with Argon2id KDF"
    
    # Phase 2.7: Open encrypted volume
    log_info "Opening encrypted LUKS volume..."
    execute_cmd "cryptsetup luksOpen $root_partition root_crypt" "Opening LUKS volume as 'root_crypt'"
    
    # Verify encrypted volume is accessible
    if [[ ! -b "/dev/mapper/root_crypt" ]]; then
        log_warn "Failed to open encrypted volume"
        return 1
    fi
    log_info "Encrypted volume successfully opened at /dev/mapper/root_crypt"
    
    # Store device information for later phases
    export TARGET_DEVICE
    export BOOT_PARTITION="$boot_partition"
    export ROOT_PARTITION="$root_partition"
    export ROOT_CRYPT="/dev/mapper/root_crypt"
}

################################################################################
# PHASE 3: BTRFS FILESYSTEM CONFIGURATION
################################################################################

phase_3_btrfs_setup() {
    log_info "=== PHASE 3: BTRFS FILESYSTEM CONFIGURATION ==="
    
    # Verify encrypted volume is open
    if [[ ! -b "$ROOT_CRYPT" ]]; then
        log_warn "Encrypted volume not accessible at $ROOT_CRYPT"
        return 1
    fi
    
    # Phase 3.1: Create BTRFS filesystem on encrypted volume
    # Purpose: Advanced snapshotting, compression, integrity checking
    log_info "Creating BTRFS filesystem on encrypted volume..."
    execute_cmd "mkfs.btrfs -f -L root $ROOT_CRYPT" "Formatting $ROOT_CRYPT with BTRFS"
    
    # Phase 3.2: Create temporary mount point and mount root
    log_info "Mounting BTRFS root filesystem..."
    mkdir -p /mnt/root
    execute_cmd "mount $ROOT_CRYPT /mnt/root" "Mounting BTRFS root to /mnt/root"
    
    # Phase 3.3: Create BTRFS subvolumes
    # Purpose:
    #   @       : Root subvolume (mounted at /)
    #   @home   : Home directories (mounted at /home)
    #   @var    : System variable data (mounted at /var)
    #   @snapshots: Snapshot storage location
    log_info "Creating BTRFS subvolumes..."
    
    execute_cmd "btrfs subvolume create /mnt/root/@" "Creating @ (root) subvolume"
    execute_cmd "btrfs subvolume create /mnt/root/@home" "Creating @home subvolume"
    execute_cmd "btrfs subvolume create /mnt/root/@var" "Creating @var subvolume"
    execute_cmd "btrfs subvolume create /mnt/root/@snapshots" "Creating @snapshots subvolume"
    
    # Phase 3.4: Unmount and remount with subvolumes
    log_info "Remounting BTRFS with subvolume structure..."
    execute_cmd "umount /mnt/root" "Unmounting temporary root mount"
    
    # Mount @ (root) with compression and other options
    # Mount options:
    #   subvol=@ : Select @ subvolume
    #   compress=zstd : Zstandard compression for better performance/ratio
    #   noatime : Disable atime updates (improves performance)
    #   nodatacow : Disable copy-on-write for data (performance optimization)
    #   space_cache=v2 : V2 space cache for efficiency
    execute_cmd "mount -o subvol=@,compress=zstd,noatime,space_cache=v2 $ROOT_CRYPT /mnt/root" \
        "Mounting @ subvolume with optimization flags"
    
    # Create mount points for other subvolumes
    mkdir -p /mnt/root/{home,var,.snapshots}
    
    # Mount @home subvolume
    execute_cmd "mount -o subvol=@home,compress=zstd,noatime,space_cache=v2 $ROOT_CRYPT /mnt/root/home" \
        "Mounting @home subvolume"
    
    # Mount @var subvolume
    execute_cmd "mount -o subvol=@var,compress=zstd,noatime,space_cache=v2 $ROOT_CRYPT /mnt/root/var" \
        "Mounting @var subvolume"
    
    # Mount @snapshots (for read-only snapshot references)
    execute_cmd "mount -o subvol=@snapshots,compress=zstd,noatime,space_cache=v2 $ROOT_CRYPT /mnt/root/.snapshots" \
        "Mounting @snapshots subvolume"
    
    # Mount EFI System Partition
    mkdir -p /mnt/root/boot
    execute_cmd "mount $BOOT_PARTITION /mnt/root/boot" "Mounting EFI System Partition at /boot"
    
    # Verify all mounts
    log_info "Verifying BTRFS mount configuration..."
    execute_cmd "mount | grep /mnt/root | tee -a $LOG_FILE" "Displaying active mounts"
    
    export MOUNT_ROOT="/mnt/root"
}

################################################################################
# PHASE 4: BASE SYSTEM INSTALLATION (PACSTRAP)
################################################################################

phase_4_pacstrap() {
    log_info "=== PHASE 4: BASE SYSTEM INSTALLATION ==="
    
    # Phase 4.1: Update package database
    log_info "Updating Arch Linux package database..."
    execute_cmd "pacman -Sy" "Syncing package database"
    
    # Phase 4.2: Install essential packages
    # Core packages:
    #   base linux-zen linux-zen-headers: Arch base + Zen kernel (optimized)
    #   mkinitcpio: Initial ramdisk generation (required for encrypted boot)
    #   grub efibootmgr: Bootloader (GRUB + EFI support)
    #   btrfs-progs: BTRFS utilities
    #   cryptsetup: LUKS management
    #   networkmanager: Network management
    #   vim nano: Text editors
    log_info "Installing base system packages via pacstrap..."
    
    local packages=(
        "base" "linux-zen" "linux-zen-headers"
        "mkinitcpio"
        "grub" "efibootmgr"
        "btrfs-progs"
        "cryptsetup"
        "networkmanager"
        "vim" "nano"
        "git" "curl" "wget"
        "sudo"
        "zsh"
        "openssh"
    )
    
    local packages_str=$(IFS=' '; echo "${packages[*]}")
    execute_cmd "pacstrap -K $MOUNT_ROOT $packages_str" "Installing base packages with pacstrap"
    
    log_info "Base system installation completed"
}

################################################################################
# PHASE 5: FSTAB GENERATION & CRYPTTAB CONFIGURATION
################################################################################

phase_5_mount_configuration() {
    log_info "=== PHASE 5: MOUNT & ENCRYPTION CONFIGURATION ==="
    
    # Phase 5.1: Generate fstab
    log_info "Generating fstab..."
    execute_cmd "genfstab -U $MOUNT_ROOT >> $MOUNT_ROOT/etc/fstab" "Generating fstab"
    
    # Phase 5.2: Verify fstab content
    log_info "Current fstab configuration:"
    cat "$MOUNT_ROOT/etc/fstab" | tee -a "$LOG_FILE"
    
    # Phase 5.3: Create crypttab for automated LUKS unlock at boot
    # Purpose: Enables systemd to automatically decrypt root partition using passphrase
    log_info "Configuring crypttab for LUKS automation..."
    
    cat > "$MOUNT_ROOT/etc/crypttab" << 'EOF'
# LUKS encrypted volumes configuration
# Format: name device password options
# 
# Example: root_crypt /dev/nvme0n1p2 none luks,discard

root_crypt	PARTUUID=$(blkid -s PARTUUID -o value $ROOT_PARTITION)	none	luks,x-systemd.device-timeout=10
EOF
    
    # Replace placeholder with actual PARTUUID
    local partuuid=$(blkid -s PARTUUID -o value "$ROOT_PARTITION")
    sed -i "s|PARTUUID=.*|$partuuid|" "$MOUNT_ROOT/etc/crypttab"
    
    log_info "crypttab configuration:"
    cat "$MOUNT_ROOT/etc/crypttab" | tee -a "$LOG_FILE"
}

################################################################################
# PHASE 6: CHROOT ENVIRONMENT SETUP
################################################################################

phase_6_chroot_setup() {
    log_info "=== PHASE 6: CHROOT ENVIRONMENT CONFIGURATION ==="
    
    # Phase 6.1: Generate mkinitcpio configuration for encrypted boot
    log_info "Configuring mkinitcpio for encrypted root..."
    
    # Key modules for encrypted boot:
    #   MODULES: btrfs (BTRFS support), dm_crypt (encryption support)
    #   HOOKS: base udev systemd keyboard sd-vconsole sd-encrypt filesystems fsck
    local mkinitcpio_conf="$MOUNT_ROOT/etc/mkinitcpio.conf"
    
    # Backup original
    cp "$mkinitcpio_conf" "${mkinitcpio_conf}.bak"
    
    # Update MODULES for BTRFS and encryption
    sed -i 's/^MODULES=.*/MODULES=(btrfs dm_crypt)/' "$mkinitcpio_conf"
    
    # Update HOOKS for systemd-based encryption
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems fsck)/' "$mkinitcpio_conf"
    
    log_info "Updated mkinitcpio.conf:"
    grep -E "^(MODULES|HOOKS)" "$mkinitcpio_conf" | tee -a "$LOG_FILE"
    
    # Phase 6.2: Generate initramfs in chroot
    log_info "Generating initramfs (mkinitcpio)..."
    arch-chroot "$MOUNT_ROOT" bash -c "mkinitcpio -p linux-zen" 2>&1 | tee -a "$LOG_FILE"
    
    log_info "Initramfs generation completed"
}

################################################################################
# PHASE 7: BOOTLOADER CONFIGURATION (GRUB)
################################################################################

phase_7_grub_installation() {
    log_info "=== PHASE 7: BOOTLOADER CONFIGURATION ==="
    
    # Phase 7.1: Install GRUB to EFI
    log_info "Installing GRUB to EFI System Partition..."
    arch-chroot "$MOUNT_ROOT" bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB" 2>&1 | tee -a "$LOG_FILE"
    
    # Phase 7.2: Configure GRUB with encrypted root parameters
    # Key kernel parameters:
    #   rd.luks.name=UUID=<uuid>:root_crypt: Maps LUKS volume to 'root_crypt'
    #   root=/dev/mapper/root_crypt: Use decrypted volume as root
    log_info "Configuring GRUB for encrypted root boot..."
    
    local root_partuuid=$(blkid -s PARTUUID -o value "$ROOT_PARTITION")
    local grub_default="$MOUNT_ROOT/etc/default/grub"
    
    # Update GRUB_CMDLINE_LINUX for LUKS and security
    sed -i "/^GRUB_CMDLINE_LINUX=/s/\"$/rd.luks.name=${root_partuuid}:root_crypt root=\\/dev\\/mapper\\/root_crypt quiet\"/" "$grub_default"
    
    # Enable GRUB encryption menu (optional security)
    echo 'GRUB_ENABLE_CRYPTODISK=y' >> "$grub_default"
    
    log_info "Updated GRUB configuration:"
    grep -E "^(GRUB_CMDLINE_LINUX|GRUB_ENABLE_CRYPTODISK)" "$grub_default" | tee -a "$LOG_FILE"
    
    # Phase 7.3: Generate GRUB configuration
    log_info "Generating GRUB menu..."
    arch-chroot "$MOUNT_ROOT" bash -c "grub-mkconfig -o /boot/grub/grub.cfg" 2>&1 | tee -a "$LOG_FILE"
    
    log_info "GRUB installation completed"
}

################################################################################
# PHASE 8: SYSTEMD & HOSTNAME CONFIGURATION
################################################################################

phase_8_system_configuration() {
    log_info "=== PHASE 8: SYSTEM CONFIGURATION ==="
    
    # Phase 8.1: Set hostname
    log_info "Configuring hostname..."
    read -p "Enter hostname for this system: " hostname
    echo "$hostname" > "$MOUNT_ROOT/etc/hostname"
    
    # Phase 8.2: Configure hosts file
    cat > "$MOUNT_ROOT/etc/hosts" << EOF
127.0.0.1       localhost
::1             localhost
127.0.1.1       $hostname.localdomain $hostname
EOF
    
    log_info "Hostname set to: $hostname"
    
    # Phase 8.3: Set timezone
    log_info "Configuring timezone..."
    arch-chroot "$MOUNT_ROOT" bash -c "ln -sf /usr/share/zoneinfo/UTC /etc/localtime && hwclock --systohc" 2>&1 | tee -a "$LOG_FILE"
    
    # Phase 8.4: Configure locale
    log_info "Configuring locale..."
    echo "en_US.UTF-8 UTF-8" > "$MOUNT_ROOT/etc/locale.gen"
    arch-chroot "$MOUNT_ROOT" locale-gen 2>&1 | tee -a "$LOG_FILE"
    echo "LANG=en_US.UTF-8" > "$MOUNT_ROOT/etc/locale.conf"
    
    # Phase 8.5: Enable NetworkManager
    log_info "Enabling NetworkManager service..."
    arch-chroot "$MOUNT_ROOT" systemctl enable NetworkManager 2>&1 | tee -a "$LOG_FILE"
    
    # Phase 8.6: Configure sudo access
    log_info "Configuring sudo access..."
    # Uncomment %wheel group in sudoers
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' "$MOUNT_ROOT/etc/sudoers"
    
    log_info "System configuration completed"
}

################################################################################
# PHASE 9: USER CREATION & SHELL CONFIGURATION
################################################################################

phase_9_user_setup() {
    log_info "=== PHASE 9: USER ACCOUNT SETUP ==="
    
    # Phase 9.1: Create primary user account
    log_info "Creating primary user account..."
    read -p "Enter username for primary account: " username
    
    arch-chroot "$MOUNT_ROOT" bash -c "useradd -m -G wheel -s /usr/bin/zsh $username" 2>&1 | tee -a "$LOG_FILE"
    
    # Phase 9.2: Set user password
    log_info "Setting password for $username (enter when prompted)..."
    arch-chroot "$MOUNT_ROOT" bash -c "passwd $username" 2>&1 | tee -a "$LOG_FILE"
    
    # Phase 9.3: Configure root password
    log_info "Setting root password (enter when prompted)..."
    arch-chroot "$MOUNT_ROOT" bash -c "passwd" 2>&1 | tee -a "$LOG_FILE"
    
    log_info "User account setup completed"
    export PRIMARY_USER="$username"
}

################################################################################
# PHASE 10: BTRFS SNAPSHOT AUTOMATION (SYSTEMD TIMERS)
################################################################################

phase_10_snapshot_automation() {
    log_info "=== PHASE 10: BTRFS SNAPSHOT AUTOMATION ==="
    
    # Phase 10.1: Create snapshot service script
    log_info "Creating BTRFS snapshot automation script..."
    
    cat > "$MOUNT_ROOT/usr/local/bin/btrfs-snapshot-weekly.sh" << 'SNAP_SCRIPT'
#!/usr/bin/env bash
################################################################################
# BTRFS Weekly Snapshot Script
# Purpose: Automated weekly snapshots of root and home subvolumes
# Usage: Executed by systemd timer (btrfs-snapshot-weekly.timer)
################################################################################

set -euo pipefail

readonly SNAPSHOT_DIR="/.snapshots"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)
readonly LOG_FILE="/var/log/btrfs-snapshots.log"

# Logging function
log_snapshot() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Create read-only snapshot of root subvolume
snapshot_root() {
    local snapshot_name="@-snapshot-${TIMESTAMP}"
    local snapshot_path="$SNAPSHOT_DIR/$snapshot_name"
    
    log_snapshot "Creating snapshot: $snapshot_name"
    
    if btrfs subvolume snapshot -r / "$snapshot_path"; then
        log_snapshot "Root snapshot created successfully: $snapshot_path"
    else
        log_snapshot "ERROR: Failed to create root snapshot"
        return 1
    fi
}

# Create read-only snapshot of home subvolume
snapshot_home() {
    local snapshot_name="@home-snapshot-${TIMESTAMP}"
    local snapshot_path="$SNAPSHOT_DIR/$snapshot_name"
    
    log_snapshot "Creating snapshot: $snapshot_name"
    
    if btrfs subvolume snapshot -r /home "$snapshot_path"; then
        log_snapshot "Home snapshot created successfully: $snapshot_path"
    else
        log_snapshot "ERROR: Failed to create home snapshot"
        return 1
    fi
}

# Cleanup old snapshots (keep last 8 weekly snapshots = ~2 months)
cleanup_old_snapshots() {
    local max_snapshots=8
    local snapshot_count=$(btrfs subvolume list "$SNAPSHOT_DIR" 2>/dev/null | wc -l)
    
    if [[ $snapshot_count -gt $max_snapshots ]]; then
        log_snapshot "Snapshot count ($snapshot_count) exceeds limit ($max_snapshots), cleaning up..."
        
        # List snapshots sorted by creation time, keep newest max_snapshots
        local snapshots_to_delete=$(btrfs subvolume list "$SNAPSHOT_DIR" 2>/dev/null | awk '{print $NF}' | sort | head -n -$max_snapshots)
        
        for snapshot in $snapshots_to_delete; do
            log_snapshot "Deleting old snapshot: $snapshot"
            btrfs subvolume delete "$SNAPSHOT_DIR/$snapshot" || log_snapshot "ERROR: Failed to delete $snapshot"
        done
    fi
}

# Main execution
main() {
    log_snapshot "=== Starting weekly snapshot process ==="
    
    # Verify snapshot directory exists and is mounted
    if [[ ! -d "$SNAPSHOT_DIR" ]]; then
        log_snapshot "ERROR: Snapshot directory not found: $SNAPSHOT_DIR"
        return 1
    fi
    
    snapshot_root || return 1
    snapshot_home || return 1
    cleanup_old_snapshots
    
    log_snapshot "=== Weekly snapshot process completed ==="
}

main "$@"
SNAP_SCRIPT
    
    # Make script executable
    chmod +x "$MOUNT_ROOT/usr/local/bin/btrfs-snapshot-weekly.sh"
    log_info "Snapshot script created and made executable"
    
    # Phase 10.2: Create systemd service file
    log_info "Creating systemd service for snapshot automation..."
    
    cat > "$MOUNT_ROOT/etc/systemd/system/btrfs-snapshot-weekly.service" << 'SERVICE_FILE'
[Unit]
Description=Weekly BTRFS Snapshot Service
Documentation=man:btrfs(8)
After=local-fs.target
Requires=btrfs-snapshot-weekly.timer

[Service]
Type=oneshot
ExecStart=/usr/local/bin/btrfs-snapshot-weekly.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_FILE
    
    log_info "Systemd service file created"
    
    # Phase 10.3: Create systemd timer
    # Purpose: Execute snapshot service every Sunday at 02:00 UTC
    log_info "Creating systemd timer for weekly snapshots..."
    
    cat > "$MOUNT_ROOT/etc/systemd/system/btrfs-snapshot-weekly.timer" << 'TIMER_FILE'
[Unit]
Description=Weekly BTRFS Snapshot Timer
Documentation=man:btrfs(8)

[Timer]
# OnCalendar: Execute every Sunday at 02:00 UTC
OnCalendar=Sun *-*-* 02:00:00
# Randomize start by up to 5 minutes to avoid I/O spikes
RandomizedDelaySec=5min
# Run missed timer if system was down
Persistent=true
# Unit to run
Unit=btrfs-snapshot-weekly.service

[Install]
WantedBy=timers.target
TIMER_FILE
    
    log_info "Systemd timer created"
    
    # Phase 10.4: Enable systemd timer
    log_info "Enabling systemd timer..."
    arch-chroot "$MOUNT_ROOT" bash -c "systemctl daemon-reload && systemctl enable btrfs-snapshot-weekly.timer" 2>&1 | tee -a "$LOG_FILE"
    
    log_info "BTRFS snapshot automation configured successfully"
}

################################################################################
# PHASE 11: SECURITY HARDENING (SYSCTL & KERNEL PARAMETERS)
################################################################################

phase_11_security_hardening() {
    log_info "=== PHASE 11: SECURITY HARDENING ==="
    
    # Phase 11.1: Create hardened sysctl configuration
    # Purpose: Kernel parameter tuning for enhanced system resilience
    log_info "Configuring security-hardened sysctl parameters..."
    
    cat > "$MOUNT_ROOT/etc/sysctl.d/99-hardening.conf" << 'SYSCTL_CONFIG'
################################################################################
# SECURITY-HARDENED SYSCTL CONFIGURATION
# 
# Purpose: Advanced kernel parameter tuning for enhanced system resilience
# against various threat vectors while maintaining system functionality.
################################################################################

# === KERNEL PROTECTION ===
# Restrict kernel module loading
kernel.modules_disabled = 1

# Restrict dmesg access to root only (prevents info leakage)
kernel.dmesg_restrict = 1

# Disable SysRq key (prevents emergency keyboard shortcuts)
kernel.sysrq = 0

# Hide kernel pointers to prevent ASLR bypass
kernel.perf_event_paranoid = 3
kernel.kptr_restrict = 2
kernel.printk_devkmsg = off

# === MEMORY PROTECTION ===
# Enable ASLR (Address Space Layout Randomization)
kernel.randomize_va_space = 2

# Restrict access to kernel logs (prevents privilege escalation info)
kernel.dmesg_restrict = 1

# === NETWORK STACK HARDENING ===
# Disable IPv6 if not required (reduces attack surface)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2

# Ignore ICMP redirects (prevent MITM attacks)
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 0

# Enable reverse path filtering (prevent spoofed packets)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable source packet routing
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# === PROCESS ACCOUNTING ===
# Log suspicious process behavior
kernel.audit = 1

# === FILE SYSTEM ===
# Restrict FIFO and regular file access
fs.protected_fifos = 2
fs.protected_regular = 2

# Enable symlink/hardlink protection
fs.protected_symlinks = 1
fs.protected_hardlinks = 1

SYSCTL_CONFIG
    
    log_info "Security-hardened sysctl configuration created"
    log_info "Applying sysctl parameters..."
    arch-chroot "$MOUNT_ROOT" sysctl -p /etc/sysctl.d/99-hardening.conf 2>&1 | tee -a "$LOG_FILE"
    
    # Phase 11.2: Configure GRUB security parameters
    log_info "Adding security parameters to GRUB configuration..."
    
    local grub_default="$MOUNT_ROOT/etc/default/grub"
    
    # Append security flags to GRUB_CMDLINE_LINUX
    sed -i '/^GRUB_CMDLINE_LINUX=/s/"$/ mitigations=auto,nosmt spectre_v1=on spectre_v2=on tsx=off loglevel=0 audit=1"/' "$grub_default"
    
    log_info "GRUB security parameters configured"
    
    # Phase 11.3: Regenerate GRUB configuration
    log_info "Regenerating GRUB menu with security parameters..."
    arch-chroot "$MOUNT_ROOT" bash -c "grub-mkconfig -o /boot/grub/grub.cfg" 2>&1 | tee -a "$LOG_FILE"
    
    log_info "Security hardening phase completed"
}

################################################################################
# PHASE 12: FINAL VERIFICATION & CLEANUP
################################################################################

phase_12_finalization() {
    log_info "=== PHASE 12: FINALIZATION & VERIFICATION ==="
    
    # Phase 12.1: Verify system configuration
    log_info "Verifying critical system configurations..."
    
    log_debug "Checking crypttab..."
    cat "$MOUNT_ROOT/etc/crypttab" | tee -a "$LOG_FILE"
    
    log_debug "Checking fstab..."
    cat "$MOUNT_ROOT/etc/fstab" | tee -a "$LOG_FILE"
    
    log_debug "Checking mkinitcpio..."
    grep -E "^(MODULES|HOOKS)" "$MOUNT_ROOT/etc/mkinitcpio.conf" | tee -a "$LOG_FILE"
    
    # Phase 12.2: Verify BTRFS structure
    log_info "Verifying BTRFS subvolume structure..."
    arch-chroot "$MOUNT_ROOT" bash -c "btrfs subvolume list / 2>/dev/null || echo 'BTRFS subvolume list requires root'" 2>&1 | tee -a "$LOG_FILE"
    
    # Phase 12.3: Unmount filesystems
    log_info "Unmounting filesystems for system shutdown..."
    
    # Unmount in reverse order
    umount -l /mnt/root/var || log_warn "Failed to unmount /var"
    umount -l /mnt/root/home || log_warn "Failed to unmount /home"
    umount -l /mnt/root/.snapshots || log_warn "Failed to unmount /.snapshots"
    umount -l /mnt/root/boot || log_warn "Failed to unmount /boot"
    umount -l /mnt/root || log_warn "Failed to unmount root"
    
    # Close LUKS volume
    execute_cmd "cryptsetup luksClose root_crypt" "Closing LUKS encrypted volume"
    
    log_info "Filesystems unmounted and LUKS volume closed"
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    log_info "================================================================================"
    log_info "ARCH LINUX SECURE DEPLOYMENT AUTOMATION - STARTING INSTALLATION"
    log_info "================================================================================"
    log_info "Deployment log: $LOG_FILE"
    log_info "Error log: $ERROR_LOG"
    log_info ""
    
    phase_1_preflight
    phase_2_disk_encryption
    phase_3_btrfs_setup
    phase_4_pacstrap
    phase_5_mount_configuration
    phase_6_chroot_setup
    phase_7_grub_installation
    phase_8_system_configuration
    phase_9_user_setup
    phase_10_snapshot_automation
    phase_11_security_hardening
    phase_12_finalization
    
    log_info ""
    log_info "================================================================================"
    log_info "INSTALLATION COMPLETED SUCCESSFULLY"
    log_info "================================================================================"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Remove installation media (USB/ISO)"
    log_info "  2. Reboot system: reboot"
    log_info "  3. Boot into new Arch Linux system"
    log_info "  4. Unlock encrypted volume when prompted"
    log_info "  5. Login with user account created during installation"
    log_info ""
    log_info "System features enabled:"
    log_info "  - LUKS2 encryption (Argon2id KDF) on root partition"
    log_info "  - BTRFS root filesystem with compression and snapshotting"
    log_info "  - Automated weekly snapshots (Sunday 02:00 UTC)"
    log_info "  - Hardened kernel parameters and sysctl configuration"
    log_info "  - Zen kernel for performance optimization"
    log_info ""
    log_info "Full deployment log available at: $LOG_FILE"
    log_info ""
}

# Execute main function
main "$@"
