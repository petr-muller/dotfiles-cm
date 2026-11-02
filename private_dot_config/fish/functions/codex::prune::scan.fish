function codex::prune::scan --description "Report per-worktree Codex sandbox state whose worktree no longer exists"
    set -l orphans (codex::prune::_orphans)
    if test (count $orphans) -eq 0
        echo "No orphaned Codex sandbox state found."
        return 0
    end

    echo "=== ORPHANED CODEX STATE ("(count $orphans)") — no matching worktree found ==="
    for e in $orphans
        echo "  $e"
    end
    echo ""
    echo -n "reclaimable: "
    du -sch $orphans 2>/dev/null | tail -1 | string split -f1 \t
end
