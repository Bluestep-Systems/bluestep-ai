---
description: "Correct BSJS formula patterns — form access, field reads/writes, HTTP, error handling, B.* utilities, DocumentLinkField"
---

Use these patterns as the baseline for every BlueStep post-save (or any) formula. Do not deviate without first checking a working formula — endpoints and merge reports behave differently, and formulas need special care.

**Why:** Hard-won from multiple failed iterations on a document-summarizer formula. The recurring failures were wrong form access and wrong HTTP response reading.

## Structure

- No `/// <reference … />` line is needed: the editor gets the ambient types (`B`, the query/form consts, `console`) from `draft/tsconfig.json`'s `include`, and the publish build wires the component's `declarations/` in itself (see the diagnostics guidance in the `/b6p-push` skill). Many older scripts start with `/// <reference path='../../../scriptlibrary' />` — that path resolves **nowhere** today (verified live 2026-08): not in a pulled workspace (`<Unit>/scriptlibrary` does not exist), and not in the platform's own in-browser editor, which error-marks the line. Don't copy it into new formulas — a dead directive gives false confidence that type-checking is wired when it isn't. In an existing formula the line is inert: leaving it is harmless, and so is removing it.
- Formulas run as bare top-level statements — NO IIFE, no `main()`, no `export default`.
- No bare `return` statements — use a guard `if` block, or `throw` inside try/catch, for early exits.
- **Scope a save formula with its Primary Form, never with a hardcoded form-id check** such as
  `if (B.currentEntry().form().id().toString() === '<form id>')`. The check silently stops matching
  if the form is recreated, and it rescues nothing: a save formula with no Primary Form has been
  reported never to fire (as reported 2026-09, not re-run here). Set it with `primaryFormId` on
  `create_script` / `update_script`. `create_script` refuses a `primaryFormId` the formula can reach
  only through a record category, and creates nothing (verified 2026-11); the reported working order
  is `create_script` without it → `set_category_requirement` → `update_script` with `primaryFormId`.

## Form / field access

- A form/query configured in the component's platform form-import config (regenerated into `declarations/index.d.ts` on pull) is available as a **top-level variable directly in `app.ts`**, named after its FID — do NOT use `B.currentRecord()`. (Older modules registered this by hand in a now-legacy `objects/imports.ts`.)
- Fields: `myForm.fields.fieldName`.
- Field read: `.val()` (direct) or `.opt().orElse(default)` (safe).
- Field write: `.val(newValue)` for scalars (string, bool, date, number).
- Clear a field: `.clear()`.
- Single-select dropdown (200): set with `.setByExportValue("active")` — it returns `false` and changes nothing when no option has that export value, so check it. `.val()` takes an `OptionItem`, not a string. Read with `.optSelected().map(o => o.exportValue()).orElse("")`.
- Select fields have no `.options()` (it throws "Unknown identifier: options"). The option lists are `activeOptions()`, `allOptions()`, `optionsByExport()` and `optionsByName()`.
- Multi-select checkbox (201): check one with `.setByExportValue("x")`, uncheck with `.setByExportValue("x", false)`; to pick by a rule, `field.activeOptions().forEach(op => { if (...) field.set(op.id(), true); })`.
- Set by ID: `.set(B.util.toId(idString))`.
- **An entry's current selection is always valid**, even when that option is now obsolete, disabled
  or locked (`B.d.ts`: a selected obsolete option behaves as active; a selected locked one cannot be
  selected or unselected). Server-side validation of a submitted option should accept the active
  options **plus** the entry's current `optSelected()` id, and skip `set()` when the submitted id is
  the current one. Validating against `activeOptions()` alone blocks every unrelated save on such
  entries. A new entry gets active options only.

## Queries

- **Narrow with `addSearch` before looping** rather than fetching everything and skipping rows in
  JS — some forms hold thousands of entries. On a query: `addSearch(formId, fieldFormulaId,
  operator, value)` or `addSearch(fieldMetaData, operator, value)`; on a multi-entry form:
  `addSearch(fieldFormulaId, operator, value)`; both chain with `addSort`. Searches add up (`&&`)
  and stay on the query for the rest of the run, so on a query other code also reads, call
  `clearSearchAndSort()` when you are done.
- **A query runs in the session's current unit** — see
  [gotchas/recordquery-session-unit.md](../gotchas/recordquery-session-unit.md) before reading a
  query from an endpoint.

## Users

- `B.user` is `null` only when nobody is logged in. A global super user **is** logged in and has a
  `User`; what a super lacks is a record (`B.optUserRecordTypeEntry` is empty). So
  `B.user === null` does not mean "super". Detect one with `B.user !== null && B.user.isGlobalSuper()`
  (verified 2026-11).

## HTTP + response reading

```typescript
const stream = B.net.fetch(url, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ...' },
  body: JSON.stringify(payload),
  connectionTimeout: 60_000,
  readTimeout: 60_000
});
const responseText = B.io.fromInputStream(stream); // ← always use this, not BufferedReader
const data = JSON.parse(responseText);
```

## Error handling

```typescript
try {
  // logic — use throw "message" for controlled early exits
} catch (e) {
  const sw = B.io.stringWriter();
  if (e.printStackTrace) e.printStackTrace(B.io.toPrintWriter(sw));
  else sw.write(e.toString());
  myForm.fields.resultField.val('[Error: ' + sw.toString() + ']');
  B.net.sendMessage('Formula failed: ' + sw.toString(), true); // modal alert to user
  B.io.printStackTrace(e); // server log
}
```

## B.* utilities

- `B.io.fromInputStream(stream)` — read HTTP response to string.
- `B.io.stringWriter()` + `B.io.toPrintWriter(sw)` — capture Java stack traces.
- `B.io.printStackTrace(e)` — write exception to server log.
- `B.toBase64(javaByteArray)` — base64-encode a `Java.ByteArray`.
- `B.net.fetch(url, params)` — outbound HTTP.
- `B.net.sendMessage(html, true)` — modal alert to current user.
- `B.util.toId(string)` — convert a string to a `Bluestep.Id`.
- `B.time.ZonedDateTime.now()` — current timestamp.

## DocumentLinkField

- Cast: `formEntry.fields.document as unknown as Bluestep.Relate.DocumentLinkField`.
- `docField.toBytes({})` — get the file as a `Java.ByteArray`.
- `docField.filename()` — get the filename string.
- `docField.contentSize()` — size in bytes (0 = no file attached).
