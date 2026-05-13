function pr::summarize::claude --description "Launch claude inside a PR summarize worktree"
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
    if test -d $HOME/Projects/RH/github.com/$org/$repo
        set launcher claude_redhat
    else if test -d $HOME/Projects/Personal/github.com/$org/$repo
        set launcher claude_mine
    else
        echo "No canonical working copy under ~/Projects/{RH,Personal}/github.com/$org/$repo" >&2
        return 1
    end

    set -l project_dir $HOME/.claude/projects/(string replace -ra '[/.]' '-' $toplevel)
    if test -d $project_dir
        set -l sessions (find $project_dir -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null)
        if test (count $sessions) -gt 0
            echo "Found "(count $sessions)" existing session(s) for $toplevel — resuming most recent."
            $launcher --continue
            return
        end
    end

    set -l title (gh pr view $pr_number --repo $org/$repo --json title -q .title 2>/dev/null)
    if test -z "$title"
        echo "Failed to fetch PR title via gh pr view $pr_number --repo $org/$repo" >&2
        return 1
    end

    $launcher --name "#$pr_number: $title" "/color purple"
end
