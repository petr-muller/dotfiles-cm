function claude_redhat_authoring_sandboxed --description "Run claude (RH/EnMaaS auth) as the author identity inside the review sandbox container against the current worktree"
    set -l key_file ~/.config/claude-sandbox/secrets/enmaas-api-key
    if not test -r $key_file
        echo "claude_redhat_authoring_sandboxed: missing EnMaaS key at $key_file" >&2
        return 1
    end
    set -g __claude_sandbox_extra_args \
        -e ANTHROPIC_BASE_URL=https://api.enmaas.devshift.net \
        -e ANTHROPIC_API_KEY=(cat $key_file) \
        -e CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1 \
        -e GIT_AUTHOR_NAME="Petr Muller" -e GIT_AUTHOR_EMAIL=muller@redhat.com \
        -e GIT_COMMITTER_NAME="Petr Muller" -e GIT_COMMITTER_EMAIL=muller@redhat.com

    claude::sandbox::_run author $argv
    set -l status_code $status
    set -e __claude_sandbox_extra_args
    return $status_code
end
