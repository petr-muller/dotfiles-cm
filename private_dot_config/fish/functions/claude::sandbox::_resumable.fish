function claude::sandbox::_resumable --description "Check whether <identity>'s sandbox state has a continuable session for <toplevel>. Internal, used by pr::review::claude, pr::summarize::claude, issue::triage::claude, work::claude before deciding whether to pass --continue. Needed because inside the container cwd is always /workspace, so <identity>'s claude.json-<identity> only ever remembers the most recently used worktree's session under that single key — passing --continue blindly fails with 'No conversation found to continue' whenever a different worktree was used more recently under the same identity, or when claude.json-<identity> was only just bootstrapped and has no project history yet."
    set -l identity $argv[1]
    set -l toplevel $argv[2]

    set -l state_file $HOME/.config/claude-sandbox/state/claude.json-$identity
    test -f $state_file
    or return 1

    set -l last_session_id (jq -r '.projects["/workspace"].lastSessionId // empty' $state_file 2>/dev/null)
    test -n "$last_session_id"
    or return 1

    set -l project_dir $HOME/.claude/projects/(string replace -ra '[/.]' '-' $toplevel)
    test -f "$project_dir/$last_session_id.jsonl"
end
