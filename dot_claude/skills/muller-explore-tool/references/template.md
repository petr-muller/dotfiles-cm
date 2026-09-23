# Walkthrough CLAUDE.md template

Fill in every bracket. Keep the conversational devrel voice; cut any section that has
nothing honest to say. The "How we'll work" section is copied verbatim — it's what makes
the later guiding session interactive, since that session only sees this file.

````markdown
# [Tool Name] Interactive Walkthrough

**Estimated time: 20-30 minutes**

Hey! Let me walk you through [Tool Name] - I think you're going to find this pretty interesting.

## How we'll work (instructions for Claude)

When guiding through this walkthrough:
1. Before each step, say what you're about to run and why.
2. Wait for the user's go-ahead before running it.
3. Run one step, show the result, and explain what it means.
4. Wait for acknowledgment before the next step. Never batch several steps.
Prefer fish syntax for shell snippets and Podman for containers. If something doesn't work
as the walkthrough expects, say so and pivot to the fallback noted in the exercise.

## What is [Tool Name]?

[1-2 sentences, conversational - "So [Tool Name] is basically..."]

## The Problem It Solves

Here's the thing - [the pain point, relatable, with a concrete "I've been there" scenario].

Before [Tool Name]:
```
[the painful way]
```

With [Tool Name]:
```
[the better way]
```

[Point out what's improved.]

## When Would You Use It?

This really shines when you're:
- [Use case 1 - why it's good here]
- [Use case 2]
- [Use case 3]

**Real talk - you probably don't need it if:**
- [Anti-use-case, honestly explained]

## How It Compares

- **vs [Alternative 1]:** [where this wins, where the alternative is better]
- **vs [Alternative 2]:** [key trade-offs]

The TL;DR: [when to pick this vs alternatives]

## Core Concepts

1. **[Concept 1]:** [whiteboard explanation]
2. **[Concept 2]:** [why this design decision matters]
3. **[Concept 3]:** ["this tripped me up at first"]

## What We'll Build Together

By the time we're done, you'll:
- [Concrete outcome 1]
- [Concrete outcome 2]
- [The "aha moment"]

## Prerequisites

- [Requirement / version, with a quick install tip - containerized if possible]

---

## Hands-On Exercises

### Exercise 1: [Interesting title]

**Time: X minutes** · File: `exercise-1/...`

[Why this exercise is cool.]

**What you'll do:** [task + why]

**Done when:** [observable success criterion]

**Pro tip:** [insider insight]

**If it doesn't work:** [known pitfall and fallback]

### Exercise 2: [Builds on Exercise 1]

**Time: X minutes** · File: `exercise-2/...`

**What you'll do:** [task]

**Done when:** [criterion]

**Watch for this:** [common gotcha]

### Exercise 3: [The "aha" part]

**Time: X minutes** · File: `exercise-3/...`

**What you'll do:** [task]

**Done when:** [criterion]

**Why this matters:** [real-world relevance]

---

## Nice Work!

**Key takeaways:**
- [What makes this tool valuable]
- [When to reach for it]
- [The core concept to remember]

## Where to Go From Here

- [Next logical step]
- [Official docs link - what they cover well]
- [Advanced feature to look into]
- [Integration advice / gotcha / performance tip]

Ask me anything about what we covered - or anything else about [Tool Name].
````
