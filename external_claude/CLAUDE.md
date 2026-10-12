# User Rules

## Build Commands

**NEVER run `pnpm build`, `npm run build`, or any production build during dev.** Not optional. User verifies manually. Builds are slow, pollute the terminal, and the user decides when to build.

**ONLY use `pnpm dev` or type-check commands if explicitly asked.**

## Model Routing

- **Delegate heavy implementation to Sonnet subagents.** New code and behavior changes ALWAYS go to `tdd-executor` (test first, confirm red, green, commit), with or without a `[TDD]` tag. Plain `executor` only for work with nothing to test: config, docs, file moves and renames, comment cleanup, running scripts, build config tweaks. `build-fixer` for build/type errors. Small, well-scoped edits can be made directly.
- **Review never replaces TDD.** security-reviewer and code-reviewer run on top of TDD. Implementing without tests and covering with review is forbidden.
- **Haiku = one-shot lookup / single-pass only.** Haiku agents (`architect-low`, `code-reviewer-low`, `security-reviewer-low`) for single-pass read/lookup/review. `writer` (Haiku) is the only sanctioned Haiku editor, docs only. Never give Haiku multi-step or code-mutating work.

## Git (canonical: git-master skill)

`~/.claude/skills/git-master/` is canonical for commits, branches, PRs, merge, push: Simple Fix Fast-Path, Branch Discipline, Conventional Commits, no AI fingerprints ever, deploy-trigger checks, CodeCommit workflow (codecommit.md). ALWAYS follow it for git work.

## Package Manager

Check `packageManager` in `package.json`, then use the matching command:

| Package Manager | Run installed package | Run one-off package |
|-----------------|----------------------|---------------------|
| pnpm | `pnpm exec` | `pnpm dlx` |
| npm | `npx` | `npx` |
| yarn | `yarn` | `yarn dlx` |
| bun | `bun` | `bunx` |

## Skills

- Frontend work: follow `~/.claude/skills/my-frontend/`.
- **graphify** (`~/.claude/skills/graphify/SKILL.md`): any input to knowledge graph. When the user types `/graphify`, invoke Skill with `skill: "graphify"` before anything else.

## Work Style

- **Verify before claiming:** before asserting "best practice" or "recommended", check WebSearch plus an official guide at least once. If unverified, say it is a general rule and domain idioms may differ.
- **Task-loop for big work:** day-sized units use the `/task-loop` skill (pre-flight, new branch, TaskCreate xN, parallel verification team, BLOCK/WARN triage, merge). Small single changes go direct.
- **Parallel dispatch, all at once:** send all N Agent/Task calls in one message. Splitting into batches of 4-5 has repeatedly dropped later ones. If splitting is unavoidable, track "this batch N / remaining M" explicitly.
- **Terse mode never compresses tool-call structure:** terse applies to prose only. Tool calls, code, commit messages, and PR bodies stay complete.
- **CSS units always rem:** convert px to rem in code even when the user says px (divide by 16, e.g. 800px is 50rem). Keep vw/vh/% as is.
- **Always use a worktree:** new branch work uses `git worktree add -b <branch> ../<repo>-<topic> main`. Never branch and edit in the main checkout.
- **Verify before claiming done (2026-10-08):** before saying done, fixed, or passing, run a fresh command that proves it, read the exit code and full output, and report with evidence. No "should work" or "probably passes". Unverified claims are remaining work. Subagent reports meet the same bar, and numbers come from actual output.

## Shared Rules

@~/.local/share/chezmoi/external_claude/shared-rules/structure.md
