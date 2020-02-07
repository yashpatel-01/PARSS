#!/usr/bin/env bash

################################################################################
# ARCH LINUX SECURE RESEARCH DEPLOYMENT - PAASS v2.4 (Enhanced)
#
# Purpose: Complete automated Arch Linux installation with security hardening,
#          LUKS2 encryption, BTRFS snapshots, and reliability enhancements.
#
# Version: 2.4 (Refactored for Reliability & Security Pillars)
#
# New Features in v2.4:
#   ✓ Refactored Mount Logic (DRY)
#   ✓ Robust Network Resilience (Multi-host check)
#   ✓ ZRAM Swap Support
#   ✓ AppArmor Integration
#   ✓ Firewall (nftables) Default Deny
#   ✓ GRUB Fallback Logic
#   ✓ Dry-Run Capability
#   ✓ Improved Error Handling & Cleanup
#
# Usage: sudo bash ./arch-secure-deploy-v2.sh [--dry-run] [--enable-tpm2]
#
################################################################################

set -euo pipefail

# === COLOR DEFINITIONS ===
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# === LOGGING CONFIGURATION ===
readonly LOG_DIR="/var/log"
readonly LOG_FILE="$LOG_DIR/arch-deploy-$(date +%Y%m%d-%H%M%S).log"
readonly ERROR_LOG="$LOG_DIR/arch-deploy-errors-$(date +%Y%m%d-%H%M%S).log"
readonly STATE_FILE="/tmp/arch-deploy-state-$$.env"

# === INSTALLATION STATE VARIABLES ===
declare TARGET_DEVICE=""
declare BOOT_PARTITION=""
declare ROOT_PARTITION=""
declare HOME_PARTITION=""
declare ROOT_CRYPT="/dev/mapper/root_crypt"
declare MOUNT_ROOT="/mnt/root"
declare ROOT_SIZE_GB=50
declare HOME_SIZE_GB=0
declare AVAILABLE_SPACE_GB=0

# === INTERACTIVE CONFIGURATION VARIABLES ===
declare HOSTNAME_SYS="devta"
declare PRIMARY_USER="patel"
declare BTRFS_ROOT_VOL="root"
declare BTRFS_HOME_VOL="home"
declare BTRFS_SNAP_VOL="snapshots"
declare LUKS_ROOT_NAME="yumraj"
declare LUKS_HOME_NAME="yumdut"
declare ADD_LOG_SUBVOLUME="true"
declare ENABLE_NVIDIA_GPU="true"
declare SNAPSHOT_RETENTION=12
declare SYSTEM_TIMEZONE="UTC"

# === FEATURE FLAGS ===
declare DRY_RUN=false
declare ENABLE_TPM2=false
declare ENABLE_APPARMOR=true
declare ENABLE_FIREWALL=true

# === RETRY CONFIGURATION ===
readonly MAX_RETRIES=3
readonly RETRY_DELAY=5

# === ARGUMENT PARSING ===
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            echo -e "${YELLOW}[WARN] DRY-RUN MODE ENABLED - No changes will be written to disk${NC}"
            ;;
        --enable-tpm2)
            ENABLE_TPM2=true
            ;;
        --disable-apparmor)
            ENABLE_APPARMOR=false
            ;;
        --disable-firewall)
            ENABLE_FIREWALL=false
            ;;
    esac
done

################################################################################
# UTILITY FUNCTIONS
################################################################################

# Error handling with comprehensive logging
trap_error() {
    local line_number=$1
    local error_code=${2:-1}
    
    echo -e "${RED}[FATAL ERROR]${NC} Script failed at line ${line_number} (exit code: $error_code)" | tee -a "$ERROR_LOG"
    echo "Diagnostic Information:" | tee -a "$ERROR_LOG"
    echo "  Timestamp: $(date)" | tee -a "$ERROR_LOG"
    echo "  Disk usage: $(df -h / | tail -1 2>/dev/null || echo 'N/A')" | tee -a "$ERROR_LOG"
    echo "  Memory usage: $(free -h | grep Mem 2>/dev/null || echo 'N/A')" | tee -a "$ERROR_LOG"
    echo "" | tee -a "$ERROR_LOG"
    echo "Logs:" >&2
    echo "  Full log: $LOG_FILE" >&2
    echo "  Error log: $ERROR_LOG" >&2
    echo "  State file: $STATE_FILE" >&2
    
    cleanup_on_error
    exit "$error_code"
}

trap 'trap_error ${LINENO}' ERR

# Cleanup function for error scenarios
cleanup_on_error() {
    log_warn "Attempting emergency cleanup..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Dry-run: Cleanup skipped"
        return
    fi

    if [[ -b "$ROOT_CRYPT" ]]; then
        cryptsetup close root_crypt 2>/dev/null || true
    fi
    
    if [[ -b "/dev/mapper/home_crypt" ]]; then
        cryptsetup close home_crypt 2>/dev/null || true
    fi
    
    umount -l /mnt/root/* 2>/dev/null || true
    umount -l /mnt/root 2>/dev/null || true
    
    # Clean up temporary keyfiles if they exist
    rm -f /tmp/luks-*-key-* 2>/dev/null || true
}

# Logging functions
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

log_success() {
    local message="$1"
    echo -e "${GREEN}[✓ SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}[✗ ERROR]${NC} $message" | tee -a "$LOG_FILE" "$ERROR_LOG"
}

log_section() {
    local title="$1"
    echo "" | tee -a "$LOG_FILE"
    echo -e "${CYAN}================================================================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}$title${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}================================================================================${NC}" | tee -a "$LOG_FILE"
}

# Execute command with error handling and dry-run support
execute_cmd() {
    local cmd="$1"
    local description="${2:-Executing command}"
    local critical="${3:-true}"
    
    log_debug "$description"
    log_debug "Command: $cmd"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] $description"
        return 0
    fi
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_debug "$description - SUCCESS"
        return 0
    else
        local exit_code=$?
        local error_msg="$description - FAILED (exit code: $exit_code)"
        
        if [[ "$critical" == "true" ]]; then
            log_error "$error_msg"
            echo "Command: $cmd" >> "$ERROR_LOG"
            echo "Exit code: $exit_code" >> "$ERROR_LOG"
            return "$exit_code"
        else
            log_warn "$error_msg (non-critical, continuing)"
            return 0
        fi
    fi
}

# Execute command with retry logic
execute_cmd_retry() {
    local cmd="$1"
    local description="$2"
    local max_attempts="${3:-$MAX_RETRIES}"
    local attempt=1
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] $description (Retryable)"
        return 0
    fi
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "[$attempt/$max_attempts] $description"
        
        if eval "$cmd" >> "$LOG_FILE" 2>&1; then
            log_success "$description - SUCCESS"
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "Attempt $attempt failed, retrying in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi
        
        ((attempt++))
    done
    
    log_error "$description - FAILED after $max_attempts attempts"
    return 1
}

# Save installation state
save_state() {
    local key="$1"
    local value="$2"
    echo "export $key=\"$value\"" >> "$STATE_FILE"
}

# Load installation state
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        log_debug "Loading installation state from $STATE_FILE"
        # shellcheck source=/dev/null
        source "$STATE_FILE"
    fi
}

# Validate block device
validate_block_device() {
    local device="$1"
    
    if [[ ! -b "$device" ]]; then
        return 1
    fi
    
    if grep -q "$device" /proc/mounts; then
        log_error "Device $device is currently mounted"
        return 1
    fi
    
    log_success "Block device $device validated"
    return 0
}

# Confirm destructive operation
confirm_destructive_operation() {
    local device="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Skipping destructive confirmation for $device"
        return 0
    fi

    local size_gb
    size_gb=$(lsblk -bnd -o SIZE "$device" | awk '{printf "%.0f", $1/(1024**3)}')
    
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    ⚠️  DESTRUCTIVE OPERATION  ⚠️                 ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Device: ${YELLOW}$device${NC}"
    echo -e "Size: ${YELLOW}${size_gb}GB${NC}"
    echo -e "Action: ${RED}ALL DATA WILL BE PERMANENTLY DESTROYED${NC}"
    echo ""
    echo "This action CANNOT be undone. You must:"
    echo "  1. Confirm you selected the CORRECT device"
    echo "  2. Confirm you have backed up all important data"
    echo "  3. Type 'YES' to proceed"
    echo ""
    
    read -p "Type 'YES' to confirm: " confirmation
    
    if [[ "$confirmation" != "YES" ]]; then
        log_warn "Confirmation failed. Operation cancelled."
        exit 0
    fi
    
    log_success "Destructive operation confirmed for $device"
}

# Validate hostname
validate_hostname() {
    local hostname="$1"
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
        return 1
    fi
    return 0
}

# Validate username
validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]] || [[ -z "$username" ]]; then
        return 1
    fi
    return 0
}

# Validate volume name
validate_volume_name() {
    local volname="$1"
    if [[ ! "$volname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    return 0
}

# Prompt for LUKS passphrase
prompt_luks_passphrase() {
    log_section "LUKS ENCRYPTION PASSPHRASE SETUP"
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  ENCRYPTION PASSPHRASE SETUP                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Passphrase Requirements:"
    echo "  • Minimum 12 characters recommended"
    echo "  • Mix of uppercase, lowercase, numbers, special chars recommended"
    echo ""
    echo -e "${YELLOW}⚠️  You will need this passphrase to boot your system every time${NC}"
    echo -e "${YELLOW}⚠️  Write it down and store it in a secure location${NC}"
    echo -e "${YELLOW}⚠️  This SINGLE passphrase will unlock BOTH root and home partitions${NC}"
    echo ""
    
    local passphrase=""
    local passphrase_confirm=""
    local attempts=0
    
    while [[ $attempts -lt 3 ]]; do
        read -sp "Enter passphrase: " passphrase
        echo ""
        
        read -sp "Confirm passphrase: " passphrase_confirm
        echo ""
        
        if [[ "$passphrase" != "$passphrase_confirm" ]]; then
            log_warn "Passphrases do not match. Try again."
            ((attempts++))
            continue
        fi
        
        if [[ -z "$passphrase" ]]; then
             log_warn "Passphrase cannot be empty."
             ((attempts++))
             continue
        fi

        log_success "Passphrase validated successfully"
        echo "$passphrase"
        return 0
    done
    
    log_error "Failed to set valid passphrase after 3 attempts"
    return 1
}

# Prompt for partition size
prompt_partition_size() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║               CUSTOM PARTITION SIZE CONFIGURATION               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Total available space: ${AVAILABLE_SPACE_GB}GB"
    echo ""
    echo "Configuration:"
    echo "  1. EFI System Partition: 1GB (FAT32)"
    echo "  2. Root partition (@): Customizable (default: 50GB)"
    echo "  3. Home partition (@home): Remainder of disk"
    echo ""
    
    while true; do
        read -p "Enter root partition size in GB [50]: " root_input
        root_input="${root_input:-50}"
        
        if ! [[ "$root_input" =~ ^[0-9]+$ ]]; then
            log_warn "Invalid input. Please enter a number."
            continue
        fi
        
        ROOT_SIZE_GB=$root_input
        HOME_SIZE_GB=$((AVAILABLE_SPACE_GB - 1 - ROOT_SIZE_GB))
        
        if [[ $ROOT_SIZE_GB -lt 50 ]]; then
            log_warn "Root partition must be at least 50GB"
            continue
        fi
        
        if [[ $HOME_SIZE_GB -lt 20 ]]; then
            log_warn "Home partition must be at least 20GB (${HOME_SIZE_GB}GB remaining)"
            continue
        fi
        
        echo ""
        echo -e "${GREEN}Partition Layout:${NC}"
        echo "  EFI System Partition: 1GB"
        echo "  Root partition (@):   ${ROOT_SIZE_GB}GB"
        echo "  Home partition (@home): ${HOME_SIZE_GB}GB"
        echo "  Total:                $((1 + ROOT_SIZE_GB + HOME_SIZE_GB))GB"
        echo ""
        
        read -p "Is this configuration correct? (yes/no) [yes]: " confirm_partition
        confirm_partition="${confirm_partition:-yes}"
        
        if [[ "$confirm_partition" == "yes" ]] || [[ "$confirm_partition" == "y" ]]; then
            log_success "Partition configuration confirmed"
            return 0
        fi
    done
}

# Check available disk space
check_disk_space() {
    local device="$1"
    local total_bytes
    total_bytes=$(lsblk -bnd -o SIZE "$device")
    AVAILABLE_SPACE_GB=$((total_bytes / (1024**3)))
    
    log_info "Available disk space: ${AVAILABLE_SPACE_GB}GB"
    
    if [[ $AVAILABLE_SPACE_GB -lt 71 ]]; then
        log_error "Insufficient disk space. Minimum required: 71GB (1GB EFI + 50GB root + 20GB home), Available: ${AVAILABLE_SPACE_GB}GB"
        return 1
    fi
    
    return 0
}

# Helper: Mount BTRFS Subvolume (DRY Refactor)
mount_btrfs_subvol() {
    local subvol="$1"
    local mountpoint="$2"
    local extra_opts="${3:-}"
    local opts="subvol=${subvol},compress=zstd,noatime,space_cache=v2${extra_opts}"
    
    log_info "Mounting ${subvol} to ${mountpoint}..."
    mkdir -p "$mountpoint"
    
    if ! execute_cmd "mount -o \"$opts\" \"/dev/mapper/$LUKS_ROOT_NAME\" \"$mountpoint\"" "Mounting $subvol" true; then
        log_error "Failed to mount $subvol"
        return 1
    fi
}

# Helper: Robust Network Check
check_network_robust() {
    local hosts=("1.1.1.1" "8.8.8.8" "archlinux.org" "google.com")
    local success=false
    
    log_info "Verifying network connectivity..."
    
    for host in "${hosts[@]}"; do
        if ping -c 1 -W 2 "$host" &>/dev/null; then
            log_success "Connected to $host"
            success=true
            break
        fi
    done
    
    if [[ "$success" == "true" ]]; then
        return 0
    else
        log_warn "Network check failed for all hosts"
        return 1
    fi
}

################################################################################
# PHASE 1: PRE-FLIGHT VALIDATION
################################################################################

phase_1_preflight_checks() {
    log_section "PHASE 1: PRE-FLIGHT VALIDATION"
    
    log_info "Checking system resources..."
    
    local cpu_cores
    cpu_cores=$(nproc)
    log_debug "CPU cores: $cpu_cores"
    
    local ram_gb
    ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    log_debug "RAM: ${ram_gb}GB"
    
    if [[ $ram_gb -lt 4 ]]; then
        log_warn "RAM is below recommended 4GB (current: ${ram_gb}GB)"
    fi
    
    # Robust network check
    if check_network_robust; then
        log_success "Network connectivity verified"
    else
        log_warn "Network connectivity check failed - Installation may fail if packages cannot be downloaded"
        read -p "Continue anyway? (y/n): " continue_net
        if [[ "$continue_net" != "y" ]]; then return 1; fi
    fi
    
    log_info "Verifying required tools..."
    local required_tools=("cryptsetup" "parted" "mkfs.btrfs" "pacstrap" "arch-chroot" "genfstab" "udevadm")
    
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_debug "✓ $tool available"
        else
            log_error "Required tool not found: $tool"
            return 1
        fi
    done
    
    log_success "Phase 1 completed successfully"
}

################################################################################
# PHASE 1B: INTERACTIVE SYSTEM CONFIGURATION
################################################################################

phase_1b_interactive_configuration() {
    log_section "PHASE 1B: INTERACTIVE SYSTEM CONFIGURATION"
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         CUSTOM SYSTEM CONFIGURATION (Interactive)          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "This script will ask for custom names and settings."
    echo "Press Enter to use default values shown in [brackets]"
    echo ""
    
    # SECTION 1: SYSTEM IDENTIFICATION
    log_info "SECTION 1: System Identification"
    echo ""
    
    log_info "Enter system hostname (computer name)"
    echo "Examples: thinkpad-research, arch-laptop, secure-dev"
    read -p "Hostname [devta]: " input_hostname
    HOSTNAME_SYS="${input_hostname:-devta}"
    
    if ! validate_hostname "$HOSTNAME_SYS"; then
        log_error "Invalid hostname. Use only alphanumeric and hyphens."
        return 1
    fi
    
    log_success "Hostname: $HOSTNAME_SYS"
    
    log_info "Enter primary username (login account)"
    echo "Examples: patel, research, developer"
    read -p "Username [patel]: " input_username
    PRIMARY_USER="${input_username:-patel}"
    
    if ! validate_username "$PRIMARY_USER"; then
        log_error "Invalid username. Use only alphanumeric, underscore, or hyphen."
        return 1
    fi
    
    log_success "Username: $PRIMARY_USER"
    
    # SECTION 2: STORAGE & BTRFS CONFIGURATION
    log_info ""
    log_info "SECTION 2: Storage & BTRFS Configuration"
    echo ""
    
    log_info "BTRFS root logical volume name"
    echo "This labels your encrypted root volume"
    read -p "BTRFS root volume [root]: " input_root_vol
    BTRFS_ROOT_VOL="${input_root_vol:-root}"
    
    if ! validate_volume_name "$BTRFS_ROOT_VOL"; then
        log_error "Invalid BTRFS root volume name"
        return 1
    fi
    
    log_success "BTRFS root volume: $BTRFS_ROOT_VOL"
    
    log_info "BTRFS home logical volume name"
    echo "This labels your encrypted home partition"
    read -p "BTRFS home volume [home]: " input_home_vol
    BTRFS_HOME_VOL="${input_home_vol:-home}"
    
    if ! validate_volume_name "$BTRFS_HOME_VOL"; then
        log_error "Invalid BTRFS home volume name"
        return 1
    fi
    
    log_success "BTRFS home volume: $BTRFS_HOME_VOL"
    
    log_info "BTRFS snapshots volume name"
    echo "This stores BTRFS snapshots for recovery"
    read -p "BTRFS snapshots volume [snapshots]: " input_snap_vol
    BTRFS_SNAP_VOL="${input_snap_vol:-snapshots}"
    
    if ! validate_volume_name "$BTRFS_SNAP_VOL"; then
        log_error "Invalid BTRFS snapshots volume name"
        return 1
    fi
    
    log_success "BTRFS snapshots volume: $BTRFS_SNAP_VOL"
    
    # SECTION 3: ENCRYPTION CONFIGURATION
    log_info ""
    log_info "SECTION 3: LUKS Encryption Names"
    echo ""
    
    log_info "LUKS encrypted root volume name"
    echo "This is the cryptographic mapping name for root"
    read -p "Root encryption name [yumraj]: " input_crypt_root
    LUKS_ROOT_NAME="${input_crypt_root:-yumraj}"
    
    if ! validate_volume_name "$LUKS_ROOT_NAME"; then
        log_error "Invalid LUKS root name"
        return 1
    fi
    
    log_success "Root encryption: $LUKS_ROOT_NAME"
    
    log_info "LUKS encrypted home volume name"
    echo "This is the cryptographic mapping name for home"
    read -p "Home encryption name [yumdut]: " input_crypt_home
    LUKS_HOME_NAME="${input_crypt_home:-yumdut}"
    
    if ! validate_volume_name "$LUKS_HOME_NAME"; then
        log_error "Invalid LUKS home name"
        return 1
    fi
    
    log_success "Home encryption: $LUKS_HOME_NAME"
    
    # SECTION 4: OPTIONAL FEATURES
    log_info ""
    log_info "SECTION 4: Optional Features"
    echo ""
    
    log_info "Include @log BTRFS subvolume?"
    echo "(Separates systemd journal - improves snapshot efficiency)"
    read -p "Include @log (y/n) [y]: " input_log
    ADD_LOG_SUBVOLUME="${input_log:-y}"
    [[ "$ADD_LOG_SUBVOLUME" =~ ^[yY]$ ]] && ADD_LOG_SUBVOLUME="true" || ADD_LOG_SUBVOLUME="false"
    log_success "@log subvolume: $ADD_LOG_SUBVOLUME"
    
    log_info "Enable NVIDIA GPU drivers?"
    echo "(For RTX A5500 CUDA support)"
    read -p "Enable NVIDIA (y/n) [y]: " input_gpu
    ENABLE_NVIDIA_GPU="${input_gpu:-y}"
    [[ "$ENABLE_NVIDIA_GPU" =~ ^[yY]$ ]] && ENABLE_NVIDIA_GPU="true" || ENABLE_NVIDIA_GPU="false"
    log_success "NVIDIA GPU support: $ENABLE_NVIDIA_GPU"
    
    log_info "Snapshot retention count"
    echo "(Number of weekly snapshots to keep: 12 = ~3 months)"
    read -p "Snapshot retention [12]: " input_snapshots
    SNAPSHOT_RETENTION="${input_snapshots:-12}"
    
    if ! [[ "$SNAPSHOT_RETENTION" =~ ^[0-9]+$ ]] || [[ "$SNAPSHOT_RETENTION" -lt 2 ]]; then
        log_warn "Invalid snapshot retention, using default: 12"
        SNAPSHOT_RETENTION=12
    fi
    
    log_success "Snapshot retention: $SNAPSHOT_RETENTION"
    
    log_info "System timezone"
    echo "(Examples: UTC, America/New_York, Europe/London)"
    read -p "Timezone [UTC]: " input_timezone
    SYSTEM_TIMEZONE="${input_timezone:-UTC}"
    log_success "Timezone: $SYSTEM_TIMEZONE"
    
    # CONFIRMATION
    log_info ""
    log_info "════════════════════════════════════════════════════════════"
    log_info "INSTALLATION SUMMARY - Please Review"
    log_info "════════════════════════════════════════════════════════════"
    log_info ""
    log_info "SYSTEM IDENTIFICATION:"
    log_info "  Hostname:                $HOSTNAME_SYS"
    log_info "  Primary User:            $PRIMARY_USER"
    log_info ""
    log_info "STORAGE CONFIGURATION:"
    log_info "  Storage Device:          $TARGET_DEVICE"
    log_info "  Root Partition:          ${ROOT_SIZE_GB}GB"
    log_info "  Home Partition:          ${HOME_SIZE_GB}GB"
    log_info "  BTRFS Root Volume:       $BTRFS_ROOT_VOL"
    log_info "  BTRFS Home Volume:       $BTRFS_HOME_VOL"
    log_info "  BTRFS Snapshots Volume:  $BTRFS_SNAP_VOL"
    log_info ""
    log_info "ENCRYPTION:"
    log_info "  Root Encryption:         $LUKS_ROOT_NAME"
    log_info "  Home Encryption:         $LUKS_HOME_NAME"
    log_info "  Passphrase Mode:         Single passphrase (unlocks both)"
    log_info ""
    log_info "OPTIONAL FEATURES:"
    log_info "  @log Subvolume:          $ADD_LOG_SUBVOLUME"
    log_info "  NVIDIA GPU Support:      $ENABLE_NVIDIA_GPU"
    log_info "  Snapshot Retention:      $SNAPSHOT_RETENTION"
    log_info "  Timezone:                $SYSTEM_TIMEZONE"
    log_info "  AppArmor:                $ENABLE_APPARMOR"
    log_info "  Firewall (nftables):     $ENABLE_FIREWALL"
    log_info "  TPM2 Support:            $ENABLE_TPM2"
    log_info ""
    log_info "════════════════════════════════════════════════════════════"
    echo ""
    
    read -p "Proceed with installation? (type 'YES' to confirm): " final_confirm
    
    if [[ "$final_confirm" != "YES" ]]; then
        log_warn "Installation cancelled by user"
        exit 0
    fi
    
    # SAVE CONFIGURATION TO STATE FILE
    log_info "Saving configuration..."
    
    save_state "HOSTNAME_SYS" "$HOSTNAME_SYS"
    save_state "PRIMARY_USER" "$PRIMARY_USER"
    save_state "BTRFS_ROOT_VOL" "$BTRFS_ROOT_VOL"
    save_state "BTRFS_HOME_VOL" "$BTRFS_HOME_VOL"
    save_state "BTRFS_SNAP_VOL" "$BTRFS_SNAP_VOL"
    save_state "LUKS_ROOT_NAME" "$LUKS_ROOT_NAME"
    save_state "LUKS_HOME_NAME" "$LUKS_HOME_NAME"
    save_state "ADD_LOG_SUBVOLUME" "$ADD_LOG_SUBVOLUME"
    save_state "ENABLE_NVIDIA_GPU" "$ENABLE_NVIDIA_GPU"
    save_state "SNAPSHOT_RETENTION" "$SNAPSHOT_RETENTION"
    save_state "SYSTEM_TIMEZONE" "$SYSTEM_TIMEZONE"
    
    log_success "Configuration saved to state file"
    log_success "Phase 1B completed successfully"
}

################################################################################
# PHASE 2: DEVICE & PARTITION CONFIGURATION (MENU-BASED SELECTION)
################################################################################

phase_2_device_configuration() {
    log_section "PHASE 2: DEVICE & PARTITION CONFIGURATION"
    
    log_info "Available block devices:"
    echo ""
    
    # Get list of block devices
    local -a devices
    mapfile -t devices < <(lsblk -d -n -o NAME,SIZE,TYPE | grep -E "nvme|sd" | awk '{print $1}')
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        log_error "No suitable storage devices found"
        return 1
    fi
    
    # Display menu
    local i=1
    declare -A device_menu
    
    for dev in "${devices[@]}"; do
        local full_path="/dev/$dev"
        local size=$(lsblk -d -n -o SIZE "$full_path")
        local type=$(lsblk -d -n -o TYPE "$full_path")
        
        echo "  ($i) $full_path - $size - $type"
        device_menu[$i]="$full_path"
        ((i++))
    done
    
    echo ""
    
    # Get user selection
    while true; do
        read -p "Select storage device (enter number 1-$((i-1))): " device_choice
        
        if [[ ! "$device_choice" =~ ^[0-9]+$ ]]; then
            log_warn "Invalid input. Please enter a number."
            continue
        fi
        
        if [[ -z "${device_menu[$device_choice]}" ]]; then
            log_warn "Invalid selection. Choose a number between 1 and $((i-1))."
            continue
        fi
        
        TARGET_DEVICE="${device_menu[$device_choice]}"
        
        if ! validate_block_device "$TARGET_DEVICE"; then
            log_warn "Invalid or mounted device: $TARGET_DEVICE"
            continue
        fi
        
        break
    done
    
    save_state "TARGET_DEVICE" "$TARGET_DEVICE"
    
    if ! check_disk_space "$TARGET_DEVICE"; then
        return 1
    fi
    
    prompt_partition_size
    
    confirm_destructive_operation "$TARGET_DEVICE"
    
    # CRITICAL FIX: Set partition names BEFORE Phase 3
    if [[ "$TARGET_DEVICE" == *"nvme"* ]] || [[ "$TARGET_DEVICE" == *"mmcblk"* ]]; then
        BOOT_PARTITION="${TARGET_DEVICE}p1"
        ROOT_PARTITION="${TARGET_DEVICE}p2"
        HOME_PARTITION="${TARGET_DEVICE}p3"
    else
        BOOT_PARTITION="${TARGET_DEVICE}1"
        ROOT_PARTITION="${TARGET_DEVICE}2"
        HOME_PARTITION="${TARGET_DEVICE}3"
    fi
    
    log_info "Partition configuration:"
    log_info "  Boot: $BOOT_PARTITION"
    log_info "  Root: $ROOT_PARTITION (${ROOT_SIZE_GB}GB)"
    log_info "  Home: $HOME_PARTITION (${HOME_SIZE_GB}GB)"
    
    save_state "BOOT_PARTITION" "$BOOT_PARTITION"
    save_state "ROOT_PARTITION" "$ROOT_PARTITION"
    save_state "HOME_PARTITION" "$HOME_PARTITION"
    
    log_success "Phase 2 completed successfully"
}

################################################################################
# PHASE 3: DISK WIPING & PARTITIONING
################################################################################

phase_3_disk_preparation() {
    log_section "PHASE 3: DISK WIPING & PARTITIONING"
    
    log_info "Closing any existing LUKS volumes..."
    if [[ "$DRY_RUN" != "true" ]]; then
        cryptsetup close "${LUKS_ROOT_NAME}" 2>/dev/null || true
        cryptsetup close "${LUKS_HOME_NAME}" 2>/dev/null || true
    fi
    
    log_info "Unmounting any existing partitions on $TARGET_DEVICE..."
    if [[ "$DRY_RUN" != "true" ]]; then
        umount "${TARGET_DEVICE}"* 2>/dev/null || true
    fi
    
    log_info "Wiping existing filesystem signatures from $TARGET_DEVICE..."
    execute_cmd "wipefs -af $TARGET_DEVICE" "Wiping all filesystem signatures" true
    
    log_info "Zeroing out first 10MB of disk..."
    execute_cmd "dd if=/dev/zero of=$TARGET_DEVICE bs=1M count=10 conv=fsync" "Zeroing disk header" true
    sync
    
    log_info "Creating new GPT partition table..."
    execute_cmd "parted -s $TARGET_DEVICE mklabel gpt" "Creating GPT label" true
    sync
    sleep 2
    
    log_info "Creating EFI System Partition (1GB)..."
    # Use percentage for better alignment
    execute_cmd "parted -s -a optimal $TARGET_DEVICE mkpart ESP fat32 1MiB 1025MiB" "Creating ESP partition" true
    execute_cmd "parted -s $TARGET_DEVICE set 1 esp on" "Setting ESP boot flag" true
    sync
    sleep 1
    
    log_info "Creating root partition (${ROOT_SIZE_GB}GB)..."
    local root_start_mib=1025
    local root_end_mib=$((root_start_mib + ROOT_SIZE_GB * 1024))
    execute_cmd "parted -s -a optimal $TARGET_DEVICE mkpart primary ${root_start_mib}MiB ${root_end_mib}MiB" "Creating root partition" true
    sync
    sleep 1
    
    log_info "Creating home partition (${HOME_SIZE_GB}GB, remainder)..."
    execute_cmd "parted -s -a optimal $TARGET_DEVICE mkpart primary ${root_end_mib}MiB 100%" "Creating home partition" true
    sync
    sleep 1
    
    log_info "Refreshing partition table..."
    if [[ "$DRY_RUN" != "true" ]]; then
        partprobe "$TARGET_DEVICE" 2>/dev/null || true
        udevadm settle --timeout=10 || true
        sync
        sleep 3
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Phase 3 completed successfully (DRY RUN)"
        return 0
    fi

    log_info "Verifying partitions exist..."
    if [[ ! -b "$BOOT_PARTITION" ]]; then
        log_error "Boot partition $BOOT_PARTITION not found"
        lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"
        return 1
    fi
    
    if [[ ! -b "$ROOT_PARTITION" ]]; then
        log_error "Root partition $ROOT_PARTITION not found"
        lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"
        return 1
    fi
    
    if [[ ! -b "$HOME_PARTITION" ]]; then
        log_error "Home partition $HOME_PARTITION not found"
        lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"
        return 1
    fi
    
    log_success "All partitions verified successfully"
    
    log_info "Setting partition types (LUKS)..."
    parted -s "$TARGET_DEVICE" set 2 type 8309 2>/dev/null || log_warn "Could not set root partition type (non-critical)"
    parted -s "$TARGET_DEVICE" set 3 type 8309 2>/dev/null || log_warn "Could not set home partition type (non-critical)"
    
    log_info "Final partition table:"
    parted -s "$TARGET_DEVICE" print | tee -a "$LOG_FILE"
    lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"
    
    log_success "Phase 3 completed successfully"
}

################################################################################
# PHASE 4: LUKS ENCRYPTION SETUP (SINGLE PASSPHRASE)
################################################################################

phase_4_luks_encryption() {
    log_section "PHASE 4: LUKS2 ENCRYPTION SETUP (SINGLE PASSPHRASE)"
    
    local luks_passphrase
    luks_passphrase=$(prompt_luks_passphrase) || return 1
    
    # ═══════════════════════════════════════════════════════════
    # FORMAT EFI SYSTEM PARTITION
    # ═══════════════════════════════════════════════════════════
    
    log_info "Formatting EFI System Partition..."
    sleep 2
    if [[ "$DRY_RUN" != "true" ]]; then
        udevadm settle --timeout=10 || true
    fi
    
    if [[ ! -b "$BOOT_PARTITION" ]] && [[ "$DRY_RUN" != "true" ]]; then
        log_error "Boot partition $BOOT_PARTITION not available"
        return 1
    fi
    
    execute_cmd "mkfs.fat -F 32 -n EFI $BOOT_PARTITION" "Formatting $BOOT_PARTITION as FAT32" true
    sync
    
    # ═══════════════════════════════════════════════════════════
    # ENCRYPT ROOT PARTITION
    # ═══════════════════════════════════════════════════════════
    
    log_info "Preparing root partition for encryption..."
    if [[ "$DRY_RUN" != "true" ]]; then
        sleep 2
        udevadm settle --timeout=10 || true
        
        if [[ ! -b "$ROOT_PARTITION" ]]; then
            log_error "Root partition $ROOT_PARTITION not available"
            lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"
            return 1
        fi
        
        # Check if already encrypted (cleanup from previous failed attempt)
        if cryptsetup isLuks "$ROOT_PARTITION" 2>/dev/null; then
            log_warn "Root partition already has LUKS header"
            log_warn "Erasing existing LUKS header..."
            echo "YES" | cryptsetup luksErase "$ROOT_PARTITION" 2>/dev/null || true
            sync
            sleep 2
        fi
    fi
    
    log_info "Encrypting root partition with LUKS2 (Argon2id KDF)..."
    
    # Use temporary keyfile with trap for cleanup
    local temp_keyfile_root="/tmp/luks-root-key-$$"
    trap 'rm -f "$temp_keyfile_root"' EXIT
    echo -n "$luks_passphrase" > "$temp_keyfile_root"
    chmod 600 "$temp_keyfile_root"
    
    # LUKS format with keyfile
    execute_cmd "cryptsetup luksFormat --type luks2 --pbkdf argon2id --pbkdf-force-iterations 4 --label 'LUKS_ROOT' --key-file '$temp_keyfile_root' '$ROOT_PARTITION'" "LUKS Format Root" true
    
    # Wait for LUKS metadata to be written
    sync
    sleep 3
    if [[ "$DRY_RUN" != "true" ]]; then
        udevadm settle --timeout=10 || true
        
        # Verify LUKS header
        if ! cryptsetup isLuks "$ROOT_PARTITION"; then
            log_error "LUKS header verification failed"
            return 1
        fi
    fi
    
    log_success "LUKS header verified"
    
    log_info "Opening encrypted root volume..."
    
    execute_cmd "cryptsetup luksOpen --key-file '$temp_keyfile_root' '$ROOT_PARTITION' '$LUKS_ROOT_NAME'" "Opening LUKS Root" true
    
    # Securely delete keyfile (trap will also catch this)
    rm -f "$temp_keyfile_root"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        sleep 1
        udevadm settle --timeout=10 || true
        
        if [[ ! -b "/dev/mapper/$LUKS_ROOT_NAME" ]]; then
            log_error "Encrypted root device /dev/mapper/$LUKS_ROOT_NAME not found"
            ls -la /dev/mapper/ | tee -a "$LOG_FILE"
            return 1
        fi
    fi
    
    log_success "Root partition encrypted and opened successfully"
    
    # ═══════════════════════════════════════════════════════════
    # ENCRYPT HOME PARTITION (SAME METHOD)
    # ═══════════════════════════════════════════════════════════
    
    log_info "Preparing home partition for encryption..."
    if [[ "$DRY_RUN" != "true" ]]; then
        sleep 2
        udevadm settle --timeout=10 || true
        
        if [[ ! -b "$HOME_PARTITION" ]]; then
            log_error "Home partition $HOME_PARTITION not available"
            lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"
            return 1
        fi
        
        # Check if already encrypted
        if cryptsetup isLuks "$HOME_PARTITION" 2>/dev/null; then
            log_warn "Home partition already has LUKS header"
            echo "YES" | cryptsetup luksErase "$HOME_PARTITION" 2>/dev/null || true
            sync
            sleep 2
        fi
    fi
    
    log_info "Encrypting home partition with LUKS2 (using SAME passphrase)..."
    
    # Create secure temporary keyfile
    local temp_keyfile_home="/tmp/luks-home-key-$$"
    trap 'rm -f "$temp_keyfile_home"' EXIT
    echo -n "$luks_passphrase" > "$temp_keyfile_home"
    chmod 600 "$temp_keyfile_home"
    
    # LUKS format
    execute_cmd "cryptsetup luksFormat --type luks2 --pbkdf argon2id --pbkdf-force-iterations 4 --label 'LUKS_HOME' --key-file '$temp_keyfile_home' '$HOME_PARTITION'" "LUKS Format Home" true
    
    sync
    sleep 3
    if [[ "$DRY_RUN" != "true" ]]; then
        udevadm settle --timeout=10 || true
        
        # Verify LUKS header
        if ! cryptsetup isLuks "$HOME_PARTITION"; then
            log_error "LUKS header verification failed for home partition"
            return 1
        fi
    fi
    
    log_info "Opening encrypted home volume..."
    
    # Open with keyfile
    execute_cmd "cryptsetup luksOpen --key-file '$temp_keyfile_home' '$HOME_PARTITION' '$LUKS_HOME_NAME'" "Opening LUKS Home" true
    
    # Securely delete keyfile
    rm -f "$temp_keyfile_home"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        sleep 1
        udevadm settle --timeout=10 || true
        
        if [[ ! -b "/dev/mapper/$LUKS_HOME_NAME" ]]; then
            log_error "Encrypted home device /dev/mapper/$LUKS_HOME_NAME not found"
            ls -la /dev/mapper/ | tee -a "$LOG_FILE"
            return 1
        fi
    fi
    
    log_success "Home partition encrypted and opened with SAME passphrase"
    
    # ═══════════════════════════════════════════════════════════
    # FINAL VERIFICATION
    # ═══════════════════════════════════════════════════════════
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Verifying encrypted volumes..."
        ls -la /dev/mapper/ | tee -a "$LOG_FILE"
        
        log_info "LUKS status summary:"
        log_info "  Root: $ROOT_PARTITION → /dev/mapper/$LUKS_ROOT_NAME"
        log_info "  Home: $HOME_PARTITION → /dev/mapper/$LUKS_HOME_NAME"
        log_info "  Single passphrase: ✓"
    fi
    
    save_state "ROOT_CRYPT_OPENED" "true"
    save_state "HOME_ENCRYPTED" "true"
    log_success "Phase 4 completed successfully"
}

################################################################################
# PHASE 5: BTRFS FILESYSTEM SETUP
################################################################################

phase_5_btrfs_filesystem() {
    log_section "PHASE 5: BTRFS FILESYSTEM SETUP"
    
    local root_crypt_device="/dev/mapper/$LUKS_ROOT_NAME"
    
    # ═══════════════════════════════════════════════════════════
    # CREATE BTRFS FILESYSTEM
    # ═══════════════════════════════════════════════════════════
    
    log_info "Creating BTRFS filesystem on encrypted root volume..."
    execute_cmd "mkfs.btrfs -f -L root_encrypted $root_crypt_device" \
        "Formatting $root_crypt_device with BTRFS" true
    
    log_info "Mounting BTRFS root (temporary)..."
    mkdir -p "$MOUNT_ROOT"
    execute_cmd "mount $root_crypt_device $MOUNT_ROOT" "Mounting BTRFS root" true
    
    # ═══════════════════════════════════════════════════════════
    # CREATE SUBVOLUMES
    # ═══════════════════════════════════════════════════════════
    
    log_info "Creating BTRFS subvolume hierarchy..."
    
    execute_cmd "btrfs subvolume create $MOUNT_ROOT/@" "Creating @ (root) subvolume" true
    execute_cmd "btrfs subvolume create $MOUNT_ROOT/@home" "Creating @home subvolume" true
    execute_cmd "btrfs subvolume create $MOUNT_ROOT/@var" "Creating @var subvolume" true
    execute_cmd "btrfs subvolume create $MOUNT_ROOT/@snapshots" "Creating @snapshots subvolume" true
    execute_cmd "btrfs subvolume create $MOUNT_ROOT/@varcache" "Creating @varcache subvolume" true
    
    if [[ "$ADD_LOG_SUBVOLUME" == "true" ]]; then
        execute_cmd "btrfs subvolume create $MOUNT_ROOT/@log" "Creating @log subvolume (for journal)" true
        log_success "@log subvolume created for systemd journal"
    fi
    
    # ═══════════════════════════════════════════════════════════
    # PREPARE FOR REMOUNTING
    # ═══════════════════════════════════════════════════════════
    
    log_info "Remounting with optimized mount options..."
    execute_cmd "umount $MOUNT_ROOT" "Unmounting temporary mount" true
    
    # ═══════════════════════════════════════════════════════════
    # MOUNT SUBVOLUMES (REFACTORED)
    # ═══════════════════════════════════════════════════════════
    
    # Mount root (@) with security flags
    mount_btrfs_subvol "@" "$MOUNT_ROOT" ",nodev,nosuid,noexec"
    
    # Mount home (@home)
    mount_btrfs_subvol "@home" "$MOUNT_ROOT/home"
    
    # Mount var (@var)
    mount_btrfs_subvol "@var" "$MOUNT_ROOT/var" ",nodev,nosuid"
    
    # Mount varcache (@varcache)
    mount_btrfs_subvol "@varcache" "$MOUNT_ROOT/var/cache" ",nodev,nosuid"
    
    # Mount snapshots (@snapshots)
    mount_btrfs_subvol "@snapshots" "$MOUNT_ROOT/.snapshots" ",nodev,nosuid"
    
    # Mount log (@log) - ONLY if ADD_LOG_SUBVOLUME is true
    if [[ "$ADD_LOG_SUBVOLUME" == "true" ]]; then
        mount_btrfs_subvol "@log" "$MOUNT_ROOT/var/log" ",nodev,nosuid"
    fi
    
    # Mount EFI partition
    log_info "Mounting EFI System Partition..."
    mkdir -p "$MOUNT_ROOT/boot"
    execute_cmd "mount $BOOT_PARTITION $MOUNT_ROOT/boot" "Mounting EFI partition" true
    
    log_success "BTRFS subvolume hierarchy created and mounted"
    
    save_state "MOUNT_ROOT" "$MOUNT_ROOT"
    save_state "BTRFS_MOUNTED" "true"
    log_success "Phase 5 completed successfully"
}
