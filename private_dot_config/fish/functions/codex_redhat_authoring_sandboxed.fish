function codex_redhat_authoring_sandboxed --description "Run codex (OpenAI API key auth) as the author identity inside the review sandbox container against the current worktree"
    set -g __claude_sandbox_extra_args \
        -e GIT_AUTHOR_NAME="Petr Muller" -e GIT_AUTHOR_EMAIL=muller@redhat.com \
        -e GIT_COMMITTER_NAME="Petr Muller" -e GIT_COMMITTER_EMAIL=muller@redhat.com

    codex::sandbox::_run author $argv
    set -l status_code $status
    set -e __claude_sandbox_extra_args
    return $status_code
end
