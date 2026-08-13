function worktree::prune::scan --description "Report which worktrees under ~/Projects/Worktrees are safe to remove (merged/closed PR or issue, clean tree) or broken (already gone from the canonical repo's registry)"
    set -l lines (worktree::prune::_classify $argv)
    or return $status

    set -l broken_paths
    set -l broken_reasons
    set -l safe_paths
    set -l safe_reasons
    set -l likely_paths
    set -l likely_reasons
    set -l manual_paths
    set -l manual_reasons

    for line in $lines
        set -l parts (string split -m4 \t -- $line)
        # parts: bucket path org repo reason
        switch $parts[1]
            case broken
                set -a broken_paths $parts[2]
                set -a broken_reasons $parts[5]
            case safe
                set -a safe_paths $parts[2]
                set -a safe_reasons $parts[5]
            case likely
                set -a likely_paths $parts[2]
                set -a likely_reasons $parts[5]
            case '*'
                set -a manual_paths $parts[2]
                set -a manual_reasons $parts[5]
        end
    end

    echo ""
    echo "=== BROKEN ("(count $broken_paths)") — no longer a git repo; worktree::prune::gc removes these with a plain rm -rf ==="
    for idx in (seq (count $broken_paths))
        echo "  $broken_paths[$idx]"
    end
    if test (count $broken_paths) -gt 0
        echo -n "  reclaimable: "
        du -sch $broken_paths 2>/dev/null | tail -1 | string split -f1 \t
    end

    echo ""
    echo "=== SAFE ("(count $safe_paths)") — merged/closed + clean; worktree::prune::gc will offer these ==="
    for idx in (seq (count $safe_paths))
        echo "  $safe_paths[$idx]"
        echo "      $safe_reasons[$idx]"
    end
    if test (count $safe_paths) -gt 0
        echo -n "  reclaimable: "
        du -sch $safe_paths 2>/dev/null | tail -1 | string split -f1 \t
    end

    echo ""
    echo "=== LIKELY ("(count $likely_paths)") — heuristic merge signal + clean; review before removing ==="
    for idx in (seq (count $likely_paths))
        echo "  $likely_paths[$idx]"
        echo "      $likely_reasons[$idx]"
    end

    echo ""
    echo "=== MANUAL ("(count $manual_paths)") — dirty, open, or undetermined; left alone ==="
    for idx in (seq (count $manual_paths))
        echo "  $manual_paths[$idx]"
        echo "      $manual_reasons[$idx]"
    end
end
