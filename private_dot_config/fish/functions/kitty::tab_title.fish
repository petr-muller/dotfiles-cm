function kitty::tab_title --description "Set the current kitty tab title (no-op outside kitty)"
    set -q KITTY_WINDOW_ID; or return 0
    command -q kitten; or return 0
    if not kitten @ --password tab-title set-tab-title -- "$argv" 2>/dev/null
        echo "kitty::tab_title: failed (remote control off? restart kitty after enabling it)" >&2
    end
    return 0
end
