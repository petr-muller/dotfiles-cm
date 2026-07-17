function claude_mine_authoring_sandboxed --description "Run claude (personal/subscription auth) as the author identity inside the review sandbox container against the current worktree"
    set -l creds_src ~/.claude/.credentials.json
    if not test -f $creds_src
        echo "Missing $creds_src (Claude subscription credentials)" >&2
        return 1
    end

    set -l tmp (mktemp -d)
    cp $creds_src $tmp/.credentials.json
    chmod 600 $tmp/.credentials.json

    set -g __claude_sandbox_extra_args \
        -v "$tmp/.credentials.json":/home/claude/.claude/.credentials.json:Z \
        -e GIT_AUTHOR_NAME="Petr Muller" -e GIT_AUTHOR_EMAIL=petr@muller.dev \
        -e GIT_COMMITTER_NAME="Petr Muller" -e GIT_COMMITTER_EMAIL=petr@muller.dev

    claude::sandbox::_run author $argv
    set -l status_code $status

    set -e __claude_sandbox_extra_args
    rm -rf $tmp

    return $status_code
end
