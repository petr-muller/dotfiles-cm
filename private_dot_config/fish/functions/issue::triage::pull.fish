function issue::triage::pull --description "Refresh issue triage branch (reset to upstream default + replay remote TRIAGE.{html,md})"
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
    set -l org $parts[2]
    set -l repo $parts[3]
    set -l issue_number $parts[4]
    set -l branch $issue_number-triage

    set -l current_branch (git -C $toplevel rev-parse --abbrev-ref HEAD)
    if test "$current_branch" != "$branch"
        echo "Expected branch '$branch', got '$current_branch'" >&2
        return 1
    end

    set -l source_remote
    for candidate in upstream origin
        if git -C $toplevel remote | string match -q $candidate
            set source_remote $candidate
            break
        end
    end
    if test -z "$source_remote"
        echo "No 'upstream' or 'origin' remote found" >&2
        return 1
    end

    echo "Fetching all remotes..."
    git -C $toplevel fetch --all
    or return 1

    set -l default_ref (git -C $toplevel symbolic-ref -q refs/remotes/$source_remote/HEAD 2>/dev/null)
    if test -z "$default_ref"
        echo "Determining default branch for $source_remote..."
        git -C $toplevel remote set-head $source_remote --auto >/dev/null
        or return 1
        set default_ref (git -C $toplevel symbolic-ref -q refs/remotes/$source_remote/HEAD)
    end
    set -l default_branch (string replace "refs/remotes/$source_remote/" "" $default_ref)
    set -l target_sha (git -C $toplevel rev-parse $source_remote/$default_branch)

    echo "Resetting $branch to $source_remote/$default_branch @ $target_sha..."
    git -C $toplevel reset --hard $target_sha
    or return 1

    pr::_private_content $toplevel $repo

    pr::_replay_artifacts $toplevel $org $repo $branch "Triage of issue $issue_number" TRIAGE.html TRIAGE.md
end
