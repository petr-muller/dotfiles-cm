function issue::triage::open --description "Open the issue on GitHub and the local TRIAGE.html"
    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/([0-9]+)-triage\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in an issue triage worktree (expected ~/Projects/Worktrees/github.com/<org>/<repo>/<N>-triage): $toplevel" >&2
        return 1
    end
    set -l org $parts[2]
    set -l repo $parts[3]
    set -l issue_number $parts[4]

    xdg-open "https://github.com/$org/$repo/issues/$issue_number" >/dev/null 2>&1 &

    if test -f $toplevel/TRIAGE.html
        xdg-open $toplevel/TRIAGE.html >/dev/null 2>&1 &
    else
        echo "TRIAGE.html not found in $toplevel — skipping local open" >&2
    end
end
