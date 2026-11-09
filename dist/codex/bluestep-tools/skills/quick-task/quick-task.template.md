# Quick task: <title>

**Type:** <bug fix | small change>
**Component:** <component name>
**Status:** in progress

## Summary

<One line: what needs to change, or the bug.>

## Root cause

<Bugs only. One or two sentences on why the current behavior is wrong. Delete this section for a non-bug change.>

## Approach

<The whole plan — a minimal checklist. Tag each item [PLATFORM] (do on the BlueStep platform first, then pull) or [CODE] (local source edit). Tick items as they're done.>

- [ ] [CODE] ...
- [ ] [PLATFORM] ...

**Sources:** <The bluestep-reference files and the B.d.ts docs (method names) read before writing this approach.>

## Verification

<How the change is checked on the platform once published.>

If the change gates by user, group or permission, check it with at least one non-super user who should pass and one who shouldn't. If the agent can't sign in as them, say before the publish who runs that check (the developer or the client), and don't report the change as verified until it's done.

## Notes

<Anything discovered during implementation that diverged from the plan. Keep this current so the doc stays a faithful record.>
