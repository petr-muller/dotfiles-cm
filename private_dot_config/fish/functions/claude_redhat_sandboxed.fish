function claude_redhat_sandboxed --description "Run claude (RH/EnMaaS auth) inside the review sandbox container against the current worktree"
    set -l key_file ~/.config/claude-sandbox/secrets/enmaas-api-key
    if not test -r $key_file
        echo "claude_redhat_sandboxed: missing EnMaaS key at $key_file" >&2
        return 1
    end
    set -g __claude_sandbox_extra_args \
        -e ANTHROPIC_BASE_URL=https://api.enmaas.devshift.net \
        -e ANTHROPIC_API_KEY=(cat $key_file) \
        -e CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1

    claude::sandbox::_run reviewer $argv
    set -l status_code $status
    set -e __claude_sandbox_extra_args
    return $status_code
end
