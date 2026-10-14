# Backend Invariants: Test Patterns

Each pattern is one behavior for the tdd loop. Test through the public interface (HTTP client or service function), assert on observable state (rows, responses), not on internals. Shapes are shown in pytest with an async HTTP client and SQLAlchemy, but the assertions are the point and translate to any stack.

## Idempotency

**Same key, same payload replays.**
```python
async def test_same_key_same_payload_replays(client, db):
    key = str(uuid4())
    first = await client.post("/api/v1/passes", json=BODY, headers={"Idempotency-Key": key})
    second = await client.post("/api/v1/passes", json=BODY, headers={"Idempotency-Key": key})
    assert first.status_code == second.status_code == 201
    assert first.json() == second.json()
    assert await count(db, Pass) == 1
```

**Same key, different payload is 400.**
```python
async def test_same_key_different_payload_rejected(client):
    key = str(uuid4())
    await client.post("/api/v1/passes", json=BODY, headers={"Idempotency-Key": key})
    other = await client.post("/api/v1/passes", json={**BODY, "count": 99}, headers={"Idempotency-Key": key})
    assert other.status_code == 400
    assert other.json()["code"] == "IDEMPOTENCY_KEY_MISMATCH"
```

**Same key in flight is 409.** Hold the first request open with an event or a slow dependency, send the second, assert 409 `IDEMPOTENCY_IN_PROGRESS`, then release the first.

**Missing key on a required endpoint is 400.**

**Stored response and business row are atomic.** Inject a failure after the business write and before the response is stored. Assert neither row exists.

## Concurrency

**Two concurrent requests create at most one row.**
```python
async def test_concurrent_duplicate_creates_one(client, db):
    results = await asyncio.gather(
        client.post("/api/v1/memberships", json=BODY),
        client.post("/api/v1/memberships", json=BODY),
    )
    statuses = sorted(r.status_code for r in results)
    assert statuses == [201, 409]
    assert await count(db, Membership) == 1
```
Run against a real database, not SQLite in memory. Constraints and row locks do not behave the same there.

**Decrement never goes below zero.** Start with 1 remaining, fire N parallel consumes, assert exactly one 200 and remaining equals 0.

**Version conflict is detected.** Read the row twice, update with the first version, update with the second version, assert the second returns 409 or raises the domain conflict error.

**Serialization failure is retried.** Patch the session to raise `OperationalError` with pgcode `40001` once, assert the operation still succeeds and ran twice.

## Atomicity

**Partial failure leaves no partial state.**
```python
async def test_failure_after_first_write_rolls_back(client, db, monkeypatch):
    monkeypatch.setattr(ledger, "append", raise_once(RuntimeError))
    response = await client.post("/api/v1/settlements", json=BODY)
    assert response.status_code == 500
    assert await count(db, Settlement) == 0
    assert await count(db, LedgerEntry) == 0
```

**Outbox row is written with the business row.** After a successful create, assert one row in the outbox table with the event type and the aggregate id, in the same test that asserts the business row.

**Nothing is sent before commit.** Make the mail or publish client record calls. Force a rollback after the business write. Assert the client was never called.

**Consumer skips a repeated message.** Deliver the same message id twice, assert the side effect happened once.

## Consistency

**Constraint rejects the invalid row even when application validation is bypassed.** Insert directly through the session, not the API. Assert `IntegrityError`. This proves the DB, not the handler, enforces the rule.

**Aggregate invariant holds after concurrent writes.** Run parallel line inserts, then assert `order.total == sum(lines.amount)`.

**Reconciliation detects drift.** Write a row to one side only, run the reconciliation function, assert it reports exactly that id.

**External result is the truth.** Make the PG client return failure after the local row was created. Assert the local row is absent or marked failed, never marked paid.

## Traceability

**Incoming traceparent is propagated outbound.**
```python
async def test_traceparent_propagates(client, httpx_mock):
    parent = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
    await client.post("/api/v1/passes", json=BODY, headers={"traceparent": parent})
    outbound = httpx_mock.get_request()
    assert outbound.headers["traceparent"].split("-")[1] == "0af7651916cd43dd8448eb211c80319c"
```

**Log records carry trace_id.** Capture logs during one request, assert every record has a non-empty trace_id equal to the request's trace.

**State change writes one audit record.** After a successful mutation, assert one audit row with actor id, idempotency key, and outcome.

## Fixtures worth having once

- A real PostgreSQL per test session (testcontainers or a CI service), with per-test transaction rollback or truncation.
- `raise_once(exc)` helper that raises on the first call and passes through afterwards.
- A recording fake for outbound clients (mail, PG, queue) that stores calls and can be told to fail.
- `httpx_mock` or equivalent to inspect outbound headers.
