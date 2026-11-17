---
description: "b6p 0.8.x sent a push to the org named by the local U###### folder, not to the org in a target URL: a push or deploy aimed at another org wrote into the folder's own org (or into a different component there), and its cleanup deleted files in the URL's org. Since b6p 0.9 a push goes to the draft's git remote, so never copy a draft/.git between orgs. One org per folder, push with --file"
---

# A push never crosses orgs

## Symptom

A component is pulled from one org (`U<org-a>/<Component>/`) and pushed with the URL of the same
component in another org, to copy a change across. The push reports success, but the other org
is unchanged. Instead, the folder's own org was written to, or a different component there that
happens to own the same WebDAV id. Platform-only files may also have been deleted in the other
org. With b6p 0.8.x, a `b6p deploy` to several orgs printed "Deploy complete!" and exited 0 even
when targets failed.

## Cause

The causes below were found with b6p 0.8.x, which pushed over WebDAV. b6p 0.9 pushes over git to
the remote of `draft/.git`, set by the pull that cloned it; whether a URL from another org is still
mapped the same way has not been checked, so the rule stands. What is new with git: a `draft/.git`
copied from another org's folder points the push at **that** org.

- **The host comes from the folder.** b6p resolves the org from the `U######` folder name and
  maps it to that org's host. From a URL it takes only the WebDAV id. The upload goes to
  `<folder's org>/files/<id from the URL>/`.
- **Two orgs can share ids.** A sandbox cloned from production keeps the ids of everything that
  existed at the clone. A mismatched push then lands on the folder's own copy without any error.
  With different ids, it lands on whatever component of the folder's org owns that WebDAV id.
- **The cleanup step uses the URL.** After uploading, the push lists the target URL's files and,
  on a yes, deletes the platform-only ones there, in the other org.
- **`deploy` swallowed failures** (b6p 0.8.x). Each target's error was logged and the loop moved on;
  the command still ended with "Deploy complete!" and exit 0. b6p 0.9 prints one line per target
  and exits 1 when any target failed.

## Rule

- **One org per folder.** To change a component in another org, pull that org's copy into its
  own `U<other-org>/<Component>/` folder, make the change there, and push with `--file` from
  that folder. Both copies can sit side by side in one workspace.
- **Never** push a URL from another org, use `--root` with another org's URL, or use
  `b6p deploy` to roll a change out across orgs.
- **Before a push to a specific org,** check that the folder's `U######` is that org's
  U-number, not its host: one org can answer on several hosts. With b6p 0.9 also check that
  `git -C "U######/<Component>/draft" remote get-url origin` names that org's host.
- **Never copy, move or replace a `draft/.git/` folder** between components or orgs: it decides
  where the push goes.
- **Ids are not a match key across orgs.** Match objects by FID or exact name in each org; see
  [field-ids-not-portable-across-propagation.md](field-ids-not-portable-across-propagation.md).
