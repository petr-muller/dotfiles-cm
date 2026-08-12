function claude::sandbox::jira::disable --description "Opt this worktree back out of RH JIRA access (acli) for sandboxed sessions"
    argparse 'h/help' -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: claude::sandbox::jira::disable"
        echo ""
        echo "Removes this worktree's opt-in marker for acli/RH JIRA access. No"
        echo "server-side state to tear down — a no-op if it was never enabled."
        return 0
    end

    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l marker ~/.config/claude-sandbox/jira/(claude::sandbox::_worktree_key $toplevel).enabled
    if test -f $marker
        rm -f $marker
        echo ">> RH JIRA access disabled for this worktree."
    end
end
