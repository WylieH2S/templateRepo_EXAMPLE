# {{PROJECT_NAME}} -- Decision Log

> Append-only record of decisions still in effect.
> When a decision is superseded, mark it SUPERSEDED and reference the new decision.

---

## Entry Format

```
### YYYY-MM-DD | DEC-NNN | <short title>

**Context:** Why this decision was needed.
**Decision:** What was decided.
**Rationale:** Why this option over the alternatives.
**Impact:** What this changes downstream.
**Status:** Active | Superseded by DEC-NNN | Reverted
```

---

## Decisions

### {{TODAY}} | DEC-001 | Bootstrap from baseline-template

**Context:** New project starting from a known-good template.
**Decision:** Use `baseline-template` as the project skeleton.
**Rationale:** Battle-tested AI-collaboration conventions (`.{{AI}}ai` / `.hey{{HUMAN}}`, `ai_context/` package, HI Mode personality, append-only handoff journal).
**Impact:** Project conventions inherited from the template; subsequent decisions append below.
**Status:** Active
