function work::kube::create --description "Generate this work worktree's kubeconfig, for work::claude (author identity) to mount"
    argparse --ignore-unknown 'delegate' 'h/help' -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: work::kube::create [cluster::ro::create flags...]"
        echo "       work::kube::create --delegate [-c CONTEXT]"
        echo ""
        echo "Default: mints a short-lived, read-only (cluster-reader) kubeconfig"
        echo "via cluster::ro::create — requires permission to create"
        echo "ServiceAccounts/RBAC on the target cluster. All cluster::ro::create"
        echo "flags (-c/-n/-s/-d) pass through; see cluster::ro::create -h."
        echo ""
        echo "  --delegate   Skip SA/RBAC creation — instead flatten YOUR OWN"
        echo "               current credentials for one context into the"
        echo "               worktree kubeconfig. Use when you can't create"
        echo "               SAs/RBAC on the target cluster. NOT scoped to"
        echo "               read-only: the sandboxed session gets whatever"
        echo "               access you have there."
        echo "  -c CONTEXT   With --delegate: which context to delegate."
        echo "               Omitted => pick interactively."
        return 0
    end

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

    set -l kube_dir ~/.config/claude-sandbox/kube
    mkdir -p $kube_dir
    chmod 700 $kube_dir
    set -l out $kube_dir/(claude::sandbox::_worktree_key $toplevel).kubeconfig

    if not set -q _flag_delegate
        cluster::ro::create -o $out $argv
        return $status
    end

    # --delegate: flatten the caller's own credentials for one context,
    # bypassing the SA/RBAC (cluster::ro::create) path entirely — for
    # clusters where the caller can't create ServiceAccounts/RoleBindings.
    # No scoping applied here: the sandboxed session ends up with whatever
    # access the delegated context already grants.
    argparse 'c/context=' -- $argv
    or return 2

    set -l kube (command -v oc; or command -v kubectl)
    if test -z "$kube"
        echo "Neither 'oc' nor 'kubectl' found on PATH." >&2
        return 1
    end

    set -l ctx
    if set -q _flag_context
        set ctx $_flag_context
    else
        set -l contexts ($kube config get-contexts -o name)
        if test (count $contexts) -eq 0
            echo "No contexts found in kubeconfig." >&2
            return 1
        end
        set ctx (printf '%s\n' $contexts | sort | gum filter --placeholder "Pick the context to delegate...")
        if test -z "$ctx"
            echo "No context selected." >&2
            return 1
        end
    end

    echo ">> WARNING: delegating YOUR OWN credentials for context '$ctx' into the sandbox — not read-only, the sandboxed session gets whatever access you have there." >&2

    set -l old_umask (umask)
    umask 077
    $kube config view --raw --minify --flatten --context=$ctx >$out
    set -l ok $status
    umask $old_umask
    if test $ok -ne 0
        rm -f $out
        echo "Failed to extract context '$ctx' from your kubeconfig." >&2
        return 1
    end
    chmod 600 $out

    begin
        printf 'mode=delegate\n'
        printf 'context=%s\n' $ctx
    end > $out.meta
    chmod 600 $out.meta

    echo ">> Wrote delegated kubeconfig ($ctx, your own credentials): $out"
    echo "   Tear down: work::kube::cleanup (no server-side cleanup needed — nothing was created)"
end
