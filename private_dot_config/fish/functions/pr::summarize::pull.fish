function pr::summarize::pull --description "Refresh PR summarize branch to latest PR head"
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
    set -l repo $parts[3]
    set -l pr_number $parts[4]
    set -l branch $pr_number-summarize

    set -l current_branch (git -C $toplevel rev-parse --abbrev-ref HEAD)
    if test "$current_branch" != "$branch"
        echo "Expected branch '$branch', got '$current_branch'" >&2
        return 1
    end

    set -l pr_remote
    for candidate in upstream origin
        if git -C $toplevel remote | string match -q $candidate
            set pr_remote $candidate
            break
        end
    end
    if test -z "$pr_remote"
        echo "No 'upstream' or 'origin' remote found" >&2
        return 1
    end

    echo "Fetching all remotes..."
    git -C $toplevel fetch --all
    or return 1

    echo "Fetching pull/$pr_number/head from $pr_remote..."
    git -C $toplevel fetch $pr_remote "pull/$pr_number/head"
    or return 1
    set -l pr_sha (git -C $toplevel rev-parse FETCH_HEAD)

    echo "Resetting $branch to PR head $pr_sha..."
    git -C $toplevel reset --hard $pr_sha
    or return 1

    pr::_private_content $toplevel $repo
end
