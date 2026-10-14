#!/usr/bin/env bash
# Run Harbor on this machine's Podman. Harbor drives `docker compose`; Compose v5 builds with buildx,
# which Podman lacks, so the task image is built with `podman build` and Compose only runs it.
#   harbor-podman.sh setup                                  install the pinned Compose, the shim, the config
#   harbor-podman.sh prepare <task dir> <copy dir> <sha256> build the task image; make a copy that uses it
#   harbor-podman.sh exec <command...>                      run a command (harbor) in the Podman setup
# The tools live in ${YGG_HARBOR_HOME:-~/.cache/yggdrasil-harbor}. The founder's ~/.docker and Podman
# config are never read or changed. Podman commands need the socket, which Claude Code's sandbox blocks.
set -euo pipefail
TOOLS="${YGG_HARBOR_HOME:-$HOME/.cache/yggdrasil-harbor}"
COMPOSE_URL="${YGG_COMPOSE_URL:-https://github.com/docker/compose/releases/download/v5.5.1/docker-compose-linux-x86_64}"
COMPOSE_SHA256="db1889184726840f75c4f9c001048430d4f25b3be3cb084d3ddd762bc0aed576"
DEFAULT_HOST="unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-root.sock"
die() { echo "harbor-podman: $2" >&2; exit "$1"; }

sha256() { sha256sum "$1" | cut -d' ' -f1; }
check_compose() { # check_compose FILE: the pinned hash, or refuse
  local got; got="$(sha256 "$1")"
  [ "$got" = "$COMPOSE_SHA256" ] || die 1 "Compose SHA-256 mismatch: $1 is $got, expected $COMPOSE_SHA256"
}
tool_env() { # the environment every Podman and Harbor call gets
  export PATH="$TOOLS/bin:$PATH"
  export DOCKER_CONFIG="$TOOLS/config" REGISTRY_AUTH_FILE="$TOOLS/config/auth.json"
  export DOCKER_HOST="${DOCKER_HOST:-$DEFAULT_HOST}"
  export CONTAINER_HOST="$DOCKER_HOST"
}

setup() {
  mkdir -p "$TOOLS/bin" "$TOOLS/config"
  printf '{"auths":{}}' > "$TOOLS/config/config.json"
  printf '{"auths":{}}' > "$TOOLS/config/auth.json"
  cat > "$TOOLS/bin/docker" <<'SHIM'
#!/bin/sh
# docker shim for Harbor on Podman: `docker compose` runs the pinned Compose, everything else podman.
if [ "${1:-}" = compose ]; then shift; exec "$(dirname "$0")/docker-compose" "$@"; fi
exec podman "$@"
SHIM
  chmod +x "$TOOLS/bin/docker"
  if [ -f "$TOOLS/bin/docker-compose" ] && [ "$(sha256 "$TOOLS/bin/docker-compose")" = "$COMPOSE_SHA256" ]; then
    echo "Compose v5.5.1 already installed"; return
  fi
  local tmp; tmp="$(mktemp "$TOOLS/bin/.docker-compose.XXXXXX")"
  curl -fsSL -o "$tmp" "$COMPOSE_URL" || { rm -f -- "$tmp"; die 1 "download failed: $COMPOSE_URL"; }
  if [ "$(sha256 "$tmp")" != "$COMPOSE_SHA256" ]; then
    rm -f -- "$tmp"
    die 1 "Compose SHA-256 mismatch: the download from $COMPOSE_URL is not v5.5.1; nothing installed"
  fi
  chmod +x "$tmp"
  mv -- "$tmp" "$TOOLS/bin/docker-compose"
  echo "installed Compose v5.5.1 in $TOOLS/bin"
}

prepare() {
  [ $# = 3 ] || die 2 "usage: harbor-podman.sh prepare <task dir> <copy dir> <brief sha256>"
  local task="${1%/}" copy="$2" want="$3"
  [ -f "$task/instruction.md" ] && [ -f "$task/task.toml" ] && [ -d "$task/environment" ] \
    || die 2 "$task is not a task (instruction.md, task.toml, environment/)"
  [ ! -e "$copy" ] || die 2 "$copy already exists; give a new folder"
  local got; got="$(sha256 "$task/instruction.md")"
  [ "$got" = "$want" ] || die 1 "brief SHA-256 mismatch: $task/instruction.md is $got, expected $want; a different task version"
  local version recorded
  read -r version recorded < <(python3 -c 'import sys, tomllib
c = tomllib.load(open(sys.argv[1], "rb"))
print(c["task"]["version"], c.get("metadata", {}).get("brief_sha256", "-"))' "$task/task.toml")
  [ "$recorded" = - ] || [ "$recorded" = "$got" ] \
    || die 1 "brief SHA-256 mismatch: task.toml records $recorded, the brief is $got"
  local image; image="localhost/$(basename "$task"):$version"
  tool_env
  podman build -t "$image" "$task/environment" >&2
  mkdir -p "$copy" && cp -a "$task/." "$copy/"
  python3 - "$copy/task.toml" "$image" <<'PY'
import re, sys
path, image = sys.argv[1], sys.argv[2]
lines = open(path).read().splitlines()
line = f'docker_image = "{image}"'
section = None
for i, l in enumerate(lines):
    if re.match(r"^\s*\[", l):
        section = l.strip()
    elif section == "[environment]" and re.match(r"^\s*docker_image\s*=", l):
        lines[i] = line
        break
else:
    if "[environment]" in (l.strip() for l in lines):
        lines.insert([l.strip() for l in lines].index("[environment]") + 1, line)
    else:
        lines += ["", "[environment]", line]
open(path, "w").write("\n".join(lines) + "\n")
PY
  echo "$image"
}

run_exec() {
  [ $# -ge 1 ] || die 2 "usage: harbor-podman.sh exec <command...>"
  # The Podman machine can't see the distro's /tmp or home, so Harbor's jobs folder must be in /mnt/wsl.
  local args=("$@") i jobs="" harbor_run=false
  for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[i]}" in
      -o | --jobs-dir) jobs="${args[i + 1]:-}" ;;
      --jobs-dir=*) jobs="${args[i]#--jobs-dir=}" ;;
      harbor | */harbor) [ "${args[i + 1]:-}" = run ] && harbor_run=true ;;
    esac
  done
  if [ -n "$jobs" ] || $harbor_run; then
    [[ "$(realpath -m -- "${jobs:-.}")" == /mnt/wsl/* ]] \
      || die 2 "the jobs folder (-o) must be under /mnt/wsl, where the Podman machine can see it"
  fi
  [ -f "$TOOLS/bin/docker-compose" ] || die 1 "no Compose in $TOOLS/bin; run harbor-podman.sh setup"
  check_compose "$TOOLS/bin/docker-compose"
  tool_env
  exec "$@"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  setup) setup ;;
  prepare) prepare "$@" ;;
  exec) run_exec "$@" ;;
  *) die 2 "usage: harbor-podman.sh setup | prepare <task dir> <copy dir> <brief sha256> | exec <command...>" ;;
esac
