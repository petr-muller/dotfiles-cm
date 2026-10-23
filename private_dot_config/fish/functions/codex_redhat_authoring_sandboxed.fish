function codex_redhat_authoring_sandboxed --description "Run codex (GPT through EnMaaS by default; leading --glm for GLM / --deepseek for DeepSeek through EnMaaS, --openai for OpenAI directly) as the author identity inside the review sandbox container against the current worktree"
    switch "$argv[1]"
        case --openai --glm --deepseek
            set -g __codex_sandbox_provider (string replace -- -- '' $argv[1])
            set -e argv[1]
    end

    set -g __claude_sandbox_extra_args \
        -e GIT_AUTHOR_NAME="Petr Muller" -e GIT_AUTHOR_EMAIL=muller@redhat.com \
        -e GIT_COMMITTER_NAME="Petr Muller" -e GIT_COMMITTER_EMAIL=muller@redhat.com

    codex::sandbox::_run author $argv
    set -l status_code $status
    set -e __claude_sandbox_extra_args
    set -e __codex_sandbox_provider
    return $status_code
end
