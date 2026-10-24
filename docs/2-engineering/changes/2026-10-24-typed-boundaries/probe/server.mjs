#!/usr/bin/env node
// SPDX-FileCopyrightText: 2026 Bruno Guilhermo de Barros Valério
// SPDX-License-Identifier: AGPL-3.0-only
// The T07 probe server: a stdio MCP server (JSON-RPC 2.0, one message per line) with one tool, submit,
// which answers "ok". It logs each call's text length and SHA-256 to $PROBE_LOG (/probe-out/server.log), so run.sh can compare
// what the server received with what the CLI's stream carries (Q2). Started as "ygg" (Q1) or, from the
// leaf's own config, as "evil", which first leaves a marker file (Q3).
import { createHash } from "node:crypto";
import { appendFileSync, writeFileSync } from "node:fs";
import { createInterface } from "node:readline";

const name = process.argv[2] ?? "ygg";
const logFile = process.env.PROBE_LOG ?? "/probe-out/server.log";
const log = (rec) => {
  try { appendFileSync(logFile, JSON.stringify({ server: name, ...rec }) + "\n"); } catch {}
};
if (name === "evil") {
  try { writeFileSync("/work/EVIL-STARTED", "the leaf's own MCP server ran\n"); } catch {}
}
log({ event: "started" });

const send = (msg) => process.stdout.write(JSON.stringify({ jsonrpc: "2.0", ...msg }) + "\n");
const tool = { name: "submit", description: "Hand back your output. Call it once, with the object you were asked for.",
  inputSchema: { type: "object", properties: { output: { type: "object" } }, required: ["output"] } };

createInterface({ input: process.stdin }).on("line", (line) => {
  let m;
  try { m = JSON.parse(line); } catch { return; }
  if (m.id === undefined) return; // a notification
  switch (m.method) {
    case "initialize":
      return send({ id: m.id, result: { protocolVersion: m.params?.protocolVersion ?? "2025-06-18",
        capabilities: { tools: {} }, serverInfo: { name, version: "0.0.1" } } });
    case "tools/list":
      return send({ id: m.id, result: { tools: [tool] } });
    case "ping":
      return send({ id: m.id, result: {} });
    case "tools/call": {
      const text = m.params?.arguments?.output?.text;
      const t = typeof text === "string" ? text : JSON.stringify(m.params?.arguments ?? null);
      log({ event: "call", tool: m.params?.name, length: t.length, sha256: createHash("sha256").update(t).digest("hex") });
      return send({ id: m.id, result: { content: [{ type: "text", text: "ok" }] } });
    }
    default:
      return send({ id: m.id, error: { code: -32601, message: `unknown method ${m.method}` } });
  }
});
