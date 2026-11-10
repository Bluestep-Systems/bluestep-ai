# ADR: Propagate a change from a source org to its target orgs, assisted and opt-in

**Status:** Accepted (2026-11-09). Ships in bluestep-tools 0.48.0: the `/b6p-propagate` skill,
the `change-log.sh` hook (Claude Code only), the close-out page and one line in each task skill.

**Date:** 2026-11-09

**Amends:** [`platform-mcp-integration.md`](platform-mcp-integration.md) — component sync stays on
the b6p CLI, but a propagation now also creates objects and writes script config through the
gateway (and through `/gql` in a browser tab), under a plan-level approval echo.

**Relates to:** [`content-sanitization-for-public-tooling.md`](content-sanitization-for-public-tooling.md)
(nothing project-specific ships; project values live in the workspace's config file),
[`instruction-tree-and-claude-only.md`](instruction-tree-and-claude-only.md) (one close-out page
that the task skills point at), [`cross-tool-plugin-output.md`](cross-tool-plugin-output.md) (a
hook event Cursor and Codex do not get), [`machine-bootstrap.md`](machine-bootstrap.md) (node is
part of the machine setup).

## Context

Teams that work in one org and then carry the change to others had no tool for it. A sandbox
cloned from production, a template or config org that feeds client orgs, a sibling org: in each
case the change was moved by hand, and nothing recorded which artifacts a change had touched.

A change is rarely code only. It often adds a field, an option list or a query too. A `b6p` push
carries only code, and it cannot cross orgs: b6p sends the push to the org of the local
`U######` folder and takes only the WebDAV id from a target URL, its cleanup deletes in the URL's
org, and `b6p deploy` exits 0 when every target fails (`bluestep-reference` ›
`gotchas/cross-org-push.md`). Objects keep their ids across orgs only when they existed at a
clone, so ids are no match key.

An internal org-to-org sync app already exists. It audits objects by FID and offers fixes, but
it writes the source's compiled files straight into the target as the live version, with no
overwrite check and no restore point; it can delete target files without asking; it does not
check that a fix goes to a configured target; it logs in with a username and password; and it
runs inside one org, so it cannot ship as a public skill.

## Decisions

1. **Our own assisted skill, built on b6p and the gateway.** Code moves only with b6p, from the
   target's own folder. Objects and config move through the gateway procedure. The internal sync
   app gave the matching rule (FID, then name; fields by formulaId) and nothing else. A `b6p
   promote` command was weighed (a deterministic guard, usable without an agent) and set aside:
   the move must also create forms, fields, option lists and queries, which the gateway already
   does, and the move should be guided.
2. **Opt-in per project, never in the way.** The flow is on only where `.bluestep/project.json`
   exists. Nothing in it blocks, delays or questions a push, a publish, a gateway write or an
   edit, in any org: changes straight in a target, work with no task and work on several tasks at
   once are allowed. Nothing assumes a git repo or a remote.
3. **One source, ordered targets.** Sandbox to production is the one-target case. A change goes
   target by target, one plan and one approval each; targets whose plans have the same shape may
   be approved together after the first; a failure stops the rollout and it resumes later.
4. **A log written by a hook, claimed at close-out.** A `PostToolUse` hook (and `PostToolUseFailure`, for a `b6p` push that exits 1 after going live) appends one line per
   platform write to `.bluestep/changes.jsonl`, tagged with the session. There is no per-machine
   "active task": it breaks with tasks in parallel. When work closes, the agent that did it names
   the task and proposes which entries belong to it, and the user confirms. One question then
   decides whether the change goes to the targets now, later, or not at all.
5. **The logging hook fails open and needs only node.** Unlike the guardrails, which fail closed,
   this hook never blocks and never prints; on any error it logs nothing. It runs one inline
   `node -e` instead of the jq → python3 → python → node chain, and does not source the shared
   input library, whose no-parser path blocks. It is wired on Claude Code only: Cursor and Codex
   have the agent append the same line itself. A change made in the platform UI is written by the
   agent on every surface, once the user says it is done. A dependency walk at move time catches
   what the log still missed (a UI change nobody mentioned, a machine without node).
6. **The task card is the shared record.** Most projects have no git remote, so the log stays on
   one machine. The card holds the list in a long-text custom field, plain ASCII, one section per
   target, parseable back; the task description, inside a fenced block, is the fallback. Not
   comments (a task has many) and not checklists (the ClickUp connector cannot write them). The
   card is written through the user's ClickUp connector, the user's own token, or text to paste.
7. **The org guard is the U-number, checked at every write.** Every push goes from a folder whose
   U-number is the step's target; every gateway write carries that `org` and an
   `expectedVersion` read from it in the same move, so a write sent to another org is refused
   when versions differ; every `/gql` write checks the tab's host. Hosts are never compared: one
   org can answer on several.
8. **A plan is an approval echo.** A plan that lists every concrete call in one target is approved
   once (`mcp-platform-authoring.md` step 5). A call not in it, a changed argument or another org
   needs its own yes; deletes keep their own echo.
9. **Copy what can be read, list the rest.** The gateway reads do not return every create setting
   of a form, field, query, record type or MEFR, and on the newer platform release line endpoint
   and MR settings, `disabled` and `runImmediate` are reachable only through `/gql` in a tab the
   agent drives. Objects are created with what the user's surface can read; each carries a "check
   by hand" list. Nothing waits on a browser.
10. **Scheduled formulas are named per write.** With `runImmediate` on, every save of a scheduled
    formula runs it once per matching record — a publish with or without a code change, a
    config-only write, the flag's own save. The plan reads the flag in the target and marks each
    such write; when it cannot be read, it says the write may run the formula.
11. **A delete moves as a delete, last, by a person when no tool exists.** No gateway tool deletes
    a script on either release line, and a deleted script can still answer a read by id. So a
    delete step runs after the code, in reverse dependency order, with its own yes; it stops when
    something in the target still uses the object; a script's last code is backed up first; and
    "gone" means a lookup by name finds nothing.

## Consequences

- A change in a source org can reach several targets with its objects, config and code, with
  restore points named before anything is written.
- Two kinds of hook now ship: guardrails that fail closed, and one logger that fails open.
- Cursor and Codex users get the skill and the close-out, but the log depends on the agent
  appending lines until their after-tool hook events are proven.
- Some settings stay manual until the platform's MCP reads return every create setting.
