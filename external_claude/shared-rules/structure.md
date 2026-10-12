# Shared Rules: Code Placement and Naming

Applies to every project. Project-specific rules take precedence.

## Directory placement

Source: Toss Frontend Fundamentals "함께 수정되는 파일을 같은 디렉토리에 두기", my-frontend "Organize by feature/domain".

- Files that change and get deleted together live in one directory.
- Before creating a file, count its importers. Used by one domain only: put it in that domain folder.
- Code used by several domains never goes inside one consumer's domain folder. A single file goes at the shared top level. A group that changes together gets a feature-named folder.
- Never create type-based folders (`utils/`, `hooks/`, `constants/`, `http/`) outside a domain.
- No domain prefix on files inside a domain folder (`order/api.ts`, not `order/orderApi.ts`).
- Importing another domain's folder is allowed. Keep the domain visible in the path. Never hoist a file to the top level to hide the dependency.

## Naming

- New folders: one lowercase word, or kebab-case for several (`app-shell`). Never create camelCase folders.
- File names follow the project's existing convention.

## Delegating to subagents

- Write the target directory tree into the spec. Never just say "follow precedent".
- Explore and Plan agents skip CLAUDE.md and these rules. Put the needed rules in their spec.
- After creating or moving files, review the diff with `frontend-fundamentals:reviewer`.

## Writing

- No em dash, en dash, middle dot (U+00B7), or arrow characters in code, comments, docs, or commit messages.
