#!/usr/bin/env node
// ~/.claude/hooks/backend-invariants-gate.js
// Stop and SubagentStop hook. If this session (or this subagent) edited backend
// code since the last declaration and the final message has no "Invariants"
// block, block once and ask for it. The block lists five names, each marked
// applied or N/A with a reason.
//
// stop_hook_active=true means a stop hook already continued this turn, so the
// gate lets the turn end to avoid a loop (Claude Code also caps at 8).
//
// Deterministic string check, no model call. Escalate to a type:prompt hook if
// empty declarations become a pattern. FAIL-OPEN on any error.
'use strict';

const { readState, clearState } = require('./backend-invariants-common.js');

const DECLARED = /\binvariants\b/i;
const FIVE = ['idempotency', 'concurrency', 'atomicity', 'consistency', 'traceability'];

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', c => {
  raw += c;
  if (raw.length > 2000000) process.exit(0);
});
process.stdin.on('error', () => process.exit(0));
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(raw);
    const state = readState(data);
    if (!state.touched) process.exit(0);

    const message = String(data.last_assistant_message || '');
    const lower = message.toLowerCase();
    const declared = DECLARED.test(message);
    const missing = FIVE.filter(name => !lower.includes(name));

    if (declared && missing.length === 0) {
      clearState(data);
      process.exit(0);
    }
    if (data.stop_hook_active) {
      // Already continued once this turn. Let it end; keep state so the next
      // turn on the same files is asked again.
      process.exit(0);
    }

    const files = (state.files || []).slice(-8).join(', ') || 'backend files';
    const reason = [
      `Backend code was edited this turn (${files}) and the final message has no complete Invariants block.`,
      'End the report with a block headed "Invariants" and one line per property:',
      'Idempotency, Concurrency, Atomicity, Consistency, Traceability, each marked applied or N/A with one reason.',
      missing.length ? `Missing: ${missing.join(', ')}.` : '',
      'Format and decision tables: backend-invariants skill.',
    ].filter(Boolean).join(' ');

    process.stdout.write(JSON.stringify({ decision: 'block', reason }));
  } catch (_) {
    // fail-open
  }
  process.exit(0);
});
