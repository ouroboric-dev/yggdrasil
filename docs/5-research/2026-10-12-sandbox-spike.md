---
title: Sandbox spike
status: accepted
date: 2026-10-12
related: [../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md, ../2-engineering/plans/2026-10-12-yggdrasil-v0/tasks.md]
style: research
---

# Sandbox spike

Task v0-T001 of the [v0 plan](../2-engineering/plans/2026-10-12-yggdrasil-v0/tasks.md). It answers
spec §16 items 1, 5, 6 and 7 on the operator's machine. The first results were run on 2026-10-12,
and the rootless results on 2026-10-14; the commands are in the appendix. Items marked
**[ANALYSIS]** are reasoning, not results.

**Status:** complete. The decision is at the end of the T001 part, after the rootless results.

## Starting point

| What | Value |
| --- | --- |
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

```text
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
| --- | --- |
| Leaf under the WSL home, mounted into the machine | `Error: statfs /home/brunogbv/ygg-spike/umbrella/.git/modules/leaf: no such file or directory` (as expected) |
| 1. Native rootless Podman in WSL | not taken (see the rootless results below) |
| 2a. Umbrella on `/mnt/wsl` (shared between WSL distros) | the mount works; `/mnt/wsl` is a 7.6 GB **tmpfs**, emptied when WSL shuts down |
| 2b. Umbrella on `/mnt/c` (the Windows drive) | the mount works; drvfs shows every file as owned by uid 1000 |
| 3. Copy in and out (`--mode copy`) | `PASS copy-roundtrip`, exit 0 |
| 4. Umbrella in the WSL home, bind-mounted into `/mnt/wsl`; the machine's rootless engine (2026-10-14) | all six mount probes pass, including file ownership |

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

Both results are about the **root** socket that WSL's `CONTAINER_HOST` points at. The same machine
also has a rootless socket; the rootless results below replace this item's risk.

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

```text
example-blocked
anthropic-http-404
agent-flushed-policy      # uid 1000 ran: iptables -P OUTPUT ACCEPT
example-REACHED-after
```

**The fix that worked: a firewall sidecar.** A `fw` service holds `NET_ADMIN` and owns the network
namespace; the work container joins it with `network_mode: "service:fw"` and gets no added
capabilities. Root in `fw` applied deny-all output with an allowlist (DNS, `api.anthropic.com` on
443, `db`, `s3`):

```text
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

## Rootless results (2026-10-14)

### Option 1: native rootless Podman in Ubuntu

Native rootless Podman inside WSL removes both the rootful risk and the mount problem. On this
distro it is blocked by two things:

- `newuidmap` and `newgidmap` are missing: `Error: command required for rootless mode with multiple
  IDs: exec: "newuidmap": executable file not found in $PATH`. They come from the `uidmap` package
  (`sudo apt install uidmap`, candidate `1:4.8.1-2ubuntu2.2`).
- **`netavark` is missing**, and neither Homebrew nor Ubuntu 22.04 packages it. Podman 5 needs it for
  compose networks, where services find each other by name. Without it, services must share one pod
  and talk over `localhost`.

The root mount is also `private` (Podman warns that `/` is not a shared mount).

With `uidmap`, Ubuntu's systemd already delegates `memory` and `pids` to the user, so rootless
containers here could have memory and process limits. A container escape would land as the
operator's own user, with the whole home directory, including `~/.config/ouroboric`.

### Option D: the Podman machine's rootless engine

On Windows, the founder's default Podman connection is the machine's **rootless** engine
(`ssh://user@…/run/user/1000/podman/podman.sock`). WSL's `CONTAINER_HOST` points at the machine's
root socket instead, which is why item 5 found a rootful engine. The machine also exposes its
rootless socket to WSL, owned by the operator:
`/mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock`.

| Probe, rootless socket | Result |
| --- | --- |
| `podman info` | rootless, Podman 5.7.1, cgroup v2, network backend `netavark`, `pasta` |
| `sandbox-check.sh --mode copy` | `registry-isolated`, `rootless`, `copy-roundtrip`: all PASS |
| `--mode mount`, leaf on `/mnt/wsl` | all six PASS, including `keep-id-ownership`, which needs no `--user` workaround here |
| `--mode mount`, leaf in the WSL home | `Error: statfs /home/brunogbv/ygg-spike/umbrella/leaf: no such file or directory` |
| `--mode mount`, umbrella bind-mounted into `/mnt/wsl` | all six PASS |

The bind mount, run by the founder in Ubuntu, makes the WSL-home umbrella visible to the machine.
`/mnt/wsl` has `shared` propagation, so the mount appears in every WSL distro:

```bash
sudo mkdir -p /mnt/wsl/ygg-bind
sudo mount --bind /home/brunogbv/ygg-spike/umbrella /mnt/wsl/ygg-bind
```

**Item 1 again, rootless,** with the bind-mounted umbrella and the component repos' pinned Go image
(`golang:1.26.7-bookworm@sha256:e8c859f5…`). `devcontainer up` returned `"outcome":"success"`. `fw`
and `work` both need `userns_mode: keep-id`, because a container can join only the network namespace
of a container in the same user namespace. After root in `fw` applied the egress rules:

```text
CapEff: 0000000000000000          # the agent (uid 1000) in work
example-blocked
anthropic-http-404
db-reachable
s3-reachable
git-ok spike                      # git log through the submodule layout
probe-written uid=1000            # owned by brunogbv in the WSL home
CapEff: 00000000800405fb          # root in work: no NET_ADMIN
root-cannot-install
example-still-blocked
```

**Finding: the machine's rootless engine can't set resource limits.** `--memory 64m --pids-limit 50`
stops the container from starting: `crun: open 'memory.max' for writing: No such file or directory`.
The engine lists no cgroup controllers (`CgroupControllers=[]`, manager `cgroupfs`). The machine is a
Fedora 43 container image whose first process is WSL's `init`, not systemd, so there is no user
service to delegate controllers to. A container sees the whole WSL VM (16 CPUs, 15.9 GB). The
machine's own 8-CPU, 2-GiB settings aren't enforced, because all WSL distros share one VM.

[ANALYSIS] Option D keeps compose with named networks and needs no package installs. A container
escape lands as the machine's user, which can reach the Windows drive, `/mnt/wsl` and the
bind-mounted tree, but not the operator's WSL home and its keys. The cost is per-container resource
limits.

## Decision

**Decided 2026-10-14** (founder, option D):

- **Driver:** `devcontainer` (CLI 0.89.0), with `podman-compose` 1.6.0.
- **Engine:** the Podman machine's **rootless** engine, through
  `unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock`. The factory sets it in its
  own configuration, and never relies on the shell's `CONTAINER_HOST`, which points at the root
  socket.
- **Mount method:** `mount`. The instance tree lives in the WSL home, and is bind-mounted into
  `/mnt/wsl` (shared propagation) at boot. The sandbox mounts only the leaf, and its git directory
  read-only, mirroring the umbrella layout.
- **Sandbox rules:**
  - every container uses `userns_mode: keep-id`;
  - the agent runs as the operator's uid, with no added capabilities;
  - the firewall lives in a sidecar that owns the network namespace;
  - every engine call uses the isolated auth and `--pull=never`.
- **Accepted gap for v0:** no per-container resource limits. The spec doesn't require them (§6.2).
  Every run has hard token and turn caps (§7.4), and a memory and processor limit in `.wslconfig`
  caps WSL as a whole. Tracked in the v0 plan's "Carried beyond v0" table.

## Spike B: `claude -p --bare` and project hooks (item 2)

Task v0-T002. Claude Code `2.1.284` (released 2026-09-28) in `node:22-bookworm-slim`, with
`DISABLE_AUTOUPDATER=1`, run as uid 1000. The leaf holds two traps: `.claude/settings.json` with a
`SessionStart` and a `PreToolUse` hook, plus `enableAllProjectMcpServers: true`, and `.mcp.json` with
a server. Each writes a marker file when it runs.

`claude --help` for this version says of `--bare`: "Anthropic auth is strictly ANTHROPIC_API_KEY or
apiKeyHelper via --settings (OAuth and keychain are never read)." Claude Code's
[authentication docs](https://code.claude.com/docs/en/authentication) (read 2026-10-13) confirm it:
"Bare mode does not read `CLAUDE_CODE_OAUTH_TOKEN`. If your script passes `--bare`, authenticate with
`ANTHROPIC_API_KEY` or an `apiKeyHelper` instead." The same page says `ANTHROPIC_API_KEY` outranks
`CLAUDE_CODE_OAUTH_TOKEN`, and that in `-p` mode "the key is always used when present".

[ANALYSIS] The factory runs on the founder's subscription (budget doc, 2026-10-13), so `--bare` is
out. The `flags` mode below is the protection to confirm. A sandbox must never carry
`ANTHROPIC_API_KEY`: if it did, runs would bill per token, silently.

**Dry run without any token** (the session fails to authenticate, so no tool runs):

| Mode | Flags | Markers | Exit |
| --- | --- | --- | --- |
| `control` | none | `.hook-session`, `.mcp-ran` | 1 |
| `protected` | `--bare` | none | 0 |
| `flags` | `--setting-sources user --strict-mcp-config` | none | 0 |

[ANALYSIS] The control run shows how early a hostile repo gets in: its `SessionStart` hook and MCP
server ran **before authentication**, in a session that then failed. Blocking them can't wait for the
first tool call.

**Finding: the plan's marker check passed a partial hit.** `ls a b c && exit 1 || exit 0` exits 0 when
only some markers exist, because `ls` fails on the missing one. The first dry run found two markers
and still exited 0. The script now checks each marker.

**Founder run, 2026-10-14,** with only `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token` on the
Ouroboric subscription) passed into the container:

| Mode | Flags | `claude` exit | Markers | Script exit |
| --- | --- | --- | --- | --- |
| `control` | none | 0 | `.hook-session`, `.hook-tool`, `.mcp-ran` | 1 |
| `protected` | `--bare` | 1 (no credential: 0 API time, $0) | none | 0 |
| `flags` | `--setting-sources user --strict-mcp-config` | 0 | none | 0 |

[ANALYSIS] In an authenticated session, the hostile repo's `PreToolUse` hook (`.hook-tool`) runs in
`control` and doesn't in `flags`. So the flags block all three traps, and the session still works on
the subscription. `--bare` can't authenticate with the token, as the docs say.

The result events (model `claude-sonnet-5-5`, Claude Code's default; 2 turns each):

| Mode | `input_tokens` | `cache_creation_input_tokens` | `cache_read_input_tokens` | `output_tokens` | `total_cost_usd` | `duration_ms` |
| --- | --- | --- | --- | --- | --- | --- |
| `control` | 4 | 5,104 | 25,176 | 94 | 0.0264 | 2,926 |
| `flags` | 4 | 3,134 | 26,776 | 97 | 0.0189 | 2,523 |

[ANALYSIS] On the subscription nothing is billed per token, but the event still reports
`total_cost_usd`, which the adapter can record as the run's API-equivalent cost (spec §5: "On a subscription, the
reported cost is what the run would cost on the API"). The event
also has `modelUsage` (cost per model), `num_turns`, `duration_api_ms`, `is_error`, `api_error_status`
and `permission_denials`, for the ledger and for error handling.

**Decided 2026-10-14:** the `claude-code` adapter authenticates with `CLAUDE_CODE_OAUTH_TOKEN` only,
and runs every session with `--setting-sources user --strict-mcp-config`, not `--bare`. The sandbox's
environment never carries `ANTHROPIC_API_KEY`, and Gleipnir's config validation fails a sandbox that
would. Usage and cost come from the `result` event.

## Spike C: OpenRouter and `privacy: strict` (item 3)

Task v0-T003. OpenRouter's [provider routing documentation](https://openrouter.ai/docs/features/provider-routing)
names two settings in the request's `provider` object:

- `data_collection`: `"allow"` (default) or `"deny"`: "Control whether to use providers that may store
  data."
- `zdr`: `true`: "Restrict routing to only ZDR (Zero Data Retention) endpoints." Account-wide ZDR and
  guardrails still apply; the request flag can only add to them.

Both can also be set account-wide in OpenRouter's privacy settings, where they apply to every key on
the account. The factory's `yggdrasil-factory` key is the account's only key so far (budget doc).

**`opencode` passes them, but not for every request.** `opencode-ai@1.18.32` (released 2026-09-21)
was pointed at a local listener that records request bodies (no real key, nothing sent to
OpenRouter). With `options.provider` set on the model:

| Requests | Model | `provider` sent |
| --- | --- | --- |
| 6 | `openai/gpt-4o-mini` (the configured model) | `{"data_collection":"deny","zdr":true,"allow_fallbacks":false}` |
| 3 | `google/gemini-nano-banana-2.1` (opencode's small model, for titles) | **none**, and the body holds the user's prompt |

With `"small_model": "openrouter/openai/gpt-4o-mini"` added, all 9 requests carried the settings.

[ANALYSIS] Without `small_model`, a run marked `privacy: strict` would still send the prompt to a
provider chosen with no privacy filter. The adapter must set it, and must check that every model the
tool may call has the settings.

**Founder run, 2026-10-14:** `openrouter-strict.sh deepseek/deepseek-v4-flash`. The account's ZDR
toggles were set to "Zero retention only" for every model group.

| Field | Value |
| --- | --- |
| Provider | OpenInference, on OpenRouter's ZDR endpoint list for `deepseek-v4-flash-20260423` |
| Tokens | 87 prompt (80 of them cached by the provider), 5 completion (all 5 reasoning) |
| Cost | $0.0000069 (`is_byok: false`) |

DeepSeek's own API isn't on the ZDR list for this model, and it didn't serve the request.

[ANALYSIS] 80 cached tokens on a first request means the provider reuses computed prompt prefixes
(the endpoint lists `supports_implicit_caching`). Cached tokens bill at a lower rate, so the adapter's
usage capture must keep `cached_tokens` separate from other prompt tokens.

**Decided 2026-10-14:** `privacy: strict` means
`provider: {"data_collection": "deny", "zdr": true, "allow_fallbacks": false}` on every OpenRouter
request, including `opencode`'s `small_model`. The account-wide "Zero retention only" setting is the
floor that no request can lower. The adapter refuses `strict` when it can't set these on every model
the tool may call.

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

The rootless version that passed on 2026-10-14 (the rootful run used the spike-only Go image
`cf7e928c…`, paths under `/mnt/wsl/ygg-spike/umbrella`, and no `userns_mode`):

```yaml
services:
  fw:
    image: docker.io/library/golang@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514
    command: ["sleep", "infinity"]
    userns_mode: "keep-id"
    cap_add: [NET_ADMIN]
  work:
    image: docker.io/library/golang@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514
    command: ["sleep", "infinity"]
    user: "1000:1000"
    userns_mode: "keep-id"
    environment: { HOME: /tmp }
    network_mode: "service:fw"
    depends_on: [fw]
    volumes:
      - /mnt/wsl/ygg-bind/leaf:/u/leaf:Z
      - /mnt/wsl/ygg-bind/.git/modules/leaf:/u/.git/modules/leaf:ro,Z
  db:
    image: docker.io/library/postgres@sha256:aa90e97ee862e558111d34cfb8b2c4bec768c2b039fb791341686928560263b3
    environment: { POSTGRES_PASSWORD: spike-only }
  s3:
    image: docker.io/chrislusf/seaweedfs@sha256:aba492e2a4e4c90bff795745e8e660affa1f09e7650f5981bd7bccd1a06cd931
    command: ["server", "-s3"]
```

Run with `REGISTRY_AUTH_FILE` and `DOCKER_CONFIG` set to the empty auth directory, and
`CONTAINER_HOST` set to the rootless socket:

```bash
export CONTAINER_HOST=unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock
npx -y @devcontainers/cli@0.89.0 up --docker-path podman --docker-compose-path podman-compose \
  --workspace-folder /mnt/wsl/ygg-bind/leaf --config "$SPIKE/dc/devcontainer.json"
```

### `probe.sh` (item 1, run in `work` with `podman exec -i dc_work_1 bash < probe.sh`)

```bash
#!/bin/bash
# Egress and access probes, run inside the work container.
echo "CapEff: $(awk '/^CapEff/{print $2}' /proc/self/status)"
curl -s -m 5 -o /dev/null http://example.com && echo example-REACHED || echo example-blocked
code=$(curl -s -m 8 -o /dev/null -w '%{http_code}' -I https://api.anthropic.com) ; echo "anthropic-http-$code"
(exec 3<>/dev/tcp/db/5432) 2>/dev/null && echo db-reachable || echo db-UNREACHABLE
(exec 3<>/dev/tcp/s3/8333) 2>/dev/null && echo s3-reachable || echo s3-UNREACHABLE
cd /u/leaf && git log -1 --format='git-ok %s' 2>&1
touch /u/leaf/.owner-probe && echo "probe-written uid=$(stat -c %u /u/leaf/.owner-probe)"
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
