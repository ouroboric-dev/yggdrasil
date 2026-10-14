"""Harbor agent adapter: hands the brief to Yggdrasil and carries out its requests in the task environment.

The factory runs on the host as `command`, and talks JSON lines over its standard input and output:

    adapter -> factory   {"type": "start", "instruction": ..., "workdir": "/app", "budget_usd": ...}
    factory -> adapter   {"id": ..., "op": ...}   exec, upload_file, upload_dir, download_file,
                                                  download_dir, selfcheck, spend, done
    adapter -> factory   {"id": ..., "ok": true, ...} or {"id": ..., "ok": false, "error": ...}

Rules for the factory: write only requests to standard output (anything else gets an error reply);
`spend` is the run's total so far, in USD; after the reply to `done`, exit; exit when standard input
closes. The factory runs in its own process group, and the whole group is ended when the run stops.

All factory logic stays in the factory. The adapter only keeps three promises Harbor doesn't:
the budget (a backstop: Yggdrasil stops itself first), secrets staying on the host, and a final
self-check of /app the way grading runs it.

Logs go to <trial>/yggdrasil/, next to Harbor's <trial>/agent/, which the task container mounts:
bridge.jsonl (one line per request) and factory.stderr.log, both with secret values redacted.
"""

import asyncio
import json
import os
import shlex
import signal
import tempfile
import time
from pathlib import Path

from pydantic import Field

from harbor.agents.base import BaseAgent
from harbor.agents.installed.base import NonZeroAgentExitCodeError
from harbor.agents.options import AgentOptions
from harbor.environments.base import BaseEnvironment
from harbor.models.agent.context import AgentContext

from ygg_harbor import __version__

SELFCHECK = str(Path(__file__).resolve().parent.parent / "selfcheck.sh")
DEFAULT_SECRET_ENV = ["ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN", "OPENROUTER_API_KEY"]
WORKDIR = "/app"
LINE_LIMIT = 64 * 1024 * 1024  # a request can carry a whole file in its command
LOGGED_COMMAND = 2000  # characters of a command kept in the log
# harbor-podman.sh exec records the caller's values here, so the factory gets them back.
ORIG_ENV = "YGG_HARBOR_ORIG_ENV"


class YggdrasilOptions(AgentOptions):
    command: str = Field(description="The factory command, run on the host; it speaks the bridge.")
    budget_usd: float = Field(default=100.0, description="The task's [metadata] budget_usd.")
    secret_env: list[str] = Field(
        default_factory=lambda: list(DEFAULT_SECRET_ENV),
        description="Host variables whose values must never reach the task environment.",
    )


class Refused(Exception):
    """A request the adapter won't carry out."""


class FactoryFailed(NonZeroAgentExitCodeError):
    """The factory stopped without done, or broke the bridge. Harbor still grades /app."""


class SecretLeak(RuntimeError):
    """The final /app holds a secret's value. The run fails hard."""


class YggdrasilAgent(BaseAgent):
    options_model = YggdrasilOptions

    @staticmethod
    def name() -> str:
        return "yggdrasil"

    def version(self) -> str:
        return __version__

    async def setup(self, environment: BaseEnvironment) -> None:
        pass

    @property
    def host_logs_dir(self) -> Path:
        return self.logs_dir.parent / "yggdrasil"

    async def run(self, instruction: str, environment: BaseEnvironment, context: AgentContext) -> None:
        opts = self.options
        secrets = {n: v for n in opts.secret_env if (v := self._get_env(n))}
        meta = context.metadata = {"budget_usd": opts.budget_usd, "spend_usd": 0.0, "stop_reason": None}
        self.host_logs_dir.mkdir(parents=True, exist_ok=True)
        log = open(self.host_logs_dir / "bridge.jsonl", "a")
        proc = await asyncio.create_subprocess_exec(
            *shlex.split(opts.command),
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            limit=LINE_LIMIT,
            env=_factory_env(),
            start_new_session=True,
        )
        stderr_pump = asyncio.create_task(
            _pump_redacted(proc.stderr, self.host_logs_dir / "factory.stderr.log", secrets)
        )
        grace = 0
        try:
            try:
                await self._send(proc, {"type": "start", "instruction": instruction, "workdir": WORKDIR,
                                        "budget_usd": opts.budget_usd})
                while True:
                    line = await proc.stdout.readline()
                    if not line:
                        raise FactoryFailed(f"the factory exited with {await proc.wait()} without saying done")
                    reply, stop, entry = await self._answer(line, environment, context, secrets)
                    log.write(_redact(json.dumps(entry), secrets) + "\n")
                    log.flush()
                    await self._send(proc, reply)
                    if stop:
                        meta["stop_reason"] = stop
                        grace = 5 if stop == "done" else 0
                        break
            except (asyncio.CancelledError, FactoryFailed):
                raise
            except Exception as e:  # a broken pipe or an oversized line: the bridge is gone
                raise FactoryFailed(f"the bridge failed: {type(e).__name__}: {e}") from e
            if meta.get("leak"):
                raise SecretLeak(f"the final /app holds a secret: {meta['leak']}")
        finally:
            await _stop(proc, grace)
            await asyncio.gather(stderr_pump, return_exceptions=True)
            log.close()

    async def _answer(self, line, environment, context, secrets):
        """One line from the factory: returns (reply, stop reason or None, log entry)."""
        try:
            req = json.loads(line)
            if not isinstance(req, dict):
                raise ValueError("not a JSON object")
        except ValueError as e:
            entry = {"t": time.time(), "op": None, "ok": False, "error": f"not a request: {e}",
                     "line": line[:200].decode(errors="replace")}
            return {"id": None, "ok": False, "error": entry["error"]}, None, entry
        entry = {"t": time.time(), "id": req.get("id"), "op": req.get("op")}
        stop = None
        try:
            fields, stop = await self._handle(req, environment, context, secrets, entry)
            reply = {"id": req.get("id"), "ok": True, **fields}
        except Refused as e:
            reply = {"id": req.get("id"), "ok": False, "error": str(e)}
        except asyncio.CancelledError:
            raise
        except Exception as e:  # the factory decides what an environment error means
            reply = {"id": req.get("id"), "ok": False, "error": f"{type(e).__name__}: {e}"}
        entry["ok"] = reply["ok"]
        if not reply["ok"]:
            entry["error"] = reply["error"]
        return reply, stop, entry

    async def _handle(self, req, environment, context, secrets, entry):
        """Carry out one request; returns (reply fields, stop reason or None)."""
        op = req.get("op")
        if op == "exec":
            self._refuse_secrets(secrets, [req["command"], *(req.get("env") or {}).values()])
            entry["command"] = req["command"][:LOGGED_COMMAND]
            r = await environment.exec(req["command"], cwd=req.get("cwd"), env=req.get("env"),
                                       timeout_sec=req.get("timeout_sec"), user=req.get("user"))
            entry["return_code"] = r.return_code
            return {"return_code": r.return_code, "stdout": r.stdout, "stderr": r.stderr}, None
        if op in ("upload_file", "upload_dir"):
            entry["source"], entry["target"] = req["source"], req["target"]
            leak = _find_secret(Path(req["source"]), secrets)
            if leak:
                raise Refused(f"refused: {leak}")
            await getattr(environment, op)(req["source"], req["target"])
            return {}, None
        if op in ("download_file", "download_dir"):
            entry["source"], entry["target"] = req["source"], req["target"]
            await getattr(environment, op)(req["source"], req["target"])
            return {}, None
        if op == "selfcheck":
            passed, detail, _ = await self._selfcheck(environment, secrets)
            entry["passed"] = passed
            return {"passed": passed, "detail": detail}, None
        if op == "spend":
            usd = float(req["usd"])
            context.cost_usd = context.metadata["spend_usd"] = entry["usd"] = usd
            return {}, ("budget" if usd > self.options.budget_usd else None)
        if op == "done":
            try:
                passed, detail, leak = await self._selfcheck(environment, secrets)
            except asyncio.CancelledError:
                raise
            except Exception as e:  # done always ends the run; a check that can't run fails
                passed, detail, leak = False, f"FAIL the self-check could not run: {type(e).__name__}: {e}", None
            context.metadata["selfcheck"] = {"passed": passed, "detail": detail}
            if leak:
                context.metadata["leak"] = leak
            entry["passed"] = passed
            return {"passed": passed, "detail": detail}, "done"
        raise Refused(f"unknown op: {op}")

    @staticmethod
    def _refuse_secrets(secrets, texts):
        for name, value in secrets.items():
            if any(value in t for t in texts if isinstance(t, str)):
                raise Refused(f"refused: the request holds the value of {name}; secrets stay on the host")

    async def _selfcheck(self, environment, secrets):
        """Download /app and run selfcheck.sh on it. Returns (passed, detail, leak or None)."""
        with tempfile.TemporaryDirectory(prefix="ygg-app-") as d:
            await environment.download_dir(WORKDIR, d)
            leak = _find_secret(Path(d), secrets)
            if leak:
                return False, f"FAIL {leak}", leak
            image = getattr(environment.task_env_config, "docker_image", None)
            if not image:
                return False, "FAIL the task has no docker_image; prepare it with harbor-podman.sh", None
            proc = await asyncio.create_subprocess_exec(
                SELFCHECK, image, d, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
                start_new_session=True,
            )
            try:
                out, _ = await proc.communicate()
            finally:
                await _stop(proc, 0)
            lines = [l for l in out.decode(errors="replace").splitlines() if l.startswith(("PASS", "FAIL"))]
            return proc.returncode == 0, (lines[-1] if lines else f"FAIL selfcheck.sh exited with {proc.returncode}"), None

    @staticmethod
    async def _send(proc, obj):
        proc.stdin.write((json.dumps(obj) + "\n").encode())
        await proc.stdin.drain()


def _factory_env() -> dict[str, str]:
    """The host environment, with the caller's container settings back in place of harbor-podman.sh's."""
    env = dict(os.environ)
    orig = env.pop(ORIG_ENV, None)
    if orig:
        for name, value in json.loads(orig).items():
            if value is None:
                env.pop(name, None)
            else:
                env[name] = value
    return env


async def _stop(proc, grace):
    """After done, give the factory `grace` seconds to exit on its own; then end its process group."""
    if proc.returncode is None and grace:
        try:
            await asyncio.wait_for(asyncio.shield(proc.wait()), grace)
        except TimeoutError:
            pass
    # The group outlives its leader, so signal it even when the factory itself has exited.
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(proc.pid, sig)
        except ProcessLookupError:
            break
        try:
            await asyncio.wait_for(asyncio.shield(proc.wait()), 5)
        except TimeoutError:
            continue
        if sig == signal.SIGTERM:
            try:
                os.killpg(proc.pid, signal.SIGKILL)  # children that ignored SIGTERM
            except ProcessLookupError:
                pass
        break


async def _pump_redacted(stream, path: Path, secrets: dict[str, str]):
    with open(path, "a") as out:
        while line := await stream.readline():
            out.write(_redact(line.decode(errors="replace"), secrets))
            out.flush()


def _redact(text: str, secrets: dict[str, str]) -> str:
    for name, value in secrets.items():
        text = text.replace(value, f"[redacted {name}]")
    return text


def _find_secret(path: Path, secrets: dict[str, str]) -> str | None:
    """The first file under path holding a secret's value, as 'the value of NAME in FILE'."""
    if not secrets:
        return None
    files = [path] if path.is_file() else [p for p in path.rglob("*") if p.is_file() and not p.is_symlink()]
    needles = {name: value.encode() for name, value in secrets.items()}
    for f in files:
        try:
            data = f.read_bytes()
        except OSError:
            continue
        for name, needle in needles.items():
            if needle in data:
                return f"the value of {name} in {f.relative_to(path) if f != path else f.name}"
    return None
