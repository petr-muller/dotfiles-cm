---
name: depbump-followup
description: Mine a dependency bump's changelog (including transitive) for project-improvement opportunities the new version unlocks — drop deprecated usage, adopt improved APIs, use new features — walk each one at a time, and emit an agent-ready prompt for each you accept
---

# Followup on a dependency bump — improvement opportunities

This PR bumps one or more dependencies. This command is **not** the dependency review (`/review:depbump` covers safety/freshness/exposure) and **not** a code review. It hunts for **work the new dependency version makes worth doing in our code**: stop calling functionality the new version deprecated, switch to an improved API the bump introduced, or adopt a genuinely useful new feature. It reads the changelog **between old and new** (including **transitive** dependencies pulled along by the bump), cross-references it against **how we actually use the dep**, walks each opportunity past you **one at a time**, and for each accepted one emits a **self-contained prompt you can hand to a separate agent**.

The mindset matches `/review:followup`: identify and hand off, don't do the work here. The *source* of opportunities is the dependency changelog × our usage, not TODOs or review threads.

## Establish context

Determine the PR and repo from the worktree — see `../../CONVENTIONS.md` ("Establishing
PR/repo context from a worktree"). Additionally, note whether the PR is **open** or
**already merged** (`gh pr view <N> --json state,mergedAt,mergeCommit`). If merged, capture
the **merge commit SHA** — accepted opportunities will be worked on the merged default
branch, not this PR's branch.

The worktree is checked out at the PR head. Resolve the base: `BASE=$(git merge-base HEAD <base-tracking-ref>)` where the base branch comes from `gh pr view <N> --repo <org>/<repo> --json baseRefName -q .baseRefName`.

Read `REVIEW.md` in the worktree root if present — a prior `/review:depbump` run may already record the changelog and our exposure; reuse it instead of re-fetching.

## Identify the bumped modules (direct and transitive)

From the manifest/lock diff, list every version change — **both direct and indirect/transitive** (a transitive bump can still deprecate or improve something we call directly). For Go:

```
git diff $BASE..HEAD -- go.mod go.sum vendor/modules.txt
```

Record per module: **module path**, **old → new version**, **direct or indirect** (`// indirect` marker). Note ecosystem (Go primary; Node/Python/Rust by analogy — see `/review:depbump`).

Prioritize where to dig: a module is **worth digging into** if we **import it ourselves** (grep the non-vendor tree for its import path) — even transitively-bumped modules we import directly matter. A transitive module we never import can still matter if a *direct* dep's changelog says "now requires / exposes <transitive> feature X", but otherwise deprioritize the pure-transitive churn.

## Read the changelogs and find what the bump unlocks

For each in-scope module, read the changelog **between old and new** (cover intermediate releases, not just the endpoints — a deprecation may land mid-range). Resolve the upstream repo from the module path or the proxy's `Origin.URL` (`curl -s "https://proxy.golang.org/<escaped-module>/@v/<newver>.info"`; uppercase → `!`+lowercase). Prefer `gh`:

```
gh release view <tag> --repo <owner>/<repo>          # per release in range
gh api repos/<owner>/<repo>/compare/<oldtag>...<newtag> -q '.commits[].commit.message'
```

Plus any `CHANGELOG*`/migration guide in the repo. Fall back to WebFetch for non-GitHub forges or release blogs.

From each changelog, extract the items that could **act on our code**, and tie each to **where we use the dep**:

- **Deprecations** — APIs/options the new version marks deprecated (or documents a replacement for) that **we currently call**. Grep our code for the deprecated symbol. These trend toward *must* — deprecated today, removed in a future bump.
- **Improved replacements** — a new API that supersedes an older one we use (e.g. context-aware variant, a typed/safer signature, a batched call replacing a loop). Worth switching if we use the old form.
- **New features** — capabilities the new version adds that would let us delete hand-rolled code, simplify, or gain a real benefit (performance, correctness, ergonomics). Only count it if there's a concrete place in *our* code that would use it — not "nice in the abstract".
- **Behavior/default changes** that suggest we should adjust our call sites (e.g. a default we currently override now matches upstream, or a knob we set is now redundant).

Grep our own code (excluding `vendor/`) for the dep's import path and the specific symbols the changelog names, so every opportunity points at real `file:line` call sites we own. If the changelog is rich but we touch none of it, say so — no opportunity.

## Form the candidate list

Category here is one of `deprecation` / `api-upgrade` / `new-feature` / `simplification` /
`default-change`; add the **dependency + version** that unlocks it and **what the changelog
says** (quote the deprecation note / release line). Otherwise follow the shared candidate
shape in `../../CONVENTIONS.md` — necessity guidance in particular: a deprecation we call is
a real *must/should*, a shiny feature we'd never use is not an opportunity.

Drop non-opportunities: anything that's actually a *bug* the bump introduces (that belongs in `/review:depbump`, possibly blocking), and abstract niceties with no call site of ours. Order most necessary / most valuable first. If there are no real opportunities, say so and stop.

## Walk one at a time

Follow the shared walk-and-record loop in `../../CONVENTIONS.md`. Question text (adapt naturally):

```
**[N/total] {category}: {title}** — unlocked by {module} {old}→{new}

**Our usage:** [where we call the affected API — `file/path:line`, how many sites.]

**What the bump offers:** [quote the deprecation / new-API / feature line from the changelog.]

**Necessity:** must / should / could — [one clause; for deprecations note the eventual-removal risk.]

**Proposed scope:** [what the followup would concretely change in our code, tight enough to hand to an agent.]
```

## Build each accepted opportunity's prompt

Follow the shared handoff-prompt format in `../../CONVENTIONS.md`. Here, "what and where"
means the repo (`<org>/<repo>`), that this followup is enabled by **PR #N — "<title>"**
bumping **<module> <old>→<new>** (include the merge commit SHA if merged), and the specific
files/call sites; the task should cite the new/old API symbols and the deprecation/feature
note from the changelog.

Write it as a prompt addressed to the agent ("In `<org>/<repo>`, now that PR #N bumped <module> to <new>, migrate … "), not as a description of one.

## After all items

Follow the shared after-all-items steps in `../../CONVENTIONS.md`. Record into a
`## Dependency followups` section (MD) / **Dependency followups** section (HTML) — each
item's entry includes the module+version that unlocks it alongside the shared fields.

## Rules

- **One item at a time.** Never present multiple opportunities in a single message.
- **Real call sites only.** Every opportunity must point at code *we* own that uses the affected API. No abstract "could be nice" without a call site.
- **Read the changelog across the range**, not just endpoints — deprecations land mid-range. Cover transitive bumps we import.
- **Be honest about necessity.** A deprecation we call is a real *must/should*; a shiny feature we'd never use is not an opportunity. A short, true list beats a padded one.
- **Self-contained prompts.** Each must stand alone for a cold agent on the merged tree — no "see above", no reliance on this session.
- No emoji, no filler.
