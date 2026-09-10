---
name: release
description: Ship a core-tools change so installed copies actually get it — bump the plugin version, write the CHANGELOG entry, push, and verify a fresh install serves the new version. Use when a change to skills, agents, lane or tools is finished and needs to reach anyone who installed the plugin.
---

# Release a core-tools version

A push to `main` reaches nobody. Teams install through the `bluestep` marketplace, which is a
pointer in `Bluestep-Systems/bspecs`; what they get is whatever the version in
`.claude-plugin/plugin.json` says, fetched when they update. So shipping is a version bump plus a
verified install, not a merge.

## Steps

1. **Decide the number.** Patch for wording and fixes inside an existing skill; minor for a new
   skill, agent or template, or a change in how one behaves; the plugin is pre-1.0, so nothing here
   is a breaking release yet.
2. **Bump `version` in `.claude-plugin/plugin.json`.** That field is the only thing the runtime
   reads — the git tag, if any, is for people.
3. **Add a `CHANGELOG.md` entry** at the top: `## <version> — <YYYY-MM-DD>`, then what changed in
   plain words and *why*, matching the voice of the entries already there. Name anything a user has
   to do differently.
4. **Update the description in `.claude-plugin/plugin.json`** if the release adds or drops a
   skill — that string is what the marketplace shows.
5. **Commit and push `main`.** One commit for the release; the message says what shipped and why.
6. **Verify from the outside, not from this checkout.** In a scratch directory:
   `claude plugin marketplace update bluestep` then `claude plugin install core-tools@bluestep`, and
   check the installed cache directory is the new version and carries the new files. A fresh session
   there with `--debug` is what proves a skill or agent loads.
7. **Only touch `bspecs` if the pointer itself changed** — a repo rename or a move to another
   marketplace. A version bump never needs a bspecs change.

## Checks

- `python -c "import json;print(json.load(open('.claude-plugin/plugin.json'))['version'])"` matches
  the top CHANGELOG heading.
- The installed cache path under `~/.claude/plugins/cache/bluestep/core-tools/` ends in the new
  version after an install.
- `--debug` in a scratch repo lists the skills and agents you expect, at that version.

<!--
Written by /harness from what this repo actually contains. Edit it freely — /harness will never
overwrite it, and `/harness --check` will tell you if the repo has moved on from what it says.
-->
