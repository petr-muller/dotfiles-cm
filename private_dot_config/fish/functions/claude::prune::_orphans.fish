function claude::prune::_orphans --description "Internal: print absolute paths of ~/.claude/projects/* dirs whose real working directory no longer exists"
    set -l sessions_dir $HOME/.claude/projects
    if not test -d $sessions_dir
        return 0
    end

    # Claude Code encodes a session's cwd by replacing every non-alphanumeric
    # character with '-', which is lossy (hyphenated dir names are
    # indistinguishable from encoded path separators). Rather than trying to
    # reverse that, forward-encode every real directory this user could
    # plausibly have launched `claude` from and diff against it.
    set -l tmp (mktemp -d)

    # Narrow: $HOME, ~/.claude, and every worktree root. The PR/issue
    # workflows always `cd` to the worktree root before launching `claude`
    # (see CLAUDE.md's "stay inside the worktree"), so nothing deeper is
    # needed there.
    for c in $HOME $HOME/.claude $HOME/Projects/Worktrees/*/*/*/*
        string trim -r -c / -- $c
    end > $tmp/real.txt

    # Broad: canonical RH/Personal checkouts are ordinary working copies —
    # `claude` can be launched from anywhere inside them (a subpackage, a
    # notes vault subdirectory, ...) — so walk them fully, pruning obvious
    # noise trees. This is the expensive part (~400k dirs, ~15s).
    find $HOME/Projects/RH $HOME/Projects/Personal \
        \( -name .git -o -name node_modules -o -name vendor -o -name .terraform -o -name .obsidian \) -prune \
        -o -type d -print >> $tmp/real.txt 2>/dev/null

    # Claude Code replaces every non-alphanumeric character (not just '/'
    # and '.' — spaces too, confirmed against a notes-vault path with
    # space-separated directory names) with '-'.
    sed -E 's/[^A-Za-z0-9]/-/g' -- $tmp/real.txt | sort -u > $tmp/encoded.txt

    for d in $sessions_dir/*/
        basename (string trim -r -c / -- $d)
    end | sort -u > $tmp/sessions.txt

    for name in (comm -23 $tmp/sessions.txt $tmp/encoded.txt)
        echo $sessions_dir/$name
    end

    rm -rf $tmp
end
