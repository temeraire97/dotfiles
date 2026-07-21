---
name: backup
description: |
  Claude Code 설정을 수동으로 백업하거나 상태를 확인합니다.
  /backup, /backup status, /backup now 등으로 사용하세요.
---

# Claude Code Backup Skill

## Overview

Claude Code 설정 파일들을 dotfiles 저장소에 백업하고 관리합니다.

**백업 대상:**
- `~/.claude/CLAUDE.md` - 전역 지침
- `~/.claude/settings.json` - 플러그인/설정
- `~/.claude/skills/` - 커스텀 스킬
- `~/.claude/plugins/installed_plugins.json` - 플러그인 목록

**백업 위치:** `~/dotfiles/claude/`

---

## Commands

사용자 입력에 따라 적절한 작업을 수행하세요.

### `/backup` 또는 `/backup status`

백업 상태를 확인합니다.

**수행 작업:**
```bash
# 1. 마지막 백업 시간 확인
cat ~/dotfiles/claude/.sync.log | tail -5

# 2. 현재 설정과 백업 비교
diff ~/.claude/CLAUDE.md ~/dotfiles/claude/CLAUDE.md
diff ~/.claude/settings.json ~/dotfiles/claude/settings.json

# 3. launchd 서비스 상태
launchctl list | grep claude-sync
```

**출력 형식:**
```markdown
## 📦 Backup Status

| 항목 | 상태 |
|------|------|
| 마지막 백업 | YYYY-MM-DD HH:MM |
| 자동 백업 | ✅ 활성화 (매일 19:00) |
| 변경사항 | 🟢 동기화됨 / 🟡 N개 파일 변경됨 |

### 최근 로그
\`\`\`
[로그 내용]
\`\`\`
```

---

### `/backup now`

즉시 백업을 실행합니다.

**수행 작업:**
```bash
~/dotfiles/claude/sync.sh
```

**출력 형식:**
```markdown
## ✅ Backup Complete

백업이 완료되었습니다.

| 항목 | 결과 |
|------|------|
| CLAUDE.md | ✅ 동기화됨 |
| settings.json | ✅ 동기화됨 |
| skills/ | ✅ 동기화됨 |
| Git commit | ✅ 커밋됨 |
```

---

### `/backup restore`

dotfiles에서 설정을 복원합니다. (주의: 현재 설정을 덮어씁니다)

**수행 작업:**
```bash
~/dotfiles/claude/install.sh
```

**출력 전 확인:**
```markdown
⚠️ 현재 설정을 dotfiles 백업으로 덮어씁니다.
진행하시겠습니까?
```

---

### `/backup diff`

현재 설정과 백업의 차이를 보여줍니다.

**수행 작업:**
```bash
diff ~/.claude/CLAUDE.md ~/dotfiles/claude/CLAUDE.md
diff ~/.claude/settings.json ~/dotfiles/claude/settings.json
```

---

### `/backup log`

백업 로그를 보여줍니다.

**수행 작업:**
```bash
cat ~/dotfiles/claude/.sync.log | tail -20
```

---

## Paths

| 용도 | 경로 |
|------|------|
| 백업 저장소 | `~/dotfiles/claude/` |
| 동기화 스크립트 | `~/dotfiles/claude/sync.sh` |
| 복원 스크립트 | `~/dotfiles/claude/install.sh` |
| 백업 로그 | `~/dotfiles/claude/.sync.log` |
| launchd plist | `~/Library/LaunchAgents/com.user.claude-sync.plist` |
