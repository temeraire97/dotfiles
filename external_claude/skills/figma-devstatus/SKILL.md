---
name: figma-devstatus
description: Enumerate every node marked Dev Mode "Ready for dev" / "Completed" in a Figma file. Figma MCP tools cannot read devStatus, so use the REST API. Use when checking what design was handed off, listing screens to build, or querying devStatus.
---

# Figma devStatus Lookup

## Core fact (reason this skill exist)

Neither Figma MCP server (`plugin:figma`, `figma-desktop`) can read devStatus.

- `use_figma` accessing `node.devStatus` gives `Error: in get_devStatus: "devStatus" is not a supported API` (blocked by plugin API allowlist)
- `get_metadata` XML output has no devStatus attribute either
- Type definitions say it exists (`DevStatusMixin.devStatus: { type: 'READY_FOR_DEV' | 'COMPLETED', description }`) — so code type-checks fine but throws at runtime

**Trap**: scanning with `try { n.devStatus } catch { continue }` swallows every node into the catch branch and reports a false "0 found". Always tally the exception count separately.

## Right path: REST API

- Token live in macOS keychain, loader in `~/.zshrc`:
  - `export FIGMA_TOKEN="$(security find-generic-password -s 'Figma PAT' -a figma -w)"`
  - Re-register: `security add-generic-password -U -s "Figma PAT" -a figma -w '<figd_token>'` (expires in 90 days)
  - `figma-token` function reloads it into current shell
- **Never print token value.** Checking length is fine.
- `~/.zshrc` already has helper function `figma-devstatus <fileKey>` (depth=3). Raise or drop depth if marked nodes sit deeper.

Snippet:

```bash
T=$(security find-generic-password -s 'Figma PAT' -a figma -w)
curl -s -H "X-Figma-Token: $T" "https://api.figma.com/v1/files/<FILE_KEY>" -o /tmp/figma_full.json
jq -r '.document.children[] | .name as $p | recurse(.children[]?) | select(.devStatus != null)
       | "\($p)\t\(.devStatus.type)\t\(.id)\t\(.type)\t\(.name)"' /tmp/figma_full.json
```

- Watch the depth param: `?depth=4` only covers down to top-level frames. For full coverage fetch without depth (big files exceed 100MB — always save to file and query with jq, never read whole thing).
- Node deep link: `https://www.figma.com/design/<FILE_KEY>?node-id=<id with colon replaced by hyphen>`

## Follow-up work pattern

- After finding marked nodes, when writing per-screen specs: pre-slice each node subtree from the REST dump into `tree.txt` (structure) / `text.txt` (copy) so agents work without MCP round trips.
- Use Figma MCP `get_screenshot` only for visual confirmation.
