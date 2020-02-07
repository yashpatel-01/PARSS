#!/usr/bin/env bash
set -euo pipefail

# Integrity Check Script (AIDE wrapper)
# Usage: ./integrity-check.sh

if ! command -v aide &>/dev/null; then
    echo "AIDE is not installed. Installing..."
    sudo pacman -S --noconfirm aide
    echo "Initializing AIDE database (this may take a while)..."
    sudo aide --init
    sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
    echo "AIDE initialized."
    exit 0
fi

echo "Running AIDE integrity check..."
if sudo aide --check; then
    echo "System integrity verified: No changes detected."
else
    echo "WARNING: Changes detected in filesystem!"
    echo "Check /var/log/aide.log for details."
    exit 1
fi
