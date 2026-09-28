---
name: task-loop
description: |
  Executes large-scale implementation work that splits into multiple tasks as a recursive pipeline: "branch creation → task decomposition → implementation team (parallel where possible + head re-verification) → git-master commit → verification team (parallel) → recursive fixes → PR merge".
  Use for feature development, large refactors, migrations, multi-file changes — anything requiring multiple commits.
  Do NOT use for small single changes (typo fixes, single-file edits) — the process is overkill.
---

# Task Loop — Recursive Pipeline

> A recursive implementation process that **decomposes, commits, and verifies a Unit of Work task-by-task**.

---

## 1. Overview

**Hierarchy**: `Unit of Work (branch) → Task (commit) → Verification (recursive fixes)`

1 Unit of Work = 1 branch = 1 PR. Inside the branch, work is broken into N tasks, each mapped to 1 commit. Independent tasks may run **in parallel via an implementation team**, after which the **head agent re-verifies the parallel outputs** before moving on. Once all tasks are complete, a **verification team reviews in parallel**, and any issues spawn `[FIX]` tasks recursively within the same Unit of Work.

```
Unit of Work
   ├── Create branch (no prefix, descriptive name)
   ├── TaskCreate decomposition
   ├── Dependency analysis → parallelizable groups
   ├── Implementation loop
   │     ├─ Sequential tasks: in_progress → implement → git-master commit → completed
   │     └─ Parallel group:
   │           ├─ Spawn N executors in a single message
   │           ├─ Head agent re-verifies merged output (consistency, conflicts, contract drift)
   │           └─ git-master commits (one per task, or grouped logically)
   ├── Verification team (parallel)
   │     ├─ code-reviewer
   │     ├─ architect-medium (use architect/Opus for complex work)
   │     └─ WebSearch (must include current year)
   ├── ❓ Issues found?
   │     └─ Yes → [FIX] TaskCreate → implement → git-master commit → lightweight re-verify (code-reviewer-low)
   │          └─ Max recursion depth 2. On the 3rd round, report to user and request a decision.
   ├── Create PR (gh pr create)
   └── Merge PR + delete branch (gh pr merge --merge --delete-branch)
```

---

## 2. Trigger Conditions

Apply Task Loop if **any** of the following hold:

- Change spans 3 or more files
- Implementation + tests land together in one session
- A design decision requires validation
- User says things like "form a team", "task list", "verify it"
- The session is executing a plan/spec authored in an earlier session

**When NOT to use Task Loop**:
- Trivial 1–2 file edits, typo fixes
- Already in the middle of another branch where switching is inappropriate
- User explicitly asks for a minimal process ("just fix it directly")
- Read-only / investigation work (Explore is enough)

---

## 3. Roles (Team Composition)

| Team | Members | When deployed | Output |
|---|---|---|---|
| **Implementation Team (sequential)** | `executor` agent (Sonnet) | Each dependent task | Code + commit |
| **Implementation Team (parallel)** | Multiple `executor` agents in one message | Group of independent tasks | Code from N agents, merged |
| **Head Re-verification** | Main agent | After every parallel group | Cross-file consistency report, drift fix list |
| **Verification Team** | `code-reviewer` + `architect-medium` + `WebSearch`, parallel | After all tasks complete | Issue report (OK/WARN/BLOCK) |
| **Lightweight Re-verify** | `code-reviewer-low` alone | After each `[FIX]` commit | Pass/fail verdict |

**Principles**:
- All implementation — even one-line config or a single annotation — is delegated to a Sonnet `executor`. The main loop NEVER calls Edit/Write itself (enforced by the `block-main-impl` hook + the Model Routing rule in CLAUDE.md).
- Agent choice: simple/bounded tasks → `executor`; composite-logic / multi-file / reactive-async chains → `executor-high` (both Sonnet). 1-2 file mechanical tweaks → `cavecrew-builder`.
- The verification team **MUST run in parallel** — multiple Agent calls in a single message.

---

## 4. Step-by-step Flow

### Step 1. Pre-flight

```
1. Check git status across all affected repos
2. Ensure main is up to date (git pull --ff-only)
3. Confirm previous related work meets its Done criteria
4. Re-read local environment rules (CLAUDE.md, no-build rules, etc.)
```

### Step 2. Create branch

```bash
git checkout main
git pull --ff-only
git checkout -b {descriptive-name}
```

**Branch naming rules**:
- ❌ Forbidden: Git Flow prefixes like `feat/`, `fix/`, `chore/`, `docs/`
- ✅ Preferred: descriptive name (e.g. `redis-state-layer`, `user-content-cache`, `add-jenkins-pipeline`)
- Cross-repo work: create branches with the **same name** in every affected repo

### Step 3. Build task list

```
TaskCreate × N
  - subject: imperative ("Add X", "Refactor Y"); prefix "[TDD] " for test-worthy tasks
  - description: file paths + acceptance criteria + dependency notes
              ([TDD] tasks: inherit the issue's Acceptance criteria verbatim as the seed behavior list)
  - The final task MUST be "Verification team review"
```

**Decomposition principles**:
- 1 Task = 1 Commit = 1 file OR 1 logical change
- If a task touches 4+ files, split it
- Task IDs reflect **dependency order**, not creation order
- Always include the verification task as a separate item
- **Mark dependencies explicitly** so the head agent can identify parallelizable groups
- **Mark test-worthy tasks `[TDD]`** — tag a task `[TDD]` when an upstream source (`to-prd`'s *Testing Decisions*, or the issue's *Acceptance criteria*) designates its module for testing. If no upstream source exists, the head agent confirms the `[TDD]` set with the user **here, at Step 3** — never later, never inside a parallel executor.
- **Never split test-writing into its own task.** A `[TDD]` task carries its tests AND implementation together. Separating "write tests" from "write code" is horizontal slicing — explicitly forbidden by the `tdd` skill.
- **`[TDD]` task → N commits** (one per green cycle) — the sole exception to "1 Task = 1 Commit". Each green is exactly the "smallest logically separable unit" the commit rule already requires.

### Step 3.5. Dependency analysis & parallelization

Before the implementation loop, the head agent classifies tasks:

```
For each task, list its blockers (tasks whose output it reads or extends).
Tasks with no shared blockers and no shared files form a "parallel group".
```

Rules for parallel groups:
- Members must not touch **the same file**.
- Members must not depend on each other's output (no read-after-write between them).
- If unsure, treat as sequential. Conservative is correct.

Example layout:
```
T1 (sequential, scaffolds the module)
└── T2, T3, T4 (parallel group: independent feature files)
        └── T5 (sequential, integrates T2–T4)
            └── T6 (Verification team)
```

### Step 4. Implementation loop

**4a. Sequential task** — for each task:

```
1. TaskUpdate(in_progress)
2. Implement
   - Non-[TDD] task → spawn a Sonnet `executor` (it owns the Edit/Write).
       Brief it to Read/Grep dependent files first and follow existing patterns
       (no novel inventions). The main loop specs the task, then reviews + commits.
   - [TDD] task → drive implementation with the `tdd` skill, §2-4 ONLY
       (Tracer Bullet → Incremental Loop → Refactor). One test → one impl, repeat.
       SKIP tdd §1 Planning — the plan is INHERITED, not re-planned: the issue's
       Acceptance criteria are the seed behavior list; tdd §2-4 grows finer
       behaviors inside the loop. Commit once per green (see Step 3).
3. Skill(git-master) commit OR direct git add + git commit
   - Korean conventional commit (type(scope): message)
   - scope is required
   - ⛔ NEVER include a Claude fingerprint
4. TaskUpdate(completed)
```

**4b. Parallel group** — for each group of independent tasks:

```
1. TaskUpdate(in_progress) on every member task
2. Spawn N agents in a SINGLE message (parallel tool calls)
   - Non-[TDD] task → `executor` agent. Spec: task, files it owns,
     files it must not touch, shared conventions. It does NOT commit;
     the head commits in step 5.
   - [TDD] task → `tdd-executor` agent with isolation: "worktree".
     Spec: task + the inherited Acceptance criteria (seed behavior list).
     It runs Skill(tdd) itself, applies §2-4, and commits once per green
     INSIDE its own worktree — no index contention with siblings.
3. Wait for all agents to finish.
   - If a tdd-executor reports it could NOT reach green: do NOT merge its
     worktree, do NOT mark its task completed. Isolate that task, let the
     rest proceed, and escalate the failing test to the user. A red state
     is never committed or merged.
4. Head agent re-verification pass:
   - Read every file that was modified
   - Check: naming consistency across files, shared types/interfaces match,
     duplicate logic, conflicting assumptions, dangling imports, ABI/contract drift
   - If drift found: spawn an `executor` to fix it (small) OR add an inline [FIX] task (large) — never patch it inline from the main loop
5. Land the work:
   - Non-[TDD] tasks → head commits per task via git-master.
     If executors made interleaved edits, split into logical commits — do NOT lump.
   - [TDD] tasks → head merges each tdd-executor worktree back onto the UoW
     branch. Parallel-group rule guarantees no file overlap, so merges are
     conflict-free; the per-green commits ride along intact.
6. TaskUpdate(completed) on every member task that succeeded
```

The head re-verification step is non-negotiable for parallel groups. Parallel agents don't see each other's work; the head is the only place inconsistencies get caught before the verification team sees them.

**Commit rules**:
- Format: `type(scope): Korean body`
- First line = WHY, body = WHAT
- 1 commit = smallest logically separable unit
- Protect untracked files — stage only what is needed (`git add .` is forbidden)
- No local build commands (`./gradlew build`, `npm run build`, etc.) — user verifies manually

### Step 5. Verification team (after all tasks complete)

**Run 3 independent agents in parallel** (three tool calls in one message):

```
Agent(code-reviewer)      → code quality, bugs, security, conventions
Agent(architect-medium)   → design coherence, plan alignment, architectural health
WebSearch({query} 2026)   → industry best practices (current year MANDATORY)
```

**If the Unit of Work contains `[TDD]` tasks**, extend the `code-reviewer` brief with two checks: (1) tests verify observable behavior, not implementation details; (2) `git log` shows an incremental test↔impl cadence — not a bulk test-dump (horizontal slicing).

**Adjust depth by complexity**:
- Simple change: `code-reviewer-low` + WebSearch only
- Standard: the three above
- Complex/risky change: `code-reviewer` (Opus) + `architect` (Opus) + 2–3 WebSearches

### Step 6. Issue triage

Verification team output must be classified into one of three grades:

| Grade | Meaning | Action |
|---|---|---|
| ✅ **OK** | Pass | Continue |
| ⚠️ **WARN** | Recommended fix | Apply if feasible; record TODO if time-constrained and continue |
| 🛑 **BLOCK** | Blocker | Must fix and re-verify |

If any BLOCK exists → Step 7. Otherwise → Step 8.

### Step 7. Recursive fix loop

```
1. TaskCreate one [FIX] task per issue
   - subject prefix: "[FIX] " — also tag "[TDD]" if the fix targets a behavioral
     bug in a [TDD] module (write the failing regression test first, then fix).
     Non-behavioral fixes (typo, import, config, lint) stay plain.
   - description: root cause + scope + file:line
2. Implementation loop (repeat Step 4)
3. Lightweight re-verify (code-reviewer-low alone, skip WebSearch)
4. Recursion depth limits:
   - 1st round: normal
   - 2nd round: print a warning, continue
   - 3rd round: STOP. Report to user and hand over the decision.
```

### Step 7.5. History hygiene before PR (2026-09-28)

The Unit-of-Work branch is local until Step 8, so its history is still editable. Before pushing:

```
1. git log --format='%h %s' main..HEAD  → check every commit:
   - test-only commit typed `feat` → retype to `test`
   - bug fix with test + impl in one commit → split into `test` then `fix`
   - `fix` commit that edits a test → move the test edit to a preceding `test` commit with a reason
   - empty body on a fix commit → add the red evidence line
2. Rewrite with reset --soft / cherry-pick or rebase -x (never interactive), keeping order.
3. Verify: tree of the new tip == tree of the old tip (`git diff <old> <new>` empty), full test suite green.
4. Record the old tip in a backup ref until the PR is merged, then delete it.
```

Sub-agent branches land on the UoW branch with rebase + ff merge only (no merge commits, never to main). Check commit typing at that moment; anything missed is fixed here.

### Step 8. Create PR

```bash
git push -u origin {branch}
gh pr create --base main --head {branch} --title "type(scope): summary" --body "..."
```

**PR body template**:

```markdown
## Summary
{1–3 bullets, why + what}

### Changes
- Per-file / per-area summary

### Design principles
- Key decisions

## Test plan
- [x] Completed automated checks
- [ ] Items needing manual verification

## Follow-ups (optional)
{next-step pointers}
```

### Step 9. Merge + cleanup (on approval)

```bash
gh pr merge {N} --merge --delete-branch
# Deletes local and remote branches automatically
```

**Warning**: only merge **after explicit user approval**. Auto-merge is forbidden. Only run it when the user issues an explicit command like `/git-master merge`.

### Step 10. Refresh knowledge graph

```bash
git checkout main
git pull --ff-only
graphify update .
```

Aligns with the project-level CLAUDE.md rule: "After modifying code, run `graphify update .` to keep the graph current". AST-only, no API cost. A stale graph causes future analyses (god nodes, communities, isolated/island detection) to mislead — run this **every time** a Unit of Work merges, even for tiny PRs. If `graphify` reports "No code-graph topology changes detected", that is expected for pure-deletion / style-only PRs and counts as success.

---

## 5. Invariants (Never Violate)

1. **No Claude fingerprint** — anywhere: commits, PRs, docs
2. **No local build commands** (`./gradlew build`, `npm run build`, `pnpm build`, etc.) — user verifies
3. **No branch prefixes** — `feat/`, `fix/`, `chore/`, etc.
4. **Korean commit messages**, scope is required
5. **Protect untracked files** — explicit staging only, `git add .` is forbidden
6. **Destructive git commands require user confirmation** — `reset --hard`, `push --force`, `branch -D`, etc.
7. **Verification team runs in parallel** — sequential is forbidden (token waste + latency)
8. **Implementation parallel groups MUST be followed by head re-verification** — never trust merged parallel output blindly
9. **WebSearch queries MUST include the current year** — prevents stale-info regression
10. **No auto-merge** — only after explicit user approval
11. **3rd recursion round = escalate** — prevents infinite loops
12. **graphify update after every merge** — once a Unit of Work merges to main, run `graphify update .` (AST-only, no API cost). Skipping this leaves the knowledge graph stale and causes future island/community-based analyses to misjudge dead code or migration leftovers.
13. **`[TDD]` tasks are implemented test-first via the `tdd` skill** — red-green-refactor, §2-4 only, one test at a time, one commit per green. tdd §1 Planning is INHERITED from upstream (`to-prd` Testing Decisions / `to-issues` Acceptance criteria), never re-run inside Task Loop. Parallel `[TDD]` tasks run in `tdd-executor` agents under worktree isolation. Splitting test-writing into a separate task (horizontal slicing) is forbidden. A red (failing) state is never committed.

---

## 6. Recommended Practices

- Task ID order = dependency order
- 1 PR = 1 Unit of Work (no per-task PRs)
- When the same work spans multiple repos: **same branch name in each repo + an independent PR per repo**
- Trust verification team output **recursively**, but escalate past 2 rounds
- Every task → spawn an executor (Sonnet); the main loop orchestrates and never edits files directly
- Maximize parallel groups when possible, but err on the sequential side when in doubt
- Prefer defensive declarations (`@Immutable`, `updatable=false`, `final`, `readonly`, etc.)
- Commit messages: WHY first, WHAT later. Keep the first line ~50 chars.

---

## 7. Relationship with Other Skills

| Skill | Relationship |
|---|---|
| `git-master` | Called during Task Loop's **commit / branch / PR steps**. Rules align. |
| `tdd` | Task Loop **uses** it as the implementation discipline for `[TDD]` tasks in Step 4 — red-green-refactor (§2-4) only. Planning (§1) is inherited from upstream (`to-prd` / `to-issues`). SRP: Task Loop owns orchestration, `tdd` owns the test-first loop. |
| `tdd-executor` | The agent Task Loop spawns for **parallel** `[TDD]` tasks (Step 4b). Has the `Skill` tool, so it loads `tdd` itself inside a worktree-isolated context and commits per green. |
| `to-prd` / `to-issues` | Run **before** Task Loop. They produce the PRD and the per-issue Acceptance criteria that `[TDD]` tasks inherit as their seed behavior list. |
| `design-first` | Runs **before** Task Loop when complex design is needed. Task Loop owns the execution phase. |
| `simplify` / `audit` / `polish` | Can be invoked **inside Task Loop's verification phase** as additional review layers. |
| `find-skills` | Discovers auxiliary skills for specific problems encountered mid-loop. |

---

## 8. Checklist (one Unit of Work lifecycle)

```
▢ Confirm prior work's Done state
▢ Bring main up to date (git pull --ff-only)
▢ Create branch (no prefix, descriptive)
▢ Build TaskList (implementation + verification + potential fixes)
▢ Dependency analysis → identify parallel groups
▢ For each Task / group:
   ▢ Mark in_progress
   ▢ Implement
     - Sequential: spec task → spawn `executor` (Sonnet) → review
     - Parallel group: spawn N executors in one message
   ▢ (Parallel group only) Head re-verification across modified files
   ▢ git-master commit (Korean, scope required, no fingerprint)
   ▢ Mark completed
▢ Run verification team in parallel (code-reviewer + architect + WebSearch with current year)
▢ If issues exist:
   ▢ [FIX] TaskCreate
   ▢ Fix + commit
   ▢ Lightweight re-verify
   ▢ (Recurse, max 2 rounds)
▢ Create PR (gh pr create)
▢ Wait for user approval
▢ On approval: gh pr merge --merge --delete-branch
▢ Refresh knowledge graph (git checkout main && git pull && graphify update .)
▢ Write retrospective / summary
```
