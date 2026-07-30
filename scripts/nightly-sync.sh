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
HEALED=0
CAPTURED=1   # 기본 실패값 — 캡처 확인 전엔 apply 금지
for f in CLAUDE.md settings.json statusline-wrapper.sh skills agents hooks; do
  if [ ! -L "$HOME/.claude/$f" ] || [ "$(readlink "$HOME/.claude/$f")" != "$SRC/external_claude/$f" ]; then
    # 캡처 먼저 — 순서 역전 절대 금지 (아래 apply 주석 참조)
    rsync -aL --exclude 'memory/' --exclude '*.local.md' --exclude '*.local.json' \
          --exclude '*.log' --exclude '.DS_Store' "$HOME/.claude/$f" "$SRC/external_claude/" 2>/dev/null
    CAPTURED=$?   # rsync rc 즉시 포획 — 이 머신은 openrsync(protocol 29). dangling 심링크 소스·읽기전용 대상에서
                  # rc=23이며 아무것도 안 옮기거나 stale 내용을 그대로 둠. 아래 apply의 전제 조건으로 필수.
    if [ "$f" = "settings.json" ]; then
      # settings.json만 자가치유 — Claude Code가 영속 설정 저장(기본 모델 변경·/config·플러그인 설치) 시
      # temp+rename으로 심링크를 실파일로 갈아치움. 정상 동작이라 재발 확정 → 사람 호출 대신 자동 복구.
      # 나머지 6개(+nvim)는 깨질 이유가 없음 → 파손이면 진짜 이상. 전부 자동 치유하면 그 신호를 덮음 → BROKEN=1 유지.
      # 순서: 위 rsync 캡처 → 여기 apply. 역전 시 apply가 실파일을 지우고 stale 소스 심링크로 대체 → 당일 변경(예: 새 모델값) 소실.
      # 같은 이유로 CAPTURED -eq 0 이 apply의 전제 — 캡처 실패 상태에서 --force로 밀면 그 소실이 그대로 실현됨.
      # 경로 한정 필수 — 맨 chezmoi apply는 대기 중인 다른 타깃 변경까지 전부 적용해버림.
      # --force 필수 — chezmoi가 마지막에 쓴 상태와 실제 항목이 다르면(현 상태 MM) 덮어쓸지 프롬프트를 띄움.
      # TTY 없는 launchd에선 응답 불가 → 무한 대기/실패로 자가치유가 매일 죽음. 플래그는 이 호출에만(전역 force 금지).
      if [ "$CAPTURED" -eq 0 ] && chezmoi apply --force "$HOME/.claude/settings.json"; then
        HEALED=1
      elif [ "$CAPTURED" -ne 0 ]; then
        # 캡처 자체가 실패 → 내용 미확보. apply 보류해 실파일 원본 보존. BROKEN과 무관하게 항상 알림 — 동시 파손과도 독립적으로 울려야 함.
        notify "settings.json 캡처 실패 — 복구 보류(실파일 보존). 조사 우선"
      else
        # 캡처는 이미 성공 → 내용 안전, 심링크 복구만 실패. 알리되 백업은 계속 (exit 금지)
        notify "settings.json 심링크 복구 실패 — 내용은 캡처됨, 백업 계속"
      fi
    else
      BROKEN=1
    fi
  fi
done
if [ ! -L "$HOME/.config/nvim" ] || [ "$(readlink "$HOME/.config/nvim")" != "$SRC/external_nvim" ]; then
  BROKEN=1
  rsync -aL --exclude '.git' --exclude 'memory/' --exclude '*.local.md' --exclude '*.local.json' \
        --exclude '*.log' --exclude '.DS_Store' "$HOME/.config/nvim/" "$SRC/external_nvim/" 2>/dev/null
fi
[ "$BROKEN" -eq 1 ] && notify "심링크 파손 — fallback 캡처함. apply 승인 금지, 조사 우선"
[ "$HEALED" -eq 1 ] && notify "settings.json 심링크 자동 복구함"   # 정보성 — 알람 아님, 같은 런에서 위 파손 알림과 동시 발생 가능

# [3] 표면 감사 — [W12] ~/.claude 루트 신규 파일(백업 사각) 검출
if [ -f "$SRC/scripts/claude-surface.txt" ]; then
  # LC_ALL=C 고정 — launchd는 LANG을 안 넘김(plist EnvironmentVariables는 PATH뿐). C 정렬은 대문자 우선이라
  # CLAUDE.md 위치가 대화형 en_US.UTF-8 결과와 어긋나 매일 오탐. 스냅샷도 `LC_ALL=C ls -A ~/.claude`로 생성할 것.
  LC_ALL=C ls -A "$HOME/.claude" | diff -q "$SRC/scripts/claude-surface.txt" - >/dev/null 2>&1 \
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
