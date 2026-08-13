function claude::prune::scan --description "Report ~/.claude/projects session dirs whose real working directory no longer exists"
    set -l orphans (claude::prune::_orphans)
    if test (count $orphans) -eq 0
        echo "No orphaned session directories found."
        return 0
    end

    echo "=== ORPHANED SESSION DIRS ("(count $orphans)") — no matching worktree/repo/\$HOME found ==="
    for d in $orphans
        echo "  $d"
    end
    echo ""
    echo -n "reclaimable: "
    du -sch $orphans 2>/dev/null | tail -1 | string split -f1 \t
end
