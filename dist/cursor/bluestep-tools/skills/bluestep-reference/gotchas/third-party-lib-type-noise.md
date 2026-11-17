---
description: "A MergeReport whose static/script.ts uses a third-party client-side global (e.g. GridStack) prints a wall of advisory type errors on a build — harmless (the emit succeeds and the library exists at runtime in the browser), silence locally with an ambient .d.ts stub"
---

# Third-party client-lib type noise on `b6p script push`

## Symptom

Every `b6p script push --snapshot` of a MergeReport whose `static/script.ts` references a third-party
client-side library prints a wall of TypeScript diagnostics unrelated to whatever actually changed:

```
Cannot find name 'GridStack'
Property 'addWidget' does not exist on type 'never'
```

— the missing-name error for the library's global, plus cascading `never`-type errors on everything
the library's return values touch. Observed with GridStack in a dashboard component; any library
loaded at runtime via a `<script>` tag behaves the same.

## Why

The library is loaded by the browser at runtime (a `<script>` tag in `static/index.html`), so it
exists as a global only in the browser. The component's local `tsconfig.json` bundles no ambient
type declarations for it, so the local **pre-push** build can't see the global and types everything
downstream of it as `never`.

## Safe to ignore — with one real risk

These diagnostics are **advisory only**: the build's emit continues through them, and the library
genuinely exists at runtime in the browser — so nothing is actually wrong. They come from a
**client-bundle** sub-project (`static/`, its own `tsconfig.json`). A type-checker finding is a
warning for the platform's build too, so it still gets a build manifest and publishes (web release
notes). With b6p 0.8 and 0.9 the CLI built locally and left these out of `typeCheckDiagnostics`.
Since b6p 1.0 the platform builds, and `typeCheckDiagnostics` is its whole ERROR + WARNING count, so
these may now raise it; whether they do has not been checked. They fail a push only with
`--fail-on-type-errors`. See the `/b6p-push` skill's `references/type-check-diagnostics.md` and
`reference/server-side-compile.md`.

The real risk is masking: the noise repeats on every push of the affected component and can bury a
**genuine new** diagnostic introduced by the session's actual change. Don't skim past the wall —
scan it for errors in files/symbols you just touched.

## Optional local silencer

Add a one-time ambient stub to the component so its local build knows the global exists — e.g.
`draft/static/globals.d.ts`:

```typescript
// Ambient stub for the runtime-loaded client library — quiets the local
// pre-push build only; does not affect what ships.
declare const GridStack: any;
```

This kills the whole cascade (the `never` errors disappear with the root missing-name error),
restores signal for real diagnostics, and has zero effect on the deployed output.
