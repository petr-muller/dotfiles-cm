function claude::sandbox::_run --description "Run the claude-review-sandbox image against the current worktree as <identity> (reviewer/author); internal, called by claude_{redhat,mine}_{,authoring_}sandboxed. Mode-specific mounts/env come in via the caller-set \$__claude_sandbox_extra_args list."
    set -l identity $argv[1]
    set -l args $argv[2..-1]

    claude::sandbox::_check $identity
    or return 1

    set -l token_file ~/.config/claude-sandbox/secrets/gh-$identity-token
    set -l gitconfig_file ~/.config/claude-sandbox/gitconfig-$identity

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
        -v "$worktree":/workspace:Z \
        -w /workspace \
        -v "$gitconfig_file":/home/claude/.gitconfig:ro,z \
        -v ~/.claude/commands:/home/claude/.claude/commands:ro,z \
        -v ~/.claude/plugins:/home/claude/.claude/plugins:ro,z \
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
        $__claude_sandbox_extra_args

    podman run $podman_args claude-review-sandbox:latest $args
end
