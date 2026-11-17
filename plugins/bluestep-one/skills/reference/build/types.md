# The seven BlueStep One types, and a new component and its repo

Load when a component is not in `components[]` yet, when setting up a component repo, when a type
error says the host lost a member, or before any publish.

## The types

A component's types are seven `.d.ts` files the running tenant generates and serves at
`https://<one.host>/one/<name>.d.ts`: `component-host`, `form-kit`, `ui`, `ui.primitives`,
`ui.structural`, `ui.tokens`, `ui.icons`. They are downloaded, never committed and never edited
(the project's settings deny `Edit(types/**)`): the next download overwrites them.

- **Download all seven before every publish**, with
  `node "${CLAUDE_PLUGIN_ROOT}/tools/fetch-types.mjs" --out <shared types folder>`. The host comes
  from `one.host` in `.claude/bluestep-one.json`. One shared folder beside the component repos serves them all.
- **Every file is checked** by the script: it opens with a `/**` comment carrying `GENERATED`, and
  has a top-level `export`. A wrong path answers **200 with the app's `index.html`**, and because
  `skipLibCheck` is on, that would turn into silent `any`. Never grep the body for `<html`: the ui
  types mention `HTMLElement`.
- **A type error that says the host lost a member means your copy is stale.** Re-download before
  debugging it: the contract moves and carries no version stamp. A refresh that *introduces* errors
  is real news; one that clears them was drift.

## A new component repo

A component is a row on the BlueStep One host (`one.host`) with a git repo on `one.gitHost`. The
agent builds and publishes only the ids in `.claude/bluestep-one.json` › `components`, and the tab
guard lets no other through without asking. For a name not listed there,
`/bluestep-one:build <name> --clone` looks it up, creates it only when it does not exist, clones
it, registers it, and sets the checkout up. Every call is a `/gql` POST from a tab signed in to
`one.host` (`/bluestep-tools:bluestep-reference` › `reference/gql-in-a-tab.md` › *The call from a
tab*). A tab on another host gets no write: say which host it is on.

### Look it up first

A read, so no prompt:
`{ user { super } customComponents { id displayName repoName repoProvisioned gitCloneUrl description } }`.
Match the name against `displayName`, ignoring case and treating `-` and `_` as the same. Match the
repo name the create would use against every `repoName` the way the server folds them (every
character outside letters, digits, `_` and `$` counts as `_`), ignoring case as well: a wider match
is asked about, never assumed.

- **One match with a repo** → no create. Show it (display name, repo name, id) and ask whether it is
  the one; register it only on that yes, then clone and set it up as an existing repo (on a no, go
  on as for no match, with a repo name of its own). When its
  `description` is empty (a component made with *New* › *Custom component* has none), offer to fill
  it with `updateCustomComponent` (`build/publish.md` › *The row's catalog fields*), with its own
  yes.
- **One match, `repoProvisioned: false`** → read its `rowVersion`
  (`remoteObjects(ids: ["<id>"]) { ... on CustomComponent { rowVersion } }`), then one
  `updateCustomComponent(inputs: [{ topId, expectedVersion, provisionRepo: true }])`, with the same
  yes and script shape as a create. Then as above.
- **Several matches** → list them and ask which.
- **No match** → create it. When `user.super` is false, the list holds only what this user can
  see, so a miss is not proof: say so in the yes sentence, and let the user confirm the name is
  new.

### The create

`CreateCustomComponentInput` needs only `displayName` on the wire. The skill sends, and requires,
all of these; propose the text ones from the task or ask for them, and never create without them:

- `displayName`: the name users see.
- `repoName`: the kebab-case of the name, lowercase letters, digits and `-`, at most 100
  characters. Treat it as permanent: it names the repo, the clone URL and every checkout. It must
  differ from every other component's repo name by more than its `.`, `-` and `_` characters.
- `summary`, `description`, `useCases` (a list of strings): the catalog and the Build assistant
  read them from the row. A later publish does not copy `component.json`'s summary to the row (it
  does copy the slots); the three change only with
  `updateCustomComponent(inputs: [{ topId, expectedVersion, summary, description, useCases }])`.
- `provisionRepo: true`.
- `seedFiles: [{ path, content }]`: the five files under
  `${CLAUDE_PLUGIN_ROOT}/templates/component/` (`.gitignore`, `tsconfig.json`, `component.json`,
  `README.md`, `src/Component.tsx`), with `{{repoName}}`, `{{displayName}}` and `{{summary}}`
  filled in: JSON-escaped in the `.json` and `.tsx` files, as is in the README. `component.json`'s
  `name` is the repo name.

**The yes.** Say in chat, in one sentence, what will be created and on which host, and that the
repo name is permanent ("I'll create the component *Task Board*, repo `task-board` (permanent), on
`<one.host>`, with its catalog fields and the plugin's starting files."). Run nothing without the
user's yes there. Where mods are on, the plugin's mod then shows one card, once, and its *Proceed*
covers bluestep-tools' guard too. The card shows the script's opening comment cut at about 200
characters, so that sentence says what and where within them. The card shows only in a folder
with `.claude/bluestep-one.json` (bluestep-tools' guard asks in any folder), and in auto mode a
guard's ask can be settled without being shown: the chat yes is the gate.

**The script** opens with the same sentence as a comment, holds the input in a literal
`variables`, writes the mutation out in full, and writes the request id out too, so a resend
carries the same one:

```js
// I'll create the component Task Board, repo task-board (permanent), on <one.host>, with its catalog fields and the plugin's starting files.
const variables = {
  inputs: [{
    displayName: "Task Board",
    repoName: "task-board",
    provisionRepo: true,
    summary: "<summary>",
    description: "<description>",
    useCases: ["<use case>", "<use case>"],
    seedFiles: [
      { path: ".gitignore", content: "<filled template>" },
      { path: "tsconfig.json", content: "<filled template>" },
      { path: "component.json", content: "<filled template>" },
      { path: "README.md", content: "<filled template>" },
      { path: "src/Component.tsx", content: "<filled template>" },
    ],
  }],
};
const query = `mutation ($inputs: [CreateCustomComponentInput!]!) {
  createCustomComponent(inputs: $inputs) { id topId repoName repoProvisioned gitCloneUrl }
}`;
const head = await fetch("/gql", { method: "HEAD", credentials: "same-origin" });
const res = await fetch("/gql", {
  method: "POST",
  credentials: "same-origin",
  headers: {
    "Content-Type": "application/json",
    "B6P-CSRF-TOKEN": head.headers.get("B6P-CSRF-TOKEN"),
    "X-Request-Id": "<a fresh UUID, written out>",
  },
  body: JSON.stringify({ query, variables }),
});
const body = await res.json();
JSON.stringify(body.errors ?? body.data);
```

**The answer.**

- `id` equals `topId` and must match `^[0-9]+___[0-9]+$`. Read `repoProvisioned` and
  `gitCloneUrl`. `repoProvisioned: false` → one provision update as in the lookup, then read again;
  still `false` → stop and report the id.
- **A lost answer** → resend the same script, same `X-Request-Id`: the server replays the first
  answer and makes no twin (P-38). Never a new id on a retry.
- **A taken name** → HTTP 200, `createCustomComponent: null`, code `PRECONDITION`. The exact repo
  name gets "already used by another component"; a name that differs only in `.`, `-` or `_` gets a
  message about a colliding container name. Either way, back to the lookup; never a second create
  under a name the agent picks. When the lookup still finds no match (the owner is a component
  this user cannot see), stop: say the repo name is taken, and ask the user for another one. A
  create under it is a new create, with its own yes.

The new repo is ready: `draft`, its only branch, holds one commit, *Scaffold component*, with
exactly the five seed files.

### Clone, then register

1. Clone `gitCloneUrl`, from the answer or the lookup (the clone URL is also on the component's
   *Settings* › *Source*). The git host is `one.gitHost`, which may differ from `one.host`. Clone with
   `GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git clone <url>`, so git fails at once instead of
   opening a login window that hangs the run. "could not read Username" means no login is saved
   for the git host yet: hand over `git ls-remote <url>` for the user to run in their own
   terminal. Git asks for a username and password (on Windows, in a *Git Credential Manager*
   window); the user types their own BlueStep login on `one.gitHost` (a `b6pt_` token also
   works as the password), and it is saved for every later clone, fetch and push. Never ask for it
   in chat. Then clone again. A 403, or a 404 on a component that exists, means that login cannot
   read the component: ask whoever administers the org for access to it.
2. `git checkout draft`.
3. Only once both worked, add `{ "id": "<id>", "name": "<repoName>", "repo": "<checkout path,
   relative to the project>" }` to `.claude/bluestep-one.json` › `components`: read the whole file,
   add the entry (none when that id is already there), leave every other key as it is, and check
   the result against
   `${CLAUDE_PLUGIN_ROOT}/config/bluestep-one.schema.json` before writing it. A clone that fails
   after a create is reported with the id, and no entry is written; the next `--clone` finds the
   component by the lookup.

### Set up the checkout

A repo the create just seeded already has the plugin's files: skip step 1.

1. **Replace files only on the untouched platform scaffold**: `draft` has one commit,
   *Scaffold component*, **and** its `component.json` has the sample `title` prop (its
   `tsconfig.json` maps only `#component-host`, its `Component.tsx` renders that title, its README
   is the platform's guide). The message alone proves nothing: a seeded create's commit has the same
   one. Then copy `tsconfig.json` and `.gitignore` from `${CLAUDE_PLUGIN_ROOT}/templates/component/`,
   and replace `component.json`, `src/Component.tsx` and the README with the component's own. Any
   other repo keeps every file; a README with no *Copied from other repos* table gets the
   template's empty one, so the copies check runs (`build/typecheck.md`).
2. Link `types` to the shared folder. On Windows `ln -s` makes a plain file, so use a junction:
   `powershell -NoProfile -Command "New-Item -ItemType Junction -Path <repo>\types -Target <shared>\types"`.
   Elsewhere `ln -s ../types types`.
3. Add `types` and `.scratch/` to the repo's `.git/info/exclude` (local, never pushed). The remote
   is the platform's own git, so one `git add .` would otherwise send probe scripts and drafts to
   the build. Stage files by name.
4. **A component repo declares no dependencies**; the build refuses any repo that does. Editor
   tooling goes in a gitignored `package.json`:
   `npm i -D typescript@'>=7' @types/react@19 @types/react-dom@19`.

### When the agent cannot create it

No tab signed in to `one.host`, no yes, or a refusal other than a taken name: say why in one line
and hand over the manual steps. The user creates the component on `one.host`: the *Build* panel ›
*Data* › *Data Structure* › *New* › *Custom component* (name, summary, use cases and repository
name; the repo is made at once and cannot be renamed). Then `--clone` again finds it by the lookup. With no tab at all, the clone, the config entry (its id is the
`<n>___<n>` the list shows) and the set-up above still work by hand.
