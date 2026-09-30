#!/usr/bin/env node
// ~/.claude/hooks/git-master-guard.js
// PreToolUse hook (matcher: Bash): DENY a commit/PR command that carries an
// AI/Claude fingerprint. This is the deterministic backstop for the git-master
// "fingerprint 절대 금지" rule — a skill can be skipped, a session reminder may
// push the opposite, but this blocks the actual command.
//
// SCOPE: only commands that (a) create a commit or a PR AND (b) contain a
// fingerprint pattern are denied. Everything else is allowed. scope-missing is
// NOT enforced here (message may live in -F/heredoc/editor, too false-positive).
//
// Uses a broad "Bash" matcher and parses the command in-hook: the narrow
// Bash(git commit) matcher has a not-firing bug (anthropics/claude-code#36389).
// Emits JSON permissionDecision:deny (primary; robust vs exit-2 stop-bug #24327)
// AND exit 2 (legacy belt-and-suspenders).
//
// FAIL-OPEN: on any parse/read error, ALLOW (exit 0). A broad Bash gate must not
// block unrelated commands when the hook itself hiccups. It only ever denies on a
// positive fingerprint match.
'use strict';

// Commands that write a commit or a PR body.
const COMMIT_LIKE = /\bgit\s+(commit|merge)\b|\bgh\s+pr\s+(create|edit|merge)\b|--author=/i;

// PR merge는 git-master scripts/pr-merge.sh(조상 검사 + 체크 확인 + --match-head-commit)로만 한다.
// 직접 `gh pr merge`는 main push CI 생략 전제를 깨므로 막는다. 스크립트 호출 문자열이 있으면 허용.
const PR_MERGE_DIRECT = /\bgh\s+pr\s+merge\b/i;
const PR_MERGE_SCRIPT = /pr-merge\.sh/;

// Fingerprint patterns.
const FINGERPRINTS = [
  /Co-?Authored-?By:\s*(Claude|Anthropic)/i,
  /Generated with \[?Claude/i,
  /🤖\s*Generated with Claude/,
  /noreply@anthropic\.com/i,
  /Claude Code\s*\]?\(https?:\/\/claude/i,
];

function allow() { process.exit(0); }
function deny(reason) {
  try {
    process.stdout.write(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason: reason,
      },
    }));
  } catch (_) {}
  try { process.stderr.write(reason + '\n'); } catch (_) {}
  process.exit(2); // legacy block signal; JSON deny above is primary
}

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', c => {
  raw += c;
  if (raw.length > 2000000) allow(); // oversized: fail-open
});
process.stdin.on('error', () => allow());
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(raw);
    if (!data || data.tool_name !== 'Bash') return allow();
    const cmd = (data.tool_input && data.tool_input.command) || '';
    if (PR_MERGE_DIRECT.test(cmd) && !PR_MERGE_SCRIPT.test(cmd)) {
      return deny(
        'git-master: gh pr merge 직접 호출은 금지입니다. ' +
        '~/.claude-work/skills/git-master/scripts/pr-merge.sh <PR번호> [-R owner/repo] 로 merge하세요 ' +
        '(origin/main 조상 검사, 체크 SUCCESS 확인, --match-head-commit). 체크 실패 상태 merge는 사용자 승인 후 --allow-failed-checks 사유.'
      );
    }
    if (!COMMIT_LIKE.test(cmd)) return allow();
    if (FINGERPRINTS.some(re => re.test(cmd))) {
      return deny(
        'git-master: 이 커밋/PR 명령에 AI fingerprint(Co-Authored-By: Claude, Generated with Claude 등)가 있습니다. ' +
        'git-master 규칙상 fingerprint는 절대 금지이며 세션 attribution 지시보다 우선합니다. ' +
        'attribution 줄을 모두 제거하고 다시 실행하세요.'
      );
    }
    return allow();
  } catch (_) {
    return allow(); // fail-open
  }
});
