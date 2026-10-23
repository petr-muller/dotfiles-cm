function codex_redhat_sandboxed --description "Run codex (GPT through EnMaaS by default; leading --glm for GLM / --deepseek for DeepSeek through EnMaaS, --openai for OpenAI directly) inside the review sandbox container against the current worktree"
    switch "$argv[1]"
        case --openai --glm --deepseek
            set -g __codex_sandbox_provider (string replace -- -- '' $argv[1])
            set -e argv[1]
    end

    codex::sandbox::_run reviewer $argv
    set -l status_code $status
    set -e __codex_sandbox_provider
    return $status_code
end
