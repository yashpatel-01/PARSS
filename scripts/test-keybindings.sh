#!/usr/bin/env bash
# Test script for LARBS keybindings and shortcuts in PARSS setup

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass=0
fail=0
warn=0

check() {
    local test_name="$1"
    local command="$2"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((pass++))
    else
        echo -e "${RED}✗${NC} $test_name"
        ((fail++))
    fi
}

check_file() {
    local test_name="$1"
    local file_path="$2"
    
    if [[ -f "$file_path" ]] || [[ -L "$file_path" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((pass++))
    else
        echo -e "${RED}✗${NC} $test_name (not found: $file_path)"
        ((fail++))
    fi
}

check_command() {
    local test_name="$1"
    local cmd="$2"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((pass++))
    else
        echo -e "${RED}✗${NC} $test_name (command not found: $cmd)"
        ((fail++))
    fi
}

check_alias() {
    local test_name="$1"
    local alias_name="$2"
    
    if alias "$alias_name" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((pass++))
    else
        echo -e "${RED}✗${NC} $test_name (alias not set: $alias_name)"
        ((fail++))
    fi
}

echo "==============================================="
echo "PARSS/LARBS Keybindings & Setup Test"
echo "==============================================="
echo

echo "--- Essential Programs ---"
check_command "Terminal (st)" "st"
check_command "Window Manager (dwm)" "dwm"
check_command "Status Bar (dwmblocks)" "dwmblocks"
check_command "Menu (dmenu)" "dmenu"
check_command "File Manager (lf)" "lf"
check_command "Text Editor (nvim)" "nvim"
check_command "Browser (librewolf)" "librewolf"
check_command "PDF Viewer (zathura)" "zathura"
check_command "Image Viewer (nsxiv)" "nsxiv"
check_command "Music Player (ncmpcpp)" "ncmpcpp"
check_command "Music Daemon (mpd)" "mpd"
check_command "Music Control (mpc)" "mpc"
check_command "RSS Reader (newsboat)" "newsboat"
check_command "Image Previews (ueberzugpp)" "ueberzugpp"
echo

echo "--- Core Scripts ---"
check_file "shortcuts generator" "$HOME/.local/bin/shortcuts"
check_file "link handler" "$HOME/.local/bin/linkhandler"
check_file "dmenu record" "$HOME/.local/bin/dmenurecord"
check_file "screenshot picker" "$HOME/.local/bin/maimpick"
check_file "display select" "$HOME/.local/bin/displayselect"
check_file "mounter" "$HOME/.local/bin/mounter"
check_file "unmounter" "$HOME/.local/bin/unmounter"
check_file "system actions" "$HOME/.local/bin/sysact"
check_file "lf with ueberzug" "$HOME/.local/bin/lfub"
check_file "remaps" "$HOME/.local/bin/remaps"
echo

echo "--- Config Files ---"
check_file "zshrc" "$HOME/.config/zsh/.zshrc"
check_file "aliasrc" "$HOME/.config/shell/aliasrc"
check_file "profile" "$HOME/.config/shell/profile"
check_file "lf config" "$HOME/.config/lf/lfrc"
check_file "nvim config" "$HOME/.config/nvim/init.vim"
check_file "X11 xinitrc" "$HOME/.config/x11/xinitrc"
check_file "X11 xprofile" "$HOME/.config/x11/xprofile"
check_file "dunst config" "$HOME/.config/dunst/dunstrc"
check_file "mpd config" "$HOME/.config/mpd/mpd.conf"
check_file "ncmpcpp config" "$HOME/.config/ncmpcpp/config"
check_file "newsboat config" "$HOME/.config/newsboat/config"
check_file "zathura config" "$HOME/.config/zathura/zathurarc"
echo

echo "--- Shell Integration ---"
# Need to source the files first
if [[ -f "$HOME/.config/shell/aliasrc" ]]; then
    source "$HOME/.config/shell/aliasrc" 2>/dev/null || true
    check_alias "Alias: cp -iv" "cp"
    check_alias "Alias: mv -iv" "mv"
    check_alias "Alias: rm -vI" "rm"
    check_alias "Alias: ls colors" "ls"
    check_alias "Alias: grep colors" "grep"
    check_alias "Alias: killall (ka)" "ka"
    check_alias "Alias: git (g)" "g"
    check_alias "Alias: editor (v)" "v"
    check_alias "Alias: yt-dlp (yt)" "yt"
else
    echo -e "${RED}✗${NC} Cannot test aliases (aliasrc not found)"
    ((fail+=9))
fi
echo

echo "--- Shortcuts Generated ---"
if [[ -f "$HOME/.local/bin/shortcuts" ]] && [[ -x "$HOME/.local/bin/shortcuts" ]]; then
    if "$HOME/.local/bin/shortcuts" >/dev/null 2>&1; then
        check_file "Shell shortcuts" "$HOME/.config/shell/shortcutrc"
        check_file "Shell env shortcuts" "$HOME/.config/shell/shortcutenvrc"
        check_file "Zsh named dirs" "$HOME/.config/shell/zshnameddirrc"
        check_file "LF shortcuts" "$HOME/.config/lf/shortcutrc"
    else
        echo -e "${YELLOW}⚠${NC} shortcuts command exists but failed to run"
        ((warn++))
    fi
else
    echo -e "${RED}✗${NC} shortcuts command not found or not executable"
    ((fail++))
fi
echo

echo "--- Bookmarks (for shortcuts) ---"
check_file "Directory bookmarks" "$HOME/.config/shell/bm-dirs"
check_file "File bookmarks" "$HOME/.config/shell/bm-files"
echo

echo "--- Environment Variables ---"
[[ -n "${EDITOR:-}" ]] && echo -e "${GREEN}✓${NC} \$EDITOR set to: $EDITOR" && ((pass++)) || { echo -e "${RED}✗${NC} \$EDITOR not set"; ((fail++)); }
[[ -n "${TERMINAL:-}" ]] && echo -e "${GREEN}✓${NC} \$TERMINAL set to: $TERMINAL" && ((pass++)) || { echo -e "${RED}✗${NC} \$TERMINAL not set"; ((fail++)); }
[[ -n "${BROWSER:-}" ]] && echo -e "${GREEN}✓${NC} \$BROWSER set to: $BROWSER" && ((pass++)) || { echo -e "${RED}✗${NC} \$BROWSER not set"; ((fail++)); }
[[ -n "${READER:-}" ]] && echo -e "${GREEN}✓${NC} \$READER set to: $READER" && ((pass++)) || { echo -e "${RED}✗${NC} \$READER not set"; ((fail++)); }
[[ -n "${FILE:-}" ]] && echo -e "${GREEN}✓${NC} \$FILE set to: $FILE" && ((pass++)) || { echo -e "${RED}✗${NC} \$FILE not set"; ((fail++)); }
echo

echo "--- X11 Setup ---"
check_file "Xresources" "$HOME/.config/x11/xresources"
check_file "Xdefaults link" "$HOME/.Xdefaults"
check_file "xinitrc link" "$HOME/.xinitrc"
echo

echo "--- DWM Source (for keybinding customization) ---"
if [[ -d "$HOME/.local/src/dwm" ]]; then
    check_file "dwm config.h" "$HOME/.local/src/dwm/config.h"
    check_file "dwm Makefile" "$HOME/.local/src/dwm/Makefile"
else
    echo -e "${RED}✗${NC} dwm source not found in ~/.local/src/dwm"
    ((fail+=2))
fi
echo

echo "==============================================="
echo "Test Summary:"
echo "==============================================="
echo -e "${GREEN}Passed:${NC} $pass"
echo -e "${RED}Failed:${NC} $fail"
echo -e "${YELLOW}Warnings:${NC} $warn"
echo

if [[ $fail -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical tests passed!${NC}"
    echo
    echo "Your PARSS/LARBS setup is complete."
    echo "Press Mod+F1 in dwm to see the keybindings guide."
    exit 0
else
    echo -e "${RED}✗ Some tests failed.${NC}"
    echo
    echo "Common issues:"
    echo "  1. Run 'ref' in your shell to reload shortcuts"
    echo "  2. Ensure you ran the shortcuts command: ~/.local/bin/shortcuts"
    echo "  3. Check that dwm, st, dmenu were compiled from source"
    echo "  4. Verify archrice dotfiles were deployed correctly"
    exit 1
fi
