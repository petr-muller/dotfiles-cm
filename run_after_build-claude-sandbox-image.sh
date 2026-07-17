#!/bin/bash
set -euo pipefail

# Rebuilds the claude-review-sandbox image on every chezmoi apply, with
# --no-cache so gh/claude-code/dnf packages actually get refreshed rather
# than reusing stale cached install layers (a plain rebuild with an
# unchanged Containerfile would just hit cache and install nothing new).
if command -v podman >/dev/null 2>&1; then
    echo "claude-sandbox: rebuilding claude-review-sandbox:latest (--no-cache)..."
    podman build --no-cache -t claude-review-sandbox:latest "$HOME/.config/claude-sandbox/image"
else
    echo "claude-sandbox: podman not found, skipping image rebuild" >&2
fi
