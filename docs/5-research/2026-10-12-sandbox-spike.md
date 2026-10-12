---
title: Sandbox spike
status: draft
date: 2026-10-12
related: [../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md, ../2-engineering/plans/2026-10-12-yggdrasil-v0/tasks.md]
style: research
---

# Sandbox spike

Task v0-T001 of the [v0 plan](../2-engineering/plans/2026-10-12-yggdrasil-v0/tasks.md). It answers
spec §16 items 1, 5, 6 and 7 on the operator's machine. Every result below was run on 2026-10-12;
the commands are in the appendix. Items marked **[ANALYSIS]** are reasoning, not results.

**Status:** option 1 (native rootless Podman) still has to be tried; it needs `sudo`, so it is a
founder step. The decision at the end is a proposal until then.

## Starting point

| What | Value |
|---|---|
| Host | WSL2, Ubuntu 22.04, kernel 6.18.40.1-microsoft-standard-WSL2 |
| `podman` client | 5.8.3 (Homebrew, first on the `PATH`) |
| Engine | 5.7.1 in the Podman Desktop machine, reached through `CONTAINER_HOST` and the connection `podman-wsl` (`/mnt/wsl/podman-sockets/podman-machine-default/podman-root.sock`) |
| Rootless | `false` |
| devcontainer CLI | `@devcontainers/cli@0.89.0` (released 2026-08-31) |
| Compose provider | `podman-compose` 1.6.0 |
| Probe image | `docker.io/alpine/git@sha256:a0a417df5d855143303637b7aa85e248281294cb3554f0f1e9c5bbc83417e764` (built 2026-09-27) |

The test tree is an umbrella at `~/ygg-spike/umbrella` with the leaf as a real submodule: the leaf's
`.git` is the file `gitdir: ../.git/modules/leaf` (review focus 3).

## Results

### Item 7: registry credentials

The first probe run failed before any mount test:

```
ERROR: (gcloud.auth.docker-helper) There was a problem refreshing your current auth tokens ...
Error: error getting credentials - err: exit status 1, out: ``
FAIL container: podman run failed:
```

The pull used an empty auth file and passed. The `podman run` that followed resolved the image again
and called the host's gcloud credential helper. Adding `--pull=never` to every `run` and `create`,
and exporting `REGISTRY_AUTH_FILE` and `DOCKER_CONFIG` pointing to the empty auth directory, stopped
it.

[ANALYSIS] Passing `--authfile` to `pull` is not enough. The sandbox driver must set the isolated
auth for every engine call, and run with `--pull=never` after an explicit pull. The devcontainer CLI
runs `podman` itself, so it must inherit the same environment.

### Item 6: mounting the leaf

| Option | Result |
|---|---|
| Leaf under the WSL home, mounted into the machine | `Error: statfs /home/brunogbv/ygg-spike/umbrella/.git/modules/leaf: no such file or directory` (as expected) |
| 1. Native rootless Podman in WSL | **not tried yet** (founder step; see below) |
| 2a. Umbrella on `/mnt/wsl` (shared between WSL distros) | the mount works; `/mnt/wsl` is a 7.6 GB **tmpfs**, emptied when WSL shuts down |
| 2b. Umbrella on `/mnt/c` (the Windows drive) | the mount works; drvfs shows every file as owned by uid 1000 |
| 3. Copy in and out (`--mode copy`) | `PASS copy-roundtrip`, exit 0 |

[ANALYSIS] Option 2a can't hold the instance tree, because it doesn't survive a WSL restart. Option
2b is durable, but git over drvfs is slow and its permissions are fake. Neither is a good home for
the tree.

**Finding: the leaf must keep its path relative to the umbrella.** The submodule's git directory sets
`core.worktree = ../../../leaf`. With the leaf at `/work`, `git log` failed with
`fatal: cannot chdir to '../../../leaf'`. Mounting the leaf at `/u/leaf` and the git directory at
`/u/.git/modules/leaf` (read-only) fixed it: `git log` and `git status` work, and writing a hook
fails.

### Item 5: rootful engine

The engine is rootful. Two consequences showed up in the probes:

- **`--userns=keep-id` does nothing on a rootful engine.** A file created in the mount was owned by
  uid 0 on the host, and git refused the repo (`detected dubious ownership`). Running the container
  with `--user 1000:1000` (and `HOME=/tmp`) fixed both: files are owned by 1000, git works.
- **A container escape lands as root in the Podman machine.** That machine is a WSL distro on the
  same kernel as the host distro, and it can reach `/mnt/wsl` and the Windows drive.

### Item 1: devcontainer CLI, compose, `NET_ADMIN`, egress

With the umbrella on `/mnt/wsl`, `devcontainer up` with a compose file (the work container, Postgres
17, SeaweedFS) returned `"outcome":"success"`. Inside, as uid 1000: git works with the mirrored
layout, files are owned by 1000, and `db:5432` and `s3:8333` are reachable.

The **first** `devcontainer up` hung for more than 8 minutes at `podman compose ... up -d` after
starting one of three services. Running `podman-compose` by hand, with and without an open stdin,
worked; the next `devcontainer up` succeeded in seconds. The cause is unknown.

**Finding: `cap_add: [NET_ADMIN]` on the work container lets the agent switch the firewall off.**
Podman passes added capabilities to non-root users, so uid 1000 had `CapEff: 0000000000001000`
(`NET_ADMIN`). After root applied the egress rules:

```
example-blocked
anthropic-http-404
agent-flushed-policy      # uid 1000 ran: iptables -P OUTPUT ACCEPT
example-REACHED-after
```

**The fix that worked: a firewall sidecar.** A `fw` service holds `NET_ADMIN` and owns the network
namespace; the work container joins it with `network_mode: "service:fw"` and gets no added
capabilities. Root in `fw` applied deny-all output with an allowlist (DNS, `api.anthropic.com` on
443, `db`, `s3`):

```
CapEff: 0000000000000000          # uid 1000 in work
example-blocked
anthropic-http-404                # connected; 404 is the API's answer to a bare HEAD
db-reachable
CapEff: 00000000800405fb          # root in work: no NET_ADMIN (bit 12)
root-cannot-install               # apt can't reach the mirrors
example-still-blocked
```

[ANALYSIS] The firewall must live where the agent's user and the work container's root can't reach
it. The allowlist resolves names to IP addresses when it is applied (`api.anthropic.com` resolved to
one address), so a long run needs it re-applied, or a published IP range.

## Option 1, for the founder

Native rootless Podman inside WSL removes both the rootful risk and the mount problem. On this
distro it is blocked by two things:

- `newuidmap` and `newgidmap` are missing: `Error: command required for rootless mode with multiple
  IDs: exec: "newuidmap": executable file not found in $PATH`. They come from the `uidmap` package
  (`sudo apt install uidmap`, candidate `1:4.8.1-2ubuntu2.2`).
- **`netavark` is missing**, and neither Homebrew nor Ubuntu 22.04 packages it. Podman 5 needs it for
  compose networks, where services find each other by name. Without it, services must share one pod
  and talk over `localhost`.

The root mount is also `private` (Podman warns that `/` is not a shared mount).

[ANALYSIS] Two ways to get there: a second WSL distro with a current Podman (Fedora ships Podman 5
with `netavark`), holding the instance tree in its home; or `uidmap` here plus one pod per sandbox,
with no compose network. The first keeps compose as designed.

## Proposed decision

Pending option 1:

- **Driver:** `devcontainer` (CLI 0.89.0), because it passed items 1 and 7 with a live mount, with
  these rules: mirror the umbrella layout in the mounts; run as the operator's uid; firewall in a
  sidecar; isolated auth and `--pull=never` for every engine call.
- **Engine:** rootless Podman in WSL if option 1 works; otherwise the rootful machine with the
  mitigations above, recorded as an accepted risk.
- **Mount method:** `mount` if option 1 works; otherwise `copy`, because the paths the machine can see
  are either temporary or slow.

## Spike B: `claude -p --bare` and project hooks (item 2)

Task v0-T002. Claude Code `2.1.284` (released 2026-09-28) in `node:22-bookworm-slim`, with
`DISABLE_AUTOUPDATER=1`, run as uid 1000. The leaf holds two traps: `.claude/settings.json` with a
`SessionStart` and a `PreToolUse` hook, plus `enableAllProjectMcpServers: true`, and `.mcp.json` with
a server. Each writes a marker file when it runs.

`claude --help` for this version says of `--bare`: "Anthropic auth is strictly ANTHROPIC_API_KEY or
apiKeyHelper via --settings (OAuth and keychain are never read)."

**Dry run without any token** (the session fails to authenticate, so no tool runs):

| Mode | Flags | Markers | Exit |
|---|---|---|---|
| `control` | none | `.hook-session`, `.mcp-ran` | 1 |
| `protected` | `--bare` | none | 0 |
| `flags` | `--setting-sources user --strict-mcp-config` | none | 0 |

[ANALYSIS] The control run shows how early a hostile repo gets in: its `SessionStart` hook and MCP
server ran **before authentication**, in a session that then failed. Blocking them can't wait for the
first tool call.

**Finding: the plan's marker check passed a partial hit.** `ls a b c && exit 1 || exit 0` exits 0 when
only some markers exist, because `ls` fails on the missing one. The first dry run found two markers
and still exited 0. The script now checks each marker.

**Still to run (founder, with the token):** all three modes with `CLAUDE_CODE_OAUTH_TOKEN`, to see
whether `--bare` authenticates with it, to catch the `PreToolUse` marker, and to record a real result
event.

The result event (`type: result`) carries `usage.input_tokens`, `usage.output_tokens`,
`usage.cache_creation_input_tokens`, `usage.cache_read_input_tokens`, `num_turns`, `total_cost_usd`,
`duration_ms` and `duration_api_ms` (field names from the dry run; values come from the founder run).

## Spike C: OpenRouter and `privacy: strict` (item 3)

Task v0-T003. OpenRouter's [provider routing documentation](https://openrouter.ai/docs/features/provider-routing)
names two settings in the request's `provider` object:

- `data_collection`: `"allow"` (default) or `"deny"`: "Control whether to use providers that may store
  data."
- `zdr`: `true`: "Restrict routing to only ZDR (Zero Data Retention) endpoints." Account-wide ZDR and
  guardrails still apply; the request flag can only add to them.

Both can also be set account-wide in OpenRouter's privacy settings. The factory's OpenRouter account
is dedicated to it (budget doc), so account-wide settings affect nothing else.

**`opencode` passes them, but not for every request.** `opencode-ai@1.18.32` (released 2026-09-21)
was pointed at a local listener that records request bodies (no real key, nothing sent to
OpenRouter). With `options.provider` set on the model:

| Requests | Model | `provider` sent |
|---|---|---|
| 6 | `openai/gpt-4o-mini` (the configured model) | `{"data_collection":"deny","zdr":true,"allow_fallbacks":false}` |
| 3 | `google/gemini-nano-banana-2.1` (opencode's small model, for titles) | **none**, and the body holds the user's prompt |

With `"small_model": "openrouter/openai/gpt-4o-mini"` added, all 9 requests carried the settings.

[ANALYSIS] Without `small_model`, a run marked `privacy: strict` would still send the prompt to a
provider chosen with no privacy filter. The adapter must set it, and must check that every model the
tool may call has the settings.

**Still to run (founder, with the key):** `openrouter-strict.sh <model>`, one real request with the
settings, to record which provider served it and the cost.

## Appendix: scripts

### `sandbox-check.sh`

The plan's probe script, with the item 7 fix (lines marked `# fix`).

```bash
#!/usr/bin/env bash
# sandbox-check.sh --mode mount|copy <leaf>: probes for spec §16 items 1, 5, 6 and 7. Throwaway.
set -uo pipefail
[ "${1:-}" = --mode ] || { echo "usage: sandbox-check.sh --mode mount|copy <leaf>"; exit 2; }
MODE="$2"; LEAF="$(realpath "$3")"; UMB="$(dirname "$LEAF")"; NAME="$(basename "$LEAF")"
IMG="docker.io/alpine/git@${GIT_IMAGE_DIGEST:?set GIT_IMAGE_DIGEST to the pinned digest}"
fail=0; pass() { echo "PASS $1"; }; warn() { echo "WARN $1: $2"; }; bad() { echo "FAIL $1: $2"; fail=1; }
AUTH="$(mktemp -d)"; echo '{}' > "$AUTH/auth.json"        # item 7: never the host's registry credentials
export REGISTRY_AUTH_FILE="$AUTH/auth.json" DOCKER_CONFIG="$AUTH"   # fix: also for run/create
podman pull -q --authfile "$AUTH/auth.json" "$IMG" >/dev/null && pass registry-isolated || bad registry-isolated "pull failed"
[ "$(podman info --format '{{.Host.Security.Rootless}}')" = true ] && pass rootless || warn rootless "engine is rootful; record the mitigation"
if [ "$MODE" = mount ]; then
  # The leaf's .git file points to ../.git/modules/<name>; mount the umbrella's module dir read-only at that path.
  RUN=(podman run --rm --pull=never --entrypoint sh -v "$LEAF:/u/$NAME:Z" -v "$UMB/.git/modules/$NAME:/u/.git/modules/$NAME:ro,Z" -w "/u/$NAME" "$IMG" -c)   # fix: --pull=never
  out="$("${RUN[@]}" 'test -f README.md && echo leaf-ok; git log -1 --format=%s && echo git-ok; touch ../.git/modules/'"$NAME"'/hooks/x 2>/dev/null && echo hook-written || echo hook-refused')" \
    || { bad container "podman run failed: $out"; exit 1; }
  grep -qx leaf-ok <<<"$out" && pass mount-leaf || bad mount-leaf "leaf not visible"
  grep -qx git-ok <<<"$out" && pass git-readable || bad git-readable "git log failed through the submodule .git file"
  grep -qx hook-refused <<<"$out" && pass gitdir-readonly || bad gitdir-readonly "a hook could be written"
  own="$(podman run --rm --pull=never --entrypoint sh --userns=keep-id -v "$LEAF:/w:Z" "$IMG" -c 'touch /w/.probe && stat -c %u /w/.probe')" \
    || { bad keep-id "podman run failed"; own=""; }
  [ "$own" = "$(id -u)" ] && pass keep-id-ownership || bad keep-id-ownership "file owner '$own', want $(id -u)"
  rm -f -- "$LEAF/.probe"
else
  cid="$(podman create --pull=never --entrypoint sh "$IMG" -c 'sleep 600')" && podman start "$cid" >/dev/null || { bad container "create failed"; exit 1; }
  podman cp "$LEAF/." "$cid:/w" && podman exec "$cid" sh -c 'test -f /w/README.md && echo changed > /w/out.txt' \
    && podman cp "$cid:/w/out.txt" "$AUTH/out.txt" && grep -qx changed "$AUTH/out.txt" && pass copy-roundtrip || bad copy-roundtrip "copy in, change, copy out failed"
  podman rm -f "$cid" >/dev/null
fi
exit $fail
```

### `devcontainer.json` and `compose.yaml` (sidecar firewall)

```json
{
  "name": "ygg-spike",
  "dockerComposeFile": "compose.yaml",
  "service": "work",
  "workspaceFolder": "/u/leaf",
  "updateRemoteUserUID": false,
  "shutdownAction": "stopCompose"
}
```

```yaml
services:
  fw:
    image: docker.io/library/golang@sha256:cf7e928cb9edc2ed8b3cc6fe77ee1ee30b9fea28149564c8840097321a7600ea
    command: ["sleep", "infinity"]
    cap_add: [NET_ADMIN]
  work:
    image: docker.io/library/golang@sha256:cf7e928cb9edc2ed8b3cc6fe77ee1ee30b9fea28149564c8840097321a7600ea
    command: ["sleep", "infinity"]
    user: "1000:1000"
    environment: { HOME: /tmp }
    network_mode: "service:fw"
    depends_on: [fw]
    volumes:
      - /mnt/wsl/ygg-spike/umbrella/leaf:/u/leaf:Z
      - /mnt/wsl/ygg-spike/umbrella/.git/modules/leaf:/u/.git/modules/leaf:ro,Z
  db:
    image: docker.io/library/postgres@sha256:aa90e97ee862e558111d34cfb8b2c4bec768c2b039fb791341686928560263b3
    environment: { POSTGRES_PASSWORD: spike-only }
  s3:
    image: docker.io/chrislusf/seaweedfs@sha256:aba492e2a4e4c90bff795745e8e660affa1f09e7650f5981bd7bccd1a06cd931
    command: ["server", "-s3"]
```

Run with `REGISTRY_AUTH_FILE` and `DOCKER_CONFIG` set to the empty auth directory:

```bash
npx -y @devcontainers/cli@0.89.0 up --docker-path podman --docker-compose-path podman-compose \
  --workspace-folder /mnt/wsl/ygg-spike/umbrella/leaf --config "$SPIKE/dc/devcontainer.json"
```

The spike installed `iptables` in `fw` at run time. A real image would ship it.

### Egress rules (run as root in `fw`)

```bash
ns=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
iptables -P OUTPUT DROP
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -p udp -d "$ns" --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp -d "$ns" --dport 53 -j ACCEPT
for ip in $(getent ahostsv4 api.anthropic.com | awk '{print $1}' | sort -u); do
  iptables -A OUTPUT -p tcp -d "$ip" --dport 443 -j ACCEPT
done
for s in db s3; do
  for ip in $(getent ahostsv4 "$s" | awk '{print $1}' | sort -u); do iptables -A OUTPUT -d "$ip" -j ACCEPT; done
done
```

The Postgres password `spike-only` is a throwaway value for a container that existed for minutes.

### `hook-check.sh` (spike B)

```bash
#!/usr/bin/env bash
# hook-check.sh control|protected|flags: exit 1 if any marker appears, 0 if none. Founder-run (uses the token).
#   control    no protection: the planted hooks and MCP server must run (exit 1)
#   protected  --bare
#   flags      --setting-sources user --strict-mcp-config (skips project settings and .mcp.json)
set -uo pipefail
rm -f -- /work/.hook-session /work/.hook-tool /work/.mcp-ran
case "${1:?control|protected|flags}" in
  control) EXTRA=() ;;
  protected) EXTRA=(--bare) ;;
  flags) EXTRA=(--setting-sources user --strict-mcp-config) ;;
  *) echo "unknown mode $1"; exit 2 ;;
esac
claude -p "Use the Bash tool to run: ls /work. Then reply with the output." \
  --allowedTools "Bash(ls:*)" "${EXTRA[@]}" --output-format stream-json --verbose > "/work/.run-$1.jsonl" 2>"/work/.run-$1.err"
echo "claude exit: $?"
tail -1 "/work/.run-$1.jsonl" | head -c 300; echo
found=0
for m in /work/.hook-session /work/.hook-tool /work/.mcp-ran; do [ -e "$m" ] && { echo "marker: $m"; found=1; }; done
exit $found
```

The image:

```dockerfile
FROM docker.io/library/node@sha256:efd0ab5780c2d9ab1f0f869571a00d5edb17793bff4cce4a2792e3eb0ffc7562
ENV DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
RUN npm install -g @anthropic-ai/claude-code@2.1.284 && npm cache clean --force
COPY hook-check.sh /usr/local/bin/hook-check.sh
```

### `openrouter-strict.sh` (spike C)

```bash
#!/usr/bin/env bash
# openrouter-strict.sh <model>: one request with no-training, no-retention settings. Founder-run.
set -euo pipefail
set -a; . ~/.config/ouroboric/factory.env; set +a
MODEL="${1:?a cheap model id from https://openrouter.ai/models}"
curl -sS --fail-with-body https://openrouter.ai/api/v1/chat/completions \
  --header @<(printf 'Authorization: Bearer %s\n' "$OPENROUTER_API_KEY") \
  --header 'Content-Type: application/json' \
  --data "{\"model\":\"$MODEL\",\"max_tokens\":5,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with OK.\"}],\"provider\":{\"data_collection\":\"deny\",\"zdr\":true,\"allow_fallbacks\":false},\"usage\":{\"include\":true}}" \
  | python3 -I -c 'import json,sys; d=json.load(sys.stdin); print("provider:", d.get("provider")); print("usage:", d.get("usage"))'
```

### `opencode.json` for the capture test (spike C)

```json
{
  "provider": {
    "openrouter": {
      "options": { "baseURL": "http://127.0.0.1:18765/api/v1", "apiKey": "dummy-not-a-key" },
      "models": {
        "openai/gpt-4o-mini": {
          "options": { "provider": { "data_collection": "deny", "zdr": true, "allow_fallbacks": false } }
        }
      }
    }
  },
  "small_model": "openrouter/openai/gpt-4o-mini"
}
```

Item 7, once more: in a fresh shell, `podman run --pull=never` on a `localhost/` image still called
the gcloud credential helper. Only the isolated `REGISTRY_AUTH_FILE` and `DOCKER_CONFIG` stopped it.
