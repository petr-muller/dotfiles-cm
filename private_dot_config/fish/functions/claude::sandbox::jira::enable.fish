function claude::sandbox::jira::enable --description "Opt this worktree in to RH JIRA access (acli) for sandboxed sessions"
    argparse 'h/help' -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: claude::sandbox::jira::enable"
        echo ""
        echo "Marks the current worktree as opted-in to acli/RH JIRA access inside"
        echo "sandboxed sessions. claude::sandbox::_run only mounts JIRA credentials"
        echo "when both the host-wide credentials (secrets/jira-token, jira-config)"
        echo "and this per-worktree marker are present — see"
        echo "~/.config/claude-sandbox/README.md setup step 4."
        echo ""
        echo "Disable again with: claude::sandbox::jira::disable"
        return 0
    end

    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    if not test -f ~/.config/claude-sandbox/secrets/jira-token; or not test -f ~/.config/claude-sandbox/jira-config
        echo "No RH JIRA host credentials configured yet (~/.config/claude-sandbox/secrets/jira-token, ~/.config/claude-sandbox/jira-config) — see ~/.config/claude-sandbox/README.md setup step 4." >&2
        return 1
    end

    set -l jira_dir ~/.config/claude-sandbox/jira
    mkdir -p $jira_dir
    chmod 700 $jira_dir
    touch $jira_dir/(claude::sandbox::_worktree_key $toplevel).enabled

    echo ">> RH JIRA access enabled for this worktree ($toplevel)."
    echo "   Disable: claude::sandbox::jira::disable"
end
