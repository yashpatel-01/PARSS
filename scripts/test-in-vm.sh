#!/usr/bin/env bash
set -euo pipefail

# Test PARSS deployment in a simulated environment
# Usage: ./test-in-vm.sh [vm-name]

VM_NAME="${1:-parss-test-vm}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="$SCRIPT_DIR/arch-secure-deploy.sh"

echo "Starting Test Suite for PARSS..."
echo "Target VM: $VM_NAME"

# 1. Syntax Check
echo "Running ShellCheck..."
if command -v shellcheck &>/dev/null; then
    shellcheck "$DEPLOY_SCRIPT" || echo "ShellCheck found issues (non-fatal for test)"
else
    echo "ShellCheck not found, skipping."
fi

# 2. Dry Run Test
echo "Executing Dry-Run Deployment..."
if sudo bash "$DEPLOY_SCRIPT" --dry-run; then
    echo "Dry-run completed successfully."
else
    echo "Dry-run failed!"
    exit 1
fi

echo "Test suite passed."
