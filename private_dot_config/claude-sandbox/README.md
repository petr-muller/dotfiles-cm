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

4. (Optional, both identities) For RH JIRA access inside sandboxed sessions
   via `acli`: unlike the GitHub identities, there's no separate bot account
   for JIRA — this exposes **your own** RH JIRA account/permissions
   (read/write, whatever your account can do) inside the sandbox. Create an
   API token at https://id.atlassian.com/manage-profile/security/api-tokens,
   then:

   ```
   echo "<api-token>" > ~/.config/claude-sandbox/secrets/jira-token
   chmod 600 ~/.config/claude-sandbox/secrets/jira-token
   cat >~/.config/claude-sandbox/jira-config <<EOF
   site=redhat.atlassian.net
   email=<your-rh-email>
   EOF
   ```

   These two files are host-wide credentials, but mounting them is still
   **opt-in per worktree** — like the `oc`/kube access below, not on for
   every session just because the files exist. From inside a worktree, run:

   ```
   claude::sandbox::jira::enable
   ```

   which drops a marker at `~/.config/claude-sandbox/jira/<worktree-key>.enabled`
   (`claude::sandbox::jira::disable` removes it again; `worktree::cleanup`
   calls that automatically before removing any worktree, so normal teardown
   cleans this up too). `claude::sandbox::_run` only mounts
   `JIRA_TOKEN`/`JIRA_SITE`/`JIRA_EMAIL` when the credential files **and**
   that worktree's marker are all present; `entrypoint.sh` runs a
   non-interactive `acli jira auth login` at container start and drops
   `JIRA_TOKEN` from the environment immediately after — nothing persists to
   disk between `--rm` runs, so this happens fresh on every session start.
   Worktrees without the marker (the default) are unaffected — no acli login
   attempted, `acli` simply has no credentials configured. Like `secrets/`
   and `gitconfig-<identity>`, none of `secrets/jira-token`, `jira-config`,
   or `jira/` are chezmoi-managed — runtime-only and machine-local.

5. (Optional, **author** identity only) For `oc` cluster access inside
   `work::claude` sessions: from inside a work worktree
   (`~/Projects/Worktrees/github.com/<org>/<repo>/work-<ID>`), run
   `work::kube::create` (any `cluster::ro::create` flag, e.g. `-c`/`-n`,
   passes through), e.g.:

   ```
   work::kube::create -c dpcr
   ```

   This generates a short-lived, read-only kubeconfig (see
   `cluster::ro::create -h`) and saves it under
   `~/.config/claude-sandbox/kube/`, keyed by the worktree's path the same
   way `claude::sandbox::_run` keys per-worktree Claude Code project dirs
   (`claude::sandbox::_worktree_key`) — so different `work::claude` worktrees
   can target different clusters/namespaces at once without clobbering each
   other. `claude::sandbox::_run` mounts that worktree's kubeconfig read-only
   to `/home/claude/.kube/config` and sets `KUBECONFIG` whenever the file
   exists — nothing else to wire up. It's a bound ServiceAccount token
   (`cluster-reader` + best-effort `cluster-monitoring-view`) and expires
   (default 24h) — just re-run `work::kube::create` to refresh it. Reviewer
   sessions don't get cluster access at all. `~/.config/claude-sandbox/kube/`
   is runtime-only/machine-local like `secrets/`, not chezmoi-managed.

   `cluster::ro::create` needs permission to create ServiceAccounts/RBAC on
   the target cluster. When that's not available, `work::kube::create
   --delegate [-c CONTEXT]` instead flattens **your own** current
   credentials for that context (`oc config view --raw --minify --flatten
   --context=...`) straight into the worktree kubeconfig — no cluster-side
   objects created, but **not scoped to read-only**: the sandboxed session
   gets whatever access your own account has there.

   Either way, `work::kube::cleanup` (no flags needed) tears things down: it
   reads a `.meta` sidecar written alongside the kubeconfig recording which
   mode created it (plus context/sa/namespace for the RBAC path), so it
   knows on its own whether there's a ServiceAccount/RBAC binding to delete
   server-side (`cluster::ro::cleanup -k <kubeconfig>`) or just a local file
   to remove (delegate) — nothing to remember or re-pass. `worktree::cleanup`
   calls it automatically for any `work-*` worktree before removing it, so
   normal worktree teardown cleans this up too without a separate step.

## Per-worktree default model

The image's baked-in `image/settings.json` has no `model` key, and
`claude::sandbox::_run` doesn't mount the host's `~/.claude/settings.json`
into the container — so every sandboxed session starts on whatever Claude
Code's own default is, and any `/model` switch made inside a session is lost
when the container exits (`--rm`), forcing you to switch again on the next
launch.

To make a worktree remember a model across launches:

```
claude::sandbox::model::set opus       # or sonnet, or a full model id
claude::sandbox::model::show
claude::sandbox::model::clear
```

This writes/removes the `model` key in `<worktree>/.claude/settings.local.json`
and adds that path to the worktree's `.git/info/exclude`. It works because
`claude::sandbox::_run` bind-mounts the whole worktree at `/workspace`
(`-v "$worktree":/workspace`), and Claude Code reads project-local settings
from `cwd/.claude/settings.local.json`, which take precedence over the
image's baked-in `settings.json`. Since the file lives on the host worktree
rather than in the ephemeral container filesystem, it survives `--rm` and
even `git reset --hard` (it's untracked). Takes effect on the *next*
sandboxed launch in that worktree, not the currently running session.

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
- The image's `claude` user is hardcoded to UID/GID 1000 (Containerfile
  `useradd`). `claude::sandbox::_run`/`_exec` use
  `--userns=keep-id:uid=1000,gid=1000` (not bare `--userns=keep-id`) to map
  the *host* user onto that UID inside the container — bare `keep-id` only
  self-maps the invoking host UID, which does nothing for you on hosts where
  your UID isn't already 1000 (e.g. a corporate/LDAP account like 11227),
  leaving `claude` unable to write bind-mounted, host-owned paths (EACCES on
  transcript writes, `~/.claude/projects/-workspace/*.jsonl` in particular).
  If the Containerfile's UID for `claude` ever changes, update the `uid=`/`gid=`
  values in both fish functions to match.
- Each identity's `~/.claude.json` (`state/claude.json-<identity>`, mounted
  as `/home/claude/.claude.json`) tracks session resume state keyed by cwd,
  which inside the container is always `/workspace` — so it only ever
  remembers the *most recently used worktree's* session per identity, not one
  per worktree. Passing `--continue` naively can therefore try to resume a
  different worktree's session (or none, on a freshly bootstrapped
  `claude.json-<identity>`) and fail with "No conversation found to
  continue" even though a real transcript exists on disk for the current
  worktree. `pr::review::claude`/`pr::summarize::claude`/
  `issue::triage::claude`/`work::claude` guard against this via
  `claude::sandbox::_resumable` (host-side check: does the identity's
  recorded `lastSessionId` actually have a matching `.jsonl` in *this*
  worktree's mounted project dir?), falling back to a fresh session when it
  doesn't line up. Genuine interactive resume is still only possible for one
  worktree at a time per identity.
