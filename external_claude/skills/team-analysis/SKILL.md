---
name: team-analysis
description: |
  Spins up a parallel agent team to analyze code/features/design across 4 axes — 2026 best practice, over-engineering detection, code structure, judged by the [KISS > YAGNI > DRY] priority.
  Use for analysis, review, approach comparison, design check, "how should I structure this?", "isn't this over-engineered?".
  Do NOT use for trivial work (typo / one-line fixes) — overkill.
---

# Team Analysis — Parallel Analysis Team

> **Philosophy**: On judgment conflict, **KISS > YAGNI > DRY**. Simplicity beats de-duplication.

---

## 1. When

- "Analyze this feature/code", "compare approaches", "check if this is over-engineered"
- Design review before implementation, structural audit of existing code
- Invoked as the analysis stage of the `/analyze-ship` pipeline

## 2. Pre-flight

1. Read `CLAUDE.md` — respect project rules
2. Scope the target (files / feature / directory)
3. If trivial → **stop**, handle inline without a team

---

## 3. Team Composition (parallel fan-out, one message)

Spawn 4 `Agent`s **concurrently in a single message**. Each owns one axis.

### Agent A — Researcher (2026 best practice)
- `subagent_type`: `Explore` or `general-purpose` + `WebSearch`
- **WebSearch queries MUST include `2026`** (confirm current recommended patterns)
- Output: industry standards, framework official guidance, deprecated-pattern warnings

### Agent B — Structure Analyst (code structure)
- `subagent_type`: `Explore` or `architect-medium`
- Map existing patterns, module boundaries, dependencies, coupling
- Output: structural strengths/weaknesses, boundary violations, circular deps

### Agent C — Over-engineering Auditor
- `subagent_type`: `code-reviewer` or `architect-medium`
- Detect needless abstraction, unused generalization, premature optimization, speculative extension points
- Tag each finding with the violated principle — **KISS / YAGNI / DRY**
- Output: `[OVERKILL]` items + simplification proposals

### Agent D — (optional) Risk / Estimator
- Complex work only. Risk, effort, implementation order
- Skip for simple analysis (YAGNI)

> The head agent (main) is NOT spawned — it synthesizes A/B/C/D results directly.

---

## 4. Synthesis (head, inline)

Merge parallel results → resolve conflicts via **KISS > YAGNI > DRY**. Output:

```markdown
## 🔬 Team Analysis

### 📡 2026 Best Practice (Researcher)
- Recommended: [pattern]
- Warning (deprecated): [item]

### 🏗️ Code Structure (Structure)
| Area | Rating | Note |
|------|--------|------|
| Module boundaries | 🟢/🟡/🔴 | … |
| Coupling | 🟢/🟡/🔴 | … |

### ⚠️ Over-engineering (Auditor)
| Item | Violation | Simplification |
|------|-----------|----------------|
| [abstraction X] | YAGNI | [remove / inline] |
| [duplication Y] | DRY | [extract] |

> Conflict handling: [adopt A by KISS — outranks DRY], etc. State the rationale.

### 🎯 Final Recommendation
1. **Keep**: [leave as-is]
2. **Simplify**: [remove the overkill]
3. **Reinforce**: [what's missing]

### Implementation Order (if applicable)
1. [ ] …
```

---

## 5. Principles

1. **Parallel fan-out** — spawn A/B/C(/D) concurrently in one message
2. **KISS > YAGNI > DRY** — always this order on conflict, state rationale
3. **Reject trivial work** — no heavy process for small changes
4. **Analysis only** — do not implement; wait for user approval (or proceed to the next stage if under `/analyze-ship`)
