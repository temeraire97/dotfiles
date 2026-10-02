#!/usr/bin/env bash
# pr-merge.sh의 체크 판정을 가짜 gh와 가짜 git으로 검사한다. 실제 저장소나 네트워크를 건드리지 않는다.
# 실행: bash ~/.claude-work/skills/git-master/scripts/test-pr-merge.sh
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"

# 가짜 gh: `pr view ... --json <필드> -q <jq>`는 FIXTURE에 jq를 적용해 돌려준다. merge와 comment는 기록만 한다.
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view")
    query=""
    while [ $# -gt 0 ]; do
      case "$1" in -q) query="$2"; shift 2 ;; *) shift ;; esac
    done
    jq -r "$query" "$FIXTURE" ;;
  "pr merge")   echo "MERGE $*" >> "$CALLS" ;;
  "pr comment") echo "COMMENT $*" >> "$CALLS" ;;
  *) echo "unexpected gh call: $*" >&2; exit 1 ;;
esac
EOF
# 가짜 git: fetch, cat-file, merge-base 모두 성공(브랜치가 base를 포함한다고 본다).
cat > "$WORK/bin/git" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$WORK/bin/gh" "$WORK/bin/git"

# run <statusCheckRollup JSON 배열> <files JSON 배열> [pr-merge.sh 추가 인자...]: "merged" 또는 "aborted"를 찍는다.
run() {
  local rollup="$1" files="$2"; shift 2
  printf '{"headRefOid":"abc123","baseRefName":"main","state":"OPEN","statusCheckRollup":%s,"files":%s}' \
    "$rollup" "$files" > "$WORK/fixture.json"
  : > "$WORK/calls"
  if PATH="$WORK/bin:$PATH" FIXTURE="$WORK/fixture.json" CALLS="$WORK/calls" PR_MERGE_RECHECK_SECONDS=0 \
      bash "$HERE/pr-merge.sh" 1 "$@" > "$WORK/stdout" 2> "$WORK/stderr" && grep -q '^MERGE ' "$WORK/calls"; then
    if grep -q '^COMMENT ' "$WORK/calls"; then echo "merged+comment"; else echo "merged"; fi
  else
    echo "aborted"
  fi
}

# 체크 한 건. actions <이름> <status> <conclusion>, external <이름> <conclusion>, status <context> <state>
actions()  { printf '{"__typename":"CheckRun","workflowName":"CI","name":"%s","status":"%s","conclusion":"%s","startedAt":"2026-01-01T00:00:00Z"}' "$1" "$2" "$3"; }
external() { printf '{"__typename":"CheckRun","workflowName":"","name":"%s","status":"COMPLETED","conclusion":"%s","startedAt":"2026-01-01T00:00:00Z"}' "$1" "$2"; }
status()   { printf '{"__typename":"StatusContext","context":"%s","state":"%s","createdAt":"2026-01-01T00:00:00Z"}' "$1" "$2"; }
arr() { local IFS=,; echo "[$*]"; }
files() { local out="" f; for f in "$@"; do out="${out:+$out,}{\"path\":\"$f\"}"; done; echo "[$out]"; }

fail=0
expect() { # <설명> <기대> <실제>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: 기대 $2, 실제 $3"; sed 's/^/       /' "$WORK/stderr"; fail=1; fi
}

CODE=$(files src/app.py)
DOCS=$(files README.md docs/guide/setup.txt notes/a.md)

expect "Actions 체크 success와 skipped"            merged         "$(run "$(arr "$(actions Lint COMPLETED SUCCESS)" "$(actions gate COMPLETED SKIPPED)")" "$CODE")"
expect "Actions 체크 실패"                         aborted        "$(run "$(arr "$(actions Lint COMPLETED FAILURE)" "$(actions Build COMPLETED SUCCESS)")" "$CODE")"
expect "Actions 체크 진행 중"                      aborted        "$(run "$(arr "$(actions Lint IN_PROGRESS "")" "$(actions Build COMPLETED SUCCESS)")" "$CODE")"
expect "전부 skipped(draft 실행)"                  aborted        "$(run "$(arr "$(actions Lint COMPLETED SKIPPED)" "$(actions Build COMPLETED SKIPPED)")" "$CODE")"
expect "외부 체크만 success"                       aborted        "$(run "$(arr "$(external Vercel SUCCESS)" "$(status deploy/preview SUCCESS)")" "$CODE")"
expect "외부 success와 Actions success"            merged         "$(run "$(arr "$(external Vercel SUCCESS)" "$(actions Lint COMPLETED SUCCESS)")" "$CODE")"
expect "외부 체크 실패"                            aborted        "$(run "$(arr "$(status deploy/preview FAILURE)" "$(actions Lint COMPLETED SUCCESS)")" "$CODE")"
expect "체크 없음, 문서만 변경"                    merged         "$(run "[]" "$DOCS")"
expect "체크 없음, 코드 변경"                      aborted        "$(run "[]" "$CODE")"
expect "체크 없음, 문서와 코드 섞임"               aborted        "$(run "[]" "$(files README.md .github/workflows/ci.yml)")"
expect "체크 없음, 코드 변경, 사유를 주고 승인"    merged+comment "$(run "[]" "$CODE" --allow-failed-checks "테스트 사유")"
expect "전부 skipped, 사유를 주고 승인"            merged+comment "$(run "$(arr "$(actions Lint COMPLETED SKIPPED)")" "$CODE" --allow-failed-checks "테스트 사유")"
exit $fail
