function codex::prune::gc --description "Delete orphaned per-worktree Codex sandbox state (no matching worktree), after one batch confirmation"
    set -l orphans (codex::prune::_orphans)
    if test (count $orphans) -eq 0
        echo "Nothing to do."
        return 0
    end

    echo "About to delete "(count $orphans)" orphaned Codex state entries:"
    for e in $orphans
        echo "  $e"
    end
    echo -n "total size: "
    du -sch $orphans 2>/dev/null | tail -1 | string split -f1 \t
    echo ""

    if not gum confirm "Delete all of the above?"
        echo "Aborted — nothing removed."
        return 1
    end

    for e in $orphans
        rm -rf -- $e
    end
    echo "Removed "(count $orphans)" Codex state entries."
end
