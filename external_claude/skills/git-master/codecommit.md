# CodeCommit Workflow

프로젝트가 AWS CodeCommit 기반일 때만 이 파일을 따른다. GitHub 프로젝트는 `SKILL.md` 4절을 쓴다.

커밋 컨벤션(SKILL.md 1절), fingerprint 절대 금지(2절), Branch Discipline(3절)은 CodeCommit에서도 동일하게 적용된다. 이 파일은 PR 생성과 merge의 CodeCommit 고유 절차만 다룬다.

---

## 비공개 값 (CRITICAL)

실제 값(`$CC_PROFILE`, `$CC_REPO`, `$CC_IAM_USER`)은 비공개 로컬 파일 `git-master.local.md`(같은 폴더)에 정의한다. 이 파일은 `*.local.md` 패턴으로 gitignore/백업에서 제외된다. 공개되는 곳에는 변수명만 노출한다.

파일이 없으면 `git-master.local.md.example`을 복사해 값을 채운다.

CodeCommit 관련 모든 `aws` CLI 명령은 반드시 `--profile $CC_PROFILE`를 쓴다:

```bash
# 올바른 사용
aws codecommit create-pull-request --profile $CC_PROFILE ...
aws codecommit get-pull-request --profile $CC_PROFILE ...
aws codecommit merge-pull-request-by-three-way --profile $CC_PROFILE ...

# 금지
aws codecommit ... --profile <other-account>   # 접근 불가
aws codecommit ...                              # 기본 프로파일 금지
```

이유: CodeCommit 저장소는 `$CC_PROFILE` 프로파일의 AWS 계정에만 존재한다.

---

## PR 생성 (CRITICAL)

main에 merge 전 반드시 PR을 먼저 생성한다. PR 없이 `git merge`로 main에 직접 병합하지 않는다.

```bash
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

워크플로우:
1. 작업 완료 후 `git push`
2. PR 생성 (위 명령)
3. PR URL 확인: `aws codecommit get-pull-request --profile $CC_PROFILE --pull-request-id <id>`
4. 리뷰 후 CodeCommit 콘솔 또는 CLI로 merge

---

## Merge (기본: CLI 3-way)

기본은 CLI 3-way merge다.

```bash
aws codecommit merge-pull-request-by-three-way \
  --profile $CC_PROFILE \
  --pull-request-id <id> \
  --repository-name $CC_REPO
```

CLI merge 시 머지 커밋 author는 AWS IAM 사용자(`$CC_IAM_USER`)로 남으며, 이는 repo의 기존 관행과 일치한다.

---

## Merge (선택: Local Merge with Custom Author)

머지 커밋 author를 AWS IAM(`$CC_IAM_USER`)이 아닌 개인 계정으로 남기고 싶을 때만 쓴다.

```bash
# 1. PR 생성 (기록용, 위와 동일)
aws codecommit create-pull-request \
  --profile $CC_PROFILE \
  --title "feat(scope): 변경 요약" \
  --description "..." \
  --targets repositoryName=$CC_REPO,sourceReference=<branch-name>,destinationReference=main

# 2. main에서 로컬 3-way merge
git checkout main
git merge <branch-name> --no-ff -m "Merge pull request #<PR-ID> from <branch-name>

<PR 제목/설명>"

# 3. Author를 git config 신원으로 amend (하드코딩 금지)
AUTHOR="$(git config user.name) <$(git config user.email)>"
git commit --amend --author="$AUTHOR" --no-edit

# 4. Remote에 push (PR은 자동 CLOSED 됨)
git push origin main
```

author 신원은 하드코딩하지 않고 git config에서 자동 참조한다. CodeCommit은 AWS라 `gh`는 무관하다. git config가 비어있는 예외 상황에서만 사람이 직접 값을 넣는다.

언제 사용:
- 머지 커밋 author를 AWS IAM이 아닌 개인 계정으로 남기고 싶을 때
- PR은 기록용으로 남기고 로컬에서 merge할 때

주의:
- PR 생성 후 로컬 merge → push하면 PR은 자동 CLOSED가 된다
- Force push가 필요할 수 있다 (`--force-with-lease` 사용)
