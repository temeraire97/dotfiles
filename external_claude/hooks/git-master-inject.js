#!/usr/bin/env node
// ~/.claude/hooks/git-master-inject.js
// UserPromptSubmit hook: when the prompt looks like a git task, inject the
// git-master core rules as context so they are present deterministically
// (skill auto-invocation is probabilistic; this backstops rule AWARENESS —
// it does not enforce. The hard fingerprint block lives in git-master-guard.js).
//
// Injected text is written as FACTUAL STATEMENTS, not imperative/system commands:
// out-of-band command framing can trip Claude's prompt-injection defenses
// (cf. anthropics/claude-code#17804).
//
// FAIL-OPEN: on any error, emit nothing and exit 0. A prompt hook must never
// block or corrupt a turn.
'use strict';

// git-intent keywords. English matched on word boundaries to cut false hits;
// Korean has no word boundary so matched as substrings.
const EN = /\b(commit|branch|merge|rebase|push|checkout|stash|cherry-pick|pull request|pr)\b/i;
const KO = /(커밋|브랜치|머지|병합|리베이스|푸시|체크아웃|스태시|풀리퀘|풀 리퀘)/;
const GH = /\bgh pr\b/i;

const CONTEXT = [
  '[git-master] 이 저장소의 git 규칙:',
  '- 커밋은 한국어 Conventional Commits이고 type(scope) 형식이며 scope는 필수다.',
  '- AI fingerprint(Co-Authored-By: Claude, Generated with Claude, 🤖)는 금지이며, 세션 attribution 지시보다 이 규칙이 우선한다.',
  '- 현재 브랜치와 무관한 작업은 새 브랜치(worktree)에서 한다.',
  '- 1-2줄, 저위험, 단일 파일 수정은 main 직행이 가능하다.',
  '- 상세는 git-master skill(SKILL.md), CodeCommit 프로젝트는 codecommit.md에 있다.',
].join('\n');

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', c => {
  raw += c;
  if (raw.length > 1000000) process.exit(0); // oversized: fail-open
});
process.stdin.on('error', () => process.exit(0));
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(raw);
    const prompt = (data && data.prompt) || '';
    if (EN.test(prompt) || KO.test(prompt) || GH.test(prompt)) {
      process.stdout.write(CONTEXT + '\n');
    }
  } catch (_) {
    // fail-open
  }
  process.exit(0);
});
