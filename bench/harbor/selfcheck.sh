#!/usr/bin/env bash
# Check a build the way grading runs it (brief §6): a fresh container from the task image holding only
# /app, owned by the unprivileged user app, and /app/start.sh run as app with a clean environment.
# It passes when port 3000 answers HTTP on the container's network address within the timeout, and
# nothing outside /app and the temporary folders was written.
#   selfcheck.sh <image> <app dir>      prints PASS or FAIL <reason>; exits 0, 1, or 2 on bad usage
# SELFCHECK_TIMEOUT (default 120 s). Needs the Podman engine that holds the image (harbor-podman.sh exec).
set -uo pipefail
die() { echo "selfcheck: $1" >&2; exit 2; }
[ $# = 2 ] || die "usage: selfcheck.sh <image> <app dir>"
IMAGE="$1" APP="$2" TIMEOUT="${SELFCHECK_TIMEOUT:-120}"
[ -d "$APP" ] || die "no app folder: $APP"
CLEAN_ENV=(env -i HOME=/home/app USER=app LANG=C.UTF-8 LC_ALL=C.UTF-8
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin)

NAME="ygg-selfcheck-$$-$RANDOM"
LOG="$(mktemp)"
pid=""
cleanup() {
  [ -n "$pid" ] && kill "$pid" 2>/dev/null
  podman rm -f -t 0 "$NAME" > /dev/null 2>&1
  rm -f -- "$LOG"
}
trap cleanup EXIT
result() { # result PASS|FAIL [reason]: print, show start.sh's output on a failure, exit
  if [ "$1" = PASS ]; then echo PASS; exit 0; fi
  echo "FAIL $2"
  [ -s "$LOG" ] && { echo "--- start.sh output (last 20 lines)" >&2; tail -20 "$LOG" >&2; }
  exit 1
}
in_ctr() { podman exec "$NAME" "$@"; }

podman run -d --pull=never --name "$NAME" --user root --entrypoint sleep "$IMAGE" infinity > /dev/null \
  || result FAIL "could not start a container from $IMAGE"
podman cp "$APP/." "$NAME:/app" && in_ctr chown -R app:app /app || result FAIL "could not copy $APP into /app"
podman exec -u app "$NAME" test -x /app/start.sh || result FAIL "/app/start.sh is missing or not executable"
ip="$(in_ctr python3 -c 'import socket; print(socket.gethostbyname(socket.gethostname()))')"
[[ -n "$ip" && "$ip" != 127.* ]] || result FAIL "the container has no network address"
baseline="$(podman diff "$NAME" | sort)"

podman exec -u app -w /app "$NAME" "${CLEAN_ENV[@]}" /app/start.sh > "$LOG" 2>&1 &
pid=$!
answers() { # any HTTP status counts; a probe that didn't run (no curl, an engine error) doesn't
  [[ "$(in_ctr curl -s -o /dev/null -m 3 -w '%{http_code}' "http://$1:3000/" 2>/dev/null)" =~ ^[1-5][0-9][0-9]$ ]]
}
deadline=$((SECONDS + TIMEOUT)) served=false
while [ $SECONDS -lt $deadline ]; do
  if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid"; rc=$?; pid=""
    [ $rc = 0 ] || result FAIL "/app/start.sh exited with $rc before port 3000 answered"
  fi
  if answers "$ip"; then served=true; break; fi
  sleep 1
done
if ! $served; then
  answers 127.0.0.1 && result FAIL "port 3000 answers on 127.0.0.1 only; serve on 0.0.0.0"
  result FAIL "nothing answered on port 3000 within ${TIMEOUT}s"
fi

# Writes outside /app and the temporary folders: changes since the baseline, minus the parents
# (/, /var) that change whenever a temporary folder does.
sleep 2
outside="$(comm -13 <(echo "$baseline") <(podman diff "$NAME" | sort) | awk '{print $2}' \
  | grep -Ev '^(/app|/tmp|/var/tmp)(/|$)|^/$|^/var$' || true)"
[ -z "$outside" ] || result FAIL "wrote outside /app and the temporary folders: $(echo $outside)"
result PASS
