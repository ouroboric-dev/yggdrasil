# Proof runs

This page is for the founder, who runs the paid proof runs of Yggdrasil v0. It gives the order of the runs, the
command of each, what to look at while a run goes, what stops a run and how to continue, and what to write down
afterwards. The same page serves the next operator.

Every run is started by `ygg-proof-run.sh` (in `ouroboric/scripts`). It sets every run up the same way, so that
`ygg metrics --compare` compares two factories and not two setups. Run it from your `ouroboric` clone.
Commands here are written for zsh.

Two rules hold for every run:

- The suites folder is only ever passed by path (`--suites`). Nobody lists it, reads it or searches it, and no agent
  touches it. The script checks it with `test -d` and nothing more.
- The credentials file is never printed. The script checks it without reading it and loads it only inside the run's
  subshell.

## Before the first run

Nothing here costs money.

Build `ygg` from the merged `main` and check the engine, from the folder that holds your `ouroboric` and
`yggdrasil` clones side by side:

```zsh
(cd yggdrasil/odin && go build -o ~/.local/bin/ygg ./cmd/ygg)
cd ouroboric && scripts/ygg-engine.sh check
```

If the machine restarted since the last run, redo what a restart undoes, in a normal terminal tab (`sudo` needs one):

```zsh
sudo mkdir -p /mnt/wsl/ygg-bind && sudo mount --bind "$HOME/ygg-it" /mnt/wsl/ygg-bind
sudo mkdir -p "/run/user/$(id -u)" && sudo chown "$(id -u):$(id -g)" "/run/user/$(id -u)" && sudo chmod 700 "/run/user/$(id -u)"
```

In the OpenRouter dashboard, check that the key's limit is $25 a month and see what is left of it.

Check what the runs need and nothing more. Both lines print only a fact and a number, never a value; do not open the
suites folder or the credentials file:

```zsh
test -d ~/ygg-it/hidden-suites/client-gallery-lite/v2 && echo "the v2 suite folder is there"
grep -c -E '^(export[[:space:]]+)?(CLAUDE_CODE_OAUTH_TOKEN|OPENROUTER_API_KEY)=.' ~/.config/ouroboric/factory.env   # 2
```

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
| Rehearsal | v0-H19 | `rehearsal` | `step-by-step`; ends at `plan-gate`, before any code | `scripts/ygg-proof-run.sh --name rehearsal --mode step-by-step --build` |
| Run 1, the baseline | v0-H20 | `r1` | nothing: the setup every other run is held to | `scripts/ygg-proof-run.sh --name r1 --build --clip` |
| Run 1 again | v0-H21 | `r1b` | nothing; it is the spread | `scripts/ygg-proof-run.sh --name r1b --baseline RUN1 --clip` |
| Unattended run | v0-H27 | `r1u` | mode `unattended`; never one side of a comparison | `scripts/ygg-proof-run.sh --name r1u --mode unattended --clip` |
| Cross-model run | v0-H22 | `r2` | the implementer only: OpenCode with `openrouter/qwen/qwen3.8-27b` | `scripts/ygg-proof-run.sh --name r2 --implementer opencode:openrouter/qwen/qwen3.8-27b --baseline RUN1 --clip` |
| Improvement run | v0-H23 | `r3` | the factory change that part two (an amendment) brings | `scripts/ygg-proof-run.sh --name r3 --baseline RUN1 --clip` |

`RUN1` is the id of run 1, such as `20261024-101500-a1b2c3`. Write it in place of `RUN1` as it was printed.

The order is the table's order, with these gates between runs:

- Question 10 (does the brief fit the realms: A, B or C) is answered: option A, which is built and merged (the
  gallery-runtime change).
- The runs use `client-gallery-lite` 4.1.0, which is made (mimir#7 and mimir#8).
- Run 1's real size is read before the other runs start (see "Caps" below).
- The improvement run needs part two merged. It uses the same mode, roles and caps as run 1.
- Add `--dry-run` to any line above to check it first.
- `--build` builds the sandbox image of every realm. The rehearsal is the first real run and always has it. Run 1 has
  it too, because the images may be gone by then; a later run leaves it out while the images are there.

### The flags that the runs use

| Flag | Meaning | Used by |
| --- | --- | --- |
| `--name NAME` | the run's name: `a-z`, `0-9` and `-` | every run |
| `--mode MODE` | `key-points` (the default), `unattended` or `step-by-step` | rehearsal, `r1u` |
| `--implementer AGENT:MODEL` | the implementer; `AGENT` is `claude-code` or `opencode`, and an OpenCode `MODEL` is `openrouter/<model>` | `r2` |
| `--baseline RUN_ID` | also prints `ygg metrics --compare RUN_ID <this run>`; the baseline may be in any earlier proof folder under `--folder` (exactly one must hold it, or the script refuses before it starts anything) | `r1b`, `r2`, `r3` |
| `--continue RUN_ID` with `--approve GATE [--note TEXT]`, `--reject GATE --reason TEXT` or `--resume` | continues a stopped or paused run (see "Continue a stopped run") | after any stop |
| `--reviewer-reasoning LEVEL` | the reasoning effort of the reviewer role: `low`, `medium` (the default), `high` or `off`; a `claude-code` reviewer ignores it. `--continue` refuses it | none; the default holds |
| `--build` | builds the sandbox images first | rehearsal, `r1` |
| `--clip` | copies the report to the Windows clipboard | every scored run |
| `--dry-run` | stops after the plan, exit 0 | any |

The flags that no run in the table changes keep their defaults. They exist for another machine or for a test:

- Roles: `--planner AGENT:MODEL` (default `claude-code:sonnet`) and `--reviewer AGENT:MODEL` (default
  `opencode:openrouter/qwen/qwen3.8-27b`). The implementer defaults to `claude-code:sonnet`. The reviewer's reasoning
  is `--reviewer-reasoning`, in the table above; leave it at `medium` for every run of a comparison.
- Caps: `--run-turns`, `--run-tokens`, `--run-usd`, `--day-turns`, `--day-tokens` and `--day-usd`.
- Time: `--wall TIME` is a number and `s`, `m` or `h` (default `8h`).
- Places: `--folder DIR` (default `~/ygg-it`), `--env FILE` (the credentials file; default
  `~/.config/ouroboric/factory.env`), `--tasks DIR` (default `../mimir`), `--suites DIR` (default
  `~/ygg-it/hidden-suites`) and `--yggdrasil DIR`.

A run has a project and a folder: `DIR/proof-NAME-TIME/project` holds the project and the run, and
`DIR/proof-NAME-TIME/` holds `factory.yaml`, `run.txt` (the run's output with the credentials removed) and `report.txt`
(the evidence the script printed). A Ctrl-C or a closed terminal stops the run cleanly through the script and keeps the
report; after a closed terminal, what the script still prints goes to `hangup.txt` in the same folder. Every `ygg` command below needs `--project` with that project path; without it `ygg`
looks in the current folder and does not find the run.

## The product owner's decisions

Every proof run gives the same product decisions, word for word, so that the runs differ in the factory and not in
the product. The runs use task `client-gallery-lite` 4.1.0, and question 10 is answered (option A).

- At `design-gate`, approve with the first block as the note, passed through a variable (see "Pass a block" below).
  The note reaches every later stage as "The product owner's decisions".
- A note given when approving a gate node reaches every later stage. A note at a gate inside the task loop
  (`feature-gate`, `merge-gate`, `pointer-gate`, `contract-gate`) or at `plan-gate` reaches every later task. A note at
  an escalation or another hard stop is not kept for the later stages: it stays on the event. Give a note at another
  gate only for a decision. A second approval with a blank note keeps the gate's earlier note; a note that is not
  blank replaces it. A note is one line: no control characters (C1 ones too) and no line or paragraph separators.
- If the spec at `spec-gate` still lacks a decision, reject it with the second block, passed the same way. A
  rejection drops the notes of the gates it goes back past: a `spec-gate` rejection keeps the `design-gate` note, but
  a rejection that goes back before `design-gate` does not.

The note for `design-gate`:

```text
Product owner's answers (2026-10-22), for every run: 1. Add a password reset: primarily by email, with security questions set at sign-up as the second way. The graded machine has no outside services and no network, so the email sender is configurable; with none configured, each reset email is written to a local outbox file under /app/.data/ that the operator can read. 2. Photographers can delete photos, galleries and their own account. 3. The client's email step says that the photographer will see the email entered. 4. Storage cap: 10 GB per photographer by default, configurable per photographer. 5. A change of a gallery password or PIN logs out the clients already in, and a photographer's password change logs out their other sessions.
```

The reason for rejecting `spec-gate`:

```text
The product owner answered the design's open questions at the design gate (2026-10-22), and the answers apply to every run. The spec must include them, with routes, data model, acceptance criteria and tests, and list each one under "Deviations from the design doc" as the product owner's decision: 1. A password reset for photographers: primarily by email, with security questions set at sign-up as the second way. The graded machine has no outside services and no network, so the email sender is configurable; with none configured, each reset email is written to a local outbox file under /app/.data/ that the operator can read. 2. Photographers can delete photos, galleries and their own account. 3. The client's email step says that the photographer will see the email entered. 4. A storage cap of 10 GB per photographer by default, configurable per photographer. 5. A change of a gallery password or PIN logs out the clients already in, and a photographer's password change logs out their other sessions.
```

### Pass a block

The second block holds double quotes and both blocks hold apostrophes, so never paste a block between quotes on the
command line: zsh breaks the command without a word. Put the block in a variable with a quoted heredoc, then pass the
variable. For the note at `design-gate`:

```zsh
N=$(cat <<'EOF'
<paste the first block here>
EOF
)
scripts/ygg-proof-run.sh --continue RUN --approve design-gate --note "$N"
```

For the reason at `spec-gate`:

```zsh
R=$(cat <<'EOF'
<paste the second block here>
EOF
)
scripts/ygg-proof-run.sh --continue RUN --reject spec-gate --reason "$R"
```

## The rehearsal

The rehearsal plans the gallery and writes no code. There is no plan-only flag: "plans only" is `--mode step-by-step`
and you not approving `plan-gate`. In that mode the run stops at each gate with exit 3 and is not graded. It costs the
planner's sessions and the two reviewers: cents to a dollar, an estimate and not a measure.

1. Start it with the command in the table.
2. At each stop, read the gate file, `PROJECT/.factory/runs/RUN/gates/design-gate-1.md`, then `spec-gate-1.md`, and so on.
   Approve the design and the spec gates, each with the `--continue` command that the script prints (see "Continue a
   stopped run"). Each approve is a separate `--continue` command, and each one has its own wall clock. Do not approve
   `plan-gate`: the run ends there. `report.txt` still holds the metrics and the report of the run. The rehearsal
   (v0-H19, T01) is done, and it predates the decisions rule: the proof runs approve and reject by "The product
   owner's decisions", not by this step.
3. Read the design, the spec, the plan (`docs/2-engineering/plans/*/tasks.md` in the project) and `docs/leaves.yaml`.
4. Answer five questions from what you read: which leaves and realms the plan uses; how the design makes
   `/app/start.sh` start the whole product on port 3000 with no outside service; where it keeps data and photos; how
   many tasks, and of which sizes; and whether the conformance or the reuse reviewer found anything.
5. Read the run, and send the five answers with both outputs and the design documents:

```zsh
ygg metrics RUN --project PROJECT
ygg report RUN --project PROJECT
```

Question 10 was decided from the answers: option A.

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
- An `escalation` gate stops in every mode (exit 3). Read it and rule on it.
- In `key-points`, the plan, feature, merge and pointer gates pass by themselves, except the contract case below.
- In `key-points`, a contract change stops the run at a `pointer-contract` gate. Read it, then approve with
  `--continue RUN --approve GATE --note "..."`. A note makes it an intervention, which is the point of the mode. To
  reject, use `--continue RUN --reject GATE --reason "..."` (see "Continue a stopped run").
- In `unattended`, a gate that would stop for a deviation blocks the task and the run goes on. A disputed finding
  blocks the task too.

## What stops a run

| Stop | How it shows | What to do |
| --- | --- | --- |
| A cap (`budget-cap`) | exit 3 | a gate: read how far it got with `ygg metrics` and decide. To continue, raise the cap while the run is stopped (see "Caps"), then `--continue RUN --approve GATE` |
| A gate | exit 3 | read the gate file; `scripts/ygg-proof-run.sh --continue RUN --approve GATE [--note "..."]`. To reject, `--continue RUN --reject GATE --reason "..."` |
| The provider's quota | exit 4 (paused) | wait for the quota, then `--continue RUN --resume` |
| The wall clock (`--wall`) | exit 124 (the script's `timeout` interrupted the run) | see "After a wall clock stop" below; the script ran `ygg doctor` |
| Ctrl-C, TERM, a closed terminal | exit 130, 143, 129 | the script stopped the run, ran `ygg doctor` and kept the report (`hangup.txt` for 129). Continue with `--continue RUN --resume` only if the run is unfinished |
| A node failed | exit 1 | read `run.txt` and the status; this is a finding, not a retry. The script runs `ygg doctor` to stop what the run left |
| Done with tasks given up | exit 5 | the run finished; the report lists the given-up tasks first |

### Continue a stopped run

A run that stopped (3) or paused (4) is not graded until it ends. The script continues it itself, with the same wall
clock, the credentials loaded only inside its own subshell, the same filter, and the output added to `run.txt` and
`report.txt`. After it finishes, it grades the run, prints the metrics, the report and the evidence, and the
comparison with the baseline the run recorded (`--baseline` names another; if the recorded baseline has since gone,
`--continue` drops the comparison with a warning and goes on). You do not load the credentials in your shell.

The last lines of the script after a stop are the command to run. After a gate stop they are:

- `proof-run: or by hand, outside this script ...`, then the raw `ygg-engine.sh ... ygg approve` and `ygg reject`
  lines. Ignore them.
- `proof-run: the run stopped at GATE; read its gates folder. If ygg offered a rejection above, reject it with a
  reason:` and then the `ygg-proof-run.sh --reject` command.
- `proof-run: or approve it (add --note TEXT if you like; some stops take no rejection or no approval):` and then the
  `ygg-proof-run.sh --approve` command, the last line. Run the one that you decide on, and only if its stop offers it.

After a pause, the last lines are the same, with `proof-run: the run paused (the provider's quota); once it is back,
continue it:` and the `--resume` command. The forms are:

```zsh
scripts/ygg-proof-run.sh --continue RUN --approve GATE [--note "..."]
scripts/ygg-proof-run.sh --continue RUN --reject GATE --reason "..."
scripts/ygg-proof-run.sh --continue RUN --resume
```

Add `--clip` to copy the report, `--wall TIME` for another wall clock, and `--folder` and `--env` only if the first
command used them. `--continue` refuses the setup flags (`--name`, `--mode`, the roles, `--reviewer-reasoning`, the
caps, `--build`, `--tasks`, `--suites` and `--yggdrasil`): the run keeps its config and its mode. Add `--dry-run` to
see what it would do. A note on `--approve` makes an intervention. A rejection takes `--reason` and no `--note`; it
advances the run at once, so it starts sessions as an approval does. A proof folder made before `--reviewer-reasoning`
continues, and the plan shows "reasoning unset".

Never edit `factory.yaml` while a process holds the run; a stop at `budget-cap` is the one time you edit it, before you
approve.

The raw fallback runs without the wall clock, the filter, `run.txt` or the report, so use it only if the script cannot.
Then the credentials must be in the shell that runs it, and nowhere else. Open a fresh shell, load them without printing
them, run the printed raw command, and close the shell:

```zsh
set -a; . ~/.config/ouroboric/factory.env; set +a
```

The script's `--reject` is the way to reject. If the script cannot, run this raw command (`ygg reject` takes `--reason`,
not `--note`), then read the run, or continue it with
`scripts/ygg-proof-run.sh --continue RUN --resume` if the rejection left it paused:

```zsh
scripts/ygg-engine.sh run --folder ~/ygg-it -- ygg reject RUN GATE --reason "..." --project PROJECT
```

Never pass `--mode` to a raw `ygg approve`, `ygg reject` or `ygg resume` on a scored run: the run keeps the mode it began
with. Never `cat` or `echo` the file or a variable. A run continued by raw commands is not graded by the script and has no new
`report.txt`. Grade it yourself once it is done, and read it with the commands of "Reading the results":

```zsh
ygg grade RUN --project PROJECT
```

### After a wall clock stop

At exit 124 the script's `timeout` interrupted the run, and, like any abnormal end (an exit other than 0, 3, 4 and 5), the
script ran `ygg doctor` to stop the sandboxes the run left. It prints no continue command. Read `run.txt`, run
`ygg status RUN --project PROJECT` and read the end of the ledger. Continue only if the run is unfinished:

```zsh
scripts/ygg-proof-run.sh --continue RUN --resume
```

### Caps

The defaults are the assumed ones: per run 1,500 turns, 12 million tokens and $5 billed; per day 2,000 turns, 24 million
tokens and $10 billed. The dollar caps count what a paid API billed, not the estimate for a Claude Code session on the
subscription. The OpenRouter key's $25 a month is the backstop.

A stop at `budget-cap` (exit 3) is a gate. Read `ygg metrics` and decide. To continue, raise the cap in that run's own
`factory.yaml` (the one in `DIR/proof-NAME-TIME`, never your `~/ygg-it/factory.yaml`) while the run is stopped. Then run
the printed `ygg-proof-run.sh --continue RUN --approve GATE` command.

Run 1's final size (turns, tokens and billed dollars) is written in the journal and sets the caps of `r1b`, `r2`, `r3` and
`r1u` from their start. The caps may change after run 1. `ygg metrics --compare` then lists the config as a difference of
setup. That does not make the pair not comparable: only another brief, task version, suite or mode does. Set a cap with
`--run-turns`, `--run-tokens`, `--run-usd` or the `--day-*` flags on the command, before the run starts.

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

A run is repeated only with the same brief, task version, graph, mode and suite. The script checks the brief's SHA-256
against `task.toml`, so a changed brief is refused. Hosted models change from hour to hour, so one run is
thin and the second says how thin. A later change must beat the spread of the repeat to mean anything.

Tell that a pair was not repeated: `ygg metrics --compare` printed `comparable: no`. It names the reason (another brief,
task version, suite or mode). Also look at the config hash and the roles in its output: a role or a cap you changed by
hand shows there as a difference of setup.

## The journal entry

Each scored run gets a journal entry in the [journal](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/6-journal/README.md).
The rule: the public journal quotes aggregate numbers and links a run by id only. It never quotes a ledger line, a
transcript, a hidden test or a path into the suites folder. Check it with `scripts/journal-check.sh` (in `ouroboric`).

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
