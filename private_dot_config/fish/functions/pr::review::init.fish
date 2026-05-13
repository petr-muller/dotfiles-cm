function pr::review::init --description "Set up a worktree to review a GitHub PR"
    if test (count $argv) -ne 1
        echo "Usage: pr-review <PR-URL|PR-NUMBER>" >&2
        return 2
    end

    set -l arg $argv[1]
    set -l pr_number
    set -l repo_root

    if string match -qr '^https?://' -- $arg
        set -l parts (string match -r '^https?://github\.com/([^/]+)/([^/]+)/pull/([0-9]+)' -- $arg)
        if test (count $parts) -lt 4
            echo "Could not parse GitHub PR URL: $arg" >&2
            return 1
        end
        set -l org $parts[2]
        set -l repo $parts[3]
        set pr_number $parts[4]

        for base in $HOME/Projects/RH/github.com $HOME/Projects/Personal/github.com
            if test -d $base/$org/$repo/.git
                set repo_root $base/$org/$repo
                break
            end
        end
        if test -z "$repo_root"
            echo "No canonical working copy found for $org/$repo under ~/Projects/{RH,Personal}/github.com/" >&2
            return 1
        end
    else if string match -qr '^[0-9]+$' -- $arg
        set pr_number $arg
        set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
        if test -z "$toplevel"
            echo "Not in a git repository (and no PR URL given)" >&2
            return 1
        end
        if not string match -qr "^$HOME/Projects/(RH|Personal)/github\.com/[^/]+/[^/]+\$" -- $toplevel
            echo "Not in a canonical GitHub working copy: $toplevel" >&2
            echo "Expected: ~/Projects/{RH,Personal}/github.com/<org>/<repo>" >&2
            return 1
        end
        set repo_root $toplevel
    else
        echo "Argument must be a GitHub PR URL or a PR number: $arg" >&2
        return 1
    end

    set -l rel (string replace -r "^$HOME/Projects/(RH|Personal)/" "" $repo_root)
    set -l worktree_path $HOME/Projects/Worktrees/$rel/$pr_number-review
    set -l branch $pr_number-review

    echo "Repo:     $repo_root"
    echo "PR:       #$pr_number"
    echo "Worktree: $worktree_path"
    echo "Branch:   $branch"

    if test -d $worktree_path
        echo "Worktree already exists — delegating to pr::review::pull."
        cd $worktree_path
        or return 1
        pr::review::pull
        return
    end

    echo "Fetching all remotes..."
    git -C $repo_root fetch --all
    or return 1

    set -l pr_remote
    for candidate in upstream origin
        if git -C $repo_root remote | string match -q $candidate
            set pr_remote $candidate
            break
        end
    end
    if test -z "$pr_remote"
        echo "No 'upstream' or 'origin' remote found" >&2
        return 1
    end

    echo "Fetching pull/$pr_number/head from $pr_remote..."
    git -C $repo_root fetch $pr_remote "pull/$pr_number/head"
    or return 1
    set -l sha (git -C $repo_root rev-parse FETCH_HEAD)

    echo "Creating worktree..."
    git -C $repo_root worktree add -b $branch $worktree_path $sha
    or return 1

    cd $worktree_path
    or return 1
    # Delegate to pull so we get overlay setup and remote artifact replay
    # consistently with the "worktree already exists" path.
    pr::review::pull
end
