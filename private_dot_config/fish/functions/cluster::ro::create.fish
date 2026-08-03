function cluster::ro::create --description "Create a read-only (cluster-reader) ServiceAccount and emit a kubeconfig for an agent"
    argparse -n cluster::ro::create s/sa= n/namespace= o/out= d/duration= c/context= h/help -- $argv
    or return 2

    if set -q _flag_help
        echo "Usage: cluster::ro::create [-s SA_NAME] [-n NAMESPACE] [-o KUBECONFIG_OUT] [-d DURATION] [-c CONTEXT]"
        echo ""
        echo "  -c CONTEXT    kubeconfig context to act against (= which cluster"
        echo "                to create the credentials in). Omitted => pick"
        echo "                interactively from existing contexts."
        echo "  -s SA_NAME    ServiceAccount name (default: muller-agent-reader)"
        echo "  -n NAMESPACE  Read access to this namespace only (RoleBinding)."
        echo "                Omitted => cluster-wide read (ClusterRoleBinding)."
        echo "                SA is created here too. Without -n, read is"
        echo "                cluster-wide and the SA namespace is picked"
        echo "                interactively from 'ci' / *muller* namespaces."
        echo "  -o FILE       kubeconfig output (default: ./<SA_NAME>.kubeconfig)"
        echo "  -d DURATION   Token lifetime, e.g. 24h, 168h (default: 24h)."
        echo "                Capped by the cluster's max token expiration."
        echo ""
        echo "Uses the cluster-reader ClusterRole (built into OpenShift)."
        echo "Issues a short-lived bound token (TokenRequest API) — the"
        echo "kubeconfig stops working when it expires; just re-run this."
        echo "Run with a context that can create RBAC objects."
        echo ""
        echo "Also writes <out>.meta (context/sa/namespace) alongside the"
        echo "kubeconfig — consumed by 'cluster::ro::cleanup -k <out>' so"
        echo "cleanup doesn't need those flags repeated."
        return 0
    end

    set -l sa_name muller-agent-reader
    set -q _flag_sa; and set sa_name $_flag_sa
    set -l ns ""
    set -q _flag_namespace; and set ns $_flag_namespace
    set -l duration 24h
    set -q _flag_duration; and set duration $_flag_duration

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
        set srcctx (printf '%s\n' $contexts | sort | gum filter --placeholder "Pick the cluster context to create credentials in...")
        if test -z "$srcctx"
            echo "No context selected." >&2
            return 1
        end
    end
    set -l kctx --context=$srcctx
    echo ">> Using context: $srcctx"

    set -l sa_ns scope binding
    if test -n "$ns"
        set sa_ns $ns
        set scope "namespace '$ns'"
    else
        # Cluster-wide read, but the SA still has to live somewhere.
        # Offer 'ci' (if present) and any namespace containing 'muller'.
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
        set sa_ns (printf '%s\n' $candidates | sort -u | gum filter --placeholder "Namespace to host the read-only SA...")
        if test -z "$sa_ns"
            echo "No namespace selected." >&2
            return 1
        end
        set scope "entire cluster"
    end
    set binding cluster-ro-sa-$sa_ns-$sa_name
    set -l out ./$sa_name.kubeconfig
    set -q _flag_out; and set out $_flag_out
    set -l label app.kubernetes.io/managed-by=cluster-ro-sa

    set -l mon_binding $binding-monitoring

    set -l impersonate
    if not $kube $kctx auth can-i create serviceaccounts -n $sa_ns 2>/dev/null | string match -q yes
        echo ">> Current user cannot create resources — will use --as system:admin"
        set impersonate --as=system:admin
    end

    echo ">> Granting read-only (cluster-reader + cluster-monitoring-view) to SA '$sa_name' in '$sa_ns' over $scope"

    $kube -n $sa_ns create serviceaccount $sa_name --dry-run=client -o yaml \
        | $kube label --local -f - $label -o yaml --dry-run=client \
        | $kube $kctx $impersonate apply -f -
    or return 1

    if test -n "$ns"
        $kube -n $ns create rolebinding $binding \
            --clusterrole=cluster-reader \
            --serviceaccount=$sa_ns:$sa_name \
            --dry-run=client -o yaml \
            | $kube label --local -f - $label -o yaml --dry-run=client \
            | $kube $kctx $impersonate apply -f -
        or return 1
    else
        $kube create clusterrolebinding $binding \
            --clusterrole=cluster-reader \
            --serviceaccount=$sa_ns:$sa_name \
            --dry-run=client -o yaml \
            | $kube label --local -f - $label -o yaml --dry-run=client \
            | $kube $kctx $impersonate apply -f -
        or return 1
    end

    # Querying the platform Thanos Querier / Prometheus API needs the OpenShift
    # cluster-monitoring-view ClusterRole. Platform metrics are cluster-wide and
    # have no namespaced equivalent, so this binding is always cluster-scoped
    # even when -n limits the Kube-API read access to one namespace.
    # Best-effort: on some clusters the caller can't create this binding (or
    # the ClusterRole is absent). Don't fail the whole run — the cluster-reader
    # credential is still useful; just warn that metrics queries won't work.
    if $kube create clusterrolebinding $mon_binding \
            --clusterrole=cluster-monitoring-view \
            --serviceaccount=$sa_ns:$sa_name \
            --dry-run=client -o yaml \
            | $kube label --local -f - $label -o yaml --dry-run=client \
            | $kube $kctx $impersonate apply -f -
        set -f have_monitoring 1
    else
        echo ">> WARNING: could not grant cluster-monitoring-view (missing role or insufficient permissions)." >&2
        echo ">>          Thanos Querier / Prometheus API access will NOT work; cluster-reader is still set." >&2
        set -f have_monitoring 0
    end

    # Short-lived bound token via the TokenRequest API — no Secret is created.
    echo ">> Requesting a $duration token for $sa_name..."
    set -l token ($kube $kctx $impersonate -n $sa_ns create token $sa_name --duration=$duration)
    or return 1
    if test -z "$token"
        echo "Failed to obtain a token for $sa_name." >&2
        return 1
    end

    # Resolve the cluster backing the selected context, then read its
    # server/CA (can't use --minify: it keys off current-context, not --context).
    set -l clustername ($kube config view -o jsonpath="{.contexts[?(@.name==\"$srcctx\")].context.cluster}")
    if test -z "$clustername"
        echo "Could not resolve cluster for context '$srcctx'." >&2
        return 1
    end
    set -l server ($kube config view -o jsonpath="{.clusters[?(@.name==\"$clustername\")].cluster.server}")
    if test -z "$server"
        echo "Could not determine API server for context '$srcctx'." >&2
        return 1
    end

    # Mirror whatever the admin context does for TLS: embed its CA if it has
    # one, otherwise fall back to insecure-skip-tls-verify (the context that
    # already works has neither a usable CA nor needs one).
    set -l ca_data ($kube config view --raw -o jsonpath="{.clusters[?(@.name==\"$clustername\")].cluster.certificate-authority-data}")

    set -l outctx $sa_name@cluster-ro
    set -l old_umask (umask)
    umask 077
    begin
        printf '%s\n' \
            "apiVersion: v1" \
            "kind: Config" \
            "clusters:" \
            "- name: cluster-ro" \
            "  cluster:" \
            "    server: $server"
        if test -n "$ca_data"
            printf '    certificate-authority-data: %s\n' "$ca_data"
        else
            printf '    insecure-skip-tls-verify: true\n'
        end
        printf '%s\n' \
            "users:" \
            "- name: $sa_name" \
            "  user:" \
            "    token: $token" \
            "contexts:" \
            "- name: $outctx" \
            "  context:" \
            "    cluster: cluster-ro" \
            "    user: $sa_name"
        if test -n "$ns"
            printf '    namespace: %s\n' "$ns"
        end
        printf 'current-context: %s\n' "$outctx"
    end > $out
    umask $old_umask

    # Sidecar metadata so cleanup tooling (cluster::ro::cleanup -k, work::kube::cleanup)
    # can reconstruct this exact SA/namespace/context without the caller having to
    # remember or re-pass them.
    begin
        printf 'mode=ro\n'
        printf 'context=%s\n' $srcctx
        printf 'sa=%s\n' $sa_name
        printf 'sa_namespace=%s\n' $sa_ns
        printf 'namespace=%s\n' "$ns"
    end > $out.meta
    chmod 600 $out.meta

    echo ">> Wrote kubeconfig: $out"
    if test "$have_monitoring" = 1
        echo "   Monitoring: cluster-monitoring-view granted (Thanos/Prometheus query API available)."
    else
        echo "   Monitoring: NOT granted — Thanos/Prometheus query API will be denied."
    end
    echo "   Verify: KUBECONFIG=$out "(basename $kube)" auth can-i --list"(test -n "$ns"; and echo " -n $ns")
    echo "   Tear down: cluster::ro::cleanup -s $sa_name"(test -n "$ns"; and echo " -n $ns")
end
