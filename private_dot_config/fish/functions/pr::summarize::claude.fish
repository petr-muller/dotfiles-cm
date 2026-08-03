function pr::summarize::claude --description "Launch claude inside a PR summarize worktree"
    argparse 'r/redhat' 'm/mine' -- $argv
    or return 1

    if set -q _flag_redhat; and set -q _flag_mine
        echo "Cannot pass both --redhat and --mine" >&2
        return 1
    end

    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/([0-9]+)-summarize\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in a PR summarize worktree (expected ~/Projects/Worktrees/github.com/<org>/<repo>/<N>-summarize): $toplevel" >&2
        return 1
    end
    set -l org $parts[2]
    set -l repo $parts[3]
    set -l pr_number $parts[4]

    set -l launcher
    if set -q _flag_redhat
        set launcher claude_redhat_sandboxed
    else if set -q _flag_mine
        set launcher claude_mine_sandboxed
    else if test -d $HOME/Projects/RH/github.com/$org/$repo
        set launcher claude_redhat_sandboxed
    else if test -d $HOME/Projects/Personal/github.com/$org/$repo
        set launcher claude_mine_sandboxed
    else
        echo "No canonical working copy under ~/Projects/{RH,Personal}/github.com/$org/$repo" >&2
        return 1
    end

    set -l project_dir $HOME/.claude/projects/(string replace -ra '[/.]' '-' $toplevel)
    if claude::sandbox::_resumable reviewer $toplevel
        echo "Resuming existing session for $toplevel."
        $launcher --continue
        return
    else if test -d $project_dir; and test (count (find $project_dir -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null)) -gt 0
        echo "Existing transcript(s) found for $toplevel, but not resumable in this sandbox (stale, or from a different worktree/run under this identity) — starting a fresh session." >&2
    end

    set -l title (gh pr view $pr_number --repo $org/$repo --json title -q .title 2>/dev/null)
    if test -z "$title"
        echo "Failed to fetch PR title via gh pr view $pr_number --repo $org/$repo" >&2
        return 1
    end

    $launcher --name "#$pr_number: $title" "/color purple"
end
