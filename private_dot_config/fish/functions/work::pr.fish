function work::pr --description "Open a PR from the author account's fork branch (pushed via work::push) against upstream, with an explicit title/body"
    if test (count $argv) -lt 1; or test (count $argv) -gt 2
        echo "Usage: work::pr TITLE [BODY]" >&2
        return 2
    end
    set -l title $argv[1]
    set -l body $argv[2]

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

    set -l visibility (gh api repos/$org/$repo --jq .private 2>/dev/null)
    if test "$visibility" != "false"
        echo "$org/$repo is private (or its visibility could not be determined) — the author account has no access there. Open the PR manually with your own identity if that's appropriate." >&2
        return 1
    end

    set -l default_ref (git -C $toplevel symbolic-ref -q refs/remotes/upstream/HEAD 2>/dev/null)
    set -l source_remote upstream
    if test -z "$default_ref"
        set default_ref (git -C $toplevel symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null)
        set source_remote origin
    end
    if test -z "$default_ref"
        echo "Could not determine the default branch (no refs/remotes/{upstream,origin}/HEAD) — run 'git remote set-head $source_remote --auto' first." >&2
        return 1
    end
    set -l base_branch (string replace "refs/remotes/$source_remote/" "" $default_ref)

    echo "$org/$repo is public — opening PR petr-muller-author:$branch -> $org/$repo:$base_branch."
    set -l title_b64 (echo -n $title | base64 -w0)
    set -l body_b64 (echo -n $body | base64 -w0)
    set -l script "set -euo pipefail
cd /workspace
title=\$(echo $title_b64 | base64 -d)
body=\$(echo $body_b64 | base64 -d)
gh pr create --repo $org/$repo --base $base_branch --head petr-muller-author:$branch --title \"\$title\" --body \"\$body\""

    claude::sandbox::_exec author $toplevel $script
end
