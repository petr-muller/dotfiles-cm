function claude::sandbox::model::show --description "Show the per-worktree model override for sandboxed sessions, if any"
    argparse 'h/help' -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: claude::sandbox::model::show"
        echo ""
        echo "Prints the \"model\" override from <worktree>/.claude/settings.local.json,"
        echo "or says there isn't one."
        return 0
    end

    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l settings_file $toplevel/.claude/settings.local.json
    if not test -f $settings_file
        echo "No per-worktree model override set for $toplevel."
        return 0
    end

    set -l model (jq -r '.model // empty' $settings_file)
    if test -z "$model"
        echo "No \"model\" key in $settings_file."
    else
        echo "$model"
    end
end
