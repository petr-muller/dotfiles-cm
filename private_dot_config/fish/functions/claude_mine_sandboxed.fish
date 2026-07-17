function claude_mine_sandboxed --description "Run claude (personal/subscription auth) inside the review sandbox container against the current worktree"
    set -l creds_src ~/.claude/.credentials.json
    if not test -f $creds_src
        echo "Missing $creds_src (Claude subscription credentials)" >&2
        return 1
    end

    set -l tmp (mktemp -d)
    cp $creds_src $tmp/.credentials.json
    chmod 600 $tmp/.credentials.json

    set -g __claude_sandbox_extra_args \
        -v "$tmp/.credentials.json":/home/claude/.claude/.credentials.json:Z

    claude::sandbox::_run reviewer $argv
    set -l status_code $status

    set -e __claude_sandbox_extra_args
    rm -rf $tmp

    return $status_code
end
