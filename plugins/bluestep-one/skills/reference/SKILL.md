---
name: reference
description: "On-demand reference for building BlueStep One custom components — the type files, creating a component and setting up its repo, the type, copies and required-fields checks, build and publish from a signed-in tab, the served and UX checks, the design check, and the rules, patterns and gotchas of the host, the kit, /gql reads and writes, rights, pages and tooling. This file is the manifest, one line per file with a \"Load when\" trigger; read it first, then only the file you need. Use when building, reviewing or planning a BlueStep One component."
---

# BlueStep One reference

Read only the file the task needs. Entries carry ids (`G-`, `R-`, `P-`) in their headings, and
other entries cite them by id; an id is the same in every file. Entries added after 0.1.0 carry
no id; cite one by its heading. Running a GraphQL call from a
signed-in tab is in the bluestep-tools reference (`/bluestep-tools:bluestep-reference` ›
`reference/gql-in-a-tab.md`).

An entry that says a GraphQL read or write was made "over the gateway" or with `graphql_query` /
`graphql_mutation` was seen before release 26.10.21.02, which took those tools off the gateway. The
same query runs unchanged as a `/gql` POST from a signed-in tab.

## Building and publishing

- [build/types.md](build/types.md) — the seven BlueStep One type files, and a new component: the lookup, the create from a signed-in tab with its catalog fields and seed files, the repo-name rules, clone then register, and the set-up of a new or existing repo. Load when a component is not in `components[]` yet, when setting up a repo, when a type error says the host lost a member, or before any publish.
- [build/typecheck.md](build/typecheck.md) — the type check, the copies check and the required-fields check (and where to run it from). Load before a push to `draft`, and when a check fails.
- [build/publish.md](build/publish.md) — build and publish, from a signed-in tab or the *Build* tab, and the row's catalog fields a publish does not copy (set by an update). Load before building or publishing, when a build fails, and when setting a component's summary, description or use cases.
- [build/served-check.md](build/served-check.md) — whether the published commit is the one served. Load after every publish, before any live check.
- [build/ux-check.md](build/ux-check.md) — the measured UX check of the served screen: timings, `/gql` calls, layout shift, errors and duplicate control names against the project's thresholds. Load after the served check, before the live check, and when the UX check stops.
- [build/design-check.md](build/design-check.md) — a canvas export beside the live screen. Load after a UI publish has passed the served check, and when writing a change's `design-audit.md`.

## Rules and patterns

- [rules.md](rules.md) — rules for any component: no private data in placement props or repos, one data path per piece of data, branching on a refusal's code, rights-refusal wording, slow-work states in the design check, settings an org can change, required fields read from the form definition, one control per Manage field type. Load when designing a component, and before deciding what a screen may show or do.
- [patterns.md](patterns.md) — patterns for a component's data, saves, states, opening times and tests (rights up front, group-keyed rules, one component bound to many forms, links to a page hidden from the menu, read-only field maps over `/gql`, links to an entry held by its `/gql` id, the built-in entry screen plus something as a fork, the choices of many link fields in one request), plus kit and layout idioms (tables as CSS grids, kit tabs, links and dialogs, focus rings, focus moves) and checking a page at 1440 px. Load when designing a component's data, saves, states, layout or tests, and before forking a form's built-in entry screen.

## Gotchas

- [gotchas/host-components-kit.md](gotchas/host-components-kit.md) — the host contract, custom components and the `@bluestep/ui` and `@bluestep/form-kit` kits: partial host saves, radio groups and arrow keys, focus in dialogs and popovers, icon sizes, missing CSS variants, `PageContent` padding, record types, sub-unit searches, copied read deadlines, `openNewEntry`, `openEntry`'s options, `components.list` names, nav reads, deletes, `shownWhen` in blocks, the save footer's truncated error, classes on a canvas `x-import`, host types from a `/gql` record, print mode and hand-drawn print copies, month inputs, `B6pCheckbox`'s missing props, "Remove my signature", merge-report fields on the built-in screen, link colours on a canvas export. Load when a component reads through the host, places itself, or draws kit parts.
- [gotchas/gql-reads.md](gotchas/gql-reads.md) — reading over `/gql`: CSRF round trips, signature filters, cached host reads, id spellings, option order, slow first reads on a text filter, signature dates, number text with separators, the `myAlerts` cap. Load before writing a `/gql` read.
- [gotchas/gql-writes-and-saves.md](gotchas/gql-writes-and-saves.md) — writing over `/gql`: links a save can clear, stale versions, field-id spellings, `history` changes, an update on a signed entry that saves nothing, alerts a receiver cannot clear, money values. Load before writing a `/gql` create or update.
- [gotchas/forms-fields-options-time.md](gotchas/forms-fields-options-time.md) — forms, relationships, option colors and checkbox layouts, windowed reads by date, true/false radios stored `"false"` at create. Load when a screen reads or writes a form, a relationship, a select, a yes/no radio or a date.
- [gotchas/formulas-save-order.md](gotchas/formulas-save-order.md) — what a PRE_EDIT formula sees in a save. Load when a screen's save must keep a formula's effect.
- [gotchas/manage-walks-and-method.md](gotchas/manage-walks-and-method.md) — copied code, live-region announcements, versions written by post-save formulas, slow or failing builds, multi-unit pages, reloads between builds, a console line on the first load after a publish, read deadlines, unload guards, a block's read after a save, an endpoint's unit behind a BlueStep One page. Load when a build, a reload or a save's version behaves oddly, or when a screen spans several units.
- [gotchas/permissions-users-staff.md](gotchas/permissions-users-staff.md) — rights, one refused part of a load, a refused start-up read, staff users, *Temporary login* and signed-out sessions. Load when deciding who may see or do what, or when a save is refused.
- [gotchas/reports-pages-search-nav.md](gotchas/reports-pages-search-nav.md) — placing a component on a page, page contexts, filters, lists built from the day's entries, nav bars and menus, list sorting, drafts across reloads. Load when a component is a page, a list or a nav piece.
- [gotchas/live-checks-probes-testing.md](gotchas/live-checks-probes-testing.md) — a component repo's `.scratch/` folder. Load before a probe, a live check or a fixture capture.
- [gotchas/tooling-windows-b6p.md](gotchas/tooling-windows-b6p.md) — the type check (`--files` on tests, a syntax error hiding type errors), `node --test` and `.tsx`, Node warnings, time zones in tests on Windows. Load when the type check or a component's tests misbehave.
