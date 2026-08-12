function work::claude --description "Launch claude inside a work worktree"
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

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/work-([A-Za-z0-9._-]+)\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in a work worktree (expected ~/Projects/Worktrees/github.com/<org>/<repo>/work-<ID>): $toplevel" >&2
        return 1
    end
    set -l org $parts[2]
    set -l repo $parts[3]
    set -l work_id $parts[4]

    set -l launcher
    if set -q _flag_redhat
        set launcher claude_redhat_authoring_sandboxed
    else if set -q _flag_mine
        set launcher claude_mine_authoring_sandboxed
    else if test -d $HOME/Projects/RH/github.com/$org/$repo
        set launcher claude_redhat_authoring_sandboxed
    else if test -d $HOME/Projects/Personal/github.com/$org/$repo
        set launcher claude_mine_authoring_sandboxed
    else
        echo "No canonical working copy under ~/Projects/{RH,Personal}/github.com/$org/$repo" >&2
        return 1
    end

    set -l project_dir $HOME/.claude/projects/(string replace -ra '[/.]' '-' $toplevel)
    if claude::sandbox::_resumable author $toplevel
        echo "Resuming existing session for $toplevel."
        $launcher --continue
        return
    else if test -d $project_dir; and test (count (find $project_dir -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null)) -gt 0
        echo "Existing transcript(s) found for $toplevel, but this identity's last-session pointer doesn't match this worktree (stale, or from a different worktree/run under this identity) — opening the resume picker." >&2
        $launcher --resume
        return
    end

    $launcher --name "$work_id" "/color orange" $argv
end
