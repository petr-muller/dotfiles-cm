function work::continue --description "Interactively pick a project, then an existing work-<ID> worktree, and enter it"
    if test (count $argv) -ne 0
        echo "Usage: work::continue" >&2
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

    set -l selected (printf '%s\n' $projects | sort | gum filter --placeholder "Pick a project...")
    if test -z "$selected"
        echo "No project selected." >&2
        return 1
    end
    set -l repo_root $HOME/Projects/$selected
    set -l rel (string replace -r "^$HOME/Projects/(RH|Personal)/" "" $repo_root)
    set -l repo (string split / $rel)[-1]

    set -l worktrees_dir $HOME/Projects/Worktrees/$rel

    set -l work_ids
    for wt in $worktrees_dir/work-*/
        test -d (string trim --right --chars=/ $wt)
        or continue
        set -a work_ids (string replace -r '^work-' '' (basename (string trim --right --chars=/ $wt)))
    end

    if test (count $work_ids) -eq 0
        echo "No existing work-<ID> worktrees for $selected under $worktrees_dir" >&2
        return 1
    end

    set -l work_id (printf '%s\n' $work_ids | sort | gum filter --placeholder "Pick work to continue...")
    if test -z "$work_id"
        echo "No work selected." >&2
        return 1
    end

    set -l worktree_path $worktrees_dir/work-$work_id

    echo "Repo:     $repo_root"
    echo "Work:     $work_id"
    echo "Worktree: $worktree_path"

    cd $worktree_path
    or return 1
    pr::_private_content $worktree_path $repo
end
