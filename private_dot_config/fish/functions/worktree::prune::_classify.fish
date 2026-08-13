function worktree::prune::_classify --description "Internal: classify worktrees under ~/Projects/Worktrees as broken/safe/likely/manual for pruning. Emits tab-separated <bucket> <path> <org> <repo> <reason> lines to stdout; progress goes to stderr."
    argparse 'repo=' -- $argv
    or return 1

    set -l base $HOME/Projects/Worktrees/github.com
    if not test -d $base
        echo "No worktrees found under $base" >&2
        return 1
    end

    set -l worktrees
    if set -q _flag_repo
        set -l parts (string split '/' -- $_flag_repo)
        if test (count $parts) -ne 2
            echo "Usage: --repo <org>/<repo>" >&2
            return 2
        end
        set worktrees $base/$parts[1]/$parts[2]/*/
    else
        set worktrees $base/*/*/*/
    end

    set -l total (count $worktrees)
    set -l i 0

    for wt in $worktrees
        set i (math $i + 1)
        set -l path (string trim -r -c / -- $wt)
        set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/(.+)\$" -- $path)
        if test (count $parts) -lt 4
            continue
        end
        set -l org $parts[2]
        set -l repo $parts[3]
        set -l name $parts[4]

        # A worktree whose .git file points at metadata the canonical repo no
        # longer has (already dropped from `git worktree list` there, e.g. by
        # a manual `rm -rf .git/worktrees/<name>` instead of `git worktree
        # remove`) isn't a git repo at all anymore — no commits can be lost,
        # `git worktree remove` can't even target it. Flag it before anything
        # else, since every other check below assumes a working git repo.
        if not git -C $path rev-parse --git-dir >/dev/null 2>&1
            echo "[$i/$total] $org/$repo/$name -> broken (worktree metadata missing from canonical repo)" >&2
            printf "%s\t%s\t%s\t%s\t%s\n" broken $path $org $repo "worktree metadata is gone from the canonical repo's registry — plain rm -rf, no git operations possible or needed"
            continue
        end

        # Claude Code itself rewrites .claude/settings.json (permission
        # grants) during a session, so a lone modification there is noise,
        # not uncommitted work — filter it out before judging cleanliness.
        set -l status_lines (git -C $path status --porcelain 2>/dev/null | string match -rv '\.claude/settings(\.local)?\.json$')
        set -l clean 1
        if test -n "$status_lines"
            set clean 0
        end

        set -l bucket manual
        set -l reason
        set -l np (string match -r '^([0-9]+)-(review|summarize|triage)$' -- $name)

        if test (count $np) -eq 3
            set -l n $np[2]
            set -l kind $np[3]
            set -l state
            if test "$kind" = triage
                set state (gh issue view $n --repo $org/$repo --json state -q .state 2>/dev/null)
            else
                set state (gh pr view $n --repo $org/$repo --json state -q .state 2>/dev/null)
            end
            if test -z "$state"
                set reason "gh lookup for $kind #$n failed (deleted PR/issue, no access, or network)"
            else if contains -- $state MERGED CLOSED
                if test $clean -eq 1
                    set bucket safe
                    set reason "$kind #$n is $state"
                else
                    set reason "$kind #$n is $state but tree has uncommitted changes"
                end
            else
                set reason "$kind #$n is still $state"
            end
        else
            set -l branch (git -C $path rev-parse --abbrev-ref HEAD 2>/dev/null)
            set -l merged_pr (gh pr list --repo $org/$repo --head $branch --state merged --json number -q '.[0].number' 2>/dev/null)
            if test -n "$merged_pr"
                if test $clean -eq 1
                    set bucket safe
                    set reason "branch '$branch' was merged via PR #$merged_pr"
                else
                    set reason "branch '$branch' was merged via PR #$merged_pr but tree has uncommitted changes"
                end
            else
                set -l remote
                for candidate in upstream origin
                    if git -C $path remote 2>/dev/null | string match -q $candidate
                        set remote $candidate
                        break
                    end
                end
                set -l default_branch
                if test -n "$remote"
                    git -C $path remote set-head $remote --auto >/dev/null 2>&1
                    set default_branch (git -C $path symbolic-ref refs/remotes/$remote/HEAD 2>/dev/null | string replace "refs/remotes/$remote/" "")
                end
                if test -z "$remote"
                    set reason "no merged PR found and no upstream/origin remote configured"
                else if test -n "$default_branch"
                    if git -C $path merge-base --is-ancestor HEAD refs/remotes/$remote/$default_branch 2>/dev/null
                        if test $clean -eq 1
                            set bucket likely
                            set reason "HEAD is already an ancestor of $remote/$default_branch (merged without a tracked PR?)"
                        else
                            set reason "looks merged into $remote/$default_branch but tree has uncommitted changes"
                        end
                    else
                        set reason "no merged PR found and not merged into $remote/$default_branch"
                    end
                else
                    set reason "no merged PR found and could not resolve $remote's default branch"
                end
            end
        end

        echo "[$i/$total] $org/$repo/$name -> $bucket ($reason)" >&2
        printf "%s\t%s\t%s\t%s\t%s\n" $bucket $path $org $repo $reason
    end
end
