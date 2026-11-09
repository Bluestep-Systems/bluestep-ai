---
description: "headF({ isCollapsable: true }) never collapses in a MergeReport whose static/ bundle draws the page after an async data load — clicking the header throws 'Cannot read properties of undefined (reading closed)'; wait for the added groupingfields.js loads, call groups.reload(), then addHeader only for headers not yet registered"
---

# A collapsible `headF` drawn after an async load never collapses

In a MergeReport whose `static/` bundle draws the page after an async data load (for example after
fetching from an Endpoint), `headF({ isCollapsable: true })` renders but clicking the header throws:

```text
Uncaught TypeError: Cannot read properties of undefined (reading 'closed')
```

## Why

The collapse logic lives in `/jslib/groupingfields.js`. Read from its source on a test org
(2026-11):

- In a MergeReport (`__mergeReports` is defined) it runs as version 2: `groups.addHeader(id, open)`
  only queues the header until the page-load step runs, and that step runs on the
  `mergeReportsLoad` event.
- `groups.init()` does nothing in version 2.
- Each copy of the script sets a fresh `globalThis.groups`, with nothing registered.
- `groups.reload()` re-runs the page-load step, which registers the queued headers.
- A click reads `groups.groups[id].closed`, so a header that was never registered throws.

As reported (2026-09, not re-run here): each collapsible `headF` call adds another copy of
`groupingfields.js` to the page. On a page drawn after load, `mergeReportsLoad` has already fired,
so the queued header is never registered, and the copies load in any order, each replacing the one
before.

## The working pattern

As reported (2026-09, confirmed in the browser then, not re-run here):

1. Before drawing, note the `script[src="/jslib/groupingfields.js"]` elements already on the page.
2. Draw the page.
3. Wait for the `load` event of each `groupingfields.js` script that `headF` added.
4. Call `groups.reload()`; this registers the header the last copy queued.
5. Call `groups.addHeader(id, open)` only for a header not already in `groups.groups`. Registering a
   header twice leaves it stuck closed: the row keeps the old closed group, so opening skips it.

The header id is the `header_N` class on the `.groupedRow` that wraps the content.

```typescript
const before = new Set(document.querySelectorAll('script[src="/jslib/groupingfields.js"]'));
renderPage(data); // draws the headF({ isCollapsable: true }) markup
const added = [...document.querySelectorAll<HTMLScriptElement>('script[src="/jslib/groupingfields.js"]')]
  .filter(s => !before.has(s));
await Promise.all(added.map(s => new Promise(r => s.addEventListener('load', r, { once: true }))));
const g = (globalThis as any).groups;
g.reload();
document.querySelectorAll('.groupedRow').forEach(row => {
  const id = [...row.classList].find(c => /^header_\d+$/.test(c));
  if (id && !g.groups[id]) g.addHeader(id, true);
});
```

The sketch assumes the added scripts have not finished loading when it starts waiting; if they
might have, check for that before waiting.
