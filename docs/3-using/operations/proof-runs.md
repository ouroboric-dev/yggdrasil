# Proof runs

This page is for the founder, who runs the paid proof runs of Yggdrasil v0. It gives the order of the runs, the
command of each, what to look at while a run goes, what stops a run and how to continue, and what to write down
afterwards. The same page serves the next operator.

Every run is started by `ygg-proof-run.sh` (in `ouroboric/scripts`). It sets every run up the same way, so that
`ygg metrics --compare` compares two factories and not two setups. Run it from `~/brunogbv/ouroboric/ouroboric`.
Commands here are written for zsh.

Two rules hold for every run:

- The suites folder is only ever passed by path (`--suites`). Nobody lists it, reads it or searches it, and no agent
  touches it. The script checks it with `test -d` and nothing more.
- The credentials file is never printed. The script checks it without reading it and loads it only inside the run's
  subshell.

## Before the first run

Nothing here costs money.

Build `ygg` from the merged `main` and check the engine:

```zsh
cd ~/brunogbv/ouroboric/yggdrasil/odin && go build -o ~/.local/bin/ygg ./cmd/ygg
cd ~/brunogbv/ouroboric/ouroboric && scripts/ygg-engine.sh check
```

If the machine restarted since the last run, redo what a restart undoes, in a normal terminal tab (`sudo` needs one):

```zsh
sudo mkdir -p /mnt/wsl/ygg-bind && sudo mount --bind /home/brunogbv/ygg-it /mnt/wsl/ygg-bind
sudo mkdir -p /run/user/1000 && sudo chown 1000:1000 /run/user/1000 && sudo chmod 700 /run/user/1000
```

In the OpenRouter dashboard, check that the key's limit is $25 a month and see what is left of it.

Then do the dry run of the run you are about to start. It spends nothing and loads no credential. Expect
`dry run: nothing was started`, the roles, the caps and exit 0:

```zsh
scripts/ygg-proof-run.sh --name rehearsal --mode step-by-step --dry-run
```

## The runs

The brief, the graph (`software`), the realms, the task and its suite are the same in every run. The table gives what
differs. Every run of a comparison is `key-points`.

| Run | Task | Name | What differs | Command |
| --- | --- | --- | --- | --- |
| Rehearsal | v0-H19 | `rehearsal` | `step-by-step`; stops at `plan-gate`, before any code | `scripts/ygg-proof-run.sh --name rehearsal --mode step-by-step --build` |
| Run 1, the baseline | v0-H20 | `r1` | nothing: the setup every other run is held to | `scripts/ygg-proof-run.sh --name r1 --build --clip` |
| Run 1 again | v0-H21 | `r1b` | nothing; it is the spread | `scripts/ygg-proof-run.sh --name r1b --baseline RUN1 --clip` |
| Unattended run | v0-H27 | `r1u` | mode `unattended`; never one side of a comparison | `scripts/ygg-proof-run.sh --name r1u --mode unattended --clip` |
| Cross-model run | v0-H22 | `r2` | the implementer only: OpenCode with `openrouter/qwen/qwen3.8-27b` | `scripts/ygg-proof-run.sh --name r2 --implementer opencode:openrouter/qwen/qwen3.8-27b --baseline RUN1 --clip` |
| Improvement run | v0-H23 | `r3` | the factory change that part two (an amendment) brings | `scripts/ygg-proof-run.sh --name r3 --baseline RUN1 --clip` |

`RUN1` is the id of run 1, such as `20261024-101500-a1b2c3`. Write it in place of `RUN1` as it was printed.

The order is the table's order, with these gates between runs:

- Question 10 (does the brief fit the realms: A, B or C) is decided after the rehearsal. Run 1 waits for it, and for
  what it requires to be built and merged.
- Run 1's real size is read before the other runs start (see "Caps" below).
- The improvement run needs part two merged. It uses the same mode, roles and caps as run 1.
- Add `--dry-run` to any line above to check it first. Add `--build` to the first real run, and again whenever the
  sandbox images are gone: it builds the sandbox image of every realm.

### The flags that the runs use

| Flag | Meaning | Used by |
| --- | --- | --- |
| `--name NAME` | the run's name: `a-z`, `0-9` and `-` | every run |
| `--mode MODE` | `key-points` (the default), `unattended` or `step-by-step` | rehearsal, `r1u` |
| `--implementer AGENT:MODEL` | the implementer; `AGENT` is `claude-code` or `opencode`, and an OpenCode `MODEL` is `openrouter/<model>` | `r2` |
| `--baseline RUN_ID` | also prints `ygg metrics --compare RUN_ID <this run>` | `r1b`, `r2`, `r3` |
| `--build` | builds the sandbox images first | rehearsal, `r1` |
| `--clip` | copies the report to the Windows clipboard | every scored run |
| `--dry-run` | stops after the plan, exit 0 | any |

The flags that no run in the table changes keep their defaults. They exist for another machine or for a test:

- Roles: `--planner AGENT:MODEL` (default `claude-code:sonnet`) and `--reviewer AGENT:MODEL` (default
  `opencode:openrouter/qwen/qwen3.8-27b`). The implementer defaults to `claude-code:sonnet`.
- Caps: `--run-turns`, `--run-tokens`, `--run-usd`, `--day-turns`, `--day-tokens` and `--day-usd`.
- Time: `--wall TIME` is a number and `s`, `m` or `h` (default `8h`).
- Places: `--folder DIR` (default `~/ygg-it`), `--env FILE` (the credentials file; default
  `~/.config/ouroboric/factory.env`), `--tasks DIR` (default `../mimir`), `--suites DIR` (default
  `~/ygg-it/hidden-suites`) and `--yggdrasil DIR`.

A run has a project and a folder: `DIR/proof-NAME-TIME/project` holds the project and the run, and
`DIR/proof-NAME-TIME/` holds `factory.yaml`, `run.txt` (the run's output with the credentials removed) and `report.txt`
(the evidence the script printed). Every `ygg` command below needs `--project` with that project path; without it `ygg`
looks in the current folder and does not find the run.

## The rehearsal

The rehearsal plans the gallery and stops at `plan-gate` (exit 3), before any code is written. It costs the planner's
sessions and the two reviewers: cents to a dollar, an estimate and not a measure.

1. Start it with the command in the table.
2. At each stop, read the gate file, `PROJECT/.factory/runs/RUN/gates/GATE-1.md`, and approve the design and the spec
   gates with the command that the script prints. Do not approve `plan-gate`.
3. Read the design, the spec, the plan (`docs/2-engineering/plans/*/tasks.md` in the project) and `docs/leaves.yaml`.
4. Answer five questions from what you read: which leaves and realms the plan uses; how the design makes
   `/app/start.sh` start the whole product on port 3000 with no outside service; where it keeps data and photos; how
   many tasks, and of which sizes; and whether the conformance or the reuse reviewer found anything.
5. Read the run, and send the five answers with both outputs and the design documents:

```zsh
ygg metrics RUN --project PROJECT
ygg report RUN --project PROJECT
```

Question 10 is decided from the answers.

## During a run

A run is long. Use three terminals.

- Second terminal, before the run starts: `scripts/ygg-events-watch.sh`. It watches the `podman events` process that the
  `devcontainer` CLI starts, for B-051 (the first `devcontainer up` hangs about half the time). Gleipnir's retry limits
  the damage. Do not change the retry.
- Third terminal, once the run has an id and a project: `ygg status RUN --watch --project PROJECT`. It prints the status
  every two seconds (`--interval` changes that), with a `now:` line that names the node, its attempt, how long it has
  run and the cost so far. It stops when the run stops running. It reads a ledger that is being written and does not
  check its chain.
- `ygg board --project PROJECT` shows the tasks by column: Ready, In progress, Verifying, Blocked, Needs you and Done.
  Look at it between stops. To see every project, add the project to the list that `ygg board --all` reads and run
  that:

```zsh
mkdir -p ~/.config/ouroboric
printf 'projects:\n  - %s\n' "PROJECT" >> ~/.config/ouroboric/projects.yaml
ygg board --all
```

`ygg metrics` of a run that is still writing may refuse, because its last line is half written. Read the metrics
when the run has stopped, and use `ygg status --watch` meanwhile.

### Gates you will meet

- The design gate stops in every mode. Read the gate file and approve with the command the script prints.
- In `key-points`, a contract change stops the run at a `pointer-contract` gate. Read it, then approve or reject with a
  note. A note makes it an intervention, which is the point of the mode.
- In `unattended`, a gate that would stop for a deviation blocks the task and the run goes on. A disputed finding
  blocks the task too.

## What stops a run

| Stop | How it shows | What to do |
| --- | --- | --- |
| A cap (`budget-cap`) | exit 3 | read how far it got with `ygg metrics`, decide, and raise the cap in `factory.yaml` before you continue |
| A gate | exit 3 | read the gate file; `ygg approve` or `ygg reject` |
| The provider's quota | exit 4 (paused) | wait for the quota, then `ygg resume` |
| The wall clock (`--wall`) | exit 124 (the script's `timeout` interrupted the run) | read the run and its status first; if the run is not finished, `ygg resume` it |
| A node failed | exit 1 | read `run.txt` and the status; this is a finding, not a retry |
| Done with tasks given up | exit 5 | the run finished; the report lists the given-up tasks first |

A run that stopped (3) or paused (4) is not graded. The script ends with the command that continues it. Run it under
`ygg-engine.sh`, because `ygg approve` and `ygg resume` need the engine environment:

```zsh
scripts/ygg-engine.sh run --folder ~/ygg-it/proof-NAME-TIME -- ygg approve RUN GATE --note "..." --project PROJECT
scripts/ygg-engine.sh run --folder ~/ygg-it/proof-NAME-TIME -- ygg resume RUN --project PROJECT
```

`ygg resume` also takes `--mode`. A run that ended 0 or 5 was graded by the script. For one you continued by hand, grade
it yourself with `ygg grade RUN --project PROJECT` once it is done.

### Caps

The defaults are the assumed ones: per run 1,500 turns, 12 million tokens and $5 billed; per day 2,000 turns, 24 million
tokens and $10 billed. The dollar caps count what a paid API billed, not the estimate for a Claude Code session on the
subscription. The OpenRouter key's $25 a month is the backstop.

Run 1's real size is read before the other runs start: write it in the journal. It sets the caps of the others, and the
caps may change. Raise a cap with `--run-turns`, `--run-tokens`, `--run-usd` or the `--day-*` flags on the run, and keep
the same values across the runs of a comparison. A cap that differs is a difference of setup.

## Reading the results

When a run ends 0 or 5 the script has graded it and printed `ygg metrics`, `ygg report`, the cost and the evidence into
`report.txt`. With `--baseline` it also printed the comparison. Read them again at any time:

```zsh
ygg metrics RUN --project PROJECT
ygg metrics --compare RUN1 RUN --project PROJECT
ygg report RUN --project PROJECT
```

`ygg report RUN --commit` also commits a copy as `docs/runs/RUN.md` in the project, because a project ignores `.factory/`.

### `ygg metrics`

`ygg metrics` checks the ledger's hash chain first and refuses a ledger that was changed or cut short. A rate over
nothing says `n/a`. It writes nothing. `--json` prints the same figures for a tool, and `first..last` lists every run of
a project with a total line.

- Tokens and turns: the sum of the sessions. The run's own totals repeat them and are left out.
- Cost: two figures, **at API prices** (the sum of the cost fields) and **billed** (the part from a paid adapter, which is
  anything but `claude-code` and `scripted`). A session with tokens and no cost is **unpriced**: its cost is unknown, not
  zero.
- Wall time: **elapsed** (first line to the end) minus the approval waits and the stopped time, which leaves the
  **active** time. Grading is grade time.
- First-pass rate: the loops that passed in attempt 1, out of the loops that ended (passed or gave up).
- Average loop attempts: the attempt each ended loop ended in, averaged.
- Reviewer veto rate: the attempts in which a reviewer raised or reopened a `blocker` or `major` finding, out of the
  attempts in which a reviewer ran. A failing check is not a veto.
- Interventions: rejections, approvals with a note, and escalations, each listed with where and what was said.
- Blocked tasks: the tasks the run recorded as blocked, each with why.
- Hidden acceptance score: the reward and the tallies of `score.json`.
- Escaped defects: the fail-to-pass scenarios that failed. With tasks given up, some failures are work that was never
  built.
- Routing: the indexes built and what they scored, or "not measured".

### `ygg metrics --compare`

The comparison is B minus A: the first id is the baseline. It prints what differed (the factory build, the config hash,
the agent and model of each role, the realm versions, the mode and the graph) and the deltas. A comparable pair names the
metrics that improved and the ones that got worse, and says whether the hidden score held (`reward: held`). A metric with
no direction, such as the veto rate, is shown and never judged.

A pair of another brief, task version, suite or mode is `comparable: no`, with the reason. The deltas still print, but the
pair gets no verdict: `verdict: not judged: the runs are not comparable`. For the unattended run this is the expected
result. For any other pair it means the setup drifted. Do not use that pair.

### `ygg report`

`ygg report` writes `report.md` into the run's folder: the tasks the run gave up first, the metrics, every intervention
with its note, the loops that gave up, and each finding a dispute overruled with both sides. It names the ledger line it
was read from, and the same run always gives the same bytes.

## Repeating a run

A run is repeated only with the same brief, graph, mode and suite. Hosted models change from hour to hour, so one run is
thin and the second says how thin. A later change must beat the spread of the repeat to mean anything.

Tell that a pair was not repeated: `ygg metrics --compare` printed `comparable: no`. It names the reason (another brief,
task version, suite or mode). Also look at the config hash and the roles in its output: a role or a cap you changed by
hand shows there, and the pair is not a repeat of that setup.

## The journal entry

Each scored run gets a journal entry in the [journal](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/6-journal/README.md).
The rule: the public journal quotes aggregate numbers and links a run by id only. It never quotes a ledger line, a
transcript, a hidden test or a path into the suites folder. Check it with `scripts/journal-check.sh`.

Name the file `YYYY-MM-DD-short-title.md`, add a row to the journal's `README.md`, and use this shape:

```markdown
---
date: 2026-10-24
tags: [proof-run, baseline]
status: open
post-candidate: no
evidence: ["run 20261024-101500-a1b2c3"]
---
## Challenge

What the run set out to show, in one or two sentences.

## Context

The setup: brief, graph, mode, the three roles and their models, the caps.

## Options

What else could have been run, and why this.

## Decision

What was run, and the command.

## Result

Aggregate numbers only: first-pass rate, average attempts, cost at API prices and billed, active time, interventions,
blocked tasks, reward and escaped defects. For a repeat, the spread. For the unattended run, which tasks were
blocked and why, and how many escalations came from the contract folder rules (B-135).

## Lessons

What the next run does differently.
```

Entry rules:

- A first-run entry is `status: open`. The improvement run's entry is `status: resolved` with the tag `factory-change`:
  its Result cites `ygg metrics --compare RUN1 RUN3` with both run ids, the change, the numbers and the spread.
- Run ids are the only link to a run.
- Run `scripts/journal-check.sh` and fix what it says.

## Exit check and retiring the hidden suite

After v0-H20 to v0-H23 and v0-H27, the exit check (v0-H25) takes the seven criteria of the design doc one at a time and
finds the evidence for each in the runs above. Retiring the v0 hidden suite (v0-H26) is the founder's alone: no agent reads
or copies a suite.

## The Harbor bridge (optional)

`ygg bridge --config FACTORY.YAML --graph GRAPH [--work DIR] [--mode MODE]` is the factory's side of the Harbor bridge.
The Harbor adapter starts it; you do not run it by hand. The steps are in `bench/harbor/README.md`, under "A run": pass
the command above with `--ak "command=ygg bridge ..."`, a config of scripted agents and a new work folder. Afterwards
check `<trial>/yggdrasil/bridge.jsonl` for `spend`, `upload_dir`, `selfcheck` and `done` requests, each answered, and
`factory.stderr.log` for the run's exit code.
