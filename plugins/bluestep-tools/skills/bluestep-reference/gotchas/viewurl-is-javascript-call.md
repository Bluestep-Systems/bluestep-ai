---
description: "In a MergeReport, entry().viewUrl() returns javascript:submitForm('Relate','commit','<url>'), not a URL — as an href it silently ignores target='_blank' and clicking it COMMITS the enclosing form; unwrap the real URL with a regex before rendering"
---

# `entry().viewUrl()` is a `javascript:` call, not a URL

In a MergeReport, `entry().viewUrl()` on a form entry does not return a navigable URL. It returns:

```text
javascript:submitForm('Relate','commit','<real-url>')
```

The wrapper depends on the script type. From a Formula (for example the link in a post-save
notification) the same call has been reported to return a plain relative URL,
`/shared/relate/editdatarecord.jsp?_event=view&_id=...&_id2=...`, with no wrapper (as reported
2026-10, not re-run here). Don't assume the wrapper everywhere, and don't wrap a Formula's URL by
hand; the unwrap below passes a plain URL through, so it is safe in either context.

A `javascript:` href **executes in the current document** instead of navigating, so rendering it
as a link's `href`:

- silently ignores `target="_blank"` — the link can never open a new tab;
- breaks ctrl-click and right-click "Open in new tab";
- **commits the enclosing form when clicked** — a real side effect for what looks like a plain
  "view the source record" affordance.

The failure is expensive to diagnose because it presents as ordinary same-tab navigation — the
obvious suspects (click interceptors, iframe nesting, `<base target>`) are all wrong, and a
published `target="_blank"` that can never work looks like a rendering bug. Reading the live
`href` in the DOM shows the cause immediately.

The declarations won't warn you either: the `B.d.ts` doc comment for `viewUrl()` describes a plain
relative URL and even shows it dropped straight into markup — the `javascript:` wrapper is runtime
behavior the type docs don't mention.

## The fix — unwrap before rendering

Match the wrapper and take the inner URL, passing anything else through untouched so a future
platform change that returns a real URL keeps working:

```typescript
const raw = entry.viewUrl();
const m = /^javascript:submitForm\((?:[^,]*,){2}\s*'([^']+)'\s*\)\s*;?$/.exec(raw);
const href = m ? m[1] : raw;
```

(Verified live 2026-08 against a page of rendered entry links.)

**Unwrap first, then edit the URL.** Appending or stripping query params works on `?` and `&`. A
param appended to a still-wrapped value lands outside the `submitForm(...)` call and silently does
nothing, so run the unwrap before any other change to the URL.

For `viewUrl()` / `editUrl()` on an imported single-entry form that has no entry yet, see
[single-entry-no-entry.md](single-entry-no-entry.md).

## Debugging rule

When a rendered link behaves oddly — wrong tab behavior, unexpected form submits — **read the
live `href` in the DOM first**, before theorizing about click handlers or embedding context.
