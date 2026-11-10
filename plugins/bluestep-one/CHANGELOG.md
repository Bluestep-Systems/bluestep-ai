# Changelog — bluestep-one

All notable changes to the `bluestep-one` plugin are documented here. The other plugins in this
repo keep their own changelogs; the root `CHANGELOG.md` lists them.

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
