#!/bin/bash
set -uo pipefail
notify() { osascript -e "display notification \"$1\" with title \"chezmoi-sync\""; }

# [0] 동시 실행 lock — macOS flock 부재 → mkdir 원자성
LOCK="${TMPDIR:-/tmp}/chezmoi-sync.lock"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK"' EXIT

SRC="$(chezmoi source-path)" || { notify "chezmoi 없음 — 백업 중단"; exit 1; }
cd "$SRC" || exit 1

# 미push 현황 헬퍼 — 모델 b: push는 항상 사람 수동, 스크립트는 보고만
unpushed() {
  git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 || return 1   # 원격/upstream 미설정 시 보고 생략
  local n; n=$(git rev-list --count '@{u}..HEAD')
  [ "$n" -gt 0 ] || return 1
  local oldest age
  oldest=$(git log '@{u}..HEAD' --format=%ct | tail -1)
  age=$(( ($(date +%s) - oldest) / 86400 ))
  echo "미push ${n}개(최고 ${age}일)"
}

# [1] gitleaks smoke — [W11] 툴 부재/파손 조기 검출
command -v gitleaks >/dev/null || { notify "gitleaks 미설치 — 백업 중단"; exit 1; }

# [2] 심링크 무결성 assert + 파손 시 fallback 캡처 — [B5] claude 6개 + ★nvim 1개
BROKEN=0
for f in CLAUDE.md settings.json statusline-wrapper.sh skills agents hooks; do
  if [ ! -L "$HOME/.claude/$f" ] || [ "$(readlink "$HOME/.claude/$f")" != "$SRC/external_claude/$f" ]; then
    BROKEN=1
    rsync -aL --exclude 'memory/' --exclude '*.local.md' --exclude '*.local.json' \
          --exclude '*.log' --exclude '.DS_Store' "$HOME/.claude/$f" "$SRC/external_claude/" 2>/dev/null
  fi
done
if [ ! -L "$HOME/.config/nvim" ] || [ "$(readlink "$HOME/.config/nvim")" != "$SRC/external_nvim" ]; then
  BROKEN=1
  rsync -aL --exclude '.git' --exclude 'memory/' --exclude '*.local.md' --exclude '*.local.json' \
        --exclude '*.log' --exclude '.DS_Store' "$HOME/.config/nvim/" "$SRC/external_nvim/" 2>/dev/null
fi
[ "$BROKEN" -eq 1 ] && notify "심링크 파손 — fallback 캡처함. apply 승인 금지, 조사 우선"

# [3] 표면 감사 — [W12] ~/.claude 루트 신규 파일(백업 사각) 검출
if [ -f "$SRC/scripts/claude-surface.txt" ]; then
  ls -A "$HOME/.claude" | diff -q "$SRC/scripts/claude-surface.txt" - >/dev/null 2>&1 \
    || notify "~/.claude 신규 항목 감지 — 페이로드 승격 또는 ignore 등재 필요"
fi

# [4] 실파일 타깃(zshrc/zshenv) re-add — [W9] 실패 무알림 금지
chezmoi re-add || notify "re-add 실패 — zsh 백업 누락 가능, 로그 확인"

# [5] 변경 수집 (.gitignore가 memory/ 등 전 깊이 차단 — [B3])
git add -A

# [6] 기밀 staged 게이트 — [B3] gitignore 실패 대비 이중화
if git diff --cached --name-only | grep -qE '(^|/)memory/|\.local\.(md|json)$|(^|/)history\.jsonl$'; then
  notify "기밀 패턴 staged — 백업 중단"; exit 1
fi

# [7] 변경 없으면 미push 현황만 알림 후 종료 — ★모델 b: push 자동 재시도 없음([I5] 대체)
if git diff --cached --quiet; then
  R=$(unpushed) && notify "변경 없음 — $R. chezmoi cd 후 git log -p 리뷰·git push"
  exit 0
fi

# [8] gitleaks 명시 스캔 — rc 분기 ([W11]) + macOS 알림 UX
gitleaks protect --staged --no-banner --redact; rc=$?
if   [ "$rc" -eq 1 ]; then notify "시크릿 감지 — 백업 중단"; exit 1
elif [ "$rc" -ne 0 ]; then notify "gitleaks 오류 rc=$rc — 백업 중단"; exit 1; fi

# [9] 커밋 — rc 가시화 ([B6][W4]). 한국어 CC·scope·fingerprint 없음
git commit --no-gpg-sign -m "chore(dotfiles): auto-sync $(date '+%Y-%m-%d %H:%M')" \
  || { notify "커밋 실패 — pre-commit 차단. 백업 중단"; exit 1; }

# [10] 커밋 완료 + 미push 현황 알림 — ★push는 사람이 리뷰 후 수동 (모델 b의 회수→사전 게이트 격상)
R=$(unpushed) || R="미push 집계 불가(원격 미설정)"
notify "auto-sync 커밋됨 — $R. chezmoi cd 후 git log -p 리뷰·git push"
