#!/usr/bin/env bash
set -euo pipefail

# PARSS Control Panel (TUI)
# Simple menu wrapper around common PARSS scripts so you don't have to
# remember individual script names.

PARSS_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSS_ROOT_DIR="$(cd "${PARSS_SCRIPTS_DIR}/.." && pwd)"

info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

ensure_package() {
    # Best-effort auto-install for simple dependencies like dialog.
    # If installation fails, caller should gracefully fall back.
    local pkg="$1"

    if command -v "$pkg" >/dev/null 2>&1; then
        return 0
    fi

    if ! command -v pacman >/dev/null 2>&1 || ! command -v sudo >/dev/null 2>&1; then
        warn "Cannot auto-install $pkg (pacman/sudo not available)."
        return 1
    fi

    info "Attempting to install missing package: $pkg"
    if sudo pacman --noconfirm --needed -S "$pkg" >/dev/null 2>&1; then
        info "Installed $pkg successfully."
        return 0
    else
        warn "Failed to install $pkg automatically."
        return 1
    fi
}

run_script() {
    local script_name="$1"
    local description="$2"
    local path="${PARSS_SCRIPTS_DIR}/${script_name}"

    if [[ ! -f "$path" ]]; then
        error "Script '$script_name' not found in ${PARSS_SCRIPTS_DIR} (${description})."
    fi

    if [[ ! -x "$path" ]]; then
        chmod +x "$path" 2>/dev/null || warn "Could not make $script_name executable; attempting to run anyway."
    fi

    info "Running: $description"
    "$path"
}

view_manual() {
    local manual="${PARSS_ROOT_DIR}/docs/PARSS-MANUAL.md"
    if [[ ! -f "$manual" ]]; then
        warn "PARSS manual not found at $manual."
        return 1
    fi

    local pager="${PAGER:-less}"
    "$pager" "$manual"
}

menu_dialog() {
    while true; do
        local choice

        # Prefer dialog if available; try to install it once if missing.
        if ! command -v dialog >/dev/null 2>&1; then
            ensure_package dialog || true
        fi

        if command -v dialog >/dev/null 2>&1; then
            choice=$(dialog \
                --clear \
                --stdout \
                --backtitle "PARSS Control Panel" \
                --title "PARSS Control Panel" \
                --menu "Choose an action:" 20 72 10 \
                1 "Desktop setup (archrice + progs.csv)" \
                2 "HiDPI/4K font configuration" \
                3 "System health dashboard" \
                4 "Filesystem integrity check (AIDE)" \
                5 "BTRFS layout dashboard" \
                6 "View PARSS manual" \
                7 "Exit") || return 0
        else
            echo
            echo "=== PARSS Control Panel ==="
            echo "1) Desktop setup (archrice + progs.csv)"
            echo "2) HiDPI/4K font configuration"
            echo "3) System health dashboard"
            echo "4) Filesystem integrity check (AIDE)"
            echo "5) BTRFS layout dashboard"
            echo "6) View PARSS manual"
            echo "7) Exit"
            echo
            read -rp "Select an option [1-7]: " choice || return 0
        fi

        case "${choice:-}" in
            1)
                run_script "desktop-setup.sh" "Desktop setup (archrice + progs.csv)"
                ;;
            2)
                run_script "setup-hidpi-final.sh" "HiDPI/4K font configuration"
                ;;
            3)
                run_script "system-health.sh" "System health dashboard"
                ;;
            4)
                run_script "integrity-check.sh" "Filesystem integrity check (AIDE)"
                ;;
            5)
                run_script "btrfs-dashboard.sh" "BTRFS layout dashboard"
                ;;
            6)
                view_manual
                ;;
            7|"" )
                info "Exiting PARSS Control Panel."
                return 0
                ;;
            *)
                warn "Invalid selection: ${choice}"
                ;;
        esac
    done
}

main() {
    menu_dialog
}

main "$@"
