function pr::summarize::codex --description "Launch codex inside a PR summarize worktree (RH identity only; GPT through EnMaaS by default, --glm for GLM, --deepseek for DeepSeek, --openai for OpenAI directly)"
    argparse -x openai,glm,deepseek 'M/model=' openai glm deepseek -- $argv
    or return 1

    # GPT modes (EnMaaS default, --openai) default to gpt-6-luna; --glm and
    # --deepseek use their enmaas-* profile's pinned model unless -M is given.
    set -l provider_flag
    set -l model_args
    set -q _flag_openai
    and set provider_flag --openai
    if set -q _flag_glm
        set provider_flag --glm
    else if set -q _flag_deepseek
        set provider_flag --deepseek
    else
        set -q _flag_model
        or set _flag_model gpt-6-luna
    end
    set -q _flag_model
    and set model_args --model $_flag_model

    set -l toplevel (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$toplevel"
        echo "Not in a git repository" >&2
        return 1
    end

    set -l parts (string match -r "^$HOME/Projects/Worktrees/github\.com/([^/]+)/([^/]+)/([0-9]+)-summarize\$" -- $toplevel)
    if test (count $parts) -lt 4
        echo "Not in a PR summarize worktree (expected ~/Projects/Worktrees/github.com/<org>/<repo>/<N>-summarize): $toplevel" >&2
        return 1
    end
    set -l org $parts[2]
    set -l repo $parts[3]
    set -l pr_number $parts[4]

    if not test -d $HOME/Projects/RH/github.com/$org/$repo
        echo "codex sandbox flows are RH-identity only; no canonical working copy under ~/Projects/RH/github.com/$org/$repo" >&2
        return 1
    end

    set -l title (gh pr view $pr_number --repo $org/$repo --json title -q .title 2>/dev/null)
    if test -z "$title"
        echo "Failed to fetch PR title via gh pr view $pr_number --repo $org/$repo" >&2
        return 1
    end

    if codex::sandbox::_resumable reviewer $toplevel
        echo "Resuming existing session for $toplevel."
        codex_redhat_sandboxed $provider_flag resume --last
        return
    end

    codex_redhat_sandboxed $provider_flag $model_args "Summarizing PR #$pr_number in $org/$repo: $title"
end
