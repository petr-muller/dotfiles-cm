# claude-sandbox

Containerized sandbox for the `pr::review::*` / `pr::summarize::*` /
`issue::triage::*` / `work::*` Claude workflows. Every session runs as one of
two dedicated GitHub identities, never your main account:

- **reviewer** (`petr-muller-reviewer`) — used by the review/summarize/triage
  workflows and their publish steps (`pr::review::push`,
  `issue::triage::push`, via the shared `pr::_push_review_artifacts`).
- **author** (`petr-muller-author`) — used by `work::claude` and `work::push`
  for authoring new changes from scratch.

See the fish functions `claude_redhat_sandboxed`/`claude_mine_sandboxed`
(reviewer), `claude_redhat_authoring_sandboxed`/`claude_mine_authoring_sandboxed`
(author), and the shared `claude::sandbox::_run`/`_exec`/`_check` for the
actual `podman run` invocations.

## One-time setup

1. Build the image:

   ```
   podman build -t claude-review-sandbox:latest ~/.config/claude-sandbox/image
   ```

   Rebuild whenever `image/Containerfile` or `image/settings.json` changes,
   or periodically to pick up `claude-code`/`gh` updates.

2. For **each identity** you want to use (`reviewer`, `author`, or both):
   create a dedicated GitHub account separate from your main account and from
   each other, generate a fine-grained personal access token for it, and save
   it. Repository access: **All repositories** — forking creates a new repo
   under the identity's own account, which isn't selectable ahead of time
   under "Only select repositories". Permissions: **Contents** (read/write),
   **Pull requests** (read/write), **Metadata** (read — auto-selected), and
   **Administration** (read/write) — the last one is what actually lets the
   account create repos/forks at all (`gh repo fork`, used by `work::push`
   and `pr::_push_review_artifacts` before pushing); without it you'll hit
   `HTTP 403: Resource not accessible by personal access token` on the fork
   step. None of this requires any permission *on* the repo being forked
   (e.g. `petr-muller/wetware`) beyond it being public and thus readable —
   these are all permissions on the identity's own account/repos.

   ```
   mkdir -p ~/.config/claude-sandbox/secrets
   chmod 700 ~/.config/claude-sandbox/secrets
   echo "ghp_..." > ~/.config/claude-sandbox/secrets/gh-<identity>-token
   chmod 600 ~/.config/claude-sandbox/secrets/gh-<identity>-token
   ```

3. Write that identity's git config to
   `~/.config/claude-sandbox/gitconfig-<identity>`, e.g.:

   ```
   [user]
     name = <bot name>
     email = <id>+<github-login>@users.noreply.github.com
   [credential "https://github.com"]
     helper =
     helper = !/usr/bin/gh auth git-credential
   ```

   (`<id>` is the account's numeric GitHub user id, from
   `gh api users/<github-login> --jq .id` — using the noreply address avoids
   putting a real email in commits made under that identity.)

   `gh` picks up `GH_TOKEN` from the environment automatically (set by the
   fish wrappers), so no `hosts.yml`/`gh auth login` is needed inside the
   container.

Neither `secrets/` nor `gitconfig-<identity>` are chezmoi-managed — they're
runtime-only and machine-local.

## Known limitations (v1)

- No network egress restriction; container gets the default podman bridge
  network.
- `image/settings.json` mirrors only the plugins the review workflow needs
  (`pr-review-toolkit`, `ci`/ai-helpers) and must be updated by hand if that
  changes on the host.
- Repo-specific toolchains (Go, Python, etc.) aren't preinstalled — extend
  the Containerfile as needed.
- The image isn't built automatically; rebuild manually after changes.
- Both identities only work against **public** repositories — neither
  account has access to private repos (including private Red Hat repos).
  `pr::review::push`/`issue::triage::push` fall back to your own identity and
  fork for private repos; `work::push` has no such fallback and just refuses.
- The **reviewer** identity's publish step (`pr::review::push`/`issue::triage::push`)
  is still host-shell-only, run after the sandboxed session.
- The **author** identity can push and open PRs directly from inside a
  `work::claude` session (see `~/.claude/CLAUDE.md`) — `GH_TOKEN` and the
  `gh auth git-credential` helper are already mounted in for that identity in
  the interactive container, not just in the one-shot `work::push` exec. Two
  bots fully operating on each other's output (author proposing PRs, reviewer
  autonomously reviewing them, with no human in the loop at all) is still out
  of scope.
