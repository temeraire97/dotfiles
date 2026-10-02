#!/usr/bin/env bash
# git-master: PR merge는 이 스크립트로만 한다.
# 1) 브랜치가 origin/main을 포함하는지(조상 검사) 확인. 뒤처졌으면 중단하고 rebase 안내.
# 2) PR 체크 확인. 조회가 실패하면 중단. 체크가 있으면 전부 SUCCESS, SKIPPED, NEUTRAL 중 하나이고
#    그중 GitHub Actions 체크의 SUCCESS가 1개 이상이어야 한다(전부 SKIPPED거나 외부 체크만 통과했으면
#    CI가 검증한 적이 없으므로 중단). 실패나 미완료면 중단.
#    체크가 하나도 없으면 등록 지연일 수 있어 한 번 더 조회한다. 그때도 없으면 변경 파일을 본다.
#    문서(*.md, docs/**)만 바뀐 PR이면 "체크 없음"으로 통과하고, 그 밖의 파일이 있으면 중단한다.
# 3) gh pr merge --merge --match-head-commit <head> 로 검사한 커밋만 merge.
# 이 조건이 지켜지면 merge commit 트리 = PR CI가 검사한 트리이므로 main push의 게이트 잡이 검증을 건너뛴다(SKILL.md 4.3).
set -euo pipefail
# macOS 기본 bash 3.2 호환 두 가지:
# - 빈 배열을 set -u 아래에서 "${arr[@]}"로 펼치면 unbound variable(4.4 미만). ${arr[@]+"${arr[@]}"}로 쓴다.
# - UTF-8 로케일에서 $VAR 바로 뒤에 한글이 오면 첫 바이트가 변수명에 붙는다. ${VAR}로 경계를 준다.
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

read -r HEAD BASE STATE < <(gh pr view "$PR" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} --json headRefOid,baseRefName,state -q '"\(.headRefOid) \(.baseRefName) \(.state)"')
[ "$STATE" = "OPEN" ] || { echo "PR #$PR 상태가 $STATE. 중단." >&2; exit 1; }

# PR head 커밋도 함께 받아 온다. 봇이 만든 브랜치(Release PR 등)는 로컬에 커밋이 없어서, base만 fetch하면
# 조상 검사가 "객체 없음" 오류로 실패하고 뒤처진 것으로 오판한다.
git fetch -q origin "$BASE" "pull/$PR/head"
if ! git cat-file -e "${HEAD}^{commit}" 2>/dev/null; then
  echo "PR #$PR head 커밋(${HEAD})을 로컬로 가져오지 못했다. 조상 검사를 할 수 없어 중단." >&2
  exit 1
fi
# merge-base --is-ancestor 종료 코드: 0 조상, 1 조상 아님, 그 외는 오류. 오류를 뒤처짐으로 읽지 않는다.
ANCESTOR_RC=0
git merge-base --is-ancestor "origin/$BASE" "$HEAD" 2>/dev/null || ANCESTOR_RC=$?
if [ "$ANCESTOR_RC" -eq 1 ]; then
  echo "PR #$PR 브랜치가 origin/${BASE}보다 뒤처져 있다. main CI를 생략하려면 트리가 같아야 한다." >&2
  echo "브랜치에서: git fetch origin && git rebase origin/$BASE && git push --force-with-lease  (PR CI 통과 후 다시 실행)" >&2
  exit 1
elif [ "$ANCESTOR_RC" -ne 0 ]; then
  echo "조상 검사가 오류로 끝났다(git merge-base 종료 코드 ${ANCESTOR_RC}). 중단." >&2
  exit 1
fi

# 체크 상태는 statusCheckRollup으로 조회한다. gh pr checks는 체크가 없을 때도 0이 아닌 코드로 끝나서
# "체크 없음"과 "조회 실패"를 구분할 수 없다. 같은 워크플로의 같은 이름 체크가 한 커밋에 여러 번 돌았으면
# (draft 해제, 재오픈 등) 가장 늦게 시작한 것만 본다. gh pr checks와 같은 기준이다.
# 출력은 한 줄에 "<STATE> <종류> <이름>". 끝나지 않은 체크는 PENDING으로 적는다.
# 종류는 워크플로에서 나온 체크면 actions, 그 밖(Vercel 같은 외부 앱, commit status)이면 external이다.
CHECKS_JQ='[.statusCheckRollup[] | {
    key: ((.workflowName // "") + "/" + (.name // .context // "?")),
    name: (.name // .context // "?"),
    kind: (if (.workflowName // "") != "" then "actions" else "external" end),
    at: (.startedAt // .createdAt // ""),
    state: (if .__typename == "StatusContext" then (.state // "PENDING")
            elif (.status // "") != "COMPLETED" then "PENDING"
            elif (.conclusion // "") == "" then "PENDING"
            else .conclusion end)
  }] | group_by(.key) | map(max_by(.at)) | .[] | "\(.state) \(.kind) \(.name)"'
query_checks() {
  gh pr view "$PR" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} --json statusCheckRollup -q "$CHECKS_JQ"
}
# 빈 결과일 때 다시 조회하기 전에 기다리는 시간(초). PR 생성이나 push 직후에는 체크가 아직 등록되지 않는다.
RECHECK_SECONDS="${PR_MERGE_RECHECK_SECONDS:-15}"

if ! CHECKS=$(query_checks); then
  echo "체크 조회 실패(gh 인증, 네트워크 등). 검증 여부를 알 수 없어 중단." >&2
  exit 1
fi
if [ -z "$CHECKS" ]; then
  echo "체크가 아직 없다. 등록 지연일 수 있어 ${RECHECK_SECONDS}초 뒤 다시 조회한다." >&2
  sleep "$RECHECK_SECONDS"
  if ! CHECKS=$(query_checks); then
    echo "체크 재조회 실패(gh 인증, 네트워크 등). 검증 여부를 알 수 없어 중단." >&2
    exit 1
  fi
fi

PROBLEM=""
if [ -z "$CHECKS" ]; then
  # 체크가 없어도 되는 경우는 워크플로의 paths-ignore에 걸리는 문서 전용 변경뿐이다. 그 밖의 파일이 바뀌었는데
  # 체크가 없으면 등록이 늦었거나 워크플로가 돌지 않은 것이므로 통과시키지 않는다.
  if ! FILES=$(gh pr view "$PR" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} --json files -q '.files[].path'); then
    echo "변경 파일 조회 실패(gh 인증, 네트워크 등). 체크가 없어도 되는 PR인지 알 수 없어 중단." >&2
    exit 1
  fi
  NON_DOC=""
  while IFS= read -r f; do
    case "$f" in
      ""|*.md|docs/*) ;;
      *) NON_DOC="${NON_DOC}${f}"$'\n' ;;
    esac
  done <<EOF_FILES
$FILES
EOF_FILES
  if [ -z "$NON_DOC" ]; then
    echo "체크 없음(문서 전용 변경). 계속." >&2
  else
    echo "체크가 하나도 없는데 문서가 아닌 파일이 바뀌었다(등록 지연이거나 워크플로가 돌지 않음):" >&2
    printf '%s' "$NON_DOC" | head -10 >&2
    PROBLEM="문서가 아닌 변경인데 체크가 없음"
  fi
else
  BAD=$(echo "$CHECKS" | grep -vE '^(SUCCESS|SKIPPED|NEUTRAL) ' || true)
  SUCCESS_COUNT=$(echo "$CHECKS" | grep -c '^SUCCESS actions ' || true)
  if [ -n "$BAD" ]; then
    echo "통과하지 않은 체크:" >&2; echo "$BAD" >&2
    PROBLEM="통과하지 않은 체크가 있음"
  elif [ "$SUCCESS_COUNT" -eq 0 ]; then
    echo "GitHub Actions 체크 중 SUCCESS가 하나도 없다(전부 SKIPPED거나 외부 체크만 통과). draft 상태에서 돈 실행이면 검증된 적이 없다:" >&2
    echo "$CHECKS" >&2
    PROBLEM="GitHub Actions 체크의 SUCCESS가 없음"
  fi
fi
if [ -n "$PROBLEM" ]; then
  if [ -z "$ALLOW_FAILED" ]; then
    echo "중단. 사용자 승인이 있으면 --allow-failed-checks '<사유>' 로 재실행(사유는 PR 코멘트로 남는다)." >&2
    exit 1
  fi
  gh pr comment "$PR" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} --body "체크 미통과 상태에서 merge(${PROBLEM}). 사유: $ALLOW_FAILED" >/dev/null
fi

gh pr merge "$PR" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} --merge --match-head-commit "$HEAD"
echo "merged PR #$PR at $HEAD (tree == PR CI tree)"
