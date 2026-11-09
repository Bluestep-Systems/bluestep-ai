---
description: "MCP get_script/read_script_draft error with 'FormulaModelRemote cannot be cast to … UserCodeScript' on legacy RelateScript formulas — the error means 'this is RelateScript', not 'missing'; read the source via the editformuladetails.jsp wizard instead; a legacy merge report's RelateScript is <img bsid> markers in its merge content (editdetailreport1.jsp), found via _show=DR, the Inspector or a formula search"
---

# Reading legacy RelateScript formula source

## The failure

The gateway MCP script-source tools `get_script` and `read_script_draft` handle **BSJS
UserCodeScripts only**. On a legacy **RelateScript** formula they error with (verified 2026-08):

```
class myassn.relate.FormulaModelRemote cannot be cast to ... UserCodeScript
```

Read that error as **"this formula is legacy RelateScript"** — not as missing, broken, or
permission-denied. MCP cannot read RelateScript source at all; do not retry other script readers.

## The workaround — read it through the formula edit wizard

In the browser, on the formula's `editformuladetails.jsp` page (the "Edit Formula Options" step):

1. The page initializes a **3-step wizard** whose step URLs sit in hidden inputs
   `__wzURL0` / `__wzURL1` / `__wzURL2`.
2. Run `submitWizard(2, "autoNamedForm0")` (in the page's JS context) to advance to the
   `editformula.jsp` **code step**.
3. Read the source from the `#formula` textarea.

This is **non-destructive**: wizard navigation POSTs to session state only — it does not commit
the formula. Verified live while porting a RelateScript formula to BSJS (2026-08).

Relevant during RelateScript → BSJS migration work, where reading the legacy source is the first
step. When you extend a RelateScript formula instead, it needs no per-field imports — see
"RelateScript formulas need no per-field imports" in
[reference/import-scope.md](../reference/import-scope.md). The MCP tool set itself is catalogued in
[conventions/mcp-platform-authoring.md](../conventions/mcp-platform-authoring.md).

## Legacy RelateScript merge reports

A legacy (pre-BsJs) merge report is a different object from a formula, with a different path to
its source. What follows is as reported 2026-09 from a customer org, not re-run here (the test org
has no legacy merge report), except where a line says verified.

- **Where the code lives.** The report's RelateScript sits in its **merge content** as
  `<img bsid="...">` markers. These are not Formula objects: they never show in Relate Structure →
  Formulas, the `editformuladetails.jsp` wizard above does not apply, and `b6p pull` cannot fetch
  them (they are not a BsJs script).
- **Finding the report.** Relate → Admin → Merge Reports is
  `relatestructure.jsp?_event=view&_id=<relateAppId>&_show=DR` (`_show=F` forms, `_show=S` formulas,
  `_show=DR` merge reports). Each report opens at `editdetailreport1.jsp?_event=edit&_id=<reportId>`,
  a setup wizard; the merge content is on its own step. (Both URLs verified 2026-11 on BsJs reports.)
- **Read the merge content first.** On the merge-content step, read `textarea[name=content]` to get
  the list of markers before anything else. The shape varies a lot: one marker can carry the whole
  report (`formula:out` and `formula:htmlOut` are common), or the content can be full HTML with a
  dozen named formulas doing the work. Do not assume the one-marker shape.
- **Marker vocabulary** (the `bsid` attribute):

  | `bsid` | Meaning |
  |---|---|
  | `formula:NAME` | a RelateScript formula on the report; `NAME` is arbitrary |
  | `<fieldId>` | Field Value (renders the value) |
  | `<fieldId>:F` | Field Edit (an editable field) |
  | `<fieldId>:I` | Field Status / merge tag |
  | `<mergeReportId>` | a **nested** merge report — open it too, it can hold more RelateScript |
  | `pagelet` | a placeholder on custom pages; the `_pageName=` sits in the text next to it |

  Each marker's `title` attribute names its type and owning form (`Field Edit: <field> / Form:
  <form>`). Read that instead of decoding ids.
- **Searching formula bodies.** Some orgs have a "Search all formulas" custom page (Relate → Admin
  Tools). It full-text searches formula bodies, in-report ones included, and links each hit to the
  object that owns it, so a distinctive string from the rendered report finds the report in one go.
  It finds one formula at a time, so the merge content is still what tells you how many there are.
  **Never search a bare `;`** to dump everything: it matches every formula in the org and froze the
  page.
- **Mapping data sources.** The report's Inspector,
  `/shared/relate/inspector/inspect.jsp?_a=<relateAppId>&_id=<reportId>&_event=view&_formClass=myassn.view.web.WebView`,
  lists what the report depends on — its queries, forms and fields, one level deep (as reported) —
  with no code to read. Without `_event=view&_formClass=…` the page shows only
  `Unknown (GraphableHelper$1)` (that requirement verified 2026-11 on a BsJs merge report).
- **Often fastest of all:** ask the user to paste the source out of the formula editor.
