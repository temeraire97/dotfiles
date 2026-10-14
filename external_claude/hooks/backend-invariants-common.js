'use strict';
// Shared helpers for backend-invariants-inject.js and backend-invariants-gate.js.
// State is one small JSON file per (session, agent) under the Claude config dir.
// Every function fails open: any error yields "no backend touched" or no-op.

const fs = require('fs');
const path = require('path');
const os = require('os');

const BACKEND_PATH = /(^|\/)(api|api-[^/]+|server|services|routers|routes|handlers|db|migrations|alembic)(\/|$)/i;
const BACKEND_EXT = /\.(py|sql)$/i;
const SKIP_EXT = /\.(md|mdx|txt|json|ya?ml|toml|lock|csv|svg|png|jpe?g|gif|ico|woff2?|css|scss|html|snap)$/i;
const TEST_PATH = /(^|\/)(tests?|__tests__|spec)(\/|$)|\.(test|spec)\.[a-z]+$|(^|\/)test_[^/]+\.py$/i;

// Content signals that a file does backend work, for files outside the glob
// (for example a Next.js server action or a Hono route in an unusual folder).
const BACKEND_CONTENT = new RegExp(
  [
    '\\b(INSERT\\s+INTO|UPDATE\\s+\\w+\\s+SET|DELETE\\s+FROM|FOR\\s+UPDATE|BEGIN|COMMIT|ROLLBACK)\\b',
    '\\b(session|db|tx|trx|transaction|conn)\\.(add|commit|rollback|execute|begin|flush|query)\\b',
    '@(router|app)\\.(get|post|put|patch|delete)\\b',
    '\\b(router|app)\\.(post|put|patch|delete)\\(',
    '\\b(httpx|requests|axios|fetch)\\s*[.(]',
    '\\b(publish|enqueue|send_message|sendMessage|produce)\\s*\\(',
    'use server',
  ].join('|'),
  'i'
);

function stateDir() {
  const base = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
  const dir = path.join(base, 'state', 'backend-invariants');
  try { fs.mkdirSync(dir, { recursive: true }); } catch (_) {}
  return dir;
}

function stateFile(data) {
  const session = String((data && data.session_id) || 'nosession').replace(/[^a-zA-Z0-9_-]/g, '');
  const agent = String((data && data.agent_id) || 'main').replace(/[^a-zA-Z0-9_-]/g, '');
  return path.join(stateDir(), `${session}--${agent}.json`);
}

function readState(data) {
  try {
    return JSON.parse(fs.readFileSync(stateFile(data), 'utf8'));
  } catch (_) {
    return { touched: false, files: [], lastInjectedAt: 0 };
  }
}

function writeState(data, state) {
  try { fs.writeFileSync(stateFile(data), JSON.stringify(state)); } catch (_) {}
}

function clearState(data) {
  try { fs.unlinkSync(stateFile(data)); } catch (_) {}
}

function isBackendFile(filePath, content) {
  if (!filePath) return false;
  if (SKIP_EXT.test(filePath)) return false;
  if (BACKEND_PATH.test(filePath) || BACKEND_EXT.test(filePath)) return true;
  if (content && BACKEND_CONTENT.test(content)) return true;
  if (!content) {
    try {
      const stat = fs.statSync(filePath);
      if (stat.size > 512 * 1024) return false;
      return BACKEND_CONTENT.test(fs.readFileSync(filePath, 'utf8'));
    } catch (_) {
      return false;
    }
  }
  return false;
}

function isTestFile(filePath) {
  return TEST_PATH.test(filePath || '');
}

module.exports = { readState, writeState, clearState, isBackendFile, isTestFile };
