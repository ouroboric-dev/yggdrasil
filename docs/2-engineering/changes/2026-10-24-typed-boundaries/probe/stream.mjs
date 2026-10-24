#!/usr/bin/env node
// SPDX-FileCopyrightText: 2026 Bruno Guilhermo de Barros Valério
// SPDX-License-Identifier: AGPL-3.0-only
// Reads a CLI's JSON-lines stream and prints the length and SHA-256 of every string found at
// <anything>.output.text, one JSON line each: what the stream carries of the submit calls' input (Q2).
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

const seen = new Set();
const walk = (v) => {
  if (Array.isArray(v)) return v.forEach(walk);
  if (v === null || typeof v !== "object") return;
  if (v.output && typeof v.output.text === "string") {
    const sha256 = createHash("sha256").update(v.output.text).digest("hex");
    if (!seen.has(sha256)) {
      seen.add(sha256);
      console.log(JSON.stringify({ length: v.output.text.length, sha256 }));
    }
  }
  // opencode and Claude Code may also carry a tool's input as a JSON string.
  for (const x of Object.values(v)) {
    if (typeof x === "string" && x.startsWith("{") && x.includes('"output"')) {
      try { walk(JSON.parse(x)); } catch {}
    } else walk(x);
  }
};
for (const line of readFileSync(process.argv[2], "utf8").split("\n")) {
  try { walk(JSON.parse(line)); } catch {}
}
