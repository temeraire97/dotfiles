#!/bin/bash
# Runs a hook script with whatever node this machine has.
#
# Hook commands are executed with a minimal PATH that often misses homebrew /
# fnm / nvm shims, so a bare `node` is unreliable and an absolute path is not
# portable across machines. This resolves node at call time and fails open
# (exit 0, no output) when no node exists — a missing runtime must never block
# a tool call.
#
# Usage: run-node.sh <script.js> [args...]

NODE="$(command -v node 2>/dev/null || true)"

if [ -z "$NODE" ]; then
    for candidate in \
        "$HOME/.local/share/fnm/aliases/default/bin/node" \
        "$HOME/Library/Application Support/fnm/aliases/default/bin/node" \
        "${FNM_DIR:+$FNM_DIR/aliases/default/bin/node}"
    do
        [ -n "$candidate" ] && [ -x "$candidate" ] && NODE="$candidate" && break
    done
fi

if [ -z "$NODE" ]; then
    # nvm's version directory name varies (e.g. v20.11.0), so this candidate
    # needs glob expansion, unlike the literal paths above/below. $HOME is
    # quoted so a path containing spaces still matches correctly.
    for path in "$HOME"/.nvm/versions/node/*/bin/node; do
        [ -x "$path" ] && NODE="$path" && break
    done
fi

if [ -z "$NODE" ]; then
    for candidate in \
        "$HOME/.volta/bin/node" \
        /opt/homebrew/bin/node \
        /usr/local/bin/node
    do
        [ -x "$candidate" ] && NODE="$candidate" && break
    done
fi

[ -n "$NODE" ] || exit 0

exec "$NODE" "$@"
