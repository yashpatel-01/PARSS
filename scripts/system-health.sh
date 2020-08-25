#!/usr/bin/env bash
set -euo pipefail

# System Health Check Dashboard
# Usage: ./system-health.sh

echo "=== PARSS System Health ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo ""

echo "[1] Service Status"
services=("NetworkManager" "tor" "apparmor" "nftables" "btrfs-snapshot-weekly.timer")
for svc in "${services[@]}"; do
    if systemctl is-active --quiet "$svc"; then
        echo "  [✓] $svc is running"
    else
        echo "  [✗] $svc is INACTIVE"
    fi
done

echo ""
echo "[2] Security Status"
if [[ -d /sys/kernel/security/apparmor ]]; then
    echo "  [✓] AppArmor loaded"
else
    echo "  [✗] AppArmor NOT loaded"
fi

echo ""
echo "[3] Disk Usage (BTRFS)"
btrfs filesystem usage / --human-readable | head -n 5

echo ""
echo "[4] Snapshot Status"
count=$(btrfs subvolume list /.snapshots 2>/dev/null | wc -l || echo 0)
echo "  Total snapshots: $count"

echo ""
echo "[5] LUKS / crypttab / GRUB"

if [[ -f /etc/crypttab ]]; then
    echo "  /etc/crypttab present:"
    grep -vE '^(#|$)' /etc/crypttab || echo "  (no active entries)"
else
    echo "  [✗] /etc/crypttab missing"
fi

if [[ -f /etc/default/grub ]]; then
    if grep -q "cryptdevice=" /etc/default/grub; then
        echo "  [✓] GRUB_CMDLINE_LINUX contains cryptdevice=..."
    else
        echo "  [✗] cryptdevice= parameter missing from /etc/default/grub"
    fi
else
    echo "  [✗] /etc/default/grub missing"
fi

if command -v cryptsetup &>/dev/null; then
    echo ""
    echo "  LUKS root/home status (via cryptsetup status):"
    while read -r name _; do
        [[ -z "$name" ]] && continue
        if cryptsetup status "$name" &>/dev/null; then
            echo "    [✓] $name: active"
        fi
    done < <(grep -vE '^(#|$)' /etc/crypttab 2>/dev/null || true)
fi

echo ""
echo "[6] BTRFS subvolume layout"
if command -v btrfs &>/dev/null; then
    btrfs subvolume list / 2>/dev/null | sed -n '1,12p' || echo "  (no subvolumes or not BTRFS root)"
else
    echo "  btrfs command not available"
fi

echo ""
echo "Health check complete."
