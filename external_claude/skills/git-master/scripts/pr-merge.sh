#!/usr/bin/env bash
# git-master: PR merge는 이 스크립트로만 한다.
# 1) 브랜치가 origin/main을 포함하는지(조상 검사) 확인. 뒤처졌으면 중단하고 rebase 안내.
# 2) PR 체크가 전부 SUCCESS인지 확인. 실패나 미완료면 중단.
# 3) gh pr merge --merge --match-head-commit <head> 로 검사한 커밋만 merge.
# 이 조건이 지켜지면 merge commit 트리 = PR CI가 검사한 트리이므로 main push CI를 생략해도 검증 공백이 없다.
set -euo pipefail
usage() { echo "usage: pr-merge.sh <PR번호> [-R owner/repo] [--allow-failed-checks '<사유>']" >&2; exit 2; }
[ $# -ge 1 ] || usage
PR="$1"; shift
REPO_ARGS=(); ALLOW_FAILED=""
while [ $# -gt 0 ]; do
  case "$1" in
    -R) REPO_ARGS=(-R "$2"); shift 2 ;;
    --allow-failed-checks) ALLOW_FAILED="$2"; shift 2 ;;
    *) usage ;;
  esac
done

read -r HEAD BASE STATE < <(gh pr view "$PR" "${REPO_ARGS[@]}" --json headRefOid,baseRefName,state -q '"\(.headRefOid) \(.baseRefName) \(.state)"')
[ "$STATE" = "OPEN" ] || { echo "PR #$PR 상태가 $STATE. 중단." >&2; exit 1; }

git fetch -q origin "$BASE"
if ! git merge-base --is-ancestor "origin/$BASE" "$HEAD" 2>/dev/null; then
  echo "PR #$PR 브랜치가 origin/$BASE보다 뒤처져 있다. main CI를 생략하려면 트리가 같아야 한다." >&2
  echo "브랜치에서: git fetch origin && git rebase origin/$BASE && git push --force-with-lease  (PR CI 통과 후 다시 실행)" >&2
  exit 1
fi

CHECKS=$(gh pr checks "$PR" "${REPO_ARGS[@]}" --json name,state -q '.[] | "\(.state) \(.name)"' 2>/dev/null || true)
if [ -z "$CHECKS" ]; then
  echo "체크 없음(문서 전용 paths-ignore 등). 계속." >&2
else
  BAD=$(echo "$CHECKS" | grep -vE '^(SUCCESS|SKIPPED|NEUTRAL) ' || true)
  if [ -n "$BAD" ]; then
    echo "통과하지 않은 체크:" >&2; echo "$BAD" >&2
    if [ -z "$ALLOW_FAILED" ]; then
      echo "중단. 사용자 승인이 있으면 --allow-failed-checks '<사유>' 로 재실행(사유는 PR 코멘트로 남는다)." >&2
      exit 1
    fi
    gh pr comment "$PR" "${REPO_ARGS[@]}" --body "체크 실패 상태에서 merge. 사유: $ALLOW_FAILED" >/dev/null
  fi
fi

gh pr merge "$PR" "${REPO_ARGS[@]}" --merge --match-head-commit "$HEAD"
echo "merged PR #$PR at $HEAD (tree == PR CI tree)"
