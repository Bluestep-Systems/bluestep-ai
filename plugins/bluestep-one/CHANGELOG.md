# Changelog — bluestep-one

All notable changes to the `bluestep-one` plugin are documented here. The other plugins in this
repo keep their own changelogs; the root `CHANGELOG.md` lists them.

## [0.3.1] — unreleased (ships with bluestep-tools 0.51.0)

### Changed

- **`/bluestep-one:setup`** denies the b6p 1.0 push form too: the project settings it writes deny
  `b6p script push` (and the `--yes --json` forms of both commands) next to `b6p push`, which b6p
  1.0 keeps only as a deprecated alias. A present settings file gets the missing entries added on
  the next run. The build skill names both forms.

## [0.3.0] — 2026-11-17

### Added

- **`/bluestep-one:build <name> --clone` creates or registers a component that is not in
  `components[]`.** It looks the name up first (`customComponents`, a read) and registers a match,
  once the user confirms it, instead of making a twin. A lookup by a user who is not super is not
  taken as proof of a miss. Only a true miss is created, with one `createCustomComponent` from a
  signed-in tab, after the user's yes in chat. The create carries the catalog fields (summary,
  description and use cases, all required by the skill), `provisionRepo: true`, the plugin's seed
  files and an `X-Request-Id`, so a lost answer is resent, not re-applied. A taken repo name goes
  back to the lookup, never to a second create under another name. The config entry is written only
  after the clone and `git checkout draft` worked, checked against the schema, never twice for one
  id. A component already listed is cloned and set up as before. Without `--clone` the skill still
  stops and names the component. → `build/types.md` › *A new component repo*.
- **Seed files** in `templates/component/`: a minimal `component.json`, `src/Component.tsx` and a
  README with an empty *Copied from other repos* table, beside the existing `tsconfig.json` and
  `.gitignore`. A seeded create commits exactly these five.
- **`build/publish.md` › *The row's catalog fields*:** a publish copies `component.json`'s `slots`
  to the row and sets `publishedSha`, but not the summary, description or use cases;
  `updateCustomComponent` sets them.
- **Pattern: the built-in entry screen plus something.** Where the *Build* panel forks a form's
  entry view, that the fork is bound to the form at once (every publish is live there), what its
  repo holds, `--clone` on it, and how to unbind it.

### Changed

- **Setting up an existing repo** replaces files only on the untouched platform scaffold, judged by
  the files (the sample `title` prop), not the commit message, which a seeded create and a fork
  share. Any other repo keeps every file, and a README without a *Copied* table gets an empty one so
  the copies check runs.
- The manual fallback names the *Build* panel's real path to a new custom component, which makes
  the repo at once.

## [0.2.1] — 2026-11-16

### Changed

- **G-229 and `build/publish.md`:** a build that fails with "source fetch answered 404" has been
  seen to fail up to seven times in a row and then build with nothing changed, and its second log
  line can read "not found" at `postResult`. The agent still stops after four failed tries and
  hands the build to the *Build* tab: each try costs minutes and one of the org's three build
  slots, and the user may choose to keep trying.

## [0.2.0] — 2026-11-16

### Added

- **Rules:** a component that writes a Manage form decides each required field in writing, from
  the form definition, never from its own list; one control per Manage field type, with Manage's
  own words, kept in a map.
- **Patterns:** a component bound on several forms reads only the form being opened; rules shared
  by many forms go in one component with a table keyed by the form's alias; linking a page hidden
  from the menu (`sites.compositePages()`, `navigation.hrefFor`); a read-only component maps fields
  by `formulaId` over `/gql`, since the host's form definition leaves out fields locked Hidden;
  linking an entry held by its `/gql` id with `formEntries.keyFor` and `entryHref`.
- **Gotchas, host and kit:** print mode overrides a component's table layout; `records.listTypes()`
  lists only the person type's sub-types; a hand-drawn print copy must apply `fieldControl`; a
  month input needs more than a canvas's 150 px; `B6pCheckbox` has no invalid, required or id; the
  form kit's "Remove my signature" that a `/gql` save does not apply; the built-in entry screen
  drops merge-report and static-content fields; a canvas export colours links, the host does not.
- **Gotchas, `/gql`:** a number field's `valueAsString` has thousands separators; `myAlerts` stops
  at 100 rows; an `auto` alert cannot be cleared by its receiver; a money field takes only
  "$4.00"-style text and no negatives.
- **Gotchas, method and rights:** a block's read after the screen's save; a BsJs endpoint's "this
  unit" query follows the Manage session's unit, not the BlueStep One page's; a refused read at a
  screen's start.

### Changed

- **G-171:** a *Signature* filter takes `d<` and `d<=` too, and since web 26.11.09 its date value
  is ISO 8601 with an offset; Manage's own date text is refused. A component that sent the old
  value fails to load.
- **G-239** now covers every refused part of a load (a side form, one record among many, one form
  in a joint query), not only a side form.
- **P-14:** a Manage on-open rule keyed on a security group has no client-side source; a BsJs
  endpoint that answers for the caller's groups does.
- **G-320:** read the dialog's opener in a layout effect, and where to move focus when the action
  removes the opener.
- `build/typecheck.md`: run `required.mjs` from the folder that holds the component repos.

### Fixed

- **The UX probe no longer counts a kit switch named by its `<label for>` as unnamed.**
  `tools/ux-probe.js` read `labels` only for inputs, selects and text areas; it now reads them for
  every labelable element, buttons included.

## [0.1.2] — 2026-11-16

### Fixed

- **The required-fields check (gate 3b) no longer fails a component that checks through the form
  kit.** `tools/required.mjs` counted only a literal `host.formEntries.validate(`, so a component
  started from the built-in entry screen, which calls the kit's `useFormValidation(host.formEntries,
  …)` and `validateAll()` before the save, failed with "call host.formEntries.validate( before each
  write". The hook calls that same host check, so a file that calls the hook and `validateAll()`
  now counts; the hook without `validateAll()` still does not. `build/typecheck.md` and gate 3b say
  so.

## [0.1.1] — 2026-11-10

### Added

- Gotchas: `B6pSaveFooter` truncates its error line; a `class` on a canvas `x-import` can replace
  a kit part's classes; a `formEntries` read filtered on a text field is slow the first time per
  value; `updateFormRow` on a signed entry can answer success and save nothing; a "[Federation
  Runtime] … shared singleton" console line on the first load after a publish, with the screen
  working. These entries carry no id; the reference's manifest says so and lists their topics.

### Changed

- **A build that fails with "source fetch answered 404" can need several tries** (G-229,
  `build/publish.md`, gate 5 of `/bluestep-one:build`). The second try is no longer "always"
  enough: after two failures sign out and in again, after four hand the build to the *Build* tab
  and report it. An org runs at most three builds at once.
- **P-76 now describes** inline warning links (each link drawn in its own words) and a reasoned
  refusal without the closing "Please try … again.", done by small helpers in each component
  repo, not by the kit.
- **G-91:** on one form checked, the built-in entry screen now draws relationship fields as
  pickers; whether its save writes the link is not checked yet.
- `build/ux-check.md` says what to do when the only console error is that first-load federation
  line.

## [0.1.0] — 2026-11-05

> **First release.** Build BlueStep One custom components with Claude Code. Claude Code only; the
> build, the publish and the checks after them need the Claude desktop app's built-in browser pane.
> Needs `bluestep-tools` (version `>=0.46.0`), which Claude Code installs with it. If you also use
> BlueStep's internal migration tooling, wait for its release that drops its own build skill before
> you install this, so the build skill and the mod do not load twice.

### Added

- **`/bluestep-one:setup`.** Checks the machine (`bluestep-tools` and its token, Node.js, git
  access to each component's repo, the desktop app's browser pane and a sign-in on the BlueStep One
  host), then writes the project files that are missing, starting with `.claude/bluestep-one.json`
  and `AGENTS.md`. It never overwrites a file; `--check` writes nothing.
- **`/bluestep-one:build`.** One component from commit to a checked screen, one gate at a time:
  fresh types, type check and tests, copies and required-fields checks, push to `draft`, build
  from a signed-in tab, publish on your yes, served-commit check, a measured UX check against the
  project's thresholds, a live check on your own test record, and a design check against an
  approved canvas export for a UI change. Also sets up a new component repo (`--clone`).
- **`/bluestep-one:reference`.** An on-demand reference, one line per file in its `SKILL.md`: the
  build and publish steps, the checks, rules and patterns for any component, and gotchas grouped
  by topic (the host and the kit, `/gql` reads and writes, forms and fields, rights, pages and
  lists, tooling).
- **Tools.** Node scripts for the gates: fetching the type files, the type check, the copies and
  required-fields checks, the UX probe and its check, and serving a canvas export beside the live
  screen. Each has tests under `tools/test/`.
- **Tab guard (hook and mod).** A `PreToolUse` hook on the browser script tools lets a lone build
  or publish of a listed component go on to the normal permission prompt and puts any other
  GraphQL mutation to you first. Where mods are on, the mod shows a card with what the script
  saves and the site the tab is on; after Proceed, the hooks do not ask again.
- **Project config.** `.claude/bluestep-one.json` (`one.host`, `one.gitHost`, `components`,
  `testPrefix`, optional `uxCheck`), with its schema and the `uxCheck` defaults in `config/`.
- **Templates.** A component repo's starting files, a change's `design-audit.md`, and the canvas
  `launch.json`.
