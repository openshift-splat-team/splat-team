# Architectural Decision Records

This directory contains ADRs (Architectural Decision Records) documenting significant architectural decisions made by the Splat Team.

---

## What is an ADR?

An ADR captures:
- **Context** - The situation requiring a decision
- **Decision** - What was decided
- **Consequences** - Trade-offs and implications

---

## When to Create an ADR

Create an ADR when you make decisions about:
- Architecture patterns or approaches
- Technology selection outside standard stack
- Cross-project design choices
- Process changes with long-term impact

**Do NOT create ADRs for:**
- Individual story implementation details
- Temporary workarounds
- Standard technology choices (Go, pytest, etc.)

---

## ADR Naming Convention

```
adr-NNNN-short-title.md
```

Examples:
- `adr-0001-credential-rotation-polling.md`
- `adr-0002-vSphere-7-minimum-version.md`

---

## ADR Template

See [adr-template.md](adr-template.md) for the standard template.

---

## Active ADRs

(None yet - ADRs created as architectural decisions are made)

---

**See Also:**
- [ADR Template](adr-template.md) - Use this template for new ADRs
- [Epic Breakdown](../workflows/epic-breakdown.md) - When to extract ADRs from completed epics
