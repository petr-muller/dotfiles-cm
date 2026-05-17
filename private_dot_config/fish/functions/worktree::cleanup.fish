function worktree::cleanup --description "From within a worktree: push if it's a pushable form factor, then remove it (confirm if work would be lost)"
    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/(.+)\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in a worktree under ~/Projects/Worktrees/github.com/<org>/<repo>/<name>: $toplevel" >&2
        return 1
    end
    set -l org $parts[2]
    set -l repo $parts[3]
    set -l name $parts[4]

    set -l repo_root
    for base in $HOME/Projects/RH/github.com $HOME/Projects/Personal/github.com
        if test -e $base/$org/$repo/.git
            set repo_root $base/$org/$repo
            break
        end
    end
    if test -z "$repo_root"
        echo "No canonical working copy under ~/Projects/{RH,Personal}/github.com/$org/$repo" >&2
        return 1
    end

    # Pushable form factors have a dedicated push helper that commits the
    # artifact and force-pushes the branch to origin.
    set -l push_fn
    if string match -qr '^[0-9]+-review$' -- $name
        set push_fn pr::review::push
    else if string match -qr '^[0-9]+-triage$' -- $name
        set push_fn issue::triage::push
    end

    if test -n "$push_fn"
        echo "Pushable worktree ($name) — running $push_fn first..."
        if not $push_fn
            echo "$push_fn failed — will fall back to the work-loss confirmation below." >&2
        end
    end

    # What would be lost by removing this worktree now?
    set -l dirty (git -C $toplevel status --porcelain)
    set -l unpushed (git -C $toplevel rev-list HEAD --not --remotes 2>/dev/null)

    if test -n "$dirty"; or test -n "$unpushed"
        echo ""
        echo "Removing $toplevel would lose:"
        if test -n "$dirty"
            echo "  - uncommitted changes:"
            git -C $toplevel status --short | sed 's/^/      /'
        end
        if test -n "$unpushed"
            echo "  - "(count $unpushed)" commit(s) not on any remote:"
            git -C $toplevel log --oneline --no-decorate HEAD --not --remotes | sed 's/^/      /'
        end
        echo ""
        if not gum confirm "Discard the above and remove the worktree?"
            echo "Aborted — worktree kept."
            return 1
        end
    end

    # Must leave the worktree before removing it, or cwd becomes invalid.
    cd $repo_root
    or return 1

    echo "Removing worktree $toplevel..."
    git -C $repo_root worktree remove --force $toplevel
    or return 1
    git -C $repo_root worktree prune 2>/dev/null

    echo "Done. Now in $repo_root."
end
