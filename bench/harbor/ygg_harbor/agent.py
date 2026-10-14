"""Harbor agent adapter: hands the brief to Yggdrasil and carries out its requests in the task environment.

The factory runs on the host as `command`, and talks JSON lines over its standard input and output:

    adapter -> factory   {"type": "start", "instruction": ..., "workdir": "/app", "budget_usd": ...}
    factory -> adapter   {"id": ..., "op": ...}   exec, upload_file, upload_dir, download_file,
                                                  download_dir, selfcheck, spend, done
    adapter -> factory   {"id": ..., "ok": true, ...} or {"id": ..., "ok": false, "error": ...}

All factory logic stays in the factory. The adapter only keeps three promises Harbor doesn't:
the budget (a backstop: Yggdrasil stops itself first), secrets staying on the host, and a final
self-check of /app the way grading runs it.
"""

import asyncio
import json
import os
import shlex
import tempfile
import time
from pathlib import Path

from pydantic import Field

from harbor.agents.base import BaseAgent
from harbor.agents.options import AgentOptions
from harbor.environments.base import BaseEnvironment
from harbor.models.agent.context import AgentContext

from ygg_harbor import __version__

SELFCHECK = str(Path(__file__).resolve().parent.parent / "selfcheck.sh")
DEFAULT_SECRET_ENV = ["ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN", "OPENROUTER_API_KEY"]
WORKDIR = "/app"
LINE_LIMIT = 64 * 1024 * 1024  # a request can carry a whole file in its command


class YggdrasilOptions(AgentOptions):
    command: str = Field(description="The factory command, run on the host; it speaks the bridge.")
    budget_usd: float = Field(default=100.0, description="The task's [metadata] budget_usd.")
    secret_env: list[str] = Field(
        default_factory=lambda: list(DEFAULT_SECRET_ENV),
        description="Host variables whose values must never reach the task environment.",
    )


class Refused(Exception):
    """A request the adapter won't carry out."""


class YggdrasilAgent(BaseAgent):
    options_model = YggdrasilOptions

    @staticmethod
    def name() -> str:
        return "yggdrasil"

    def version(self) -> str:
        return __version__

    async def setup(self, environment: BaseEnvironment) -> None:
        pass

    async def run(self, instruction: str, environment: BaseEnvironment, context: AgentContext) -> None:
        opts = self.options
        secrets = {n: v for n in opts.secret_env if (v := self._get_env(n))}
        meta = context.metadata = {"budget_usd": opts.budget_usd, "spend_usd": 0.0, "stop_reason": None}
        self.logs_dir.mkdir(parents=True, exist_ok=True)
        stderr = open(self.logs_dir / "factory.stderr.log", "ab")
        log = open(self.logs_dir / "bridge.jsonl", "a")
        proc = await asyncio.create_subprocess_exec(
            *shlex.split(opts.command),
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=stderr,
            limit=LINE_LIMIT,
        )
        grace = 0
        try:
            await self._send(proc, {"type": "start", "instruction": instruction, "workdir": WORKDIR,
                                    "budget_usd": opts.budget_usd})
            while True:
                line = await proc.stdout.readline()
                if not line:
                    raise RuntimeError(f"the factory exited with {await proc.wait()} without saying done")
                req = json.loads(line)
                op = req.get("op")
                entry = {"t": time.time(), "id": req.get("id"), "op": op}
                try:
                    reply, stop = await self._handle(req, environment, context, secrets, entry)
                    reply = {"id": req.get("id"), "ok": True, **reply}
                except Refused as e:
                    reply, stop = {"id": req.get("id"), "ok": False, "error": str(e)}, None
                except Exception as e:  # the factory decides what an environment error means
                    reply, stop = {"id": req.get("id"), "ok": False, "error": f"{type(e).__name__}: {e}"}, None
                entry["ok"] = reply["ok"]
                if not reply["ok"]:
                    entry["error"] = reply["error"]
                log.write(json.dumps(entry) + "\n")
                log.flush()
                await self._send(proc, reply)
                if stop:
                    meta["stop_reason"] = stop
                    grace = 5 if stop == "done" else 0
                    break
            if meta.get("leak"):
                raise RuntimeError(f"the final /app holds a secret: {meta['leak']}")
        finally:
            await self._stop(proc, grace)
            stderr.close()
            log.close()

    async def _handle(self, req, environment, context, secrets, entry):
        """Carry out one request; returns (reply fields, stop reason or None)."""
        op = req.get("op")
        if op == "exec":
            entry["command"] = req["command"]
            self._refuse_secrets(secrets, [req["command"], *(req.get("env") or {}).values()])
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
            passed, detail, leak = await self._selfcheck(environment, secrets)
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
                SELFCHECK, image, d, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT
            )
            out, _ = await proc.communicate()
            lines = [l for l in out.decode(errors="replace").splitlines() if l.startswith(("PASS", "FAIL"))]
            return proc.returncode == 0, (lines[-1] if lines else f"FAIL selfcheck.sh exited with {proc.returncode}"), None

    @staticmethod
    async def _send(proc, obj):
        proc.stdin.write((json.dumps(obj) + "\n").encode())
        await proc.stdin.drain()

    @staticmethod
    async def _stop(proc, grace):
        """After done, give the factory `grace` seconds to exit on its own; then end it."""
        if proc.returncode is not None:
            return
        if grace:
            try:
                await asyncio.wait_for(asyncio.shield(proc.wait()), grace)
                return
            except TimeoutError:
                pass
        for signal_it in (proc.terminate, proc.kill):
            try:
                signal_it()
                await asyncio.wait_for(asyncio.shield(proc.wait()), 5)
                return
            except ProcessLookupError:
                return
            except TimeoutError:
                continue


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
