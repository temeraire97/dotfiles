#!/bin/bash
# Combines claude-hud and context-mode status lines into one.
# Claude Code allows only a single statusLine command, so this wrapper
# feeds the same stdin JSON to both and stacks their output.

input=$(cat)

# Resolve bun without hardcoding a machine-specific home.
BUN="$(command -v bun 2>/dev/null || true)"
[ -n "$BUN" ] || BUN="$HOME/.bun/bin/bun"
[ -x "$BUN" ] || exit 0   # no bun on this machine — emit no status line

hud_entry=$(ls -td ~/.claude/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null | head -1)
ctx_bundle=$(ls -td ~/.claude/plugins/cache/context-mode/context-mode/*/cli.bundle.mjs 2>/dev/null | head -1)

hud=""
[ -n "$hud_entry" ] && hud=$(printf '%s' "$input" | "$BUN" "${hud_entry}src/index.ts" 2>/dev/null)

ctx=""
[ -n "$ctx_bundle" ] && ctx=$(printf '%s' "$input" | "$BUN" "$ctx_bundle" statusline 2>/dev/null)

[ -n "$hud" ] && printf '%s\n' "$hud"
[ -n "$ctx" ] && printf '%s\n' "$ctx"
