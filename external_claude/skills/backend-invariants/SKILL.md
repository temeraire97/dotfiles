---
name: backend-invariants
description: Checklist, decision tables, and test patterns for the five backend invariants (idempotency, concurrency, atomicity, consistency, traceability). Use when planning, implementing, or reviewing any HTTP handler, DB write, migration, queue producer or consumer, or outbound integration, in any language.
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

Five properties every backend change must examine. The rule file `backend-invariants.md` states the defaults in one line each. This skill is the working procedure: questions to ask while planning, the decision for each answer, and the test that proves it. Test patterns with code shapes are in [tests.md](tests.md).

Project conventions win over the defaults here. In uwellnow the canonical document is `.github/docs/engineering-conventions.md` section 6.1.

## Procedure

1. Before writing the behavior list (tdd skill section 1), answer the five question groups below for the change.
2. Each "yes" adds at least one behavior to the list and therefore one test.
3. Each "no" is written down with its reason. "N/A" without a reason is not an answer.
4. When reporting, end with the `Invariants` block (format at the bottom). The Stop hook looks for it.

## 1. Idempotency

Ask:
- Can a client send this request twice (retry, double click, replay)? Every non-GET answers yes.
- Does a duplicate cause money movement, a physical action, an email, or a second row that a UNIQUE constraint would not reject?

| Situation | Decision |
|---|---|
| POST or PATCH with money or physical side effect | `Idempotency-Key` header required. Missing key is 400 |
| Duplicate is already rejected by a UNIQUE constraint (signup by email) | Key optional. Map the IntegrityError to a domain 409 |
| GET, HEAD, OPTIONS, DELETE, full PUT | Idempotent by definition. No key |
| Same key, same payload, finished | Replay the stored response (status and body), including a stored 5xx |
| Same key, different payload | 400 `IDEMPOTENCY_KEY_MISMATCH`. Compare a hash of the canonical body. Stripe, Square, and Zalando use 400; the IETF draft and TrueLayer use 422; this project does not use 422 anywhere |
| Same key, still processing | 409 `IDEMPOTENCY_IN_PROGRESS`. Do not run the operation twice |
| Storage | Key scoped to (principal, operation). Store the result in the same transaction as the business write. Keep 24 hours. Key is client generated, UUID v4 or v7, at most 255 chars, never contains personal data |

Reference points: Stripe (255 chars, 24 h, replays stored errors), Toss Payments (300 chars, 15 days, 409 in flight, mismatch code not in the official reference), IETF draft-ietf-httpapi-idempotency-key-header (expired 2026-04, no RFC).

## 2. Concurrency

Ask:
- Does the code read something, decide, then write based on what it read? That is check-then-act and it is unsafe under Read Committed without protection.
- Can two requests touch the same row, counter, balance, slot, or stock at once?
- Does the code hold a transaction open while waiting on a user, a timer, or an outbound call?

| Situation | Decision |
|---|---|
| Uniqueness (one active token per user, one membership per org) | UNIQUE constraint or partial unique index. Application check is only for the error message |
| Decrement with floor (stock, quota, balance) | One conditional `UPDATE ... SET n = n - 1 WHERE id = ? AND n >= 1`. Zero rows affected means refused. No prior SELECT |
| Read, compute, write on one row | `SELECT ... FOR UPDATE` inside the transaction, or a version column in the UPDATE WHERE with zero rows meaning conflict |
| Job queue, pick one pending row | `SELECT ... FOR UPDATE SKIP LOCKED LIMIT 1` |
| Cross-process mutual exclusion (migration runner, scheduled job) | `pg_advisory_lock`, never a flag column |
| Many rows locked in one transaction | Always the same order (sort by primary key). Strongest lock first |
| Transaction spans user input or outbound HTTP | Split it. Commit first, call out, record the outcome in a second transaction |
| SERIALIZABLE or REPEATABLE READ | Wrap in a retry loop on SQLSTATE 40001 (and 40P01 deadlock) |

Pessimistic (FOR UPDATE) when a retry is expensive or has side effects: payments, reservations. Optimistic (version column) when reads dominate and conflicts are rare: profile edits.

## 3. Atomicity

Ask:
- Which writes must all succeed or all fail together?
- Does the code write to the DB and then publish, mail, or call another system?
- If the second step fails after the first commits, what state is the user left in?

| Situation | Decision |
|---|---|
| Several tables share one invariant | One transaction. One commit |
| DB write plus event or message | Transactional outbox: write the event row in the same transaction, a relay publishes it. At-least-once delivery, so the consumer stores processed message ids and skips repeats |
| DB write plus email or push | Commit first, then send. Record send outcome. Never send inside the transaction |
| DB write plus external PG or partner API | Call out first with an idempotency key, then record the confirmed result. The external result is the source of truth. On timeout, query the partner before retrying |
| Steps across services that cannot share a transaction | Saga with a compensating action per step. Write down which step is the point of no return |

Any library or platform that says "exactly-once" is at-least-once plus deduplication. Keep the deduplication.

## 4. Consistency

Two senses. Answer both.

**Within one transaction (invariants).**
- Which rules must be true after every commit? (order total equals sum of lines, ledger balance equals sum of entries, one primary identity per user)
- Is each rule enforced by a DB constraint (UNIQUE, FK, CHECK, NOT NULL, trigger) or only by application code? Application-only enforcement is a defect unless the rule cannot be expressed in the DB.
- Does the aggregate (SUM then INSERT) suffer serialization anomalies under Read Committed? If so, SERIALIZABLE with 40001 retry, or lock the parent row.

**Across tables or systems (agreement).**
- Which other table, cache, search index, partner system, or ledger must agree with this write?
- Is the agreement immediate (same transaction) or eventual? If eventual, name the reconciliation job, its schedule, and the alert on drift.
- For money: which side is authoritative? The PG or bank statement is the truth, the local table is a projection. `UNIQUE(order_id, payment_type)` and `UNIQUE(pg_transaction_id)` stop double recording.
- Read-your-writes: after this write, does the next read on this API see it? If a replica or cache can lag, say so in the API doc.

Korean documents use 정합성 for both senses and 무결성 for value-level rules. In English keep "invariants" and "cross-system agreement" as separate items so the second one is not forgotten.

## 5. Traceability

Ask:
- When this fails in production, can one id find every log line, DB row, and partner call for the request?
- Who did it, with what key, when, and what happened?

| Situation | Decision |
|---|---|
| Inbound HTTP | Extract `traceparent` with the OpenTelemetry propagator. Generate a new trace if absent. Never parse the header by hand |
| Outbound HTTP, queue message | Inject `traceparent` into headers or message attributes with the same propagator |
| Logging | Every record carries trace_id and span_id, set by the OTel log handler or MDC, not by string formatting |
| Business workflow spanning several traces (order id, settlement batch id) | Separate correlation field. Not a replacement for trace_id |
| State change | One audit record: actor, idempotency key, request time, outcome, trace_id |
| Legacy `X-Correlation-ID` | Log both during migration. Remove only after dashboards and consumers switched |

## Reporting format

End the task report with this block. Each line is `applied` or `N/A` followed by one reason. The Stop hook blocks a backend task that ends without the word `Invariants`.

```
Invariants
- Idempotency: applied. Idempotency-Key on POST /passes, 400 on mismatch, test test_passes_idempotency.py
- Concurrency: applied. Conditional UPDATE on remaining_count, two concurrent requests test
- Atomicity: applied. Pass row and audit row in one transaction, outbox row for issued event
- Consistency: applied. UNIQUE(org_id, phone) constraint, reconciliation job pass_count_reconcile nightly
- Traceability: applied. traceparent propagated, audit record with actor and key
```

A property that does not apply is still listed:

```
- Idempotency: N/A. GET endpoint, no state change
```
