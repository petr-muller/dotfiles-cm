function codex_redhat_sandboxed --description "Run codex (OpenAI API key auth) inside the review sandbox container against the current worktree"
    codex::sandbox::_run reviewer $argv
end
