function claude_redhat_authoring_sandboxed --description "Run claude (RH/Vertex auth) as the author identity inside the review sandbox container against the current worktree"
    set -g __claude_sandbox_extra_args \
        -v ~/.config/gcloud/application_default_credentials.json:/home/claude/.config/gcloud/application_default_credentials.json:ro,Z \
        -e GOOGLE_APPLICATION_CREDENTIALS=/home/claude/.config/gcloud/application_default_credentials.json \
        -e CLAUDE_CODE_USE_VERTEX=1 \
        -e CLOUD_ML_REGION=global \
        -e ANTHROPIC_VERTEX_PROJECT_ID=itpc-gcp-hcm-pe-eng-claude \
        -e GIT_AUTHOR_NAME="Petr Muller" -e GIT_AUTHOR_EMAIL=muller@redhat.com \
        -e GIT_COMMITTER_NAME="Petr Muller" -e GIT_COMMITTER_EMAIL=muller@redhat.com

    claude::sandbox::_run author $argv
    set -l status_code $status
    set -e __claude_sandbox_extra_args
    return $status_code
end
