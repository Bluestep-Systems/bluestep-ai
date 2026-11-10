#!/bin/bash
# change-log: record platform writes for /b6p-propagate. PostToolUse, Claude Code only.
#
# Not a guardrail: it never blocks, never asks, and never prints (stdout or stderr). Every path
# ends in `exit 0`. It writes only in a workspace that turned the flow on: the first
# `.bluestep/project.json` found walking up from the session folder. Each logged write becomes
# one JSON line appended to `.bluestep/changes.jsonl` next to that file; the line format is in
# skills/b6p-propagate/references/change-log.md.
#
# What it logs (in an org listed in project.json):
#   - a gateway invoke_org_tool call whose inner tool is not a read (PostToolUse only: an MCP error
#     result goes to PostToolUseFailure and wrote nothing);
#   - a `b6p ... push` run through Bash or PowerShell whose --json result says pushed:true. Also on
#     PostToolUseFailure: b6p exits 1 on a publish that went live with type-check diagnostics or
#     kept platform-only files, and Claude Code reports any non-zero exit there, with the output
#     inside `error` after an `Exit code N` line;
#   - a browser javascript_tool script holding a GraphQL mutation (org mapped later by host).
#
# Needs node (the machine setup installs it). Without node, or on any parse or write error, it
# logs nothing and lets the call through; /b6p-propagate's dependency walk is the net for missed
# writes. Unlike the guardrails it does not use lib/hook-input.sh, whose no-parser path blocks.

INPUT=$(cat 2>/dev/null) || exit 0

# Cheap filter before starting node: most Bash calls are not b6p pushes.
case "$INPUT" in
  *invoke_org_tool* | *b6p* | *mutation*) ;;
  *) exit 0 ;;
esac

command -v node >/dev/null 2>&1 || exit 0

printf '%s' "$INPUT" | node -e '
const fs = require("fs");
const path = require("path");
let raw = "";
process.stdin.on("data", (c) => (raw += c)).on("end", () => {
  try { run(JSON.parse(raw)); } catch (e) { /* fail open: never block, never print */ }
});

const READ_PREFIXES = ["list_", "get_", "describe_", "lookup_", "read_", "find_", "inspector", "run_", "trigger_", "available_", "graphql_query"];
// Write tools of both platform release lines: inner tool -> [type, op]. Anything else -> unknown.
const WRITE_TOOLS = {
  form: ["form", "change"], batch_fields: ["field", "change"], field: ["field", "change"],
  option_list: ["option_list", "change"], option_list_item: ["option_list", "change"],
  create_option_list: ["option_list", "create"], update_option_list: ["option_list", "change"],
  view: ["view", "change"], update_view_criterion: ["view", "change"], create_mefr: ["mefr", "create"],
  record_type: ["record_type", "change"], delete_record_type: ["record_type", "delete"],
  attach_category_forms: ["record_type", "wire"], folder: ["folder", "change"], document_folder: ["folder", "change"],
  create_script: ["script", "create"], update_script: ["script", "change"], write_script_draft: ["script", "change"],
  script_forms: ["script", "wire"], script_queries: ["script", "wire"], script_field_access: ["script", "wire"],
  script_record_types: ["script", "wire"], add_forms: ["script", "wire"], remove_forms: ["script", "wire"],
  add_queries: ["script", "wire"], remove_queries: ["script", "wire"], add_field_access: ["script", "wire"],
  remove_field_access: ["script", "wire"], add_record_types: ["script", "wire"], remove_record_types: ["script", "wire"],
  set_category_requirement: ["script", "wire"], set_permissions: ["permission", "change"],
  grant_permission: ["permission", "change"], revoke_permission: ["permission", "change"],
  form_permission: ["permission", "change"], reorder_form_fields: ["form", "change"], update_pagelet: ["form", "change"],
};

function findConfig(start) {
  let dir = path.resolve(start || process.cwd());
  for (;;) {
    const f = path.join(dir, ".bluestep", "project.json");
    if (fs.existsSync(f)) return f;
    const up = path.dirname(dir);
    if (up === dir) return null;
    dir = up;
  }
}

function normOrg(o) {
  const m = String(o || "").match(/^U?(\d+)$/i);
  return m ? "U" + m[1] : null;
}

function firstTopId(o, depth) {
  if (!o || typeof o !== "object" || depth > 6) return null;
  if (typeof o.topId === "string") return o.topId;
  for (const v of Object.values(o)) { const r = firstTopId(v, depth + 1); if (r) return r; }
  return null;
}

// Class part of a topId per type, to pick the created object out of a response that names others.
const CLASS_PREFIX = { form: "1000001_", view: "1000019_", option_list: "1000012_", record_type: "1000003_" };

function findTopId(o, prefix, depth) {
  if (!o || typeof o !== "object" || depth > 6) return null;
  if (typeof o.topId === "string" && o.topId.startsWith(prefix)) return o.topId;
  for (const v of Object.values(o)) { const r = findTopId(v, prefix, depth + 1); if (r) return r; }
  return null;
}

// A create-or-update tool: create when it says so, or names a parent and no own id.
function isCreate(inner, a) {
  if (typeof a.action === "string") return a.action.toUpperCase() === "CREATE";
  if (inner === "view") return !a.viewId && !!a.formId;
  if (inner === "option_list") return !a.listId && !!a.name;
  if (inner === "record_type") return !a.recordTypeId && !!a.parentId;
  return false;
}

function fidOf(id, args) {
  const m = String(id || "").match(/__FID_([A-Za-z0-9_]+)/);
  if (m) return m[1];
  const alt = (args && Array.isArray(args.altIds) ? args.altIds : []).find((a) => a && a.key === "FID");
  return alt ? String(alt.value) : null;
}

function lastJsonBlock(s) {
  // Drop what follows the last "}" (an "EXIT=0" line an agent adds, a prompt), then take the outermost
  // object that parses to the end.
  const all = String(s || "");
  const text = all.slice(0, all.lastIndexOf("}") + 1);
  for (let i = text.lastIndexOf("{"); i >= 0; i = text.lastIndexOf("{", i - 1)) {
    try { return JSON.parse(text.slice(i)); } catch (e) { /* keep looking */ }
  }
  return null;
}

function run(d) {
  const cfgFile = findConfig(d.cwd);
  if (!cfgFile) return;
  const cfg = JSON.parse(fs.readFileSync(cfgFile, "utf8"));
  const roles = {};
  if (cfg.source && cfg.source.org) roles[normOrg(cfg.source.org)] = ["source", cfg.source.name || null];
  for (const t of cfg.targets || []) if (t && t.org) roles[normOrg(t.org)] = ["target", t.name || null];

  const tool = String(d.tool_name || "");
  const input = d.tool_input || {};
  // A failed call wrote nothing, except a b6p push that exited 1 after going live.
  if (d.hook_event_name === "PostToolUseFailure" && tool !== "Bash" && tool !== "PowerShell") return;
  let e = null;

  if (/__invoke_org_tool$/.test(tool) && /bluestep-gateway/.test(tool)) {
    const inner = String(input.tool || "");
    if (!inner || READ_PREFIXES.some((p) => inner.startsWith(p))) return;
    const org = normOrg(input.org);
    if (!org || !roles[org]) return;
    const resp = Array.isArray(d.tool_response) ? d.tool_response : [];
    let body = null;
    try { body = JSON.parse((resp[0] && resp[0].text) || "null"); } catch (err) { body = null; }
    if (body && (body.error || body.errors)) return;
    // Some tools nest their arguments under their own name ({ form: {...} }, { view: {...} }).
    const raw = input.arguments || {};
    const args = raw[inner] && typeof raw[inner] === "object" && !Array.isArray(raw[inner])
      ? Object.assign({}, raw, raw[inner]) : raw;
    let [type, op] = WRITE_TOOLS[inner] || ["unknown", "unknown"];
    if (op === "change" && isCreate(inner, args)) op = "create";
    // The id of the object itself: never the parent id a create names (the formId of a new view or field).
    const own = { script: args.scriptId, form: args.formId, field: args.fieldId, option_list: args.listId,
      view: args.viewId, record_type: args.recordTypeId, permission: args.objectId }[type];
    const created = CLASS_PREFIX[type] ? findTopId(body && body.data, CLASS_PREFIX[type], 0) : null;
    // A create of a typed class takes only an id of that class: null beats the id of another object.
    const fallback = CLASS_PREFIX[type] ? null : firstTopId(body && body.data, 0);
    const objId = (op === "create" ? created || fallback : own || args.scriptId ||
      args.objectId || firstTopId(body && body.data, 0)) || null;
    e = { org, source: "gateway", tool: inner, op, type, objId,
      name: args.name || args.displayName || args.mefrName || null, fid: fidOf(objId, args) };
  } else if (tool === "Bash" || tool === "PowerShell") {
    const cmd = String(input.command || "");
    if (!/\bb6p\b[\s\S]*\bpush\b/.test(cmd)) return;
    const text = (d.tool_response && d.tool_response.stdout) || (typeof d.error === "string" ? d.error : "");
    const out = lastJsonBlock(text);
    if (!out || out.pushed !== true) return;
    const p = (cmd.match(/--(?:file|root)\s+("([^"]+)"|\x27([^\x27]+)\x27|(\S+))/) || []);
    const filePath = String(p[2] || p[3] || p[4] || "").split("\\").join("/");
    const m = filePath.match(/(?:^|\/)(U\d+)\/([^/]+)/);
    if (!m || !roles[m[1]]) return;
    e = { org: m[1], source: "b6p", tool: "b6p push", op: /--snapshot\b/.test(cmd) ? "publish" : "draft",
      type: "script", objId: null, name: m[2], fid: null };
  } else if (/__(javascript_tool|browser_batch)$/.test(tool)) {
    const js = String(input.text || "") + (Array.isArray(input.actions) ? input.actions
      .filter((a) => a && a.name === "javascript_tool").map((a) => String((a.input && a.input.text) || "")).join("\n") : "");
    const mm = js.match(/\bmutation\b[^{]*\{\s*([A-Za-z_]\w*)/);
    if (!mm) return;
    const resp = Array.isArray(d.tool_response) ? d.tool_response.map((r) => (r && r.text) || "").join("\n") : "";
    const host = (resp.match(/captured at origin (https?:\/\/[^\s)]+)/) || [])[1] || null;
    e = { org: null, host, source: "gql", tool: mm[1], op: "unknown", type: "unknown", objId: null, name: null, fid: null };
  } else {
    return;
  }

  const at = new Date().toISOString();
  const role = e.org ? roles[e.org] : null;
  const line = Object.assign({ v: 1, kind: "entry", id: at + "-" + Math.random().toString(16).slice(2, 6), at,
    session: d.session_id || null }, e, {
    role: role ? role[0] : null, target: role && role[0] === "target" ? role[1] : null, surface: "claude-code" });
  fs.appendFileSync(path.join(path.dirname(cfgFile), "changes.jsonl"), JSON.stringify(line) + "\n");
}
' 2>/dev/null
exit 0
