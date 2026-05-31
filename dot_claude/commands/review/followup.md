---
description: Identify post-merge followup work for a PR about to merge or recently merged, walk each opportunity one at a time, and emit an agent-ready prompt for each one you accept
allowed-tools: Read, Edit, Write, Bash, Glob, Grep, AskUserQuestion
---

# Followup after merge

The PR is about to be merged, or just merged. The diff and reviews are settled — this command does not re-review them. Instead, take the stance of a thoughtful maintainer the moment after hitting merge: **"OK, this landed — now that it has, is there anything we can or should do to leave the codebase better than we found it?"** That question is the whole job. Answer it broadly and with judgment.

The answer might be an obvious loose end (a deferred TODO, a doc the new flag needs, an untested path) or something less literal that this change *invites* — a now-removable workaround, an abstraction the new code makes worth extracting, a neighbouring rough edge the diff put a spotlight on, a simplification that only becomes possible once this is in. Don't restrict yourself to tidying what the PR touched; the merge is a prompt to think about the surrounding code, not just the diff. Be genuinely creative here — the best followups are often the ones nobody wrote down.

It walks each opportunity past you **one at a time**, lets you accept / skip / reshape it, and for each accepted one emits a **self-contained prompt you can hand to a separate agent** to actually do the work.

## Establish context

Determine the PR and repo from the worktree, like `/review:address`:
- Branch is typically `N-review` (or `N-summarize`) — extract `N`. Otherwise infer from the checked-out branch via `gh pr view`.
- `<org>/<repo>` from git remotes (prefer `upstream`, fall back to `origin`).
- Note whether the PR is **open (about to merge)** or **already merged** (`gh pr view <N> --json state,mergedAt,mergeCommit`). If merged, capture the **merge commit SHA** — the followup agent will work on the merged default branch, not this PR's branch.

If the worktree doesn't correspond to a PR, say so and stop.

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

Each candidate has: a short **title**, a **category** (a short label that fits — `cleanup` / `docs` / `tests` / `tech-debt` / `deferred-review` / `todo` / `removal` are common, but coin your own if it captures the idea better), **where** (`file:line` or area), **why it's followup and not part of the merge**, and a **necessity** read — must (will bite if ignored) / should (clearly worth it) / could (nice-to-have). Read the relevant code before forming an opinion; don't just echo a comment. Drop non-followups (anything that actually should block the merge — surface those plainly and suggest `/review:gate` instead).

Order most necessary / most valuable first. If there are no real followups, say so and stop.

## Walk one at a time

For each candidate, present it with `AskUserQuestion`. **One item per message — never batch.**

Question text (adapt naturally):

```
**[N/total] {category}: {title}** (`file/path:line` or area)

**Why followup:** [1-2 sentences — why it's worth doing, and why it didn't block the merge.]

**Necessity:** must / should / could — [one clause of justification]

**Proposed scope:** [what the followup would concretely change/add, tight enough to hand to an agent.]
```

Options:
- **"Accept"** — this becomes a handoff prompt. (Don't write the prompt yet; collect it.)
- **"Skip"** — drop it, move on.
- **"Discuss"** — free-form conversation to refine or challenge the proposal. After discussing, **re-present the same item** with `AskUserQuestion`, with the scope revised per the discussion. The user's feedback shapes the eventual prompt.

After Accept or Skip, move straight to the next item — don't ask "continue?".

## Build each accepted followup's prompt

For every accepted item, compose **one self-contained prompt** for a separate agent. Assume the agent starts **cold** and works on the **merged default branch** (or current `main`), not this PR branch — so it must carry all the context it needs:

- **What and where**: the repo (`<org>/<repo>`), and that this is post-merge followup to **PR #N — "<title>"** (include the merge commit SHA if merged). Name the specific files/areas.
- **The task**: an imperative instruction describing exactly what to do, incorporating any constraints from the Discuss step.
- **Acceptance criteria**: how the agent knows it's done (tests pass, doc section added, TODO removed and behavior preserved, etc.).
- **Scope guard**: state what's out of scope so the agent doesn't sprawl.

Write it as a prompt addressed to the agent ("In `<org>/<repo>`, following PR #N … do X. …"), not as a description of a prompt.

## After all items

1. Print a one-line tally: accepted vs skipped.
2. Print each accepted followup's prompt in its **own fenced code block**, titled with the followup, so each is trivially copy-pasteable to dispatch to a separate agent. One block per followup.
3. **If `REVIEW.md` exists**, append (or replace, on re-runs) a `## Followups` section at the end of it recording each accepted followup — its title, category, necessity, where, and the full handoff prompt (in a fenced block). This keeps the artifact as the durable record. Do not touch the frontmatter or existing findings, and don't create `REVIEW.md` if it's absent.
4. **If `REVIEW.html` exists**, mirror the same followups into it (add or replace a **Followups** section near the end), styled consistently with the file's existing CSS — read the file and reuse its classes. Each followup: title, a category/necessity badge, the `file:line`/area, and the handoff prompt in a `<pre>` block so it stays copy-pasteable. Keep it in sync with the `REVIEW.md` `## Followups` section. Don't create `REVIEW.html` if it's absent.

Do **not** commit, and do **not** start doing the followup work yourself — this command only identifies and hands off.

## Rules

- **Answer the maintainer's question, not a checklist.** The categories and example lists are prompts for thinking, not the scope. A creative, well-judged followup that fits no listed category is exactly what's wanted; a rote one that just ticks a box is not.
- **One item at a time.** Never present multiple followups in a single message.
- **Read the code** before proposing each item; form your own opinion on whether it's worth doing.
- **Followup, not blocker.** If something actually must happen before merge, say so and point at `/review:gate` — don't smuggle it in as "followup".
- **Be honest about necessity.** Don't inflate a `could` into a `must`. A short, true list beats a long, padded one.
- **Self-contained prompts.** Each must stand alone for a cold agent on the merged tree — no "see above", no reliance on this session.
- No emoji, no filler.
