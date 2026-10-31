function quick::pr --description "Review a PR with codex (DeepSeek): init, codex, push, open"
    if test (count $argv) -ne 1
        echo "Usage: quick::pr <PR-URL|N>" >&2
        return 1
    end

    pr::review::init $argv[1]
    or return 1

    pr::review::codex --deepseek
    pr::review::push
    or return 1
    pr::review::open
end
