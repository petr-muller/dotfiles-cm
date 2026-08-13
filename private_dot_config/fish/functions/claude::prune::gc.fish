function claude::prune::gc --description "Delete orphaned ~/.claude/projects session dirs (no matching real directory), after one batch confirmation"
    set -l orphans (claude::prune::_orphans)
    if test (count $orphans) -eq 0
        echo "Nothing to do."
        return 0
    end

    echo "About to delete "(count $orphans)" orphaned session dirs:"
    for d in $orphans
        echo "  $d"
    end
    echo -n "total size: "
    du -sch $orphans 2>/dev/null | tail -1 | string split -f1 \t
    echo ""

    if not gum confirm "Delete all of the above?"
        echo "Aborted — nothing removed."
        return 1
    end

    for d in $orphans
        rm -rf -- $d
    end
    echo "Removed "(count $orphans)" session dirs."
end
