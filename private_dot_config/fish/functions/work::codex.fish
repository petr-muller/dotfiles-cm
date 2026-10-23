function work::codex --description "Launch codex inside a work worktree (RH identity only; GPT through EnMaaS by default, --glm for GLM, --deepseek for DeepSeek, --openai for OpenAI directly)"
    argparse --ignore-unknown -x openai,glm,deepseek 'M/model=' openai glm deepseek -- $argv
    or return 1

    # GPT modes (EnMaaS default, --openai) default to gpt-6.1-sol; --glm and
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
        or set _flag_model gpt-6.1-sol
    end
    set -q _flag_model
    and set model_args --model $_flag_model

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
        codex_redhat_authoring_sandboxed $provider_flag resume --last
        return
    end

    codex_redhat_authoring_sandboxed $provider_flag $model_args $argv
end
