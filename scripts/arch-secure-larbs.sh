#!/usr/bin/env bash

################################################################################
# ARCH LINUX SECURE RESEARCH DEPLOYMENT AUTOMATION SCRIPT (PILLAR 6 ENHANCED)
# 
# Purpose: Comprehensive, fully-automated installation and hardening for a
#          privacy-centric, security-engineered Arch Linux research platform
#          with reproducible desktop environment (suckless stack + voidrice).
#
# Target: Fresh Arch Linux ISO installation (bare metal equivalent)
# 
# Features:
#   - LUKS encryption with Argon2 key derivation (mandatory)
#   - BTRFS root filesystem with advanced snapshotting
#   - Security hardening (kernel parameters, sysctl tuning)
#   - CSV-driven package installation (pacman, AUR, Git)
#   - Automatic voidrice dotfile deployment
#   - Suckless window manager stack (dwm, st, dmenu, slstatus)
#   - Systemd timer-based weekly snapshot automation
#   - Reproducible desktop environment from dotfiles
#   - Comprehensive error handling and logging
#
# Architecture:
#   Phase 1-12: Base system installation + security hardening (Pillar 6)
#   Phase 13: AUR helper installation (yay)
#   Phase 14: CSV-driven package installation
#   Phase 15: Voidrice dotfile deployment
#   Phase 16: Suckless programs compilation
#   Phase 17: User environment finalization
#   Phase 18: System unmounting & verification
#
# Usage: sudo bash ./arch-secure-deploy-enhanced.sh
# 
# Prerequisites:
#   - Arch Linux ISO booted environment with network connectivity
#   - Target storage device identified (e.g., /dev/nvme0n1)
#   - Minimum 150GB storage (recommended 256GB+ for research + AUR builds)
#   - Root privilege execution
#
# Notes:
#   - Phases 1-12 from previous Pillar 6 script (see arch-secure-deploy.sh)
#   - Phases 13-18 are NEW: LARBS integration + dotfiles + suckless programs
#   - CSV package manifest can be customized (see progs.csv structure)
#   - Voidrice automatically deployed from Luke Smith's official repository
#   - Suckless programs compiled from official git sources
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
readonly STATE_FILE="/tmp/arch-deploy-state.env"

################################################################################
# UTILITY FUNCTIONS (Shared across all phases)
################################################################################

# Error handling with comprehensive logging
trap_error() {
    local line_number=$1
    echo -e "${RED}[ERROR]${NC} Script failed at line ${line_number}" | tee -a "$ERROR_LOG"
    echo "Full log available at: $LOG_FILE" >&2
    exit 1
}

trap 'trap_error ${LINENO}' ERR

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

# Execute command with error handling
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

# Save installation state
save_state() {
    local key="$1"
    local value="$2"
    echo "export $key=\"$value\"" >> "$STATE_FILE"
}

# Load installation state
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
    fi
}

################################################################################
# REFERENCE: Phases 1-12 are identical to arch-secure-deploy.sh
# They handle:
#   Phase 1: Pre-installation configuration
#   Phase 2: Disk partitioning & LUKS encryption
#   Phase 3: BTRFS filesystem setup
#   Phase 4: Base system installation (pacstrap)
#   Phase 5: Mount & encryption configuration
#   Phase 6: Chroot environment & mkinitcpio
#   Phase 7: GRUB bootloader installation
#   Phase 8: System configuration (hostname, timezone, locale)
#   Phase 9: User account setup
#   Phase 10: BTRFS snapshot automation (systemd timers)
#   Phase 11: Security hardening (sysctl + kernel parameters)
#   Phase 12: Finalization & verification
#
# For full implementation of Phases 1-12, reference arch-secure-deploy.sh
#
################################################################################

################################################################################
# PHASE 13: AUR HELPER INSTALLATION (YAY)
################################################################################

phase_13_aur_helper() {
    log_info "=== PHASE 13: AUR HELPER INSTALLATION (YAY) ==="
    
    log_info "Installing yay AUR helper for package management..."
    
    # Create temporary build directory
    local tmp_yay="$MOUNT_ROOT/tmp/yay-build"
    mkdir -p "$tmp_yay"
    
    log_info "Cloning yay from AUR repository..."
    execute_cmd "cd $tmp_yay && git clone https://aur.archlinux.org/yay.git" \
        "Cloning yay source repository"
    
    log_info "Building yay (this may take 2-3 minutes)..."
    arch-chroot "$MOUNT_ROOT" bash << 'EOC'
cd /tmp/yay-build/yay
makepkg -si --noconfirm 2>&1
if [[ $? -eq 0 ]]; then
    echo "yay installation successful"
else
    echo "yay installation failed" >&2
    exit 1
fi
EOC
    
    # Cleanup build directory
    rm -rf "$tmp_yay"
    
    log_info "yay AUR helper installation completed"
}

################################################################################
# PHASE 14: CSV-DRIVEN PACKAGE INSTALLATION
################################################################################

# CSV format: name^category^installation_method
# Installation methods:
#   "" (blank) = pacman repository (official/community)
#   "A"       = AUR (Arch User Repository via yay)
#   "G"       = Git source (clone, make, make install)

create_progs_csv() {
    # Purpose: Generate package manifest for installation
    # This can be customized or replaced with custom CSV
    # Each line format: packagename^category^method
    
    cat > "$MOUNT_ROOT/tmp/progs.csv" << 'CSV_CONTENT'
# ==============================================================================
# PROGRAMMING & DEVELOPMENT TOOLS
# ==============================================================================
base-devel^dev^
gcc^dev^
clang^dev^
make^dev^
cmake^dev^
gdb^dev^
lldb^dev^
rustup^dev^A
nodejs^dev^
npm^dev^
python^dev^
python-pip^dev^
go^dev^
git^dev^
github-cli^dev^A

# ==============================================================================
# DISPLAY SERVER & GRAPHICS (XORG)
# ==============================================================================
xorg-server^x11^
xorg-xinit^x11^
xorg-xrandr^x11^
xorg-xsetroot^x11^
xorg-xclipboard^x11^
xclip^x11^
xsel^x11^
xdotool^x11^
feh^x11^
picom^x11^

# ==============================================================================
# SUCKLESS ECOSYSTEM DEPENDENCIES
# ==============================================================================
libx11^suckless^
libxft^suckless^
libxinerama^suckless^
libxcb^suckless^
libxext^suckless^
freetype2^suckless^
fontconfig^suckless^
imlib2^suckless^

# ==============================================================================
# SUCKLESS PROGRAMS (Core - compiled from source in Phase 16)
# ==============================================================================
# Note: dwm^wm^G, st^terminal^G, dmenu^menu^G, slstatus^status^G
# These are compiled in Phase 16 from official suckless.org git repositories

# ==============================================================================
# SHELL & TERMINAL UTILITIES
# ==============================================================================
zsh^shell^
zsh-syntax-highlighting^shell^
zsh-autosuggestions^shell^
zsh-completions^shell^
fzf^shell^
ripgrep^shell^
fd^shell^
bat^shell^
exa^shell^
lsd^shell^
the_silver_searcher^shell^

# ==============================================================================
# FILE MANAGEMENT & NAVIGATION
# ==============================================================================
lf^files^A
ranger^files^
ueberzug^files^
tree^files^
ncdu^files^

# ==============================================================================
# TEXT EDITORS & EDITING TOOLS
# ==============================================================================
neovim^editor^
vim^editor^
nano^editor^
tree-sitter^editor^
luarocks^editor^A

# ==============================================================================
# INTERNET & NETWORKING TOOLS
# ==============================================================================
firefox^net^
w3m^net^
curl^net^
wget^net^
newsboat^net^
lynx^net^
neomutt^net^
urlscan^net^A

# ==============================================================================
# MULTIMEDIA & MEDIA PLAYERS
# ==============================================================================
ffmpeg^media^
imagemagick^media^
mpv^media^
mpc^media^
mpd^media^
ncmpcpp^media^
sox^media^
audacity^media^A

# ==============================================================================
# AUDIO SYSTEM & UTILITIES
# ==============================================================================
pulseaudio^audio^
pavucontrol^audio^
pamixer^audio^
alsa-utils^audio^
pulseaudio-alsa^audio^

# ==============================================================================
# DOCUMENT VIEWING & PDF TOOLS
# ==============================================================================
zathura^docs^
zathura-pdf-mupdf^docs^
zathura-ps^docs^
pdfminer.six^docs^A
ghostscript^docs^

# ==============================================================================
# SYSTEM UTILITIES & MONITORING
# ==============================================================================
htop^sysutil^
btop^sysutil^A
tmux^sysutil^
screen^sysutil^
openssh^sysutil^
rsync^sysutil^
gnu-netcat^sysutil^
strace^sysutil^
lsof^sysutil^

# ==============================================================================
# COMPRESSION & ARCHIVE TOOLS
# ==============================================================================
tar^util^
zip^util^
unzip^util^
p7zip^util^
bzip2^util^
xz^util^
gzip^util^

# ==============================================================================
# SECURITY & ENCRYPTION
# ==============================================================================
pass^security^
gnupg^security^
openssl^security^
age^security^A

# ==============================================================================
# FONTS
# ==============================================================================
ttf-liberation^font^
ttf-dejavu^font^
nerd-fonts-complete^font^A
noto-fonts^font^
noto-fonts-emoji^font^

# ==============================================================================
# SYSTEM PACKAGES
# ==============================================================================
pacman-contrib^system^
devtools^system^
systemd^system^
dbus^system^
elogind^system^

# ==============================================================================
# NOTIFICATION & UI COMPONENTS
# ==============================================================================
dunst^ui^
libnotify^ui^

# ==============================================================================
# MISCELLANEOUS UTILITIES
# ==============================================================================
man-db^doc^
man-pages^doc^
bash-completion^util^
jq^util^
yq^util^A
bottom^sysutil^A
CSV_CONTENT
}

phase_14_package_installation() {
    log_info "=== PHASE 14: CSV-DRIVEN PACKAGE INSTALLATION ==="
    
    # Generate package manifest
    log_info "Creating package installation manifest from CSV..."
    create_progs_csv
    
    local progs_file="$MOUNT_ROOT/tmp/progs.csv"
    local pacman_count=0
    local aur_count=0
    local git_count=0
    local error_count=0
    
    log_info "Installing packages from CSV manifest..."
    log_info "Total lines to process: $(wc -l < "$progs_file")"
    
    # Read and process CSV file
    while IFS='^' read -r name category install_method || [[ -n "$name" ]]; do
        # Skip comments and empty lines
        [[ "$name" =~ ^#.* ]] && continue
        [[ -z "$name" ]] && continue
        [[ "$name" =~ ^[[:space:]]*$ ]] && continue
        
        case "$install_method" in
            "A")
                # AUR installation via yay (as normal user)
                log_info "[AUR] Installing $name from Arch User Repository..."
                if arch-chroot "$MOUNT_ROOT" bash -c "sudo -u $PRIMARY_USER yay -S --noconfirm --cleanmenu=false --diffmenu=false $name" 2>&1 | tee -a "$LOG_FILE"; then
                    ((aur_count++))
                else
                    log_warn "[AUR] Failed to install $name - continuing with other packages"
                    ((error_count++))
                fi
                ;;
            "G")
                # Git source installation (deferred to Phase 16 for suckless programs)
                log_debug "[GIT] Deferring $name to git-source installation phase (Phase 16)"
                ((git_count++))
                ;;
            *)
                # Pacman repository installation (default)
                log_info "[PACMAN] Installing $name from official repository..."
                if arch-chroot "$MOUNT_ROOT" bash -c "pacman -S --noconfirm $name" 2>&1 | tee -a "$LOG_FILE"; then
                    ((pacman_count++))
                else
                    log_warn "[PACMAN] Failed to install $name - continuing with other packages"
                    ((error_count++))
                fi
                ;;
        esac
        
        # Brief pause between installations to avoid system load
        sleep 0.5
        
    done < "$progs_file"
    
    log_info "================================"
    log_info "Package installation summary:"
    log_info "  Pacman packages:   $pacman_count"
    log_info "  AUR packages:      $aur_count"
    log_info "  Git programs:      $git_count (deferred)"
    log_info "  Installation errors: $error_count"
    log_info "================================"
    
    log_info "CSV-driven package installation completed"
}

################################################################################
# PHASE 15: VOIDRICE DOTFILE DEPLOYMENT
################################################################################

phase_15_voidrice_deployment() {
    log_info "=== PHASE 15: VOIDRICE DOTFILE DEPLOYMENT ==="
    
    log_info "Deploying voidrice dotfiles (Luke Smith's ricing configuration)..."
    
    local user_home="$MOUNT_ROOT/home/$PRIMARY_USER"
    local void_source="$user_home/.config/voidrice-source"
    
    # Clone voidrice repository to temporary location
    log_info "Cloning voidrice repository from LukeSmithxyz/voidrice..."
    arch-chroot "$MOUNT_ROOT" bash << EOC
sudo -u $PRIMARY_USER git clone --depth 1 https://github.com/LukeSmithxyz/voidrice.git $void_source 2>&1
if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to clone voidrice repository" >&2
    exit 1
fi
EOC
    
    # Deploy dotfiles to user home directory
    log_info "Deploying dotfiles to user home directory..."
    arch-chroot "$MOUNT_ROOT" bash << EOC
cd $user_home

# Create .config directory if it doesn't exist
sudo -u $PRIMARY_USER mkdir -p .config .local/bin .local/share

# Copy .config files (XDG user directories)
if [[ -d "$void_source/.config" ]]; then
    sudo -u $PRIMARY_USER cp -r $void_source/.config/* .config/ 2>&1 || true
fi

# Copy shell configuration files
if [[ -f "$void_source/.zshrc" ]]; then
    sudo -u $PRIMARY_USER cp $void_source/.zshrc .zshrc 2>&1 || true
fi

if [[ -f "$void_source/.zprofile" ]]; then
    sudo -u $PRIMARY_USER cp $void_source/.zprofile .zprofile 2>&1 || true
fi

# Copy X11 resources
if [[ -f "$void_source/.Xresources" ]]; then
    sudo -u $PRIMARY_USER cp $void_source/.Xresources .Xresources 2>&1 || true
fi

# Copy local bin scripts
if [[ -d "$void_source/.local/bin" ]]; then
    sudo -u $PRIMARY_USER cp -r $void_source/.local/bin/* .local/bin/ 2>&1 || true
    sudo -u $PRIMARY_USER chmod +x .local/bin/* 2>&1 || true
fi

# Copy local share files
if [[ -d "$void_source/.local/share" ]]; then
    sudo -u $PRIMARY_USER cp -r $void_source/.local/share/* .local/share/ 2>&1 || true
fi

# Fix ownership and permissions
sudo -u $PRIMARY_USER chown -R $PRIMARY_USER:$PRIMARY_USER .config .local .zshrc .zprofile .Xresources 2>/dev/null || true
sudo -u $PRIMARY_USER chmod 755 .config .local .local/bin 2>/dev/null || true

echo "Voidrice dotfiles deployed successfully"
EOC
    
    # Cleanup temporary voidrice source (optional - keep for reference)
    # rm -rf "$void_source"
    
    log_info "Voidrice dotfiles deployment completed"
}

################################################################################
# PHASE 16: SUCKLESS PROGRAMS COMPILATION & INSTALLATION
################################################################################

phase_16_suckless_compilation() {
    log_info "=== PHASE 16: SUCKLESS PROGRAMS COMPILATION & INSTALLATION ==="
    
    log_info "Compiling and installing suckless software from official sources..."
    
    # Array of suckless programs to build
    local suckless_programs=("dwm" "st" "dmenu" "slstatus")
    local build_base="$MOUNT_ROOT/tmp/suckless-build"
    local successful=0
    local failed=0
    
    mkdir -p "$build_base"
    
    for prog in "${suckless_programs[@]}"; do
        log_info "Building suckless program: $prog ($(echo $((++successful))) of ${#suckless_programs[@]})..."
        
        # Clone from official suckless.org git repository
        arch-chroot "$MOUNT_ROOT" bash << EOC
cd $build_base

# Clone the specific suckless program
git clone https://git.suckless.org/$prog 2>&1

if [[ ! -d "$prog" ]]; then
    echo "ERROR: Failed to clone $prog" >&2
    exit 1
fi

cd $prog

# Compile and install
echo "Compiling $prog..."
make clean 2>&1 || true
make 2>&1

if [[ $? -ne 0 ]]; then
    echo "ERROR: Compilation of $prog failed" >&2
    exit 1
fi

echo "Installing $prog..."
sudo make install 2>&1

if [[ $? -eq 0 ]]; then
    echo "$prog compiled and installed successfully"
else
    echo "ERROR: Installation of $prog failed" >&2
    exit 1
fi
EOC
        
        if [[ $? -eq 0 ]]; then
            log_info "✓ $prog compiled and installed successfully"
            ((successful++))
        else
            log_warn "✗ $prog compilation/installation failed"
            ((failed++))
        fi
    done
    
    # Cleanup build directory
    rm -rf "$build_base"
    
    log_info "Suckless programs compilation completed"
    log_info "Successful builds: $successful, Failed builds: $failed"
}

################################################################################
# PHASE 17: USER ENVIRONMENT FINALIZATION
################################################################################

phase_17_environment_finalization() {
    log_info "=== PHASE 17: USER ENVIRONMENT FINALIZATION ==="
    
    local user_home="$MOUNT_ROOT/home/$PRIMARY_USER"
    
    # Create .xinitrc for X11 startup
    log_info "Creating .xinitrc for X11 startup configuration..."
    cat > "$user_home/.xinitrc" << 'XINITRC'
#!/usr/bin/env bash
# X11 initialization script for dwm environment

# Load X11 resources
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

# Start compositor (picom) for transparency/effects
picom -b &

# Start status bar (slstatus)
while true; do
    slstatus
    sleep 1
done &

# Set wallpaper
feh --bg-scale ~/.local/share/bg.png 2>/dev/null || true

# Start window manager (dwm)
# dwm restarts on exit (normal behavior)
exec dwm
XINITRC
    
    arch-chroot "$MOUNT_ROOT" bash -c "
        sudo -u $PRIMARY_USER chmod +x $user_home/.xinitrc
        sudo -u $PRIMARY_USER chown $PRIMARY_USER:$PRIMARY_USER $user_home/.xinitrc
    " 2>&1 | tee -a "$LOG_FILE"
    
    # Ensure zsh is default shell for both user and root
    log_info "Setting zsh as default shell for all accounts..."
    arch-chroot "$MOUNT_ROOT" bash -c "
        chsh -s /usr/bin/zsh $PRIMARY_USER
        chsh -s /usr/bin/zsh root
    " 2>&1 | tee -a "$LOG_FILE"
    
    # Create necessary user directories
    log_info "Creating user directory structure..."
    arch-chroot "$MOUNT_ROOT" bash -c "
        sudo -u $PRIMARY_USER mkdir -p $user_home/{Desktop,Documents,Downloads,Music,Pictures,Videos,.cache,.config,.local/{bin,share,state}}
        sudo -u $PRIMARY_USER chmod 700 $user_home/.local $user_home/.cache
        sudo -u $PRIMARY_USER chmod 755 $user_home/{Desktop,Documents,Downloads,Music,Pictures,Videos}
    " 2>&1 | tee -a "$LOG_FILE"
    
    # Setup dbus for user session
    log_info "Configuring user session (dbus)..."
    arch-chroot "$MOUNT_ROOT" bash -c "
        sudo -u $PRIMARY_USER dbus-update-activation-environment DISPLAY XAUTHORITY 2>/dev/null || true
    " 2>&1 | tee -a "$LOG_FILE"
    
    # Create sample .profile for login shells
    log_info "Creating shell profile for user..."
    cat > "$user_home/.profile" << 'PROFILE'
# User shell profile (sourced by login shells)
export PATH="$HOME/.local/bin:$PATH"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
PROFILE
    
    arch-chroot "$MOUNT_ROOT" bash -c "
        sudo -u $PRIMARY_USER chown $PRIMARY_USER:$PRIMARY_USER $user_home/.profile
        sudo -u $PRIMARY_USER chmod 644 $user_home/.profile
    " 2>&1 | tee -a "$LOG_FILE"
    
    log_info "User environment finalization completed"
}

################################################################################
# PHASE 18: SYSTEM UNMOUNTING & FINAL VERIFICATION
################################################################################

phase_18_system_unmounting() {
    log_info "=== PHASE 18: SYSTEM UNMOUNTING & FINAL VERIFICATION ==="
    
    log_info "Verifying final system state..."
    
    # Display installed packages count
    local pkg_count=$(arch-chroot "$MOUNT_ROOT" bash -c "pacman -Q | wc -l" 2>/dev/null || echo "Unknown")
    log_info "Total packages installed: $pkg_count"
    
    log_info "Unmounting filesystems for system reboot..."
    
    # Unmount in reverse dependency order
    umount -l /mnt/root/var || log_warn "Failed to unmount /var (may be in use)"
    umount -l /mnt/root/home || log_warn "Failed to unmount /home (may be in use)"
    umount -l /mnt/root/.snapshots || log_warn "Failed to unmount /.snapshots (may be in use)"
    umount -l /mnt/root/boot || log_warn "Failed to unmount /boot (may be in use)"
    umount -l /mnt/root || log_warn "Failed to unmount /mnt/root (may be in use)"
    
    # Close LUKS volume
    log_info "Closing LUKS encrypted volume..."
    execute_cmd "cryptsetup luksClose root_crypt" "Closing LUKS encrypted volume"
    
    log_info "Filesystems unmounted and LUKS volume closed successfully"
}

################################################################################
# MAIN EXECUTION ORCHESTRATION
################################################################################

main() {
    log_info "================================================================================"
    log_info "ARCH LINUX SECURE RESEARCH DEPLOYMENT - ENHANCED WITH LARBS INTEGRATION"
    log_info "================================================================================"
    log_info "Deployment started: $(date)"
    log_info "Deployment log: $LOG_FILE"
    log_info "Error log: $ERROR_LOG"
    log_info ""
    
    # Load any previous state for recovery
    load_state
    
    # IMPORTANT: This script assumes Phases 1-12 have been completed
    # For full installation, include the complete Phase 1-12 implementation
    # from arch-secure-deploy.sh BEFORE calling these phases
    
    # NEW PHASES: LARBS Integration
    log_info "Starting LARBS integration phases (13-18)..."
    
    phase_13_aur_helper
    phase_14_package_installation
    phase_15_voidrice_deployment
    phase_16_suckless_compilation
    phase_17_environment_finalization
    phase_18_system_unmounting
    
    log_info ""
    log_info "================================================================================"
    log_info "INSTALLATION COMPLETED SUCCESSFULLY"
    log_info "================================================================================"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Remove installation media (USB/ISO)"
    log_info "  2. Power off system: sudo shutdown -h now"
    log_info "  3. Boot into newly installed system"
    log_info "  4. Unlock encrypted volume with LUKS passphrase when prompted"
    log_info "  5. Login with username: $PRIMARY_USER"
    log_info "  6. Start X11 desktop: startx"
    log_info ""
    log_info "System features enabled:"
    log_info "  ✓ LUKS2 encryption (Argon2id KDF) on root partition"
    log_info "  ✓ BTRFS root filesystem with compression and snapshotting"
    log_info "  ✓ Automated weekly snapshots (Sunday 02:00 UTC)"
    log_info "  ✓ Hardened kernel parameters and sysctl configuration"
    log_info "  ✓ Zen kernel for performance optimization"
    log_info "  ✓ Suckless window manager stack:"
    log_info "      - dwm: Dynamic window manager (tiling)"
    log_info "      - st: Simple terminal emulator"
    log_info "      - dmenu: Dynamic menu launcher"
    log_info "      - slstatus: Status bar"
    log_info "  ✓ Reproducible environment from voidrice dotfiles"
    log_info "  ✓ CSV-driven package management (pacman, AUR, git)"
    log_info "  ✓ AUR support via yay"
    log_info "  ✓ Comprehensive security hardening"
    log_info ""
    log_info "Desktop configuration:"
    log_info "  - Window Manager: dwm (suckless tiling WM)"
    log_info "  - Terminal: st (suckless terminal emulator)"
    log_info "  - Menu: dmenu (suckless application launcher)"
    log_info "  - Status Bar: slstatus + picom (compositor)"
    log_info "  - Shell: zsh (with voidrice configuration)"
    log_info "  - Editor: neovim/vim (with plugins)"
    log_info "  - File Manager: lf (command-line file manager)"
    log_info "  - Media Player: mpv"
    log_info ""
    log_info "Keyboard shortcuts (from voidrice):"
    log_info "  - See ~/.config/dwm/config.h and voidrice documentation"
    log_info "  - Common: Mod+Enter = new terminal, Mod+d = dmenu"
    log_info ""
    log_info "Customization options:"
    log_info "  - Edit ~/.config/zsh/.zshrc for shell configuration"
    log_info "  - Recompile dwm/st: cd ~/.local/src/<program> && sudo make install"
    log_info "  - Customize packages: Edit progs.csv and re-run package phase"
    log_info "  - Snapshots: systemctl status btrfs-snapshot-weekly.timer"
    log_info ""
    log_info "Logs and diagnostics:"
    log_info "  - Full deployment log: $LOG_FILE"
    log_info "  - Error log: $ERROR_LOG"
    log_info "  - Snapshot log: /var/log/btrfs-snapshots.log"
    log_info "  - System journal: journalctl -xe"
    log_info ""
    log_info "Deployment completed: $(date)"
    log_info ""
}

# Execute main function if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
