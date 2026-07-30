---
name: backup
description: |
  Inspect, run, or restore the chezmoi-managed backup of Claude Code config (백업, 백업 상태, 복원).
  Use /backup, /backup status, /backup now, /backup restore, /backup diff, /backup log.
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
2. **Push is always manual.** The automation commits **locally only**. A human
   reviews `git log -p origin/main..HEAD` and pushes. Never push on the user's
   behalf, and never describe the sync as "pushed".

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

미push 커밋이 있으면: `git -C "$(chezmoi source-path)" log -p origin/main..HEAD`로
diff를 직접 리뷰한 뒤 `git push`. 저장소가 공개이므로 리뷰 없이 push 금지.
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

**다음 단계 (사람이 직접):**
\`\`\`
git -C "$(chezmoi source-path)" log -p origin/main..HEAD   # diff 리뷰
git -C "$(chezmoi source-path)" push                        # 승인 후 push
\`\`\`
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

Show what would change, without changing anything.

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
