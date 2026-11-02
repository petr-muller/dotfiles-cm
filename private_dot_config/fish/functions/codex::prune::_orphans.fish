function codex::prune::_orphans --description "Internal: print absolute paths of per-worktree Codex sandbox state (~/.config/claude-sandbox/state/codex-{sessions,agents}-*) whose worktree no longer exists"
    set -l state_dir $HOME/.config/claude-sandbox/state
    set -l worktrees_root $HOME/Projects/Worktrees

    # Bail on an empty/missing worktree root (e.g. unmounted ~/Projects):
    # otherwise every entry would look orphaned.
    set -l worktrees $worktrees_root/*/*/*/*
    if not test -d $state_dir; or test (count $worktrees) -eq 0
        return 0
    end

    set -l live
    for w in $worktrees
        set -a live (claude::sandbox::_worktree_key $w)
    end

    # Unlike Claude Code's lossy project-dir encoding, these keys come from
    # our own claude::sandbox::_worktree_key, so forward-encoding the worktree
    # roots is exact. Only keys under the worktree root are candidates; the
    # identity-only legacy dirs (codex-sessions-<identity>) and anything
    # launched from elsewhere are left alone.
    set -l prefix (claude::sandbox::_worktree_key $worktrees_root/)
    for entry in $state_dir/codex-sessions-* $state_dir/codex-agents-*
        set -l key (string match -rg -- '^codex-(?:sessions|agents)-(?:author|reviewer)-(-.*?)(?:\.md)?$' (path basename -- $entry))
        test -n "$key"; or continue
        string match -q -- "$prefix*" $key; or continue
        contains -- $key $live; or echo $entry
    end
end
