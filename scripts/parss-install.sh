#!/usr/bin/env bash
set -euo pipefail

# parss-install: helper to install packages AND record them in archrice/progs.csv
# Usage examples:
#   parss-install p neovim "Neovim text editor"
#   parss-install a librewolf-bin "Librewolf browser"
#   parss-install g https://github.com/you/yourtool.git "Custom tool"

info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

ARCHRICE_DIR="${ARCHRICE_DIR:-$HOME/.local/src/archrice}"
PROGS_FILE="${PROGS_FILE:-$ARCHRICE_DIR/progs.csv}"
AUR_HELPER="${AUR_HELPER:-yay}"

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || error "Missing required command: $cmd"
}

ensure_progs_file() {
    if [[ -f "$PROGS_FILE" ]]; then
        return 0
    fi
    mkdir -p "$(dirname "$PROGS_FILE")"
    info "Creating new progs.csv at $PROGS_FILE"
    echo '#TAG,NAME IN REPO (or git url),PURPOSE (should be a verb phrase to sound right while installing)' > "$PROGS_FILE"
}

append_entry() {
    local tag="$1" name="$2" comment="$3"
    # Note: empty tag becomes leading comma.
    echo "${tag},${name},\"${comment}\"" >> "$PROGS_FILE"
}

install_pacman() {
    local pkg="$1"
    require_cmd sudo
    require_cmd pacman
    info "Installing $pkg via pacman"
    sudo pacman --noconfirm --needed -S "$pkg" || warn "Failed to install $pkg via pacman"
}

install_aur() {
    local pkg="$1"
    local helper="$AUR_HELPER"
    if ! command -v "$helper" >/dev/null 2>&1; then
        warn "AUR helper '$helper' not found; skipping install of $pkg."
        return 1
    fi
    info "Installing $pkg via AUR helper $helper"
    "$helper" --noconfirm --needed -S "$pkg" || warn "Failed to install $pkg via AUR ($helper)"
}

install_git() {
    local url="$1"
    local repodir="$HOME/.local/src"
    mkdir -p "$repodir"

    local name="${url##*/}"
    name="${name%.git}"
    local dir="$repodir/$name"

    if [[ -d "$dir/.git" ]]; then
        info "Updating existing git repo $url in $dir"
        git -C "$dir" pull --ff-only || warn "Failed to update $url; using existing copy."
    else
        info "Cloning $url into $dir"
        git clone --depth 1 "$url" "$dir" || { warn "Clone failed for $url"; return 1; }
    fi

    info "Building and installing from $dir"
    ( cd "$dir" && make && sudo make install ) || warn "Build/install failed for $url"
}

usage() {
    cat <<EOF
Usage: parss-install <mode> <name-or-url> [comment...]

Modes:
  p, pacman   Install pacman package      (CSV tag: "")
  a, aur      Install AUR package        (CSV tag: "A")
  g, git      Install from git + make    (CSV tag: "G")

Examples:
  parss-install p neovim "Neovim text editor"
  parss-install a librewolf-bin "Librewolf browser"
  parss-install g https://github.com/you/yourtool.git "Custom tool"
EOF
    exit 1
}

main() {
    if [[ $# -lt 2 ]]; then
        usage
    fi

    local mode="$1"; shift
    local name="$1"; shift
    local comment
    if [[ $# -gt 0 ]]; then
        comment="$*"
    else
        comment="installed via parss-install"
    fi

    local tag="" installer="install_pacman"
    case "$mode" in
        p|pacman)
            tag=""
            installer="install_pacman"
            ;;
        a|aur)
            tag="A"
            installer="install_aur"
            ;;
        g|git)
            tag="G"
            installer="install_git"
            ;;
        *)
            error "Unknown mode: $mode"
            ;;
    esac

    ensure_progs_file
    append_entry "$tag" "$name" "$comment"

    # Perform the actual installation. Even if it fails, the CSV still records intent.
    "$installer" "$name" || true

    info "Recorded in progs.csv: tag='${tag:-<empty>}' name='$name' comment='$comment'"
}

main "$@"
