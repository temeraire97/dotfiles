# My Frontend Guidelines

Frontend code design principles.

---

## Readability

- **Name magic numbers**: use named constants (e.g., `ANIMATION_DELAY_MS = 300`)
- **Abstract implementation details**: extract complex logic into dedicated components/HOCs (e.g., `AuthGuard`, `InviteButton`)
- **Separate conditional code paths**: split widely different UI/logic into separate components
- **Simplify ternaries**: replace complex or nested ternaries with `if`/`else` or IIFE
- **Name complex conditions**: assign boolean expressions to descriptive variables (`isSameCategory`, `isPriceInRange`)

---

## Predictability

- **Standardize return types**: use consistent return types across similar functions
  - React Query hooks → return whole query object
  - validation functions → `{ ok: true } | { ok: false; reason: string }`
- **Reveal hidden logic (SRP)**: function does only what its signature implies - no hidden side effects
- **Use unique, descriptive names**: avoid ambiguity in custom wrappers (e.g., `httpService.getWithAuth` not just `http.get`)

---

## Cohesion

- **Form cohesion**: pick field-level validation (independent fields) or form-level validation (zod schema) per requirements
- **Organize by feature/domain**: group related files together, not by code type
- **Relate constants to logic**: define constants near related logic or use names showing the relationship

---

## Coupling

- **Avoid premature abstraction**: allow some duplication when use cases may diverge
- **Scope state management**: split broad state hooks into small focused ones to prevent unnecessary re-renders
- **Use composition instead of props drilling**: render children directly instead of passing props through intermediate components
