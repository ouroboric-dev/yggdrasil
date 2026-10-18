#!/usr/bin/env bash
# Smoke runs through Harbor on Podman: nop must score 0, the adapter with the fake factory 1.
#   bench/harbor/tests/smoke.sh <task dir> <brief sha256>
# The grader here is a trivial tests/test.sh written into a throwaway copy of the task: it only checks
# that /app/start.sh answers on port 3000. It is never the hidden suite and is never committed.
# Needs Podman (run outside Claude Code's sandbox) and harbor-podman.sh setup.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCH="$(cd "$HERE/.." && pwd)"
HP="$BENCH/harbor-podman.sh"
[ $# = 2 ] || { echo "usage: smoke.sh <task dir> <brief sha256>" >&2; exit 2; }
TASK="$1" SHA="$2"

T="$(mktemp -d)"
JOBS="$(mktemp -d /mnt/wsl/ygg-harbor-jobs.XXXXXX)"
IMAGE=""
# shellcheck disable=SC2329  # called by the EXIT trap below
cleanup() {
  # Containers write the jobs folder as root, so a container from the task image empties it.
  [ -n "$IMAGE" ] && "$HP" exec podman run --rm --pull=never -v "$JOBS:/jobs" --entrypoint sh "$IMAGE" \
    -c 'rm -rf /jobs/* /jobs/.[!.]*' > /dev/null 2>&1
  rm -rf -- "$JOBS" "$T"
}
trap cleanup EXIT

IMAGE="$("$HP" prepare "$TASK" "$T/task" "$SHA" | tail -1)" || exit 1
mkdir -p "$T/task/tests"
cat > "$T/task/tests/test.sh" <<'EOF'
#!/bin/bash
# Smoke grader: 1 if /app/start.sh, run as app with a clean environment, answers on port 3000.
mkdir -p /logs/verifier
reward=0
if [ -x /app/start.sh ]; then
  chown -R app:app /app
  cd /app && runuser -u app -- env -i HOME=/home/app USER=app LANG=C.UTF-8 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin /app/start.sh > /logs/verifier/start.log 2>&1 &
  for _ in $(seq 1 120); do
    curl -s -o /dev/null -m 2 http://127.0.0.1:3000/ && { reward=1; break; }
    sleep 1
  done
fi
echo "{\"reward\": $reward}" > /logs/verifier/reward.json
EOF
chmod +x "$T/task/tests/test.sh"

trial() { # trial LABEL: the run's one trial as "<reward> <exception> <adapter self-check>"
  python3 - "$JOBS/$1" <<'PY'
import glob, json, sys
for path in glob.glob(f"{sys.argv[1]}/**/result.json", recursive=True):
    r = json.load(open(path))
    if "trial_name" in r:
        reward = ((r.get("verifier_result") or {}).get("rewards") or {}).get("reward")
        exc = r.get("exception_info")
        check = (((r.get("agent_result") or {}).get("metadata") or {}).get("selfcheck") or {}).get("detail", "-")
        print(reward if reward is not None else "none", (exc or {}).get("exception_type", "none"), check.split()[0])
        break
else:
    print("none no-trial-result -")
PY
}
harbor() { # harbor LABEL ARGS...: one Harbor run of the copy into its own jobs folder
  local label="$1"; shift
  "$HP" exec uv run -q --project "$BENCH" harbor run -p "$T/task" -o "$JOBS/$label" -y "$@" \
    > "$T/$label.log" 2>&1 || { echo "harbor run $label exited with $?:" >&2; tail -20 "$T/$label.log" >&2; }
}

harbor nop -a nop
harbor yggdrasil -a ygg_harbor.agent:YggdrasilAgent --ak "command=python3 $HERE/fake_factory.py smoke"
read -r nop_reward nop_exc _ < <(trial nop)
read -r ygg_reward ygg_exc ygg_check < <(trial yggdrasil)
echo "nop ${nop_reward%.0} exception=$nop_exc"
echo "yggdrasil ${ygg_reward%.0} exception=$ygg_exc selfcheck=$ygg_check"
if [ "${nop_reward%.0}" = 0 ] && [ "${ygg_reward%.0}" = 1 ] && [ "$ygg_exc" = none ] && [ "$ygg_check" = PASS ]; then
  exit 0
fi
tail -20 "$T/yggdrasil.log" >&2
exit 1
