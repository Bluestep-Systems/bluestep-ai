---
description: "Touching an imported single-entry form when the record has no entry yet creates and saves an empty entry (even read-only, even just id()); editUrl() throws a NullPointerException; only viewUrl() is safe — test a real value, not existence"
---

# An imported single-entry form with no entry yet

When BsJs code touches an imported **single-entry** form (current record) and the record has no
entry for it yet:

- **Loading the import creates and saves an empty entry** in the same transaction. Calling `id()`,
  `created()`, `modified()`, `entry().justCreated()`, or reading any field all do it — even when the
  form is imported read-only, and even with no fields imported.
- **`editUrl()` throws** `java.lang.NullPointerException: Cannot invoke
  "myassn.view.web.EventInfo.getEventUrl()" because "this.realEvent" is null`.
- **Only `viewUrl()` is safe.** In a formula it returns a plain URL (a redirect to it works); from
  a MergeReport it comes back wrapped — see
  [viewurl-is-javascript-call.md](viewurl-is-javascript-call.md).

BsJs has no existence check, so "does this record have an entry yet?" cannot be answered without
creating one. `id().isValid()` is always true once the code has run, and `created()` / `modified()`
return "now" when there was no entry. Test a **real value** instead — a required field that is not
blank, or a flag a formula on that form sets.

(Reported 2026-10 from a post-save formula and confirmed by the platform team, who track it as a
platform bug; retire this page when that ships.)
