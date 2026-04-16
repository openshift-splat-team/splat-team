#!/bin/bash
# Botminter startup script - syncs git repos before starting

set -e

echo "[$(date -Iseconds)] Starting botminter startup sequence..."

# Sync team repo
echo "[$(date -Iseconds)] Syncing team repo..."
cd /home/splat/.botminter/workspaces/splat/team
git fetch && git rebase origin/main

# Sync superman-atlas workspace
echo "[$(date -Iseconds)] Syncing superman-atlas workspace..."
cd /home/splat/.botminter/workspaces/splat/superman-atlas
git fetch && git rebase origin/main

echo "[$(date -Iseconds)] Git sync complete. Starting botminter daemon..."
cd /home/splat
bm daemon start

echo "[$(date -Iseconds)] Starting members..."
bm start

echo "[$(date -Iseconds)] Botminter startup complete"
