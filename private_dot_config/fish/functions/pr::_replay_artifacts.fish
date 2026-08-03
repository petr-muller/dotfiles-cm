function pr::_replay_artifacts --description "Replay review/triage artifacts for <branch> on top of HEAD, from wherever pr::_push_review_artifacts publishes them (reviewer account's fork for public repos, origin otherwise)"
    set -l toplevel $argv[1]
    set -l org $argv[2]
    set -l repo $argv[3]
    set -l branch $argv[4]
    set -l commit_message $argv[5]
    set -l files $argv[6..-1]

    # This MUST mirror pr::_push_review_artifacts' destination choice: push
    # goes to the reviewer account's fork for public repos and to origin (my
    # own fork, host identity) otherwise. Replaying unconditionally from
    # origin — as this used to — silently resurrects whatever stale artifact
    # my own fork still carries from before the reviewer-fork switch, or
    # reports "nothing to replay" for a review that does exist.
    set -l source_ref
    set -l source_label
    set -l visibility (gh api repos/$org/$repo --jq .private 2>/dev/null)

    if test "$visibility" = false
        set source_label "petr-muller-reviewer/$repo@$branch"
        # Public repo: an anonymous HTTPS fetch is enough, so this stays on
        # the host — no sandboxed reviewer identity needed just to read.
        if git -C $toplevel fetch --quiet https://github.com/petr-muller-reviewer/$repo.git $branch 2>/dev/null
            # Resolve immediately: an earlier `git fetch pull/N/head` in the
            # caller also wrote FETCH_HEAD, so it must not be read lazily.
            set source_ref (git -C $toplevel rev-parse FETCH_HEAD)
        end
    else
        # Private repo, or visibility couldn't be determined: same fail-safe
        # as the push side — my own identity, my own fork.
        set source_label "origin/$branch"
        if git -C $toplevel rev-parse --verify --quiet origin/$branch >/dev/null
            set source_ref origin/$branch
        end
    end

    if test -z "$source_ref"
        echo "No $source_label — nothing to replay."
        return 0
    end

    set -l replay
    for f in $files
        if git -C $toplevel cat-file -e $source_ref:$f 2>/dev/null
            set -a replay $f
        end
    end

    if test (count $replay) -eq 0
        echo "$source_label exists but has none of "(string join ", " $files)" — nothing to replay."
        return 0
    end

    echo "Replaying "(string join ", " $replay)" from $source_label on top..."
    for f in $replay
        git -C $toplevel checkout $source_ref -- $f
        or return 1
        git -C $toplevel add $f
        or return 1
    end
    git -C $toplevel commit -m "$commit_message"
    or return 1
end
