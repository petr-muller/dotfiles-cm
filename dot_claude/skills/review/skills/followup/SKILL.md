---
name: followup
description: Identify post-merge followup work for a PR about to merge or recently merged, walk each opportunity one at a time, and emit an agent-ready prompt for each one you accept
---

# Followup after merge

The PR is about to be merged, or just merged. The diff and reviews are settled — this command does not re-review them. Instead, take the stance of a thoughtful maintainer the moment after hitting merge: **"OK, this landed — now that it has, is there anything we can or should do to leave the codebase better than we found it?"** That question is the whole job. Answer it broadly and with judgment.

The answer might be an obvious loose end (a deferred TODO, a doc the new flag needs, an untested path) or something less literal that this change *invites* — a now-removable workaround, an abstraction the new code makes worth extracting, a neighbouring rough edge the diff put a spotlight on, a simplification that only becomes possible once this is in. Don't restrict yourself to tidying what the PR touched; the merge is a prompt to think about the surrounding code, not just the diff. Be genuinely creative here — the best followups are often the ones nobody wrote down.

It walks each opportunity past you **one at a time**, lets you accept / skip / reshape it, and for each accepted one emits a **self-contained prompt you can hand to a separate agent** to actually do the work.

## Establish context

Determine the PR and repo from the worktree — see `../../CONVENTIONS.md` ("Establishing
PR/repo context from a worktree"). Additionally, note whether the PR is **open (about to
merge)** or **already merged** (`gh pr view <N> --json state,mergedAt,mergeCommit`). If
merged, capture the **merge commit SHA** — the followup agent will work on the merged
default branch, not this PR's branch.

Read `REVIEW.md` in the worktree root if present — its open questions, its `should-fix`/`nit`/`question` findings, and anything noted as deferred are prime followup sources.

## Gather context (read-only)

Build a picture of what just changed and the ground around it. Batch these:

1. **PR diff + description** — `gh pr view <N> --repo <org>/<repo> --json title,body,files -q .` and the diff (`git diff <base>...<head>`, or `gh pr diff <N>`).
2. **TODOs introduced by the PR** — grep the diff / changed files for `TODO`, `FIXME`, `XXX`, `HACK` added in this PR (not pre-existing ones elsewhere).
3. **`REVIEW.md`** — open questions, unaddressed `should-fix`/`nit` findings, and questions that imply later work.
4. **Deferred review threads** — `gh api repos/<org>/<repo>/pulls/<N>/comments` and `.../issues/<N>/comments`; look for "follow-up", "in a later PR", "out of scope (for now)", "we should later", "filed/should file an issue", "leaving as TODO". Skip bot noise.
5. **The neighbourhood** — read the files the PR touched and the code immediately around them, not just the changed lines. The most interesting followups usually live just outside the diff.

Then think like the maintainer asking the question. Don't run a checklist — let the change suggest its own opportunities. To prime that thinking (these are **examples, not a required list** — ignore any that don't fit, and reach for things not on it):
- A deferred review thread or punted suggestion that's worth picking up now.
- New flags / config / API / CRD fields whose docs didn't land with them.
- New code paths that nothing exercises yet.
- Code left transitional, duplicated, or scaffolded to keep the PR small — now finishable.
- A workaround or special-case that this change makes removable.
- An abstraction or shared helper the new code makes worth extracting.
- A feature flag / gate / deprecation that schedules future work.
- A nearby rough edge the diff threw into relief — naming, a leaky boundary, an inconsistency — that it's now natural to fix.

The point is the maintainer's question, not the bullets. If something genuinely good doesn't fit any category here, propose it anyway.

## Form the candidate list

Category here is a short label that fits (`cleanup` / `docs` / `tests` / `tech-debt` /
`deferred-review` / `todo` / `removal` are common, but coin your own if it captures the idea
better); add **why it's followup and not part of the merge**. Otherwise follow the shared
candidate shape in `../../CONVENTIONS.md`.

Order most necessary / most valuable first. If there are no real followups, say so and stop.

## Walk one at a time

Follow the shared walk-and-record loop in `../../CONVENTIONS.md`. Question text (adapt naturally):

```
**[N/total] {category}: {title}** (`file/path:line` or area)

**Why followup:** [1-2 sentences — why it's worth doing, and why it didn't block the merge.]

**Necessity:** must / should / could — [one clause of justification]

**Proposed scope:** [what the followup would concretely change/add, tight enough to hand to an agent.]
```

## Build each accepted followup's prompt

Follow the shared handoff-prompt format in `../../CONVENTIONS.md`. Here, "what and where"
means the repo (`<org>/<repo>`) and that this is post-merge followup to **PR #N — "<title>"**
(include the merge commit SHA if merged), plus the specific files/areas.

Write it as a prompt addressed to the agent ("In `<org>/<repo>`, following PR #N … do X. …"), not as a description of a prompt.

## After all items

Follow the shared after-all-items steps in `../../CONVENTIONS.md`. Record into a
`## Followups` section (MD) / **Followups** section (HTML).

## Rules

- **Answer the maintainer's question, not a checklist.** The categories and example lists are prompts for thinking, not the scope. A creative, well-judged followup that fits no listed category is exactly what's wanted; a rote one that just ticks a box is not.
- **One item at a time.** Never present multiple followups in a single message.
- **Read the code** before proposing each item; form your own opinion on whether it's worth doing.
- **Followup, not blocker.** If something actually must happen before merge, say so and point at `/review:gate` — don't smuggle it in as "followup".
- **Be honest about necessity.** Don't inflate a `could` into a `must`. A short, true list beats a long, padded one.
- **Self-contained prompts.** Each must stand alone for a cold agent on the merged tree — no "see above", no reliance on this session.
- **Always record into the artifacts.** Whenever `REVIEW.md` / `REVIEW.html` exist, the `Followups` section is written every run — never skip it. (Don't create either file if it's absent.)
- No emoji, no filler.
