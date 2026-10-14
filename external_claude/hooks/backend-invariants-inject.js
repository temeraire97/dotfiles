#!/usr/bin/env node
// ~/.claude/hooks/backend-invariants-inject.js
// PreToolUse hook (matcher: Edit|Write|MultiEdit). When the target file is
// backend code (path glob, or content signals for files outside the glob), it
// (a) records "backend touched" in the per-session state for the Stop gate and
// (b) injects a short reminder of the five invariants as additionalContext.
//
// The reminder repeats at most once every REINJECT_MS per session so that long
// sessions get it again after the rule file has scrolled out of attention, but
// a burst of edits does not pay for it on every call.
//
// Written as factual statements, not commands, to stay clear of prompt-injection
// heuristics. FAIL-OPEN: on any error emit nothing and exit 0.
'use strict';

const { readState, writeState, isBackendFile, isTestFile } = require('./backend-invariants-common.js');

const REINJECT_MS = 5 * 60 * 1000;

const REMINDER = [
  '[backend-invariants] This file is backend code. The five invariants apply to this change:',
  'idempotency (Idempotency-Key on side-effect POST/PATCH; 400 mismatch, 409 in flight, replay stored response),',
  'concurrency (constraint first, then FOR UPDATE or conditional UPDATE or version column; no check-then-act),',
  'atomicity (one transaction per invariant; mail and events after commit via outbox; at-least-once plus dedup),',
  'consistency (DB constraints enforce invariants; cross-system agreement is eventual with a named reconciliation job; PG result is the truth),',
  'traceability (traceparent via OTel propagator; trace_id in every log; one audit record per state change).',
  'The task report ends with an Invariants block, one line per property, applied or N/A with a reason.',
  'Details: backend-invariants skill.',
].join(' ');

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
    const input = (data && data.tool_input) || {};
    const filePath = input.file_path || input.path || '';
    const content = input.content || input.new_string || '';
    if (!isBackendFile(filePath, content)) process.exit(0);

    const state = readState(data);
    state.touched = true;
    if (!isTestFile(filePath)) {
      state.files = Array.from(new Set([...(state.files || []), filePath])).slice(-50);
    }
    const now = Date.now();
    const due = now - (state.lastInjectedAt || 0) >= REINJECT_MS;
    if (due) state.lastInjectedAt = now;
    writeState(data, state);

    if (due) {
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          additionalContext: REMINDER,
        },
      }));
    }
  } catch (_) {
    // fail-open
  }
  process.exit(0);
});
