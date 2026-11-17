# {{displayName}}

{{summary}}

`component.json` names the component (`{{repoName}}`), the slots it can be placed in and its
props. `src/Component.tsx` is the module the host loads.

## Setting up a checkout

- **Types.** The seven `.d.ts` files of the BlueStep One host are downloaded, never committed:
  each is served at `https://<host>/one/<name>.d.ts` (`component-host`, `form-kit`, `ui`,
  `ui.primitives`, `ui.structural`, `ui.tokens`, `ui.icons`). Keep them in one shared `types`
  folder beside the component repos and link this repo's `types` to it; `tsconfig.json` maps
  every import through that link. Download them again before every publish.
- **No dependencies.** The build refuses a repo that declares any. Editor tooling goes in a
  `package.json` that `.gitignore` keeps out of git:
  `npm i -D typescript@'>=7' @types/react@19 @types/react-dom@19`.
- **Local only.** Add `types` and `.scratch/` to `.git/info/exclude`, and stage files by name.

## Copied from other repos

Repos share no code. A file copied from another repo gets a row here: its path in this repo, its
path in the source repo (starting with that repo's folder), and the source commit it was taken
from.

| Copy | Source | Source commit |
| --- | --- | --- |
