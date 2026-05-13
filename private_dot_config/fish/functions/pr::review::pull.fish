function pr::review::pull --description "Refresh PR review branch from remotes (PR head + remote REVIEW.{html,md})"
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
    set -l repo $parts[3]
    set -l pr_number $parts[4]
    set -l branch $pr_number-review

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

    if git -C $toplevel rev-parse --verify --quiet origin/$branch >/dev/null
        set -l review_files REVIEW.html REVIEW.md
        set -l replay
        for f in $review_files
            if git -C $toplevel cat-file -e origin/$branch:$f 2>/dev/null
                set -a replay $f
            end
        end
        if test (count $replay) -gt 0
            echo "Replaying "(string join ", " $replay)" from origin/$branch on top..."
            for f in $replay
                git -C $toplevel checkout origin/$branch -- $f
                or return 1
                git -C $toplevel add $f
            end
            git -C $toplevel commit -m "Review of PR $pr_number"
            or return 1
        else
            echo "origin/$branch exists but has no REVIEW.{html,md} — nothing to replay."
        end
    else
        echo "No origin/$branch — nothing to replay."
    end
end
