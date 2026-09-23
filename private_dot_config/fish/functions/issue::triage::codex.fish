function issue::triage::codex --description "Launch codex inside an issue triage worktree (RH identity only)"
    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/([0-9]+)-triage\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in an issue triage worktree (expected ~/Projects/Worktrees/github.com/<org>/<repo>/<N>-triage): $toplevel" >&2
        return 1
    end
    set -l org $parts[2]
    set -l repo $parts[3]
    set -l issue_number $parts[4]

    if not test -d $HOME/Projects/RH/github.com/$org/$repo
        echo "codex sandbox flows are RH-identity only; no canonical working copy under ~/Projects/RH/github.com/$org/$repo" >&2
        return 1
    end

    set -l title (gh issue view $issue_number --repo $org/$repo --json title -q .title 2>/dev/null)
    if test -z "$title"
        echo "Failed to fetch issue title via gh issue view $issue_number --repo $org/$repo" >&2
        return 1
    end

    if codex::sandbox::_resumable reviewer $toplevel
        echo "Resuming existing session for $toplevel."
        codex_redhat_sandboxed resume --last
        return
    end

    # Codex runs YOLO on a fresh session and infers the task from this prompt,
    # so point it at refresh explicitly when triage artifacts already exist.
    set -l prompt "Triaging issue #$issue_number in $org/$repo: $title"
    if test -f $toplevel/TRIAGE.md
        echo "TRIAGE.md present: steering codex to \$triage:refresh."
        set prompt "$prompt

TRIAGE.md already exists in this worktree from an earlier triage of this issue. Do NOT start a new triage. Run the \$triage:refresh skill (/home/claude/.agents/skills/triage/skills/refresh/SKILL.md) to inspect issue activity since that triage and update the artifacts or recommend a full re-triage."
    end

    codex_redhat_sandboxed "$prompt"
end
