# PARSS TUI (Text User Interface) Guide

## Overview

PARSS now features a **persistent TUI interface** that captures and displays all terminal output in real-time, providing a professional installer experience similar to archinstall.

---

## Features

### ✅ **Persistent Interface**
- TUI stays open throughout installation
- Live log viewer with auto-scrolling
- Real-time output capture

### ✅ **Dual Tool Support**
- **Primary:** `dialog` (preferred - more features)
- **Fallback:** `whiptail` (if dialog unavailable)
- Auto-installation if neither present

### ✅ **Black Background + Cyan Accents**
- OLED-friendly black background
- Bright cyan borders and highlights
- High contrast white text
- Professional appearance

### ✅ **Output Capture**
- All command output displayed in TUI
- Simultaneous logging to files
- Live progress indicators
- Success/failure messages

---

## Architecture

### Global Variables
```bash
TUI_AVAILABLE=false      # Is TUI enabled?
TUI_USE_DIALOG=false     # Using dialog (true) or whiptail (false)?
TUI_OUTPUT_FILE          # Captures command output
TUI_STATUS_FILE          # Current operation status
TUI_LOG_VIEWER_PID       # Background log viewer process
```

### Initialization
```bash
init_tui()               # Detect/install dialog, configure colors
cleanup_tui()            # Clean up temporary files
```

---

## Core Functions

### 1. **Execute with Live Output (Recommended)**
```bash
tui_exec_with_progress "Phase Title" "Description" command args

# Example:
tui_exec_with_progress "Phase 6" "Installing base system" \
    pacstrap -K /mnt base linux linux-firmware
```

**What it does:**
- Shows live command output in a dialog progressbox
- User sees every line as it executes
- Progress indicator (for whiptail)
- Returns command exit code

**Visual (with dialog):**
```
┌────────────────────────────────────────────┐
│ Phase 6                                    │
├────────────────────────────────────────────┤
│ Installing base system                     │
│                                            │
│ resolving dependencies...                  │
│ looking for conflicting packages...        │
│ downloading packages...                    │
│ installing packages...                     │
│ (100%) base-3.0-1.pkg.tar.zst             │
│ ...                                        │
│                                            │
│ [OK]  [Cancel]                             │
└────────────────────────────────────────────┘
```

---

### 2. **Execute with Output Capture**
```bash
tui_exec "Phase Title" "Description" command args

# Example:
tui_exec "Phase 8" "Installing GRUB" \
    grub-install --target=x86_64-efi --efi-directory=/boot
```

**What it does:**
- Executes command
- Captures output to `$TUI_OUTPUT_FILE`
- Adds formatted header/footer
- Logs success/failure
- Good for commands that don't need live display

---

### 3. **Persistent Log Viewer**
```bash
tui_show_log_viewer "Installation Progress" 20 78

# Do work... output appears in real-time

tui_close_log_viewer
```

**What it does:**
- Opens background log viewer (tailboxbg with dialog)
- Automatically scrolls as new output appears
- Stays open until closed
- Perfect for long-running phases

**Visual:**
```
┌────────────────────────────────────────────┐
│ Installation Progress                      │
├────────────────────────────────────────────┤
│                                            │
│ [Phase 3] Wiping disk signatures          │
│ Command: wipefs -af /dev/nvme0n1           │
│ /dev/nvme0n1: 8 bytes were erased...       │
│ [✓] Success: Wiping disk                  │
│                                            │
│ [Phase 3] Creating GPT partition table    │
│ Command: parted -s /dev/nvme0n1 mklabel... │
│ Information: You may need to update...     │
│ [✓] Success: Creating partition table     │
│                                            │
│ ...                                        │
└────────────────────────────────────────────┘
```

---

### 4. **Status Updates**
```bash
tui_update_status "Phase 6" "Installing 45/78 packages"
```

**What it does:**
- Updates `$TUI_STATUS_FILE`
- Can be read by monitoring scripts
- Good for status bars

---

### 5. **Info Boxes (Non-blocking)**
```bash
tui_info "Phase 6" "Installing base system packages..."

# Example:
tui_info "PARSS - Base Installation" \
    "Installing base system (30 packages)\n\nETA: 5-15 minutes"
```

**What it does:**
- Shows brief message
- Disappears automatically or after timeout
- Also logs to `$TUI_OUTPUT_FILE`
- Good for status updates

---

### 6. **Message Boxes (Requires OK)**
```bash
tui_msgbox "Title" "Message" height width

# Example:
tui_msgbox "Installation Complete" \
    "Base system installed successfully!\n\nPress OK to continue." 10 60
```

**What it does:**
- Shows message
- Waits for user to press OK
- Good for important notifications

---

### 7. **Yes/No Dialogs**
```bash
if tui_yesno "Confirm" "Proceed with installation?" 10 60; then
    # User chose Yes
else
    # User chose No
fi
```

**What it does:**
- Shows Yes/No dialog
- Returns 0 for Yes, 1 for No
- Good for confirmations

---

## Color Configuration

### Dialog (DIALOGRC)
```bash
# Auto-generated at /tmp/parss-dialogrc-$$
screen_color = (WHITE,BLACK,OFF)
dialog_color = (WHITE,BLACK,OFF)
title_color = (BRIGHTWHITE,BLACK,ON)
border_color = (BRIGHTCYAN,BLACK,ON)
button_active_color = (WHITE,CYAN,ON)
gauge_color = (WHITE,CYAN,ON)
# ... and more
```

### Whiptail (NEWT_COLORS)
```bash
export NEWT_COLORS="
root=white,black
window=white,black
border=brightcyan,black
title=brightwhite,black
button=black,cyan
actbutton=white,cyan
# ... and more
"
```

---

## Usage Patterns

### Pattern 1: Long-Running Command
```bash
phase_6_base_installation() {
    tui_phase_start "6" "Base Installation" \
        "Installing core Arch Linux system (5-15 minutes)"
    
    # Show live output as it happens
    tui_exec_with_progress "Base System" "Installing packages" \
        pacstrap -K /mnt base linux linux-firmware btrfs-progs ...
    
    log_success "Base system installed"
}
```

### Pattern 2: Multiple Commands with Progress
```bash
phase_8_chroot_configuration() {
    tui_phase_start "8" "Bootloader Setup" \
        "Configuring mkinitcpio and GRUB"
    
    # Start log viewer in background
    tui_show_log_viewer "GRUB Installation" 20 78
    
    # Multiple commands - output appears in log viewer
    tui_exec "GRUB" "Installing GRUB" \
        grub-install --target=x86_64-efi ...
    
    tui_exec "GRUB" "Generating config" \
        grub-mkconfig -o /boot/grub/grub.cfg
    
    # Close log viewer
    tui_close_log_viewer
    
    log_success "Bootloader configured"
}
```

### Pattern 3: Package Installation with Counter
```bash
total=78
n=0

while IFS=, read -r tag prog comment; do
    n=$((n + 1))
    
    # Show progress
    tui_info "Package Installation" \
        "[$n/$total] Installing: $prog"
    
    # Execute
    pacman -S "$prog" 2>&1 | tee -a "$TUI_OUTPUT_FILE"
done < progs.csv
```

---

## Benefits

### ✅ **User Experience**
- Never wonder if it's frozen
- See exactly what's happening
- Professional installer appearance
- Familiar to archinstall users

### ✅ **Debugging**
- All output captured
- Easy to see what failed
- Timestamps and context
- Full command history

### ✅ **Flexibility**
- Works with or without TUI
- Graceful fallback to text
- Verbose logging preserved
- Console output always available

---

## Migration Guide

### Old Way (Brief Popups)
```bash
if [[ "$TUI_AVAILABLE" == "true" ]]; then
    whiptail --title "Installing" --infobox "Please wait..." 8 70
fi
pacstrap -K /mnt base linux
```

**Problem:** User sees "Please wait..." for 10 minutes with no activity

### New Way (Live Output)
```bash
tui_exec_with_progress "Base Installation" \
    "Installing packages (this may take 5-15 minutes)" \
    pacstrap -K /mnt base linux
```

**Solution:** User sees live output, knows it's working, can see progress

---

## Example: Full Phase with TUI

```bash
phase_example() {
    # 1. Show phase start notification
    tui_phase_start "X" "Example Phase" "Doing important work"
    
    # 2. Option A: Single long command with live output
    tui_exec_with_progress "Step 1" "Running long command" \
        some_long_command --with args
    
    # 3. Option B: Multiple commands with persistent viewer
    tui_show_log_viewer "Example Progress" 20 78
    
    tui_exec "Step 2" "First task" command1
    tui_exec "Step 3" "Second task" command2
    tui_exec "Step 4" "Third task" command3
    
    tui_close_log_viewer
    
    # 4. Confirm completion
    tui_msgbox "Success" "Phase completed successfully!" 8 60
    
    log_success "Phase X completed"
}
```

---

## Testing

### Test TUI Availability
```bash
if [[ "$TUI_AVAILABLE" == "true" ]]; then
    echo "TUI enabled using: $([ "$TUI_USE_DIALOG" == "true" ] && echo "dialog" || echo "whiptail")"
else
    echo "TUI not available, using text-only mode"
fi
```

### Test Live Output
```bash
tui_exec_with_progress "Test" "Counting" \
    bash -c 'for i in {1..10}; do echo "Count: $i"; sleep 1; done'
```

### Test Log Viewer
```bash
tui_show_log_viewer "Test Viewer" 15 70 &
for i in {1..20}; do
    echo "Test line $i" >> "$TUI_OUTPUT_FILE"
    sleep 0.5
done
tui_close_log_viewer
```

---

## Troubleshooting

### TUI not appearing?
```bash
# Check if dialog/whiptail installed
command -v dialog || command -v whiptail

# Check TUI_AVAILABLE flag
echo "$TUI_AVAILABLE"

# Install manually if needed
pacman -S dialog
```

### Output not showing in TUI?
```bash
# Ensure you're using tui_exec or tui_exec_with_progress
# Regular commands won't appear in TUI automatically

# Check output file
tail -f "$TUI_OUTPUT_FILE"
```

### Colors not working?
```bash
# Check DIALOGRC or NEWT_COLORS
echo "$DIALOGRC"
cat "$DIALOGRC"

echo "$NEWT_COLORS"
```

---

## Best Practices

1. **Use `tui_exec_with_progress` for long commands** (>30 seconds)
2. **Use `tui_exec` for quick commands** you want logged
3. **Use persistent log viewer** for phases with many commands
4. **Always call `cleanup_tui()`** at script end
5. **Update status** during long operations for monitoring
6. **Test fallback** to ensure text-only mode works

---

## Future Enhancements

- [ ] Split-pane view (log + progress)
- [ ] Real-time system stats (CPU, RAM, disk)
- [ ] ETA calculations for known operations
- [ ] Color-coded output (errors in red, success in green)
- [ ] Interactive menu for phase selection

---

**Your PARSS installer now has enterprise-grade TUI! 🎉**
