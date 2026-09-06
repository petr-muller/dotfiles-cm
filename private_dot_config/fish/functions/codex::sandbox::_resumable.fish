function codex::sandbox::_resumable --description "Check whether <identity>'s sandbox state has a continuable Codex session for <toplevel>. Internal, used by pr::review::codex, pr::summarize::codex, issue::triage::codex, work::codex before deciding whether to pass `resume --last`. Safe because codex::sandbox::_run keys the mounted sessions dir per identity+worktree, so any session file found here belongs to this worktree."
    set -l identity $argv[1]
    set -l toplevel $argv[2]

    set -l worktree_key (claude::sandbox::_worktree_key $toplevel)
    set -l sessions_dir $HOME/.config/claude-sandbox/state/codex-sessions-$identity-$worktree_key

    test -d $sessions_dir
    or return 1

    test (count (find $sessions_dir -type f -name '*.jsonl' 2>/dev/null)) -gt 0
end
