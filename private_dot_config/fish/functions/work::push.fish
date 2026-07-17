function work::push --description "Push the current work branch to the author account's fork (public repos only)"
    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/work-([A-Za-z0-9._-]+)\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in a work worktree (expected ~/Projects/Worktrees/github.com/<org>/<repo>/work-<ID>): $toplevel" >&2
        return 1
    end
    set -l org $parts[2]
    set -l repo $parts[3]
    set -l work_id $parts[4]
    set -l branch $work_id

    set -l current_branch (git -C $toplevel rev-parse --abbrev-ref HEAD)
    if test "$current_branch" != "$branch"
        echo "Expected branch '$branch', got '$current_branch'" >&2
        return 1
    end

    if not git -C $toplevel diff --quiet
        or not git -C $toplevel diff --cached --quiet
        echo "Uncommitted changes present in $toplevel — commit them (as the author identity, during the sandboxed work::claude session) before pushing." >&2
        return 1
    end

    set -l visibility (gh api repos/$org/$repo --jq .private 2>/dev/null)
    if test "$visibility" != "false"
        echo "$org/$repo is private (or its visibility could not be determined) — the author account has no access there. Push manually with your own identity if that's appropriate." >&2
        return 1
    end

    echo "$org/$repo is public — pushing to the author account's fork (petr-muller-author/$repo)."
    set -l script "set -euo pipefail
cd /workspace
gh repo fork $org/$repo
git push https://github.com/petr-muller-author/$repo.git HEAD:$branch --force"

    claude::sandbox::_exec author $toplevel $script
end
