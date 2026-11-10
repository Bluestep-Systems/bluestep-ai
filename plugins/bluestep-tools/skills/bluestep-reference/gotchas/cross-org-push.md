---
description: "b6p sends a push to the org named by the local U###### folder, not to the org in a target URL: a push or deploy aimed at another org writes into the folder's own org (or into a different component there), its cleanup deletes files in the URL's org, and `b6p deploy` reports success when every target failed — one org per folder, push with --file"
---

# A push never crosses orgs

## Symptom

A component is pulled from one org (`U<org-a>/<Component>/`) and pushed with the URL of the same
component in another org, to copy a change across. The push reports success, but the other org
is unchanged. Instead, the folder's own org was written to, or a different component there that
happens to own the same WebDAV id. Platform-only files may also have been deleted in the other
org. A `b6p deploy` to several orgs prints "Deploy complete!" and exits 0 even when targets
failed.

## Cause

- **The host comes from the folder.** b6p resolves the org from the `U######` folder name and
  maps it to that org's host. From a URL it takes only the WebDAV id. The upload goes to
  `<folder's org>/files/<id from the URL>/`.
- **Two orgs can share ids.** A sandbox cloned from production keeps the ids of everything that
  existed at the clone. A mismatched push then lands on the folder's own copy without any error.
  With different ids, it lands on whatever component of the folder's org owns that WebDAV id.
- **The cleanup step uses the URL.** After uploading, the push lists the target URL's files and,
  on a yes, deletes the platform-only ones there, in the other org.
- **`deploy` swallows failures.** Each target's error is logged and the loop moves on; the
  command still ends with "Deploy complete!" and exit 0.

## Rule

- **One org per folder.** To change a component in another org, pull that org's copy into its
  own `U<other-org>/<Component>/` folder, make the change there, and push with `--file` from
  that folder. Both copies can sit side by side in one workspace.
- **Never** push a URL from another org, use `--root` with another org's URL, or use
  `b6p deploy` to roll a change out across orgs.
- **Before a push to a specific org,** check that the folder's `U######` is that org's
  U-number, not its host: one org can answer on several hosts.
- **Ids are not a match key across orgs.** Match objects by FID or exact name in each org; see
  [field-ids-not-portable-across-propagation.md](field-ids-not-portable-across-propagation.md).
