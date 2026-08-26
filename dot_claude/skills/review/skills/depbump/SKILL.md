---
name: depbump
description: Review a PR that bumps a dependency — security/freshness of the release, what changed, and how heavily/sensitively we use it; plus a standard code review if the PR also touches project code
---

# Review a dependency-bump PR

This PR bumps one or more dependencies. Two shapes are possible, and they get different treatment:

- **Dep-only** — the PR changes *only* dependency manifests / lockfiles / vendored code and nothing in the project's own source. Do **only** the dependency analysis below. There is no project code to review.
- **Dep + code** — the PR bumps a dependency **and** changes the project's own code (e.g. adapting to a new API, using a new feature). Do **both**: the dependency analysis below **and** a standard code review of the project-code changes.

The dependency analysis answers three things, in order:

1. **Is the bump safe to take now?** — when was the new release cut? I usually don't want to jump onto releases that are too fresh (no soak time to catch regressions or a compromised/yanked release).
2. **What is the dependency, and do we use it directly?** — direct vs. indirect, and where/how it's imported.
3. **What changed, and how exposed are we?** — read the changelog between old and new, and weigh it against how we use the dep: sensitive code paths or not, heavy exposure or light.

## Establish context

Determine the PR and repo from the worktree — see `../../CONVENTIONS.md` ("Establishing
PR/repo context from a worktree").

The worktree is checked out at the PR head. Get the base to diff against: `BASE=$(git merge-base HEAD <base-branch>)` where the base branch comes from `gh pr view <N> --repo <org>/<repo> --json baseRefName -q .baseRefName` (resolve it to the local tracking ref, e.g. `upstream/<base>`).

## Identify the dependency change(s) and classify the PR

Look at what the PR touches: `git diff --stat $BASE..HEAD`.

Detect the ecosystem from the changed manifest/lock files:
- **Go** (primary here): `go.mod`, `go.sum`, `vendor/**`, `vendor/modules.txt`.
- **Node**: `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`.
- **Python**: `requirements*.txt`, `pyproject.toml`, `poetry.lock`, `Pipfile.lock`.
- **Rust**: `Cargo.toml`, `Cargo.lock`. Others by analogy.

Extract the actual version changes from the manifest diff — for Go, `git diff $BASE..HEAD -- go.mod` shows `-<module> v<old>` / `+<module> v<new>` lines (and `// indirect` markers). Record, per bumped module: **module path**, **old version**, **new version**, and whether it's **direct or indirect**.

**Classify the PR:**
- **Dep-only** if every changed file is a dependency manifest, lockfile, or vendored/generated artifact of the bump (`go.mod`, `go.sum`, `vendor/**`, lockfiles, regenerated `zz_generated*`/bindata that only move because the dep moved).
- **Dep + code** if anything outside that set changed — real edits to the project's own source/config/docs/tests.

State the classification explicitly before going further.

If the PR bumps **many** modules at once (common with bot PRs / `go mod tidy` sweeps), don't deep-dive every indirect one. Focus the analysis on **direct** deps and on any indirect dep with a large version jump or that we actually import; summarize the long tail of indirect-only churn in one line.

## Dependency analysis

Run this for each in-scope bumped module. Gather everything read-only and in parallel where possible; don't narrate between calls.

### 1. Freshness / security of the new release

Get the release timestamp of the **new** version from the Go module proxy (it's the version-resolution source of truth and also returns the upstream repo + ref):

```
curl -s "https://proxy.golang.org/<escaped-module>/@v/<newversion>.info"
```

Module-path escaping: uppercase letters become `!` + lowercase (e.g. `github.com/Azure/x` → `github.com/!azure/x`). The response is `{"Version","Time","Origin":{"URL","Ref","Hash"}}` — `Time` is the release/commit time; `Origin.URL` and `Origin.Ref` give the upstream repo and tag. For non-Go ecosystems, get the publish time from the registry instead (npm: `npm view <pkg>@<ver> time.<ver>`; PyPI: `https://pypi.org/pypi/<pkg>/<ver>/json` → `urls[].upload_time`).

Compute the **age** of the release relative to today and report it. Guideline (not a hard rule — I said *usually*):
- **< ~5 days old** → flag prominently. Too fresh; a regression or a compromised/yanked release often surfaces within days. Recommend waiting unless there's a reason to take it now (e.g. it *is* the security fix).
- **< ~2 weeks old** → note the age and let me judge.
- **older** → fine on the freshness axis; say so in one line.

Also note if the new version is a **pseudo-version** (`v0.0.0-<date>-<hash>`, i.e. an untagged commit) rather than a real tagged release — that's a weaker provenance signal worth calling out. The date is embedded in the pseudo-version.

### 2. What the dependency is, and whether we use it directly

- **Direct or indirect** — from the `// indirect` marker in `go.mod` (or the equivalent). An indirect dep we don't import ourselves is lower-stakes; a direct dep in core code is higher.
- **Import surface in our code** — grep the project (excluding `vendor/`) for the module's import path:
  `grep -rn --include='*.go' '"<module-path>' . | grep -v '/vendor/'`
  Count the importing files/packages and list where they sit. Is it imported in one util, or threaded through core packages? Test-only?
- One sentence on **what the dependency does** (logging, crypto, HTTP client, YAML parsing, k8s client, …) so the rest of the analysis has context.

### 3. Changelog, and how exposed we are

Read what actually changed between old and new. Resolve the upstream repo from `Origin.URL` (or the module path: `github.com/owner/repo/...` → `owner/repo`; `k8s.io/x` → `kubernetes/x`; `golang.org/x/y` → `golang/y`; `sigs.k8s.io/x` → `kubernetes-sigs/x`; `gopkg.in/x.v3` → its GitHub home).

For GitHub-hosted deps, prefer `gh`:
- Release notes for the new tag (and any tags in between): `gh release view <tag> --repo <owner>/<repo>` (skip if releases aren't used).
- Commit range: `gh api repos/<owner>/<repo>/compare/<oldtag>...<newtag> -q '.commits[].commit.message' | head`.
- A `CHANGELOG*` in the repo if releases are sparse.
Fall back to WebFetch for non-GitHub forges.

Summarize the **substantive** changes between the two versions — bug fixes, security fixes (CVEs), behavior changes, API changes, new deps pulled in. Ignore docs/CI churn.

Then **combine changelog × usage** into an exposure judgment for *our* project:
- **Sensitive code?** — do we use the parts of the dep that touch auth/tokens, crypto/TLS, exec/subprocess, network listeners, deserialization of untrusted input, path/file handling, templating/SQL? A change in code we exercise on a sensitive path matters more than a changelog full of features we never call.
- **Heavy or light exposure?** — heavy = imported across many packages or on a hot/core path; light = a single helper, or test-only. Tie it back to the import surface from step 2.
- Call out specifically whether any changed behavior in the changelog lands in code we actually exercise. "v1.3 changed retry defaults" only matters if we use that client.

## Standard code review (dep + code only)

If the PR also changes project code, review those changes the normal way: invoke the built-in **`review`** skill (`/review`) via the Skill tool, scoped to the **project-code** changes — treat the manifest/lockfile/vendored churn as the dependency context (already covered above), not as code to line-review. Fold its findings into the output below under their own heading; don't let vendored noise drown the real review.

For dep-only PRs, skip this entirely — there is no project code to review.

## Output discipline

Follow the shared silent-gather-then-single-summary discipline in `../../CONVENTIONS.md`:
do all gathering, grepping, changelog reading, and (if applicable) the standard review
first, without narrating between calls. Then print **one** self-contained summary as the
last thing:

- **Classification** — dep-only or dep + code, and the bumped module(s) with `old → new`.
- **Per dependency:**
  - **Freshness** — new-release age and date; flag if too fresh / pseudo-version, otherwise "fine".
  - **Usage** — direct/indirect, what it does, import surface (counts + where), sensitive or not.
  - **Changelog & exposure** — the substantive changes, any CVE/security fix, and the exposure verdict (heavy/light, sensitive/not) tied to how we use it.
  - **Take** — one line: safe to bump now / wait for soak / look closer at X.
- **Code review** (dep + code only) — the standard-review findings by severity, under their own heading.

Be specific — module paths, versions, dates, `file:line`, blast radius. No emoji, no filler, no diplomatic hedging. If freshness or exposure argues for waiting, say so plainly.
