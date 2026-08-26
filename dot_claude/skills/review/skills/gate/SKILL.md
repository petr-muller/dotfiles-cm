---
name: gate
description: Gate a reviewed PR for merge — check that prior findings are addressed and surface independent merge risk, then recommend merge / hold / do-not-merge
---

# Gate the PR for merge

The PR has **already been reviewed** — by me (a local `REVIEW.md` exists) and/or by others (reviews and comments on GitHub). This command is not another code review. It is a **mergeability decision aid**: take the existing review evidence as given, check the current state of the PR against it, layer an independent merge-risk pass on top, and recommend **merge / hold / do-not-merge**.

Two areas matter, in order:

1. **Are the important prior findings addressed?** — cross-reference earlier review findings (local `REVIEW.md` + the reviews/comments on the PR) against the current code. Surface mainly the findings that are **not addressed or borderline**; don't re-litigate the ones clearly resolved.
2. **Is this risky to merge regardless of the reviews?** — independent pass for breakage, with emphasis on upstream projects where we don't control all deployments (existing instances must not break): API changes, configuration changes, behavioral/functional changes.

This is a decision aid **for the maintainer**, not a merge-queue status check. It exists to surface substantive risk — unresolved concerns, unaddressed feedback, backward-incompatible changes — so a human can decide whether to allow the merge. It has nothing to say about CI status, `tide`/merge-queue mechanics, required labels (`lgtm`, `approved`, hold labels), branch protection, or `mergeable`/`mergeStateStatus`/`reviewDecision` — those are mechanical gates GitHub or the merge bot already enforce and report on their own; do not fetch them, do not mention them, and never let a missing label or bot-reported "not mergeable" status drive the verdict. Judge only the substance: what reviewers raised, whether it was addressed, and independent risk in the diff.

## Establish context

Determine the PR and repo from the worktree — see `../../CONVENTIONS.md` ("Establishing
PR/repo context from a worktree").

Read `REVIEW.md` in the worktree root if present. Parse frontmatter (`pr`, `head_sha` → `OLD_SHA`, `base`, `reviewed_at`, `verdict`) and the findings list (severity tokens per `../../CONVENTIONS.md`). If absent, gate still runs from the PR-side evidence alone — just note that there's no local review artifact.

## Gather evidence (parallel, read-only)

Batch these:

1. **Current PR head + state** — `gh pr view <N> --repo <org>/<repo> --json headRefOid,state,title -q .` → `NEW_SHA`. Note only whether it's already merged or closed.
2. **Make `NEW_SHA` (and `OLD_SHA`) local** — `git fetch upstream pull/<N>/head` (fall back to `origin`).
3. **What changed since the review** — if `OLD_SHA` is known and reachable: `git log --oneline OLD_SHA..NEW_SHA` and `git diff --stat OLD_SHA..NEW_SHA`. If force-pushed / unreachable, note it and use `gh pr view --json commits`.
4. **Reviews** — `gh api repos/<org>/<repo>/pulls/<N>/reviews --jq '.[] | select(.state != "PENDING")'`. Note `state` (`CHANGES_REQUESTED`, `APPROVED`, `COMMENTED`), author, `submitted_at`, body.
5. **Inline comments** — `gh api repos/<org>/<repo>/pulls/<N>/comments` (path, line, body, author, created_at; group threads).
6. **Issue comments** — `gh api repos/<org>/<repo>/issues/<N>/comments` (actionable feedback + holds; skip bot noise and pure LGTM).

## Assemble the set of important findings

Pull together, de-duplicated:
- From `REVIEW.md`: the `blocking` and `should-fix` findings (carry `nit`/`question` only if they touch real risk).
- From the PR: every `CHANGES_REQUESTED` review and its inline comments, substantive inline comments from any reviewer, and explicit holds/blocking comments.

Skip my own already-resolved nits and pure approvals. The goal is the *gating* set — things whose disposition affects whether this should merge.

## Area 1 — are the important findings addressed?

For each item in the gating set, **read the current code** at the relevant path/lines (and, where useful, the `OLD_SHA..NEW_SHA` diff for that file) and classify:

- **addressed** — a later commit clearly resolves it. Don't dwell on these.
- **not-addressed** — still stands in the current head.
- **borderline** — partially addressed, addressed in a way that may not satisfy the reviewer, or addressed-by-discussion without a code change.
- **can't-tell** — needs the author/reviewer to confirm (say what you'd ask).

Present **mainly the not-addressed / borderline / can't-tell** items. For each, give: the finding (one line, attributed to its source — `REVIEW.md` or `@reviewer`), what the current code does, and a **recommended disposition** (e.g. "blocks merge — the nil-deref at `foo.go:47` is unchanged"; "fine to merge — addressed in `abc123`, reviewer hasn't re-approved but the concern is gone"). Be honest: if a reviewer's blocking concern was waved away without being fixed, say it gates merge.

## Area 2 — independent merge risk

Regardless of what the reviews covered, scan the diff (`OLD_SHA..NEW_SHA` if reviewing the delta since review, else the full PR diff vs `base`) for changes that could break **existing deployments we don't control** in upstream projects. Look specifically for:

- **API changes** — exported library surface (Go: exported funcs/types/consts/struct fields removed, renamed, or signature-changed), Kubernetes API / CRD changes (`api/`, `*_types.go`, CRD YAML, schema/validation, version bumps, defaulting/conversion), proto/gRPC. Flag anything backward-incompatible or requiring coordinated rollout.
- **Configuration changes** — flags added/removed/renamed/defaults changed, config-file schema changes, env vars, required-vs-optional shifts. A changed default is a silent behavior change for everyone who didn't set it.
- **Functional / behavioral changes** — changed default behavior, removed/deprecated features, altered output or wire formats, data migrations, changed error/exit semantics.

### Use repository skills if available

The repo may carry skills built for exactly this kind of breakage evaluation. **Discover and use them:**
- Glob `.claude/skills/*/SKILL.md` (includes overlaid `muller-*` skills) and read their `description` frontmatter.
- If one is suited to the change at hand — e.g. CRD/API-compat review, Go API-surface checks, config-schema validation, or a project-specific compatibility checker — **invoke it via the Skill tool** and fold its findings into this pass.
- Use judgement: only invoke skills relevant to what the diff actually touches. If none are relevant, do the analysis directly.

For each risk, state the blast radius ("affects every component that imports `pkg/x`", "breaks clusters with existing `Foo` CRs", "anyone not setting `--bar` gets new behavior") and whether it's release-noted / gated / opt-in.

## Decide

Produce one verdict:

- **merge** — prior gating findings are addressed (or acceptably dispositioned) and no unacceptable merge risk. Note any caveats the author should release-note.
- **hold** — something should be resolved or confirmed first (an unaddressed should-fix, a risky change lacking a release note or migration path, a reviewer's concern silently dropped, an open question that genuinely needs an answer before merging). Say exactly what unblocks it.
- **do-not-merge** — an unaddressed blocking finding or a backward-incompatible change that will break existing deployments without justification/gating.

Give a one-paragraph rationale and a short **gating list**: the specific items (with `file:line` and source) that drive the verdict.

## Persist into REVIEW.* if they exist

If `REVIEW.md` / `REVIEW.html` exist in the worktree root, record the gate outcome **in place**, keeping the two in sync. Do **not** overwrite the original review `verdict` — the gate decision is separate, layered on top.

In `REVIEW.md` frontmatter, add/update a `gate:` block:

```yaml
gate:
  decision: merge | hold | do-not-merge
  gated_at: <ISO 8601 UTC, Z suffix>   # date -u -Iseconds | sed 's/+00:00/Z/'
  gated_head_sha: <NEW_SHA>
  reviewed_head_sha: <OLD_SHA>         # head the original review covered
```

And add/update a `## Gate` section in the body (place it right after the frontmatter/`# Review` heading, before `## What this PR does`): the verdict line, the rationale paragraph, the gating list, and the Area-2 risks. On re-runs, replace the previous `## Gate` section rather than appending a second one.

In `REVIEW.html`, mirror this: add a **Gate** callout near the top (just after the existing verdict block) styled consistently with the file's existing CSS — read the file and reuse its classes; a colored box like `.verdict` works (green for merge, amber for hold, red for do-not-merge). Mirror the same gating list and risks. Replace any prior Gate block on re-runs.

If `REVIEW.md` / `REVIEW.html` do **not** exist, don't create them — present the gate decision in the session only.

Generate the timestamp during the gather phase (`date -u -Iseconds | sed 's/+00:00/Z/'`), not as a separate step before the edits.

## Output discipline

The user sees every tool call. Do all gathering, code reading, skill invocation, and artifact edits **first**, without narrating between calls. Then print **one** self-contained summary as the last thing:

- **Verdict**: `merge` / `hold` / `do-not-merge`, one-line rationale.
- **Findings disposition** (Area 1): only the not-addressed / borderline / can't-tell items, each with source, current state, and recommended disposition. One line if everything important is addressed.
- **Merge risk** (Area 2): the API / config / behavioral risks found (and which skills, if any, informed them), with blast radius. "No notable merge risk" if clean.
- **Gating list**: the specific items driving the verdict.
- **Artifacts**: the absolute paths of `REVIEW.md` / `REVIEW.html` if updated; otherwise note nothing was written.

Be specific — names, paths, SHAs, blast radius. No emoji, no filler, no diplomatic hedging. If a concern is unresolved, say it gates; if it's fine, say merge.
