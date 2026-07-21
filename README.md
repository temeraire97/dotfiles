# dotfiles

chezmoi 기반 머신 설정 백업 — zsh · Homebrew · Claude Code · Neovim.

## 새 머신 복원

사전 요구: Homebrew, git, GitHub SSH key (repo가 private).

```bash
brew install chezmoi
chezmoi init --apply git@github.com:temeraire97/dotfiles.git
```

apply 시 run 스크립트가 자동 수행:

- `brew bundle` — Brewfile의 formula/cask 일괄 설치 (Brewfile 변경 시마다 재실행)
- fnm으로 Node LTS 설치 + `corepack disable` (pnpm은 brew 설치본 사용 정책)
- nvim headless `Lazy! restore` — `lazy-lock.json` 기준 플러그인 복원
- 소스 repo에 `core.hooksPath=githooks` 설정 (pre-commit 게이트 활성화)
- Claude Code marketplace·플러그인 복원 (`settings.json`의 `extraKnownMarketplaces`/`enabledPlugins` 기준)

## 구조

```
.
├── Brewfile                          # brew bundle dump 캡처
├── dot_zshrc / dot_zshenv            # zsh 설정 (실파일 관리)
├── external_claude/                  # ~/.claude 페이로드 — CLAUDE.md, settings.json,
│                                     #   statusline-wrapper.sh, skills/, agents/, hooks/
├── external_nvim/                    # ~/.config/nvim 페이로드 — init.lua, lua/, lazy-lock.json 등
├── private_dot_claude/               # ~/.claude 심링크 6개 (symlink_*.tmpl → external_claude/)
├── dot_config/symlink_nvim.tmpl      # ~/.config/nvim → external_nvim/
├── dot_local/bin/symlink_node.tmpl   # ~/.local/bin/node → fnm default
├── .chezmoiscripts/                  # 복원 자동화 (run_once / run_onchange)
├── githooks/pre-commit               # 시크릿 3게이트
├── scripts/nightly-sync.sh           # 야간 자동 커밋 스크립트
└── scripts/claude-surface.txt        # ~/.claude 표면 감사 baseline
```

`external_` 디렉터리는 chezmoi가 홈에 배포하지 않는 페이로드이며(`.chezmoiignore`), 홈에는 이곳을 가리키는 심링크만 배포된다. 앱(Claude CLI, lazy.nvim)이 재작성하는 파일이 심링크를 관통해 소스 working tree에 바로 쓰이므로 drift가 0이고, `chezmoi apply`가 앱의 변경을 되돌릴 수 없다.

## 동기화 모델

- **로컬 커밋 자동**: launchd가 매일 17:00에 `scripts/nightly-sync.sh` 실행 — 심링크 무결성 검사 → 표면 감사 → `re-add` → gitleaks 스캔 → 로컬 커밋까지만. (launchd 등록은 아직 미활성)
- **push는 수동**: `chezmoi cd`로 소스 repo에 진입한 뒤 `git log -p origin/main..HEAD`로 diff 리뷰 → `git push`. (서브셸 없이 한 줄로 하려면 `git -C "$(chezmoi source-path)" log -p origin/main..HEAD`)

push를 수동으로 두는 이유: gitleaks는 시크릿만 잡고, 클라이언트명·경로 같은 산문 기밀은 못 잡는다. 원격에 닿는 모든 바이트가 사람의 diff 리뷰를 거치게 하는 사전 게이트다.

## 시크릿 정책

repo에 시크릿 0. pre-commit이 3게이트로 강제한다:

1. gitleaks staged 스캔 (미설치·오류 시에도 커밋 차단, fail-closed)
2. 구조 파일(`*.tmpl`, 스크립트)의 `/Users/` 절대경로 하드코딩 차단
3. 기밀 경로 패턴(`memory/`, `*.local.md`, `history.jsonl` 등) staged 차단

머신별·비밀 설정은 `~/.zshrc.local` / `~/.zshenv.local`에 두면 된다 — 의도적으로 백업하지 않는다.

## 주의

`chezmoi apply` 프롬프트에 `~/.claude` 하위 항목의 내용 diff가 뜨면 심링크 파손 신호다. **승인하지 말고** 심링크 상태부터 조사할 것 (야간 스크립트가 fallback 캡처 후 알림을 보낸다).
