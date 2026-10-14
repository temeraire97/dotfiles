---
paths:
  - "**/api/**"
  - "**/api-*/**"
  - "**/server/**"
  - "**/services/**"
  - "**/routers/**"
  - "**/routes/**"
  - "**/handlers/**"
  - "**/db/**"
  - "**/migrations/**"
  - "**/alembic/**"
  - "**/*.py"
  - "**/*.sql"
---

# Backend Invariants

Every backend change (HTTP handler, DB write, queue, outbound call, migration) must address five properties. For each one, either apply it or state why it does not apply. Never leave one unexamined. The checklist, decision tables, and test patterns live in the `backend-invariants` skill; load it before planning a backend task.

1. **Idempotency.** Any POST or PATCH with money or physical side effects takes an `Idempotency-Key` header, scoped to (principal, operation). Same key and same payload replays the stored response. Same key and different payload returns 400 `IDEMPOTENCY_KEY_MISMATCH` (Stripe, Square, Zalando; the IETF draft says 422 but this project does not use 422). Same key still in flight returns 409. The stored result is written in the same transaction as the business write and kept 24 hours. GET and DELETE are idempotent by definition and need no key.
2. **Concurrency.** Check-then-act is unsafe without protection. Protect with a DB constraint first (UNIQUE, FK, CHECK), then `SELECT ... FOR UPDATE`, a single conditional UPDATE, or a version column. Lock rows in one fixed order. Never hold a transaction open across user input or an outbound call. Retry on SQLSTATE 40001.
3. **Atomicity.** Writes that share an invariant go in one transaction. Mail, outbound HTTP, and events happen after commit; events go through a transactional outbox row written in the same transaction. Delivery is at-least-once, so consumers deduplicate by message id. Treat any "exactly-once" claim as suspect.
4. **Consistency.** Two senses, both required. Within one transaction, aggregate invariants hold (order and its lines, wallet and its ledger) and DB constraints are the first defense, not application validation. Across systems or tables, records agree: declare it eventual, name the reconciliation job, and alert on drift. For payments, the external PG result is the source of truth and its failure aborts the transaction.
5. **Traceability.** Propagate W3C `traceparent` with the OpenTelemetry inject and extract API, never by hand. Every log record carries trace_id and span_id. A business correlation id is a separate field. Every state-changing request leaves one audit record with actor, idempotency key, timestamp, and outcome.

Before finishing a backend task, end the report with an `Invariants` block listing the five names, each marked applied or N/A with one reason. A Stop hook checks for this block.
