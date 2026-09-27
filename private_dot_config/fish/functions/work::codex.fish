function work::codex --description "Launch codex inside a work worktree (RH identity only)"
    argparse --ignore-unknown 'M/model=' -- $argv
    or return 1

    set -q _flag_model
    or set -l _flag_model gpt-6-sol

    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/work-([A-Za-z0-9._-]+)\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in a work worktree (expected ~/Projects/Worktrees/github.com/<org>/<repo>/work-<ID>): $toplevel" >&2
        return 1
    end
    set -l org $parts[2]
    set -l repo $parts[3]

    if not test -d $HOME/Projects/RH/github.com/$org/$repo
        echo "codex sandbox flows are RH-identity only; no canonical working copy under ~/Projects/RH/github.com/$org/$repo" >&2
        return 1
    end

    if codex::sandbox::_resumable author $toplevel
        echo "Resuming existing session for $toplevel."
        codex_redhat_authoring_sandboxed resume --last
        return
    end

    codex_redhat_authoring_sandboxed --model $_flag_model $argv
end
