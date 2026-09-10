# core — rules for the model

Layer 1 rule set for repos that are not BlueStep components. Ships with the `core-tools` plugin;
a project picks it explicitly. Nothing here repeats what the harness already does. Each rule names
the design section it comes from (the `agent-workflow-efficiency` design in the `code` workspace) or is marked *verify*.

## Reading (§ 8)

1. **Load things when you need them, not up front.** Keep paths and identifiers; open the file when
   the task reaches it. Do not pre-read a folder "to be safe".
2. **Narrow question, narrow tool.** For a count, a line, a key, or one symbol, use the shell:
   `grep -c`, `grep -n`, `sed -n 'A,Bp'`, `jq`. Reading a whole file to answer one question is the
   single largest avoidable cost measured (211 unbounded reads over 25 KB were 17.9 MB in 30 days).
3. **Read a range of a big file, never the whole file.** Over about 300 lines, find the section
   first (grep, headings, symbol), then read with offset and limit. Read whole only when you will
   edit most of it.
4. **Prefer symbol navigation to grep-then-read** when a code-intelligence tool is available
   (go to definition, find references). If it is not, say so once and fall back to grep. *verify:
   task 6 measures whether this holds quality.*
5. **Ask an MCP for what the task needs, not the whole record.** ClickUp: fetch the last N comments
   or one comment by id, never the full thread to answer one question (p90 18 KB per call, 17 MB in
   30 days). Same rule for any connector that can page or filter.
6. **Screenshot last.** For text and structure use `read_page`, `get_page_text` or `find`. Take a
   screenshot only when the question is visual, and scale it down when layout is all you need
   (each full screenshot is about 164 KB).

## Delegating (§ 7)

7. **Delegate when there is a lot to read and little to report back.** A subagent that sweeps many
   files and returns a conclusion is the right shape. Ask it for a summary, not the file dumps.
8. **Do not delegate a short lookup.** Under about three reads, do it inline. A subagent pays its own
   startup on every turn.
9. **Do not fan out ordinary coding work.** One implementer per task, in its own context, when the
    task's reads would otherwise bloat the main session. Parallel agents are for breadth-first
    research, not for a change that touches three files.
10. **Every delegation states four things:** the objective, the output format, which tools and
    sources to use, and the boundaries (what not to touch, when to stop).

## Sessions (§ 5) — a person acts, you raise it at the moment it applies

11. **One task per session.** When the user starts something unrelated, say so and offer: write
    the handoff into the task file, then `/clear`. Do not silently carry two tasks.
12. **Keep the task file current.** If `.claude/tasks/<slug>.md` exists, write decisions into its
    *Decisions* section as they are made and update *State* before stopping. If it does not exist and
    the work will span sessions, offer to create it from the template in design § 5.
13. **After two failed corrections on the same point, stop.** Say that a clean session with a
    rewritten prompt is likely to do better than a third attempt, and offer the handoff.
14. **Before a large new step in a long session**, suggest `/compact <focus>` naming what to keep.
    Do not suggest compaction right after the user returns from a break; suggest `/clear` instead
    (cold compaction re-reads the whole history uncached, § 6.5).
15. **When the user is abandoning an approach**, suggest `/rewind` rather than `/compact` (§ 6.5).
16. **If you notice a model or effort change mid-session**, mention once that it re-reads the whole
    conversation (§ 6.5). Do not repeat it.
17. **Edits to CLAUDE.md, AGENTS.md or any rule file take effect only after `/clear`, `/compact` or
    a restart.** Say so when you make one, and verify rule changes in a fresh session (§ 6.5).

## Not rules (measured and dropped, so nobody re-adds them)

- *Never read a file twice* — built into the harness; 0.8% of reads (§ 8).
- *Group independent tool calls* — already in the system prompt; not movable by a rule (§ 8).
- *Don't `cd` into the current folder* — about 130 K tokens in 30 days, immaterial (§ 8).
- *Cache warming, TTL changes* — 99.4% of requests already arrive inside the TTL (§ 6.5).
