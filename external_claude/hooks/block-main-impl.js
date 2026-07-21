#!/usr/bin/env node
// ~/.claude/hooks/block-main-impl.js
// PreToolUse gate: DENY Edit|Write|MultiEdit|NotebookEdit from the MAIN (Opus orchestrator) session,
// ALLOW the same tools inside a SUBAGENT (Sonnet executor/tdd-executor/build-fixer/etc).
//
// DISCRIMINATOR: top-level `agent_id` in the PreToolUse stdin JSON is documented as
// "present ONLY when the hook fires inside a subagent call". agent_id present => subagent => ALLOW.
// agent_id absent => main session => DENY. We do NOT use agent_type (also set for `claude --agent`
// main sessions, which would wrongly ALLOW a main session). FAIL-CLOSED: deny on any error.
//
// *** EXPERIMENTAL ON THIS BUILD ***  Two things are unverified locally and MUST pass the live test
// (see spec test plan T1/T2) before this hook is trusted as enforcement:
//   1) that PreToolUse hooks fire at all inside subagents on this version (cf. GitHub #34692),
//   2) that permissionDecision:"deny" actually blocks the Edit under defaultMode:bypassPermissions
//      + skipAutoPermissionPrompt:true (cf. #26923/#37210).
// The .block-main-impl.log written below lets you confirm both from a real run.
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const WRITE_TOOLS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit']);
const LOG = path.join(os.homedir(), '.claude', 'hooks', '.block-main-impl.log');

function log(line) {
  try { fs.appendFileSync(LOG, new Date().toISOString() + ' ' + line + '\n'); } catch (_) {}
}
function deny(reason, ctx) {
  log('DENY ' + (ctx || '') + ' :: ' + reason);
  try {
    process.stdout.write(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'deny',
        permissionDecisionReason: reason
      }
    }));
  } catch (_) {}
  try { process.stderr.write(reason + '\n'); } catch (_) {}
  // belt-and-suspenders: exit 2 is the legacy block signal; JSON deny above is primary.
  process.exit(2);
}
function allow(ctx) {
  log('ALLOW ' + (ctx || ''));
  process.exit(0);
}

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', c => {
  raw += c;
  if (raw.length > 1000000) deny('block-main-impl: oversized payload (fail-closed)', 'oversize');
});
process.stdin.on('error', () => deny('block-main-impl: stdin error (fail-closed)', 'stdin-err'));
process.stdin.on('end', () => {
  let data;
  try { data = JSON.parse(raw); }
  catch (_) { return deny('block-main-impl: unparseable payload (fail-closed)', 'parse-err'); }
  try {
    const tool = data && data.tool_name;
    if (!WRITE_TOOLS.has(tool)) return allow('non-write tool=' + tool);
    const id = data && data.agent_id;
    const atype = (data && data.agent_type) || '-';
    if (typeof id === 'string' && id.length > 0) {
      return allow('subagent tool=' + tool + ' agent_id=' + id + ' agent_type=' + atype);
    }
    return deny(
      'Main-session edits are blocked by orchestrator policy. The main (Opus) loop is an architect/orchestrator only. Delegate this ' + tool + ' to a Sonnet subagent: spawn the `executor` agent (or `tdd-executor` for [TDD] tasks) via the Task tool and have IT make the edit.',
      'main tool=' + tool + ' agent_type=' + atype
    );
  } catch (e) {
    return deny('block-main-impl: unexpected error ' + (e && e.message) + ' (fail-closed)', 'unexpected');
  }
});
