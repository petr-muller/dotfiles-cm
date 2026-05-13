function pr::review::push --description "Commit REVIEW.{html,md} and push the review branch to origin"
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
    set -l pr_number $parts[4]
    set -l branch $pr_number-review

    set -l current_branch (git -C $toplevel rev-parse --abbrev-ref HEAD)
    if test "$current_branch" != "$branch"
        echo "Expected branch '$branch', got '$current_branch'" >&2
        return 1
    end

    set -l review_files REVIEW.html REVIEW.md
    set -l present
    for f in $review_files
        if test -f $toplevel/$f
            set -a present $f
        end
    end
    if test (count $present) -eq 0
        echo "Neither REVIEW.html nor REVIEW.md found in $toplevel" >&2
        return 1
    end

    for f in $present
        git -C $toplevel add $f
        or return 1
    end

    if git -C $toplevel diff --cached --quiet
        echo "No staged changes to "(string join ", " $present)" — nothing to commit."
    else
        git -C $toplevel commit -m "Review of PR $pr_number"
        or return 1
    end

    git -C $toplevel push --force-with-lease --set-upstream origin $branch:$branch
end
