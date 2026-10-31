function quick::work --description "Start work with codex (DeepSeek): init, codex"
    if test (count $argv) -gt 1
        echo "Usage: quick::work [WORK-ID]" >&2
        return 1
    end

    work::init $argv
    or return 1

    work::codex --deepseek
end
