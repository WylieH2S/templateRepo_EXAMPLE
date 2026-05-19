---
name: ski-lift
description: Capture a SKI LIFT observation — a tool, library, or capability that would automate or eliminate something we're doing manually. Appends to ai_context/ski_lift_log.chloeai in the standard format. Use whenever you notice we're doing manually what an existing tool would do better.
---

# /ski-lift

A **SKI LIFT** is raised when we are doing X manually and a tool, library, feature, or platform capability would automate or eliminate it. It is a non-blocking lateral observation — the user decides whether to act on it.

(Formal definition: ADR-007 in templateRepo_EXAMPLE / `ai_context/decisions/007-ski-lift-mechanism.chloeai`.)

## When to raise a SKI LIFT

- We are doing something manually that an existing tool would automate
- We are implementing a solved problem (better solutions exist)
- We are working around a constraint that has a simpler bypass via existing tooling
- A relevant new capability has emerged that changes the calculus

## What this skill does

1. Locate the SKI LIFT log: `ai_context/ski_lift_log.chloeai`. Create it if missing (with a header).
2. Collect the SKI LIFT fields from the user. Ask only the ones not obvious from context.
3. Format and append the entry.
4. Confirm to the user (don't ask for further action — SKI LIFTs are observations, not commitments).

## Entry format

```
### YYYY-MM-DD | [REPO or CROSS-CUTTING] | Short Title
**Doing manually:** [what we're doing by hand]
**The ski lift:** [tool/feature/library + link if known]
**Adoption effort:** low | medium | high
**Why it matters:** [one sentence]
**Status:** Open
```

## Inline signal format (during work, before invoking this skill)

If you spotted the SKI LIFT mid-conversation, signal it inline first so the user sees it in context:

```
SKI LIFT: [what we're doing manually] → [the ski lift] | effort: [low/medium/high] | why it matters: [one sentence]
```

Then invoke this skill to persist it.

## Header (when creating the file for the first time)

```
#CHLOEAI:1
TYPE="ski_lift_log"
SCOPE="cross-cutting or per-repo tooling intelligence"
FORMAT="see ADR-007 for spec"

# SKI LIFT LOG

Open entries — review periodically (typically at STRATEGIC zoom moments).
Mark Adopted (YYYY-MM-DD) or Declined (reason) when closed.

---

```

## Fields to gather

| Field | Source |
|---|---|
| date | today |
| scope | `[REPO]` if specific to this project; `[CROSS-CUTTING]` if affects multiple repos or workflow itself |
| title | short — "Adopt lefthook for pre-commit guards" |
| doing manually | what's the manual work being replaced |
| the ski lift | tool/feature name + link |
| adoption effort | low (under an hour) / medium (a session) / high (a project) |
| why it matters | one-sentence value |

## Status lifecycle

- **Open** — captured, no decision yet (default)
- **Adopted (YYYY-MM-DD)** — implemented; note the adoption date
- **Declined (reason)** — explicitly decided against; note the reason

Never silently delete SKI LIFT entries. They're a record of what was considered.

## Review cadence

Surface open entries at STRATEGIC zoom moments. The log is Tier 2 — read on demand, not every session.
