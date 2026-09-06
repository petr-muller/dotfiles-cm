function codex::sandbox::_run --description "Run codex (OpenAI) inside the review-sandbox image against the current worktree as <identity> (reviewer/author); internal, called by codex_redhat_{,authoring_}sandboxed. Mode-specific env comes in via the caller-set \$__claude_sandbox_extra_args list (shared with claude::sandbox::_run)."
    set -l identity $argv[1]
    set -l args $argv[2..-1]

    codex::sandbox::_check $identity
    or return 1

    set -l token_file ~/.config/claude-sandbox/secrets/gh-$identity-token
    set -l gitconfig_file ~/.config/claude-sandbox/gitconfig-$identity
    set -l openai_key_file ~/.config/claude-sandbox/secrets/openai-api-key

    # Same CPU policy as claude::sandbox::_run: cap reviewer sessions, leave
    # author (work::) sessions unrestricted.
    set -l cpu_limit_args
    if test "$identity" != author
        set cpu_limit_args --cpus=4
    end

    set -l worktree (pwd)
    set -l worktree_key (claude::sandbox::_worktree_key $worktree)

    # Codex's own session/rollout history, one file per session. Keyed by
    # identity *and* worktree (like Claude's project_dir below) — mounted at
    # the container's fixed /home/claude/.codex/sessions regardless of which
    # host worktree is active, so `codex resume --last` (which just picks
    # the most recent file under there) only ever sees this worktree's own
    # sessions instead of silently reattaching a different worktree's.
    set -l state_dir ~/.config/claude-sandbox/state
    set -l codex_sessions_dir $state_dir/codex-sessions-$identity-$worktree_key
    mkdir -p $codex_sessions_dir

    set -l kube_mount_args
    set -l kubeconfig_file ~/.config/claude-sandbox/kube/$worktree_key.kubeconfig
    if test "$identity" = author; and test -f $kubeconfig_file
        set kube_mount_args \
            -v "$kubeconfig_file":/home/claude/.kube/config:ro,z \
            -e KUBECONFIG=/home/claude/.kube/config
    end

    set -l jira_mount_args
    set -l jira_token_file ~/.config/claude-sandbox/secrets/jira-token
    set -l jira_config_file ~/.config/claude-sandbox/jira-config
    set -l jira_enabled_file ~/.config/claude-sandbox/jira/$worktree_key.enabled
    if test -f $jira_token_file; and test -f $jira_config_file; and test -f $jira_enabled_file
        set -l jira_site (string match -rg '^site=(.*)$' <$jira_config_file)
        set -l jira_email (string match -rg '^email=(.*)$' <$jira_config_file)
        set jira_mount_args \
            -e JIRA_TOKEN=(cat $jira_token_file) \
            -e JIRA_SITE="$jira_site" \
            -e JIRA_EMAIL="$jira_email"
    end

    # See claude::sandbox::_run for the TERM/keep-id rationale — identical
    # here, same image/entrypoint.
    set -l podman_args \
        --rm -it --userns=keep-id:uid=1000,gid=1000 \
        $cpu_limit_args \
        -v "$worktree":/workspace:Z \
        -w /workspace \
        -v "$gitconfig_file":/home/claude/.gitconfig:ro,z \
        -v ~/.claude/skills:/home/claude/.agents/skills:ro,z \
        -v ~/.claude/CLAUDE.md:/home/claude/.codex/AGENTS.md:ro,z \
        -v "$codex_sessions_dir":/home/claude/.codex/sessions:Z \
        -e GH_TOKEN=(cat $token_file) \
        -e OPENAI_API_KEY=(cat $openai_key_file) \
        -e TERM=xterm-256color \
        -e COLORTERM="$COLORTERM" \
        -e KITTY_WINDOW_ID="$KITTY_WINDOW_ID" \
        -e TERM_PROGRAM="$TERM_PROGRAM" \
        -e TERM_PROGRAM_VERSION="$TERM_PROGRAM_VERSION" \
        -e WT_SESSION="$WT_SESSION" \
        -e KONSOLE_VERSION="$KONSOLE_VERSION" \
        -e VTE_VERSION="$VTE_VERSION" \
        (claude::sandbox::_worktree_git_mount $worktree) \
        $kube_mount_args \
        $jira_mount_args \
        $__claude_sandbox_extra_args

    podman run $podman_args claude-review-sandbox:latest codex $args
end
