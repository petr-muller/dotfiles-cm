function pr::review::open --description "Open the PR on GitHub and the local REVIEW.html"
    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/([0-9]+)-review\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in a PR review worktree (expected ~/Projects/Worktrees/github.com/<org>/<repo>/<N>-review): $toplevel" >&2
        return 1
    end
    set -l org $parts[2]
    set -l repo $parts[3]
    set -l pr_number $parts[4]

    xdg-open "https://github.com/$org/$repo/pull/$pr_number" >/dev/null 2>&1 &

    if test -f $toplevel/REVIEW.html
        xdg-open $toplevel/REVIEW.html >/dev/null 2>&1 &
    else
        echo "REVIEW.html not found in $toplevel — skipping local open" >&2
    end
end
