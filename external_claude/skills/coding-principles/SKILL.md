---
name: coding-principles
description: Behavioral guardrails for writing or changing code. Surfaces ambiguity before coding, keeps the diff to the minimum that solves the request, and touches only the lines the request requires. Preloaded into implementation agents; also applies when the main session writes specs for them.
---

# Coding Principles

Distilled from the Karpathy guidelines (multica-ai/andrej-karpathy-skills, MIT). These bias toward caution over speed. For trivial tasks, use judgment.

## Think before coding

- State assumptions explicitly. When uncertain, ask.
- When several readings of the request exist, present them instead of picking one silently.
- When a simpler approach exists, say so. Push back when warranted.
- When something is unclear, stop, name what is confusing, and ask.

## Simplicity first

- No features beyond what was asked.
- No abstractions for single-use code.
- No flexibility or configurability that was not requested.
- No error handling for impossible scenarios.
- If 200 lines could be 50, rewrite. Ask whether a senior engineer would call it overcomplicated; if yes, simplify.

## Surgical changes

- Do not improve adjacent code, comments, or formatting. Do not refactor what is not broken.
- Match existing style even when you would do it differently.
- Unrelated dead code: mention it, do not delete it.
- Remove imports, variables, and functions that your own change made unused. Leave pre-existing dead code unless asked.
- Every changed line should trace directly to the request.
