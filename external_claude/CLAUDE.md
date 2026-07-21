# User Rules

## Build Commands

**NEVER run `pnpm build`, `npm run build`, or any production build during dev.**

Not optional. User verify manually. Build commands:
- Waste time (builds slow)
- Pollute terminal
- Not your job — user decide when build

**ONLY use `pnpm dev` or type-check commands if explicitly asked.**

## Model Routing (Orchestrator Discipline)

**The main loop (Opus) is an ORCHESTRATOR / ARCHITECT only.** It plans, decomposes, delegates, reviews, and commits — it does NOT write implementation code itself.

- ⛔ **Main Opus loop: NEVER call `Edit` / `Write` / `MultiEdit` / `NotebookEdit` directly.** Every file-modifying change is delegated to a **Sonnet** subagent via the Task tool.
- ✅ **Implementation → Sonnet subagents.** Spawn `executor` (or `tdd-executor` for `[TDD]` tasks, `build-fixer` for build/type errors) for every code change, including "tiny" ones. Consistency over the marginal latency saved by inlining.
- ✅ **Haiku = one-shot lookup / single-pass only.** Use Haiku-tier agents (`architect-low`, `code-reviewer-low`, `security-reviewer-low`) for single-pass read/lookup/review. The `writer` agent (Haiku) is the one sanctioned Haiku editor, and ONLY for documentation. Never give a Haiku agent multi-step or code-mutating work.
- A PreToolUse hook (`block-main-impl.js`) enforces this by denying Edit/Write from the main session; if it is ever disabled, this directive still governs.
- The ONLY exception is a literal one-keystroke fix the user explicitly orders inline ("just fix it directly"); even then prefer delegation.

## Simple Fix Fast-Path (간단 수정은 main 직접)

**간단한 수정은 Branch Discipline의 예외로 worktree/브랜치/PR/검증 파이프라인을 생략하고 main에 직접 commit + push한다.**

이는 BRANCHING 정책의 변경이다 (누가 편집하는지가 아님). **Sonnet executor는 여전히 편집을 담당하며**, 다만 worktree 오버헤드 없이 main에 직접 배포된다.

**적용 대상:**
- 변경량: 약 1-2줄 이내
- 위험도: 명백하고 저위험
  - 오타 수정
  - 한 줄 버그 수정
  - 빌드/설정 스크립트 경미한 tweak
  - 주석·문서 소소한 수정
- 영향: 단일 파일, 명백한 의도

**제외 (반드시 worktree→브랜치→PR→검증 사용):**
- 다중 파일 변경 (3파일 이상)
- 로직·동작 변경
- 마이그레이션, 대규모 리팩토링
- 설계 결정 필요
- **판단 불명확 시 → 무조건 브랜치 사용 (보수적 원칙)**

**커밋 규칙 (동일 유지):**
- 편집은 Sonnet executor에 위임 (main loop는 Edit/Write 직접 금지)
- 한국어 Conventional Commits 형식: `type(scope): message`
- scope 필수 (생략 금지)
- AI/Claude fingerprint 절대 금지 (Co-Authored-By 등)

**배포 고지:**
- Main 직접 push는 CI/배포를 트리거할 수 있음
- 배포 영향이 있으면 **push 전에 사용자에게 고지** 필수

## Package Manager Rules

Check `packageManager` field in `package.json` for project's package manager, then use matching command:

| Package Manager | Run installed package | Run one-off package |
|-----------------|----------------------|---------------------|
| pnpm | `pnpm exec` | `pnpm dlx` |
| npm | `npx` | `npx` |
| yarn | `yarn` | `yarn dlx` |
| bun | `bun` | `bunx` |

## Custom Skills

Git/커밋 작업 시 `~/.claude/skills/git-master/` 규칙 **반드시** 따를 것.
Frontend 작업 시 `~/.claude/skills/my-frontend/` 가이드라인 참고할 것.
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) — any input to knowledge graph. Trigger: `/graphify`
User types `/graphify` → invoke Skill tool with `skill: "graphify"` before anything else.

## Work-style (promoted from a client project memory, 2026-06-08)

- **Verify before claiming:** "best practice" / "권장 방법" 단정 전 WebSearch + 공식 가이드 1회 이상 확인; 검증 못 했으면 "일반론, 도메인 idiom은 다를 수 있음" 명시.
- **Task-loop for big work:** Day 단위 큰 UoW는 `/task-loop` skill(Pre-flight → 새 브랜치 → TaskCreate×N → verification team 병렬 → BLOCK/WARN triage → merge); 작은 단일 변경은 직접 진행.
- **Parallel dispatch — dispatch all at once:** Agent/Task N개 보낼 때 4-5개씩 나눠 보내다 후반 누락 반복 발생 → 한 메시지에 전부 호출. 분할 불가피하면 "이번 N개 / 남은 M개" 명시 추적.
- **Caveman/terse 모드 — 도구 호출 구조는 압축 금지:** prose/텍스트 응답만 terse 적용; 도구 호출 XML, 코드, 커밋 메시지, PR 본문은 항상 완전한 형식 유지.
- **CSS 단위 무조건 rem:** 사용자가 px로 말해도 코드엔 rem 환산 (÷16, 예: 800px→50rem); vw/vh/% 는 그대로 유지.
- **Worktree 무조건:** 신규 브랜치 작업은 `git worktree add -b <branch> ../<repo>-<topic> main`; 메인 체크아웃에 직접 브랜치+편집 금지.