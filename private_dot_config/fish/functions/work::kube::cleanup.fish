function work::kube::cleanup --description "Tear down this work worktree's cluster credentials and remove its local kubeconfig, auto-detecting whether server-side RBAC/SA cleanup is needed"
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

    set -l out ~/.config/claude-sandbox/kube/(claude::sandbox::_worktree_key $toplevel).kubeconfig

    if not test -f $out
        echo ">> No kubeconfig for this worktree ($out) — nothing to do."
        return 0
    end

    set -l meta $out.meta
    if not test -f $meta
        echo ">> No metadata sidecar ($meta) — can't tell whether this needs server-side cleanup. Removing the local file only; if it was created via cluster::ro::create, clean up the ServiceAccount/RBAC manually (cluster::ro::cleanup)." >&2
        rm -f $out
        return 0
    end

    set -l mode
    for line in (cat $meta)
        set -l kv (string split -m1 '=' -- $line)
        if test "$kv[1]" = mode
            set mode $kv[2]
        end
    end

    switch "$mode"
        case ro
            cluster::ro::cleanup -k $out
            or return 1
        case delegate
            echo ">> Delegated kubeconfig (your own credentials) — nothing created server-side."
        case '*'
            echo ">> Unrecognized mode '$mode' in $meta — removing local files only." >&2
    end

    rm -f $out $meta
    echo ">> Removed local kubeconfig: $out"
end
