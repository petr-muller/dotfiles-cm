function quick::summarize --description "Summarize a PR with codex (DeepSeek) in a throwaway worktree: init, codex, cleanup"
    if test (count $argv) -ne 1
        echo "Usage: quick::summarize <PR-URL|N>" >&2
        return 1
    end

    pr::summarize::init $argv[1]
    or return 1

    pr::summarize::codex --deepseek
    worktree::cleanup
end
