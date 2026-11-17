---
description: "Compiled draft/.build/*.js files embed the full TypeScript source as a base64 sourcemap, so text removed from the source stays in the repo until the platform rebuilds .build/; every pushed commit also stays in the script's git history on the platform"
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
2. Push the component with `/b6p-push`. With b6p 1.0 the platform rebuilds `.build/` from the fixed
   source on every push and b6p moves your local `draft/` to that build; publish to make it live.
3. Commit the rebuilt `.build/` files in the project repo too.

To confirm, decode the sourcemap of each compiled file and search the result. Older commits still
hold the old `.build/` files; cleaning history is a separate decision (see
[client data](../conventions/client-data.md)).

**The platform keeps every pushed commit.** A script's draft is a git repository on the platform, and b6p never force-pushes, so text pushed once stays in the script's history there
even after a fixed publish; no b6p command removes it.
