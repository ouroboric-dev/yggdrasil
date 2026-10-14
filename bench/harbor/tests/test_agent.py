"""Tests for the Harbor agent adapter, against a fake environment and tests/fake_factory.py."""

import asyncio
import json
import os
import shutil
import sys
import uuid
from pathlib import Path
from types import SimpleNamespace

import pytest
from harbor.agents.factory import AgentFactory
from harbor.agents.installed.base import NonZeroAgentExitCodeError
from harbor.environments.base import ExecResult
from harbor.models.agent.context import AgentContext

from ygg_harbor import agent as agent_module

HERE = Path(__file__).parent
FAKE_FACTORY = HERE / "fake_factory.py"
# Built at run time, so no secret-shaped string is ever committed.
SECRET = "fake-secret-" + uuid.uuid4().hex


class FakeEnvironment:
    """Records every call; download_dir copies a fixture app folder."""

    def __init__(self, app_dir: Path, image: str | None = "localhost/demo:1.0.0"):
        self.calls = []
        self.app_dir = app_dir
        self.task_env_config = SimpleNamespace(docker_image=image)

    async def exec(self, command, cwd=None, env=None, timeout_sec=None, user=None):
        self.calls.append(("exec", command, cwd, env, timeout_sec, user))
        return ExecResult(stdout=f"ran {command}", stderr="warn", return_code=7)

    async def upload_file(self, source_path, target_path):
        self.calls.append(("upload_file", str(source_path), target_path))

    async def upload_dir(self, source_dir, target_dir):
        self.calls.append(("upload_dir", str(source_dir), target_dir))

    async def download_file(self, source_path, target_path):
        self.calls.append(("download_file", source_path, str(target_path)))

    async def download_dir(self, source_dir, target_dir):
        self.calls.append(("download_dir", source_dir, str(target_dir)))
        if source_dir == "/app":
            shutil.copytree(self.app_dir, target_dir, dirs_exist_ok=True)


@pytest.fixture
def world(tmp_path, monkeypatch):
    """A clean app folder, a passing fake selfcheck.sh, and no real secrets in the environment."""
    for name in agent_module.DEFAULT_SECRET_ENV:
        monkeypatch.delenv(name, raising=False)
    app = tmp_path / "app"
    app.mkdir()
    (app / "start.sh").write_text("#!/bin/sh\n")
    fake_check = tmp_path / "selfcheck.sh"
    fake_check.write_text(f'#!/bin/sh\necho "$1 $2" > {tmp_path}/selfcheck-args\necho PASS\n')
    fake_check.chmod(0o755)
    monkeypatch.setattr(agent_module, "SELFCHECK", str(fake_check))
    return SimpleNamespace(tmp=tmp_path, app=app, env=FakeEnvironment(app))


def make_agent(world, script, **options):
    (world.tmp / "script.json").write_text(json.dumps(script))
    command = f"{sys.executable} {FAKE_FACTORY} {world.tmp / 'script.json'} {world.tmp / 'transcript.jsonl'}"
    # Harbor's layout: logs_dir is <trial>/agent, which the task container mounts at /logs/agent.
    logs = world.tmp / "trial" / "agent"
    logs.mkdir(parents=True, exist_ok=True)
    return AgentFactory.create_agent_from_import_path(
        "ygg_harbor.agent:YggdrasilAgent", logs_dir=logs, command=command, **options
    )


def transcript(world):
    lines = [json.loads(l) for l in (world.tmp / "transcript.jsonl").read_text().splitlines()]
    return lines[0]["pid"], lines[1], lines[2:]


def run(world, script, timeout=None, **options):
    agent = make_agent(world, script, **options)
    context = AgentContext()
    coro = agent.run("Build client gallery lite.", world.env, context)
    asyncio.run(asyncio.wait_for(coro, timeout) if timeout else coro)
    return agent, context


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    # A zombie still answers kill(0); it has exited.
    return Path(f"/proc/{pid}/stat").read_text().split()[2] != "Z"


def test_the_agent_is_importable_by_path_and_needs_a_command(tmp_path):
    with pytest.raises(ValueError):
        AgentFactory.create_agent_from_import_path("ygg_harbor.agent:YggdrasilAgent", logs_dir=tmp_path)
    agent = AgentFactory.create_agent_from_import_path(
        "ygg_harbor.agent:YggdrasilAgent", logs_dir=tmp_path, command="true"
    )
    assert agent.name() == "yggdrasil"
    assert agent.options.budget_usd == 100


def test_the_start_message_carries_the_instruction_and_budget(world):
    run(world, [{"op": "done"}], budget_usd=42)
    _, start, _ = transcript(world)
    assert start == {
        "type": "start",
        "instruction": "Build client gallery lite.",
        "workdir": "/app",
        "budget_usd": 42,
    }


def test_exec_reaches_the_environment_and_the_reply_carries_the_result(world):
    script = [
        {"op": "exec", "command": "npm ci", "cwd": "/app", "env": {"CI": "1"}, "timeout_sec": 60, "user": "app"},
        {"op": "done"},
    ]
    run(world, script)
    assert ("exec", "npm ci", "/app", {"CI": "1"}, 60, "app") in world.env.calls
    _, _, replies = transcript(world)
    assert replies[0] == {"id": 0, "ok": True, "return_code": 7, "stdout": "ran npm ci", "stderr": "warn"}


def test_uploads_and_downloads_reach_the_environment(world):
    src = world.tmp / "src.txt"
    src.write_text("plain\n")
    script = [
        {"op": "upload_file", "source": str(src), "target": "/app/src.txt"},
        {"op": "upload_dir", "source": str(world.app), "target": "/app/sub"},
        {"op": "download_file", "source": "/app/a", "target": str(world.tmp / "a")},
        {"op": "download_dir", "source": "/app/d", "target": str(world.tmp / "d")},
        {"op": "done"},
    ]
    run(world, script)
    assert world.env.calls[:4] == [
        ("upload_file", str(src), "/app/src.txt"),
        ("upload_dir", str(world.app), "/app/sub"),
        ("download_file", "/app/a", str(world.tmp / "a")),
        ("download_dir", "/app/d", str(world.tmp / "d")),
    ]
    _, _, replies = transcript(world)
    assert all(r["ok"] for r in replies)


def test_the_selfcheck_op_runs_selfcheck_on_the_downloaded_app_with_the_task_image(world):
    run(world, [{"op": "selfcheck"}, {"op": "done"}])
    _, _, replies = transcript(world)
    assert replies[0] == {"id": 0, "ok": True, "passed": True, "detail": "PASS"}
    image, _ = (world.tmp / "selfcheck-args").read_text().split()
    assert image == "localhost/demo:1.0.0"


def test_done_runs_a_final_selfcheck_records_it_and_ends_the_factory(world):
    agent, context = run(world, [{"op": "done"}])
    pid, _, replies = transcript(world)
    assert replies[-1]["ok"] is True
    assert context.metadata["stop_reason"] == "done"
    assert context.metadata["selfcheck"] == {"passed": True, "detail": "PASS"}
    assert not alive(pid)


def test_a_failing_final_selfcheck_is_recorded_not_raised(world, monkeypatch):
    failing = world.tmp / "failing.sh"
    failing.write_text("#!/bin/sh\necho 'FAIL nothing answered on port 3000 within 120s'\nexit 1\n")
    failing.chmod(0o755)
    monkeypatch.setattr(agent_module, "SELFCHECK", str(failing))
    _, context = run(world, [{"op": "done"}])
    assert context.metadata["selfcheck"] == {
        "passed": False,
        "detail": "FAIL nothing answered on port 3000 within 120s",
    }


def test_a_task_without_a_prebuilt_image_fails_the_selfcheck(world):
    world.env.task_env_config.docker_image = None
    _, context = run(world, [{"op": "done"}])
    assert context.metadata["selfcheck"]["passed"] is False
    assert "docker_image" in context.metadata["selfcheck"]["detail"]


def test_spend_sets_the_cost_and_a_report_over_budget_stops_the_factory(world):
    script = [{"op": "spend", "usd": 40.5}, {"op": "spend", "usd": 100.25}, {"sleep": 60}, {"op": "done"}]
    _, context = run(world, script, timeout=20)
    pid, _, replies = transcript(world)
    assert replies[0]["ok"] is True
    assert context.cost_usd == 100.25
    assert context.metadata["stop_reason"] == "budget"
    assert context.metadata["spend_usd"] == 100.25
    assert not alive(pid)


def test_a_secret_in_an_exec_command_is_refused(world, monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", SECRET)
    run(world, [{"op": "exec", "command": f"echo {SECRET} > /app/.env"}, {"op": "done"}])
    _, _, replies = transcript(world)
    assert replies[0]["ok"] is False and "OPENROUTER_API_KEY" in replies[0]["error"]
    assert SECRET not in replies[0]["error"]
    assert not [c for c in world.env.calls if c[0] == "exec"]


def test_a_secret_in_an_exec_environment_is_refused(world, monkeypatch):
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN", SECRET)
    run(world, [{"op": "exec", "command": "claude -p hi", "env": {"TOKEN": SECRET}}, {"op": "done"}])
    _, _, replies = transcript(world)
    assert replies[0]["ok"] is False
    assert not [c for c in world.env.calls if c[0] == "exec"]


def test_a_secret_in_an_uploaded_file_is_refused(world, monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", SECRET)
    folder = world.tmp / "up"
    (folder / "deep").mkdir(parents=True)
    (folder / "deep" / "config.json").write_text(f'{{"key": "{SECRET}"}}')
    run(world, [{"op": "upload_dir", "source": str(folder), "target": "/app/x"}, {"op": "done"}])
    _, _, replies = transcript(world)
    assert replies[0]["ok"] is False and "ANTHROPIC_API_KEY" in replies[0]["error"]
    assert not [c for c in world.env.calls if c[0] == "upload_dir"]


def test_secret_env_names_come_from_the_option(world, monkeypatch):
    monkeypatch.setenv("MY_FACTORY_KEY", SECRET)
    run(world, [{"op": "exec", "command": f"echo {SECRET}"}, {"op": "done"}], secret_env=["MY_FACTORY_KEY"])
    _, _, replies = transcript(world)
    assert replies[0]["ok"] is False


def test_a_secret_in_the_final_app_fails_the_run(world, monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", SECRET)
    (world.app / "config.js").write_text(f"export const key = '{SECRET}';\n")
    agent = make_agent(world, [{"op": "done"}])
    context = AgentContext()
    with pytest.raises(RuntimeError, match="OPENROUTER_API_KEY"):
        asyncio.run(agent.run("brief", world.env, context))
    assert context.metadata["selfcheck"]["passed"] is False


def test_a_factory_that_exits_without_done_fails_the_run(world):
    agent = make_agent(world, [{"op": "exec", "command": "ls"}, {"exit": 3}])
    with pytest.raises(NonZeroAgentExitCodeError, match="exited with 3"):
        asyncio.run(agent.run("brief", world.env, AgentContext()))


def test_a_timeout_kills_the_factory(world):
    with pytest.raises(TimeoutError):
        run(world, [{"sleep": 60}, {"op": "done"}], timeout=2)
    pid, _, _ = transcript(world)
    assert not alive(pid)


def test_an_unknown_op_gets_an_error_reply_and_the_run_goes_on(world):
    _, context = run(world, [{"op": "teleport"}, {"op": "done"}])
    _, _, replies = transcript(world)
    assert replies[0]["ok"] is False and "teleport" in replies[0]["error"]
    assert context.metadata["stop_reason"] == "done"


def test_the_log_records_each_request_but_no_environment_values(world):
    script = [{"op": "exec", "command": "npm test", "env": {"DB_PASSWORD": "hunter2"}}, {"op": "done"}]
    agent, _ = run(world, script)
    log = (agent.logs_dir.parent / "yggdrasil" / "bridge.jsonl").read_text()
    entries = [json.loads(l) for l in log.splitlines()]
    assert [e["op"] for e in entries] == ["exec", "done"]
    assert entries[0]["command"] == "npm test" and entries[0]["return_code"] == 7
    assert "hunter2" not in log
    assert (agent.logs_dir.parent / "yggdrasil" / "factory.stderr.log").exists()


def all_text(folder: Path) -> str:
    return "".join(f.read_text(errors="replace") for f in folder.rglob("*") if f.is_file())


def test_a_refused_secret_reaches_no_log_and_the_container_mounted_folder_holds_no_log(world, monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", SECRET)
    script = [{"op": "exec", "command": f"echo {SECRET} > /app/.env"}, {"stderr": f"key is {SECRET}"}, {"op": "done"}]
    agent, _ = run(world, script)
    assert list(agent.logs_dir.iterdir()) == []
    host = agent.logs_dir.parent / "yggdrasil"
    assert SECRET not in all_text(host)
    assert "[redacted OPENROUTER_API_KEY]" in (host / "factory.stderr.log").read_text()


def test_the_factory_s_children_die_with_it_on_a_timeout(world):
    with pytest.raises(TimeoutError):
        run(world, [{"spawn": 60}, {"sleep": 60}, {"op": "done"}], timeout=3)
    lines = [json.loads(l) for l in (world.tmp / "transcript.jsonl").read_text().splitlines()]
    child = next(l["child"] for l in lines if "child" in l)
    assert not alive(child)


def test_a_cancelled_run_kills_a_running_selfcheck(world, monkeypatch):
    slow = world.tmp / "slow.sh"
    slow.write_text(f"#!/bin/sh\necho $$ > {world.tmp}/selfcheck-pid\nexec sleep 60\n")
    slow.chmod(0o755)
    monkeypatch.setattr(agent_module, "SELFCHECK", str(slow))
    with pytest.raises(TimeoutError):
        run(world, [{"op": "selfcheck"}, {"op": "done"}], timeout=3)
    assert not alive(int((world.tmp / "selfcheck-pid").read_text()))


def test_a_line_that_is_not_a_request_gets_an_error_reply_and_the_run_goes_on(world):
    _, context = run(world, [{"raw": "npm WARN deprecated"}, {"raw": "[1, 2]"}, {"op": "done"}])
    _, _, replies = transcript(world)
    assert replies[0]["ok"] is False and replies[1]["ok"] is False
    assert context.metadata["stop_reason"] == "done"


def test_done_ends_the_run_even_when_the_final_download_fails(world):
    async def broken(source_dir, target_dir):
        raise OSError("container is gone")

    world.env.download_dir = broken
    _, context = run(world, [{"op": "done"}])
    assert context.metadata["stop_reason"] == "done"
    assert context.metadata["selfcheck"]["passed"] is False
    assert "container is gone" in context.metadata["selfcheck"]["detail"]


def test_the_factory_gets_the_callers_container_settings_not_harbors(world, monkeypatch):
    monkeypatch.setenv("DOCKER_HOST", "unix:///root.sock")
    monkeypatch.setenv("CONTAINER_HOST", "unix:///root.sock")
    monkeypatch.setenv("DOCKER_CONFIG", "/tools/config")
    monkeypatch.setenv("REGISTRY_AUTH_FILE", "/tools/config/auth.json")
    monkeypatch.setenv("PATH", "/tools/bin:/usr/bin:/bin")
    monkeypatch.setenv("YGG_HARBOR_ORIG_ENV", json.dumps({
        "DOCKER_HOST": None, "CONTAINER_HOST": "unix:///user.sock", "DOCKER_CONFIG": None,
        "REGISTRY_AUTH_FILE": None, "PATH": "/usr/bin:/bin",
    }))
    run(world, [{"op": "done"}])
    env = json.loads((world.tmp / "transcript.jsonl").read_text().splitlines()[0])["env"]
    assert env == {"DOCKER_HOST": None, "CONTAINER_HOST": "unix:///user.sock", "DOCKER_CONFIG": None,
                   "REGISTRY_AUTH_FILE": None, "PATH": "/usr/bin:/bin", "YGG_HARBOR_ORIG_ENV": None}
