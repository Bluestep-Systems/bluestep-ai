---
description: Read the most recent PRIOR committed version of a form entry with entry.versionStream().findFirst().orElse(null) to diff current-vs-previous field values, with no stored "old value" fields
---
# Diffing a Field Against Its Previous Committed Version

To detect whether a field changed on save without storing a separate "old value" field, read the most recent **prior** committed version of the entry off its version stream and compare field-by-field.

## Canonical read

```typescript
// Java.Stream is declared empty, so type the calls this page uses.
type FormEntry = Bluestep.Relate.FormEntry;
interface VersionStream<T> {
  findFirst(): { orElse(other: T | null): T | null };
  limit(n: number): { iterator(): { hasNext(): boolean; next(): T } };
}
const versionsOf = (e: FormEntry) => e.versionStream() as unknown as VersionStream<FormEntry>;

// Previous committed version, or null on first create:
const prev = versionsOf(entry).findFirst().orElse(null);
```

`versionStream()` yields the committed versions most-recent-first (see the order note below);
`findFirst()` is the previous version (a Java `Optional`), and `.orElse(null)` collapses the empty
case to `null`.

## Walking the history: order and cost

- **`versionStream()` is newest first** (as reported 2026-10 on a production org, not re-run here).
  `versions()` returns the same versions as a list, with **no documented order** — do not rely on
  one.
- **Each version is a separate history read** (reported at ~25–55 ms each; an entry with ~4,800
  versions read through `versions()` took over two minutes and timed the page out). Read a bounded
  number from the stream instead, with the `versionsOf` cast above:

```typescript
const it = versionsOf(entry).limit(50).iterator();
while (it.hasNext()) {
  const v = it.next();
  // ...
}
```

- **Some entries have no versions at all.** A multi-entry row created over the gateway and then
  changed by three committed writes from an endpoint returned an empty `versions()` and
  `versionStream()` (verified 2026-11; the cause was not found — no gateway tool exposes a history
  setting). On such an entry `prev` is always `null`, so the change detection below **never fires**.
  Before relying on it, check on the target form that a real edit leaves a version to read.

## Normalize-and-compare helper

Compare `cur.fields[name].val()` against `prev.fields[name].val()`, normalizing so equivalent values don't read as changed. Use `JSON.stringify` for array-valued fields (e.g. multi-select) and a trimmed `String()` otherwise:

```typescript
function norm(v: unknown): string {
  return Array.isArray(v) ? JSON.stringify(v) : String(v ?? "").trim();
}

function changed(cur: FormEntry, prev: FormEntry, name: string): boolean {
  return norm(cur.fields[name].val()) !== norm(prev.fields[name].val());
}
```

## First-create null guard

On a brand-new entry there is no prior version, so `prev` is `null`. Skip the comparison entirely rather than treating "no previous" as a change:

```typescript
if (prev != null) {
  // Only compare when there is a previous version; a first create has nothing to diff against.
  if (changed(cur, prev, "status")) { /* ... */ }
}
```

A formula body is top-level code, so there is no `return` to stop early (see
`conventions/formula-patterns.md`): wrap the work in the `if`, or in a function you return from.

## Pre-save vs post-save timing caveat

**Where you run this matters.** In a **pre-save** formula the current save has not committed yet, so `findFirst()` reliably returns the truly-previous version. In a **post-save** the current save may already be committed, in which case `findFirst()` can return the *just-committed* state instead of the prior one. Before relying on the result in a post-save, verify that the version you read back is genuinely the prior version and not the state you just wrote.

## Example (generic)

A pre-save that stamps a "modified" timestamp only when a tracked set of fields changed vs. the previous version:

```typescript
const prev = versionsOf(entry).findFirst().orElse(null);
if (prev != null) {
  const tracked = ["fieldA", "fieldB", "fieldC"]; // generic FIDs
  const anyChanged = tracked.some((name) => changed(entry, prev, name));
  if (anyChanged) {
    entry.fields.modifiedAt.val(B.time.ZonedDateTime.now(B.time.userZoneId()));
  }
}
```
