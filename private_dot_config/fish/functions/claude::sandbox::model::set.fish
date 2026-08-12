function claude::sandbox::model::set --description "Set the default Claude Code model for sandboxed sessions in this worktree"
    argparse 'h/help' -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: claude::sandbox::model::set <model> [worktree-path]"
        echo ""
        echo "Writes/updates the \"model\" key in <worktree>/.claude/settings.local.json"
        echo "so sandboxed sessions started in this worktree (claude_{redhat,mine}_{,authoring_}sandboxed)"
        echo "come up already on <model>, instead of needing /model after every launch."
        echo ""
        echo "This works because the whole worktree is bind-mounted into the container"
        echo "(claude::sandbox::_run: -v \"\$worktree\":/workspace) and Claude Code reads"
        echo "project-local settings from cwd/.claude/settings.local.json, which take"
        echo "precedence over the image's baked-in settings.json. The file lives on the"
        echo "host worktree, not in the ephemeral container, so it survives --rm and"
        echo "even git reset --hard (it's untracked)."
        echo ""
        echo "<model> is whatever Claude Code's own /model accepts (e.g. opus, sonnet,"
        echo "or a full model id)."
        echo ""
        echo "[worktree-path] defaults to the current git worktree's toplevel; pass it"
        echo "explicitly to target a worktree you haven't cd'd into yet."
        echo ""
        echo "Takes effect on the next sandboxed launch in this worktree, not the"
        echo "currently running session. Inspect with claude::sandbox::model::show,"
        echo "remove with claude::sandbox::model::clear."
        return 0
    end

    if test (count $argv) -lt 1; or test (count $argv) -gt 2
        echo "Usage: claude::sandbox::model::set <model> [worktree-path]" >&2
        return 2
    end
    set -l model $argv[1]

    set -l toplevel
    if test (count $argv) -eq 2
        set toplevel $argv[2]
    else
        set toplevel (git rev-parse --show-toplevel 2>/dev/null)
        if test -z "$toplevel"
            echo "Not in a git repository" >&2
            return 1
        end
    end

    set -l settings_file $toplevel/.claude/settings.local.json
    mkdir -p (dirname $settings_file)

    set -l tmp (mktemp)
    if test -f $settings_file
        jq --arg m "$model" '.model = $m' $settings_file >$tmp
        or begin
            rm -f $tmp
            return 1
        end
    else
        jq -n --arg m "$model" '{model: $m}' >$tmp
        or begin
            rm -f $tmp
            return 1
        end
    end
    mv $tmp $settings_file

    set -l exclude_file (git -C $toplevel rev-parse --git-path info/exclude)
    if not grep -qxF -- .claude/settings.local.json $exclude_file 2>/dev/null
        echo .claude/settings.local.json >>$exclude_file
    end

    echo ">> Sandboxed sessions in this worktree will default to model '$model' (from next launch)."
end
