function pr::_private_content --description "Clone/update private claude-content branch and wire overlays into the worktree"
    if test (count $argv) -ne 2
        echo "Usage: pr::_private_content <worktree-path> <project-name>" >&2
        return 2
    end
    set -l worktree $argv[1]
    set -l project $argv[2]
    set -l remote_url git@github.com:petr-muller/claude-content.git
    set -l dir .private-claude-content

    set -l exclude_file (git -C $worktree rev-parse --git-path info/exclude)

    # Overlay paths (relative to worktree root) that should always be excluded
    # from git, whether or not the corresponding symlink ends up being created.
    set -l overlay_paths $dir .claude/commands/muller CLAUDE.local.md NOTES

    for path in $overlay_paths
        if not grep -qxF -- $path $exclude_file 2>/dev/null
            echo $path >> $exclude_file
        end
    end

    if not git ls-remote --exit-code --heads $remote_url $project >/dev/null 2>&1
        return 0
    end

    if test -d $worktree/$dir
        echo "Updating $dir from $remote_url (branch $project)..."
        git -C $worktree/$dir fetch origin $project
        or return 1
        git -C $worktree/$dir reset --hard FETCH_HEAD
        or return 1
    else
        echo "Cloning $remote_url (branch $project) into $dir..."
        git -C $worktree clone -b $project $remote_url $dir
        or return 1
    end

    pr::_private_content::link $worktree $dir .claude/commands/muller
    pr::_private_content::link $worktree $dir CLAUDE.md CLAUDE.local.md

    # Discover skills carried by this branch and symlink each individually under
    # a `muller-` prefix to avoid collisions with the repo's own .claude/skills/.
    set -l overlay_skills_dir $worktree/$dir/.claude/skills
    if test -d $overlay_skills_dir
        for skill_path in $overlay_skills_dir/*/
            set -l skill_name (basename $skill_path)
            set -l link_rel .claude/skills/muller-$skill_name
            if not grep -qxF -- $link_rel $exclude_file 2>/dev/null
                echo $link_rel >> $exclude_file
            end
            pr::_private_content::link $worktree $dir .claude/skills/$skill_name $link_rel
        end
    end

    pr::_private_content::id_notes $worktree $dir $project
end

function pr::_private_content::id_notes --description "If the worktree branch is prefixed with a JIRA ticket or PMyyNN effort id, expose its notes/<id> dir as a top-level NOTES symlink and point CLAUDE.local.md at it"
    set -l worktree $argv[1]
    set -l dir $argv[2]
    set -l project $argv[3]

    set -l branch (git -C $worktree rev-parse --abbrev-ref HEAD 2>/dev/null)
    if test -z "$branch"; or test "$branch" = HEAD
        return 0
    end
    set -l lc (string lower -- $branch)

    # Effort id (pm<yy><nn>) takes precedence; otherwise a JIRA-looking
    # <letters>-<digits> prefix. Case-insensitive (branch already lowered).
    set -l id (string match -rg '^(pm[0-9]{4})(?:[-_/]|$)' -- $lc)
    if test -z "$id"
        set id (string match -rg '^([a-z][a-z0-9]*-[0-9]+)(?:[-_/]|$)' -- $lc)
    end
    if test -z "$id"
        return 0
    end

    if not test -d $worktree/$dir/notes/$id
        echo "No private notes for '$id' (looked for notes/$id in branch $project)"
        return 0
    end

    echo "Wiring private notes for '$id' into NOTES/ ..."
    pr::_private_content::link $worktree $dir notes/$id NOTES

    # CLAUDE.local.md is normally a symlink to the branch-wide overlay
    # CLAUDE.md; replace it with a generated stub that imports that same
    # file and additionally points Claude at the per-id NOTES/ directory.
    set -l clm $worktree/CLAUDE.local.md
    rm -f $clm
    begin
        if test -e $worktree/$dir/CLAUDE.md
            echo "@$dir/CLAUDE.md"
            echo
        end
        echo "# Working notes: $id"
        echo
        echo "Private working notes for \`$id\` are symlinked at \`NOTES/\` (→ \`$dir/notes/$id/\`)."
        echo "They carry broader context, progress, and findings for this effort/ticket."
        echo "Read them at the start of the task, and record new findings and progress there."
    end >$clm
end

function pr::_private_content::link --description "Symlink an overlay path from .private-claude-content into the worktree, if the source exists"
    set -l worktree $argv[1]
    set -l overlay_root $argv[2]
    set -l source_rel $argv[3]
    set -l link_rel $source_rel
    if test (count $argv) -ge 4
        set link_rel $argv[4]
    end

    set -l source $worktree/$overlay_root/$source_rel
    set -l link $worktree/$link_rel

    if not test -e $source
        return 0
    end

    mkdir -p (dirname $link)
    or return 1

    # Compute a relative target so the symlink survives worktree moves.
    # The symlink itself counts as one component; the rest are directories to climb.
    set -l ups (math (string split / $link_rel | count) - 1)
    set -l up (string repeat -n $ups ../)
    set -l target $up$overlay_root/$source_rel

    ln -sfn $target $link
end
