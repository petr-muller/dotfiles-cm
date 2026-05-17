function cluster::ro::cleanup --description "Remove a read-only ServiceAccount, its RBAC binding and token secret"
    argparse -n cluster::ro::cleanup s/sa= n/namespace= c/context= h/help -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: cluster::ro::cleanup [-s SA_NAME] [-n NAMESPACE] [-c CONTEXT]"
        echo ""
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
    set -l srcctx
    if set -q _flag_context
        set srcctx $_flag_context
        if not contains -- $srcctx $contexts
            echo "Context '$srcctx' not found. Known: "(string join ", " $contexts) >&2
            return 1
        end
    else
        set srcctx (printf '%s\n' $contexts | sort | gum filter --placeholder "Pick the cluster context to clean up...")
        if test -z "$srcctx"
            echo "No context selected." >&2
            return 1
        end
    end
    set -l kctx --context=$srcctx
    echo ">> Using context: $srcctx"

    set -l sa_ns
    if test -n "$ns"
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

    echo ">> Removing read-only SA '$sa_name' (ns '$sa_ns')"

    if test -n "$ns"
        $kube $kctx -n $ns delete rolebinding $binding --ignore-not-found
    else
        $kube $kctx delete clusterrolebinding $binding --ignore-not-found
    end
    $kube $kctx delete clusterrolebinding $mon_binding --ignore-not-found
    $kube $kctx -n $sa_ns delete serviceaccount $sa_name --ignore-not-found

    echo ">> Done. Removed the ServiceAccount and its RBAC bindings only."
end
