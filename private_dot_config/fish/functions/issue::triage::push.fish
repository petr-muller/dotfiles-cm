function issue::triage::push --description "Commit TRIAGE.{html,md} and push the triage branch to origin"
    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/([0-9]+)-triage\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in an issue triage worktree (expected ~/Projects/Worktrees/github.com/<org>/<repo>/<N>-triage): $toplevel" >&2
        return 1
    end
    set -l issue_number $parts[4]
    set -l branch $issue_number-triage

    set -l current_branch (git -C $toplevel rev-parse --abbrev-ref HEAD)
    if test "$current_branch" != "$branch"
        echo "Expected branch '$branch', got '$current_branch'" >&2
        return 1
    end

    set -l triage_files TRIAGE.html TRIAGE.md
    set -l present
    for f in $triage_files
        if test -f $toplevel/$f
            set -a present $f
        end
    end
    if test (count $present) -eq 0
        echo "Neither TRIAGE.html nor TRIAGE.md found in $toplevel" >&2
        return 1
    end

    for f in $present
        git -C $toplevel add $f
        or return 1
    end

    if git -C $toplevel diff --cached --quiet
        echo "No staged changes to "(string join ", " $present)" — nothing to commit."
    else
        git -C $toplevel commit -m "Triage of issue $issue_number"
        or return 1
    end

    git -C $toplevel push --force-with-lease --set-upstream origin $branch:$branch
end
