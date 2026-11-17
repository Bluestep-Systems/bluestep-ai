---
description: "Deploying an off-platform Vite/Preact SPA merge report. Since the web release that makes scripts git-only, deploy-lib's WebDAV upload into draft/static/ and snapshot/static/ is refused (HTTP 403): build Vite into the pulled report's draft/static/ and publish with b6p script push --snapshot. Keeps the deploy-lib notes for a server without that release: install from git, the package.json config block (config.deployUrl is camelCase, config.deploypathsuffix/config.builddir are lowercase), npm run deploy -- --build --clean, the auth resolution order (--token-file → BLUESTEP_TOKEN → .env-local → interactive, Authorization: Bearer) and Node 20+. Owns the config-casing issue link (deploy-lib issue #30)."
---

This is the deploy half of the off-platform Vite/Preact SPA merge-report pattern — see
[vite spa merge report](../reference/vite-spa-merge-report.md) for the architecture and when to use it.
**deploy-lib** takes the built `dist/` and uploads it into the report's `static/` folder, so the platform
compiler is never involved.

## Since the git-only release: deploy with b6p

deploy-lib uploads over WebDAV. Once a server has the web release that makes scripts git-only, every
WebDAV write into a script's `draft/` or `snapshot/` is refused with HTTP 403 ("This script is edited
through git; use the BSJS editor or the b6p CLI."), so `npm run deploy` can no longer reach the report.
Whether deploy-lib gets a git-based release is not known yet. Until it does, deploy with b6p 1.0 or later:

1. **Pull the report once** with `/b6p-pull`, so `U######/<Report>/draft/` is a git clone of it. If the
   report still publishes over WebDAV, the pull moves it to git (`/b6p-pull` step 2).
2. **Build into the report's `draft/static/`.** Point Vite's `build.outDir` at that folder (a path
   relative to the Vite project, e.g. `../U######/<Report>/draft/static`) with `build.emptyOutDir: true`,
   so stale content-hashed assets are removed (what deploy-lib's `--clean` did). Or copy `dist/` into it.
   Keep `base: './'` ([vite merge report gotchas](../gotchas/vite-merge-report-gotchas.md)).
3. **Publish with b6p**, through `/b6p-push` (it asks before it publishes):

   ```bash
   b6p --yes --json script push --file "U######/<Report>/draft/scripts/app.ts" --snapshot --message "<description>" --enable-git
   ```

   The platform builds the push from each `tsconfig.json` in the draft (`scripts/`), writes the build
   manifest, and publishes; the Vite output in `static/` holds no TypeScript and no `tsconfig.json`,
   so the platform's build leaves it as it is. A script whose platform `externallyBuilt` setting is on
   (the release's one-time cutover set it on existing bundler-built scripts) skips the build check
   altogether; b6p has no flag for it. The publish is a commit, so the report's history is its git
   history, next to the Vite project's own repository.

This route follows the b6p 1.0 and web release notes; it has not yet been run end to end on a live
report.

## deploy-lib (servers without the git-only release)

### Install deploy-lib from git

deploy-lib is not on npm — install it straight from the upstream git repo:

```bash
npm install git+https://github.com/BlueStep-Platform/deploy-lib.git
```

Upstream: [github.com/BlueStep-Platform/deploy-lib](https://github.com/BlueStep-Platform/deploy-lib).

### package.json config block — CRITICAL casing

deploy-lib reads its settings from npm's `config` env vars. There is **one non-obvious trap**:

- **`config.deployUrl` is camelCase.** deploy-lib reads `npm_package_config_deployUrl`, so the key **must**
  be `deployUrl`. The deploy-lib README shows lowercase `config.deployurl`, which **silently fails** — npm
  preserves the key's case, so a lowercase `deployurl` never populates `npm_package_config_deployUrl` and
  the deploy has no target. This is filed upstream:
  [deploy-lib issue #30](https://github.com/BlueStep-Platform/deploy-lib/issues/30).
- **`config.deploypathsuffix` and `config.builddir` are lowercase** — in both the code and the README. Use
  `"deploypathsuffix": "static"` (uploads land under the report's `static/` folder) and `"builddir": "dist"`
  (Vite's default build output).

A correct `package.json` (placeholders — fill in your report's WebDAV folder and your git remote):

```json
{
  "repository": {
    "type": "git",
    "url": "git+https://github.com/<owner>/<repo>.git"
  },
  "config": {
    "deployUrl": "https://<org>.bluestep.net/files/<id>/",
    "deploypathsuffix": "static",
    "builddir": "dist"
  },
  "scripts": {
    "build": "tsc -b && vite build",
    "deploy": "deploy-lib"
  }
}
```

The `deployUrl` is the report's WebDAV folder (its `.../files/<id>/` root). Keep the default `build` script
that the `preact-ts` template ships (`tsc -b && vite build`) — deploy-lib runs it for you when you pass
`--build`.

### Running the deploy

```bash
npm run deploy -- --build --clean
```

- **`--build`** runs the `build` script first, producing a fresh `dist/`.
- **`--clean`** removes remote files that are not in the new build, so stale content-hashed assets from a
  previous deploy don't accumulate under `static/`.

deploy-lib uploads to **both** `draft/static/` and `snapshot/static/` in one run — the draft copy for
working/testing and the snapshot copy for the served report. That is exactly the WebDAV write the
git-only release refuses.

### Auth resolution order

deploy-lib resolves its credential in this order and stops at the first one it finds:

1. `--token-file <path>` — read the token from a file.
2. `BLUESTEP_TOKEN` environment variable.
3. `.env-local` — a dotenv file holding `BLUESTEP_TOKEN`, read from `process.cwd()`.
4. Otherwise, an **interactive prompt**.

Whichever it resolves, deploy-lib sends it as `Authorization: Bearer <token>`. The BlueStep platform token
works as the bearer token. **Never commit a token or echo its value.**

> **`.env-local` is not `.env.local`.** deploy-lib hardcodes the filename `.env-local` (hyphen) in
> `process.cwd()` — it does **not** read `.env.local` (dot). The trap: the common gitignore globs (`*.local`,
> `.env`, `.env*.local`) do **not** match `.env-local`, so a token file created there is **not** ignored by
> default and can be committed by accident. Either add `.env-local` explicitly to the project's `.gitignore`,
> or prefer `--token-file` pointing outside the repo (or the `BLUESTEP_TOKEN` env var).

## Node 20+ required

Vite 7 and deploy-lib need Node 20+ (b6p itself needs 18+). deploy-lib is ESM and uses Web Crypto, which is not a global until Node 20. On Node 18 the deploy fails with
`crypto is not defined`. Run all `npm`/build/deploy steps under Node 20+ (e.g. via `nvm`). See
[vite merge report gotchas](../gotchas/vite-merge-report-gotchas.md) for this and the other sharp edges.

## See also

- [vite spa merge report](../reference/vite-spa-merge-report.md) — the pattern and architecture this deploy
  workflow serves.
- [vite merge report gotchas](../gotchas/vite-merge-report-gotchas.md) — `base: './'`, `<head>` stripping,
  mount-id match, Node 20+, and the config-key casing recap.
