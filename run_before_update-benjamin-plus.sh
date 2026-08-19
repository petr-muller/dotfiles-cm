#!/bin/bash
set -euo pipefail

# Refreshes the benjamin-plus-skill checkout that dot_claude/CLAUDE.md.tmpl
# inlines (via `output "cat" ...` of injected-instruction.md), on every
# chezmoi apply -- so the injected token-efficiency rules track upstream
# automatically instead of needing a manual re-copy. Must be run_before_ (not
# run_after_/plain run_) so the checkout is current before CLAUDE.md.tmpl is
# rendered in the same apply, same idea as run_after_build-claude-sandbox-image.sh
# redoing its thing unconditionally on every apply.
repo="$HOME/.benjamin-plus"
if [ -d "$repo/.git" ]; then
    git -C "$repo" pull --ff-only --quiet
else
    git clone --quiet https://github.com/JetBrains/benjamin-plus-skill "$repo"
fi
