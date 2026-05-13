# Repository layout

Main working copies live under `~/Projects/`:

- `~/Projects/RH/github.com/<org>/<repo>` — Red Hat work (GitHub)
- `~/Projects/RH/gitlab.cee.redhat.com/<group>/<repo>` — Red Hat work (internal GitLab)
- `~/Projects/Personal/github.com/<org>/<repo>` — personal projects

Worktrees live under `~/Projects/Worktrees/github.com/<org>/<repo>/<worktree>` (no RH/Personal split here).

## Remotes

For repos I don't solely own:
- `origin` — SSH URL to **my fork**; main push destination
- `upstream` — HTTPS URL to the **canonical/main repository**

## Working style

I rarely commit directly in the main working copies — actual work happens in worktrees under `~/Projects/Worktrees/`.

## PR review workflow

To review a PR numbered `N` in `<org>/<repo>`:

1. **Set up the worktree** — `pr::review::init <PR-URL|N>` (in `~/.config/fish/functions/pr::review::init.fish`):
   - With a GitHub PR URL: locates the canonical working copy under `~/Projects/{RH,Personal}/github.com/<org>/<repo>`.
   - With a bare number: must be invoked from inside the canonical working copy.
   - Runs `git fetch --all`, fetches `pull/N/head` (prefers `upstream`, falls back to `origin`), creates worktree at `~/Projects/Worktrees/github.com/<org>/<repo>/N-review` on a new branch `N-review` initialized to the PR head, and `cd`s into it.
   - If the worktree already exists, `cd`s into it and delegates to `pr::review::pull` (refresh-in-place).

2. **Launch Claude in the worktree** — `pr::review::claude` (in `~/.config/fish/functions/pr::review::claude.fish`):
   - Must be run from inside the review worktree.
   - Picks `claude_redhat` if the canonical copy is under `~/Projects/RH/`, else `claude_mine` (under `~/Projects/Personal/`). Both forward `$argv` to `claude`.
   - If `~/.claude/projects/<encoded-cwd>/` contains any `.jsonl` sessions, resumes the most recent via `claude --continue` (path-encoding rule: replace both `/` and `.` with `-`).
   - Otherwise fetches the PR title via `gh pr view N --repo <org>/<repo>` and launches fresh with `--name "#N: <title>"` plus initial prompt `/color cyan`.

3. **Do the review.** When finished, `/review:save` writes two artifacts at the worktree root:
   - `REVIEW.html` — human-readable, opened in browser while doing the actual GitHub review.
   - `REVIEW.md` — same content, agent-readable. YAML frontmatter holds `pr`, `title`, `head_sha`, `base`, `reviewed_at`, `verdict`.
   - `/review:refresh` consumes `REVIEW.md` later to detect new PR activity since `reviewed_at`/`head_sha` and either updates both artifacts in place or recommends a full re-review.

4. **Refresh from remotes** (optional) — `pr::review::pull` (in `~/.config/fish/functions/pr::review::pull.fish`):
   - Must be run from inside the review worktree on branch `N-review`.
   - `git fetch --all`, then re-fetches `pull/N/head` and `reset --hard`s `N-review` to it (latest PR content).
   - If `origin/N-review` exists, replays whichever of `REVIEW.html` / `REVIEW.md` is present there as a single `Review of PR #N` commit on top — via `git checkout origin/N-review -- <file>`. Avoids cherry-pick conflicts entirely.

5. **Publish the review** — `pr::review::push` (in `~/.config/fish/functions/pr::review::push.fish`):
   - Must be run from inside the review worktree on branch `N-review`.
   - Stages whichever of `REVIEW.html` / `REVIEW.md` exist, commits them in one commit (`Review of PR #N`) on top of the PR head, and pushes `N-review` to `origin` (my fork) with the same branch name.
   - Uses `git push --force-with-lease`: the branch is always rebuilt as "PR head + one review commit", so the local and remote trees match but the SHAs differ (different parents/timestamps after each `pull`). Force-with-lease is the correct semantics — refuses to clobber if someone else pushed in the meantime.

## PR summarize workflow

For lighter touch work — getting an overview of a PR and doing some quick querying without a full review. Worktree/branch named `N-summarize`; can coexist with an `N-review` worktree for the same PR. No expectation of any `REVIEW.html` or other output artifact.

- **`pr::summarize::init <PR-URL|N>`** (in `~/.config/fish/functions/pr::summarize::init.fish`) — identical to `pr::review::init` but uses `N-summarize` for the worktree path and branch name. If the worktree exists, delegates to `pr::summarize::pull`.
- **`pr::summarize::claude`** (in `~/.config/fish/functions/pr::summarize::claude.fish`) — identical to `pr::review::claude` but matches the `N-summarize` worktree path and launches with `/color purple` instead of `/color cyan`.
- **`pr::summarize::pull`** (in `~/.config/fish/functions/pr::summarize::pull.fish`) — identical to `pr::review::pull` but matches the `N-summarize` worktree and only resets the branch to the latest PR head (no `REVIEW.html` replay).

## Issue triage workflow

Lightweight workflow for inspecting / triaging a GitHub issue (not a PR — there's no PR head to track):

- **`issue::triage::init <ISSUE-URL|N>`** (in `~/.config/fish/functions/issue::triage::init.fish`) — accepts URL form `https://github.com/<org>/<repo>/issues/<N>` or a bare number (must be in canonical working copy). Locates the canonical repo, fetches all remotes, resolves the default branch of `upstream` (falling back to `origin`) via `git symbolic-ref refs/remotes/<remote>/HEAD` (running `remote set-head --auto` if it's unset), and creates a worktree at `~/Projects/Worktrees/github.com/<org>/<repo>/<N>-triage` on a new branch `<N>-triage` pointed at that default-branch SHA.
- If the worktree already exists, `cd`s into it and delegates to `issue::triage::pull` (refresh-in-place).
- Triggers the same private-content overlay as the PR workflows.
- **`issue::triage::pull`** (in `~/.config/fish/functions/issue::triage::pull.fish`) — must be on `N-triage`. Fetches all remotes, resolves the upstream default branch, `reset --hard`s to it (latest `main`). If `origin/N-triage` exists, replays whichever of `TRIAGE.html` / `TRIAGE.md` is present there as a single `Triage of issue #N` commit on top.
- **`issue::triage::push`** (in `~/.config/fish/functions/issue::triage::push.fish`) — must be on `N-triage`. Stages whichever of `TRIAGE.html` / `TRIAGE.md` exist, commits them in one commit (`Triage of issue #N`), and `git push --force-with-lease --set-upstream origin N-triage`. Force-with-lease semantics for the same reason as `pr::review::push`: the branch is rebuilt as "main + one triage commit" and SHAs differ across `pull`s.
- **`issue::triage::claude`** (in `~/.config/fish/functions/issue::triage::claude.fish`) — identical to `pr::review::claude` but matches the `N-triage` worktree path. Fetches the title via `gh issue view N --repo <org>/<repo>` (not `pr view`) and launches with `/color pink`.

## Private claude-content overlay

Each `init`/`pull` (both review and summarize) runs the shared helper `pr::_private_content` (in `~/.config/fish/functions/pr::_private_content.fish`):

- Checks `git@github.com:petr-muller/claude-content.git` for a branch named after the repo (e.g. `sippy`, `prow`) using `git ls-remote --exit-code --heads`. If no such branch, does nothing.
- If present, clones (or fetches + `reset --hard` if already cloned) that branch into `.private-claude-content/` inside the worktree.
- Always appends a known set of overlay paths (`.private-claude-content`, `.claude/commands/muller`, …) to `$(git rev-parse --git-path info/exclude)` (the worktree's `.git/info/exclude`) if not already present — deliberately not `.gitignore`, so the exclusion isn't tracked. The exclude list grows as new overlays are added; entries are written even if the corresponding source doesn't exist yet.
- If the matching branch exists, also creates symlinks from the worktree into the overlay (relative symlinks so the worktree stays movable; parent dirs are created as needed; existing symlinks are replaced via `ln -sfn`):
    - `.claude/commands/muller` → `.private-claude-content/.claude/commands/muller` (directory-namespaced; this is the supported pattern for commands).
    - For **each skill** discovered at `.private-claude-content/.claude/skills/<name>/`: symlink `<worktree>/.claude/skills/muller-<name>` → that source. The `muller-` *name* prefix (not a parent dir — Claude Code only discovers skills exactly one level under `.claude/skills/`) avoids collisions with skills the repo carries. Each skill's SKILL.md should also set `name: muller-<name>` in its frontmatter so the discovered name matches. Done dynamically: drop a new skill in the overlay branch and the next `init`/`pull` picks it up — no helper edits needed.
    - `CLAUDE.local.md` → `.private-claude-content/CLAUDE.md` (uses `CLAUDE.local.md` so it loads alongside the repo's own `CLAUDE.md` without conflict — Claude Code appends `CLAUDE.local.md` after `CLAUDE.md` at each directory level).
