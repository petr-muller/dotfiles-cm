function claude::sandbox::_check --description "Preflight checks for the review sandbox: image built, <identity> (reviewer/author) secrets present"
    set -l identity $argv[1]

    if not podman image exists claude-review-sandbox:latest
        echo "claude-review-sandbox:latest image not found. Build it with:" >&2
        echo "  podman build -t claude-review-sandbox:latest ~/.config/claude-sandbox/image" >&2
        return 1
    end

    if not test -f ~/.config/claude-sandbox/secrets/gh-$identity-token
        echo "Missing ~/.config/claude-sandbox/secrets/gh-$identity-token ($identity account GitHub token). See ~/.config/claude-sandbox/README.md." >&2
        return 1
    end

    if not test -f ~/.config/claude-sandbox/gitconfig-$identity
        echo "Missing ~/.config/claude-sandbox/gitconfig-$identity ($identity bot git identity). See ~/.config/claude-sandbox/README.md." >&2
        return 1
    end
end
