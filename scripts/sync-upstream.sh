#!/usr/bin/env bash
set -euo pipefail

# Sync PAASS with upstream LARBS/voidrice
# Usage: ./sync-upstream.sh

UPSTREAM_URL="https://github.com/LukeSmithxyz/voidrice.git"
LOCAL_BRANCH="master"
UPSTREAM_BRANCH="master"

echo "Fetching upstream changes from $UPSTREAM_URL..."
git remote add upstream "$UPSTREAM_URL" 2>/dev/null || true
git fetch upstream

echo "Checking for updates..."
COMMITS=$(git rev-list HEAD..upstream/$UPSTREAM_BRANCH --count)

if [[ "$COMMITS" -gt 0 ]]; then
    echo "Found $COMMITS new commits upstream."
    echo "Attempting to merge..."
    
    if git merge upstream/$UPSTREAM_BRANCH; then
        echo "Successfully merged upstream changes."
    else
        echo "Merge conflict detected. Please resolve manually."
        exit 1
    fi
else
    echo "Already up to date."
fi
