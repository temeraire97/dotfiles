---
name: analyze-ship
description: |
  End-to-end "analyze then build" pipeline. Orchestrates, in order: grill (lock requirements) → team-analysis (parallel team review) → to-prd (write PRD) → to-issues (break into issues) → task-loop (implement, verify, merge).
  Use to drive a large feature, refactor, or migration "from start to finish".
  Do NOT use for trivial work — overkill.
---

# Analyze-Ship — Analyze→Build Pipeline

> **Thin orchestrator.** Each stage invokes an existing skill via the `Skill` tool **on demand (lazy load)**. No content duplicated — single source of truth (DRY).
> **Philosophy**: KISS > YAGNI > DRY.

---

## Pipeline

```
grill-me  →  team-analysis  →  to-prd  →  to-issues  →  task-loop
(lock reqs)   (parallel team)   (PRD)      (split issues) (build · verify · merge)
```

Each stage = one `Skill` call. **Each stage's output feeds the next.** Approval gate between stages.

---

## Stages

### 1. Grill — Lock Requirements
- `Skill(skill: "grill-me")`
- Interrogate requirements, scope, edge cases until ambiguity is gone
- ✅ Gate: proceed when shared understanding is reached

### 2. Team Analysis — Parallel Review
- `Skill(skill: "team-analysis")`
- 4 axes: 2026 best practice / structure / over-engineering / [KISS>YAGNI>DRY]
- Produces: recommendation + implementation order
- ✅ Gate: user approves the approach

### 3. To PRD
- `Skill(skill: "to-prd")`
- Stage 1+2 context → write & publish PRD
- ✅ Gate: confirm PRD

### 4. To Issues
- `Skill(skill: "to-issues")`
- PRD → tracer-bullet vertical-slice issues
- ✅ Gate: confirm issue list

### 5. Task Loop — Implement
- `Skill(skill: "task-loop")`
- branch → task decomposition → impl team (parallel) → commit → verification team → recursive fixes → PR merge

---

## Principles

1. **Sequential lazy load** — never preload all 5 skills. Each SKILL.md enters context only at its stage → saves context
2. **Respect gates** — advance only after user approval per stage. No unsupervised runaway
3. **Skipping allowed** — if the user says "skip grill" / "PRD already exists", drop that stage and move on
4. **Chain outputs** — explicitly pass the prior stage's result as input to the next skill
5. **Abortable** — if the user stops at any gate, end there
6. **Orchestrator-only** — analyze-ship and its sub-skills NEVER edit files from the main loop; all implementation is delegated to Sonnet executors inside `task-loop` (per CLAUDE.md Model Routing). The main loop drives the pipeline and reviews.
