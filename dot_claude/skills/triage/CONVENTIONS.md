# `triage:*` shared conventions

Read by whichever `triage:*` skill is running when its own `SKILL.md` points here.

## How the skills chain together

```
(triage performed in the session)
   │
   ▼
/triage:save      → writes TRIAGE.md (+ rendered TRIAGE.html); defines the artifact schema
   ├─→ /triage:refresh   → fold in activity since triaged_at, or record a re-triage recommendation
   └─→ /triage:advise    → concrete maintainer actions (suggested commands, never executed)
```

## Establishing issue/repo context from a worktree

- **Issue number** — the worktree's branch is `N-triage`; extract `N`. Once `TRIAGE.md`
  exists, its `issue: org/repo#N` frontmatter is authoritative.
- **`<org>/<repo>`** — from the git remotes: prefer `upstream`, fall back to `origin`.
- If the worktree doesn't correspond to a triaged issue, say so and stop.

Every `gh api` call that lists comments or timeline events passes `--paginate` (the API
returns 30 items per page). Cross-references (`cross-referenced`, `connected`) come from
`/issues/<N>/timeline`, not `/issues/<N>/events`.

## Artifacts

`TRIAGE.md` is the single source of truth; its schema (frontmatter keys, section order,
finding tags) is defined in `skills/save/SKILL.md`. `TRIAGE.html` is generated from it —
never hand-edited. Any skill that changes `TRIAGE.md` finishes with:

```
python3 <skill-base-dir>/../../scripts/render.py TRIAGE.md
```

Timestamps are UTC with a literal `Z` suffix (`date -u -Iseconds | sed 's/+00:00/Z/'`) so
they compare lexicographically with GitHub's. Generate them during the gather phase.

## Output discipline

Do all gathering and artifact edits first, without narrating between tool calls; then print
one self-contained summary last. Be specific (names, timestamps, comment authors, PR
numbers, exact command text); no emoji, no filler. Never run a state-changing `gh` command
(comment, close, label, assign) unless the user explicitly says to.
