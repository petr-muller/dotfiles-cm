function claude::sandbox::_run --description "Run the claude-review-sandbox image against the current worktree as <identity> (reviewer/author); internal, called by claude_{redhat,mine}_{,authoring_}sandboxed. Mode-specific mounts/env come in via the caller-set \$__claude_sandbox_extra_args list."
    set -l identity $argv[1]
    set -l args $argv[2..-1]

    claude::sandbox::_check $identity
    or return 1

    set -l token_file ~/.config/claude-sandbox/secrets/gh-$identity-token
    set -l gitconfig_file ~/.config/claude-sandbox/gitconfig-$identity

    # Cap CPU usage for reviewer sessions (review/summarize/triage) — a
    # reviewer building/compiling the repo under test can otherwise pin
    # every host core. author (work::) sessions are left unrestricted since
    # they're the actual work being done.
    set -l cpu_limit_args
    if test "$identity" != author
        set cpu_limit_args --cpus=4
    end

    set -l worktree (pwd)
    set -l worktree_key (claude::sandbox::_worktree_key $worktree)

    # Keyed by the host worktree path (unique per worktree) so different
    # worktrees never share history, but mounted at the *container's* own
    # project-dir name below — Claude Code encodes its project dir from its
    # own cwd, which inside the container is always /workspace (-> encoded
    # "-workspace"), not from the host path. Mounting at the host-path
    # encoding instead would silently miss every write: sessions would land
    # in an unmounted, --rm-discarded directory and never persist.
    set -l project_dir $HOME/.claude/projects/$worktree_key
    mkdir -p $project_dir

    # oc/cluster access: author-only for now, one kubeconfig per worktree
    # (different work::claude worktrees legitimately target different
    # clusters/namespaces at once). Not generated here — pre-create it with
    # `work::kube::create` from inside the worktree (thin wrapper around
    # cluster::ro::create keyed the same way as project_dir above). Mounted
    # only if present so worktrees without one are unaffected.
    set -l kube_mount_args
    set -l kubeconfig_file ~/.config/claude-sandbox/kube/$worktree_key.kubeconfig
    if test "$identity" = author; and test -f $kubeconfig_file
        set kube_mount_args \
            -v "$kubeconfig_file":/home/claude/.kube/config:ro,z \
            -e KUBECONFIG=/home/claude/.kube/config
    end

    # RH JIRA access via acli: both identities, but opt-in per worktree (like
    # kube) rather than on for every session once host credentials exist —
    # claude::sandbox::jira::enable/disable toggle the per-worktree marker.
    # There's no separate bot identity for JIRA (unlike the gh-<identity>
    # tokens), so this exposes *my own* RH JIRA account/permissions inside
    # the sandbox — see ~/.config/claude-sandbox/README.md. entrypoint.sh
    # consumes JIRA_TOKEN once (a non-interactive `acli jira auth login`) and
    # drops it; only JIRA_SITE/JIRA_EMAIL are non-secret and fine to leave
    # set.
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

    # Sandbox-only Claude Code onboarding state — separate per identity,
    # persisted across runs so onboarding only happens once. Bootstrapped
    # with just the two fields that gate the onboarding wizard (taken from
    # the host's ~/.claude.json at the time this was written), not the full
    # file — that also holds oauthAccount/userID/machineID/projects/session
    # state we deliberately keep out of this sandbox.
    set -l state_dir ~/.config/claude-sandbox/state
    mkdir -p $state_dir
    set -l claude_json $state_dir/claude.json-$identity
    if not test -f $claude_json
        echo '{"hasCompletedOnboarding": true, "lastOnboardingVersion": "0.2.74"}' >$claude_json
    end

    # TERM is forced rather than passed through: nonstandard host TERM
    # values (xterm-kitty, wezterm, foot, ...) ship their own terminfo
    # entries with the terminal itself, not via any Linux distro package, so
    # they'd be missing inside the container and cause capability lookups to
    # fail/fall back oddly (weird colors). xterm-256color is guaranteed
    # present and broadly recognized; COLORTERM is still forwarded for real
    # truecolor detection.
    #
    # But forcing TERM this way also blinds Claude Code's own terminal
    # detection, which decides whether Shift+Enter is natively supported by
    # checking `TERM.includes("kitty") || process.env.KITTY_WINDOW_ID`
    # (confirmed by grepping strings out of the installed claude binary) —
    # with TERM overridden and KITTY_WINDOW_ID unset, it no longer recognizes
    # kitty and Shift+Enter stops inserting a newline. Forwarding the actual
    # terminal-identity env vars (which Claude Code also checks per-terminal:
    # KITTY_WINDOW_ID, TERM_PROGRAM, WT_SESSION, KONSOLE_VERSION,
    # VTE_VERSION) restores that detection without touching TERM/terminfo.
    #
    # keep-id:uid=1000,gid=1000 (not bare keep-id): bare keep-id maps the
    # invoking host UID to itself inside the container, but the image's
    # `claude` user is hardcoded to UID/GID 1000 regardless of the host
    # account's actual UID — on hosts where that differs (e.g. UID 11227),
    # bare keep-id leaves `claude` unable to write bind-mounted, host-owned
    # paths (EACCES on transcript writes). Mapping the host UID onto 1000
    # explicitly makes `claude` the owner as seen from inside the container.
    set -l podman_args \
        --rm -it --userns=keep-id:uid=1000,gid=1000 \
        $cpu_limit_args \
        -v "$worktree":/workspace:Z \
        -w /workspace \
        -v "$gitconfig_file":/home/claude/.gitconfig:ro,z \
        -v ~/.claude/commands:/home/claude/.claude/commands:ro,z \
        -v ~/.claude/plugins:/home/claude/.claude/plugins:ro,z \
        -v ~/.claude/skills:/home/claude/.claude/skills:ro,z \
        -v ~/.claude/CLAUDE.md:/home/claude/.claude/CLAUDE.md:ro,z \
        -v ~/.claude/statusline-command.sh:/home/claude/.claude/statusline-command.sh:ro,z \
        -v ~/.claude/slogans.txt:/home/claude/.claude/slogans.txt:ro,z \
        -v "$project_dir":/home/claude/.claude/projects/-workspace:Z \
        -v "$claude_json":/home/claude/.claude.json:z \
        -e GH_TOKEN=(cat $token_file) \
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

    podman run $podman_args claude-review-sandbox:latest $args
end
