#!/usr/bin/env bash
set -euo pipefail

# System Health Check Dashboard
# Usage: ./system-health.sh

echo "=== PAASS System Health ==="
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
echo "Health check complete."
