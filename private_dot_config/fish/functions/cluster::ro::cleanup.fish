function cluster::ro::cleanup --description "Remove a read-only ServiceAccount, its RBAC binding and token secret"
    argparse -n cluster::ro::cleanup s/sa= n/namespace= c/context= k/kubeconfig= h/help -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: cluster::ro::cleanup [-s SA_NAME] [-n NAMESPACE] [-c CONTEXT]"
        echo "       cluster::ro::cleanup -k KUBECONFIG"
        echo ""
        echo "  -k KUBECONFIG kubeconfig produced by cluster::ro::create — reads"
        echo "                KUBECONFIG.meta for context/sa/namespace so none of"
        echo "                -s/-n/-c need to be remembered/re-passed. If the"
        echo "                sidecar records mode=delegate (no SA/RBAC was ever"
        echo "                created), this is a no-op."
        echo "  -c CONTEXT    kubeconfig context to act against. Omitted =>"
        echo "                pick interactively from existing contexts."
        echo "  -s SA_NAME    ServiceAccount name (default: muller-agent-reader)"
        echo "  -n NAMESPACE  Namespace it was scoped to (must match the"
        echo "                value passed to cluster::ro::create)."
        echo ""
        echo "Idempotent. Does NOT delete any namespace."
        return 0
    end

    set -l sa_name muller-agent-reader
    set -q _flag_sa; and set sa_name $_flag_sa
    set -l ns ""
    set -q _flag_namespace; and set ns $_flag_namespace
    set -l srcctx
    set -q _flag_context; and set srcctx $_flag_context
    set -l sa_ns_from_meta

    if set -q _flag_kubeconfig
        set -l meta $_flag_kubeconfig.meta
        if not test -f $meta
            echo "No metadata sidecar at '$meta' (expected next to a cluster::ro::create kubeconfig) — pass -s/-n/-c manually instead." >&2
            return 1
        end
        for line in (cat $meta)
            set -l kv (string split -m1 '=' -- $line)
            switch $kv[1]
                case mode
                    if test "$kv[2]" = delegate
                        echo ">> '$_flag_kubeconfig' is a delegated kubeconfig (your own credentials) — no ServiceAccount/RBAC was created, nothing to clean up server-side."
                        return 0
                    end
                case context
                    set srcctx $kv[2]
                case sa
                    set sa_name $kv[2]
                case sa_namespace
                    set sa_ns_from_meta $kv[2]
                case namespace
                    set ns $kv[2]
            end
        end
    end

    set -l kube (command -v oc; or command -v kubectl)
    if test -z "$kube"
        echo "Neither 'oc' nor 'kubectl' found on PATH." >&2
        return 1
    end

    set -l contexts ($kube config get-contexts -o name)
    if test (count $contexts) -eq 0
        echo "No contexts found in kubeconfig." >&2
        return 1
    end
    if test -z "$srcctx"
        set srcctx (printf '%s\n' $contexts | sort | gum filter --placeholder "Pick the cluster context to clean up...")
        if test -z "$srcctx"
            echo "No context selected." >&2
            return 1
        end
    else if not contains -- $srcctx $contexts
        echo "Context '$srcctx' not found. Known: "(string join ", " $contexts) >&2
        return 1
    end
    set -l kctx --context=$srcctx
    echo ">> Using context: $srcctx"

    set -l sa_ns
    if test -n "$sa_ns_from_meta"
        set sa_ns $sa_ns_from_meta
    else if test -n "$ns"
        set sa_ns $ns
    else
        # Match how create chose the SA namespace ('ci' or *muller*); the
        # ClusterRoleBinding name embeds it, so it must be the same value.
        set -l all_ns ($kube $kctx get namespaces -o name | string replace 'namespace/' '')
        if test -z "$all_ns"
            echo "Could not list namespaces on context '$srcctx'." >&2
            return 1
        end
        set -l candidates
        if contains -- ci $all_ns
            set -a candidates ci
        end
        for n in $all_ns
            if string match -q '*muller*' -- $n
                set -a candidates $n
            end
        end
        if test (count $candidates) -eq 0
            echo "No eligible SA namespace ('ci' or *muller*) found on context '$srcctx'." >&2
            return 1
        end
        set sa_ns (printf '%s\n' $candidates | sort -u | gum filter --placeholder "Namespace the read-only SA lives in...")
        if test -z "$sa_ns"
            echo "No namespace selected." >&2
            return 1
        end
    end
    set -l binding cluster-ro-sa-$sa_ns-$sa_name
    set -l mon_binding $binding-monitoring

    set -l impersonate
    if not $kube $kctx auth can-i delete serviceaccounts -n $sa_ns 2>/dev/null | string match -q yes
        echo ">> Current user cannot delete resources — will use --as system:admin"
        set impersonate --as=system:admin
    end

    echo ">> Removing read-only SA '$sa_name' (ns '$sa_ns')"

    if test -n "$ns"
        $kube $kctx $impersonate -n $ns delete rolebinding $binding --ignore-not-found
    else
        $kube $kctx $impersonate delete clusterrolebinding $binding --ignore-not-found
    end
    $kube $kctx $impersonate delete clusterrolebinding $mon_binding --ignore-not-found
    $kube $kctx $impersonate -n $sa_ns delete serviceaccount $sa_name --ignore-not-found

    echo ">> Done. Removed the ServiceAccount and its RBAC bindings only."
end
