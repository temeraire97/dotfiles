# My Git Rules

Git 커밋, 브랜치, PR 관련 사용자 커스텀 규칙입니다.

---

## Commit Message Convention

커밋 메시지 생성 시:
1. `git status`와 `git diff`로 변경사항 확인
2. **한국어**로 Conventional Commits 형식 작성
3. 커밋 실행하지 말고 메시지만 제안 (사용자가 직접 커밋)

**형식:** `type(scope): message` - scope는 **필수**, 생략 금지

---

## ⛔ FINGERPRINT 절대 금지 (ABSOLUTE RULE)

**절대 절대 무조건 무슨 일이 있어도 다음을 추가하지 말 것:**

- `Co-Authored-By: Claude`
- `Co-Authored-By: Claude Code`
- `Co-Authored-By: Claude Opus`
- `Generated with Claude Code`
- `🤖 Generated with Claude`
- 기타 AI/Claude 관련 fingerprint 일체

**이 규칙은 협상 불가. 예외 없음. 어떤 상황에서도 위반 금지.**

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`, `ci`, `build`

---

## Git Workflow

### 저장소 타입별 워크플로우

| 저장소 | PR 생성 | Merge 방식 | CLI |
|--------|---------|------------|-----|
| **GitHub** | `gh pr create` | **3-way merge (`--merge`)** | `gh` |
| **CodeCommit** | `aws codecommit` | **CLI 3-way merge** (`merge-pull-request-by-three-way`) | `aws` |

---

### GitHub 프로젝트

**GitHub은 로컬 merge가 필요 없음** - 웹 UI 또는 CLI에서 직접 merge:

```bash
# 1. PR 생성
gh pr create --title "feat(scope): 변경 요약" --body "..." --base main

# 2. PR merge (3-way merge 기본)
gh pr merge <PR-NUMBER> --merge

# 3. 로컬 동기화 & 브랜치 삭제
git checkout main && git pull
git branch -d <branch-name>
```

---

### CodeCommit 프로젝트

**CodeCommit은 `aws codecommit` CLI로 PR 생성·merge** 한다:
- `gh` CLI 대신 `aws codecommit` CLI 사용
- Merge는 `aws codecommit merge-pull-request-by-three-way` (CLI 3-way merge) 사용
- CLI merge 시 머지 커밋 author는 AWS IAM 사용자(`$CC_IAM_USER`)로 남으며, 이는 repo의 기존 관행과 일치한다
- 머지 커밋 author를 개인 계정으로 남기고 싶을 때만 아래 "Local Merge with Custom Author" 옵션을 선택적으로 사용

### ⚠️ CodeCommit AWS Profile (CRITICAL)

> 실제 값(`$CC_PROFILE`, `$CC_REPO`, `$CC_IAM_USER`)은 비공개 로컬 파일 `git-master.local.md`(같은 폴더, gitignore·백업 제외)에 정의되어 있다. 공개 저장소에는 변수명만 노출된다.

**CodeCommit 관련 `aws` CLI 명령은 반드시 `--profile $CC_PROFILE` 사용:**

```bash
# ✅ 올바른 사용
aws codecommit create-pull-request --profile $CC_PROFILE ...
aws codecommit get-pull-request --profile $CC_PROFILE ...
aws codecommit merge-pull-request-by-three-way --profile $CC_PROFILE ...

# ❌ 절대 금지 (다른 프로파일 사용)
aws codecommit ... --profile <other-account>    # 접근 불가
aws codecommit ...                  # 기본 프로파일 사용 금지
```

**이유:** CodeCommit 저장소는 `$CC_PROFILE` 프로파일의 AWS 계정에만 존재함

**GitHub Flow 사용:**
1. `main`은 항상 배포 가능 상태
2. main에서 설명적인 이름의 브랜치 생성 (prefix 없이)
3. 정기적으로 push
4. PR → Review → Merge to main → Deploy

**브랜치 네이밍**: 작업 내용을 설명하는 이름 사용

```
# Good examples
user-content-cache-key
add-jenkins-pipeline
fix-login-error

# Don't use (Git Flow style)
feature/xxx, fix/xxx, chore/xxx
```

---

## Branch Discipline (CRITICAL)

**작업 시작 전 반드시 현재 브랜치명 확인할 것.**

현재 브랜치명과 **관련 없는 작업** 요청 시:
1. **진행 거부** - 새 브랜치 생성 전까지
2. 경고: "이 작업은 `<current-branch>` 브랜치와 맞지 않습니다. 새 브랜치를 먼저 만드세요."
3. 제안: `git checkout main && git checkout -b <appropriate-name>`

**이것은 협상 불가.** 관련 없는 작업을 한 브랜치에 섞으면:
- Git 히스토리 오염
- PR 리뷰 불가능
- Merge conflict 발생
- 정리하느라 시간 낭비

**사용자가 게을러지지 않도록 브랜치 규율 강제할 것.**

---

### 예외: 간단 수정은 main 직접 (Simple Fix Fast-Path)

**Branch Discipline의 예외로 인정되는 수정 작업은 두 가지 경로가 있다.** 판단이 애매하면 보수적으로 브랜치를 사용한다.

#### 경로 1: 자동 eligible (질문 없이 main 직행)

**다음을 모두 만족하는 간단한 수정:**
- 변경량: 약 1-2줄 이내
- 위험도: 명백하고 저위험 (오타 수정, 한 줄 버그 수정, 빌드/설정 스크립트 경미한 tweak, 주석·문서 소소한 수정)
- 영향: 단일 파일, 명백한 의도

**동작:** 브랜치/PR 생략, `main`에서 직접 수정 → 커밋 → push

#### 경로 2: 사용자 판단 (fix 타입 작업)

**`fix` 타입이지만 trivial하지 않은 경우** (로직·동작 변경, 범위 불명확 등)는 사용자에게 먼저 질문:

> "fix 작업입니다. `main`에서 바로 커밋할까요, 아니면 브랜치+PR로 진행할까요?"

- 사용자가 **main 직행** 선택 → 브랜치 생성 없이 `main`에서 수정 → 커밋 → push (PR 생략)
- 사용자가 **브랜치** 선택 또는 무응답 → 기존 Branch Discipline 대로 브랜치+PR

#### 반드시 브랜치 사용 (예외 대상 아님)

- 다중 파일 변경 (3파일 이상)
- 로직·동작 변경 (범위 불명확한 경우)
- 마이그레이션, 대규모 리팩토링
- 설계 결정 필요
- **feat/refactor 등 비-fix 작업** — 항상 Branch Discipline 준수
- **판단 불명확 시 → 무조건 브랜치 사용 (보수적 원칙)**

#### 공통 규칙

- 한국어 Conventional Commits 형식: `type(scope): message`
- scope 필수 (생략 금지)
- AI/Claude fingerprint 절대 금지 (Co-Authored-By 등)
- Main 직접 push는 CI/배포 파이프라인을 트리거할 수 있음 → 배포 영향이 있으면 **push 전에 사용자에게 고지** 필수

---

## Testing Multiple Branches in Staging

**Throw-Away Integration Branch** 패턴으로 여러 feature 브랜치를 staging에서 함께 테스트:

```bash
# 1. main에서 임시 staging 브랜치 생성
git checkout main
git checkout -b staging-qa

# 2. 모든 feature 브랜치 병합 (octopus merge)
git merge feature-a feature-b feature-c feature-d

# 3. staging 환경에 배포 & 테스트

# 4. 테스트 후 삭제 (일회용)
git branch -D staging-qa

# 5. 각 feature를 개별 PR로 main에 병합
```

**핵심 원칙:**
- Staging 브랜치는 **일회용** - 테스트 후 삭제
- Feature 브랜치는 그대로 유지
- QA 통과 후, 각 feature를 **개별 PR**로 main에 병합
- 하나가 실패하면, 해당 feature 제외하고 staging 브랜치 재생성

---

## CodeCommit PR 생성 (CRITICAL)

**main에 merge 전 반드시 PR을 먼저 생성할 것.**

```bash
# PR 생성 (CodeCommit)
aws codecommit create-pull-request \
  --profile $CC_PROFILE \
  --title "feat(scope): 변경 요약" \
  --description "## Summary
- 변경사항 1
- 변경사항 2

## Test plan
- [x] 테스트 통과" \
  --targets repositoryName=$CC_REPO,sourceReference=<branch-name>,destinationReference=main
```

**워크플로우:**
1. 작업 완료 후 `git push`
2. **PR 생성** (위 명령어)
3. PR URL 확인: `aws codecommit get-pull-request --profile $CC_PROFILE --pull-request-id <id>`
4. 리뷰 후 **CodeCommit 콘솔에서 merge** 또는 CLI로 merge

```bash
# PR merge (CodeCommit)
aws codecommit merge-pull-request-by-three-way \
  --profile $CC_PROFILE \
  --pull-request-id <id> \
  --repository-name $CC_REPO
```

**직접 merge 금지** - PR 없이 `git merge`로 main에 직접 병합하지 말 것

---

## Local Merge with Custom Author (CodeCommit 선택 옵션)

기본은 CLI merge다. **머지 커밋 author를 AWS IAM(`$CC_IAM_USER`)이 아닌 개인 계정으로 남기고 싶을 때만** 아래 로컬 merge를 사용한다:

```bash
# 1. PR 생성 (기록용 - 위와 동일)
aws codecommit create-pull-request \
  --profile $CC_PROFILE \
  --title "feat(scope): 변경 요약" \
  --description "..." \
  --targets repositoryName=$CC_REPO,sourceReference=<branch-name>,destinationReference=main

# 2. main에서 로컬 3-way merge
git checkout main
git merge <branch-name> --no-ff -m "Merge pull request #<PR-ID> from <branch-name>

<PR 제목/설명>"

# 3. Author 변경 (amend)
git commit --amend --author="AaronYun <hyensooyoon@gmail.com>" --no-edit

# 4. Remote에 push (PR은 자동 CLOSED 됨)
git push origin main
```

**언제 사용:**
- Merge 커밋 author를 AWS IAM이 아닌 개인 계정으로 남기고 싶을 때
- PR은 기록용으로 남기고 로컬에서 merge할 때

**주의:**
- PR 생성 후 로컬 merge → push하면 PR은 자동으로 CLOSED 상태가 됨
- Force push가 필요할 수 있음 (`--force-with-lease` 사용)
