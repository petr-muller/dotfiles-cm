function worktree::prune::gc --description "Remove worktrees classified as broken or safe by worktree::prune::_classify, confirming each one before removal"
    set -l lines (worktree::prune::_classify $argv)
    or return $status

    set -l broken_paths
    set -l broken_orgs
    set -l broken_repos
    set -l safe_paths
    set -l safe_orgs
    set -l safe_repos
    set -l safe_reasons
    set -l likely_count 0

    for line in $lines
        set -l parts (string split -m4 \t -- $line)
        # parts: bucket path org repo reason
        switch $parts[1]
            case broken
                set -a broken_paths $parts[2]
                set -a broken_orgs $parts[3]
                set -a broken_repos $parts[4]
            case safe
                set -a safe_paths $parts[2]
                set -a safe_orgs $parts[3]
                set -a safe_repos $parts[4]
                set -a safe_reasons $parts[5]
            case likely
                set likely_count (math $likely_count + 1)
        end
    end

    if test (count $broken_paths) -eq 0; and test (count $safe_paths) -eq 0
        echo "Nothing in the broken or safe buckets — nothing to do. Run worktree::prune::scan for the full report."
        return 0
    end

    set -l start_dir (pwd)
    set -l removed 0
    set -l skipped 0
    set -l aborted 0

    # Three-way choice per item, not a plain yes/no: with `gum confirm`,
    # Esc/Ctrl-C is indistinguishable from a deliberate "no", so there was no
    # way to stop the whole batch early — only skip one item at a time. Here
    # Esc/Ctrl-C (empty selection) means "abort everything"; skipping just
    # this one item requires picking "Skip" explicitly.

    # Broken worktrees aren't git repos anymore (metadata already dropped
    # from the canonical repo) — no `git worktree remove` is possible or
    # needed, just reclaim the directory and prune the canonical repo's
    # stale bookkeeping in case any is left.
    for idx in (seq (count $broken_paths))
        set -l path $broken_paths[$idx]
        if not test -d $path
            continue
        end
        echo ""
        echo "$path (broken — not a git repo)"
        set -l choice (gum choose "Remove" "Skip" "Abort remaining")
        if test -z "$choice"
            set choice "Abort remaining"
        end
        switch $choice
            case Remove
                rm -rf -- $path
                for base in $HOME/Projects/RH/github.com $HOME/Projects/Personal/github.com
                    if test -d $base/$broken_orgs[$idx]/$broken_repos[$idx]/.git
                        git -C $base/$broken_orgs[$idx]/$broken_repos[$idx] worktree prune 2>/dev/null
                        break
                    end
                end
                set removed (math $removed + 1)
            case Skip
                set skipped (math $skipped + 1)
            case '*'
                set aborted 1
                break
        end
    end

    if test $aborted -eq 0
        for idx in (seq (count $safe_paths))
            set -l path $safe_paths[$idx]
            if not test -d $path
                continue
            end
            set -l org $safe_orgs[$idx]
            set -l repo $safe_repos[$idx]
            set -l reason $safe_reasons[$idx]
            echo ""
            echo "$path"
            echo "  $org/$repo — $reason"
            set -l n (string match -r '#([0-9]+)' -- $reason)
            if test (count $n) -eq 2
                if string match -q '*triage*' -- $reason
                    echo "  https://github.com/$org/$repo/issues/$n[2]"
                else
                    echo "  https://github.com/$org/$repo/pull/$n[2]"
                end
            end
            set -l choice (gum choose "Remove" "Skip" "Abort remaining")
            if test -z "$choice"
                set choice "Abort remaining"
            end
            switch $choice
                case Remove
                    cd $path
                    or continue
                    if worktree::cleanup
                        set removed (math $removed + 1)
                    else
                        echo "worktree::cleanup failed for $path — left in place." >&2
                        set skipped (math $skipped + 1)
                    end
                case Skip
                    set skipped (math $skipped + 1)
                case '*'
                    set aborted 1
                    break
            end
        end
    end

    cd $start_dir 2>/dev/null

    echo ""
    if test $aborted -eq 1
        echo "Aborted. Removed $removed, skipped $skipped, rest left untouched."
    else
        echo "Removed $removed, skipped $skipped."
    end
    if test $likely_count -gt 0
        echo "($likely_count more in the 'likely' bucket — see worktree::prune::scan; not touched automatically.)"
    end
end
