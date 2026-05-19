---
name: handoff
description: Write a session-end HANDOFF block to the project's continuity file and validate the substrate. Use at the end of a session when you've made meaningful progress and want the next session to pick up cleanly. Captures zoom_level, recommended_model, recommended_effort, task_queue, and next_zoom_trigger in the standard HI Mode format.
---

# /handoff

Automates the SESSION wrap protocol from HI Mode. Captures session-end state in the standard HANDOFF block format and appends it to the project's continuity file.

## What this skill does

1. Determine the target file: prefer `readme_AI.chloeai`'s `HANDOFF_LOG:` section if present; otherwise append to `AI_HANDOFF.chloeai`.
2. Find the next SESSION-N number by scanning prior entries.
3. Collect the HANDOFF fields. Infer from the current session where possible; ask the user only for fields that require judgment.
4. Format and append the block.
5. Run `validate-substrate` as a post-check.
6. Report the new block + validation result.

## HANDOFF block format

```
@YYYY-MM-DD|SESSION-N|
zoom_level=STRATEGIC|TACTICAL|OPERATIONAL
recommended_model=haiku|sonnet|opus
recommended_effort=low|medium|high
reason="why this tier suits the next tasks"
task_queue=[
  {tier:X, task:"..."},
  ...
]
next_zoom_trigger="condition that should shift zoom level"
signed="Model | charter version | date"
```

## Fields to gather

| Field | Source |
|---|---|
| date | today (system) |
| SESSION-N | next sequential number after last entry |
| zoom_level | from current HI Mode zoom — ask if uncertain |
| recommended_model | infer from task_queue tier distribution — ask to confirm |
| recommended_effort | derived from model (haiku→low, sonnet→medium, opus→high) — ask to confirm |
| reason | one sentence — synthesize from session work |
| task_queue | list of `{tier, task}` items; pull from open TODOs, plan items, and known follow-ups |
| next_zoom_trigger | one sentence — what condition flips the zoom level |
| signed | model name + charter version + today's date |

## Ask the user (one consolidated question, not a barrage)

If any of the inferred values look wrong or uncertain, surface them in one AskUserQuestion call covering all the open decisions at once. Do not pepper the user with one question per field.

## Writeback rules

- Append-only. Do not rewrite prior HANDOFF entries.
- The block goes at the bottom of the target file (after the last existing block).
- Preserve exact format — downstream tools parse this.

## Post-step

After writing the block, run `bash .claude/skills/validate-substrate/validate.sh`. If it fails, surface the failure to the user immediately — the HANDOFF is in but the substrate has a regression.

## When NOT to invoke

- Session made no material change (no code, no decisions, no state shift). HANDOFF blocks are signal, not ritual.
- User is mid-task and not winding down. HANDOFF is end-of-session.

## When to invoke

- User says "wrap this up" / "let's call it" / "end of session"
- Hitting a natural stopping point (phase complete, milestone shipped, blocker hit that needs human input)
- Context approaching compaction and you want the state captured cleanly before compression
