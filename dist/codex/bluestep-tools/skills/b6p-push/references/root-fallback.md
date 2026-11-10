# `--root` push — a component never pulled with the CLI (read by `/b6p-push` step 4 when `--file` fails with `Missing metadata`)

`b6p push --file <path>` fails with `Missing metadata` when the component has no local sync metadata: it was never pulled through the CLI, so there is nothing to find the destination from.

**First, if the component was just pulled** (a pull that exited `0` moments ago, often of a component created minutes before): pull it once more with `b6p --yes pull "<DAV URL>"` and retry the step-4 `--file` push. The first pull of a freshly created component can finish without storing its sync record; the second one stores it. A pull with no record writes the platform copy over the local files, so copy any local edit aside first and put it back after.

Otherwise push it explicitly:

```
b6p --yes --json push <target-url> --root "U######/<ComponentName>" [--snapshot --message "<description>"]
```

- `--root` is the component's **root** — the folder that *contains* `draft/`, not `draft/` itself. Pointing at `draft/` gives `Draft folder not found: .../draft/draft`.
- **`<target-url>` must belong to the folder's own org.** b6p sends the push to the org named by the `U######` folder and takes only the WebDAV id from the URL, so a URL from another org writes into the folder's org (or into a different component there) and deletes in the other org (the `bluestep-reference` skill's `gotchas/cross-org-push.md`). With the `bluestep-gateway` MCP server connected, look the script up by name through its `invoke_org_tool` with `org` set to the folder's `U######` (inner tool `lookup_script_by_name`; see the `bluestep-reference` skill's `conventions/mcp-platform-authoring.md`) and use the returned `webDavUrl`. Otherwise ask the user for the WebDAV URL, and refuse one whose org is not the folder's: to change a component in another org, pull that org's copy into its own folder and push from there.
- The step-3 choice still applies: carry `--snapshot --message "<description>"` if the user chose Publish. Do not try argument shapes until one works — a guess can land on a draft-only push that never compiles or goes live.
- Read the result exactly as in step 5. The commands the CLI prints there repeat the target URL and `--root`.
