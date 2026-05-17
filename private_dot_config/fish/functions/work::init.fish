function work::init --description "Interactively pick a GitHub project and set up a work worktree off the latest upstream default branch"
    if test (count $argv) -gt 1
        echo "Usage: work::init [WORK-ID]" >&2
        return 2
    end

    # Enumerate canonical GitHub working copies under both spaces.
    set -l projects
    for base in $HOME/Projects/RH/github.com $HOME/Projects/Personal/github.com
        test -d $base
        or continue
        for org_dir in $base/*/
            for repo_dir in $org_dir*/
                if test -e (string trim --right --chars=/ $repo_dir)/.git
                    set -a projects (string replace "$HOME/Projects/" "" (string trim --right --chars=/ $repo_dir))
                end
            end
        end
    end

    if test (count $projects) -eq 0
        echo "No GitHub working copies found under ~/Projects/{RH,Personal}/github.com/" >&2
        return 1
    end

    set -l selected (printf '%s\n' $projects | sort | gum filter --placeholder "Pick a project to work on...")
    if test -z "$selected"
        echo "No project selected." >&2
        return 1
    end
    set -l repo_root $HOME/Projects/$selected

    set -l work_id
    if test (count $argv) -eq 1
        set work_id $argv[1]
    else
        set work_id (gum input --placeholder "Work ID (e.g. trt-1234-something)")
    end
    set work_id (string trim -- $work_id)
    if test -z "$work_id"
        echo "No work ID given." >&2
        return 1
    end
    if not string match -qr '^[A-Za-z0-9._-]+$' -- $work_id
        echo "Work ID must contain only letters, digits, '.', '_' or '-': $work_id" >&2
        return 1
    end

    set -l rel (string replace -r "^$HOME/Projects/(RH|Personal)/" "" $repo_root)
    set -l repo (string split / $rel)[-1]
    set -l worktree_path $HOME/Projects/Worktrees/$rel/work-$work_id
    set -l branch $work_id

    echo "Repo:     $repo_root"
    echo "Work:     $work_id"
    echo "Worktree: $worktree_path"
    echo "Branch:   $branch"

    if test -d $worktree_path
        echo "Worktree already exists — entering it and refreshing overlay."
        cd $worktree_path
        or return 1
        pr::_private_content $worktree_path $repo
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
    git -C $repo_root worktree prune 2>/dev/null
    git -C $repo_root worktree add -B $branch $worktree_path $target_sha
    or return 1

    cd $worktree_path
    or return 1
    pr::_private_content $worktree_path $repo
end
