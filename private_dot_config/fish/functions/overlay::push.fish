function overlay::push --description "Commit and push changes in the worktree's private claude-content overlay (.private-claude-content) so other worktrees pick them up"
    set -l dir .private-claude-content

    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end
    # Invoked from inside the overlay clone itself: step out to the worktree.
    if test (basename $toplevel) = $dir
        set toplevel (git -C (dirname $toplevel) rev-parse --show-toplevel 2>/dev/null)
        if test -z "$toplevel"
            echo "Not in a git repository" >&2
            return 1
        end
    end

    set -l overlay $toplevel/$dir
    if not test -d $overlay
        echo "No $dir overlay in this worktree: $toplevel" >&2
        return 1
    end
    if test "$(git -C $overlay rev-parse --show-toplevel 2>/dev/null)" != "$overlay"
        echo "$overlay is not a git repository" >&2
        return 1
    end

    set -l commit_message "Update overlay from "(basename $toplevel)
    if test (count $argv) -ge 1
        set commit_message $argv[1]
    end

    if test -e (git -C $overlay rev-parse --git-path rebase-merge); or test -e (git -C $overlay rev-parse --git-path rebase-apply)
        echo "A rebase is in progress in $overlay — resolve it and run 'git -C $overlay rebase --continue' first" >&2
        return 1
    end

    set -l branch (git -C $overlay rev-parse --abbrev-ref HEAD)
    if test "$branch" = HEAD
        echo "$overlay is on a detached HEAD, expected a branch" >&2
        return 1
    end

    set -l unpushed (git -C $overlay rev-list --count '@{upstream}..HEAD' 2>/dev/null)
    if test -z "$unpushed"
        echo "Branch '$branch' in $overlay has no upstream configured" >&2
        return 1
    end

    if test -z "$(git -C $overlay status --porcelain)"; and test $unpushed -eq 0
        echo "nothing to push"
        return 0
    end

    git -C $overlay add -A
    or return 1
    if git -C $overlay diff --cached --quiet
        echo "No uncommitted changes — pushing $unpushed existing commit(s)."
    else
        git -C $overlay commit -m "$commit_message"
        or return 1
    end

    echo "Rebasing onto the latest $branch..."
    if not git -C $overlay pull --rebase
        if test -e (git -C $overlay rev-parse --git-path rebase-merge); or test -e (git -C $overlay rev-parse --git-path rebase-apply)
            echo "Rebase of $branch stopped on conflicts in $overlay (left in progress)." >&2
            echo "  - .scratch/upstream/** mirror-zone conflicts: take either side, then re-run /muller-mirror-issues" >&2
            echo "    (it regenerates mirror zones and never touches local zones)." >&2
            echo "  - Anything else: resolve by hand." >&2
            echo "Then: git -C $overlay rebase --continue && overlay::push" >&2
        end
        return 1
    end

    git -C $overlay push
    or return 1

    echo "Pushed "(git -C $overlay rev-parse --short HEAD)" to $branch"
end
