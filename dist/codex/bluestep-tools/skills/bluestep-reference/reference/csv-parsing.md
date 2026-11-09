---
description: BlueStep merge reports CAN read & parse uploaded CSVs — built-in B.csv() parser + DocumentLinkField/Document/fetch access
---

A server-side BSJS merge report CAN access and parse an uploaded CSV at runtime. BlueStep ships a first-class CSV parser — no hand-rolled splitting needed.

**Parser:** `B.csv(input, charset?)` (aliases `B.io.csv` / `B.text.csv`). Accepts a Reader, InputStream, FetchedResource, or string. Methods: `.toListOfObjects()` (array of objects keyed by header row — easiest), `.forEach((rowEList, i)=>…)` (streaming), `.toList()` (2D), and chainable `.fieldDelimeter()/.textDelimeter()/.escapeCharacter()`. Rows from `.row()` are Java-backed `EList<string>` — use `.forEach`/index, NOT JS `.map()`; `toListOfObjects()` rows behave like plain objects.

**Three ways to get the file's bytes (priority order):**
1. **DocumentLinkField on a form/record (preferred)** — an uploaded-file field. `field.content()` → string; `field.forReader(r => B.csv(r).toListOfObjects())` streams it. Also `.forInputStream()`, `.toBytes()`, `.filename()`, `.contentType()`, `.permUrl()/.davUrl()`. No HTTP hop — but reading the content can need super user (see **Permissions**).
2. **Document in a folder** — `folder.documents()['name.csv']` → same `.content()/.forReader()/.toBytes()` accessors. For file-system uploads not on a record.
3. **Fetch by URL** — `B.net.fetch(url)` then `B.csv(fetcher, fetcher.charset)`. Fallback only — reliability depends on URL + session auth. Prefer 1/2 for uploaded files. Platform `/download/...` URLs need a signed-in session and ignore Basic Auth: they answer with the login page as `200 text/html`. With `followRedirects: false` a download URL answers `303` on the normal path, so you read an HTML stub and never see the bytes (both as reported 2026-09, not re-run here).

**Permissions:** merge report runs in current user's context; routes 1/2 read via the platform object model subject to record/folder security. **Reading a document's content can also need super user.** From an endpoint run by a non-super user, every content read threw `RemoteSecurityException ... !isSuperUser`, even though the document and its folder gave that user access and `/download/` served the file. That covers `content()`, `toBytes()`, `contentType()`, `forReader()`, `forInputStream()`, and `B.find.document(id).toBytes()` too. What fixed it was turning on the component's **Run as Super User** setting (as reported 2026-09 from an endpoint, not re-run here; whether a merge report hits the same throw is not known). That setting lifts platform filtering for the whole script, so weigh it and filter in code. The gateway tools cannot read or set it. The GraphQL input `UpdateScriptEndpointInput` has a `runAsSuper` field (verified 2026-11; setting it that way not tried).

**Gotchas:** strip UTF-8 BOM (`﻿` corrupts first header key on Excel/QuickBooks exports); handle `\r\n`; sanitize currency (`$`, thousands commas, `(123)` negatives) before parseFloat; pass charset if Windows-1252; streaming `.forReader()` avoids buffering huge files and sidesteps the "code 0 but real content" issue seen with `B.io.fromInputStream`.

**Relevance:** unlocks metrics that aren't in relational data — e.g. figures exported from an external accounting tool or survey results. Pattern: upload CSV to a Document field on a settings record; in app.ts `field.forReader(r => B.csv(r).toListOfObjects())`; a Verify table can show the parsed rows.
