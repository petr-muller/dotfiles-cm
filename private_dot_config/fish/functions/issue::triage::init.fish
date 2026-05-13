function issue::triage::init --description "Set up a worktree to triage a GitHub issue, at latest upstream default branch"
    if test (count $argv) -ne 1
        echo "Usage: issue::triage::init <ISSUE-URL|ISSUE-NUMBER>" >&2
        return 2
    end

    set -l arg $argv[1]
    set -l issue_number
    set -l repo_root

    if string match -qr '^https?://' -- $arg
        set -l parts (string match -r '^https?://github\.com/([^/]+)/([^/]+)/issues/([0-9]+)' -- $arg)
        if test (count $parts) -lt 4
            echo "Could not parse GitHub issue URL: $arg" >&2
            return 1
        end
        set -l org $parts[2]
        set -l repo $parts[3]
        set issue_number $parts[4]

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
        set issue_number $arg
        set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
        if test -z "$toplevel"
            echo "Not in a git repository (and no issue URL given)" >&2
            return 1
        end
        if not string match -qr "^$HOME/Projects/(RH|Personal)/github\.com/[^/]+/[^/]+\$" -- $toplevel
            echo "Not in a canonical GitHub working copy: $toplevel" >&2
            echo "Expected: ~/Projects/{RH,Personal}/github.com/<org>/<repo>" >&2
            return 1
        end
        set repo_root $toplevel
    else
        echo "Argument must be a GitHub issue URL or an issue number: $arg" >&2
        return 1
    end

    set -l rel (string replace -r "^$HOME/Projects/(RH|Personal)/" "" $repo_root)
    set -l worktree_path $HOME/Projects/Worktrees/$rel/$issue_number-triage
    set -l branch $issue_number-triage

    echo "Repo:     $repo_root"
    echo "Issue:    #$issue_number"
    echo "Worktree: $worktree_path"
    echo "Branch:   $branch"

    if test -d $worktree_path
        echo "Worktree already exists — delegating to issue::triage::pull."
        cd $worktree_path
        or return 1
        issue::triage::pull
        return
    end

    echo "Fetching all remotes..."
    git -C $repo_root fetch --all
    or return 1

    set -l source_remote
    for candidate in upstream origin
        if git -C $repo_root remote | string match -q $candidate
            set source_remote $candidate
            break
        end
    end
    if test -z "$source_remote"
        echo "No 'upstream' or 'origin' remote found" >&2
        return 1
    end

    set -l default_ref (git -C $repo_root symbolic-ref -q refs/remotes/$source_remote/HEAD 2>/dev/null)
    if test -z "$default_ref"
        echo "Determining default branch for $source_remote..."
        git -C $repo_root remote set-head $source_remote --auto >/dev/null
        or return 1
        set default_ref (git -C $repo_root symbolic-ref -q refs/remotes/$source_remote/HEAD)
    end
    set -l default_branch (string replace "refs/remotes/$source_remote/" "" $default_ref)
    set -l target_sha (git -C $repo_root rev-parse $source_remote/$default_branch)
    echo "Source:   $source_remote/$default_branch @ $target_sha"

    echo "Creating worktree..."
    git -C $repo_root worktree add -b $branch $worktree_path $target_sha
    or return 1

    cd $worktree_path
    or return 1
    # Delegate to pull so we get overlay setup and remote artifact replay
    # consistently with the "worktree already exists" path.
    issue::triage::pull
end
