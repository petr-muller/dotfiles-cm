function pr::review::codex --description "Launch codex inside a PR review worktree (RH identity only)"
    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/([0-9]+)-review\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in a PR review worktree (expected ~/Projects/Worktrees/github.com/<org>/<repo>/<N>-review): $toplevel" >&2
        return 1
    end
    set -l org $parts[2]
    set -l repo $parts[3]
    set -l pr_number $parts[4]

    if not test -d $HOME/Projects/RH/github.com/$org/$repo
        echo "codex sandbox flows are RH-identity only; no canonical working copy under ~/Projects/RH/github.com/$org/$repo" >&2
        return 1
    end

    set -l meta (gh pr view $pr_number --repo $org/$repo --json title,author -q '.title, .author.login' 2>/dev/null)
    set -l title $meta[1]
    set -l author $meta[2]
    if test -z "$title"
        echo "Failed to fetch PR title via gh pr view $pr_number --repo $org/$repo" >&2
        return 1
    end

    if codex::sandbox::_resumable reviewer $toplevel
        echo "Resuming existing session for $toplevel."
        codex_redhat_sandboxed resume --last
        return
    end

    # Codex runs YOLO on a fresh session and infers the task from this prompt,
    # so name the intended skill explicitly instead of letting it guess:
    # existing review artifacts => refresh; dependency-bot/bump PR => depbump.
    set -l skills /home/claude/.agents/skills/review/skills
    set -l prompt "Reviewing PR #$pr_number in $org/$repo: $title"
    if test -f $toplevel/REVIEW.md
        echo "REVIEW.md present: steering codex to \$review:refresh."
        set prompt "$prompt

REVIEW.md already exists in this worktree from an earlier review of this PR. Do NOT start a new review. Run the \$review:refresh skill ($skills/refresh/SKILL.md) to inspect PR activity since that review and update the artifacts or recommend a full re-review."
    else if string match -qri '^(app/)?(dependabot|renovate)(\[bot\])?$' -- $author
        or string match -qri '^(\S+\(deps[^)]*\)!?:\s*)?bump\s' -- $title
        echo "Dependency bump detected (author: $author): steering codex to \$review:depbump."
        set prompt "$prompt

This PR is a dependency bump (author: $author). Review it with the \$review:depbump skill ($skills/depbump/SKILL.md) rather than a generic full code review."
    end

    codex_redhat_sandboxed "$prompt"
end
