function claude::sandbox::model::clear --description "Remove the per-worktree model override for sandboxed sessions"
    argparse 'h/help' -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: claude::sandbox::model::clear"
        echo ""
        echo "Removes the \"model\" key from <worktree>/.claude/settings.local.json"
        echo "(deleting the file if that was its only key). Sandboxed sessions in this"
        echo "worktree fall back to the image's default model on the next launch."
        return 0
    end

    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l settings_file $toplevel/.claude/settings.local.json
    if not test -f $settings_file
        echo "No per-worktree model override set."
        return 0
    end

    set -l tmp (mktemp)
    jq 'del(.model)' $settings_file >$tmp
    or begin
        rm -f $tmp
        return 1
    end

    if jq -e '. == {}' $tmp >/dev/null
        rm -f $tmp
        rm -f $settings_file
    else
        mv $tmp $settings_file
    end

    echo ">> Per-worktree model override cleared."
end
