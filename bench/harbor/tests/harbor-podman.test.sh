#!/usr/bin/env bash
# Tests for harbor-podman.sh with fake podman and Compose binaries.   bench/harbor/tests/harbor-podman.test.sh
# YGG_TEST_ONLINE=1 also downloads the real pinned Compose binary and checks the environment of exec.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HP="$HERE/../harbor-podman.sh"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT
fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   $d"; else echo "FAIL $d"; fail=1; fi; }

# A fake podman that logs its arguments, first on PATH.
mkdir -p "$T/fakebin"
printf '#!/bin/sh\necho "podman $*" >> "%s/podman.log"\n' "$T" > "$T/fakebin/podman"
chmod +x "$T/fakebin/podman"
export PATH="$T/fakebin:$PATH"
export YGG_HARBOR_HOME="$T/tools"

# A wrong Compose binary, served from a local file.
printf '#!/bin/sh\necho "fake compose $*"\n' > "$T/wrong-compose"
YGG_COMPOSE_URL="file://$T/wrong-compose" "$HP" setup > "$T/out" 2>&1; rc=$?
check "setup refuses a Compose download with the wrong hash" bash -c "[ $rc = 1 ] && grep -q 'SHA-256 mismatch' '$T/out'"
check "nothing is installed as bin/docker-compose after a refusal" test ! -e "$T/tools/bin/docker-compose"
check "setup writes config.json and auth.json as empty auths" \
  bash -c "[ \"\$(cat '$T/tools/config/config.json')\" = '{\"auths\":{}}' ] && [ \"\$(cat '$T/tools/config/auth.json')\" = '{\"auths\":{}}' ]"

# The shim, with a fake Compose put in place by hand.
cp "$T/wrong-compose" "$T/tools/bin/docker-compose" && chmod +x "$T/tools/bin/docker-compose"
check "the shim sends 'docker compose' to bin/docker-compose" \
  bash -c "[ \"\$('$T/tools/bin/docker' compose up -d)\" = 'fake compose up -d' ]"
"$T/tools/bin/docker" ps -a > /dev/null
check "the shim sends everything else to podman" grep -qx 'podman ps -a' "$T/podman.log"
"$HP" exec true > "$T/out" 2>&1; rc=$?
check "exec refuses an installed Compose binary with the wrong hash" bash -c "[ $rc = 1 ] && grep -q 'SHA-256 mismatch' '$T/out'"
"$HP" exec harbor run -p x -o /tmp/jobs > "$T/out" 2>&1; rc=$?
check "exec refuses a jobs folder outside /mnt/wsl" bash -c "[ $rc = 2 ] && grep -q '/mnt/wsl' '$T/out'"
"$HP" exec harbor run -p x --jobs-dir=/tmp/jobs > "$T/out" 2>&1; rc=$?
check "exec refuses --jobs-dir= outside /mnt/wsl too" bash -c "[ $rc = 2 ] && grep -q '/mnt/wsl' '$T/out'"
"$HP" exec uv run harbor run -p x > "$T/out" 2>&1; rc=$?
check "exec refuses harbor run without a jobs folder (the default is the current folder)" bash -c "[ $rc = 2 ] && grep -q '/mnt/wsl' '$T/out'"

# prepare: a small task.
mkdir -p "$T/demo-task/environment"
echo "Build a thing." > "$T/demo-task/instruction.md"
echo "FROM scratch" > "$T/demo-task/environment/Dockerfile"
sha="$(sha256sum "$T/demo-task/instruction.md" | cut -d' ' -f1)"
cat > "$T/demo-task/task.toml" <<TOML
schema_version = "1.4"

[task]
name = "demo/demo-task"
version = "2.1.0"

[metadata]
brief_sha256 = "$sha"

[environment]
workdir = "/app"
cpus = 4
TOML
cp "$T/demo-task/task.toml" "$T/task.toml.orig"
: > "$T/podman.log"
"$HP" prepare "$T/demo-task" "$T/copy1" 0000000000000000000000000000000000000000000000000000000000000000 > "$T/out" 2>&1; rc=$?
check "prepare refuses a brief hash mismatch" bash -c "[ $rc = 1 ] && grep -q 'brief' '$T/out'"
check "prepare builds nothing and copies nothing on a mismatch" bash -c "[ ! -s '$T/podman.log' ] && [ ! -e '$T/copy1' ]"
"$HP" prepare "$T/demo-task" "$T/copy2" "$sha" > "$T/out" 2>&1; rc=$?
check "prepare succeeds on a match and prints the image name" bash -c "[ $rc = 0 ] && [ \"\$(tail -1 '$T/out')\" = 'localhost/demo-task:2.1.0' ]"
check "prepare builds the image from the task's environment/ with podman build" \
  grep -qx "podman build -t localhost/demo-task:2.1.0 $T/demo-task/environment" "$T/podman.log"
check "the copy's task.toml has docker_image under [environment]" \
  python3 -c "import tomllib,sys; c=tomllib.load(open('$T/copy2/task.toml','rb')); sys.exit(c['environment'].get('docker_image')!='localhost/demo-task:2.1.0' or c['environment']['cpus']!=4)"
check "the copy holds the rest of the task" test -f "$T/copy2/instruction.md" -a -f "$T/copy2/environment/Dockerfile"
check "the original task.toml is unchanged" cmp -s "$T/demo-task/task.toml" "$T/task.toml.orig"
sed -i 's/^brief_sha256 = .*/brief_sha256 = "1111111111111111111111111111111111111111111111111111111111111111"/' "$T/demo-task/task.toml"
"$HP" prepare "$T/demo-task" "$T/copy3" "$sha" > "$T/out" 2>&1; rc=$?
check "prepare refuses when task.toml's brief_sha256 disagrees with the brief" bash -c "[ $rc = 1 ] && [ ! -e '$T/copy3' ]"
cp "$T/task.toml.orig" "$T/demo-task/task.toml"
"$HP" prepare "$T/demo-task" "$T/copy2" "$sha" > "$T/out" 2>&1; rc=$?
check "prepare refuses a copy folder that already exists" bash -c "[ $rc = 2 ]"

if [ "${YGG_TEST_ONLINE:-0}" = 1 ]; then
  export YGG_HARBOR_HOME="$T/online"
  "$HP" setup > "$T/out" 2>&1; rc=$?
  check "online: setup installs the real Compose binary" bash -c "[ $rc = 0 ] && [ -x '$T/online/bin/docker-compose' ]"
  check "online: the shim runs Compose v5.5.1" bash -c "'$T/online/bin/docker' compose version | grep -q 'v5.5.1'"
  env -u DOCKER_HOST "$HP" exec env > "$T/env" 2>&1; rc=$?
  check "online: exec runs with the tools bin/ first on PATH" bash -c "[ $rc = 0 ] && grep -q '^PATH=$T/online/bin:' '$T/env'"
  check "online: exec sets DOCKER_CONFIG and REGISTRY_AUTH_FILE to the tools config" \
    bash -c "grep -qx 'DOCKER_CONFIG=$T/online/config' '$T/env' && grep -qx 'REGISTRY_AUTH_FILE=$T/online/config/auth.json' '$T/env'"
  check "online: exec defaults DOCKER_HOST and CONTAINER_HOST to the machine's root socket" \
    bash -c "grep -qx 'DOCKER_HOST=unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-root.sock' '$T/env' && grep -qx 'CONTAINER_HOST=unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-root.sock' '$T/env'"
  DOCKER_HOST=unix:///run/other.sock "$HP" exec env > "$T/env" 2>&1
  check "online: an explicit DOCKER_HOST is kept and given to podman" \
    bash -c "grep -qx 'DOCKER_HOST=unix:///run/other.sock' '$T/env' && grep -qx 'CONTAINER_HOST=unix:///run/other.sock' '$T/env'"
  env -u DOCKER_HOST CONTAINER_HOST=unix:///user.sock "$HP" exec python3 -c \
    'import json, os; print(json.dumps(json.loads(os.environ["YGG_HARBOR_ORIG_ENV"]), sort_keys=True))' > "$T/orig" 2>&1
  check "online: exec records the caller's container settings for the factory" \
    python3 -c "import json,os,sys; o=json.load(open('$T/orig')); sys.exit(not (o['DOCKER_HOST'] is None and o['CONTAINER_HOST']=='unix:///user.sock' and o['PATH']==os.environ['PATH'] and set(o)=={'DOCKER_HOST','CONTAINER_HOST','DOCKER_CONFIG','REGISTRY_AUTH_FILE','PATH'}))"
  "$HP" exec harbor run -p x -o /mnt/wsl/ygg-test-jobs > "$T/out" 2>&1; rc=$?
  check "online: a jobs folder under /mnt/wsl passes the check" bash -c "! grep -q 'must be under /mnt/wsl' '$T/out'"
fi

exit $fail
