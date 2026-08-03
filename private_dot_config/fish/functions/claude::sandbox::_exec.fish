function claude::sandbox::_exec --description "Run a bash script inside a throwaway review-sandbox container as <identity> (reviewer/author), with <worktree> mounted rw at /workspace. Used for one-shot git/gh operations (see pr::_push_review_artifacts, work::push), not interactive claude sessions."
    set -l identity $argv[1]
    set -l worktree $argv[2]
    set -l script $argv[3]

    claude::sandbox::_check $identity
    or return 1

    set -l token_file ~/.config/claude-sandbox/secrets/gh-$identity-token
    set -l gitconfig_file ~/.config/claude-sandbox/gitconfig-$identity

    # keep-id:uid=1000,gid=1000: see claude::sandbox::_run for why bare
    # keep-id isn't enough when the host UID doesn't happen to be 1000.
    podman run --rm --userns=keep-id:uid=1000,gid=1000 \
        -v "$worktree":/workspace:Z \
        -w /workspace \
        -v "$gitconfig_file":/home/claude/.gitconfig:ro,Z \
        -e GH_TOKEN=(cat $token_file) \
        (claude::sandbox::_worktree_git_mount $worktree) \
        --entrypoint bash \
        claude-review-sandbox:latest -c "$script"
end
