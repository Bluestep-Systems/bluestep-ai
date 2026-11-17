---
description: "Compiled draft/.build/*.js files embed the full TypeScript source as a base64 sourcemap, so text removed from the source stays in the repo until a publish rebuilds .build/; with b6p 0.9 every pushed commit also stays in the script's git history on the platform"
---

# Compiled output keeps text removed from source

## Symptom

You remove something from a component's TypeScript (client data, a secret, an old comment) and
commit. A search of the source finds nothing. The text is still in the repo.

## Cause

Each compiled file in `draft/.build/` ends with an inline sourcemap: a
`//# sourceMappingURL=data:application/json;base64,...` comment that holds the full TypeScript
source it was built from. Until `.build/` is rebuilt, the old source rides along inside the
compiled `.js`, base64-encoded.

Plain-text search does not see it, and neither do the client-data checks: they skip `.build/` and
cannot read base64 anyway.

## Fix

1. Fix the TypeScript source.
2. Publish the component with `/b6p-push`, once the user has chosen to publish (a draft save
   does not rebuild `.build/`). With b6p 0.9 the publish builds fresh `.build/` output in your local
   `draft/` and commits it.
3. Commit the rebuilt `.build/` files in the project repo too.

To confirm, decode the sourcemap of each compiled file and search the result. Older commits still
hold the old `.build/` files; cleaning history is a separate decision (see
[client data](../conventions/client-data.md)).

**The platform keeps every pushed commit.** Since b6p 0.9 a script's draft is a git repository on
the platform, and b6p never force-pushes, so text pushed once stays in the script's history there
even after a fixed publish; no b6p command removes it.
