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

    # AGENTS.md = host CLAUDE.md + a note clarifying that inside this sandbox
    # the worktree lives at /workspace (this container's fixed mount point,
    # == its cwd), not at the absolute host path CLAUDE.md's "Stay inside
    # the worktree" section refers to — that host path isn't mounted here at
    # all. Without this, an agent that treats those absolute paths literally
    # (rather than inferring from its own cwd, like Claude Code does) will
    # `test -d`/`namei` the host path, find nothing, and wrongly conclude the
    # worktree is missing/unwritable. Regenerated every run so edits to the
    # host CLAUDE.md are picked up.
    set -l agents_file $state_dir/codex-agents-$identity-$worktree_key.md
    cat ~/.claude/CLAUDE.md >$agents_file
    printf '\n\n# Codex sandbox path note\n\nThis session runs inside the codex sandbox container. The worktree described above by its host path (e.g. under `~/Projects/Worktrees/...`) is bind-mounted into this container at the fixed path `/workspace`, which is also this session'"'"'s cwd. The host path itself does not exist inside this container — do not `test -d`/`namei`/`cd` to it. Treat `/workspace` (equivalently `.`/cwd) as that worktree and read/write files there directly.\n' >>$agents_file

    # Codex runs YOLO and, left to itself, publishes to GitHub (posts
    # reviews/comments, pushes, opens PRs) unprompted. Anything GitHub-visible
    # must be an explicit user request in the session itself. This also
    # overrides CLAUDE.md's "work::claude sessions push and open PRs directly"
    # guidance for Codex author sessions.
    printf '\n\n# Codex: never publish without an explicit request (IMPORTANT)\n\nThis rule overrides anything above, including the CLAUDE.md guidance that `work::*` sessions push and open PRs directly.\n\nDo NOT take any GitHub-visible or otherwise outward-facing action unless the user explicitly asked for that specific action in this session. That includes: `git push`; `gh pr create`/`gh pr review`/`gh pr comment`/`gh pr merge`/`gh pr close`/`gh pr edit`; `gh issue create`/`gh issue comment`/`gh issue edit`/`gh issue close`; `gh api` calls with a non-GET method; adding labels, reactions, or review-thread resolutions; and running the `review:autopilot` or `review:watch` skills (which post to GitHub). The initial prompt describing the task (e.g. "Reviewing PR #N", "Triaging issue #N") is NOT such a request, and neither is a skill whose steps mention posting.\n\nWhen the work is done, stop at local artifacts (e.g. `REVIEW.md`/`REVIEW.html`, `TRIAGE.md`/`TRIAGE.html`, local commits) and tell the user what you would publish and the exact command; then wait for them to say so. Read-only `gh` usage (`gh pr view`, `gh pr diff`, `gh api` GETs, etc.) is fine.\n' >>$agents_file

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
    # Persistent Go caches, dedicated (not the host's) so a compromised
    # sandbox can't poison host builds. Worktree is always /workspace, so
    # cache keys stay stable across worktrees.
    set -l go_cache_root ~/.cache/claude-sandbox
    mkdir -p $go_cache_root/go-build $go_cache_root/go-mod

    set -l podman_args \
        --rm -it --userns=keep-id:uid=1000,gid=1000 \
        $cpu_limit_args \
        -v "$worktree":/workspace:Z \
        -v $go_cache_root/go-build:/home/claude/.cache/go-build:z \
        -v $go_cache_root/go-mod:/home/claude/go/pkg/mod:z \
        -w /workspace \
        -v "$gitconfig_file":/home/claude/.gitconfig:ro,z \
        -v ~/.claude/skills:/home/claude/.agents/skills:ro,z \
        -v "$agents_file":/home/claude/.codex/AGENTS.md:ro,z \
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
