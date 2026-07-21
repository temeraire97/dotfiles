# chezmoi 첫 백업 명세서 v2 (현재 머신 설정 · 모델 b 동기화)

작성일: 2026-07-21 · 대상 머신: macOS arm64 (Darwin 25.4.0), 사용자 `hyunsoo`, brew=/opt/homebrew
전판: v1 "chezmoi 이관 최종 명세서" (safety-first · 공격검증 반영판). 본 v2는 사용자 승인 결정 4건을 반영한 전면 개정판이며, v1에서 실증된 게이트·수치·명령은 모델 변경에 따른 필연 수정 외 그대로 승계한다.

---

## 1. 요약

**프레이밍 전환**: 이 작업은 "구 머신/구 repo에서의 이관"이 아니라 **이 머신 현재 설정의 첫 chezmoi 백업**이다. 구 repo 2개(claude-setting, nvim-settings)는 마이그레이션 소스가 아니다 — 현재 홈의 라이브 파일이 유일한 소스이며, 구 repo들은 soak 기간(1주) 동안의 **공짜 롤백 수단**일 뿐이다. 이에 따라 런북은 15스텝 → **8스텝**으로 축소된다.

**확정 결정 4건** (사용자 승인 완료):

1. **리프레임** — 라이브 홈에서 `rsync -aL`(=cp -RL+exclude) 1회 캡처. 구 repo 미커밋 정리·bundle 3종 의식·아카이브 의식 삭제. 사전 백업은 홈 스냅샷 1개로 축소.
2. **nvim 흡수** — nvim-settings를 별도 repo로 유지하지 않고 소스 repo `external_nvim/` 페이로드 + `dot_config/symlink_nvim.tmpl`(타깃: `{{ .chezmoi.sourceDir }}/external_nvim`)로 흡수. claude와 동일한 externally-modified symlink 패턴(`lazy-lock.json` = 앱-재작성 파일 → write-through).
3. **동기화 모델 b** — 야간 launchd는 **로컬 커밋까지만**. push는 사람이 diff 리뷰(`git log -p`) 후 수동. `autoCommit/autoPush=false` 유지(chezmoi 순정), 야간 잡이 `git add`/`commit`만 자동. 산문 기밀(gitleaks가 못 잡는 비-시크릿 기밀)의 원격 노출이 **구조적으로 소멸** — push 전 사람 diff 리뷰가 완전한 사전 게이트.
4. **launchd 17:00** — StartCalendarInterval Hour=17 (launchd는 로컬 타임존).

부수 확정: `keybindings.json`은 생기면 표면 감사([W12])로 처리(기본안). 기밀 방어 다층 구조(ignore + gitignore + pre-commit 3게이트 + gitleaks 2중 + 공개 전 전 히스토리 스캔)와 externally-modified symlink 패턴, 롤백 forget-선행 원칙은 v1 그대로 유지된다(4장 승계표).

---

## 2. 최종 아키텍처

### 2.1 소스 트리 전체

```
~/.local/share/chezmoi/                       # git repo. 원격: github.com/temeraire97/dotfiles
│                                             #   (S7 전까지 원격 없음. private 생성→검증→public 전환)
├── .chezmoi.toml.tmpl                        # init 시 ~/.config/chezmoi/chezmoi.toml 생성
├── .chezmoiignore                            # 2.2 전문
├── .gitignore                                # 2.3 전문 — git 레이어 2차 방어 + nvim 산출물 패턴 병합
├── README.md                                 # 한국어 README (홈 배포 제외)
├── Brewfile                                  # brew bundle dump 라이브 캡처 (chezmoi 포함)
├── githooks/
│   └── pre-commit                            # 2.5 참조. core.hooksPath로 활성화(클론마다 run_once_30이 복원)
├── scripts/
│   ├── nightly-sync.sh                       # 2.5 참조. launchd 17:00 실행체. 모델 b: 커밋까지만, push 없음
│   └── claude-surface.txt                    # ~/.claude 루트 표면 baseline (S5에서 생성·커밋)
├── external_claude/                          # ★ 라이브 페이로드. external_ prefix = 속성 파싱 면역 [I4]
│   │                                         #   타깃명 "claude" → .chezmoiignore로 홈 배포 차단
│   ├── CLAUDE.md
│   ├── settings.json                         # claude CLI 재작성 → 심링크 관통으로 소스 working tree 즉시 반영
│   ├── statusline-wrapper.sh                 # 이미 포터블(동적 탐색) — 무수정
│   ├── skills/                               # 실디렉터리만 (파손 심링크는 S2에서 라이브 정리)
│   ├── agents/
│   └── hooks/                                # run-node.sh + package.json({"type":"commonjs"} 필수 유지)
├── external_nvim/                            # ★ 신규 — nvim 페이로드. 타깃명 "nvim" → ignore 차단 (claude와 동일 메커니즘)
│   ├── init.lua
│   ├── lua/
│   ├── lazyvim.json
│   ├── lazy-lock.json                        # 앱(lazy.nvim) 재작성 → write-through로 야간 커밋에 자동 포함
│   ├── stylua.toml
│   └── .neoconf.json                         # (.git · install.sh · README · LICENSE 미이식)
├── dot_zshrc                                 # 실파일 관리 (하드코딩 0건 실측 — 템플릿 불요)
├── dot_zshenv
├── private_dot_claude/                       # ~/.claude (private_=700 보존, exact_ 의도적 미사용)
│   ├── symlink_CLAUDE.md.tmpl                # 내용: {{ .chezmoi.sourceDir }}/external_claude/CLAUDE.md
│   ├── symlink_settings.json.tmpl
│   ├── symlink_statusline-wrapper.sh.tmpl
│   ├── symlink_skills.tmpl
│   ├── symlink_agents.tmpl
│   └── symlink_hooks.tmpl
├── dot_config/
│   └── symlink_nvim.tmpl                     # ★ 재타깃: {{ .chezmoi.sourceDir }}/external_nvim
├── dot_local/
│   └── bin/
│       └── symlink_node.tmpl                 # → {{ .chezmoi.homeDir }}/.local/share/fnm/aliases/default/bin/node
├── private_Library/                          # ~/Library는 macOS 기본 700 — private_ 접두사로 모드 보존, 미지정 시 apply가 755 강제
│   └── private_LaunchAgents/
│       └── com.user.chezmoi-sync.plist.tmpl  # 17:00. ⚠ S8에서 작성·커밋 (공개 전 무인 커밋 차단 순서 유지 [B1])
└── .chezmoiscripts/
    ├── run_onchange_before_10-brew-bundle-darwin.sh.tmpl
    ├── run_once_after_20-fnm-node-lts.sh.tmpl
    ├── run_once_after_25-nvim-lazy-restore.sh.tmpl       # ★ clone → headless Lazy restore(lockfile 준수)로 교체
    ├── run_once_after_30-set-git-hooks-path.sh.tmpl
    ├── run_onchange_after_40-reload-chezmoi-sync-agent.sh.tmpl   # ⚠ S8에서 작성·커밋
    └── run_once_after_50-claude-plugins-restore.sh.tmpl
```

구 repo 2개의 지위: **롤백 수단 (soak 1주 한정)** — 소스도 앵커도 아니다. soak 통과 후 처분 자유(9장). 영구 앵커는 S2의 홈 스냅샷 1개.

### 2.2 .chezmoiignore 전문

타깃 경로 기준 매칭. `!` 부활은 exclude-우선 규칙으로 신뢰 불가 → 명시 열거(KISS). v1의 "P1 임시 안전벨트 2줄"은 폐지 — 런북이 연속 실행 8스텝으로 압축되어 무기한 중간 상태가 존재하지 않고, 심링크 tmpl 작성 전에는 chezmoi가 `.claude`에 배포할 항목 자체가 없다.

```gitignore
# ===== [1] 소스 헬퍼 — 홈 배포 대상 아님 =====
README.md
Brewfile
claude                # external_claude/의 타깃명. 심링크 착지점일 뿐 — ~/claude 생성 금지
claude/**             # 페이로드 내용을 타깃 상태에서 제외 (externally-modified 패턴의 핵심)
nvim                  # ★ external_nvim/의 타깃명 — ~/nvim 생성 금지 (claude와 동일 메커니즘)
nvim/**
scripts
scripts/**
githooks
githooks/**

# ===== [2] 기밀·런타임 — chezmoi add/re-add/status 가시권에서 구조적 제거 =====
projects/**                      # ~/projects = 클라이언트 저장소. add 실수 원천 차단
.claude.json                     # [W7] 클라이언트 경로·exampleFiles 포함 48KB
.claude.json.backup*
.claude/projects/**              # 클라이언트 기밀 대화/메모리 — 절대 금지
.claude/sessions/**
.claude/history.jsonl
.claude/**/memory/**
.claude/**/*.local.md
.claude/**/*.local.json
.claude/mcp.json
.claude/plugins/**
.claude/cache/**
.claude/chrome/**
.claude/downloads/**
.claude/file-history/**
.claude/session-env/**
.claude/shell-snapshots/**
.claude/backups/**
.claude/tasks/**
.claude/teams/**
.claude/context-mode/**
.claude/.caveman-active
.claude/.last-cleanup
.claude/mcp-needs-auth-cache.json
.claude/*.backup.*
.claude/*.log
.config/nvim/**/*                # ★ 심링크 내용은 external_nvim 페이로드 소관 — 타깃 상태 밖. `**`는 0세그먼트도
                                 #   매치해 `/**`가 본체까지 ignore(실증) → `/**/*`로 콘텐츠만 차단 (심링크 자체는 관리)
.zshrc.local                     # [W9] 시크릿 격리 관례 파일 — 의도적 미백업
.zshenv.local

# ===== [3] 일반 오염 방지 =====
**/.DS_Store
**/*.log
.env
.env.*
**/*credentials*
**/*.secret
```

미래 신규 런타임 파일(열거 밖)은 `nightly-sync.sh`의 표면 감사([W12])가 잡는다. `keybindings.json`도 생기면 이 경로로 처리(기본안 확정).

### 2.3 소스 repo .gitignore 전문 (git 레이어 2차 방어 — 야간 `git add -A` 필터)

```gitignore
# 심링크 페이로드 표면 방어 — 세션이 skills/ 하위에 새로 만드는 기밀 차단
# [B3] */memory/는 1단계 깊이만 매치 → 전 깊이 패턴으로 교정 (주석은 별도 행 — 트레일링 주석은 패턴 일부가 됨)
memory/
*.local.md
*.local.json
.env
.env.*
*credentials*
*.secret
mcp.json
*.log
.DS_Store
*.backup.*

# ★ external_nvim 런타임·테스트 산출물 — 구 nvim-settings .gitignore 병합
#   (경로 한정 스코프: 무슬래시 패턴의 전 리포 오발 차단 + doc/tags의 앵커링 보존)
external_nvim/tt.*
external_nvim/.tests
external_nvim/doc/tags
external_nvim/debug
external_nvim/.repro
external_nvim/foo.*
external_nvim/data

# 기밀 미러 [W10] — chezmoi ignore 의미론 변동/수동 add 실수 대비
**/history.jsonl
**/sessions/
private_dot_claude/projects/
private_dot_claude/plugins/
dot_claude/
.claude.json
```

### 2.4 .chezmoiexternal.toml

**파일 자체를 만들지 않는다 (없음).** v1의 유일 후보였던 nvim-settings(git-repo external)가 흡수 결정으로 소멸 — 후보 0건. KISS.

### 2.5 스크립트별 전문

**`.chezmoi.toml.tmpl`** (v1 동일 — autoCommit/autoPush=false는 모델 b의 전제)
```toml
[add]
    secrets = "error"   # v2.71.1 실측 미발동([W6]) — 방어 산정 제외, 선언은 0비용이라 유지
[git]
    autoAdd = false
    autoCommit = false
    autoPush = false
```

**`.chezmoiscripts/run_onchange_before_10-brew-bundle-darwin.sh.tmpl`** (v1 동일)
```bash
{{ if eq .chezmoi.os "darwin" -}}
#!/bin/bash
set -euo pipefail
# Brewfile hash: {{ include "Brewfile" | sha256sum }}   # 해시 주석 = onchange 트리거
brew bundle --file="{{ .chezmoi.sourceDir }}/Brewfile"
[ "$(command -v pnpm)" = "/opt/homebrew/bin/pnpm" ] || echo "WARN: pnpm이 brew 설치본이 아님 — corepack shim 의심" >&2
{{ end -}}
```

**`.chezmoiscripts/run_once_after_20-fnm-node-lts.sh.tmpl`** (v1 동일)
```bash
{{ if eq .chezmoi.os "darwin" -}}
#!/bin/bash
set -euo pipefail
command -v fnm >/dev/null || exit 0
corepack disable 2>/dev/null || true      # pnpm=brew 정책을 검사가 아닌 강제로
fnm ls | grep -q default && exit 0        # 기존 머신 무간섭: default 별칭 존재 시 무조건 no-op
fnm install --lts
fnm default lts-latest
"$HOME/.local/bin/node" -v                # symlink_node가 dangling이 아님을 확인
{{ end -}}
```

**`.chezmoiscripts/run_once_after_25-nvim-lazy-restore.sh.tmpl`** ★ 교체 — clone → headless 플러그인 사전 설치 (구 nvim install.sh의 사전 설치 역할 계승, 실패는 warn만)
```bash
#!/bin/bash
set -uo pipefail
command -v nvim >/dev/null || exit 0
# restore = lazy-lock.json 준수 설치. sync는 install+update+clean으로 lockfile을 "재작성"해
#   방금 캡처·커밋한 lock을 S5 apply 직후 즉시 갱신 — lockfile 기준 재현이 목적이므로 restore가 정확
nvim --headless "+Lazy! restore" +qa || echo "WARN: Lazy restore 실패 — 이후 nvim에서 수동 :Lazy restore" >&2
```

**`.chezmoiscripts/run_once_after_30-set-git-hooks-path.sh.tmpl`** (v1 동일)
```bash
#!/bin/bash
git -C "{{ .chezmoi.sourceDir }}" config core.hooksPath githooks
```

**`.chezmoiscripts/run_onchange_after_40-reload-chezmoi-sync-agent.sh.tmpl`** (v1 동일 — ⚠ S8에서 커밋)
```bash
{{ if eq .chezmoi.os "darwin" -}}
#!/bin/bash
# plist hash: {{ include "private_Library/private_LaunchAgents/com.user.chezmoi-sync.plist.tmpl" | sha256sum }}
# sourceDir: {{ .chezmoi.sourceDir }}   # [B2] sourceDir 이동 시 렌더 결과가 변해 자동 재발화
LABEL="com.user.chezmoi-sync"; PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"; DOMAIN="gui/$(id -u)"
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
{{ end -}}
```
self-bootout 함정 없음: 이 스크립트는 대화형 apply에서만 돌고 야간 잡은 apply를 하지 않는다.

**`.chezmoiscripts/run_once_after_50-claude-plugins-restore.sh.tmpl`** (v1 동일 — 새 머신 전용)
```bash
#!/bin/bash
set -uo pipefail
command -v claude >/dev/null || exit 0
S="{{ .chezmoi.sourceDir }}/external_claude/settings.json"
jq -r '.extraKnownMarketplaces // {} | to_entries[] | .value.source.repo' "$S" | while read -r r; do claude plugins marketplace add "$r" || true; done
jq -r '.enabledPlugins // {} | to_entries[] | select(.value==true) | .key' "$S" | while read -r p; do claude plugins install "$p" || true; done
```

**`githooks/pre-commit`** (v1 동일 — 3게이트 전부 유지: 커밋은 여전히 자동이므로)
```bash
#!/bin/bash
# 게이트 1: gitleaks — rc 분기 ([W11] 툴 오류를 시크릿으로 오진 금지, fail-closed 유지)
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks protect --staged --no-banner --redact; rc=$?
  if   [ "$rc" -eq 1 ]; then echo "BLOCK: 시크릿 감지"; exit 1
  elif [ "$rc" -ne 0 ]; then echo "BLOCK: gitleaks 오류 rc=$rc — 스캔 불가(설정/버전 확인)"; exit 1; fi
else
  echo "BLOCK: gitleaks 미설치 — public repo 커밋 불가 (brew install gitleaks)"; exit 1
fi
# 게이트 2: /Users/ 하드코딩 가드 — [B6] chezmoi 구조 파일 한정(페이로드 제외: 백업 인질화 방지)
if [ "${ALLOW_USERS_PATH:-0}" != "1" ]; then
  if git diff --cached -- '*.tmpl' '.chezmoiscripts' 'scripts' 'githooks' 'private_Library' | grep -qE '^\+.*/Users/[a-z]+'; then
    echo "BLOCK: 구조 파일에 홈 절대경로 — {{ .chezmoi.homeDir }} 템플릿 사용 (의도적 예외: ALLOW_USERS_PATH=1)"; exit 1
  fi
fi
# 게이트 3: 기밀 경로 패턴 — [B3] .gitignore 우회(강제 add 등) 대비 이중화
if git diff --cached --name-only | grep -qE '(^|/)memory/|\.local\.(md|json)$|(^|/)history\.jsonl$'; then
  echo "BLOCK: 기밀 패턴 경로가 staged됨"; exit 1
fi
exit 0
```

**`scripts/nightly-sync.sh`** ★ 모델 b 전면 재작성 — launchd 17:00 실행체. **커밋까지만, push 없음.** apply 절대 금지.
```bash
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
```
v1 대비 삭제: [4] nvim lazy-lock 7일 dirty 감시 — nvim 흡수로 write-through되어 야간 커밋에 자동 포함([I8] 소멸). [8] push 재시도 분기, [11] push+요약 알림 — 모델 b로 소멸([I5][W8]).
로그는 plist의 StandardOut/ErrorPath(`~/Library/Logs/chezmoi-sync.log`)로 — repo 밖이라 롤링 코드 불요.

**`private_Library/private_LaunchAgents/com.user.chezmoi-sync.plist.tmpl`** ★ 17:00 (launchd StartCalendarInterval은 로컬 타임존)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.user.chezmoi-sync</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>{{ .chezmoi.sourceDir }}/scripts/nightly-sync.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>17</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>{{ .chezmoi.homeDir }}/Library/Logs/chezmoi-sync.log</string>
  <key>StandardErrorPath</key><string>{{ .chezmoi.homeDir }}/Library/Logs/chezmoi-sync.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
</dict>
</plist>
```

### 2.6 템플릿(.tmpl) 대상 — 최소주의 4계열

1. **`private_Library/private_LaunchAgents/com.user.chezmoi-sync.plist.tmpl`** — launchd는 `$HOME` 미확장이므로 절대경로 3곳 전부 템플릿(위 전문). 17:00. ~/Library는 macOS 기본 700 — private_ 접두사로 모드 보존, 미지정 시 apply가 755 강제.
2. **심링크 tmpl 7개** — `private_dot_claude/symlink_*.tmpl` 6개(내용: `{{ .chezmoi.sourceDir }}/external_claude/<이름>`) + ★`dot_config/symlink_nvim.tmpl`(내용: `{{ .chezmoi.sourceDir }}/external_nvim`). 머신마다 apply 시점의 소스 경로로 렌더 → 홈 경로 하드코딩의 구조적 해결 지점.
3. **`dot_local/bin/symlink_node.tmpl`**(`{{ .chezmoi.homeDir }}/.local/share/fnm/aliases/default/bin/node`).
4. **`.chezmoi.toml.tmpl` + `.chezmoiscripts/*.tmpl`** — OS 가드, Brewfile/plist 해시 트리거, sourceDir 참조.

**홈 경로 재발 방지 3중 구조** (v1 유지): ① repo 콘텐츠 리터럴 `/Users/*` 0건 원칙 ② pre-commit `/Users/` grep 가드(구조 파일 한정) ③ S7 공개 게이트의 전수 grep.

**템플릿화 금지 목록** (v1 + nvim 확장): `dot_zshrc`·`dot_zshenv`(하드코딩 0건 실측), `hooks/run-node.sh`·`statusline-wrapper.sh`(이미 포터블), `settings.json`(앱 소유 라이브 파일), ★`external_nvim/` 페이로드 전체 — 특히 `lazy-lock.json`(앱 재작성 파일 — 템플릿화 시 write-through와 즉시 충돌).

---

## 3. 동기화 모델 (모델 b)

### 3.1 앱-재작성 파일: externally-modified symlink 패턴 — 이제 claude + nvim 공통

`settings.json`(CLI 재작성)·`hooks/`(플러그인 auto-deploy)·`skills`·`agents`·`CLAUDE.md`·`statusline-wrapper.sh` → `external_claude/`, ★`lazy-lock.json`(lazy.nvim 재작성)·nvim 설정 전체 → `external_nvim/`. 페이로드를 소스 repo에 실파일로 두고 chezmoi 관리를 끈 뒤(.chezmoiignore), 홈에는 sourceDir향 심링크 **7개**(~/.claude 6 + ~/.config/nvim 1)만 배포.

**왜 이 방식인가** (v1 논증 유지): 앱이 쓰는 순간 심링크 관통으로 소스 working tree에 반영 = drift가 정의상 0이고, `chezmoi apply`(--force 포함)가 앱 변경을 되돌리는 것이 구조적으로 불가능(내용이 타깃 상태 밖). 디렉터리 심링크라 "새 파일 자동 편입"도 보존. `external_` prefix로 소스 속성 파싱 면역([I4]) — external_nvim에도 동일 적용. v1의 "nvim-settings는 통합하지 않는다"는 흡수 결정으로 대체 — 별도 repo·별도 커밋처가 사라져 lazy-lock이 야간 커밋에 자동 합류한다.

### 3.2 야간 자동 백업: launchd 17:00, **로컬 커밋까지만**

- 라벨 `com.user.chezmoi-sync`(plist는 chezmoi 템플릿 관리, run_onchange_40이 reload). 구 `com.user.claude-sync`는 S1에서 bootout+**disable**(재부팅 영속), S8에서 plist 삭제.
- 파이프라인(2.5): lock → gitleaks smoke → 심링크 7개 assert+fallback → 표면 감사 → re-add → `git add -A` → 기밀 staged 게이트 → gitleaks 명시 스캔 → **커밋** → **"커밋됨 + 미push N개(최고 M일)" 알림**. 여기서 끝 — **push 없음**.
- **push는 사람의 명시적 행위**: `chezmoi cd` → `git log -p origin/main..HEAD` diff 리뷰 → `git push`. **리뷰는 반드시 diff 수준** — 야간 커밋 제목은 전부 동일한 `chore(dotfiles): auto-sync …`라 메시지-온리 `git log`는 리뷰어에게 콘텐츠 정보량이 0이다. **최소 리뷰 범위 = external_claude/CLAUDE.md·skills·agents diff 통독 — push의 필수 선행 조건.** 권장 리듬 주 1회 이상(알림이 매일 17:00 미push 카운트·최고령을 리마인드).
- `autoCommit/autoPush=false` 유지 — chezmoi 순정. 자동 git 동작은 야간 잡의 `add`/`commit`뿐이며 chezmoi 설정으로는 어떤 자동 git도 켜지 않는다.
- **야간 잡은 `chezmoi apply`를 절대 하지 않는다** (v1 유지): 설정 역행·self-bootout 함정 원천 차단. 정방향은 항상 사람이 대화형으로.
- **launchd 활성화는 S8(원격 공개 후)** (v1 순서 유지 [B1][B4]): 무인 push는 없어졌지만 무인 **커밋**은 여전히 히스토리에 박히므로, 공개 전 히스토리를 사람의 의도적 커밋만으로 유지하는 순서는 그대로 둔다. 신규 repo라 히스토리가 짧아 S7 전 히스토리 스캔 부담도 최소.

**산문 기밀의 구조적 해소**: gitleaks는 비-시크릿 기밀 "산문"(클라이언트명·경로가 든 문장)에 0겹이다. v1(자동 push)은 push 후 24h 회수 창([W8])이라는 사후 보정에 의존했으나, 모델 b에서는 **원격에 닿는 모든 바이트가 사람의 diff 리뷰(`git log -p`)를 통과** — 리뷰가 사후 회수가 아닌 완전한 사전 게이트가 되어 W8이 소멸한다. 단 이 게이트의 성립 조건은 diff 수준 리뷰다(3.2 최소 리뷰 범위) — 메시지-온리 리뷰로는 소멸 판정이 성립하지 않는다.

**트레이드오프 (정직한 명시)**: 미push 손실 창. 로컬 디스크와 머신이 동시에 죽으면 마지막 push 이후의 커밋들이 소실된다 — push 리듬이 주 1회면 최대 약 1주치 설정 변경분. 완화: ① 매일 17:00 알림이 미push 카운트+최고령을 표시(6일 넘게 쌓이면 알림 문구로 자각) ② 이 repo는 "설정 백업"이라 홈이 살아있는 한 재캡처 가능 — 원격은 재해 복구용 2차 사본이고 홈+로컬 git 2중은 매일 갱신된다. v1의 반대 리스크(산문 기밀이 24h 내 public 노출)와 견줘 의도적으로 선택한 트레이드오프다.

### 3.3 gitleaks 게이트 위치 (신뢰 게이트 2중 + 공개 게이트 1 — v1 유지)

1. **`githooks/pre-commit`** — 모든 커밋 경로(야간·수동)의 최종 게이트. `core.hooksPath`+run_once_30으로 클론마다 자동 복원. rc=1(시크릿)/기타 rc(툴 오류) 구분 fail-closed.
2. **`nightly-sync.sh` 내 명시 스캔** — macOS 알림 UX 담당, 동일 rc 분기.
3. **S7 공개 게이트: `gitleaks git`(전 히스토리)** — working tree만 보는 `gitleaks dir`은 히스토리 blob을 놓침이 실증([B4]).

`add.secrets="error"`는 v2.71.1 실기기 미발동 실증([W6])으로 방어 산정 제외(선언은 유지, 버전 업 시 재검증 — 9장 운영 규칙).

**유출 경로 0 논증 (모델 b 갱신)**: 기밀이 public repo에 도달하려면 [chezmoi add(→ignore가 차단 — add 방향 차단 실증) 또는 심링크 페이로드 내 생성(→전 깊이 gitignore+staged 게이트 2중 차단)] AND [pre-commit 통과] AND [**사람이 diff 리뷰(`git log -p`) 후 수동 push**] AND [공개 전 전 히스토리 스캔 통과]가 모두 뚫려야 한다. v1 대비 "사람 push" 한 겹이 추가되었고, 이 겹은 산문 기밀까지 커버하는 유일한 겹이다. `~/projects`와 `~/.claude` 런타임은 어떤 자동 수집 경로에도 연결되어 있지 않다.

---

## 4. v1 공격 검증 승계표

v1의 BLOCK 6·WARN 12·INFO 8이 v2에서 어떤 상태인지. **소멸은 반드시 구조적 사유가 있어야 하며, 편의에 의한 완화는 없다.**

| ID | v2 상태 | 근거 |
|----|----|----|
| B1 | **유지(위협 약화)** | 무인 push 소멸로 3단 체인의 마지막 고리가 끊겼으나 무인 커밋은 여전히 히스토리에 박힘 → S7 `gitleaks git` 전 히스토리 스캔 + launchd 활성화를 public 이후(S8)로 미루는 순서 전부 유지 |
| B2 | 유지 | sourceDir graft 기각 유지(기본 `~/.local/share/chezmoi`), 완전 철수 rm -rf 리터럴 경로 고정, run_onchange_40 sourceDir 주석. 구 dotfiles 경로 충돌 논점은 soak 후 삭제로 자연 해소되나 원칙은 존치 |
| B3 | 유지 | `.gitignore` `memory/` 전 깊이 패턴, nightly [6]+pre-commit 게이트 3 이중화, 캡처 rsync **양 경로(claude·nvim — S4 ①·② 및 nightly [2] fallback 2종) 모두** 기밀 exclude 세트(`memory/`·`*.local.*`·`*.log`·`.DS_Store`), S7 `find … -name memory` 0건 게이트(external_nvim까지 확대) |
| B4 | 유지 | S7 `gitleaks git`(전 히스토리)+`git log --all` 육안, launchd 활성화 공개 후 순서 유지 |
| B5 | **강화** | 심링크 assert+fallback 캡처 대상이 claude 6개 → **7개(nvim 추가)**. "apply 프롬프트에 페이로드 경로 등장 = 파손 신호, 승인 금지" 원칙에 `~/.config/nvim`도 포함 |
| B6 | 유지 | `/Users/` 가드 구조 파일 한정, nightly [9] commit rc 검사+알림, `ALLOW_USERS_PATH=1` 탈출구 |
| W1 | 유지 | S1 bootout+**disable**(override DB, 재부팅 영속) 2단, `print-disabled` 검증, 롤백 `enable` 복원 |
| W2 | **소멸(사유: divergence 창 자체 제거)** | 구 repo→소스 rsync 2회+창 닫기 구조가 라이브 홈 1회 캡처로 대체되어 스냅샷↔전환 사이 창이 없음. 잔여 조치(pgrep 세션 종료 게이트, 롤백의 조건부 회수-우선)는 S4·6장에 승계 |
| W3 | 유지 | 실측 검출 확인된 임의 AKIA 픽스처(allowlist 밖 값 사용 — 실제 값은 재현 시 임의 생성), 양성/음성 대조군, 픽스처 즉시 삭제 (S3) |
| W4 | 유지 | nightly [9] commit rc 검사+알림+exit 1, gitleaks 미설치 fail-closed |
| W5 | 유지 | 모든 롤백에서 `chezmoi forget --force` 선행 — 재탈취 봉쇄 (6장) |
| W6 | 유지 | add.secrets 방어 산정 제외·선언 유지·리허설은 "발동 여부 기록"(S3), 업그레이드 후 재검증 규칙(9장) |
| W7 | 유지 | `.claude.json`(+backup*) ignore 등재, gitignore 미러, S6 dry-run 네거티브 테스트 |
| W8 | **소멸(사유: push 수동화+diff 리뷰 의무)** | 24h 회수 창이라는 사후 보정 자체가 불요 — push 전 사람 diff 리뷰(`git log -p`, 최소 범위 3.2)가 완전한 **사전** 게이트. 메시지-온리 리뷰는 야간 커밋 제목 동일성 탓에 정보량 0이므로 diff 수준이 소멸의 성립 조건. v1 "남은 결정 1"의 강화안이 모델 b로 상위 호환 채택된 셈 |
| W9 | 유지 | nightly [4] re-add rc 알림, `~/.zshrc.local` 시크릿 격리 관례(미백업) |
| W10 | 유지 | `.gitignore` 기밀 미러 섹션(history.jsonl·sessions·projects 등) |
| W11 | 유지 | pre-commit·nightly 양쪽 rc=1/기타 rc 분기, nightly [1] smoke 체크 |
| W12 | 유지 | nightly [3] 표면 감사+`claude-surface.txt` baseline. keybindings.json은 "생기면 표면 감사" 기본안 확정 |
| I1 | **소멸(사유: 스텝 자체 삭제)** | 구 repo 커밋 정리(P0-2)·bundle 3종 의식이 리프레임으로 삭제 — 구 repo는 소스가 아니므로 dirty여도 무해(캡처 시점의 라이브 파일이 그대로 v2 소스가 되어 손실 없음) |
| I2 | 유지 | S5 2단 apply: `chezmoi apply ~/.zshrc ~/.zshenv` → 전체 apply (부재 창 초 단위) |
| I3 | 유지(형태 변경) | 구 repo `git ls-files` 매니페스트 대조 → **동일 rsync `-n` 재실행 무전송** + 루트 파일 `cmp` (라이브 캡처에 맞는 등가 검증) |
| I4 | **강화** | `external_` prefix 파싱 면역이 external_nvim에도 적용 — 페이로드 2개 모두 면역 |
| I5 | **소멸(사유: 알림 대체)** | push 자동 재시도가 무의미(push 자체가 수동) → "미push N개(최고 M일)" 알림으로 대체. 잔여 추적 기능은 오히려 강화(카운트+나이 상시 보고) |
| I6 | 유지 | graft 기각(B2), age 미도입(암호화 대상 0건 실측) |
| I7 | 유지 | S6 dry-run 기밀 add 차단 게이트 + "chezmoi 업그레이드 후 S6 재실행" 운영 규칙 |
| I8 | **소멸(사유: nvim 흡수)** | lazy-lock.json이 write-through 페이로드에 편입 — 야간 커밋에 자동 포함되어 7일 dirty 감시(nightly 구 [4]) 자체가 불요 |

---

## 5. 실행 런북 (8스텝)

> **실행 완료 (2026-07-21)**: S1~S8 전부 실행됨. 이 런북은 이후 신규 머신 재현 및 롤백 참조용.
> 원격: github.com/temeraire97/dotfiles (public). 소스: ~/.local/share/chezmoi

전제: S2의 홈 스냅샷은 전 과정 **읽기 전용 앵커**. S4~S5는 모든 Claude Code 세션·nvim을 종료한 **plain 터미널**에서 연속 실행한다(이 런북을 Claude 세션으로 실행하면 그 세션 자체가 S4 게이트 위반). 구 repo 2개에 커밋·push하지 않는다 — dirty 상태 그대로 두어도 무해(라이브 파일이 소스). 단 하나의 의도적 예외: S2의 파손 심링크 청소는 ~/.claude/* 디렉터리 심링크를 관통해 claude-setting working tree를 실변경한다(tracked 파일이라 soak 기간 `git checkout`으로 가역).

---

**[S1] 구 야간 잡 정지 — 최우선, 영속 차단** `[W1][B1]`
- 명령:
  ```bash
  launchctl bootout gui/$(id -u)/com.user.claude-sync
  launchctl disable gui/$(id -u)/com.user.claude-sync   # override DB — 재부팅/재로그인에도 영속
  ```
  plist 파일은 롤백용으로 그대로 둔다. S8까지 재로드 금지.
- 검증: `launchctl list | grep claude-sync` → 출력 없음; `launchctl print-disabled gui/$(id -u) | grep com.user.claude-sync` → `disabled`.
- 롤백: `launchctl enable gui/$(id -u)/com.user.claude-sync && launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.claude-sync.plist`.

**[S2] 홈 스냅샷 1개 — 영구 롤백 앵커** (v1 P0-2·P0-3의 축소 대체)
- 명령:
  ```bash
  TS=$(date +%Y%m%d-%H%M%S); B=~/backups/pre-chezmoi-$TS; mkdir -p "$B/claude"
  # 파손 심링크 정리 — 기록 → 삭제 순서 (삭제 항목이 앵커에 남도록. 백업 가치 0 + 이후 rsync -aL 오류 방지)
  find -L ~/.claude/skills ~/.claude/agents ~/.claude/hooks -type l > "$B/removed-broken-links.txt"  # -L에서 -type l = 파손 링크만 매치
  find -L ~/.claude/skills ~/.claude/agents ~/.claude/hooks -type l -exec rm {} +   # ⚠ ~/.claude/* 디렉터리 심링크 관통 → claude-setting
                                                                                     #   working tree 실변경(의도된 유일 예외 — tracked라 git checkout 가역)
  find -H ~/.claude/skills ~/.claude/agents ~/.claude/hooks -type l | wc -l          # → 0 필수. 잔존(해석 가능 링크) 시
                                                                                     #   육안 판단 — 외부 참조 inlining 방지 게이트
  for f in CLAUDE.md settings.json statusline-wrapper.sh skills agents hooks; do
    rsync -aL "$HOME/.claude/$f" "$B/claude/"          # 해석 복사 — 심링크 관통 실파일
  done
  cp -L ~/.zshrc "$B/zshrc"; cp -L ~/.zshenv "$B/zshenv"
  ls -la ~/.claude > "$B/links-claude.txt"
  ls -la ~/.zshrc ~/.zshenv ~/.config/nvim ~/.local/bin/node > "$B/links-home.txt"
  cp ~/Library/LaunchAgents/com.user.claude-sync.plist "$B/"
  ```
  nvim은 스냅샷 불요 — soak 기간 앵커는 nvim-settings repo 자체(원격 포함, `ln -s` 복원으로 즉시 원상)이며 soak 후에는 소스 repo의 external_nvim이 최신 페이로드다.
- 검증: `ls "$B"` → claude/·zshrc·zshenv·links 2종·removed-broken-links.txt·plist 존재; `cmp ~/.claude/settings.json "$B/claude/settings.json"` → 무출력; `links-claude.txt`에 심링크 6개 기록.
- 롤백: 읽기 전용(파손 링크 삭제는 의도적 청소 — 복원 불요. 목록은 `removed-broken-links.txt`, 필요 시 claude-setting에서 `git checkout`으로 복구 가능). 스냅샷 완성 전 다음 단계 진입 금지.

**[S3] chezmoi 설치 + 소스 초기화 + 안전 골격 + 게이트 리허설** `[W3][W6]`
- 명령:
  ```bash
  brew install chezmoi
  chezmoi init                                  # 원격 없이 로컬 전용
  SRC=$(chezmoi source-path)
  # .chezmoi.toml.tmpl / .chezmoiignore(2.2 최종본) / .gitignore(2.3) / githooks/pre-commit(2.5) 작성 후:
  git -C $SRC config core.hooksPath githooks && chmod +x $SRC/githooks/pre-commit
  git -C $SRC add -A && git -C $SRC commit -m "feat(chezmoi): 안전 골격(시크릿 게이트·ignore) 구축"
  chezmoi init                                  # 설정 재생성
  ```
  (v1의 임시 안전벨트 2줄은 폐지 — 2.2 사유. 최종본을 처음부터 사용.)
- 검증 (게이트 리허설 5종 — v1 P1-2 승계):
  1. `chezmoi --version`; `chezmoi doctor`에 FAILED 없음; `git -C $SRC rev-parse --git-dir` → `.git`.
  2. **양성 대조군(pre-commit 시크릿)**: `echo 'aws_access_key_id=AKIA################' > $SRC/.leaktest; git -C $SRC add .leaktest; git -C $SRC commit -m "test(gate): 차단 확인"` → **차단(exit≠0)** → `git -C $SRC reset && rm $SRC/.leaktest` (픽스처 즉시 삭제 필수. 픽스처는 재현 시 임의의 유효 형식 AKIA 값으로 생성 — gitleaks allowlist에 없는 값이어야 함).
  3. **양성 대조군(/Users/ 가드)**: `echo '/Users/hyunsoo/x' > $SRC/gate-test.tmpl` → add·commit 시도 → 차단 확인 → reset+삭제 (가드는 구조 파일 한정 — 반드시 `.tmpl`로 테스트).
  4. **음성 대조군**: 무해 파일 1개 커밋 통과 확인.
  5. **add.secrets 발동 기록**: `echo 'aws_access_key_id=AKIA################' > ~/.fake-secret; chezmoi add ~/.fake-secret` → 발동 여부 **기록만**(v2.71.1 미발동이 정상) → `chezmoi forget --force ~/.fake-secret 2>/dev/null; rm -f $SRC/dot_fake-secret ~/.fake-secret` (커밋 전 완전 삭제 — 히스토리 오염 금지).
- 롤백: `rm -rf ~/.local/share/chezmoi ~/.config/chezmoi`; `brew uninstall chezmoi` — 시스템 무변경.

**[S4] 라이브 캡처 + 소스 완성** ★ 리프레임의 핵심 — 구 repo가 아닌 **현재 홈**에서 1회 캡처
- 게이트: 모든 Claude Code 세션·nvim 종료. **이하 S5까지 plain 터미널에서 연속 실행.**
  `pgrep -x claude` → 없음; `pgrep -x nvim` → 없음; `find -H ~/.claude/skills ~/.claude/agents ~/.claude/hooks -type l | wc -l` → 0 (S2 이후 재발 확인); `launchctl list | grep -E 'claude-sync|chezmoi-sync'` → 없음 (구 야간 잡 부재 재확인 — v1 P2-1 belt-and-suspenders 복원).
- 명령:
  ```bash
  SRC=$(chezmoi source-path); mkdir -p $SRC/external_claude $SRC/external_nvim
  # ① claude 6항목 — 라이브 홈에서 해석 복사 1회 (rsync -aL = cp -RL + exclude)
  rsync -aL --exclude 'memory/' --exclude '*.local.md' --exclude '*.local.json' \
        --exclude '.DS_Store' --exclude '*.log' --exclude '*.backup.*' \
        ~/.claude/CLAUDE.md ~/.claude/settings.json ~/.claude/statusline-wrapper.sh \
        ~/.claude/skills ~/.claude/agents ~/.claude/hooks \
        $SRC/external_claude/
  # ② nvim 페이로드 — ~/.config/nvim(현재 nvim-settings향 심링크)을 -L로 해석 복사
  rsync -aL --exclude '.git' --exclude 'install.sh' --exclude 'README*' --exclude 'LICENSE' \
        --exclude 'memory/' --exclude '*.local.md' --exclude '*.local.json' \
        --exclude '*.log' --exclude '.DS_Store' \
        ~/.config/nvim/ $SRC/external_nvim/
  # ③ zsh 흡수 (심링크 관통 — 해제는 S5)
  chezmoi add --follow ~/.zshrc ~/.zshenv
  # ④ Brewfile — 라이브 캡처
  brew bundle dump --file=$SRC/Brewfile --force
  # ⑤ 구조 파일 작성(2장 전문): 심링크 tmpl 7개, symlink_node.tmpl, scripts/nightly-sync.sh,
  #    run_onchange_before_10 / run_once_after_20·25·30·50  (plist·run_onchange_40은 S8로 연기)
  git -C $SRC add -A && git -C $SRC commit -m "feat(backup): 현재 머신 설정 첫 캡처(claude·nvim·zsh·brew)"
  ```
- 검증:
  ```bash
  # 캡처 완전성 — 동일 인자 dry-run 재실행이 무전송이면 완전 [I3 등가 대체]
  rsync -aLn --itemize-changes <①과 동일 인자>   # → 무출력
  rsync -aLn --itemize-changes <②와 동일 인자>   # → 무출력
  for f in CLAUDE.md settings.json statusline-wrapper.sh; do cmp ~/.claude/$f $SRC/external_claude/$f; done
  cmp ~/.config/nvim/lazy-lock.json $SRC/external_nvim/lazy-lock.json
  test -f $SRC/external_claude/hooks/package.json && test -f $SRC/external_claude/hooks/run-node.sh && echo HOOKS_OK
  test ! -e $SRC/external_nvim/.git && test ! -e $SRC/external_nvim/install.sh && echo NVIM_OK
  find $SRC/external_claude $SRC/external_nvim -type d -name memory | wc -l   # → 0
  find $SRC/external_claude $SRC/external_nvim -type l | wc -l                # → 0
  chezmoi cat ~/.zshrc | diff - ~/.zshrc                                      # → 무출력
  grep -q 'brew "chezmoi"' $SRC/Brewfile && echo BREW_OK
  ```
- 롤백: `rm -rf $SRC/external_claude $SRC/external_nvim; chezmoi forget --force ~/.zshrc ~/.zshenv` 후 커밋 전이면 `git -C $SRC checkout -- . && git -C $SRC clean -fd`, 커밋 후면 `git -C $SRC reset --hard HEAD~1` — **홈은 무변경**(캡처·add는 전부 소스 방향 복사).

**[S5] apply — 심링크 7개 재타깃 + zsh 타입 전환** `[I2][B5]`
- 명령:
  ```bash
  chezmoi apply --dry-run --verbose   # 육안 게이트: zsh 타입 전환 + 심링크 7개 재타깃 + 스크립트 pending"만".
                                      # settings.json 등 "내용" diff가 보이면 ignore 오류 — 즉시 중단
  rm ~/.zshrc ~/.zshenv && chezmoi apply ~/.zshrc ~/.zshenv   # 파일만 즉시 배치 — 부재 창 초 단위 [I2]
  chezmoi apply                                               # 전체 (스크립트 포함 — run_once_25가 Lazy restore)
  ls -A ~/.claude > $SRC/scripts/claude-surface.txt           # 표면 감사 baseline [W12]
  git -C $SRC add -A && git -C $SRC commit -m "chore(claude): 표면 baseline 기록"
  ```
- 검증:
  ```bash
  for f in CLAUDE.md settings.json statusline-wrapper.sh skills agents hooks; do readlink ~/.claude/$f; done
                                              # → 전부 $SRC/external_claude/*
  readlink ~/.config/nvim                     # → $SRC/external_nvim
  [ ! -L ~/.zshrc ] && [ -f ~/.zshrc ] && echo ZSH_OK; zsh -ic 'echo SHELL_OK'
  ~/.local/bin/node -v; command -v pnpm       # → /opt/homebrew/bin/pnpm
  jq -e . ~/.claude/settings.json >/dev/null && echo JSON_OK
  claude --version                            # + 새 세션 1회: statusline·훅 무오류 확인 후 종료
  nvim --headless '+q'                        # 무오류 기동 (Lazy restore는 run_once_25가 수행)
  # write-through 실증 — claude·nvim 각 1회 [v1 P2-5 승계]
  touch ~/.claude/skills/.wt-test && git -C $SRC status --porcelain | grep -q 'external_claude/skills/.wt-test' \
    && rm ~/.claude/skills/.wt-test && echo WT_CLAUDE_OK
  touch ~/.config/nvim/.wt-test && git -C $SRC status --porcelain | grep -q 'external_nvim/.wt-test' \
    && rm ~/.config/nvim/.wt-test && echo WT_NVIM_OK
  ```
- 롤백: 6장 "soak 기간 롤백" — claude는 `claude-setting install.sh`, nvim은 심링크 복원으로 즉시 원상.

**[S6] 야간 파이프라인 수동 리허설 + 기밀 add 차단 검증** `[I7][W7]` — **전부 통과 전 S7 진입 금지**
- ※ 실행 완료(22ae7e1/9522d1f) — 아래 newline-안전 수정은 S8·후속 머신 재실행용.
- 명령:
  ```bash
  printf '\n# rehearsal %s\n' "$(date +%s)" >> ~/.claude/CLAUDE.md   # 선행 \n = trailing newline 부재 파일에서도 마커 독립 라인 보장
                                             # ⚠ echo "…" >> 금지: CLAUDE.md가 newline 없이 끝나면 마커가 마지막 실콘텐츠
                                             #   라인에 병합 → 라인 삭제 원복이 사용자 콘텐츠까지 지우는 파괴 동작이 됨(실증)
  bash $SRC/scripts/nightly-sync.sh          # 1회차: 커밋 경로 리허설
  git -C $SRC show HEAD~1:external_claude/CLAUDE.md > $SRC/external_claude/CLAUDE.md
                                             # 원복 = git 원복(마커 주입 직전 커밋 상태로 바이트-정확 — trailing newline 상태 무관).
                                             #   sed 라인 삭제 대체. 소스 실파일 리다이렉트 — write-through 등가라 홈 뷰 즉시 일치
  bash $SRC/scripts/nightly-sync.sh          # 2회차: 원복 커밋
  bash $SRC/scripts/nightly-sync.sh          # 3회차: no-op (exit 0, 무커밋·무알림)
  # 기밀 add 차단 dry-run — 게이트 고장이어도 소스에 실복사 없음 [v1 P2-7 승계]
  chezmoi add --dry-run --verbose ~/.claude/history.jsonl 2>&1 | grep -i ignoring
  chezmoi add --dry-run --verbose ~/.claude/projects     2>&1 | grep -i ignoring
  chezmoi add --dry-run --verbose ~/.claude.json         2>&1 | grep -i ignoring
  chezmoi add --dry-run --verbose ~/projects             2>&1 | grep -i ignoring
  ```
- 검증: `git -C $SRC log -2 --format=%s` → `chore(dotfiles): auto-sync YYYY-MM-DD HH:MM` 2건(한국어 CC·scope·fingerprint 없음); 1·2회차에 **"auto-sync 커밋됨 — 미push 집계 불가(원격 미설정)…" 알림 발화**(원격 부재 상태의 정상 문구 — push 시도·push 알림은 없어야 함); 심링크 파손 알림 0; 3회차 무커밋; dry-run 4건 모두 `ignoring` 출력; `chezmoi managed | grep -E 'history|\.claude\.json|projects'` → 무출력. 실패 시 해당 파일 수정 후 이 스텝 재실행.
- 롤백: 무해 커밋 2건뿐 — 파괴적 동작 없음.

**[S7] 전 히스토리 스캔 → private 생성 → 최초 수동 push → 육안 → public 전환** `[B1][B4]` ★ 유일한 사용자 승인점
- 명령:
  ```bash
  SRC=$(chezmoi source-path)
  gitleaks git $SRC --no-banner                                          # 전 커밋 히스토리 — 0건 필수
  git -C $SRC log --all --diff-filter=A --name-only --format= | sort -u  # 히스토리 등장 전체 경로 육안 감사
  grep -RIlE --exclude-dir=.git '/Users/[a-z]' $SRC                      # 전수 grep — 판정 이원화(B6 정합): 구조 파일 히트 = 즉시 수정(무출력 필수),
                                                                         #   external_claude/·external_nvim/ 페이로드 히트 = 앱이 절대경로를 쓸 수 있으므로
                                                                         #   기밀성 육안 판단 후 진행 가능(트리아지 — 페이로드는 템플릿화 금지 대상)
                                                                         #   평문 /Users/는 pre-commit 게이트 자신의 가드 정규식에 자기참조 히트 — B6 정합 패턴으로 실제 홈 경로만 검사
  find $SRC/external_claude $SRC/external_nvim -type d -name memory      # 무출력 필수
  chezmoi managed                                                        # 육안: 예상 목록만
  gh repo create temeraire97/dotfiles --private --description 'chezmoi dotfiles'
  git -C $SRC remote add origin git@github.com:temeraire97/dotfiles.git
  git -C $SRC push -u origin main        # 최초 push — 수동 (모델 b: 원격에 닿는 push는 처음부터 사람 손)
  # GitHub 웹 육안: external_claude/{skills,agents,hooks}·external_nvim/{lua,lazy-lock.json} 존재,
  # projects/·memory/·mcp.json·history·.claude.json 부재, 전체 커밋 히스토리 확인,
  # external_nvim 콘텐츠 1회 통독(주석·경로·클라이언트 언급 여부 — 구 별도 repo 가시성에서 public dotfiles로의 승격 검토). 이상 없을 때만:
  gh repo edit temeraire97/dotfiles --visibility public --accept-visibility-change-consequences
  ```
  신규 repo라 히스토리가 짧아(수 커밋) 스캔·육안 부담 최소. repo 이름 `dotfiles`는 구 로컬 dotfiles repo와 중복이었으나 2026-07-21 해당 repo 삭제로 해소(9장) — 충돌 논점 종결.
- 검증: `gh repo view temeraire97/dotfiles --json visibility` → PUBLIC (**사용자 명시 승인 후에만** — 8장).
- 롤백: 스캔·감사 실패 → **private 유지 상태에서** 정화(`git filter-repo` 또는 orphan 스쿼시) 후 재push·재검증. public 전환 후 발견 → 6장 "public 전환 후 기밀 발견".

**[S8] launchd 17:00 활성화 + E2E 리허설 + 구 잡 제거 → soak 개시** `[B1][W1]`
- 명령:
  ```bash
  # ① plist.tmpl(17:00)·run_onchange_after_40 작성·커밋 → 리뷰 후 수동 push
  git -C $SRC add -A && git -C $SRC commit -m "feat(launchd): 야간 백업 에이전트 활성화(17:00)"
  git -C $SRC push
  chezmoi apply                                               # plist 배치 + run_onchange_40이 bootstrap
  launchctl kickstart -k gui/$(id -u)/com.user.chezmoi-sync   # 강제 1회 발화
  # ② E2E: "커밋 도달 + 알림 발화" 검증 — push 검증이 아님 (모델 b)
  printf '\n# e2e-test %s\n' "$(date +%s)" >> ~/.claude/CLAUDE.md   # newline-안전 주입 (S6 동일 — echo >> 는 trailing newline 부재 시 마지막 라인에 병합, 금지)
  bash $SRC/scripts/nightly-sync.sh          # 커밋 + "커밋됨 — 미push N개" 알림 확인
  git -C $SRC show HEAD~1:external_claude/CLAUDE.md > $SRC/external_claude/CLAUDE.md \
    && bash $SRC/scripts/nightly-sync.sh     # 원복 = git 원복(S6 동일 — 마커 주입 직전 커밋으로 바이트-정확, trailing newline 무관.
                                             #   소스 실파일 리다이렉트 = write-through 등가라 홈 뷰 즉시 일치)
  # ③ push는 수동 실행으로 확인: 리뷰 → push → 원격 도달
  git -C $SRC log -p origin/main..HEAD       # e2e 커밋 2건 diff 육안 리뷰 (= 실전 push 전 diff 리뷰 관행의 첫 실습 — 3.2 최소 범위)
  git -C $SRC push
  # ④ 구 잡 제거 (plist 사본은 S2 스냅샷에 존재. disable 오버라이드는 라벨 상이로 새 잡에 무영향)
  rm ~/Library/LaunchAgents/com.user.claude-sync.plist
  ```
- 검증: `launchctl print gui/$(id -u)/com.user.chezmoi-sync | grep nightly-sync` → 로드 확인; `tail -20 ~/Library/Logs/chezmoi-sync.log` → 정상 종료; ②에서 auto-sync 커밋 2건 + 알림 2회(각 "커밋됨 — 미push …") 발화; ③ 후 `git -C $SRC log origin/main..HEAD` → 빈 출력; `launchctl list | grep -E 'claude-sync$'` → 없음.
- 롤백: `launchctl bootout gui/$(id -u)/com.user.chezmoi-sync; rm ~/Library/LaunchAgents/com.user.chezmoi-sync.plist` 후 원인 수정·재apply. 구 plist는 스냅샷에서 복원 가능.
- **soak 개시**: 이후 1주 일상 사용. 매일 17:00 알림 확인, 주 1회 이상 `chezmoi cd` → `git log -p` diff 리뷰 → `git push`. 통과 기준·이후 정리는 9장.

---

## 6. 롤백 전판

**공통 원칙**: 앵커는 2계층 — ① **S2 홈 스냅샷**(`~/backups/pre-chezmoi-$TS`, 비-git, 영구 보관 권장) ② **soak 1주 한정 구 repo 2개**(공짜 롤백 수단 — claude-setting `install.sh` 재실행/nvim 심링크 복원 = 즉시 원상). 모든 롤백은 `chezmoi forget --force` 선행([W5] — 이후 apply의 재탈취 봉쇄). **주의: `chezmoi apply` 프롬프트에 `~/.claude` 또는 `~/.config/nvim` 하위 경로가 나타나면 심링크 파손 신호 — 승인 금지, 조사 우선**([B5]).
구 dotfiles repo(구, 로컬 전용 `dotfiles`)는 2026-07-21 삭제됨 — 아카이브: `~/backups/pre-chezmoi-20260721-151630/old-dotfiles-repo.tar.gz`(25K).

### S1~S3 실패 시
홈 무변경 구간. launchd 복원(S1 롤백) 또는 `rm -rf ~/.local/share/chezmoi ~/.config/chezmoi`(S3 롤백)로 원상.

### zsh 롤백 `[W5]`
```bash
chezmoi forget --force ~/.zshrc ~/.zshenv        # ① 관리 해제 먼저
rm -f ~/.zshrc ~/.zshenv
cp "$B/zshrc" ~/.zshrc && cp "$B/zshenv" ~/.zshenv          # ② 스냅샷 실파일 복원
# (구 dotfiles repo 삭제됨 2026-07-21 — 심링크 복원 대안 소멸. 아래로 대체:)
# cp ~/backups/pre-chezmoi-20260721-151630/zshrc  ~/.zshrc
# cp ~/backups/pre-chezmoi-20260721-151630/zshenv ~/.zshenv
```
검증: `chezmoi managed | grep -E 'zshrc|zshenv'` → 무출력; `zsh -ic 'echo OK'`. node 링크는 no-op(무변경 검증됨), brew bundle은 추가 설치뿐 — 조치 불요.

### claude 롤백 — soak 기간 (회수-우선 조건부)
```bash
# ① 회수(조건부): 전환 완료(S5 이후)일 때만 — chezmoi 기간 변경분을 구 repo로 회수
if [ "$(readlink ~/.claude/settings.json)" = "$(chezmoi source-path)/external_claude/settings.json" ]; then
  rsync -a $(chezmoi source-path)/external_claude/ ~/projects/claude-setting/
  git -C ~/projects/claude-setting add -A && git -C ~/projects/claude-setting commit -m "chore(claude): chezmoi 기간 변경분 회수"
fi
# ② 심링크 6개 재생성 + 구 plist 재설치 — 즉시 원상
bash ~/projects/claude-setting/install.sh
# ③ 관리 해제 — 재탈취 봉쇄
chezmoi forget --force ~/.claude/CLAUDE.md ~/.claude/settings.json ~/.claude/statusline-wrapper.sh \
  ~/.claude/skills ~/.claude/agents ~/.claude/hooks
# ④ 새 잡 제거(S8 이후였다면) + 구 잡 재활성화
launchctl bootout gui/$(id -u)/com.user.chezmoi-sync 2>/dev/null
rm -f ~/Library/LaunchAgents/com.user.chezmoi-sync.plist
launchctl enable gui/$(id -u)/com.user.claude-sync
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.claude-sync.plist
```
검증: `readlink ~/.claude/settings.json` → `~/projects/claude-setting/settings.json` 등 6개; `claude --version`; `chezmoi managed | grep claude` → 무출력.

### nvim 롤백 — soak 기간
```bash
rsync -a --exclude '.git' $(chezmoi source-path)/external_nvim/ ~/projects/nvim-settings/   # 회수(선택)
chezmoi forget --force ~/.config/nvim
rm ~/.config/nvim && ln -s ~/projects/nvim-settings ~/.config/nvim                          # 즉시 원상
```
검증: `readlink ~/.config/nvim` → `~/projects/nvim-settings`; `nvim --headless '+q'` 무오류.

### soak 이후 롤백 (구 repo 처분 후)
스냅샷 기반 **실파일 복원** — 링크 구조는 원래와 다르지만 기능 원상:
```bash
chezmoi forget --force <해당 타깃>
rm <홈의 심링크>
cp -R "$B/claude/<이름>" ~/.claude/<이름>          # claude: 스냅샷에서
cp -R $(chezmoi source-path)/external_nvim ~/.config/nvim   # nvim: 소스 repo가 곧 최신 페이로드
```

### public 전환 후 기밀 발견 (v1 계승)
1. 즉시 `gh repo edit temeraire97/dotfiles --visibility private --accept-visibility-change-consequences`.
2. 시크릿이면 해당 자격증명 **즉시 회전**.
3. 히스토리 오염 시: `gh repo delete`로 원격 소각 → 로컬 `git filter-repo`(또는 orphan 스쿼시) 정화 → 재push → S7 게이트 전체 재실행 후 재공개.
4. 로컬 소스·홈 상태는 무손상 — 기능 롤백 불요.

### 완전 철수 (전면 포기)
```bash
# claude·nvim·zsh 롤백 수행 후 (soak 이후라면 페이로드 실파일화를 소스 삭제보다 먼저):
rm -rf ~/.local/share/chezmoi ~/.config/chezmoi   # 리터럴 경로 고정 [B2] — purge 프롬프트 리스크 회피
brew uninstall chezmoi
```
검증: soak 기간 철수 = `$B/links-claude.txt`/`links-home.txt`와 `ls -la` 대조 완전 일치. soak 이후 철수 = 실파일 배치라 링크 구조 상이 — 기능 검증(claude·nvim·zsh 기동)으로 대체.

### 부분 실패 격리 (v1 계승)
```bash
chezmoi state delete-bucket --bucket=scriptState   # run_once
chezmoi state delete-bucket --bucket=entryState    # run_onchange
```
후 재-apply.

---

## 7. 백업하지 않는 것과 사유

| 항목 | 결정 | 사유 |
|----|----|----|
| `~/.claude` 런타임 전부 (sessions/, projects/, history.jsonl, cache/, tasks/, teams/ 등) | 미백업·ignore | 클라이언트 기밀 또는 재생성 가능 — 백업 무가치, 유출 위험만 존재 |
| `~/.claude.json` | 미백업·ignore ([W7]) | 앱 소유 머신 상태 + 클라이언트 프로젝트 경로·파일명 포함 |
| `mcp.json`, `plugins/` 상태 | 미백업 | 토큰 포함 가능/머신 상태. 플러그인 복원은 settings.json 선언(run_once_50)으로 충분 |
| ★ nvim의 `.git`·`install.sh`·`README`·`LICENSE` | 미이식 | 히스토리는 soak 기간 구 repo가 보유(이후 처분 자유), install.sh 역할(플러그인 사전 설치)은 run_once_25가 계승(sync 아닌 lockfile 준수 restore), 문서류는 신 repo README 소관 |
| ★ `external_nvim/` 테스트·런타임 산출물 (tt.*, .tests, doc/tags, debug, .repro, foo.*, data) | git 제외 | 구 nvim-settings .gitignore 병합 — 2.3에 경로 한정 스코프로 등재 |
| `.chezmoiexternal.toml` | 미작성 | ★ nvim 흡수로 유일 후보 소멸 — 후보 0건 (KISS) |
| age 암호화 | 미도입 | 암호화 필요 파일 0건 실측. 시크릿은 `~/.zshrc.local`(미백업) 관례로 격리 |
| corepack | `corepack disable` 강제 | pnpm=brew 결정의 실체화 — 검사(WARN)가 아닌 강제 |
| 구 install.sh / sync.sh / com.user.claude-sync.plist | 미이식 | 후계(chezmoi apply / nightly-sync.sh / chezmoi-sync.plist.tmpl 17:00)로 대체. 구 plist 사본은 S2 스냅샷에 보존 |
| 파손 스킬 심링크 | 기록 후 폐기 | ★ S2에서 목록 기록(`removed-broken-links.txt`) 후 라이브 상태 자체를 청소 — 구 repo 커밋 의식(v1 P0-2)은 삭제 |
| settings.json·zshrc·run-node.sh·statusline-wrapper.sh·★external_nvim 페이로드 템플릿화 | 금지 | 앱 소유/앱 재작성 파일 충돌 또는 이미 포터블 — 재템플릿화는 퇴행 (2.6 금지 목록) |
| 구 repo 커밋 히스토리 승계 | 승계 안 함 | ★ 신규 repo는 "이 머신 첫 백업" — 과거 히스토리는 soak 기간 구 repo에서 열람, 필요 시 처분 전 아카이브(9장) |

---

## 8. 남은 승인점 — 1개

**S7의 public 전환**이 유일하다. private 생성·검증·최초 push까지는 런북이 진행하되, `gh repo edit --visibility public`은 배포 고지 원칙에 따라 **사용자 명시 승인 후에만** 실행한다. push 자체가 전부 수동(모델 b)이므로 "최초 push + 공개"라는 가장 민감한 두 행위가 자연스럽게 사람 손을 통과한다.

v1 "남은 결정 사항" 7건의 처분:

| v1 결정 | v2 처분 |
|----|----|
| 1. 산문 기밀 방어 수위 | **모델 b 채택으로 확정·소멸** — push 수동화+diff 리뷰 의무(3.2)가 강화안(push 보류+수동 승인)의 상위 호환 |
| 2. keybindings.json 선제 등재 | **기본안 확정·소멸** — 생기면 표면 감사([W12]) 알림 후 처리 |
| 3. nvim lazy-lock 처리 | **nvim 흡수로 소멸** — write-through로 야간 커밋에 자동 포함 |
| 4. public 전환 승인 | **유일 잔존** (본 장) |
| 5. claude-setting 아카이브 승인 | **소멸** — soak 후 자유 처분으로 격하(9장), 승인 불요 |
| 6. repo 이름 `dotfiles` 충돌 | **해소** — 구 로컬 dotfiles가 soak 후 삭제 대상이라 충돌 소멸 |
| 7. chezmoi 버전 pin | **운영 규칙 한 줄로 확정** — pin 없음, "업그레이드 후 S6 재실행 + add.secrets 재검증"(9장) |

---

## 9. soak 후 정리

**soak 통과 기준** (S8 개시 후 1주): `git -C $SRC log --oneline --since='7 days ago' | grep -c auto-sync` ≥ 발화일수; 심링크 파손·기밀 staged·gitleaks·커밋 실패 알림 0회; 수동 리뷰→push 1회 이상 성공(미push 알림 카운트가 push 후 리셋됨 확인); `chezmoi doctor`·`chezmoi status` 오염 없음.

**구 repo 2개 처분 옵션** (통과 후 자유 — 어떤 조합도 시스템에 무영향):

| repo | 옵션 | 비고 |
|----|----|----|
| `~/projects/claude-setting` | GitHub archive / 원격·로컬 삭제 | soak 중 `install.sh` 재실행 = 즉시 원상 수단이었음 — 처분 후 롤백은 S2 스냅샷 기반으로 전환(6장). 히스토리 보존 원하면 archive 권장 |
| `~/projects/nvim-settings` | 원격 archive·삭제 / 로컬 삭제 | 처분 후 롤백 수단은 소스 repo의 `external_nvim` 자체(최신 페이로드) |
| S2 스냅샷 `~/backups/pre-chezmoi-$TS` | **영구 보관 권장** | 유일한 비-git 앵커, 수 MB 수준 |

구 dotfiles repo(구, 로컬 전용)는 이미 2026-07-21 삭제됨 — 아카이브: `~/backups/pre-chezmoi-20260721-151630/old-dotfiles-repo.tar.gz`(25K).

**운영 규칙** (soak 이후 상시):
- chezmoi 업그레이드 후: S6의 dry-run 기밀 add 차단 4종 재실행 + add.secrets 발동 여부 재기록 ([I7][W6] — 버전 pin 없음).
- push 리듬: 매일 17:00 알림의 미push 카운트·최고령을 신호로 주 1회 이상 `chezmoi cd` → `git log -p origin/main..HEAD` diff 리뷰(최소 범위: external_claude/CLAUDE.md·skills·agents 통독) → `git push`.
- `~/.claude` 신규 항목 알림([W12]) 시 2지선다: 설정이면 페이로드 승격+symlink tmpl 추가, 런타임이면 `.chezmoiignore` 등재+`claude-surface.txt` baseline 갱신.

### 알려진 함정: StartCalendarInterval 타임존 시프트 (2026-07-21 실측)

부팅 시 UserEventAgent(Aqua)가 `/etc/localtime` 확정 **이전**에 기동하면, 그 세션 동안
캘린더 잡의 발화 시각이 옛 타임존으로 계산된다. 실측: 부팅 08:37 → UserEventAgent 08:42
→ localtime(Asia/Seoul) 확정 08:46 → `{Hour:17}` 잡이 `익일 09:00 KST`(= 17:00 PDT)로 등록,
17:00에 미발화.

- `launchctl print`는 **원본 descriptor만** 보여주고 계산된 다음 발화 시각을 보여주지 않음 → 정상으로 보임
- 진단: `/usr/bin/log show --last 12h --predicate 'process == "UserEventAgent"' | grep -i StartCalendarInterval`
  (⚠ zsh에서 `log`는 빌트인 — **반드시 절대경로** `/usr/bin/log`)
- 등록 로그에 나오는 절대 시각이 의도한 로컬 시각과 다르면 이 버그
- 복구: UserEventAgent 재기동 시 자동 정정(SIP로 kickstart 불가, 자연 재기동 대기 또는 재로그인).
  잡 재등록은 `launchctl bootout gui/$(id -u)/com.user.chezmoi-sync && chezmoi apply`
- 근본 대책(미적용, 검토됨): `StartInterval` + 스크립트 내 `date` 기반 하루 1회 가드(anacron 패턴).
  StartInterval은 launchd 코어의 상대 타이머라 타임존 연산이 없어 이 버그에 구조적 면역.
- 반증된 통설: "Hour를 `<string>`으로 쓰면 미발화" → 실제로는 와일드카드 처리되어 매분 폭주 발화
