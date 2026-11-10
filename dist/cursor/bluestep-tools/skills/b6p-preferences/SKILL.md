---
name: b6p-preferences
description: See and change your own preferences for the BlueStep (B6P) tools in this project, in one place — how Claude writes its answers to you (short and plain, or complete and technical), when a long conversation gets summarized, and whether the client-data guard is on. Use when the user asks how to change how Claude answers, wants shorter, simpler or more technical answers, asks what they can configure or where a setting lives, or says "preferences", "settings" or "configuration" about these tools. Changes only the user's own settings file, never the team's.
---

# /b6p-preferences — your settings for the BlueStep tools, in one place

Some settings are each person's own: how answers read, when a long conversation is summarized. They
live in `.claude/settings.local.json`, which is git-ignored, so a change here never reaches a teammate.
This skill shows them in plain words, says what each one does, and changes the one the user picks.
`/b6p-setup` asks the first one when it brings a project up to date, using the card below.

Everything the user reads is plain: what the setting does and what changes for them, never a key
name unless they ask. Ask with clickable options (`AskUserQuestion` in Claude Code), one card at a
time.

## On Cursor or Codex

Neither has output styles or these settings. Write nothing. Say that the project's `AGENTS.md`
already tells the agent to match the user's level, and where a personal preference goes instead:
on Cursor, a User Rule (Customize → Rules), on Codex, `~/.codex/AGENTS.md`. Offer the line to paste
for shorter answers: "Answer briefly in plain, everyday words; lead with the answer; no file names,
ids or technical terms unless I ask." Then stop.

## Step 1 — Read what is set now (read only)

On Claude Code, read `.claude/settings.local.json`, `.claude/settings.json` and `~/.claude/settings.json`. A missing
file is fine. The value that applies is the first one found in that order.

| Preference | Key | How to show it |
|---|---|---|
| How Claude answers | `outputStyle` | `bluestep-tools:Plain answers` → "Short and plain"; `default` or not set → "Complete and technical"; any other name → that name, as the user's own choice |
| When a long conversation is summarized | `autoCompactWindow` | a number of tokens, shown as "at about 400K" |
| Client-data guard | `phi-guard` plugin | installed or not, and on or off here (see step 3) |

Show one short table, preference · now · what it does, then ask "What do you want to change?" with
the three preferences and **Nothing**.

## Step 2 — How Claude answers

Before the card, say in one line: "This is only for you, in this project, and you can change it
again any time with `/b6p-preferences`." Then ask "How do you want Claude to answer you?" with these
two options, each with its example, in the user's language:

- **Short and plain** (recommended if you don't write code) — the answer first, in everyday words,
  with no file names or technical terms unless you ask. Example: "The list is empty because the unit
  was renamed. Check its name on the platform."
- **Complete and technical** (recommended if you write code) — more detail: files, lines of code and
  commands. Example: "`staffQuery.search` filters on `unitName` (`app.ts:6`); after the rename it
  returns `[]`."

When the current value is another style the user picked (for example `Concise`), add a third
option, **Keep `<name>`**.

On the answer, merge one key into `.claude/settings.local.json` — create the file with just that key
if it is absent, never touch its other keys:

- Short and plain → `"outputStyle": "bluestep-tools:Plain answers"` (exactly this; any other spelling
  matches no style and Claude falls back to none).
- Complete and technical → `"outputStyle": "default"`.
- Keep → write nothing.

Never write this key to Claude Code's `.claude/settings.json`: the team shares that file. Say it applies from the
next session. Both choices keep the project's answering rules (lead with the answer, ask only what
is yours to decide, a last list of what was not checked); the short style pushes further toward
brevity and everyday words.

## Step 3 — The other two

- **When a long conversation is summarized.** Claude re-reads the whole conversation on every
  message; past a point it summarizes the older part so answers stay accurate and cheaper. The team
  default is about 400K tokens, in Claude Code's `.claude/settings.json`. Offer **Keep the team default** or
  **Set my own** (a number from 100000 to 1000000); a personal value goes in
  `.claude/settings.local.json` as `autoCompactWindow` and wins over the team's, for this user only.
- **Client-data guard (`phi-guard`).** It blocks an edit that looks like real client data. Check
  whether it is installed and whether this project turns it off, the way
  `../b6p-setup/references/enablement-claude-code.md` (relative to this file) says. Not installed →
  offer it and, on a yes, hand over the install from that file; never run it. Turned off here →
  say so: that is a team decision in Claude Code's `.claude/settings.json`, so this skill does not change it.

## Report

One line per change: what changed, for whom (only you, this project) and when it applies (next
session). If nothing changed, say so in one line.