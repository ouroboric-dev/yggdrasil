#!/usr/bin/env bash
# Tests for selfcheck.sh against a real task image.   bench/harbor/tests/selfcheck.test.sh <image>
# Needs Podman, so it runs outside Claude Code's sandbox, under harbor-podman.sh exec (the engine the
# image was built in). One fixture app per case; each failing case gets a short timeout.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC="$HERE/../selfcheck.sh"
IMAGE="${1:?usage: selfcheck.test.sh <image>}"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT
fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   $d"; else echo "FAIL $d"; fail=1; fi; }
app() { # app NAME START_SH_BODY: a fixture app with an index page
  mkdir -p "$T/$1/www" && echo "hello" > "$T/$1/www/index.html"
  printf '#!/bin/bash\n%s\n' "$2" > "$T/$1/start.sh" && chmod +x "$T/$1/start.sh"
}
serve='exec python3 -m http.server 3000 --bind 0.0.0.0 --directory /app/www'
run() { # run NAME [TIMEOUT]: selfcheck.sh's exit code in $rc, its output in $T/out
  SELFCHECK_TIMEOUT="${2:-120}" "$SC" "$IMAGE" "$T/$1" > "$T/out" 2>&1; rc=$?
}
left() { podman ps -a --filter name=ygg-selfcheck --format '{{.Names}}' | wc -l; }
before="$(left)"

# Grading's conditions, asserted by the app itself: user app, owner of /app, a clean environment.
app good "[ \"\$(id -un)\" = app ] || exit 11
[ -O /app ] && [ -O /app/www/index.html ] || exit 12
[ \"\$HOME\" = /home/app ] && [ \"\$USER\" = app ] || exit 13
[ -z \"\${YGG_SELFCHECK_PROBE:-}\" ] && [ \"\$(env | grep -cv '^\(HOME\|USER\|LANG\|LC_ALL\|PATH\|PWD\|SHLVL\|_\)=')\" = 0 ] || exit 14
echo scratch > /tmp/scratch
$serve"
YGG_SELFCHECK_PROBE=1 run good
check "an app serving on 0.0.0.0:3000 as user app with a clean environment passes" \
  bash -c "[ $rc = 0 ] && grep -qx PASS '$T/out'"

app daemon "nohup python3 -m http.server 3000 --bind 0.0.0.0 --directory /app/www > /tmp/server.log 2>&1 &
exit 0"
run daemon
check "a start.sh that starts the server in the background and exits 0 passes" bash -c "[ $rc = 0 ]"

mkdir -p "$T/nostart/www"
run nostart 10
check "a missing start.sh fails" bash -c "[ $rc = 1 ] && grep -q '^FAIL.*start.sh' '$T/out'"

app noexec "$serve" && chmod -x "$T/noexec/start.sh"
run noexec 10
check "a start.sh that isn't executable fails" bash -c "[ $rc = 1 ] && grep -q '^FAIL.*start.sh' '$T/out'"

app loopback 'exec python3 -m http.server 3000 --bind 127.0.0.1 --directory /app/www'
run loopback 10
check "a server bound to 127.0.0.1 only fails" bash -c "[ $rc = 1 ] && grep -q '^FAIL.*3000' '$T/out'"

app outside 'exec /usr/local/bin/ygg-built-outside-app --port 3000'
run outside 10
check "a dependency installed outside /app at build time fails" bash -c "[ $rc = 1 ] && grep -q '^FAIL.*exited' '$T/out'"

app exits 'echo "cannot start" >&2; exit 3'
run exits 10
check "a start.sh that exits non-zero fails with its exit code" bash -c "[ $rc = 1 ] && grep -q '^FAIL.*exited with 3' '$T/out'"

app homewrite "echo state > \"\$HOME/state.db\"
$serve"
run homewrite 30
check "a write outside /app and the temporary folders fails and names the path" \
  bash -c "[ $rc = 1 ] && grep -q '^FAIL.*outside /app' '$T/out' && grep -q '/home/app/state.db' '$T/out'"

app slow "sleep 30; $serve"
run slow 5
check "nothing on port 3000 within the timeout fails" bash -c "[ $rc = 1 ] && grep -q '^FAIL.*3000' '$T/out'"

# A probe that never runs (curl missing, an engine error) must not count as an answer.
mkdir -p "$T/nocurl-bin"
printf '#!/bin/bash\nfor a in "$@"; do [ "$a" = curl ] && exit 127; done\nexec %s "$@"\n' "$(command -v podman)" \
  > "$T/nocurl-bin/podman" && chmod +x "$T/nocurl-bin/podman"
PATH="$T/nocurl-bin:$PATH" SELFCHECK_TIMEOUT=10 "$SC" "$IMAGE" "$T/good" > "$T/out" 2>&1; rc=$?
check "a probe that can't run fails instead of passing" bash -c "[ $rc = 1 ] && grep -q '^FAIL' '$T/out'"

"$SC" "$IMAGE" "$T/does-not-exist" > "$T/out" 2>&1; rc=$?
check "a missing app folder is a usage error" bash -c "[ $rc = 2 ]"

check "no self-check container is left behind" bash -c "[ \"\$(podman ps -a --filter name=ygg-selfcheck --format '{{.Names}}' | wc -l)\" = '$before' ]"

exit $fail
