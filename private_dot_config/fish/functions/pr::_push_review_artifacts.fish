function pr::_push_review_artifacts --description "Stage+commit the given files and push <branch>: to the reviewer account's fork (sandboxed reviewer identity) if <org>/<repo> is public, else to origin with the host identity as before"
    set -l toplevel $argv[1]
    set -l org $argv[2]
    set -l repo $argv[3]
    set -l branch $argv[4]
    set -l commit_message $argv[5]
    set -l files $argv[6..-1]

    set -l present
    for f in $files
        if test -f $toplevel/$f
            set -a present $f
        end
    end
    if test (count $present) -eq 0
        echo "None of "(string join ", " $files)" found in $toplevel" >&2
        return 1
    end

    for f in $present
        git -C $toplevel add $f
        or return 1
    end

    set -l is_public 0
    set -l visibility (gh api repos/$org/$repo --jq .private 2>/dev/null)
    if test "$visibility" = "false"
        set is_public 1
    end

    if test $is_public -eq 0
        # Private repo, or visibility couldn't be determined: fail safe and
        # keep the pre-reviewer-fork behavior — your own identity, your own
        # fork.
        if git -C $toplevel diff --cached --quiet
            echo "No staged changes to "(string join ", " $present)" — nothing to commit."
        else
            git -C $toplevel commit -m "$commit_message"
            or return 1
        end
        git -C $toplevel push --force-with-lease --set-upstream origin $branch:$branch
        return
    end

    echo "$org/$repo is public — publishing via the reviewer account's fork (petr-muller-reviewer/$repo)."
    set -l script "set -euo pipefail
cd /workspace
if ! git diff --cached --quiet; then
  git commit -m '$commit_message'
else
  echo 'No staged changes — nothing to commit.'
fi
gh repo fork $org/$repo
git push https://github.com/petr-muller-reviewer/$repo.git HEAD:$branch --force"

    claude::sandbox::_exec reviewer $toplevel $script
end
