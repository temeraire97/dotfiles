---
name: backup
description: |
  Inspect, run, or restore the chezmoi-managed backup of Claude Code config (백업, 백업 상태, 복원).
  Use /backup, /backup status, /backup now, /backup review, /backup push, /backup restore, /backup diff, /backup log.
---

# Claude Code Backup Skill

## Overview

Claude Code config is backed up by **chezmoi**. The backup repo *is* the chezmoi
source directory — resolve it with `chezmoi source-path`, never hardcode it.

**What is backed up** (payload lives in `<source>/external_claude/`):

- `~/.claude/CLAUDE.md` - global instructions
- `~/.claude/settings.json` - plugins/settings
- `~/.claude/statusline-wrapper.sh` - statusline
- `~/.claude/skills/` - custom skills
- `~/.claude/agents/` - subagent definitions
- `~/.claude/hooks/` - hook scripts

Each of those is a **symlink** from `~/.claude/` into `<source>/external_claude/`,
so an app writing through the symlink lands directly in the source working tree —
drift is structurally zero.

**Not backed up:** `~/.claude/settings.local.json` is deliberately excluded by
`.chezmoiignore` (machine-local overrides). Do not try to "fix" its absence.

**Two facts that govern every command below:**

1. The remote `git@github.com:temeraire97/dotfiles.git` is **PUBLIC**. Anything
   committed is one push away from being world-readable.
2. **Push is never automatic.** The automation commits **locally only**. Pushing
   happens through `/backup push` alone, and only after `/backup review` has run
   in the same conversation and the user answered its gate with an explicit yes.
   `/backup now` and `/backup status` never push, and never describe the sync as
   "pushed".

**Automation:** launchd job `com.user.chezmoi-sync` runs
`<source>/scripts/nightly-sync.sh` daily at **17:00**, logging to
`~/Library/Logs/chezmoi-sync.log`.

---

## Commands

Pick the matching action from the user's input.

### `/backup` or `/backup status`

Report backup health: pending changes, unpushed commits, automation state, log tail.

**Actions:**
```bash
# [1] Pending target-state changes (source -> home)
chezmoi status

# [2] Working tree + ahead/behind vs origin (the unpushed count)
git -C "$(chezmoi source-path)" status -sb

# [3] Recent local commits
git -C "$(chezmoi source-path)" log --oneline -5

# [4] launchd job registration
launchctl list | grep chezmoi-sync

# [5] Tail of the nightly log
tail -20 ~/Library/Logs/chezmoi-sync.log
```

Read the `##` line from step [2]: `[ahead N]` is the unpushed count. Report it —
do not act on it.

**Output format:**
```markdown
## 📦 Backup Status

| 항목 | 상태 |
|------|------|
| 소스 저장소 | `~/.local/share/chezmoi` (원격 **PUBLIC**) |
| 마지막 커밋 | YYYY-MM-DD HH:MM — [커밋 제목] |
| 미push 커밋 | 🟢 없음 / 🟡 N개 — push는 사람이 수동 |
| 대기 변경 | 🟢 없음 / 🟡 N개 항목 |
| 자동 백업 | ✅ 등록됨 (매일 17:00) / ❌ 미등록 |

### 최근 로그
\`\`\`
[로그 tail]
\`\`\`

미push 커밋이 있으면 `/backup review`로 리뷰 후 `/backup push`.
저장소가 공개이므로 리뷰 없이 push 금지.
```

---

### `/backup now`

Run the nightly sync immediately. It commits locally only — it does **not** push.

**Actions:**
```bash
# [1] Same script launchd runs at 17:00 — local commit only
bash "$(chezmoi source-path)/scripts/nightly-sync.sh"
```

The script is fail-closed: it aborts on a missing/failing gitleaks, on staged
secret patterns, or on a pre-commit rejection. If it aborts, report the reason
verbatim instead of retrying.

**Output format:**
```markdown
## ✅ Backup Complete

로컬 커밋까지 완료했습니다. (push 안 함 — 사람이 리뷰 후 수동)

| 항목 | 결과 |
|------|------|
| 심링크 무결성 | ✅ 정상 / ⚠️ 파손 감지 |
| 표면 감사 | ✅ 변동 없음 / ⚠️ 신규 항목 |
| gitleaks 스캔 | ✅ 통과 |
| Git commit | ✅ 커밋됨 / ⏭️ 변경 없음 |
| 미push 커밋 | N개 |

**다음 단계:** `/backup review` → `/backup push`
```

---

### `/backup review`

Review the **unpushed range** (`origin/main..HEAD`) before it becomes public.
Read-only. This is the mandatory gate in front of `/backup push`.

Not the same as `/backup diff`: that one compares live home vs. source and shows
uncommitted edits. This one inspects commits that are already made but not yet
on the public remote.

**Actions:**
```bash
SRC="$(chezmoi source-path)"

# [1] Refresh the remote ref so the range is accurate
git -C "$SRC" fetch origin --quiet

# [2] What is unpushed
git -C "$SRC" log --format='%h %ci %s' origin/main..HEAD
git -C "$SRC" diff --stat origin/main..HEAD

# [3] Secret scan over exactly that range (fail-closed: missing gitleaks = FAIL)
gitleaks git --log-opts="origin/main..HEAD" --no-banner --redact "$SRC"

# [4] Added lines only: token shapes + personal absolute paths.
#     `command grep` on purpose: the Claude Code shell aliases grep to ugrep,
#     which silently drops matches for the alternation+{8,} group below.
git -C "$SRC" diff origin/main..HEAD | command grep -E '^\+' | command grep -v '^+++' \
  | command grep -inE 'sk-[a-z0-9_-]{10,}|ghp_[A-Za-z0-9]{20,}|xox[bp]-|AKIA[0-9A-Z]{12}|eyJ[A-Za-z0-9_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_./+=-]{8,}["'"'"']|/Users/[a-z0-9_-]+' \
  || echo "(no pattern hits)"

# [5] Hand-review the files that carry real risk. Print each in full.
#     Everything under external_claude/skills/<third-party>/ that is a pure
#     upstream version bump can be summarised by version delta instead.
git -C "$SRC" diff origin/main..HEAD -- \
  dot_zshrc external_claude/settings.json external_claude/CLAUDE.md \
  external_claude/hooks external_claude/agents \
  external_claude/statusline-wrapper.sh
git -C "$SRC" diff origin/main..HEAD --diff-filter=A --name-only   # new files
```

**Verdict rules:**
- **BLOCK** if gitleaks is missing, exits non-zero, or reports a leak; or if step
  [4] shows a credential-shaped hit. Report the exact line (redacted). Do not
  proceed to push. Fixing history is the user's job — offer the amend/rebase
  plan, do not run it unasked.
- **WARN** for `/Users/<name>` paths, new symlinks that point outside the repo
  (they dangle on a fresh machine and their content is not backed up), and
  new hook scripts. Name each with file and line. These do not block push.
- **PASS** otherwise.

**Output format:**
```markdown
## 🔍 Backup Review — origin/main..HEAD

| 항목 | 결과 |
|------|------|
| 미push 커밋 | N개 (YYYY-MM-DD ~ YYYY-MM-DD) |
| 변경 파일 | N개 (+A / -D) |
| gitleaks | ✅ no leaks / ❌ N leaks / ❌ 미설치 |
| 패턴 grep | ✅ 0건 / ⚠️ N건 (경로) / ❌ N건 (자격증명 의심) |
| 판정 | ✅ PASS / ⚠️ WARN / ❌ BLOCK |

### 변경 요약
- [파일 그룹별 한 줄: 무엇이 왜 바뀌었는지]

### 주의 (WARN 항목)
- [파일:행 — 내용 — 차단 사유 아님]

판정이 PASS/WARN이면 `/backup push`로 진행 가능. BLOCK이면 push 금지.
```

---

### `/backup push`

Push local commits to the **PUBLIC** remote. Irreversible in practice: once
pushed, content is world-readable and may be cached or forked even if
force-removed later.

**Preconditions — all three, no exceptions:**
1. `/backup review` ran **in this conversation**, on the same HEAD, and its
   verdict was PASS or WARN. If it has not run, run it now and show the result
   before the gate. If HEAD moved since the review (a `/backup now` or nightly
   commit landed), re-run review.
2. The verdict was not BLOCK.
3. The user answers the gate below with an explicit yes. Silence, "ok?", or a
   request to "just push" made *before* the review was shown do not count.

**Gate — ask, then wait:**
```markdown
⚠️ 공개 저장소(`temeraire97/dotfiles`)로 push합니다. 되돌릴 수 없습니다.

| 항목 | 값 |
|------|-----|
| 대상 | origin/main ← local main |
| 커밋 | N개 (`abc1234` ~ `def5678`) |
| 리뷰 판정 | ✅ PASS / ⚠️ WARN (N건: [요약]) |

push 하시겠습니까? (yes/no)
```

**Actions (only after yes):**
```bash
SRC="$(chezmoi source-path)"

# [1] Guard: HEAD must still be what was reviewed
git -C "$SRC" rev-parse HEAD

# [2] Guard: never force, never push a non-main branch by accident
git -C "$SRC" branch --show-current          # must print: main

# [3] Push
git -C "$SRC" push origin main

# [4] Confirm
git -C "$SRC" status -sb                     # expect: ## main...origin/main (no [ahead])
```

Never use `--force`, `--force-with-lease`, or `-u` to a different remote. If the
push is rejected (non-fast-forward), stop and report — someone else pushed to
the public repo, and merging that is a human decision.

**Output format:**
```markdown
## 🚀 Backup Pushed

| 항목 | 결과 |
|------|------|
| push | ✅ origin/main ← N개 커밋 (`abc1234`..`def5678`) |
| 상태 | `## main...origin/main` — 동기화됨 |
```

---

### `/backup restore`

Overwrite a live config file with the source's target state. **Destructive.**

**A path argument is mandatory.** Always name the exact target:

```bash
# [1] REQUIRED: one explicit target path
chezmoi apply ~/.claude/settings.json

# [2] Verify — the target should now be a symlink into external_claude/
ls -l ~/.claude/settings.json
```

Why the path is not optional: a bare `chezmoi apply` applies **every** pending
target-state change at once, across the whole home directory — zsh files, nvim,
`~/.local/bin`, anything else that happens to be out of sync. Unrelated live
config gets overwritten in the same breath as the file the user actually asked
about, with no undo. Scope the apply to the single path, every time.

**Ask before running — do not skip this gate:**
```markdown
⚠️ 복원은 파괴적 작업입니다. 현재 로컬 설정을 소스의 타깃 상태로 덮어씁니다.

| 항목 | 값 |
|------|-----|
| 대상 | `~/.claude/settings.json` |
| 동작 | 로컬 파일 → 소스 타깃 상태로 덮어쓰기 |
| 되돌리기 | 불가 (로컬 변경분 소실) |

진행하시겠습니까? (yes/no)
```

If `chezmoi apply` proposes a **content** diff for anything under `~/.claude/`,
that is a broken-symlink signal, not a normal restore. Decline, and investigate
the symlink first (see Symlink Integrity below).

**New-machine restore is a different job.** There is no install script here.
Follow the "새 머신 복원" section of the repo `README.md` — `brew install chezmoi`
then `chezmoi init --apply <remote>`, which runs the `.chezmoiscripts/` bootstrap.

---

### `/backup diff`

Show what would change, without changing anything. For committed-but-unpushed
history use `/backup review` instead.

**Actions:**
```bash
# [1] Live home vs. source target state
chezmoi diff

# [2] Uncommitted changes inside the source repo itself
git -C "$(chezmoi source-path)" diff
```

---

### `/backup log`

Show the automation log.

**Actions:**
```bash
# [1] Nightly sync output (launchd stdout+stderr)
tail -40 ~/Library/Logs/chezmoi-sync.log
```

---

## Symlink Integrity

`nightly-sync.sh` asserts that each `~/.claude/` entry is still a symlink pointing
into `<source>/external_claude/`.

- **`settings.json` is self-healing.** The Claude CLI sometimes replaces the
  symlink with a regular file. The script captures the file's content into the
  source first, then re-applies the symlink — so no settings are lost in the
  repair.
- **Every other broken symlink is an alarm, not a repair job.** The script only
  captures a fallback copy and notifies. A human must investigate the cause
  before anything is applied. Do not auto-fix it, and do not approve a
  `chezmoi apply` that would paper over it.

---

## Paths

| Purpose | Path |
|------|------|
| Backup repo (source) | `$(chezmoi source-path)` → `~/.local/share/chezmoi` |
| Claude payload | `<source>/external_claude/` |
| Sync script | `<source>/scripts/nightly-sync.sh` |
| Backup log | `~/Library/Logs/chezmoi-sync.log` |
| launchd plist | `~/Library/LaunchAgents/com.user.chezmoi-sync.plist` |
| Remote (PUBLIC) | `git@github.com:temeraire97/dotfiles.git` |
| New-machine restore guide | `<source>/README.md` |
