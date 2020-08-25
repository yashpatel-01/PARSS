#!/usr/bin/env bash
set -euo pipefail

# PARSS BTRFS Dashboard
# Quick overview of encrypted BTRFS layout, usage, and snapshots.

echo "=== PARSS BTRFS Dashboard ==="
echo "Host: $(hostname)"
echo "Date: $(date)"
echo ""

echo "[1] Block devices and mappings (lsblk)"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS

echo ""
echo "[2] BTRFS filesystems (btrfs filesystem show)"
if command -v btrfs &>/dev/null; then
    btrfs filesystem show 2>/dev/null || echo "  No BTRFS filesystems detected."
else
    echo "  btrfs command not available."
fi

echo ""
echo "[3] Root filesystem usage (btrfs filesystem usage /)"
if command -v btrfs &>/dev/null; then
    btrfs filesystem usage / --human-readable 2>/dev/null | head -n 20 || echo "  Not a BTRFS root or cannot read usage."
else
    df -h /
fi

echo ""
echo "[4] BTRFS subvolumes on / (btrfs subvolume list /)"
if command -v btrfs &>/dev/null; then
    btrfs subvolume list / 2>/dev/null || echo "  No subvolumes or not a BTRFS root."
else
    echo "  btrfs command not available."
fi

echo ""
echo "[5] Snapshots under /.snapshots"
if [[ -d /.snapshots ]]; then
    if command -v btrfs &>/dev/null; then
        btrfs subvolume list /.snapshots 2>/dev/null || echo "  No snapshots found under /.snapshots."
    else
        echo "  btrfs command not available."
    fi
else
    echo "  /.snapshots directory not found."
fi

echo ""
echo "[6] Mounts for BTRFS root and subvolumes"
mount | grep btrfs || echo "  No BTRFS mounts found."

echo ""
echo "Done."
