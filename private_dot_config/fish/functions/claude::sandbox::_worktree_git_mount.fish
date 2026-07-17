function claude::sandbox::_worktree_git_mount --description "If <worktree>/.git is a git-worktree gitlink file, print the podman -v args needed to expose the canonical repo's .git dir at the same absolute path inside the container (nothing otherwise). A worktree's .git file points at an absolute host path (<canonical-repo>/.git/worktrees/<name>), and that admin dir's commondir resolves back to the canonical repo's .git for the actual object database/refs/config — none of which lives under the worktree directory itself, so without this, git doesn't work at all inside the container."
    set -l worktree $argv[1]
    set -l git_file $worktree/.git

    if not test -f $git_file
        # Not a worktree gitlink (a plain .git directory, or nothing) —
        # nothing extra to mount.
        return 0
    end

    set -l gitdir_line (string trim (cat $git_file))
    set -l admin_dir (string replace -r '^gitdir:\s*' '' -- $gitdir_line)
    if not test -d $admin_dir
        echo "warning: $git_file points at '$admin_dir', which doesn't exist — git will likely fail inside the sandbox" >&2
        return 0
    end

    set -l commondir_file $admin_dir/commondir
    if not test -f $commondir_file
        return 0
    end
    set -l canonical_git_dir (realpath $admin_dir/(string trim (cat $commondir_file)))
    if not test -d $canonical_git_dir
        echo "warning: resolved canonical .git dir '$canonical_git_dir' doesn't exist — git will likely fail inside the sandbox" >&2
        return 0
    end

    echo -v
    # :z (shared), not :Z (private) — the canonical repo's .git is reachable
    # from every worktree of that repo, so concurrent sandboxed sessions
    # against different worktrees of the same repo legitimately mount this
    # same host path at once. :Z relabels it for exclusive use by whichever
    # container started last, leaving any other concurrently running
    # container's access to it stale (host-side "Permission denied" on any
    # read, even stat, from inside the other container).
    echo "$canonical_git_dir":"$canonical_git_dir":z
end
