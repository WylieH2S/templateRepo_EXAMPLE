# {{PROJECT_NAME}} -- Current Mission

> Mandatory mission-control layer.
> Read this before choosing implementation work.
> This file is intentionally short. If it becomes a journal, it has failed.

---

## North Star

<!-- One sentence: the long-term outcome that justifies all current work. -->

## Active Priority

<!-- The single highest-priority item in flight RIGHT NOW. -->

## In-Scope This Phase

<!-- Bullet list of what is fair game to touch in the current phase. -->

## Out-of-Scope

<!-- Bullet list of what is explicitly not being touched, even if tempting. -->

## Current Discipline

<!-- Rules of engagement for the current phase. Examples:
     - One fragile subsystem per build.
     - One live-test question per build.
     - Prefer removing noise before adding signal.
     - If a proposed change cannot name its revert path, do not implement it. -->

## Stop Conditions

Stop and return control to {{OWNER_NAME}} if any of these happen:

- The next proposed change touches more than one fragile subsystem.
- The test question cannot be stated in one sentence.
- The implementation relies on assumptions not present in current source.
- A finding from a prior session is being treated as current truth without verification.

## Task Contract Required Before Code

Before any code change, write this contract in the assistant response or working notes:

```
Task:
Blocker:
Design intent served:
Subsystem:
Files likely touched:
Explicitly not touching:
Expected result:
Live test:
Revert path:
```

If the contract is fuzzy, do not code.

## Priority Ranking

<!-- For queued items beyond the active priority, rank them. -->

---

_Last updated: {{TODAY}}_
