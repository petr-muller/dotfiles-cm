function claude::sandbox::_worktree_key --description "Encode an absolute worktree path into the flat key used for per-worktree sandbox state (Claude Code project dirs, kubeconfigs, ...)"
    string replace -ra '[/.]' '-' $argv[1]
end
