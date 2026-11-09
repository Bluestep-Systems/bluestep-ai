---
description: "A RecordQuery runs in the session's current unit, which follows the last site or page the user loaded — an endpoint (or a Git Site calling it) can read nothing; pin the unit with currentUnit(baseRecord) on every request"
---

# A query runs in the session's current unit

A `RecordQuery` reads the records of the session's **current unit**, and the current unit follows
the last site or page the user loaded. Nothing in the code changes, but the results do:

- An endpoint's query reads return **nothing** after the caller last loaded a site that lives in
  another unit, and the full data after an admin page of the right unit — same user, same
  permissions.
- A Git Site or any other cross-origin caller that sends the user's credentials inherits the same
  session, so its data appears or vanishes depending on what the user browsed last.

(As reported 2026-10 on an endpoint whose data record sat in the top unit; not re-run here.)

## The fix — pin the unit on every request

Before any read or write, set each query's unit from a record that lives where the data is, and keep
the session's unit if the lookup fails:

```typescript
try {
  const rec = B.find.baseRecord("<data record id>");
  dealsQuery.currentUnit(rec);     // dealsQuery: a query bound by its FID
} catch (e) {
  console.warn("Could not pin the query unit; using the session's");
}
```

`currentUnit(...)` takes a unit id string, an `Id`, an `Entry`, a `Unit`, a `BaseRecord` or a
`FormEntry`; `currentUnit()` with no argument reads the current one, and `resetUnit()` goes back to
the session's.

Related: [meetscriteria-formula-context.md](meetscriteria-formula-context.md) (a unit-scoped query
inside a formula run).
