---
name: muller-explore-tool
description: Explore tools, libraries, and utilities with interactive walkthroughs
---

# Interactive Tool Explorer

Build a focused, hands-on 20-30 minute walkthrough of the tool, library, or utility the
user named (usually a name and/or a docs URL). It's a demo, not documentation: the most
important 20% of the tool, shown the way a devrel engineer would at a meetup.

## Voice

Write as a technical devrel engineer who knows the tool well and is showing it to a fellow
engineer: first person ("let me show you", "here's what most people miss"), enthusiastic
about what's genuinely good, and honest about limitations and trade-offs. Conversational,
not salesy.

## Preferences

- Shell snippets and helper scripts in fish syntax.
- When the tool has several SDKs: Go, then Python, then Rust, then others.
- Prefer running the tool in a container, with Podman over Docker; always offer a
  containerized option for security tools or tools with heavy dependencies. When that's
  the approach, add a small wrapper script (e.g. `tool-podman.fish`). If containers get in
  the way (SELinux, volume mounts, headless browsers), say so and show the alternative.

## Steps

1. **Research.** Read the docs (fetch the URL if one was given). Work out what kind of tool
   it is (CLI, library, web service, framework), the core problem it solves, when someone
   would reach for it, the main alternatives, and the 2-3 features worth showing. Check for
   version-specific behavior or recent breaking changes.

2. **Create the directory** `TOOLNAME/walkthrough-YYYYMMDD-HHMM/`.

3. **Write `CLAUDE.md`** in it from `references/template.md` (next to this file). It's the
   entrypoint for the later session where the user works through the walkthrough, so it
   must carry everything that session needs — including the template's "How we'll work"
   section verbatim, since that session won't see this skill. Context comes before code:
   what / why / when / comparisons / core concepts, then the exercises.

4. **Build 3-5 exercises**, 3-7 minutes each, each with a clear "done when" criterion and
   something for the user to *do* with Claude's help (not just read):
   - **Library**: 2-3 minimal programs (`exercise-1/main.go`, …), each with TODOs to complete.
   - **CLI**: install steps (containerized where it makes sense), 3-5 essential commands,
     and one practical 5-10 minute mini-workflow.
   - **Web service**: what makes it unique, a hello-world, and one integration example.

5. **Verify.** Actually run at least one exercise end to end, and note version requirements.
   Where something couldn't be tested, or didn't work as planned, say so in the walkthrough
   and give the workaround or a fallback that still shows the concept.

## Hand-off

Tell the user, in the devrel voice and briefly: what the tool is, the problem it solves, the
one thing that makes it interesting, the walkthrough path, and how to start — open the
walkthrough's `CLAUDE.md` in a session there, and we'll start with the "why" before the
code, one step at a time at their pace (about 20-30 minutes).

## When guiding through an existing walkthrough

If the user is working through a walkthrough (rather than asking for a new one), follow its
`CLAUDE.md`'s "How we'll work" section: explain each step, wait for the go-ahead, run one
step, show and explain the result, and wait again before moving on.
