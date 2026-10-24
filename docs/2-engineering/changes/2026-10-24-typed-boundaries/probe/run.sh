#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Bruno Guilhermo de Barros Valério
# SPDX-License-Identifier: AGPL-3.0-only
# The T07 probe (change typed-boundaries): one short read-only session per CLI and size, in the current work
# image, with the probe server added as Odin's "ygg" server and a leaf whose own configs name a server "evil".
#   ygg-engine.sh run -- bash run.sh --opencode-model MODEL [--image IMAGE] [--claude-model MODEL]
#                                    [--sizes "16000 300000"] [--dir DIR] [--skip-claude] [--skip-opencode]
# MODEL for opencode is the OpenRouter model id without the openrouter/ prefix (the reviewer's, in factory.yaml).
# IMAGE defaults to the newest localhost/ygg-work image. DIR (default $YGG_BIND/probe-mcp-<time>) must be a folder
# the engine sees at the same path: the bind mount is one. The sessions need CLAUDE_CODE_OAUTH_TOKEN and
# OPENROUTER_API_KEY in the environment; they are passed by name and never printed.
# It answers, per CLI: Q1 did the CLI start "ygg" and let the model call submit; Q2 does the stream carry the
# call's whole input (same length and SHA-256 as the server received); Q3 did the leaf's "evil" server start.
# Everything lands in DIR/out: one stream per session, one server log per session, and summary.txt.
# It costs four paid sessions with the default sizes. It never starts, stops or restarts the engine.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
usage() { sed -n '6,7p' "${BASH_SOURCE[0]}" | sed 's/^# //' >&2; exit 2; }
image="" claude_model="sonnet" oc_model="" sizes="16000 300000" dir="" run_claude=1 run_oc=1
while [ $# -gt 0 ]; do
  case "$1" in
    --image) image="${2:?}"; shift 2 ;;
    --claude-model) claude_model="${2:?}"; shift 2 ;;
    --opencode-model) oc_model="${2:?}"; shift 2 ;;
    --sizes) sizes="${2:?}"; shift 2 ;;
    --dir) dir="${2:?}"; shift 2 ;;
    --skip-claude) run_claude=0; shift ;;
    --skip-opencode) run_oc=0; shift ;;
    *) usage ;;
  esac
done
fail() { echo "probe: $*" >&2; exit 2; }
[ -n "${CONTAINER_HOST:-}" ] || fail "CONTAINER_HOST is not set: run this under ouroboric/scripts/ygg-engine.sh run --"
pod() { podman --url "$CONTAINER_HOST" "$@"; }
[ "$run_oc" = 0 ] || [ -n "$oc_model" ] || fail "--opencode-model is needed (or --skip-opencode)"
[ "$run_claude" = 0 ] || [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] || fail "CLAUDE_CODE_OAUTH_TOKEN is not set"
[ "$run_oc" = 0 ] || [ -n "${OPENROUTER_API_KEY:-}" ] || fail "OPENROUTER_API_KEY is not set"
if [ -z "$image" ]; then
  image="$(pod images --sort created --format '{{.Repository}}:{{.Tag}}' --filter reference=localhost/ygg-work | awk 'NR == 1')"
  [ -n "$image" ] || fail "no localhost/ygg-work image; build one with a smoke run first, or pass --image"
fi
dir="${dir:-${YGG_BIND:-/mnt/wsl/ygg-bind}/probe-mcp-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$dir/probe" "$dir/out"
cp "$here/server.mjs" "$here/stream.mjs" "$here/managed-settings.json" "$dir/probe/"
out="$dir/out"
echo "probe: image $image; folder $dir"

versions="$(pod run --rm "$image" sh -c 'claude --version; opencode --version' 2>&1 || true)"
{ echo "image: $image"; echo "versions:"; printf '  %s\n' "${versions//$'\n'/$'\n  '}"; } > "$out/summary.txt"

prompt() { # SIZE
  cat <<EOF
This session tests a tool, nothing else. Do not read or change any file.
1. Call the tool named submit (it may be listed as mcp__ygg__submit or ygg_submit) exactly once, with the
   argument {"output": {"text": T}}, where T is the word "probe" followed by one space, repeated $(($1 / 6)) times
   (about $1 characters). The exact count does not matter.
2. Then answer in one line: "done", followed by the full names of every MCP tool you have, comma-separated.
EOF
}

# session CLI SIZE: a fresh leaf, one session, its stream in $out/CLI-SIZE.jsonl.
session() {
  local cli="$1" size="$2" leaf="$dir/leaf-$1-$2" log="/probe-out/$1-$2.server.log"
  mkdir -p "$leaf"
  cp "$here/leaf/.mcp.json" "$here/leaf/opencode.json" "$leaf/"
  local run=(podman --url "$CONTAINER_HOST" run --rm -i -v "$leaf:/work" -w /work -v "$dir/probe:/probe:ro" -v "$out:/probe-out"
    -v "$dir/probe/managed-settings.json:/etc/claude-code/managed-settings.json:ro")
  if [ "$cli" = claude ]; then
    local mcp tools="Read,Grep,Glob,mcp__ygg__submit"
    mcp="{\"mcpServers\":{\"ygg\":{\"command\":\"node\",\"args\":[\"/probe/server.mjs\",\"ygg\"],\"env\":{\"PROBE_LOG\":\"$log\"}}}}"
    prompt "$size" | timeout 1800 "${run[@]}" -e CLAUDE_CODE_OAUTH_TOKEN "$image" \
      claude -p --output-format stream-json --verbose --no-session-persistence --setting-sources user \
      --strict-mcp-config --mcp-config "$mcp" --model "$claude_model" --max-turns 6 \
      --tools "$tools" --allowedTools "$tools" --permission-mode dontAsk \
      > "$out/$cli-$size.jsonl" 2> "$out/$cli-$size.stderr" || echo "probe: $cli $size exited $?" >&2
  else
    local conf
    conf="{\"\$schema\":\"https://opencode.ai/config.json\",\"autoupdate\":false,\"share\":\"disabled\",
\"provider\":{\"openrouter\":{\"options\":{\"apiKey\":\"{env:OPENROUTER_API_KEY}\"},\"models\":{\"$oc_model\":{\"options\":{\"reasoning\":{\"effort\":\"high\"}}}}}},
\"small_model\":\"openrouter/$oc_model\",\"agent\":{\"build\":{\"steps\":6}},
\"permission\":{\"edit\":\"deny\",\"bash\":\"deny\",\"webfetch\":\"deny\",\"external_directory\":\"deny\",\"task\":\"deny\",\"question\":\"deny\"},
\"mcp\":{\"ygg\":{\"type\":\"local\",\"command\":[\"node\",\"/probe/server.mjs\",\"ygg\"],\"environment\":{\"PROBE_LOG\":\"$log\"}}}}"
    prompt "$size" | timeout 1800 "${run[@]}" -e OPENROUTER_API_KEY -e OPENCODE_CONFIG_CONTENT="$conf" \
      -e OPENCODE_DISABLE_PROJECT_CONFIG=1 -e OPENCODE_DISABLE_CLAUDE_CODE=1 -e OPENCODE_DISABLE_EXTERNAL_SKILLS=1 \
      -e OPENCODE_DISABLE_AUTOUPDATE=true -e OPENCODE_DISABLE_SHARE=true -e OPENCODE_DISABLE_MODELS_FETCH=true \
      "$image" opencode run --format json -m "openrouter/$oc_model" \
      > "$out/$cli-$size.jsonl" 2> "$out/$cli-$size.stderr" || echo "probe: $cli $size exited $?" >&2
  fi
  answer "$cli" "$size" "$leaf"
}

# answer CLI SIZE LEAF: the three answers for one session, appended to summary.txt.
answer() {
  local cli="$1" size="$2" leaf="$3" log="$out/$1-$2.server.log" calls streamed q1 q2 q3
  calls="$(grep -h '"event":"call"' "$log" 2>/dev/null | grep '"server":"ygg"' || true)"
  streamed="$(node "$dir/probe/stream.mjs" "$out/$cli-$size.jsonl")"
  if [ -n "$calls" ]; then q1="yes ($(echo "$calls" | wc -l) call(s))"; else q1="no (the server got no call; see $cli-$size.stderr)"; fi
  q2="no call to compare"
  if [ -n "$calls" ]; then
    local sha len
    sha="$(echo "$calls" | tail -n 1 | sed 's/.*"sha256":"\([0-9a-f]*\)".*/\1/')"
    len="$(echo "$calls" | tail -n 1 | sed 's/.*"length":\([0-9]*\).*/\1/')"
    if echo "$streamed" | grep -q "$sha"; then q2="yes (the stream holds the whole input: $len characters, same SHA-256)"
    else q2="no (the server got $len characters; the stream holds: ${streamed:-nothing})"; fi
  fi
  if [ -e "$leaf/EVIL-STARTED" ]; then q3="YES: the leaf's evil server started; stop the plan and tell the founder"
  else q3="no (no marker)"; fi
  { echo "$cli, size $size:"; echo "  Q1 $q1"; echo "  Q2 $q2"; echo "  Q3 $q3"; } | tee -a "$out/summary.txt"
}

for size in $sizes; do
  [ "$run_claude" = 0 ] || session claude "$size"
  [ "$run_oc" = 0 ] || session opencode "$size"
done
echo "probe: done; the summary is $out/summary.txt; the streams are beside it (they hold no credential)"
