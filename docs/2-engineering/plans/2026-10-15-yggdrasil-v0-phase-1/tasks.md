---
title: Yggdrasil v0, Phase 1 tasks (contract and walking skeleton)
status: accepted
date: 2026-10-15
related: [../2026-10-12-yggdrasil-v0/plan.md, ../2026-10-12-yggdrasil-v0/tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../changes/2026-10-12-require-budget-caps/tasks.md]
style: spec
---

# Yggdrasil v0, Phase 1: contract and walking skeleton

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking. Tasks and steps marked **founder** are done by the founder,
> never by an agent.

**Goal:** the [plan](../2026-10-12-yggdrasil-v0/plan.md)'s Phase 1 exit criterion. A scripted toy graph
runs end to end in all three modes, stops at gates, resumes, and refuses to run without complete caps.
CI is green and required.

**Architecture:** Gungnir gets the contract: the `Agent` interface, approval points and modes,
findings, ledger events, and JSON schemas for `factory.yaml`, `graph.yaml` and `pack.yaml`, each with a
strict parser. Gleipnir gets the `scripted` adapter. Odin gets the hash-chained ledger, `run.json`,
the mode × approval-point table, the engine for exec, agent and gate nodes, and the `ygg` command
line. A toy realm in `odin/testdata/toy/` drives the end-to-end tests that CI runs.

**Tech stack:** Go 1.26; `go.yaml.in/yaml/v3`, `github.com/santhosh-tekuri/jsonschema/v6`;
GitHub Actions; Bash for the `ouroboric` scripts.

**Spec:** [v0 engineering spec](../../specs/2026-10-11-yggdrasil-v0-spec.md) §1, §2, §3.3, §4.1–§4.4,
§4.6, §7, §10.1, §12, §13, and the accepted change
[require budget caps](../../changes/2026-10-12-require-budget-caps/tasks.md), whose
`require-budget-caps-T001` is done here, in v0-T021 and v0-T031 to v0-T036.

**Status:** accepted when the founder merges the pull request that adds this file.

**Code in this plan was run.** Every Go file, schema and test below was built and run in a scratch Go
workspace on 2026-10-15, with `go test -race` on Go 1.26.4 and 1.26.9. Each task's end state was also
built and tested on its own. Copy the code as written; if a step's expected result differs, stop and
report it, because the plan is wrong.

## Decisions for this phase

Each line is **Decided 2026-10-15** when the founder merges this plan.

1. **The SDD ledger folder.** This file is `tasks.md`, as every plan folder names it
   (`plans/README.md`). Superpowers' `sdd-workspace` names a workspace after the plan file's basename.
   It also keeps a `plan-path` marker, and adds the parent folder's name on a clash. Phase 0's
   `.superpowers/sdd/tasks/` names Phase 0's plan, so this plan's workspace is
   `.superpowers/sdd/tasks-2026-10-15-yggdrasil-v0-phase-1/`. This was checked by running the script on
   this file. The controller resolves the folder with `sdd-workspace`, never by hand. The Phase 0
   ledger stays where it is, unchanged; archiving it is the founder's call.
2. **Module versions.** A component requires its siblings at the pseudo-version of a commit on the
   sibling's `main`. `go.work` is for local work only, and CI builds with `GOWORK=off`. So a change
   that spans repos merges in dependency order: `gungnir`, then `gleipnir`, then `odin`. Each consumer
   PR pins the merged commit with `GOWORK=off go get github.com/ouroboric-dev/<dep>@<sha>`. Tags wait
   until an interface settles (spec §1). The pins resolve through `proxy.golang.org`. A `direct`
   fetch would go through the founder's global https→ssh rewrite and fail, so a pin must name a
   pushed commit.
3. **The founder pushes CI files.** GitHub refuses a GitHub App's push to `.github/workflows/` unless
   the App has the `workflows` permission, and the pr-bot doesn't have it (`scripts/pr-bot.json`).
   That stays so: an agent that could edit CI could weaken the check that gates its own PRs
   (invariant 7). The agent prepares the commits, and the founder pushes them (v0-H05). The other
   option, giving the bot `workflows: write`, is not taken.
4. **No sandbox and no leaf yet.** Agents and exec nodes work in `<project>/workspace/`, beside
   `.factory/`, never inside it. Exec nodes run on the host, without a shell, with only `PATH`, `HOME`
   (the workspace) and `LANG`. So neither `CLAUDE_CODE_OAUTH_TOKEN` nor `ANTHROPIC_API_KEY` reaches
   them, in line with the Phase 0 ruling that the sandbox never carries `ANTHROPIC_API_KEY`. Phase 2
   replaces the workspace with the leaf, and Phase 3 moves leaf commands into the sandbox. Phase 1
   runs only the `scripted` adapter. It calls no model and needs no Podman. The `claude-code` adapter
   (Phase 3) will use `--setting-sources user --strict-mcp-config`, never `--bare`.
5. **Paid-API roles.** Whether a role bills a paid API comes from its adapter. `claude-code` runs on a
   subscription and `scripted` costs nothing. Every other adapter, `opencode` and any future one,
   counts as paid, so the caps need `usd`. There is no billing field per role.
6. **Gate overrides only tighten.** `gates:` may set `stop` on any soft approval point. The one
   loosening is `design: auto`, and only in unattended mode (spec §7.1, "explicit override only").
   Hard approval points can't be named at all. The overrides are checked at start and at every
   `--mode` switch.
7. **Gate names.** On the command line, the gate node's id names the approval point:
   `ygg approve <run> design-gate`. Gate files are `gates/<node>-<n>.md`, one each time the gate is
   reached, so a rejection loop keeps the file of every decision.
8. **Resume, in Phase 1, works from `run.json`.** It restarts the interrupted node from scratch, as
   attempt n+1. Checkpoint commits and the leaf reset come in Phase 2 (spec §4.3). A killed process
   leaves the run `running` with no lock held, and `status` and `doctor` report it as interrupted.
9. **The `Agent` contract.** Spec §2.2 leaves the method set to the plan. `Task` gains `Node`,
   `Attempt` and `TranscriptDir`. `Result.Validate` refuses a malformed result, and usage from a
   malformed result never counts.
10. **Exit codes.** 0: done. 1: a node failed. 2: refused, and nothing ran. 3: stopped at an
    approval point.
11. **Budget caps.** Phase 1 refuses to run without complete caps (`require-budget-caps-T001`).
    Stopping a run at the `budget-cap` approval point is Phase 4, as the plan's table says. Nothing in
    Phase 1 spends tokens. **For Phase 3's tasks:** its real sessions run before Phase 4's
    enforcement, so Phase 3 must bound each one (one session, `MaxTurns` set).
12. **The CI image is `golang:1.26.9-bookworm`, not the scaffolds' 1.26.7.** On 1.26.7,
    `govulncheck` v1.8.0 reports GO-2026-6604 (`os.Root`, fixed in 1.26.9) as reachable through the
    `scripted` adapter. That would fail the required check from day one. On 1.26.9 it reports no
    reachable vulnerability (both checked on 2026-10-15). The image was pushed on 2026-10-08, so it
    meets the two-week rule on **2026-10-22**, and v0-T028 doesn't push before then. The three CI
    repos' devcontainers move to the same digest in the same commit. The other three move when they
    get code.
13. **A check is required only where CI exists.** `setup-repo.sh` requires the `test` check exactly
    when the repo has `.github/workflows/ci.yml` on `main`, and `check-repos.sh` expects it on the same
    condition. Phase 1 adds CI to `gungnir`, `gleipnir` and `odin`. Later phases add the same workflow
    to their repos, and the founder re-runs `setup-repo.sh`.
14. **Libraries.** Gungnir uses `go.yaml.in/yaml/v3` v3.0.5 (MIT and Apache-2.0, released 2026-07-26)
    and `github.com/santhosh-tekuri/jsonschema/v6` v6.0.3 (Apache-2.0, 2026-06-28). Gleipnir uses the
    same YAML library. No other module is added. The schemas are JSON Schema 2020-12 files embedded
    in Gungnir, so editors and other tools can use them too.

## Global constraints

- **Local copies.** The component repos live only as submodules of `yggdrasil`, at
  `/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`, and `yggdrasil/go.work` builds them together.
  Each task works on a branch in the submodule it changes. The umbrella's pointers move once, in
  v0-T038.
- **GitHub.** Agents reach GitHub only as `ouroboric-pr-bot`, through
  `/home/brunogbv/brunogbv/ouroboric/ouroboric/scripts/as-bot.sh`. `as-bot.sh <repo> <command>` pushes
  and opens PRs; `as-bot.sh --read all <command>` reads. Every change lands through a PR the founder
  merges. Agents never merge and never push to `main`.
- **Commits.** Read `git status --short` first, and stage explicit paths, never `git add -A`. Commit
  messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commits and PRs carry
  no session links. Every repo runs the `gitleaks` hook. A test that needs a secret-looking value
  builds it at run time.
- **Go.** `go.mod` says `go 1.26`. Code is `gofmt`-clean and `go vet`-clean. Before a PR opens, the
  repo passes `GOWORK=off go test -race ./...` in its own folder, as CI runs it. This machine has Go
  1.26.4; CI uses 1.26.9.
- **Pins**, each at least two weeks old when pinned:

  | What | Pin |
  | --- | --- |
  | `go.yaml.in/yaml/v3` | v3.0.5 |
  | `github.com/santhosh-tekuri/jsonschema/v6` | v6.0.3 (brings `golang.org/x/text` v0.14.0, indirect) |
  | `govulncheck` | `golang.org/x/vuln/cmd/govulncheck@v1.8.0` (2026-09-08) |
  | `actions/checkout` | v7.0.1, `3d3c42e5aac5ba805825da76410c181273ba90b1` (2026-07-20) |
  | CI and devcontainer image | `docker.io/library/golang:1.26.9-bookworm@sha256:d9c68c2c51161e12fd77e4c6320687c9cd86e1af1e3ad6e6cd63ff970641453c` (pushed 2026-10-08; usable from 2026-10-22) |

- **Licences.** Each repo's `REUSE.toml` makes `**` (code and `testdata/`) AGPL-3.0-only, and
  `docs/**`, `README.md` and `AGENTS.md` CC-BY-4.0. `reuse lint` (`reuse==5.0.2`) passes in every repo
  a task touches.
- **The hidden suite.** No agent reads, lists or searches `ouroboric-dev/huldra` or its clone under
  `~/brunogbv/ouroboric-private/`.
- **Deletions** (`rm`, `git branch -D`) are asked for first, one per command, after a read-only check.

## Review focus

1. **Two `ygg` processes on one run**, such as an `approve` while a `resume` runs. Expected: the run is
   locked (`flock`), the second command exits 2 with "another ygg process is using this run", and a
   killed process frees the lock. Pinned by v0-T027 `TestLockAllowsOneProcess` and v0-T032 "a run
   another process holds".
2. **Operator credentials reaching an exec node**, such as `CLAUDE_CODE_OAUTH_TOKEN` or
   `ANTHROPIC_API_KEY` in the operator's shell. Expected: the node sees only `PATH`, `HOME` and
   `LANG`. Pinned by v0-T033 `TestExecGetsNoCredentialsFromTheOperator`.
3. **The realm's `graph.yaml` edited between a stop and a resume**, so the saved position points at
   another node. Expected: the run refuses to continue, and the operator starts a new run. Pinned by
   v0-T032 "a graph edited after the run started".
4. **A config that reads two ways**: a second YAML document, a duplicate key, a misspelled key,
   `tokens: 1.5`, or `run: [true]` (YAML reads `true` as a boolean). Expected: refused, never
   defaulted. Pinned by v0-T022 `TestFactoryRefusesWhatItCannotReadExactly` and v0-T023
   `TestParseGraphRefuses`.
5. **A ledger changed, cut short, or torn by a crash.** Expected: verification names the line,
   nothing appends to it, and `ygg doctor` reports an ERROR. Pinned by v0-T026, v0-T032 "a ledger cut
   short", and v0-T036 `TestDoctorFindsAChangedLedger`.

## Order

| Task | Repo | Size | Depends on |
| --- | --- | --- | --- |
| v0-T020 contract types | `gungnir` | M | Phase 0 |
| v0-T021 schemas and `factory.yaml` caps | `gungnir` | M | v0-T020 |
| v0-T022 strict reading, gate overrides | `gungnir` | S | v0-T021 |
| v0-T023 `graph.yaml` and `pack.yaml` | `gungnir` | M | v0-T022 |
| v0-T024 ledger events and findings | `gungnir` | M | v0-T021 |
| v0-T025 the `scripted` adapter | `gleipnir` | M | v0-T020 merged |
| v0-T026 the ledger | `odin` | M | v0-T024 merged |
| v0-T027 `run.json` and the run lock | `odin` | M | v0-T026 |
| v0-T028 CI workflows (prepared) | three | S | v0-T025 and v0-T027 merged; not before 2026-10-22 |
| v0-T029 required CI check in the repo scripts | `ouroboric` | M | none |
| v0-H05 (founder) CI on, check required | three | S | v0-T028, v0-T029 |
| v0-T030 the mode × approval-point table | `odin` | S | v0-T026 |
| v0-T031 starting a run | `odin` | M | v0-T023, v0-T025 merged; v0-T027, v0-T030 |
| v0-T032 opening a run again | `odin` | M | v0-T031 |
| v0-T033 the engine: exec and agent nodes | `odin` | M | v0-T032 |
| v0-T034 the engine: gate nodes | `odin` | M | v0-T033 |
| v0-T035 the `ygg` command line | `odin` | M | v0-T034 |
| v0-T036 `ygg doctor` | `odin` | S | v0-T035 |
| v0-T037 the end-to-end toy graph | `odin` | M | v0-T036 |
| v0-T038 pointers and the exit check | `yggdrasil` | S | all above, merged; v0-H05 |

"Merged" means the founder merged that PR, so its commit can be pinned (decision 2). Inside one
repo, tasks stack on one branch or on consecutive PRs; their tests don't need the PR before them to
be merged.

## Not in Phase 1

`ygg status --watch`, `board`, `report` and `metrics` (Phase 6); loop nodes, retries, findings in a
loop, and stopping at `budget-cap` (Phase 4); git checkpoints, the tree walker, and the `repo-admin`
approval point (Phase 2, with `remote-creates-repos-T001`); the `claude-code` and `opencode` adapters,
the sandbox, `Sandbox`, Havamal, and `doctor`'s container checks (Phase 3); using a pack's default
roles and checks (Phase 5); the `StateStore`, `Remote` and `Tracker` interfaces (with the phases that
implement them).

## How each task lands

Every agent task ends the same way. Run the commands in the repo's folder,
`/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`:

```bash
gofmt -l .                        # prints nothing
go vet ./...
GOWORK=off go test -race ./...    # what CI runs
uvx -q --from 'reuse==5.0.2' reuse lint -q
git status --short                # then stage the task's files by path
git commit -m "<what changed> (v0-T0xx)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
../../ouroboric/scripts/as-bot.sh <repo> git push -u origin <branch>
../../ouroboric/scripts/as-bot.sh <repo> gh pr create --repo ouroboric-dev/<repo> --title "<title> (v0-T0xx)" --body-file <file>
```

The PR body names the task, lists its acceptance criteria with their evidence (the named test's
output), and says which earlier PRs it needs merged first.

To pin a sibling (decision 2), fetch it, then pin its `main`:

```bash
../../ouroboric/scripts/as-bot.sh --read all git -C ../gungnir fetch -q origin
GOWORK=off go get github.com/ouroboric-dev/gungnir@$(git -C ../gungnir rev-parse origin/main)
GOWORK=off go mod tidy
```

---

### Task v0-T020: the contract types

Gungnir's root package: the `Agent` interface, approval points and modes, and findings (spec §2.2,
§4.6, §7.1).

**Files (in `gungnir`):**

- Create: `agent.go`, `gate.go`, `finding.go`, `gungnir_test.go`
- Modify: `AGENTS.md`. Its line "Interfaces live in `gungnir`, never here (spec §1)." is wrong for
  this repo, so it becomes "Every interface and schema lives here. A change here comes with a PR in
  each affected component (spec §1)."

**Interfaces:**

- Produces: `gungnir.Agent`, `Task`, `Result`, `Status` (`StatusOK`, `StatusFailed`), `Usage`
  (`Add`), `Result.Validate`; `Gate` with its 15 constants, `Gate.Hard`, `Gate.Known` and `Gates()`;
  `Mode` (`ModeStepByStep`, `ModeKeyPoints`, `ModeUnattended`), `ParseMode` and `Mode.Looser`;
  `Finding`, `Severity`, `FindingStatus` and `Finding.Validate`.

**Acceptance criteria:**

- [ ] The hard approval points are exactly the eight of spec §7.1, and `Known` is false for any other
      name.
- [ ] `Result.Validate` refuses an empty or unknown status, a negative count, and a NaN or infinite
      cost.
- [ ] `Finding.Validate` refuses a missing or line-less location, an unknown severity or status, and
      a `fixed` finding without proof.

**Named test:** `go test ./... -run 'TestResultValidate|TestUsageAdd|TestHardGates|TestModes|TestFindingValidate'`
in `gungnir`. **Layer:** `gungnir`. **Size:** M (314 lines). **Depends on:** Phase 0.

- [ ] **Step 1:** branch `contract/types`; write `gungnir_test.go`:

```go
package gungnir

import (
	"math"
	"slices"
	"testing"
)

func TestResultValidateRefusesWhatCouldPassForSuccess(t *testing.T) {
	bad := map[string]Result{
		"no status":       {},
		"unknown status":  {Status: "passed"},
		"negative tokens": {Status: StatusOK, Usage: Usage{InTok: -1}},
		"negative turns":  {Status: StatusOK, Usage: Usage{Turns: -1}},
		"NaN cost":        {Status: StatusOK, Usage: Usage{CostUSD: math.NaN()}},
		"infinite cost":   {Status: StatusOK, Usage: Usage{CostUSD: math.Inf(1)}},
	}
	for name, r := range bad {
		if err := r.Validate(); err == nil {
			t.Errorf("%s: Validate() = nil, want an error", name)
		}
	}
	for _, s := range []Status{StatusOK, StatusFailed} {
		if err := (Result{Status: s}).Validate(); err != nil {
			t.Errorf("status %s: Validate() = %v, want nil", s, err)
		}
	}
}

func TestUsageAdd(t *testing.T) {
	got := Usage{InTok: 1, OutTok: 2, CacheTok: 3, Turns: 4, CostUSD: 0.5}.
		Add(Usage{InTok: 10, OutTok: 20, CacheTok: 30, Turns: 40, CostUSD: 0.25, CostEstimated: true})
	want := Usage{InTok: 11, OutTok: 22, CacheTok: 33, Turns: 44, CostUSD: 0.75, CostEstimated: true}
	if got != want {
		t.Errorf("Add() = %+v, want %+v", got, want)
	}
}

func TestHardGatesAreTheSpecList(t *testing.T) {
	hard := []Gate{"deploy-prod", "store-submit", "real-secrets-or-user-data", "budget-cap",
		"external-input", "policy-violation", "shrink-guard", "guardrail-change"}
	for _, g := range Gates() {
		if g.Hard() != slices.Contains(hard, g) {
			t.Errorf("%s.Hard() = %v, want %v", g, g.Hard(), !g.Hard())
		}
		if !g.Known() {
			t.Errorf("%s.Known() = false", g)
		}
	}
	if len(Gates()) != 15 {
		t.Errorf("len(Gates()) = %d, want 15", len(Gates()))
	}
	if Gate("nope").Known() || Gate("nope").Hard() {
		t.Error(`Gate("nope") is known or hard`)
	}
}

func TestModes(t *testing.T) {
	if !ModeUnattended.Looser(ModeKeyPoints) || !ModeKeyPoints.Looser(ModeStepByStep) {
		t.Error("want unattended looser than key-points, and key-points looser than step-by-step")
	}
	if ModeStepByStep.Looser(ModeKeyPoints) || ModeKeyPoints.Looser(ModeKeyPoints) {
		t.Error("a tighter or equal mode is not looser")
	}
	if m, err := ParseMode("key-points"); err != nil || m != ModeKeyPoints {
		t.Errorf(`ParseMode("key-points") = %q, %v`, m, err)
	}
	if _, err := ParseMode("fast"); err == nil {
		t.Error(`ParseMode("fast") = nil error`)
	}
}

func TestFindingValidate(t *testing.T) {
	good := Finding{ID: "F1", Source: "reviewer-spec", Severity: SeverityMajor,
		Location: "api/auth.go:42-48", Claim: "the PIN is not throttled", Status: FindingOpen}
	if err := good.Validate(); err != nil {
		t.Fatalf("good finding: %v", err)
	}
	bad := map[string]func(*Finding){
		"no location":           func(f *Finding) { f.Location = "" },
		"location without line": func(f *Finding) { f.Location = "api/auth.go" },
		"unknown severity":      func(f *Finding) { f.Severity = "critical" },
		"fixed with no proof":   func(f *Finding) { f.Status = FindingFixed },
		"unknown status":        func(f *Finding) { f.Status = "closed" },
		"no id":                 func(f *Finding) { f.ID = "" },
	}
	for name, change := range bad {
		f := good
		change(&f)
		if err := f.Validate(); err == nil {
			t.Errorf("%s: Validate() = nil, want an error", name)
		}
	}
	fixed := good
	fixed.Status, fixed.Proof = FindingFixed, "api/auth.go:44 limits tries; check run 7 rung 4 passed"
	if err := fixed.Validate(); err != nil {
		t.Errorf("fixed with proof: %v", err)
	}
}
```

- [ ] **Step 2:** run `go test ./...`; expect a build failure on undefined names, such as `undefined: Result`.
- [ ] **Step 3:** write `agent.go`:

```go
// Package gungnir is the contract every Yggdrasil component implements (spec §2.2).
package gungnir

import (
	"context"
	"fmt"
	"math"
	"time"
)

// Agent runs one agent session. The adapters live in Gleipnir.
type Agent interface {
	Name() string
	Run(ctx context.Context, t Task) (Result, error)
}

// Task is one agent session's input. Every session starts clean (spec §4.4).
type Task struct {
	Role          string        // the factory.yaml role, such as "planner"
	Node          string        // the graph node that runs the session
	Attempt       int           // 1 the first time the node runs; one more on every re-run
	Prompt        string        // the full prompt
	Workdir       string        // the only directory the session may change
	Model         string        // the role's model
	ReadOnly      bool          // read-only roles get read and search tools only
	MaxTurns      int           // 0: the adapter's own limit
	Timeout       time.Duration // 0: no limit beyond the context
	EnvAllowlist  []string      // the host variables the session may see
	TranscriptDir string        // where the adapter writes the session's transcript
}

// Status is how a session ended.
type Status string

const (
	StatusOK     Status = "ok"
	StatusFailed Status = "failed"
)

// Usage is what a session consumed. Tokens and turns are the primary numbers (spec §5).
type Usage struct {
	InTok         int64   `json:"in_tok"`
	OutTok        int64   `json:"out_tok"`
	CacheTok      int64   `json:"cache_tok"`
	Turns         int64   `json:"turns"`
	CostUSD       float64 `json:"cost_usd"`
	CostEstimated bool    `json:"cost_estimated"`
}

// Add returns the sum of u and v. The sum is estimated if either part is.
func (u Usage) Add(v Usage) Usage {
	return Usage{
		InTok:         u.InTok + v.InTok,
		OutTok:        u.OutTok + v.OutTok,
		CacheTok:      u.CacheTok + v.CacheTok,
		Turns:         u.Turns + v.Turns,
		CostUSD:       u.CostUSD + v.CostUSD,
		CostEstimated: u.CostEstimated || v.CostEstimated,
	}
}

// Result is how a session ended and what it cost.
type Result struct {
	Status         Status
	Summary        string
	Usage          Usage
	TranscriptPath string
}

// Validate refuses a result that could be misread as a pass. Missing or malformed data is never
// defaulted (spec §4.6).
func (r Result) Validate() error {
	if r.Status != StatusOK && r.Status != StatusFailed {
		return fmt.Errorf("result status %q is neither %q nor %q", r.Status, StatusOK, StatusFailed)
	}
	u := r.Usage
	if u.InTok < 0 || u.OutTok < 0 || u.CacheTok < 0 || u.Turns < 0 {
		return fmt.Errorf("result usage has a negative count: %+v", u)
	}
	if u.CostUSD < 0 || math.IsNaN(u.CostUSD) || math.IsInf(u.CostUSD, 0) {
		return fmt.Errorf("result cost %v is not a finite, non-negative number", u.CostUSD)
	}
	return nil
}
```

- [ ] **Step 4:** write `gate.go`:

```go
package gungnir

import (
	"fmt"
	"slices"
)

// Gate names an approval point (spec §7.1).
type Gate string

const (
	GateDesign          Gate = "design"
	GateSpec            Gate = "spec"
	GatePlan            Gate = "plan"
	GateFeature         Gate = "feature"
	GateMerge           Gate = "merge"
	GatePointer         Gate = "pointer"
	GatePointerContract Gate = "pointer-contract"

	// The hard approval points stop in every mode, and no config can override them.
	GateDeployProd      Gate = "deploy-prod"
	GateStoreSubmit     Gate = "store-submit"
	GateRealSecrets     Gate = "real-secrets-or-user-data"
	GateBudgetCap       Gate = "budget-cap"
	GateExternalInput   Gate = "external-input"
	GatePolicyViolation Gate = "policy-violation"
	GateShrinkGuard     Gate = "shrink-guard"
	GateGuardrailChange Gate = "guardrail-change"
)

var (
	softGates = []Gate{GateDesign, GateSpec, GatePlan, GateFeature, GateMerge, GatePointer, GatePointerContract}
	hardGates = []Gate{GateDeployProd, GateStoreSubmit, GateRealSecrets, GateBudgetCap, GateExternalInput,
		GatePolicyViolation, GateShrinkGuard, GateGuardrailChange}
)

// Hard reports whether g is a hard approval point.
func (g Gate) Hard() bool { return slices.Contains(hardGates, g) }

// Known reports whether g is an approval point of the spec.
func (g Gate) Known() bool { return g.Hard() || slices.Contains(softGates, g) }

// Gates returns every known approval point, the soft ones first.
func Gates() []Gate { return slices.Concat(softGates, hardGates) }

// Mode is an autonomy mode (spec §7.1).
type Mode string

const (
	ModeStepByStep Mode = "step-by-step"
	ModeKeyPoints  Mode = "key-points"
	ModeUnattended Mode = "unattended"
)

var modes = []Mode{ModeStepByStep, ModeKeyPoints, ModeUnattended} // tightest first

// ParseMode returns the mode named s.
func ParseMode(s string) (Mode, error) {
	if m := Mode(s); slices.Contains(modes, m) {
		return m, nil
	}
	return "", fmt.Errorf("unknown mode %q (want step-by-step, key-points or unattended)", s)
}

// Looser reports whether m stops at fewer approval points than other.
func (m Mode) Looser(other Mode) bool { return slices.Index(modes, m) > slices.Index(modes, other) }
```

- [ ] **Step 5:** write `finding.go`:

```go
package gungnir

import (
	"errors"
	"fmt"
	"regexp"
)

// Severity is how bad a finding is.
type Severity string

const (
	SeverityBlocker Severity = "blocker"
	SeverityMajor   Severity = "major"
	SeverityMinor   Severity = "minor"
)

// FindingStatus is where a finding stands.
type FindingStatus string

const (
	FindingOpen     FindingStatus = "open"
	FindingFixed    FindingStatus = "fixed"
	FindingDisputed FindingStatus = "disputed"
)

// Finding is what a check or a reviewer reports (spec §4.6).
type Finding struct {
	ID       string        `json:"id"`       // stable across fix attempts
	Source   string        `json:"source"`   // the rung or reviewer that raised it
	Severity Severity      `json:"severity"` // blocker, major or minor
	Location string        `json:"location"` // file:line or file:line-line
	Claim    string        `json:"claim"`    // what is wrong
	Status   FindingStatus `json:"status"`   // open, fixed or disputed
	Proof    string        `json:"proof,omitempty"`
}

var location = regexp.MustCompile(`^[^\s:]+:[0-9]+(-[0-9]+)?$`)

// Validate refuses a finding with missing or malformed fields. A malformed finding is an agent
// failure, never a pass (spec §4.6).
func (f Finding) Validate() error {
	var errs []error
	if f.ID == "" || f.Source == "" || f.Claim == "" {
		errs = append(errs, errors.New("a finding needs an id, a source and a claim"))
	}
	switch f.Severity {
	case SeverityBlocker, SeverityMajor, SeverityMinor:
	default:
		errs = append(errs, fmt.Errorf("severity %q is not blocker, major or minor", f.Severity))
	}
	if !location.MatchString(f.Location) {
		errs = append(errs, fmt.Errorf("location %q is not file:line or file:line-line", f.Location))
	}
	switch f.Status {
	case FindingOpen, FindingDisputed:
	case FindingFixed:
		if f.Proof == "" {
			errs = append(errs, errors.New("a fixed finding needs proof"))
		}
	default:
		errs = append(errs, fmt.Errorf("status %q is not open, fixed or disputed", f.Status))
	}
	return errors.Join(errs...)
}
```

- [ ] **Step 6:** run `go test ./...`; expect `ok`. Fix the `AGENTS.md` line. Land it (see "How each
      task lands").

---

### Task v0-T021: schemas and the `factory.yaml` caps

The schema package, and `factory.yaml` with required caps. This is the `gungnir` half of
`require-budget-caps-T001`.

**Files (in `gungnir`):**

- Create: `schema/schema.go`, `schema/factory.schema.json`, `schema/factory.go`,
  `schema/factory_test.go`
- Modify: `go.mod`, `go.sum`

**Interfaces:**

- Consumes: `gungnir.Mode`, `gungnir.Gate` (v0-T020).
- Produces: `schema.Factory`, `Role`, `Budget`, `Cap`; `LoadFactory(path)`, `ParseFactory(file, data)`
  (both `(*Factory, error)`); `*CapsError` with `File`, `Missing []string` and `Paid`;
  `PaidAPI(agent string) bool`. Unexported helpers for the next tasks: `decodeYAML`, `validate`,
  `decodeStrict`, `parseYAML`, `sortedKeys`. Each schema's `$id` is
  `https://github.com/ouroboric-dev/gungnir/schema/<file>`.

**Acceptance criteria:**

- [ ] The `factory.yaml` schema rejects a file without caps (`TestFactorySchemaRequiresCaps`, "the
      schema itself requires the caps").
- [ ] No caps, a per-run cap without a per-day cap, a cap without turns, and a paid-API role without
      a spend limit each give a `*CapsError` that names the missing fields and shows how to set them.
      It suggests no values.
- [ ] Complete caps parse. The mode defaults to `key-points` and privacy to `standard`.

**Named test:** `go test ./schema/ -run TestFactorySchemaRequiresCaps` (the change's named test).
**Layer:** `gungnir`. **Size:** M (377 lines). **Depends on:** v0-T020.

- [ ] **Step 1:** add the two libraries:
      `GOWORK=off go get go.yaml.in/yaml/v3@v3.0.5 github.com/santhosh-tekuri/jsonschema/v6@v6.0.3`.
- [ ] **Step 2:** write `schema/factory_test.go`:

```go
package schema

import (
	"errors"
	"regexp"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

const scriptedRoles = `
roles:
  planner: { agent: scripted, model: none, script: toy.script.yaml }
`

const paidRoles = `
roles:
  planner: { agent: claude-code, model: opus }
  reviewer-spec: { agent: opencode, model: openrouter/qwen }
`

const fullCaps = `
budget:
  per_run: { tokens: 1000, turns: 10 }
  per_day: { tokens: 2000, turns: 20 }
`

func TestFactorySchemaRequiresCaps(t *testing.T) {
	cases := []struct {
		name, yaml string
		missing    []string
	}{
		{"no caps", scriptedRoles, []string{"budget.per_run", "budget.per_day"}},
		{"a per-run cap but no per-day cap", scriptedRoles + "budget:\n  per_run: { tokens: 1000, turns: 10 }\n",
			[]string{"budget.per_day"}},
		{"a cap without turns", scriptedRoles + "budget:\n  per_run: { tokens: 1000 }\n  per_day: { tokens: 2000, turns: 20 }\n",
			[]string{"budget.per_run.turns"}},
		{"an empty file", "", []string{"budget.per_run", "budget.per_day"}},
		{"a paid-API role and no spend limit", paidRoles + fullCaps, []string{
			"budget.per_run.usd (role reviewer-spec runs on opencode, which bills a paid API)",
			"budget.per_day.usd (role reviewer-spec runs on opencode, which bills a paid API)"}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := ParseFactory("factory.yaml", []byte(c.yaml))
			var ce *CapsError
			if !errors.As(err, &ce) {
				t.Fatalf("ParseFactory() error = %v, want a *CapsError", err)
			}
			if !slices.Equal(ce.Missing, c.missing) {
				t.Errorf("Missing = %q, want %q", ce.Missing, c.missing)
			}
			msg := err.Error()
			if !strings.Contains(msg, "per_day: { tokens: <tokens>, turns: <turns>") {
				t.Errorf("the message doesn't show how to set the caps:\n%s", msg)
			}
			if regexp.MustCompile(`(tokens|turns|usd): [0-9]`).MatchString(msg) {
				t.Errorf("the message suggests a value; the factory ships no defaults:\n%s", msg)
			}
		})
	}
	t.Run("the schema itself requires the caps", func(t *testing.T) {
		doc, err := decodeYAML("factory.yaml", []byte(scriptedRoles))
		if err != nil {
			t.Fatal(err)
		}
		if err := validate("factory.yaml", "factory.schema.json", doc); err == nil {
			t.Error("the schema accepts a file without budget")
		}
	})
	t.Run("complete caps parse", func(t *testing.T) {
		f, err := ParseFactory("factory.yaml", []byte(scriptedRoles+fullCaps))
		if err != nil {
			t.Fatalf("ParseFactory() = %v", err)
		}
		if f.Budget.PerDay.Turns != 20 || f.Mode != gungnir.ModeKeyPoints || f.Privacy != "standard" {
			t.Errorf("got %+v", f)
		}
		if _, err := ParseFactory("factory.yaml", []byte(paidRoles+
			"budget:\n  per_run: { tokens: 1000, turns: 10, usd: 5 }\n  per_day: { tokens: 2000, turns: 20, usd: 10 }\n")); err != nil {
			t.Errorf("paid roles with spend limits: %v", err)
		}
	})
}
```

- [ ] **Step 3:** run `go test ./schema/`; expect a build failure: `undefined: ParseFactory`.
- [ ] **Step 4:** write `schema/factory.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/factory.schema.json",
  "title": "factory.yaml",
  "description": "The operator's factory settings: mode, approval-point overrides, roles, budget caps and privacy (spec §5, §7; change require-budget-caps). Caps are required and have no defaults.",
  "type": "object",
  "additionalProperties": false,
  "required": ["roles", "budget"],
  "properties": {
    "mode": { "enum": ["step-by-step", "key-points", "unattended"] },
    "gates": {
      "type": "object",
      "propertyNames": {
        "enum": ["design", "spec", "plan", "feature", "merge", "pointer", "pointer-contract",
                 "deploy-prod", "store-submit", "real-secrets-or-user-data", "budget-cap",
                 "external-input", "policy-violation", "shrink-guard", "guardrail-change"]
      },
      "additionalProperties": { "enum": ["stop", "auto"] }
    },
    "roles": {
      "type": "object",
      "minProperties": 1,
      "propertyNames": { "pattern": "^[a-z][a-z0-9-]*$" },
      "additionalProperties": { "$ref": "#/$defs/role" }
    },
    "budget": {
      "type": "object",
      "additionalProperties": false,
      "required": ["per_run", "per_day"],
      "properties": {
        "per_run": { "$ref": "#/$defs/cap" },
        "per_day": { "$ref": "#/$defs/cap" }
      }
    },
    "privacy": { "enum": ["standard", "strict"] }
  },
  "$defs": {
    "role": {
      "type": "object",
      "additionalProperties": false,
      "required": ["agent", "model"],
      "properties": {
        "agent": { "enum": ["claude-code", "opencode", "scripted"] },
        "model": { "type": "string", "minLength": 1 },
        "script": { "type": "string", "minLength": 1 }
      },
      "if": { "properties": { "agent": { "const": "scripted" } } },
      "then": { "required": ["script"] },
      "else": { "not": { "required": ["script"] } }
    },
    "cap": {
      "type": "object",
      "additionalProperties": false,
      "required": ["tokens", "turns"],
      "properties": {
        "tokens": { "type": "integer", "minimum": 1 },
        "turns": { "type": "integer", "minimum": 1 },
        "usd": { "type": "number", "exclusiveMinimum": 0 }
      }
    }
  }
}
```

- [ ] **Step 5:** write `schema/schema.go`:

```go
// Package schema holds the JSON schemas of Yggdrasil's files, and parses the files against them.
// Every parser refuses what it can't read exactly; nothing missing or malformed is defaulted.
package schema

import (
	"bytes"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"

	"github.com/santhosh-tekuri/jsonschema/v6"
	"go.yaml.in/yaml/v3"
)

//go:embed *.schema.json
var files embed.FS

const base = "https://github.com/ouroboric-dev/gungnir/schema/"

// compile compiles one embedded schema. Its $id must be base + name.
func compile(name string) (*jsonschema.Schema, error) {
	raw, err := files.ReadFile(name)
	if err != nil {
		return nil, err
	}
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(raw))
	if err != nil {
		return nil, fmt.Errorf("%s: %w", name, err)
	}
	c := jsonschema.NewCompiler()
	if err := c.AddResource(base+name, doc); err != nil {
		return nil, err
	}
	return c.Compile(base + name)
}

// validate checks a decoded document against the named schema.
func validate(file, schemaName string, doc any) error {
	s, err := compile(schemaName)
	if err != nil {
		return err
	}
	if err := s.Validate(doc); err != nil {
		return fmt.Errorf("%s: %w", file, err)
	}
	return nil
}

// decodeYAML reads the first YAML document and returns it as JSON values, ready for validate.
// Duplicate keys are an error in the YAML decoder itself.
func decodeYAML(file string, data []byte) (any, error) {
	dec := yaml.NewDecoder(bytes.NewReader(data))
	var doc any
	if err := dec.Decode(&doc); err != nil && !errors.Is(err, io.EOF) {
		return nil, fmt.Errorf("%s: %w", file, err)
	}
	raw, err := json.Marshal(doc)
	if err != nil {
		return nil, fmt.Errorf("%s: every key must be a string: %w", file, err)
	}
	return jsonschema.UnmarshalJSON(bytes.NewReader(raw))
}

// decodeStrict decodes one YAML document into v and refuses unknown fields.
func decodeStrict(file string, data []byte, v any) error {
	dec := yaml.NewDecoder(bytes.NewReader(data))
	dec.KnownFields(true)
	if err := dec.Decode(v); err != nil && !errors.Is(err, io.EOF) {
		return fmt.Errorf("%s: %w", file, err)
	}
	return nil
}

// parseYAML validates data against the named schema, then decodes it into v.
func parseYAML(file, schemaName string, data []byte, v any) error {
	doc, err := decodeYAML(file, data)
	if err != nil {
		return err
	}
	if err := validate(file, schemaName, doc); err != nil {
		return err
	}
	return decodeStrict(file, data, v)
}
```

- [ ] **Step 6:** write `schema/factory.go`:

```go
package schema

import (
	"fmt"
	"os"
	"slices"
	"strings"

	"github.com/ouroboric-dev/gungnir"
)

// Factory is factory.yaml.
type Factory struct {
	Mode    gungnir.Mode            `yaml:"mode"`
	Gates   map[gungnir.Gate]string `yaml:"gates"`
	Roles   map[string]Role         `yaml:"roles"`
	Budget  Budget                  `yaml:"budget"`
	Privacy string                  `yaml:"privacy"`
}

// Role maps a role to an agent adapter and a model (spec §5).
type Role struct {
	Agent  string `yaml:"agent"`
	Model  string `yaml:"model"`
	Script string `yaml:"script"` // scripted adapter only: the script, relative to factory.yaml
}

// Budget holds the caps. Both are required, and the factory ships no default values.
type Budget struct {
	PerRun Cap `yaml:"per_run"`
	PerDay Cap `yaml:"per_day"`
}

// Cap limits tokens and turns, and dollars when a role bills a paid API.
type Cap struct {
	Tokens int64   `yaml:"tokens"`
	Turns  int64   `yaml:"turns"`
	USD    float64 `yaml:"usd"`
}

// PaidAPI reports whether an adapter bills a paid API. Only adapters known to run on a
// subscription or at no cost return false, so a new adapter needs a spend limit until it is listed.
func PaidAPI(agent string) bool { return agent != "claude-code" && agent != "scripted" }

// CapsError lists the cap fields that factory.yaml lacks.
type CapsError struct {
	File    string
	Missing []string
	Paid    bool // a role bills a paid API, so the caps need usd too
}

func (e *CapsError) Error() string {
	var b strings.Builder
	fmt.Fprintf(&b, "%s has no complete budget caps, so nothing runs. Missing:\n", e.File)
	for _, m := range e.Missing {
		fmt.Fprintf(&b, "  - %s\n", m)
	}
	usd := ""
	if e.Paid {
		usd = ", usd: <dollars>"
	}
	b.WriteString("Set your own limits in it; the factory ships no defaults:\n  budget:\n")
	fmt.Fprintf(&b, "    per_run: { tokens: <tokens>, turns: <turns>%s }\n", usd)
	fmt.Fprintf(&b, "    per_day: { tokens: <tokens>, turns: <turns>%s }\n", usd)
	return b.String()
}

// LoadFactory reads and parses a factory.yaml file.
func LoadFactory(path string) (*Factory, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return ParseFactory(path, data)
}

// ParseFactory parses factory.yaml. Incomplete caps give a *CapsError before any other check, so
// the operator learns what to set. The gate overrides are checked against the file's own mode.
func ParseFactory(file string, data []byte) (*Factory, error) {
	doc, err := decodeYAML(file, data)
	if err != nil {
		return nil, err
	}
	if err := checkCaps(file, doc); err != nil {
		return nil, err
	}
	if err := validate(file, "factory.schema.json", doc); err != nil {
		return nil, err
	}
	var f Factory
	if err := decodeStrict(file, data, &f); err != nil {
		return nil, err
	}
	if f.Mode == "" {
		f.Mode = gungnir.ModeKeyPoints
	}
	if f.Privacy == "" {
		f.Privacy = "standard"
	}
	return &f, nil
}

func checkCaps(file string, doc any) error {
	root, _ := doc.(map[string]any)
	roles, _ := root["roles"].(map[string]any)
	paid := ""
	for _, name := range sortedKeys(roles) {
		role, _ := roles[name].(map[string]any)
		if agent, ok := role["agent"].(string); ok && PaidAPI(agent) {
			paid = fmt.Sprintf("role %s runs on %s, which bills a paid API", name, agent)
			break
		}
	}
	budget, _ := root["budget"].(map[string]any)
	var missing []string
	for _, c := range []string{"per_run", "per_day"} {
		cp, ok := budget[c].(map[string]any)
		if !ok {
			missing = append(missing, "budget."+c)
			continue
		}
		for _, field := range []string{"tokens", "turns"} {
			if cp[field] == nil {
				missing = append(missing, "budget."+c+"."+field)
			}
		}
		if paid != "" && cp["usd"] == nil {
			missing = append(missing, "budget."+c+".usd ("+paid+")")
		}
	}
	if len(missing) > 0 {
		return &CapsError{File: file, Missing: missing, Paid: paid != ""}
	}
	return nil
}

func sortedKeys[K ~string, V any](m map[K]V) []K {
	keys := make([]K, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	slices.Sort(keys)
	return keys
}
```

- [ ] **Step 7:** `GOWORK=off go mod tidy`; run the named test; expect `ok`. Land it.

---

### Task v0-T022: strict reading and gate overrides

**Files (in `gungnir`):**

- Modify: `schema/schema.go`, `schema/factory.go`, `schema/factory_test.go`

**Interfaces:**

- Produces: `(*schema.Factory).CheckGates(mode gungnir.Mode) error`, which v0-T031 calls on every
  `--mode` switch. `ParseFactory` calls it with the file's own mode.

**Acceptance criteria:**

- [ ] A second YAML document, a duplicate key, a misspelled key, zero or fractional or wordy tokens,
      an unknown mode or agent, a scripted role without a script, a script on another adapter, and a
      non-string key are each refused (review focus 4).
- [ ] A `stop` override on any hard approval point is refused as hard; on any soft one it parses.
- [ ] `plan: auto` is refused. `design: auto` is refused in key-points and accepted in unattended,
      and `CheckGates(key-points)` refuses it again.

**Named test:** `go test ./schema/ -run 'TestFactoryRefusesWhatItCannotReadExactly|TestFactoryGateOverrides'`.
**Layer:** `gungnir`. **Size:** S (73 lines). **Depends on:** v0-T021.

- [ ] **Step 1:** append to `schema/factory_test.go`:

```go
func TestFactoryRefusesWhatItCannotReadExactly(t *testing.T) {
	cases := map[string]string{
		"two YAML documents":   scriptedRoles + fullCaps + "---\nmode: unattended\n",
		"a duplicate key":      scriptedRoles + fullCaps + "budget:\n  per_run: { tokens: 1, turns: 1 }\n",
		"a misspelled key":     scriptedRoles + fullCaps + "privcy: strict\n",
		"zero tokens":          scriptedRoles + "budget:\n  per_run: { tokens: 0, turns: 10 }\n  per_day: { tokens: 2000, turns: 20 }\n",
		"tokens as a word":     scriptedRoles + "budget:\n  per_run: { tokens: many, turns: 10 }\n  per_day: { tokens: 2000, turns: 20 }\n",
		"tokens as a fraction": scriptedRoles + "budget:\n  per_run: { tokens: 1.5, turns: 10 }\n  per_day: { tokens: 2000, turns: 20 }\n",
		"an unknown mode":      "mode: fast\n" + scriptedRoles + fullCaps,
		"an unknown agent":     "roles:\n  planner: { agent: codex, model: x }\n" + "budget:\n  per_run: { tokens: 1, turns: 1, usd: 1 }\n  per_day: { tokens: 1, turns: 1, usd: 1 }\n",
		"scripted, no script":  "roles:\n  planner: { agent: scripted, model: none }\n" + fullCaps,
		"a script on claude":   "roles:\n  planner: { agent: claude-code, model: opus, script: x.yaml }\n" + fullCaps,
		"a non-string key":     scriptedRoles + fullCaps + "1: x\n",
	}
	for name, y := range cases {
		if _, err := ParseFactory("factory.yaml", []byte(y)); err == nil {
			t.Errorf("%s: ParseFactory() = nil error", name)
		}
	}
}
```

- [ ] **Step 2:** run `go test ./schema/ -run TestFactoryRefusesWhatItCannotReadExactly`. Expect
      exactly one failure, `two YAML documents: ParseFactory() = nil error` (checked): the decoder
      reads only the first document.
- [ ] **Step 3:** in `schema/schema.go`, `decodeYAML`, after the first `Decode` and before
      `json.Marshal`, refuse a second document. Its comment becomes "reads exactly one YAML document".
      Run the test again; expect `ok`.

```go
	var extra any
	if err := dec.Decode(&extra); !errors.Is(err, io.EOF) {
		return nil, fmt.Errorf("%s: holds more than one YAML document", file)
	}
```

- [ ] **Step 4:** append to `schema/factory_test.go`:

```go
func TestFactoryGateOverrides(t *testing.T) {
	parse := func(mode, gates string) error {
		_, err := ParseFactory("factory.yaml", []byte("mode: "+mode+"\ngates: "+gates+"\n"+scriptedRoles+fullCaps))
		return err
	}
	for _, g := range gungnir.Gates() {
		err := parse("key-points", "{ "+string(g)+": stop }")
		if g.Hard() && (err == nil || !strings.Contains(err.Error(), "hard approval point")) {
			t.Errorf("%s: stop override error = %v, want the hard approval point refusal", g, err)
		}
		if !g.Hard() && err != nil {
			t.Errorf("%s: stop override error = %v, want nil", g, err)
		}
	}
	if err := parse("key-points", "{ plan: auto }"); err == nil {
		t.Error("plan: auto parsed; an override may only tighten")
	}
	if err := parse("key-points", "{ design: auto }"); err == nil {
		t.Error("design: auto parsed in key-points mode")
	}
	if err := parse("unattended", "{ design: auto }"); err != nil {
		t.Errorf("design: auto in unattended mode: %v", err)
	}
	f, err := ParseFactory("factory.yaml", []byte("mode: unattended\ngates: { design: auto }\n"+scriptedRoles+fullCaps))
	if err != nil {
		t.Fatal(err)
	}
	if err := f.CheckGates(gungnir.ModeKeyPoints); err == nil {
		t.Error("CheckGates(key-points) accepts design: auto; a --mode switch must re-check it")
	}
}
```

- [ ] **Step 5:** run `go test ./schema/`; expect a build failure: `f.CheckGates undefined`.
- [ ] **Step 6:** in `schema/factory.go`, add `CheckGates` before `sortedKeys`, and call it at the
      end of `ParseFactory`, just before `return &f, nil`:

```go
// CheckGates refuses overrides that mode doesn't allow (spec §7.2). No override may touch a hard
// approval point. An override may only tighten, to stop; the one exception is design: auto, and
// only in unattended mode.
func (f *Factory) CheckGates(mode gungnir.Mode) error {
	for _, g := range sortedKeys(f.Gates) {
		switch v := f.Gates[g]; {
		case g.Hard():
			return fmt.Errorf("gates.%s: %s is a hard approval point, and no config can override it", g, g)
		case v == "auto" && g != gungnir.GateDesign:
			return fmt.Errorf("gates.%s: an override can only set stop; design: auto in unattended mode is the one exception", g)
		case v == "auto" && mode != gungnir.ModeUnattended:
			return fmt.Errorf("gates.design: auto is allowed only in unattended mode, not %s", mode)
		}
	}
	return nil
}
```

```go
	if err := f.CheckGates(f.Mode); err != nil {
		return nil, fmt.Errorf("%s: %w", file, err)
	}
```

- [ ] **Step 7:** run the named test; expect `ok`. Land it.

---

### Task v0-T023: `graph.yaml` and `pack.yaml`

**Files (in `gungnir`):**

- Create: `schema/graph.schema.json`, `schema/pack.schema.json`, `schema/graph.go`, `schema/pack.go`,
  `schema/graph_test.go`

**Interfaces:**

- Produces: `schema.Graph` (`Index(id) int`), `Node`, `NodeKind` (`KindExec`, `KindAgent`,
  `KindGate`), `Duration`; `LoadGraph(path)`, `ParseGraph(file, data)` (both `(*Graph, error)`).
  After parsing, every gate's `Reruns` names the node a rejection re-runs. Also `schema.Pack`,
  `PackRole`, and `LoadPack(dir) (*Pack, error)`.

**Acceptance criteria:**

- [ ] A gate re-runs the node it names, which must come before it and must not be a gate. Without a
      name, it re-runs the nearest non-gate node before it. With no such node, the graph is refused.
- [ ] Each refusal in `TestParseGraphRefuses` fails for its own reason. Among them: duplicate ids,
      a `loop` node (a later schema version), a prompt outside the realm, and `run: [true]`.
- [ ] Every approval point Gungnir knows can be a gate node.
- [ ] A pack whose graph path leaves the realm is refused.

**Named test:** `go test ./schema/ -run 'TestParseGraph|TestGraphSchema|TestLoadPack'`. **Layer:**
`gungnir`. **Size:** M (349 lines). **Depends on:** v0-T022.

- [ ] **Step 1:** write `schema/graph_test.go`:

```go
package schema

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

const toyGraph = `
name: toy
version: 1.0.0
nodes:
  - { id: design, kind: agent, role: planner, prompt: prompts/design.md, timeout: 10m }
  - { id: design-gate, kind: gate, gate: design }
  - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md }
  - { id: dor, kind: exec, run: [test, -s, plan.md] }
  - { id: plan-gate, kind: gate, gate: plan, reruns: plan }
`

func TestParseGraphResolvesWhatARejectionReruns(t *testing.T) {
	g, err := ParseGraph("graph.yaml", []byte(toyGraph))
	if err != nil {
		t.Fatalf("ParseGraph() = %v", err)
	}
	if got := g.Nodes[1].Reruns; got != "design" {
		t.Errorf("design-gate reruns %q, want design (the node before it)", got)
	}
	if got := g.Nodes[4].Reruns; got != "plan" {
		t.Errorf("plan-gate reruns %q, want plan (named)", got)
	}
	if got := time.Duration(g.Nodes[0].Timeout); got != 10*time.Minute {
		t.Errorf("design timeout = %v, want 10m", got)
	}
	if g.Index("dor") != 3 || g.Index("nope") != -1 {
		t.Errorf("Index() is wrong")
	}
}

func TestParseGraphRefuses(t *testing.T) {
	head := "name: toy\nversion: 1.0.0\nnodes:\n"
	const bySchema = "jsonschema validation failed"
	cases := map[string]struct{ nodes, want string }{
		"a duplicate id":                   {"  - { id: a, kind: exec, run: [echo] }\n  - { id: a, kind: exec, run: [echo] }\n", "used twice"},
		"a loop node (not yet)":            {"  - { id: a, kind: loop }\n", bySchema},
		"a gate with nothing before it":    {"  - { id: g, kind: gate, gate: design }\n", "no node before it"},
		"a gate that re-runs a later node": {"  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: plan, reruns: b }\n  - { id: b, kind: exec, run: [echo] }\n", "must be a node before it"},
		"a gate that re-runs a gate":       {"  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: plan }\n  - { id: h, kind: gate, gate: feature, reruns: g }\n", "must be a node before it"},
		"an unknown approval point":        {"  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: ship }\n", bySchema},
		"exec without a command":           {"  - { id: a, kind: exec }\n", bySchema},
		"agent with a command":             {"  - { id: a, kind: agent, role: planner, prompt: p.md, run: [echo] }\n", bySchema},
		"a boolean as a command":           {"  - { id: a, kind: exec, run: [true] }\n", bySchema}, // YAML reads true as a boolean; write "true"
		"a prompt outside the realm":       {"  - { id: a, kind: agent, role: planner, prompt: ../secrets.md }\n", "inside the realm"},
		"an absolute prompt path":          {"  - { id: a, kind: agent, role: planner, prompt: /etc/passwd }\n", "inside the realm"},
		"a timeout in words":               {"  - { id: a, kind: exec, run: [echo], timeout: 5 minutes }\n", bySchema},
		"no nodes":                         {"  []\n", bySchema},
	}
	for name, c := range cases {
		_, err := ParseGraph("graph.yaml", []byte(head+c.nodes))
		if err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: ParseGraph() = %v, want an error containing %q", name, err, c.want)
		}
	}
}

func TestGraphSchemaKnowsEveryApprovalPoint(t *testing.T) {
	for _, g := range gungnir.Gates() {
		y := "name: toy\nversion: 1.0.0\nnodes:\n  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: " + string(g) + " }\n"
		if _, err := ParseGraph("graph.yaml", []byte(y)); err != nil {
			t.Errorf("gate %s: %v", g, err)
		}
	}
}

func TestLoadPack(t *testing.T) {
	dir := t.TempDir()
	write := func(s string) {
		if err := os.WriteFile(filepath.Join(dir, "pack.yaml"), []byte(s), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write("name: toy\nversion: 0.1.0\ngraph: graph.yaml\nroles:\n  planner: { agent: scripted, model: none }\nchecks:\n  unit: [go, test, ./...]\n")
	p, err := LoadPack(dir)
	if err != nil {
		t.Fatalf("LoadPack() = %v", err)
	}
	if p.Graph != "graph.yaml" || p.Roles["planner"].Agent != "scripted" || len(p.Checks["unit"]) != 3 {
		t.Errorf("got %+v", p)
	}
	for name, s := range map[string]string{
		"a graph outside the realm": "name: toy\nversion: 0.1.0\ngraph: ../graph.yaml\n",
		"no version":                "name: toy\ngraph: graph.yaml\n",
		"an unknown field":          "name: toy\nversion: 0.1.0\ngraph: graph.yaml\nhooks: [x]\n",
	} {
		write(s)
		if _, err := LoadPack(dir); err == nil {
			t.Errorf("%s: LoadPack() = nil error", name)
		}
	}
}
```

- [ ] **Step 2:** run the named test; expect a build failure: `undefined: ParseGraph`.
- [ ] **Step 3:** write `schema/graph.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/graph.schema.json",
  "title": "graph.yaml",
  "description": "A realm's graph: nodes run in order; a gate node is an approval point (spec §4.2, §7). Loop nodes come in a later schema version.",
  "type": "object",
  "additionalProperties": false,
  "required": ["name", "version", "nodes"],
  "properties": {
    "name": { "$ref": "#/$defs/id" },
    "version": { "$ref": "#/$defs/version" },
    "nodes": { "type": "array", "minItems": 1, "items": { "$ref": "#/$defs/node" } }
  },
  "$defs": {
    "id": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
    "version": { "type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$" },
    "duration": { "type": "string", "pattern": "^[0-9]+(ms|s|m|h)$" },
    "node": {
      "type": "object",
      "required": ["id", "kind"],
      "properties": { "kind": { "enum": ["exec", "agent", "gate"] } },
      "oneOf": [
        {
          "additionalProperties": false,
          "required": ["run"],
          "properties": {
            "id": { "$ref": "#/$defs/id" },
            "kind": { "const": "exec" },
            "run": { "type": "array", "minItems": 1, "items": { "type": "string", "minLength": 1 } },
            "timeout": { "$ref": "#/$defs/duration" }
          }
        },
        {
          "additionalProperties": false,
          "required": ["role", "prompt"],
          "properties": {
            "id": { "$ref": "#/$defs/id" },
            "kind": { "const": "agent" },
            "role": { "$ref": "#/$defs/id" },
            "prompt": { "type": "string", "minLength": 1 },
            "read_only": { "type": "boolean" },
            "max_turns": { "type": "integer", "minimum": 1 },
            "timeout": { "$ref": "#/$defs/duration" }
          }
        },
        {
          "additionalProperties": false,
          "required": ["gate"],
          "properties": {
            "id": { "$ref": "#/$defs/id" },
            "kind": { "const": "gate" },
            "gate": {
              "enum": ["design", "spec", "plan", "feature", "merge", "pointer", "pointer-contract",
                       "deploy-prod", "store-submit", "real-secrets-or-user-data", "budget-cap",
                       "external-input", "policy-violation", "shrink-guard", "guardrail-change"]
            },
            "reruns": { "$ref": "#/$defs/id" }
          }
        }
      ]
    }
  }
}
```

- [ ] **Step 4:** write `schema/pack.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/pack.schema.json",
  "title": "pack.yaml",
  "description": "A realm pack: its name, version, graph, default roles and check commands (spec §9.4).",
  "type": "object",
  "additionalProperties": false,
  "required": ["name", "version", "graph"],
  "properties": {
    "name": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
    "version": { "type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$" },
    "graph": { "type": "string", "minLength": 1 },
    "roles": {
      "type": "object",
      "propertyNames": { "pattern": "^[a-z][a-z0-9-]*$" },
      "additionalProperties": {
        "type": "object",
        "additionalProperties": false,
        "required": ["agent", "model"],
        "properties": {
          "agent": { "enum": ["claude-code", "opencode", "scripted"] },
          "model": { "type": "string", "minLength": 1 }
        }
      }
    },
    "checks": {
      "type": "object",
      "propertyNames": { "pattern": "^[a-z][a-z0-9-]*$" },
      "additionalProperties": { "type": "array", "minItems": 1, "items": { "type": "string", "minLength": 1 } }
    }
  }
}
```

- [ ] **Step 5:** write `schema/graph.go`:

```go
package schema

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"go.yaml.in/yaml/v3"
)

// Graph is a realm's graph.yaml. Nodes run in order.
type Graph struct {
	Name    string `yaml:"name"`
	Version string `yaml:"version"`
	Nodes   []Node `yaml:"nodes"`
}

// NodeKind is what a node does.
type NodeKind string

const (
	KindExec  NodeKind = "exec"  // runs a command
	KindAgent NodeKind = "agent" // runs one agent session
	KindGate  NodeKind = "gate"  // an approval point
)

// Node is one step of a graph. Which fields apply depends on Kind.
type Node struct {
	ID       string       `yaml:"id"`
	Kind     NodeKind     `yaml:"kind"`
	Run      []string     `yaml:"run"`       // exec: the command, without a shell
	Role     string       `yaml:"role"`      // agent: the factory.yaml role
	Prompt   string       `yaml:"prompt"`    // agent: the prompt file, relative to the graph
	ReadOnly bool         `yaml:"read_only"` // agent
	MaxTurns int          `yaml:"max_turns"` // agent
	Timeout  Duration     `yaml:"timeout"`   // exec and agent
	Gate     gungnir.Gate `yaml:"gate"`      // gate: the approval point
	Reruns   string       `yaml:"reruns"`    // gate: the node a rejection re-runs; set by ParseGraph
}

// Duration is a time.Duration written as "30s", "10m" or "1h".
type Duration time.Duration

func (d *Duration) UnmarshalYAML(n *yaml.Node) error {
	v, err := time.ParseDuration(n.Value)
	if err != nil {
		return err
	}
	*d = Duration(v)
	return nil
}

// Index returns the position of the node with the given id, or -1.
func (g *Graph) Index(id string) int {
	for i, n := range g.Nodes {
		if n.ID == id {
			return i
		}
	}
	return -1
}

// LoadGraph reads and parses a graph.yaml file.
func LoadGraph(path string) (*Graph, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return ParseGraph(path, data)
}

// ParseGraph parses graph.yaml. Ids must be unique, prompt files must stay inside the realm, and
// every gate gets the node its rejection re-runs: the one it names, which must come before it and
// not be a gate, or else the nearest non-gate node before it.
func ParseGraph(file string, data []byte) (*Graph, error) {
	var g Graph
	if err := parseYAML(file, "graph.schema.json", data, &g); err != nil {
		return nil, err
	}
	seen := map[string]int{}
	for i := range g.Nodes {
		n := &g.Nodes[i]
		if _, dup := seen[n.ID]; dup {
			return nil, fmt.Errorf("%s: node id %q is used twice", file, n.ID)
		}
		seen[n.ID] = i
		if n.Kind == KindAgent && !filepath.IsLocal(n.Prompt) {
			return nil, fmt.Errorf("%s: node %s: prompt %q must be a path inside the realm", file, n.ID, n.Prompt)
		}
		if n.Kind != KindGate {
			continue
		}
		if n.Reruns == "" {
			for j := i - 1; j >= 0 && n.Reruns == ""; j-- {
				if g.Nodes[j].Kind != KindGate {
					n.Reruns = g.Nodes[j].ID
				}
			}
			if n.Reruns == "" {
				return nil, fmt.Errorf("%s: gate %s has no node before it to re-run when rejected", file, n.ID)
			}
			continue
		}
		j, ok := seen[n.Reruns]
		if !ok || j == i || g.Nodes[j].Kind == KindGate {
			return nil, fmt.Errorf("%s: gate %s re-runs %q, which must be a node before it and not a gate", file, n.ID, n.Reruns)
		}
	}
	return &g, nil
}
```

- [ ] **Step 6:** write `schema/pack.go`:

```go
package schema

import (
	"fmt"
	"os"
	"path/filepath"
)

// Pack is a realm's pack.yaml (spec §9.4).
type Pack struct {
	Name    string              `yaml:"name"`
	Version string              `yaml:"version"`
	Graph   string              `yaml:"graph"`  // relative to the pack
	Roles   map[string]PackRole `yaml:"roles"`  // default roles; factory.yaml's roles are used from Phase 1
	Checks  map[string][]string `yaml:"checks"` // check commands, used from Phase 4
}

// PackRole is a realm's default agent and model for a role.
type PackRole struct {
	Agent string `yaml:"agent"`
	Model string `yaml:"model"`
}

// LoadPack reads dir/pack.yaml. The graph path must stay inside dir.
func LoadPack(dir string) (*Pack, error) {
	file := filepath.Join(dir, "pack.yaml")
	data, err := os.ReadFile(file)
	if err != nil {
		return nil, err
	}
	var p Pack
	if err := parseYAML(file, "pack.schema.json", data, &p); err != nil {
		return nil, err
	}
	if !filepath.IsLocal(p.Graph) {
		return nil, fmt.Errorf("%s: graph %q must be a path inside the realm", file, p.Graph)
	}
	return &p, nil
}
```

- [ ] **Step 7:** run the named test; expect `ok`. Land it.

---

### Task v0-T024: ledger events and findings

The ledger line format, with OpenTelemetry's GenAI attribute names (spec §10.1), and the finding
schema (spec §4.6). The `gen_ai.*` names were checked on 2026-10-15 against the registry in
`open-telemetry/semantic-conventions-genai`, where they moved from the main semantic conventions.
That repo has no release yet, and the names' status is Development.

**Files (in `gungnir`):**

- Create: `event.go`, `schema/ledger-event.schema.json`, `schema/finding.schema.json`,
  `schema/event.go`, `schema/event_test.go`

**Interfaces:**

- Produces: `gungnir.Event`, `EventName` with 20 constants, `Events()`, `LedgerSchema`
  (`"ygg.ledger/v1"`), `Event.WithUsage(Usage) Event`; `schema.ValidateEvent(line []byte) error`;
  `schema.ParseFinding(data []byte) (gungnir.Finding, error)`.

**Acceptance criteria:**

- [ ] Usage marshals as `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens` and
      `gen_ai.usage.cache_read.input_tokens`; the role as `gen_ai.agent.name`; the model as
      `gen_ai.request.model`.
- [ ] Every event name validates. An unknown event, a missing or short `prev`, an unknown field, and
      a path as the run id are refused.
- [ ] A finding without a location, a fixed one without proof, free text, and `{}` are refused.

**Named test:** `go test ./schema/ -run 'TestEventsUseOTelNames|TestLedgerEventSchema|TestParseFinding'`.
**Layer:** `gungnir`. **Size:** M (270 lines). **Depends on:** v0-T021.

- [ ] **Step 1:** write `schema/event_test.go`:

```go
package schema

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

const zeros = "0000000000000000000000000000000000000000000000000000000000000000"

func event(name gungnir.EventName) gungnir.Event {
	return gungnir.Event{Schema: gungnir.LedgerSchema, Seq: 1, Time: time.Date(2026, 10, 15, 9, 0, 0, 0, time.UTC),
		Run: "20261015-090000-a1b2c3", Name: name, Prev: zeros}
}

func TestEventsUseOTelNames(t *testing.T) {
	e := event(gungnir.EventNodeFinished).WithUsage(gungnir.Usage{InTok: 1200, OutTok: 300, CacheTok: 900, Turns: 4, CostUSD: 0.02})
	e.Node, e.Attempt, e.Role, e.Model, e.Adapter = "design", 1, "planner", "none", "scripted"
	line, err := json.Marshal(e)
	if err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{`"gen_ai.usage.input_tokens":1200`, `"gen_ai.usage.output_tokens":300`,
		`"gen_ai.usage.cache_read.input_tokens":900`, `"gen_ai.request.model":"none"`, `"gen_ai.agent.name":"planner"`} {
		if !strings.Contains(string(line), key) {
			t.Errorf("line lacks %s:\n%s", key, line)
		}
	}
	if err := ValidateEvent(line); err != nil {
		t.Errorf("ValidateEvent() = %v", err)
	}
}

func TestLedgerEventSchema(t *testing.T) {
	for _, n := range gungnir.Events() {
		line, _ := json.Marshal(event(n))
		if err := ValidateEvent(line); err != nil {
			t.Errorf("%s: %v", n, err)
		}
	}
	bad := map[string]string{
		"an unknown event": strings.Replace(mustJSON(t, event(gungnir.EventRunStarted)), `"run_started"`, `"run_paused"`, 1),
		"no prev":          strings.Replace(mustJSON(t, event(gungnir.EventRunStarted)), `,"prev":"`+zeros+`"`, "", 1),
		"a short prev":     strings.Replace(mustJSON(t, event(gungnir.EventRunStarted)), zeros, "abc", 1),
		"an unknown field": strings.Replace(mustJSON(t, event(gungnir.EventRunStarted)), `{`, `{"tokens":5,`, 1),
		"a path as run id": strings.Replace(mustJSON(t, event(gungnir.EventRunStarted)), "20261015-090000-a1b2c3", "../x", 1),
		"not JSON":         `{"schema":`,
	}
	for name, line := range bad {
		if err := ValidateEvent([]byte(line)); err == nil {
			t.Errorf("%s: ValidateEvent() = nil", name)
		}
	}
}

func TestParseFindingRefusesMalformedFindings(t *testing.T) {
	good := `{"id":"F1","source":"reviewer-spec","severity":"major","location":"api/auth.go:42","claim":"no throttle","status":"open"}`
	if _, err := ParseFinding([]byte(good)); err != nil {
		t.Fatalf("good finding: %v", err)
	}
	for name, s := range map[string]string{
		"no location":         `{"id":"F1","source":"r","severity":"major","claim":"c","status":"open"}`,
		"fixed without proof": `{"id":"F1","source":"r","severity":"major","location":"a.go:1","claim":"c","status":"fixed"}`,
		"free text":           `the code looks fine`,
		"an empty object":     `{}`,
	} {
		if _, err := ParseFinding([]byte(s)); err == nil {
			t.Errorf("%s: ParseFinding() = nil error", name)
		}
	}
}

func mustJSON(t *testing.T, v any) string {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}
```

- [ ] **Step 2:** run the named test; expect a build failure: `undefined: gungnir.Event`.
- [ ] **Step 3:** write `event.go`:

```go
package gungnir

import "time"

// LedgerSchema names the ledger line format. A breaking change gets a new version.
const LedgerSchema = "ygg.ledger/v1"

// EventName is what a ledger line records (spec §10.1).
type EventName string

const (
	EventRunStarted      EventName = "run_started"
	EventRunResumed      EventName = "run_resumed"
	EventRunFinished     EventName = "run_finished"
	EventRunFailed       EventName = "run_failed"
	EventNodeStarted     EventName = "node_started"
	EventNodeFinished    EventName = "node_finished"
	EventNodeFailed      EventName = "node_failed"
	EventCheckResult     EventName = "check_result"
	EventGatePending     EventName = "gate_pending"
	EventGateApproved    EventName = "gate_approved"
	EventGateRejected    EventName = "gate_rejected"
	EventGateAutoPassed  EventName = "gate_auto_passed"
	EventLoopAttempt     EventName = "loop_attempt"
	EventEscalation      EventName = "escalation"
	EventRoutingLookup   EventName = "routing_lookup"
	EventBudgetWarning   EventName = "budget_warning"
	EventPolicyViolation EventName = "policy_violation"
	EventPointerMoved    EventName = "pointer_moved"
	EventModeChanged     EventName = "mode_changed"
	EventConfigChanged   EventName = "config_changed"
)

// Events returns every event name, in the order above.
func Events() []EventName {
	return []EventName{EventRunStarted, EventRunResumed, EventRunFinished, EventRunFailed,
		EventNodeStarted, EventNodeFinished, EventNodeFailed, EventCheckResult, EventGatePending,
		EventGateApproved, EventGateRejected, EventGateAutoPassed, EventLoopAttempt, EventEscalation,
		EventRoutingLookup, EventBudgetWarning, EventPolicyViolation, EventPointerMoved,
		EventModeChanged, EventConfigChanged}
}

// Event is one ledger line. Fields follow OpenTelemetry's GenAI attribute names (gen_ai.*) where
// one exists, so an OTel exporter is a mapping (spec §10.1); the rest use the ygg.* namespace.
type Event struct {
	Schema  string    `json:"schema"`
	Seq     int64     `json:"seq"` // 1 on the first line
	Time    time.Time `json:"time"`
	Run     string    `json:"ygg.run.id"`
	Node    string    `json:"ygg.node.id,omitempty"`
	Name    EventName `json:"event"`
	Attempt int       `json:"ygg.attempt,omitempty"`

	Role       string `json:"gen_ai.agent.name,omitempty"` // the factory.yaml role
	Provider   string `json:"gen_ai.provider.name,omitempty"`
	Model      string `json:"gen_ai.request.model,omitempty"`
	Adapter    string `json:"ygg.agent.adapter,omitempty"`
	CLIVersion string `json:"ygg.agent.cli_version,omitempty"`

	InputTokens     int64   `json:"gen_ai.usage.input_tokens,omitempty"`
	OutputTokens    int64   `json:"gen_ai.usage.output_tokens,omitempty"`
	CacheReadTokens int64   `json:"gen_ai.usage.cache_read.input_tokens,omitempty"`
	Turns           int64   `json:"ygg.usage.turns,omitempty"`
	CostUSD         float64 `json:"ygg.usage.cost_usd,omitempty"`
	CostEstimated   bool    `json:"ygg.usage.cost_estimated,omitempty"`

	DurationMS int64  `json:"ygg.duration_ms,omitempty"`
	Result     string `json:"ygg.result,omitempty"`
	Gate       string `json:"ygg.gate.name,omitempty"` // the gate node's id
	Note       string `json:"ygg.note,omitempty"`      // an approval note or a rejection reason
	Mode       Mode   `json:"ygg.mode,omitempty"`
	Looser     bool   `json:"ygg.mode.looser,omitempty"`
	ConfigHash string `json:"ygg.config.sha256,omitempty"`
	Commit     string `json:"ygg.ref.commit,omitempty"`
	GateFile   string `json:"ygg.ref.gate_file,omitempty"`

	Prev string `json:"prev"` // hex SHA-256 of the previous line; 64 zeros on the first line
}

// WithUsage returns e with u's numbers in the usage fields.
func (e Event) WithUsage(u Usage) Event {
	e.InputTokens, e.OutputTokens, e.CacheReadTokens = u.InTok, u.OutTok, u.CacheTok
	e.Turns, e.CostUSD, e.CostEstimated = u.Turns, u.CostUSD, u.CostEstimated
	return e
}
```

- [ ] **Step 4:** write `schema/ledger-event.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/ledger-event.schema.json",
  "title": "ledger.jsonl line",
  "description": "One line of a run's hash-chained ledger (spec §10.1). gen_ai.* names follow the OpenTelemetry GenAI attribute registry (open-telemetry/semantic-conventions-genai, read 2026-10-15; status Development).",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "seq", "time", "ygg.run.id", "event", "prev"],
  "properties": {
    "schema": { "const": "ygg.ledger/v1" },
    "seq": { "type": "integer", "minimum": 1 },
    "time": { "type": "string", "minLength": 20 },
    "ygg.run.id": { "type": "string", "pattern": "^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$" },
    "ygg.node.id": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
    "event": {
      "enum": ["run_started", "run_resumed", "run_finished", "run_failed", "node_started",
               "node_finished", "node_failed", "check_result", "gate_pending", "gate_approved",
               "gate_rejected", "gate_auto_passed", "loop_attempt", "escalation", "routing_lookup",
               "budget_warning", "policy_violation", "pointer_moved", "mode_changed", "config_changed"]
    },
    "ygg.attempt": { "type": "integer", "minimum": 1 },
    "gen_ai.agent.name": { "type": "string" },
    "gen_ai.provider.name": { "type": "string" },
    "gen_ai.request.model": { "type": "string" },
    "ygg.agent.adapter": { "type": "string" },
    "ygg.agent.cli_version": { "type": "string" },
    "gen_ai.usage.input_tokens": { "type": "integer", "minimum": 0 },
    "gen_ai.usage.output_tokens": { "type": "integer", "minimum": 0 },
    "gen_ai.usage.cache_read.input_tokens": { "type": "integer", "minimum": 0 },
    "ygg.usage.turns": { "type": "integer", "minimum": 0 },
    "ygg.usage.cost_usd": { "type": "number", "minimum": 0 },
    "ygg.usage.cost_estimated": { "type": "boolean" },
    "ygg.duration_ms": { "type": "integer", "minimum": 0 },
    "ygg.result": { "type": "string" },
    "ygg.gate.name": { "type": "string" },
    "ygg.note": { "type": "string" },
    "ygg.mode": { "enum": ["step-by-step", "key-points", "unattended"] },
    "ygg.mode.looser": { "type": "boolean" },
    "ygg.config.sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "ygg.ref.commit": { "type": "string", "pattern": "^[0-9a-f]{40,64}$" },
    "ygg.ref.gate_file": { "type": "string" },
    "prev": { "type": "string", "pattern": "^[0-9a-f]{64}$" }
  }
}
```

- [ ] **Step 5:** write `schema/finding.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/finding.schema.json",
  "title": "finding",
  "description": "A typed finding from a check or a reviewer (spec §4.6).",
  "type": "object",
  "additionalProperties": false,
  "required": ["id", "source", "severity", "location", "claim", "status"],
  "properties": {
    "id": { "type": "string", "minLength": 1 },
    "source": { "type": "string", "minLength": 1 },
    "severity": { "enum": ["blocker", "major", "minor"] },
    "location": { "type": "string", "pattern": "^[^\\s:]+:[0-9]+(-[0-9]+)?$" },
    "claim": { "type": "string", "minLength": 1 },
    "status": { "enum": ["open", "fixed", "disputed"] },
    "proof": { "type": "string", "minLength": 1 }
  },
  "if": { "properties": { "status": { "const": "fixed" } } },
  "then": { "required": ["proof"] }
}
```

- [ ] **Step 6:** write `schema/event.go`:

```go
package schema

import (
	"bytes"
	"encoding/json"
	"fmt"

	"github.com/ouroboric-dev/gungnir"
	"github.com/santhosh-tekuri/jsonschema/v6"
)

// ValidateEvent checks one ledger line, without its newline, against the ledger schema.
func ValidateEvent(line []byte) error {
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(line))
	if err != nil {
		return fmt.Errorf("ledger line: %w", err)
	}
	return validate("ledger line", "ledger-event.schema.json", doc)
}

// ParseFinding parses one finding as JSON. A finding that fails the schema or Validate is an error,
// never a pass (spec §4.6).
func ParseFinding(data []byte) (gungnir.Finding, error) {
	var f gungnir.Finding
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(data))
	if err != nil {
		return f, fmt.Errorf("finding: %w", err)
	}
	if err := validate("finding", "finding.schema.json", doc); err != nil {
		return f, err
	}
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&f); err != nil {
		return f, fmt.Errorf("finding: %w", err)
	}
	return f, f.Validate()
}
```

- [ ] **Step 7:** run the named test; expect `ok`. Land it.

---

### Task v0-T025: the `scripted` adapter

Replays canned actions, for deterministic tests at no model cost (spec §5, §13).

**Files (in `gleipnir`):**

- Create: `scripted/scripted.go`, `scripted/scripted_test.go`
- Modify: `go.mod`, `go.sum`

**Interfaces:**

- Consumes: `gungnir.Agent`, `Task`, `Result`, `Status`, `Usage` (v0-T020, merged and pinned).
- Produces: `scripted.Load(path string) (*scripted.Agent, error)`, where `*Agent` implements
  `gungnir.Agent` with `Name() == "scripted"`. The script format is
  `steps: { <node id>: [ <step for attempt 1>, <attempt 2>, … ] }`. A step has `actions`
  (`write: {path, content}` or `remove: <path>`) and exactly one of `result: {status, summary, usage:
  {in, out, cache, turns, cost_usd, cost_estimated}}`, `hang: true` or `error: <text>`. Each run
  writes `<TranscriptDir>/<node>-<attempt>.json` with the task's role, node, attempt, model and
  prompt.

**Acceptance criteria:**

- [ ] Attempt n of a node replays step n. A missing step is an error, never a default.
- [ ] `hang` blocks until the context ends; `error` returns the script's error.
- [ ] No write leaves the workdir, whether through `..`, an absolute path, or a symlink (`os.Root`).
- [ ] An ambiguous script is refused at `Load`.

**Named test:** `go test ./scripted/`. **Layer:** `gleipnir`. **Size:** M (303 lines). **Depends
on:** v0-T020 merged.

- [ ] **Step 1:** branch `adapter/scripted`; pin `gungnir` (see "How each task lands"); then
      `GOWORK=off go get go.yaml.in/yaml/v3@v3.0.5`.
- [ ] **Step 2:** write `scripted/scripted_test.go`:

```go
package scripted

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

func load(t *testing.T, script string) *Agent {
	t.Helper()
	p := filepath.Join(t.TempDir(), "script.yaml")
	if err := os.WriteFile(p, []byte(script), 0o644); err != nil {
		t.Fatal(err)
	}
	a, err := Load(p)
	if err != nil {
		t.Fatalf("Load() = %v", err)
	}
	return a
}

func TestScriptedReplaysOneStepPerAttempt(t *testing.T) {
	a := load(t, `
steps:
  design:
    - actions:
        - write: { path: docs/design.md, content: "# Design\n" }
      result: { status: ok, summary: wrote the design, usage: { in: 1000, out: 200, cache: 50, turns: 3, cost_usd: 0.01 } }
    - result: { status: failed, summary: gave up }
`)
	work, transcripts := t.TempDir(), t.TempDir()
	task := gungnir.Task{Role: "planner", Node: "design", Attempt: 1, Prompt: "Write the design.", Workdir: work, TranscriptDir: transcripts}
	r, err := a.Run(context.Background(), task)
	if err != nil {
		t.Fatalf("attempt 1: %v", err)
	}
	if r.Status != gungnir.StatusOK || r.Usage.InTok != 1000 || r.Usage.Turns != 3 || r.Usage.CostUSD != 0.01 {
		t.Errorf("attempt 1 = %+v", r)
	}
	if b, err := os.ReadFile(filepath.Join(work, "docs/design.md")); err != nil || string(b) != "# Design\n" {
		t.Errorf("docs/design.md = %q, %v", b, err)
	}
	if b, err := os.ReadFile(r.TranscriptPath); err != nil || !strings.Contains(string(b), "Write the design.") {
		t.Errorf("transcript %s = %q, %v; want the prompt in it", r.TranscriptPath, b, err)
	}
	task.Attempt = 2
	if r, err := a.Run(context.Background(), task); err != nil || r.Status != gungnir.StatusFailed {
		t.Errorf("attempt 2 = %+v, %v; want a failed result", r, err)
	}
	task.Attempt = 3
	if _, err := a.Run(context.Background(), task); err == nil {
		t.Error("attempt 3 has no step, but Run returned no error")
	}
	if _, err := a.Run(context.Background(), gungnir.Task{Node: "spec", Attempt: 1, Workdir: work}); err == nil {
		t.Error("node spec has no steps, but Run returned no error")
	}
}

func TestScriptedHangsUntilTheContextEnds(t *testing.T) {
	a := load(t, "steps:\n  build:\n    - hang: true\n")
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan error, 1)
	go func() {
		_, err := a.Run(ctx, gungnir.Task{Node: "build", Attempt: 1, Workdir: t.TempDir()})
		done <- err
	}()
	cancel()
	select {
	case err := <-done:
		if !errors.Is(err, context.Canceled) {
			t.Errorf("Run() = %v, want context.Canceled", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Run() did not return after the context was cancelled")
	}
}

func TestScriptedErrorStepIsAnAgentFailure(t *testing.T) {
	a := load(t, "steps:\n  build:\n    - error: the CLI crashed\n")
	if _, err := a.Run(context.Background(), gungnir.Task{Node: "build", Attempt: 1, Workdir: t.TempDir()}); err == nil || err.Error() != "the CLI crashed" {
		t.Errorf("Run() = %v, want the script's error", err)
	}
}

func TestScriptedCannotWriteOutsideTheWorkdir(t *testing.T) {
	outside := t.TempDir()
	work := t.TempDir()
	if err := os.Symlink(outside, filepath.Join(work, "link")); err != nil {
		t.Fatal(err)
	}
	a := load(t, "steps:\n  build:\n    - actions:\n        - write: { path: link/escaped.txt, content: x }\n      result: { status: ok }\n")
	if _, err := a.Run(context.Background(), gungnir.Task{Node: "build", Attempt: 1, Workdir: work}); err == nil {
		t.Error("a write through a symlink out of the workdir succeeded")
	}
	if _, err := os.Stat(filepath.Join(outside, "escaped.txt")); !errors.Is(err, os.ErrNotExist) {
		t.Errorf("escaped.txt exists outside the workdir (stat: %v)", err)
	}
}

func TestLoadRefusesAmbiguousScripts(t *testing.T) {
	cases := map[string]string{
		"two outcomes":       "steps:\n  a:\n    - { hang: true, result: { status: ok } }\n",
		"no outcome":         "steps:\n  a:\n    - actions: [ { remove: x } ]\n",
		"an unknown status":  "steps:\n  a:\n    - result: { status: passed }\n",
		"an unknown field":   "steps:\n  a:\n    - result: { status: ok }\n      sleep: 5\n",
		"a path that climbs": "steps:\n  a:\n    - actions: [ { write: { path: ../x, content: y } } ]\n      result: { status: ok }\n",
		"an absolute path":   "steps:\n  a:\n    - actions: [ { remove: /etc/passwd } ]\n      result: { status: ok }\n",
		"write and remove":   "steps:\n  a:\n    - actions: [ { write: { path: x, content: y }, remove: z } ]\n      result: { status: ok }\n",
	}
	for name, s := range cases {
		p := filepath.Join(t.TempDir(), "script.yaml")
		if err := os.WriteFile(p, []byte(s), 0o644); err != nil {
			t.Fatal(err)
		}
		if _, err := Load(p); err == nil {
			t.Errorf("%s: Load() = nil error", name)
		}
	}
}
```

- [ ] **Step 3:** run the named test; expect a build failure: `undefined: Load`.
- [ ] **Step 4:** write `scripted/scripted.go`:

```go
// Package scripted is the agent adapter that replays canned actions, at no model cost. It is for
// tests only (spec §5, §13).
package scripted

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/ouroboric-dev/gungnir"
	"go.yaml.in/yaml/v3"
)

// Script says what each attempt of each node does: steps[node][attempt-1].
type Script struct {
	Steps map[string][]Step `yaml:"steps"`
}

// Step is one attempt. Exactly one of Result, Hang and Error is set.
type Step struct {
	Actions []Action `yaml:"actions"` // applied in order, inside the workdir, before the result
	Result  *Outcome `yaml:"result"`
	Hang    bool     `yaml:"hang"`  // block until the context ends: a session the factory must stop
	Error   string   `yaml:"error"` // Run returns this error: an agent failure
}

// Action changes one file in the workdir. Exactly one field is set.
type Action struct {
	Write  *Write `yaml:"write"`
	Remove string `yaml:"remove"`
}

// Write writes Content to Path, creating parent directories.
type Write struct {
	Path    string `yaml:"path"`
	Content string `yaml:"content"`
}

// Outcome is the result a step reports.
type Outcome struct {
	Status  gungnir.Status `yaml:"status"`
	Summary string         `yaml:"summary"`
	Usage   struct {
		In            int64   `yaml:"in"`
		Out           int64   `yaml:"out"`
		Cache         int64   `yaml:"cache"`
		Turns         int64   `yaml:"turns"`
		CostUSD       float64 `yaml:"cost_usd"`
		CostEstimated bool    `yaml:"cost_estimated"`
	} `yaml:"usage"`
}

// Agent replays a Script.
type Agent struct{ script Script }

var _ gungnir.Agent = (*Agent)(nil)

// Load reads and checks a script. A script that could be read two ways is refused.
func Load(path string) (*Agent, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	dec := yaml.NewDecoder(bytes.NewReader(data))
	dec.KnownFields(true)
	var s Script
	if err := dec.Decode(&s); err != nil && !errors.Is(err, io.EOF) {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	for node, steps := range s.Steps {
		for i, st := range steps {
			if err := st.check(); err != nil {
				return nil, fmt.Errorf("%s: steps.%s[%d]: %w", path, node, i, err)
			}
		}
	}
	return &Agent{script: s}, nil
}

func (st Step) check() error {
	set := 0
	for _, b := range []bool{st.Result != nil, st.Hang, st.Error != ""} {
		if b {
			set++
		}
	}
	if set != 1 {
		return errors.New("set exactly one of result, hang and error")
	}
	if st.Result != nil && st.Result.Status != gungnir.StatusOK && st.Result.Status != gungnir.StatusFailed {
		return fmt.Errorf("result status %q is neither ok nor failed", st.Result.Status)
	}
	for _, a := range st.Actions {
		switch {
		case a.Write != nil && a.Remove != "":
			return errors.New("an action sets both write and remove")
		case a.Write != nil && !filepath.IsLocal(a.Write.Path), a.Write == nil && !filepath.IsLocal(a.Remove):
			return errors.New("an action's path must be a relative path inside the workdir")
		}
	}
	return nil
}

func (a *Agent) Name() string { return "scripted" }

// Run replays the step for t.Node's attempt t.Attempt. Files change only inside t.Workdir: the
// workdir is opened as an os.Root, so neither ".." nor a symlink leads out of it.
func (a *Agent) Run(ctx context.Context, t gungnir.Task) (gungnir.Result, error) {
	steps := a.script.Steps[t.Node]
	if t.Attempt < 1 || t.Attempt > len(steps) {
		return gungnir.Result{}, fmt.Errorf("scripted: the script has no attempt %d for node %q", t.Attempt, t.Node)
	}
	st := steps[t.Attempt-1]
	transcript, err := writeTranscript(t)
	if err != nil {
		return gungnir.Result{}, err
	}
	if st.Hang {
		<-ctx.Done()
		return gungnir.Result{}, ctx.Err()
	}
	if st.Error != "" {
		return gungnir.Result{}, errors.New(st.Error)
	}
	root, err := os.OpenRoot(t.Workdir)
	if err != nil {
		return gungnir.Result{}, err
	}
	defer root.Close()
	for _, act := range st.Actions {
		if err := apply(root, act); err != nil {
			return gungnir.Result{}, fmt.Errorf("scripted: %w", err)
		}
	}
	o := st.Result
	return gungnir.Result{
		Status:  o.Status,
		Summary: o.Summary,
		Usage: gungnir.Usage{InTok: o.Usage.In, OutTok: o.Usage.Out, CacheTok: o.Usage.Cache,
			Turns: o.Usage.Turns, CostUSD: o.Usage.CostUSD, CostEstimated: o.Usage.CostEstimated},
		TranscriptPath: transcript,
	}, nil
}

func apply(root *os.Root, act Action) error {
	if act.Write == nil {
		return root.Remove(act.Remove)
	}
	if dir := filepath.Dir(act.Write.Path); dir != "." {
		if err := root.MkdirAll(dir, 0o755); err != nil {
			return err
		}
	}
	return root.WriteFile(act.Write.Path, []byte(act.Write.Content), 0o644)
}

// writeTranscript records the task the session got, so tests can check what reached the agent.
func writeTranscript(t gungnir.Task) (string, error) {
	if t.TranscriptDir == "" {
		return "", nil
	}
	if err := os.MkdirAll(t.TranscriptDir, 0o755); err != nil {
		return "", err
	}
	data, err := json.MarshalIndent(map[string]any{
		"role": t.Role, "node": t.Node, "attempt": t.Attempt, "model": t.Model, "prompt": t.Prompt,
	}, "", "  ")
	if err != nil {
		return "", err
	}
	p := filepath.Join(t.TranscriptDir, fmt.Sprintf("%s-%d.json", t.Node, t.Attempt))
	return p, os.WriteFile(p, data, 0o644)
}
```

- [ ] **Step 5:** `GOWORK=off go mod tidy`; run the named test; expect `ok`. Land it.

---

### Task v0-T026: the ledger

**Files (in `odin`):**

- Create: `internal/ledger/ledger.go`, `internal/ledger/ledger_test.go`
- Modify: `go.mod`, `go.sum`

**Interfaces:**

- Consumes: `gungnir.Event`, `schema.ValidateEvent` (v0-T024, merged and pinned).
- Produces: `ledger.Genesis`, `ledger.Anchor{Seq int64; Hash string}`,
  `ledger.Open(path string, want Anchor) (*Ledger, error)`, `(*Ledger).Append(gungnir.Event) error`,
  `Head() Anchor` and `Close() error`, and `ledger.Verify(path string, want Anchor) (Anchor, error)`.

**Acceptance criteria:**

- [ ] Each line holds the SHA-256 of the line before it; the first holds `Genesis`. Each line is
      synced to disk before `Append` returns.
- [ ] `Verify` names the changed line, catches lines cut from the end against an anchor, and
      refuses a torn last line. `Open` refuses to append to any of these (review focus 5).
- [ ] `Append` refuses an event the schema rejects, and the head doesn't move.

**Named test:** `go test ./internal/ledger/`. **Layer:** `odin`. **Size:** M (270 lines). **Depends
on:** v0-T024 merged.

- [ ] **Step 1:** branch `engine/ledger`; pin `gungnir`.
- [ ] **Step 2:** write `internal/ledger/ledger_test.go`:

```go
package ledger

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

const run = "20261015-090000-a1b2c3"

func write(t *testing.T, n int) (string, Anchor) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "ledger.jsonl")
	l, err := Open(path, Anchor{})
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	for i := 0; i < n; i++ {
		if err := l.Append(gungnir.Event{Run: run, Node: "design", Name: gungnir.EventNodeStarted, Attempt: i + 1}); err != nil {
			t.Fatal(err)
		}
	}
	return path, l.Head()
}

func lines(t *testing.T, path string) [][]byte {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return bytes.Split(bytes.TrimSuffix(b, []byte("\n")), []byte("\n"))
}

func TestLedgerChainsEveryLine(t *testing.T) {
	path, head := write(t, 3)
	ls := lines(t, path)
	sum := sha256.Sum256(ls[0])
	if !bytes.Contains(ls[1], []byte(`"prev":"`+hex.EncodeToString(sum[:])+`"`)) {
		t.Errorf("line 2 doesn't hold line 1's hash:\n%s", ls[1])
	}
	if !bytes.Contains(ls[0], []byte(`"prev":"`+Genesis+`"`)) {
		t.Errorf("line 1 doesn't start from the genesis hash:\n%s", ls[0])
	}
	got, err := Verify(path, head)
	if err != nil || got != head || got.Seq != 3 {
		t.Errorf("Verify() = %+v, %v; want %+v", got, err, head)
	}
}

func TestVerifyNamesTheChangedLine(t *testing.T) {
	path, head := write(t, 3)
	b, _ := os.ReadFile(path)
	changed := bytes.Replace(b, []byte(`"ygg.attempt":2`), []byte(`"ygg.attempt":7`), 1)
	if err := os.WriteFile(path, changed, 0o644); err != nil {
		t.Fatal(err)
	}
	_, err := Verify(path, head)
	if err == nil || !strings.Contains(err.Error(), "line 2 was changed") {
		t.Errorf("Verify() = %v, want an error that names line 2", err)
	}
}

func TestVerifyCatchesLinesCutFromTheEnd(t *testing.T) {
	path, head := write(t, 3)
	ls := lines(t, path)
	if err := os.WriteFile(path, append(bytes.Join(ls[:2], []byte("\n")), '\n'), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Verify(path, Anchor{}); err != nil {
		t.Fatalf("without an anchor the shorter chain is valid, but Verify() = %v", err)
	}
	if _, err := Verify(path, head); err == nil || !strings.Contains(err.Error(), "lines were removed") {
		t.Errorf("Verify() with the anchor = %v, want lines were removed", err)
	}
}

func TestVerifyRefusesATornLastLine(t *testing.T) {
	path, _ := write(t, 2)
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		t.Fatal(err)
	}
	f.WriteString(`{"schema":"ygg.ledger/v1","seq":3`)
	f.Close()
	if _, err := Verify(path, Anchor{}); err == nil || !strings.Contains(err.Error(), ":3: the line is incomplete") {
		t.Errorf("Verify() = %v, want line 3 incomplete", err)
	}
	if _, err := Open(path, Anchor{}); err == nil {
		t.Error("Open() appends to a ledger with a torn line")
	}
}

func TestOpenContinuesTheChain(t *testing.T) {
	path, head := write(t, 2)
	l, err := Open(path, head)
	if err != nil {
		t.Fatal(err)
	}
	if err := l.Append(gungnir.Event{Run: run, Name: gungnir.EventRunResumed}); err != nil {
		t.Fatal(err)
	}
	l.Close()
	if got, err := Verify(path, l.Head()); err != nil || got.Seq != 3 {
		t.Errorf("Verify() = %+v, %v; want 3 good lines", got, err)
	}
}

func TestAppendRefusesAnEventTheSchemaRejects(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ledger.jsonl")
	l, err := Open(path, Anchor{})
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	if err := l.Append(gungnir.Event{Run: "../../etc", Name: gungnir.EventRunStarted}); err == nil {
		t.Error("Append() wrote an event with a path as its run id")
	}
	if l.Head().Seq != 0 {
		t.Errorf("a refused event moved the head to %d", l.Head().Seq)
	}
}
```

- [ ] **Step 3:** run the named test; expect a build failure: `undefined: Open`.
- [ ] **Step 4:** write `internal/ledger/ledger.go`:

```go
// Package ledger writes and verifies a run's hash-chained ledger (spec §10.1). Odin is its only
// writer. Each line holds the SHA-256 of the line before it, so a changed line breaks the chain at
// the next one; run.json keeps an anchor (the last line's number and hash), so lines cut from the
// end are caught too.
package ledger

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

// Genesis is the prev hash of a ledger's first line.
const Genesis = "0000000000000000000000000000000000000000000000000000000000000000"

// Anchor is a ledger's last line number and that line's hash. Seq 0 means an empty ledger.
type Anchor struct {
	Seq  int64  `json:"seq"`
	Hash string `json:"hash"`
}

// Ledger appends events to one ledger.jsonl.
type Ledger struct {
	f    *os.File
	head Anchor
}

// Open opens path for appending, creating it if it doesn't exist. It refuses a ledger whose chain
// is broken, or that doesn't reach the anchor run.json recorded.
func Open(path string, want Anchor) (*Ledger, error) {
	head, err := Verify(path, want)
	if err != nil && !(errors.Is(err, os.ErrNotExist) && want.Seq == 0) {
		return nil, err
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0o644)
	if err != nil {
		return nil, err
	}
	return &Ledger{f: f, head: head}, nil
}

// Head returns the anchor of the last line written.
func (l *Ledger) Head() Anchor { return l.head }

// Append sets e's schema, seq, prev and (if unset) time, checks e against the ledger schema, and
// writes it as one line, synced to disk before Append returns.
func (l *Ledger) Append(e gungnir.Event) error {
	e.Schema = gungnir.LedgerSchema
	e.Seq = l.head.Seq + 1
	e.Prev = l.head.Hash
	if e.Time.IsZero() {
		e.Time = time.Now().UTC()
	}
	line, err := json.Marshal(e)
	if err != nil {
		return err
	}
	if err := schema.ValidateEvent(line); err != nil {
		return err
	}
	if _, err := l.f.Write(append(line, '\n')); err != nil {
		return err
	}
	if err := l.f.Sync(); err != nil {
		return err
	}
	l.head = Anchor{Seq: e.Seq, Hash: hash(line)}
	return nil
}

// Close closes the file.
func (l *Ledger) Close() error { return l.f.Close() }

// Verify checks every line of path: the schema, the sequence, and the link to the line before. It
// also checks that the ledger reaches want and holds want's hash at want's line. It returns the
// ledger's head, or an error that names the first bad line.
func Verify(path string, want Anchor) (Anchor, error) {
	head := Anchor{Hash: Genesis}
	f, err := os.Open(path)
	if err != nil {
		return head, err
	}
	defer f.Close()
	r := bufio.NewReader(f)
	for {
		line, err := r.ReadBytes('\n')
		if len(line) == 0 && errors.Is(err, io.EOF) {
			break
		}
		if err != nil && !errors.Is(err, io.EOF) {
			return head, err
		}
		n := head.Seq + 1
		if !bytes.HasSuffix(line, []byte("\n")) {
			return head, fmt.Errorf("%s:%d: the line is incomplete", path, n)
		}
		line = bytes.TrimSuffix(line, []byte("\n"))
		if err := schema.ValidateEvent(line); err != nil {
			return head, fmt.Errorf("%s:%d: %w", path, n, err)
		}
		var e struct {
			Seq  int64  `json:"seq"`
			Prev string `json:"prev"`
		}
		if err := json.Unmarshal(line, &e); err != nil {
			return head, fmt.Errorf("%s:%d: %w", path, n, err)
		}
		if e.Seq != n {
			return head, fmt.Errorf("%s:%d: seq is %d", path, n, e.Seq)
		}
		if e.Prev != head.Hash {
			return head, fmt.Errorf("%s:%d: prev doesn't match line %d, so line %d was changed", path, n, n-1, n-1)
		}
		head = Anchor{Seq: n, Hash: hash(line)}
		if n == want.Seq && head.Hash != want.Hash {
			return head, fmt.Errorf("%s:%d: the line differs from the one run.json recorded", path, n)
		}
	}
	if head.Seq < want.Seq {
		return head, fmt.Errorf("%s: has %d lines, but run.json recorded %d: lines were removed", path, head.Seq, want.Seq)
	}
	if head.Seq == 0 {
		head.Hash = Genesis
	}
	return head, nil
}

func hash(line []byte) string {
	s := sha256.Sum256(line)
	return hex.EncodeToString(s[:])
}
```

- [ ] **Step 5:** run the named test; expect `ok`. Land it.

---

### Task v0-T027: `run.json` and the run lock

**Files (in `odin`):**

- Create: `internal/run/state.go`, `internal/run/state_test.go`

**Interfaces:**

- Consumes: `ledger.Anchor` (v0-T026).
- Produces: `run.State` (run.json, schema `"ygg.run/v1"`), `run.Status` (`StatusRunning`,
  `StatusStopped`, `StatusFailed`, `StatusDone`), `RoleRecord`, `NewID(now, random) (string, error)`,
  `NewIDNow()`, `ValidID(string) bool`, `Dir(project, id) string`, `(*State).Save(dir) error`,
  `LoadState(dir) (*State, error)`, `Lock(dir) (unlock func(), err error)`, `Locked(dir) bool` and
  `ErrInUse`.

**Acceptance criteria:**

- [ ] Run ids look like `20261015-142233-a1b2c3`, and `ValidID` refuses anything that could be a path.
- [ ] `Save` writes atomically (a temporary file, then a rename) and leaves only `run.json`.
- [ ] `LoadState` refuses unknown fields and another schema, and never returns a nil map.
- [ ] One process at a time holds a run (review focus 1).

**Named test:** `go test ./internal/run/`. **Layer:** `odin`. **Size:** M (268 lines). **Depends
on:** v0-T026.

- [ ] **Step 1:** write `internal/run/state_test.go`:

```go
package run

import (
	"bytes"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

func TestRunIDs(t *testing.T) {
	id, err := NewID(time.Date(2026, 10, 15, 14, 22, 33, 0, time.UTC), bytes.NewReader([]byte{0xa1, 0xb2, 0xc3}))
	if err != nil || id != "20261015-142233-a1b2c3" {
		t.Errorf("NewID() = %q, %v", id, err)
	}
	if id, err := NewIDNow(); err != nil || !ValidID(id) {
		t.Errorf("NewIDNow() = %q, %v", id, err)
	}
	for _, bad := range []string{"", "../../etc", "20261015-142233-a1b2c3/..", "20261015-142233-A1B2C3", "x"} {
		if ValidID(bad) {
			t.Errorf("ValidID(%q) = true", bad)
		}
	}
}

func TestStateSaveIsAtomicAndRoundTrips(t *testing.T) {
	dir := t.TempDir()
	s := &State{ID: "20261015-142233-a1b2c3", Status: StatusStopped, Mode: gungnir.ModeKeyPoints,
		Position: 2, Attempts: map[string]int{"design": 1}, Pending: "design-gate",
		Usage: gungnir.Usage{InTok: 5, Turns: 1}}
	if err := s.Save(dir); err != nil {
		t.Fatal(err)
	}
	got, err := LoadState(dir)
	if err != nil {
		t.Fatal(err)
	}
	if got.Pending != "design-gate" || got.Attempts["design"] != 1 || got.Usage.InTok != 5 || got.Schema != StateSchema {
		t.Errorf("LoadState() = %+v", got)
	}
	if got.Reasons == nil || got.Summaries == nil {
		t.Error("LoadState() left a map nil; the engine writes to it")
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 1 {
		t.Errorf("Save() left %d files, want only run.json", len(entries))
	}
}

func TestLoadStateRefusesWhatOdinDidntWrite(t *testing.T) {
	dir := t.TempDir()
	for name, body := range map[string]string{
		"an unknown field": `{"schema":"ygg.run/v1","id":"x","pwned":true}`,
		"another schema":   `{"schema":"ygg.run/v9","id":"x"}`,
		"not JSON":         `{`,
	} {
		os.WriteFile(filepath.Join(dir, "run.json"), []byte(body), 0o644)
		if _, err := LoadState(dir); err == nil {
			t.Errorf("%s: LoadState() = nil error", name)
		}
	}
}

func TestLockAllowsOneProcess(t *testing.T) {
	dir := t.TempDir()
	unlock, err := Lock(dir)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := Lock(dir); !errors.Is(err, ErrInUse) {
		t.Errorf("a second Lock() = %v, want ErrInUse", err)
	}
	if !Locked(dir) {
		t.Error("Locked() = false while held")
	}
	unlock()
	if Locked(dir) {
		t.Error("Locked() = true after unlock")
	}
	if !strings.Contains(ErrInUse.Error(), "another ygg process") {
		t.Error("ErrInUse doesn't say what holds the run")
	}
}
```

- [ ] **Step 2:** run the named test; expect a build failure: `undefined: NewID`.
- [ ] **Step 3:** write `internal/run/state.go`. Keep the nil-map lines in `LoadState`: empty maps
      aren't written, and without those lines a reloaded run panics on its first rejection. The
      end-to-end test found this.

```go
// Package run holds a run's directory, its run.json, its lock, and the checks that a run may start
// or continue (spec §4.1, §4.3, §12).
package run

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"syscall"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/ledger"
)

// StateSchema names the run.json format.
const StateSchema = "ygg.run/v1"

// Status is where a run stands.
type Status string

const (
	StatusRunning Status = "running" // a process is walking the graph, or died while it was
	StatusStopped Status = "stopped" // waiting at an approval point
	StatusFailed  Status = "failed"  // a node failed; resume re-runs it
	StatusDone    Status = "done"
)

// RoleRecord is the agent and model a role used.
type RoleRecord struct {
	Agent string `json:"agent"`
	Model string `json:"model"`
}

// State is run.json. Odin is its only writer.
type State struct {
	Schema       string                `json:"schema"`
	ID           string                `json:"id"`
	Status       Status                `json:"status"`
	Mode         gungnir.Mode          `json:"mode"`
	Realm        string                `json:"realm"`
	RealmVersion string                `json:"realm_version"`
	RealmDir     string                `json:"realm_dir"`
	GraphVersion string                `json:"graph_version"`
	GraphSHA256  string                `json:"graph_sha256"`
	ConfigPath   string                `json:"config_path"`
	ConfigSHA256 string                `json:"config_sha256"`
	Brief        string                `json:"brief,omitempty"`
	BriefSHA256  string                `json:"brief_sha256,omitempty"`
	Roles        map[string]RoleRecord `json:"roles"`
	Position     int                   `json:"position"`            // index of the next node to run
	Attempts     map[string]int        `json:"attempts"`            // node id: attempts started
	Pending      string                `json:"pending,omitempty"`   // the gate node waiting for a decision
	Reasons      map[string]string     `json:"reasons,omitempty"`   // node id: rejection reason for its next attempt
	Summaries    map[string]string     `json:"summaries,omitempty"` // node id: its last result
	Usage        gungnir.Usage         `json:"usage"`
	Ledger       ledger.Anchor         `json:"ledger"`
	Error        string                `json:"error,omitempty"`
	Created      time.Time             `json:"created"`
	Updated      time.Time             `json:"updated"`
}

var idPattern = regexp.MustCompile(`^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$`)

// NewID returns a run id: the UTC time and six random hex digits, such as 20261015-142233-a1b2c3.
func NewID(now time.Time, random io.Reader) (string, error) {
	b := make([]byte, 3)
	if _, err := io.ReadFull(random, b); err != nil {
		return "", err
	}
	return now.UTC().Format("20060102-150405") + "-" + hex.EncodeToString(b), nil
}

// NewIDNow returns a run id for the current time.
func NewIDNow() (string, error) { return NewID(time.Now(), rand.Reader) }

// ValidID reports whether id is a run id, so it can't name a path outside the runs directory.
func ValidID(id string) bool { return idPattern.MatchString(id) }

// Dir returns the run directory of id under project.
func Dir(project, id string) string { return filepath.Join(project, ".factory", "runs", id) }

// Save writes run.json atomically: a temporary file in the same directory, synced, then renamed
// over the old one, then the directory synced (spec §12).
func (s *State) Save(dir string) error {
	s.Schema = StateSchema
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, "run.json.tmp-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(append(data, '\n')); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmp.Name(), filepath.Join(dir, "run.json")); err != nil {
		return err
	}
	d, err := os.Open(dir)
	if err != nil {
		return err
	}
	defer d.Close()
	return d.Sync()
}

// LoadState reads dir/run.json and refuses unknown fields or another schema.
func LoadState(dir string) (*State, error) {
	data, err := os.ReadFile(filepath.Join(dir, "run.json"))
	if err != nil {
		return nil, err
	}
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	var s State
	if err := dec.Decode(&s); err != nil {
		return nil, fmt.Errorf("%s/run.json: %w", dir, err)
	}
	if s.Schema != StateSchema {
		return nil, fmt.Errorf("%s/run.json: schema %q, want %q", dir, s.Schema, StateSchema)
	}
	// Empty maps aren't written (omitempty), so make them again: the engine writes to all three.
	if s.Attempts == nil {
		s.Attempts = map[string]int{}
	}
	if s.Reasons == nil {
		s.Reasons = map[string]string{}
	}
	if s.Summaries == nil {
		s.Summaries = map[string]string{}
	}
	return &s, nil
}

// ErrInUse means another ygg process holds the run's lock.
var ErrInUse = errors.New("another ygg process is using this run")

// Lock takes dir/lock for this process. The kernel drops the lock when the process ends, so a
// killed run never stays locked.
func Lock(dir string) (unlock func(), err error) {
	f, err := os.OpenFile(filepath.Join(dir, "lock"), os.O_RDWR|os.O_CREATE, 0o644)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		f.Close()
		if errors.Is(err, syscall.EWOULDBLOCK) {
			return nil, ErrInUse
		}
		return nil, err
	}
	return func() { f.Close() }, nil
}

// Locked reports whether another process holds dir/lock.
func Locked(dir string) bool {
	unlock, err := Lock(dir)
	if err != nil {
		return errors.Is(err, ErrInUse)
	}
	unlock()
	return false
}
```

- [ ] **Step 4:** run the named test; expect `ok`. Land it.

---

### Task v0-T028: CI workflows (prepared by the agent)

**Files (in each of `gungnir`, `gleipnir` and `odin`):**

- Create: `.github/workflows/ci.yml`
- Modify: `.devcontainer/devcontainer.json` (the image, to the CI digest; decision 12)

**Interfaces:**

- Produces: a job named `test`, reported by GitHub Actions, which v0-T029's scripts require.

**Acceptance criteria:**

- [ ] The workflow runs `gofmt`, `go vet`, `go test -race` and `govulncheck` in the pinned image,
      with `GOWORK=off`, read-only permissions, and no persisted credentials.
- [ ] Each repo's commit is on a local branch `ci/workflow`. Nothing is pushed: the pr-bot can't push
      workflow files (decision 3).

**Named test:** run what the workflow runs, with the CI toolchain, in each repo:
`GOTOOLCHAIN=go1.26.9 GOWORK=off go test -race ./...` and
`GOTOOLCHAIN=go1.26.9 GOWORK=off go run golang.org/x/vuln/cmd/govulncheck@v1.8.0 ./...`. Both exit
0. Then the founder's run in v0-H05 shows `test` green on each PR. **Layer:** `gungnir`, `gleipnir`,
`odin`. **Size:** S (3 × 33 lines). **Depends on:** v0-T025 and v0-T027 merged; not before
2026-10-22.

- [ ] **Step 1:** check that the image is at least two weeks old:
      `curl -sS https://hub.docker.com/v2/repositories/library/golang/tags/1.26.9-bookworm | jq -r .last_updated`
      should print 2026-10-08 or earlier. If the digest moved, stop and ask the founder.
- [ ] **Step 2:** in each repo, on branch `ci/workflow`, write `.github/workflows/ci.yml`:

```yaml
# CI: the required check "test" (spec §13; plan Phase 1). It runs in the devcontainer's image, without
# go.work, so it builds this module exactly as its go.mod says. The pr-bot can't change this file (it
# has no workflows permission); the founder pushes changes to it.
name: ci
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    container:
      image: docker.io/library/golang:1.26.9-bookworm@sha256:d9c68c2c51161e12fd77e4c6320687c9cd86e1af1e3ad6e6cd63ff970641453c
    env:
      GOWORK: "off"
      GOTOOLCHAIN: local
      GOFLAGS: -mod=readonly
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: gofmt
        run: test -z "$(gofmt -l .)" || { gofmt -l .; exit 1; }
      - name: vet
        run: go vet ./...
      - name: test
        run: go test -race ./...
      - name: govulncheck
        run: go run golang.org/x/vuln/cmd/govulncheck@v1.8.0 ./...
```

- [ ] **Step 3:** set `.devcontainer/devcontainer.json`'s `image` to the same reference.
- [ ] **Step 4:** run the named test in each repo; expect exit 0, and `Your code is affected by 0
      vulnerabilities`.
- [ ] **Step 5:** commit both files on `ci/workflow` in each repo
      (`CI: the required test check (v0-T028)`). Don't push. Tell the founder the three branches are
      ready for v0-H05.

---

### Task v0-T029: the required CI check in the repo scripts

**Files (in `ouroboric`):**

- Modify: `scripts/setup-repo.sh`, `scripts/check-repos.sh`
- Create: `scripts/tests/fake-gh`, `scripts/tests/setup-repo.test.sh`,
  `scripts/tests/check-repos.test.sh`

**Interfaces:**

- Produces: `setup-repo.sh <repo>` adds a `required_status_checks` rule (context `test`,
  `integration_id` 15368 for GitHub Actions, strict) when `.github/workflows/ci.yml` exists on
  `main`. `check-repos.sh --check ruleset` then expects
  `…,required_status_checks:test@15368:strict` on the same condition (decision 13).
- Produces: `scripts/tests/fake-gh`, a fake `gh api` for script tests. It answers GETs from
  `$FAKE_GH_DIR/GET/<path, with / as _>.json` and logs other requests as JSON lines in
  `$FAKE_GH_DIR/log`.

**Acceptance criteria:**

- [ ] A repo without CI gets the same three rules as before; a repo with CI also gets the required
      check, and an existing ruleset is replaced.
- [ ] `check-repos.sh` fails a repo with CI whose check isn't required, a check another app could
      pass, and a required check with no CI to pass it.
- [ ] Read-only against GitHub, every existing repo still passes `--check ruleset`: none has CI yet.
      (Checked on 2026-10-15 for `gungnir odin gleipnir ouroboric yggdrasil`.)

**Named test:** `bash scripts/tests/setup-repo.test.sh` and `bash scripts/tests/check-repos.test.sh`
both exit 0, and `as-bot.sh --read all scripts/check-repos.sh --check ruleset` exits 0. **Layer:**
`ouroboric`. **Size:** M (about 105 lines). **Depends on:** none.

- [ ] **Step 1:** branch `setup/required-ci-check`; write `scripts/tests/fake-gh` (mode 755):

```bash
#!/usr/bin/env bash
# Fake gh for the script tests: "gh api" answers GETs from $FAKE_GH_DIR/GET/<path, / as _>.json
# (404 when the file is missing) and logs every other request as a JSON line in $FAKE_GH_DIR/log.
set -uo pipefail
[ "${1:-}" = api ] || { echo "fake gh: only 'gh api' is faked" >&2; exit 2; }
shift
method=GET path='' q='' input=''
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method="$2"; shift 2 ;;
    -q) q="$2"; shift 2 ;;
    --input) input="$2"; shift 2 ;;
    -F|-f) shift 2 ;;
    --silent|--paginate) shift ;;
    *) path="$1"; shift ;;
  esac
done
if [ "$method" != GET ]; then
  body=''; [ "$input" = - ] && body="$(cat)"
  jq -cn --arg m "$method" --arg p "$path" --arg b "$body" '{method:$m,path:$p,body:$b}' >> "$FAKE_GH_DIR/log"
  echo '{}'; exit 0
fi
f="$FAKE_GH_DIR/GET/${path//\//_}.json"
[ -f "$f" ] || { echo '{"message":"Not Found"}'; echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
if [ -n "$q" ]; then jq -r "$q" "$f"; else cat "$f"; fi
```

- [ ] **Step 2:** write `scripts/tests/setup-repo.test.sh`:

```bash
#!/usr/bin/env bash
# Tests for setup-repo.sh's ruleset against a fake gh.   scripts/tests/setup-repo.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT
fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   $d"; else echo "FAIL $d"; fail=1; fi; }
mkdir -p "$T/bin" && cp "$HERE/fake-gh" "$T/bin/gh" && chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH"
G='repos_ouroboric-dev'
# ruleset_body <repo>: the body of the last ruleset write
ruleset_body() { jq -rs "map(select(.path|test(\"repos/ouroboric-dev/$1/rulesets\")))|last|.body" "$FAKE_GH_DIR/log"; }
has_check() { jq -e '[.rules[]|select(.type=="required_status_checks")|.parameters
  |select(.strict_required_status_checks_policy==true)|.required_status_checks[]
  |select(.context=="test" and .integration_id==15368)]|length==1' >/dev/null; }
export -f ruleset_body has_check

export FAKE_GH_DIR="$T/no-ci"; mkdir -p "$FAKE_GH_DIR/GET"
echo '[]' > "$FAKE_GH_DIR/GET/${G}_alpha_rulesets.json"
GH_TOKEN=fake "$HERE/../setup-repo.sh" alpha > /dev/null
check "a repo without CI: the ruleset is created" bash -c "jq -e 'select(.method==\"POST\" and .path==\"repos/ouroboric-dev/alpha/rulesets\")' '$FAKE_GH_DIR/log' >/dev/null"
check "a repo without CI: the standard rules and no required check" bash -c "ruleset_body alpha | jq -e '[.rules[].type]|sort==[\"deletion\",\"non_fast_forward\",\"pull_request\"]' >/dev/null"

export FAKE_GH_DIR="$T/ci"; mkdir -p "$FAKE_GH_DIR/GET"
echo '[{"id":7,"name":"protect-main"}]' > "$FAKE_GH_DIR/GET/${G}_beta_rulesets.json"
echo '{"name":"ci.yml"}' > "$FAKE_GH_DIR/GET/${G}_beta_contents_.github_workflows_ci.yml.json"
GH_TOKEN=fake "$HERE/../setup-repo.sh" beta > /dev/null
check "a repo with CI: the existing ruleset is replaced" bash -c "jq -e 'select(.method==\"PUT\" and .path==\"repos/ouroboric-dev/beta/rulesets/7\")' '$FAKE_GH_DIR/log' >/dev/null"
check "a repo with CI: test from GitHub Actions is required, on an up-to-date branch" bash -c "ruleset_body beta | has_check"
check "the other rules stay" bash -c "ruleset_body beta | jq -e '[.rules[].type]|sort==[\"deletion\",\"non_fast_forward\",\"pull_request\",\"required_status_checks\"]' >/dev/null"
exit $fail
```

- [ ] **Step 3:** write `scripts/tests/check-repos.test.sh`:

```bash
#!/usr/bin/env bash
# Tests for check-repos.sh's ruleset check against a fake gh.   scripts/tests/check-repos.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT
fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok   $d"; else echo "FAIL $d"; fail=1; fi; }
mkdir -p "$T/bin" "$T/GET" && cp "$HERE/fake-gh" "$T/bin/gh" && chmod +x "$T/bin/gh"
export PATH="$T/bin:$PATH" FAKE_GH_DIR="$T"
STD='{"type":"deletion"},{"type":"non_fast_forward"},{"type":"pull_request","parameters":{"allowed_merge_methods":["squash"],"required_approving_review_count":1,"dismiss_stale_reviews_on_push":true,"require_last_push_approval":true}}'
CHECK='{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"required_status_checks":[{"context":"test","integration_id":15368}]}}'
OTHER='{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"required_status_checks":[{"context":"test","integration_id":999}]}}'
# repo <name> <has ci: yes|no> <rules json>
repo() {
  echo '[{"id":1,"name":"protect-main","enforcement":"active"}]' > "$T/GET/repos_ouroboric-dev_$1_rulesets.json"
  echo "{\"rules\":[$3]}" > "$T/GET/repos_ouroboric-dev_$1_rulesets_1.json"
  [ "$2" = yes ] && echo '{"name":"ci.yml"}' > "$T/GET/repos_ouroboric-dev_$1_contents_.github_workflows_ci.yml.json"
  return 0
}
result() { "$HERE/../check-repos.sh" --check ruleset "$1" | cut -d' ' -f1; }

repo plain no "$STD";              check "no CI, standard rules: PASS" [ "$(result plain)" = PASS ]
repo unrequired yes "$STD";        check "CI, but its check isn't required: FAIL" [ "$(result unrequired)" = FAIL ]
repo required yes "$STD,$CHECK";   check "CI, and test from GitHub Actions is required: PASS" [ "$(result required)" = PASS ]
repo spoofable yes "$STD,$OTHER";  check "CI, but another app can satisfy the check: FAIL" [ "$(result spoofable)" = FAIL ]
repo stray no "$STD,$CHECK";       check "a required check with no CI to pass it: FAIL" [ "$(result stray)" = FAIL ]
exit $fail
```

- [ ] **Step 4:** run both tests. Expect `setup-repo.test.sh` to fail its last two cases, and
      `check-repos.test.sh` its second and third. Every other case passes.
- [ ] **Step 5:** in `scripts/setup-repo.sh`, end `RULESET` after the `pull_request` rule, without
      `]}`, and add the check before the ruleset is written:

```bash
  {"type":"pull_request","parameters":{"allowed_merge_methods":["squash"],"dismiss_stale_reviews_on_push":true,"require_code_owner_review":false,"require_last_push_approval":true,"required_approving_review_count":1,"required_review_thread_resolution":false}}'
# A repo with CI requires its "test" job, reported by GitHub Actions (app 15368) so no other app can
# pass it, on a branch that is up to date with main.
if gh_api "$R/contents/.github/workflows/ci.yml" --silent >/dev/null 2>&1; then
  RULESET+=',{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"do_not_enforce_on_create":false,"required_status_checks":[{"context":"test","integration_id":15368}]}}'
fi
RULESET+=']}'
```

- [ ] **Step 6:** in `scripts/check-repos.sh`, `check_ruleset`: the `jq` filter also describes a
      `required_status_checks` rule, and the expected string grows when the repo has CI:

```bash
  rules="$(gh_api "repos/$ORG/$1/rulesets/$id" -q '[.rules[]|.type+(if .type=="pull_request" then ":"+(.parameters.allowed_merge_methods|join("+"))+":"+(.parameters.required_approving_review_count|tostring)+(if .parameters.dismiss_stale_reviews_on_push then ":stale-dismissed" else "" end)+(if .parameters.require_last_push_approval then ":last-push-approved" else "" end) elif .type=="required_status_checks" then ":"+([.parameters.required_status_checks[]|.context+"@"+(.integration_id|tostring)]|join("+"))+(if .parameters.strict_required_status_checks_policy then ":strict" else "" end) else "" end)]|sort|join(",")')"
  local want="deletion,non_fast_forward,pull_request:squash:1:stale-dismissed:last-push-approved"
  # A repo with CI must require its test job from GitHub Actions (app 15368), on an up-to-date branch.
  gh_api "repos/$ORG/$1/contents/.github/workflows/ci.yml" --silent >/dev/null 2>&1 && want+=",required_status_checks:test@15368:strict"
  [ "$rules" = "$want" ] && ok "$1" ruleset || bad "$1" ruleset "rules: $rules (run setup-repo.sh)"
```

- [ ] **Step 7:** run the named test; expect every case `ok`, and exit 0. Commit (`setup: require the
      CI check where CI exists (v0-T029)`); push with `as-bot.sh ouroboric`; open the PR.

---

### Task v0-H05 (founder): CI on, and its check required

**Acceptance criteria:**

- [ ] `ouroboric-dev`'s Actions policy allows only `actions/checkout`, pinned to a full commit SHA;
      workflow permissions are read-only by default; and Actions can't create or approve pull
      requests.
- [ ] The three `ci/workflow` PRs are merged, each with `test` green.
- [ ] `setup-repo.sh` has run on `gungnir`, `gleipnir` and `odin` after v0-T029 merged.

**Named test (agent-run):**
`as-bot.sh --read all scripts/check-repos.sh --check ruleset gungnir gleipnir odin` prints three
`PASS`, and the next bot PR in `odin` lists `test` as required:
`as-bot.sh --read all gh pr checks <n> --repo ouroboric-dev/odin --required`. **Layer:** GitHub org
and the three repos. **Size:** S. **Depends on:** v0-T028, v0-T029 merged.

- [ ] **Step 1:** in the org's settings (Actions → General), set: "Allow ouroboric-dev, and select
      non-ouroboric-dev, actions and reusable workflows", listing only
      `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1`; "Require actions to be pinned to a
      full-length commit SHA" if offered; workflow permissions "Read repository contents and packages
      permissions"; and "Allow GitHub Actions to create and approve pull requests" off.
- [ ] **Step 2:** push the three branches with your own short-lived token (fine-grained: the three
      repos; Contents, Workflows and Pull requests read and write; expiring within a day), then open
      the PRs. The `insteadOf` line overrides your global https→ssh rewrite for these pushes:

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil
read -rs -p 'token: ' T; export T
for r in gungnir gleipnir odin; do
  git -C "$r" -c credential.helper= \
    -c "credential.helper=!f() { test \"\$1\" = get && printf 'username=x-access-token\npassword=%s\n' \"\$T\"; }; f" \
    -c url.https://github.com/ouroboric-dev/.insteadOf=https://github.com/ouroboric-dev/ \
    push https://github.com/ouroboric-dev/$r.git ci/workflow
  GH_TOKEN="$T" gh pr create --repo "ouroboric-dev/$r" --head ci/workflow \
    --title "CI: the required test check (v0-T028)" --body "Phase 1, decision 3: the founder pushes CI files."
done
unset T
```

- [ ] **Step 3:** review each diff, wait for `test` to pass, and merge. You pushed the last commit,
      so the ruleset won't take your approval; merge with your admin bypass.
- [ ] **Step 4:** after v0-T029 merges, with the short-lived admin token:
      `GH_TOKEN=… scripts/setup-repo.sh gungnir`, then `gleipnir`, then `odin`. Delete the token.
- [ ] **Step 5:** ask an agent to run the named test.

---

### Task v0-T030: the mode × approval-point table

**Files (in `odin`):**

- Create: `internal/gate/decide.go`, `internal/gate/decide_test.go`

**Interfaces:**

- Produces: `gate.Action` (`Stop`, `Auto`, `Block`), `gate.Facts{Deviation, ContractInSpec bool}`,
  and `gate.Decide(mode gungnir.Mode, g gungnir.Gate, overrides map[gungnir.Gate]string, f Facts) Action`.

**Acceptance criteria:**

- [ ] The table test holds spec §7.1 row by row, for all 15 approval points and all three modes.
- [ ] A spec deviation stops; `ContractInSpec` lets `pointer-contract` pass outside step-by-step;
      overrides can't pass a hard gate; an unknown gate stops.

**Named test:** `go test ./internal/gate/`. **Layer:** `odin`. **Size:** S (116 lines). **Depends
on:** v0-T026 (the pinned `gungnir`).

- [ ] **Step 1:** write `internal/gate/decide_test.go`:

```go
package gate

import (
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

// The table of spec §7.1, one row per approval point: step-by-step, key-points, unattended.
func TestModeTimesApprovalPointTable(t *testing.T) {
	type row struct{ step, key, unattended Action }
	none := Facts{}
	table := map[gungnir.Gate]row{
		"design":           {Stop, Stop, Stop},
		"spec":             {Stop, Auto, Auto},
		"plan":             {Stop, Auto, Auto},
		"feature":          {Stop, Auto, Auto},
		"merge":            {Stop, Auto, Auto},
		"pointer":          {Stop, Auto, Auto},
		"pointer-contract": {Stop, Stop, Block},
	}
	for _, g := range gungnir.Gates() {
		want, soft := table[g]
		if !soft {
			want = row{Stop, Stop, Stop} // every hard approval point
		}
		got := row{
			Decide(gungnir.ModeStepByStep, g, nil, none),
			Decide(gungnir.ModeKeyPoints, g, nil, none),
			Decide(gungnir.ModeUnattended, g, nil, none),
		}
		if got != want {
			t.Errorf("%s: got %v, want %v", g, got, want)
		}
	}
	if len(table)+8 != len(gungnir.Gates()) {
		t.Errorf("the table covers %d soft gates; gungnir knows %d gates", len(table), len(gungnir.Gates()))
	}
}

func TestDecideFactsAndOverrides(t *testing.T) {
	cases := []struct {
		name string
		mode gungnir.Mode
		gate gungnir.Gate
		over map[gungnir.Gate]string
		f    Facts
		want Action
	}{
		{"a spec deviation stops in key-points", gungnir.ModeKeyPoints, "spec", nil, Facts{Deviation: true}, Stop},
		{"a spec deviation stops in unattended", gungnir.ModeUnattended, "spec", nil, Facts{Deviation: true}, Stop},
		{"spec: stop stops in key-points", gungnir.ModeKeyPoints, "spec", map[gungnir.Gate]string{"spec": "stop"}, Facts{}, Stop},
		{"plan: stop stops in unattended", gungnir.ModeUnattended, "plan", map[gungnir.Gate]string{"plan": "stop"}, Facts{}, Stop},
		{"design: auto passes in unattended", gungnir.ModeUnattended, "design", map[gungnir.Gate]string{"design": "auto"}, Facts{}, Auto},
		{"design: auto still stops in key-points", gungnir.ModeKeyPoints, "design", map[gungnir.Gate]string{"design": "auto"}, Facts{}, Stop},
		{"an approved contract change passes in key-points", gungnir.ModeKeyPoints, "pointer-contract", nil, Facts{ContractInSpec: true}, Auto},
		{"an approved contract change stops in step-by-step", gungnir.ModeStepByStep, "pointer-contract", nil, Facts{ContractInSpec: true}, Stop},
		{"an override can't pass a hard gate", gungnir.ModeUnattended, "budget-cap", map[gungnir.Gate]string{"budget-cap": "auto"}, Facts{}, Stop},
		{"an unknown gate stops", gungnir.ModeUnattended, "ship-it", nil, Facts{}, Stop},
	}
	for _, c := range cases {
		if got := Decide(c.mode, c.gate, c.over, c.f); got != c.want {
			t.Errorf("%s: Decide() = %s, want %s", c.name, got, c.want)
		}
	}
}
```

- [ ] **Step 2:** run the named test; expect a build failure: `undefined: Decide`.
- [ ] **Step 3:** write `internal/gate/decide.go`:

```go
// Package gate decides what Odin does at an approval point (spec §7).
package gate

import "github.com/ouroboric-dev/gungnir"

// Action is what Odin does at an approval point.
type Action string

const (
	Stop  Action = "stop"  // write the gate file, log gate_pending, save state and exit
	Auto  Action = "auto"  // write the gate file, log gate_auto_passed and continue
	Block Action = "block" // unattended pointer-contract: block the task and continue with the rest
)

// Facts are what the run learned that the table depends on.
type Facts struct {
	Deviation      bool // spec: the design-conformance review found a deviation
	ContractInSpec bool // pointer-contract: the approved spec contains the contract change
}

// Decide applies the mode × approval-point table of spec §7.1, then the config's overrides.
// Overrides are checked by schema.Factory.CheckGates before a run starts or continues. An unknown
// approval point stops, so a typo never passes silently.
func Decide(mode gungnir.Mode, g gungnir.Gate, overrides map[gungnir.Gate]string, f Facts) Action {
	if !g.Known() || g.Hard() || mode == gungnir.ModeStepByStep || overrides[g] == "stop" {
		return Stop
	}
	switch g {
	case gungnir.GateDesign:
		if mode == gungnir.ModeUnattended && overrides[g] == "auto" {
			return Auto
		}
		return Stop
	case gungnir.GateSpec:
		if f.Deviation {
			return Stop
		}
		return Auto
	case gungnir.GatePointerContract:
		if f.ContractInSpec {
			return Auto
		}
		if mode == gungnir.ModeUnattended {
			return Block
		}
		return Stop
	default: // plan, feature, merge, pointer
		return Auto
	}
}
```

- [ ] **Step 4:** run the named test; expect `ok`. Land it.

---

### Task v0-T031: starting a run

The run starts only with complete caps. This is the `odin` half of `require-budget-caps-T001`, for
`ygg run`. It also adds the toy realm the remaining tasks use.

**Files (in `odin`):**

- Create: `internal/run/run.go`, `internal/run/caps_test.go`, `internal/agents/agents.go`,
  `testdata/toy/pack.yaml`, `testdata/toy/graph.yaml`, `testdata/toy/script.yaml`,
  `testdata/toy/script-hang.yaml`, and `testdata/toy/prompts/{design,spec,plan,build}.md`, each
  holding one line, `Write <name>.`
- Modify: `go.mod`, `go.sum` (pin `gungnir` with v0-T023 merged, and `gleipnir`)

**Interfaces:**

- Consumes: `schema.ParseFactory`, `CheckGates`, `LoadPack`, `ParseGraph`; `scripted.Load`;
  `ledger.Open`; `run.State`, `Lock`, `NewIDNow`.
- Produces: `run.Options{Project, Config, Realm, Brief string; Mode gungnir.Mode}`, `run.Setup`,
  `run.Prepare(Options) (*Setup, error)`, `run.Start(Options) (*Run, error)`, and `run.Run` with
  `Workspace()`, `Log(gungnir.Event) error`, `Save() error` and `Close() error`. Also
  `agents.New(role schema.Role, configDir string) (gungnir.Agent, error)`, which knows only
  `scripted` in Phase 1.

**Acceptance criteria:**

- [ ] `Start` with no caps, with a per-run cap but no per-day cap, or with a paid-API role and no
      spend limit returns a `*schema.CapsError` naming the fields, and creates nothing.
- [ ] With complete caps, `Start` creates `.factory/runs/<id>/` with `run.json` (status `running`,
      mode `key-points`) and one ledger line, `run_started`.

**Named test:** `go test ./internal/run/ -run TestRunRefusesWithoutCompleteCaps` (the change's named
test). **Layer:** `odin`. **Size:** M (357 lines). **Depends on:** v0-T023 and v0-T025 merged;
v0-T027, v0-T030.

- [ ] **Step 1:** pin `gungnir` and `gleipnir`. Write the toy realm. `testdata/toy/pack.yaml`:

```yaml
name: toy
version: 0.1.0
graph: graph.yaml
```

`testdata/toy/graph.yaml`:

```yaml
# The toy graph: every node kind and four approval points, with a scripted agent (spec §13).
name: toy
version: 1.0.0
nodes:
  - { id: design, kind: agent, role: planner, prompt: prompts/design.md }
  - { id: design-gate, kind: gate, gate: design }
  - { id: spec, kind: agent, role: planner, prompt: prompts/spec.md }
  - { id: spec-gate, kind: gate, gate: spec }
  - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md }
  - { id: dor, kind: exec, run: [test, -s, plan.md] }
  - { id: plan-gate, kind: gate, gate: plan, reruns: plan }
  - { id: build, kind: agent, role: implementer, prompt: prompts/build.md }
  - { id: check, kind: exec, run: [grep, -q, done, build.txt] }
  - { id: feature-gate, kind: gate, gate: feature }
```

`testdata/toy/script.yaml`:

```yaml
# The scripted agent's answers for the toy graph. spec has a second attempt for a rejection.
steps:
  design:
    - actions: [ { write: { path: design.md, content: "# Design\n" } } ]
      result: { status: ok, summary: wrote design.md, usage: { in: 1000, out: 100, turns: 2 } }
  spec:
    - actions: [ { write: { path: spec.md, content: "# Spec\n" } } ]
      result: { status: ok, summary: wrote spec.md, usage: { in: 1000, out: 100, turns: 2 } }
    - actions: [ { write: { path: spec.md, content: "# Spec\n\nUsers: photographers and their clients.\n" } } ]
      result: { status: ok, summary: named the users in spec.md, usage: { in: 1000, out: 100, turns: 2 } }
  plan:
    - actions: [ { write: { path: plan.md, content: "# Plan\n" } } ]
      result: { status: ok, summary: wrote plan.md, usage: { in: 1000, out: 100, turns: 2 } }
  build:
    - actions: [ { write: { path: build.txt, content: "done\n" } } ]
      result: { status: ok, summary: built it, usage: { in: 2000, out: 400, cache: 1500, turns: 5 } }
```

`testdata/toy/script-hang.yaml`:

```yaml
# As script.yaml, but build's first attempt hangs until the process is killed.
steps:
  design:
    - actions: [ { write: { path: design.md, content: "# Design\n" } } ]
      result: { status: ok, summary: wrote design.md, usage: { in: 1000, out: 100, turns: 2 } }
  spec:
    - actions: [ { write: { path: spec.md, content: "# Spec\n" } } ]
      result: { status: ok, summary: wrote spec.md, usage: { in: 1000, out: 100, turns: 2 } }
  plan:
    - actions: [ { write: { path: plan.md, content: "# Plan\n" } } ]
      result: { status: ok, summary: wrote plan.md, usage: { in: 1000, out: 100, turns: 2 } }
  build:
    - hang: true
    - actions: [ { write: { path: build.txt, content: "done\n" } } ]
      result: { status: ok, summary: built it, usage: { in: 2000, out: 400, turns: 5 } }
```

- [ ] **Step 2:** write `internal/run/caps_test.go`:

```go
package run

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

const (
	scriptedRoles = "roles:\n  planner: { agent: scripted, model: none, script: SCRIPT }\n  implementer: { agent: scripted, model: none, script: SCRIPT }\n"
	paidRoles     = "roles:\n  planner: { agent: opencode, model: openrouter/qwen }\n  implementer: { agent: scripted, model: none, script: SCRIPT }\n"
	fullCaps      = "budget:\n  per_run: { tokens: 100000, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\n"
)

func toy(t *testing.T) string {
	t.Helper()
	p, err := filepath.Abs("../../testdata/toy")
	if err != nil {
		t.Fatal(err)
	}
	return p
}

// writeConfig writes factory.yaml into a temporary directory, with SCRIPT replaced by the toy script.
func writeConfig(t *testing.T, dir, body string) string {
	t.Helper()
	p := filepath.Join(dir, "factory.yaml")
	body = strings.ReplaceAll(body, "SCRIPT", filepath.Join(toy(t), "script.yaml"))
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestRunRefusesWithoutCompleteCaps(t *testing.T) {
	cases := []struct {
		name, config string
		missing      []string
	}{
		{"no caps", scriptedRoles, []string{"budget.per_run", "budget.per_day"}},
		{"a per-run cap but no per-day cap", scriptedRoles + "budget:\n  per_run: { tokens: 100000, turns: 100 }\n", []string{"budget.per_day"}},
		{"a paid-API role and no spend limit", paidRoles + fullCaps, []string{"budget.per_run.usd", "budget.per_day.usd"}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			project := t.TempDir()
			_, err := Start(Options{Project: project, Config: writeConfig(t, t.TempDir(), c.config), Realm: toy(t)})
			var ce *schema.CapsError
			if !errors.As(err, &ce) {
				t.Fatalf("Start() error = %v, want a *schema.CapsError", err)
			}
			for _, m := range c.missing {
				if !strings.Contains(err.Error(), m) {
					t.Errorf("the error doesn't name %s:\n%s", m, err)
				}
			}
			if _, err := os.Stat(filepath.Join(project, ".factory")); !errors.Is(err, fs.ErrNotExist) {
				t.Error("Start() refused, but created .factory/")
			}
		})
	}
	t.Run("complete caps start a run", func(t *testing.T) {
		project := t.TempDir()
		r, err := Start(Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
		if err != nil {
			t.Fatalf("Start() = %v", err)
		}
		defer r.Close()
		s, err := LoadState(r.Dir)
		if err != nil || s.Status != StatusRunning || s.Mode != gungnir.ModeKeyPoints || s.Ledger.Seq != 1 {
			t.Errorf("run.json = %+v, %v", s, err)
		}
	})
}
```

- [ ] **Step 3:** run the named test; expect a build failure: `undefined: Start`.
- [ ] **Step 4:** write `internal/agents/agents.go`:

```go
// Package agents builds the agent adapter a role names.
package agents

import (
	"fmt"
	"path/filepath"

	"github.com/ouroboric-dev/gleipnir/scripted"
	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

// New returns the adapter for role. A scripted role's script path is relative to configDir.
// Phase 3 adds claude-code and opencode; until then a role that names them can't start.
func New(role schema.Role, configDir string) (gungnir.Agent, error) {
	switch role.Agent {
	case "scripted":
		p := role.Script
		if !filepath.IsAbs(p) {
			p = filepath.Join(configDir, p)
		}
		return scripted.Load(p)
	default:
		return nil, fmt.Errorf("agent %q isn't in this build of ygg yet", role.Agent)
	}
}
```

- [ ] **Step 5:** write `internal/run/run.go`:

```go
package run

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/agents"
	"github.com/ouroboric-dev/odin/internal/ledger"
)

// Options say what to run.
type Options struct {
	Project string       // the directory that holds .factory/ and workspace/
	Config  string       // factory.yaml
	Realm   string       // the directory that holds pack.yaml
	Brief   string       // optional
	Mode    gungnir.Mode // "" means the config's mode
}

// Setup is everything a run needs, loaded and checked.
type Setup struct {
	Config       *schema.Factory
	ConfigPath   string // absolute
	ConfigSHA256 string
	Pack         *schema.Pack
	RealmDir     string // absolute
	Graph        *schema.Graph
	GraphSHA256  string
	Brief        string // absolute, or ""
	BriefText    string
	BriefSHA256  string
	Mode         gungnir.Mode
	Agents       map[string]gungnir.Agent // role: adapter, for every role the graph uses
}

// Prepare loads and checks the config, the realm and the brief, and builds the agents. It writes
// nothing. Incomplete caps give a *schema.CapsError (change require-budget-caps).
func Prepare(o Options) (*Setup, error) {
	s := &Setup{Agents: map[string]gungnir.Agent{}}
	var err error
	if s.ConfigPath, err = filepath.Abs(o.Config); err != nil {
		return nil, err
	}
	cfgData, err := os.ReadFile(s.ConfigPath)
	if err != nil {
		return nil, err
	}
	if s.Config, err = schema.ParseFactory(s.ConfigPath, cfgData); err != nil {
		return nil, err
	}
	s.ConfigSHA256 = sum(cfgData)
	s.Mode = s.Config.Mode
	if o.Mode != "" {
		s.Mode = o.Mode
	}
	if err := s.Config.CheckGates(s.Mode); err != nil {
		return nil, fmt.Errorf("%s: %w", s.ConfigPath, err)
	}
	if s.RealmDir, err = filepath.Abs(o.Realm); err != nil {
		return nil, err
	}
	if s.Pack, err = schema.LoadPack(s.RealmDir); err != nil {
		return nil, err
	}
	graphPath := filepath.Join(s.RealmDir, s.Pack.Graph)
	graphData, err := os.ReadFile(graphPath)
	if err != nil {
		return nil, err
	}
	if s.Graph, err = schema.ParseGraph(graphPath, graphData); err != nil {
		return nil, err
	}
	s.GraphSHA256 = sum(graphData)
	for _, n := range s.Graph.Nodes {
		if n.Kind != schema.KindAgent {
			continue
		}
		if _, err := os.Stat(filepath.Join(s.RealmDir, n.Prompt)); err != nil {
			return nil, fmt.Errorf("%s: node %s: %w", graphPath, n.ID, err)
		}
		if s.Agents[n.Role] != nil {
			continue
		}
		role, ok := s.Config.Roles[n.Role]
		if !ok {
			return nil, fmt.Errorf("%s: node %s uses role %s, which %s doesn't define", graphPath, n.ID, n.Role, s.ConfigPath)
		}
		if s.Agents[n.Role], err = agents.New(role, filepath.Dir(s.ConfigPath)); err != nil {
			return nil, fmt.Errorf("role %s: %w", n.Role, err)
		}
	}
	if o.Brief != "" {
		if s.Brief, err = filepath.Abs(o.Brief); err != nil {
			return nil, err
		}
		b, err := os.ReadFile(s.Brief)
		if err != nil {
			return nil, err
		}
		s.BriefText, s.BriefSHA256 = string(b), sum(b)
	}
	return s, nil
}

// Run is an open run: its directory, state, setup, ledger and lock.
type Run struct {
	Project string
	Dir     string
	State   *State
	Setup   *Setup
	Ledger  *ledger.Ledger
	unlock  func()
}

// Workspace is the directory agents and exec nodes work in. Phase 2 replaces it with the leaf.
func (r *Run) Workspace() string { return filepath.Join(r.Project, "workspace") }

// Log appends e to the ledger, with the run's id.
func (r *Run) Log(e gungnir.Event) error {
	e.Run = r.State.ID
	return r.Ledger.Append(e)
}

// Save records the ledger's head in run.json and writes it.
func (r *Run) Save() error {
	r.State.Ledger = r.Ledger.Head()
	r.State.Updated = time.Now().UTC()
	return r.State.Save(r.Dir)
}

// Close closes the ledger and releases the lock.
func (r *Run) Close() error {
	err := r.Ledger.Close()
	r.unlock()
	return err
}

// Start prepares a new run, then creates its directory, run.json and first ledger line. If
// Prepare refuses, nothing is created.
func Start(o Options) (*Run, error) {
	setup, err := Prepare(o)
	if err != nil {
		return nil, err
	}
	project, err := filepath.Abs(o.Project)
	if err != nil {
		return nil, err
	}
	id, err := NewIDNow()
	if err != nil {
		return nil, err
	}
	dir := Dir(project, id)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Join(project, "workspace"), 0o755); err != nil {
		return nil, err
	}
	unlock, err := Lock(dir)
	if err != nil {
		return nil, err
	}
	l, err := ledger.Open(filepath.Join(dir, "ledger.jsonl"), ledger.Anchor{})
	if err != nil {
		unlock()
		return nil, err
	}
	now := time.Now().UTC()
	roles := map[string]RoleRecord{}
	for name := range setup.Agents {
		roles[name] = RoleRecord{Agent: setup.Config.Roles[name].Agent, Model: setup.Config.Roles[name].Model}
	}
	r := &Run{Project: project, Dir: dir, Setup: setup, Ledger: l, unlock: unlock, State: &State{
		ID: id, Status: StatusRunning, Mode: setup.Mode,
		Realm: setup.Pack.Name, RealmVersion: setup.Pack.Version, RealmDir: setup.RealmDir,
		GraphVersion: setup.Graph.Version, GraphSHA256: setup.GraphSHA256,
		ConfigPath: setup.ConfigPath, ConfigSHA256: setup.ConfigSHA256,
		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles,
		Attempts: map[string]int{}, Reasons: map[string]string{}, Summaries: map[string]string{},
		Created: now, Updated: now,
	}}
	if err := r.Log(gungnir.Event{Name: gungnir.EventRunStarted, Mode: setup.Mode, ConfigHash: setup.ConfigSHA256}); err != nil {
		r.Close()
		return nil, err
	}
	return r, r.Save()
}

func sum(b []byte) string {
	s := sha256.Sum256(b)
	return hex.EncodeToString(s[:])
}
```

- [ ] **Step 6:** run the named test; expect `ok`. Land it.

---

### Task v0-T032: opening a run again

What `resume`, `approve` and `reject` open. It refuses whatever would mislead the run. This is the
`resume` part of `require-budget-caps-T001`.

**Files (in `odin`):**

- Modify: `internal/run/run.go`, `internal/run/caps_test.go`
- Create: `internal/run/open_test.go`

**Interfaces:**

- Produces: `run.Open(project, id string, mode gungnir.Mode) (*Run, error)`. It returns `ErrInUse`, a
  `*schema.CapsError`, or an error that says why. It logs `config_changed` when `factory.yaml`
  changed, and `mode_changed` (with `ygg.mode.looser`) when `mode` switches it.

**Acceptance criteria:**

- [ ] Resume refuses without complete caps, as run does.
- [ ] `Open` refuses a run another process holds, a changed graph, a changed brief, a path as the run
      id, and a ledger that doesn't reach run.json's anchor (review focus 1, 3 and 5).
- [ ] A switch to a looser mode is logged.

**Named test:** `go test ./internal/run/ -run 'TestRunRefusesWithoutCompleteCaps|TestOpenRefuses'`.
**Layer:** `odin`. **Size:** M (154 lines). **Depends on:** v0-T031.

- [ ] **Step 1:** in `internal/run/caps_test.go`, add this subtest to
      `TestRunRefusesWithoutCompleteCaps`, before "complete caps start a run":

```go
	t.Run("resume refuses in the same cases", func(t *testing.T) {
		project, cfgDir := t.TempDir(), t.TempDir()
		r, err := Start(Options{Project: project, Config: writeConfig(t, cfgDir, scriptedRoles+fullCaps), Realm: toy(t)})
		if err != nil {
			t.Fatal(err)
		}
		id := r.State.ID
		r.Close()
		writeConfig(t, cfgDir, scriptedRoles+"budget:\n  per_run: { tokens: 100000, turns: 100 }\n")
		_, err = Open(project, id, "")
		var ce *schema.CapsError
		if !errors.As(err, &ce) || !strings.Contains(err.Error(), "budget.per_day") {
			t.Errorf("Open() error = %v, want a *schema.CapsError naming budget.per_day", err)
		}
	})
```

- [ ] **Step 2:** write `internal/run/open_test.go`:

```go
package run

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func TestOpenRefusesWhatWouldMisleadARun(t *testing.T) {
	start := func(t *testing.T) (project, id, realm string) {
		project, realm = t.TempDir(), t.TempDir()
		if err := os.CopyFS(realm, os.DirFS(toy(t))); err != nil {
			t.Fatal(err)
		}
		r, err := Start(Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: realm})
		if err != nil {
			t.Fatal(err)
		}
		r.Close()
		return project, r.State.ID, realm
	}
	t.Run("a run another process holds", func(t *testing.T) {
		project, id, _ := start(t)
		r, err := Open(project, id, "")
		if err != nil {
			t.Fatal(err)
		}
		defer r.Close()
		if _, err := Open(project, id, ""); !errors.Is(err, ErrInUse) {
			t.Errorf("a second Open() = %v, want ErrInUse", err)
		}
	})
	t.Run("a graph edited after the run started", func(t *testing.T) {
		project, id, realm := start(t)
		g := filepath.Join(realm, "graph.yaml")
		b, _ := os.ReadFile(g)
		os.WriteFile(g, []byte(strings.Replace(string(b), "  - { id: dor,", "  - { id: lint, kind: exec, run: [echo] }\n  - { id: dor,", 1)), 0o644)
		if _, err := Open(project, id, ""); err == nil || !strings.Contains(err.Error(), "graph changed") {
			t.Errorf("Open() = %v, want a refusal because the graph changed", err)
		}
	})
	t.Run("a path as the run id", func(t *testing.T) {
		project, _, _ := start(t)
		if _, err := Open(project, "../../../tmp", ""); err == nil || !strings.Contains(err.Error(), "not a run id") {
			t.Errorf("Open() = %v, want not a run id", err)
		}
	})
	t.Run("a ledger cut short", func(t *testing.T) {
		project, id, _ := start(t)
		os.WriteFile(filepath.Join(Dir(project, id), "ledger.jsonl"), nil, 0o644)
		if _, err := Open(project, id, ""); err == nil || !strings.Contains(err.Error(), "lines were removed") {
			t.Errorf("Open() = %v, want lines were removed", err)
		}
	})
	t.Run("a looser mode is logged", func(t *testing.T) {
		project, id, _ := start(t)
		r, err := Open(project, id, gungnir.ModeUnattended)
		if err != nil {
			t.Fatal(err)
		}
		r.Close()
		b, _ := os.ReadFile(filepath.Join(Dir(project, id), "ledger.jsonl"))
		if !strings.Contains(string(b), `"event":"mode_changed"`) || !strings.Contains(string(b), `"ygg.mode.looser":true`) {
			t.Errorf("the ledger doesn't log the looser mode:\n%s", b)
		}
	})
}
```

- [ ] **Step 3:** run the named test; expect a build failure: `undefined: Open`.
- [ ] **Step 4:** in `internal/run/run.go`, add `"errors"` to the imports, and add before `func sum`:

```go
// Open locks and loads run id for resume, approve or reject, and checks that it may continue: the
// caps are still complete, the graph and brief are unchanged, and the ledger reaches the anchor in
// run.json. mode switches the run's mode at this pause ("" keeps it); a switch is logged.
func Open(project, id string, mode gungnir.Mode) (*Run, error) {
	if !ValidID(id) {
		return nil, fmt.Errorf("%q is not a run id", id)
	}
	project, err := filepath.Abs(project)
	if err != nil {
		return nil, err
	}
	dir := Dir(project, id)
	if _, err := os.Stat(filepath.Join(dir, "run.json")); err != nil {
		return nil, fmt.Errorf("no run %s in %s", id, project)
	}
	unlock, err := Lock(dir)
	if err != nil {
		return nil, err
	}
	r, err := open(project, dir, mode)
	if err != nil {
		unlock()
		return nil, err
	}
	r.unlock = unlock
	return r, nil
}

func open(project, dir string, mode gungnir.Mode) (*Run, error) {
	s, err := LoadState(dir)
	if err != nil {
		return nil, err
	}
	if mode == "" {
		mode = s.Mode
	}
	setup, err := Prepare(Options{Project: project, Config: s.ConfigPath, Realm: s.RealmDir, Brief: s.Brief, Mode: mode})
	if err != nil {
		return nil, err
	}
	if setup.GraphSHA256 != s.GraphSHA256 {
		return nil, errors.New("the realm's graph changed since the run started, so its positions no longer hold; start a new run")
	}
	if setup.BriefSHA256 != s.BriefSHA256 {
		return nil, errors.New("the brief changed since the run started; a brief is frozen, so start a new run")
	}
	l, err := ledger.Open(filepath.Join(dir, "ledger.jsonl"), s.Ledger)
	if err != nil {
		return nil, err
	}
	r := &Run{Project: project, Dir: dir, State: s, Setup: setup, Ledger: l, unlock: func() {}}
	if setup.ConfigSHA256 != s.ConfigSHA256 {
		s.ConfigSHA256 = setup.ConfigSHA256
		if err := r.Log(gungnir.Event{Name: gungnir.EventConfigChanged, ConfigHash: setup.ConfigSHA256}); err != nil {
			l.Close()
			return nil, err
		}
	}
	if mode != s.Mode {
		looser := mode.Looser(s.Mode)
		s.Mode = mode
		if err := r.Log(gungnir.Event{Name: gungnir.EventModeChanged, Mode: mode, Looser: looser}); err != nil {
			l.Close()
			return nil, err
		}
	}
	return r, r.Save()
}
```

- [ ] **Step 5:** run the named test; expect `ok`. Land it.

---

### Task v0-T033: the engine, exec and agent nodes

**Files (in `odin`):**

- Create: `internal/engine/engine.go`, `internal/engine/engine_test.go`, `internal/engine/gates.go`
  (a stop-only placeholder that v0-T034 replaces)

**Interfaces:**

- Consumes: `run.Run`, `run.Status`; `gungnir.Event`, `Task`, `Result`; `schema.Node`.
- Produces: `engine.Outcome{Status run.Status; Gate string; Err error}`,
  `engine.Advance(ctx, *run.Run) (Outcome, error)`, `engine.ExecTimeout` (10 minutes), and the
  unexported `startAttempt` and `nodeFailure`, which v0-T034 uses.

**Acceptance criteria:**

- [ ] Nodes run in order. Usage adds up in run.json. The ledger has `node_started` and
      `node_finished` with the `gen_ai.*` usage, then `run_finished`.
- [ ] A failed node stops the run as `failed`, and the next `Advance` re-runs it as attempt 2.
- [ ] A malformed result is a failure, and its usage isn't counted (spec §4.6).
- [ ] An exec node sees only `PATH`, `HOME` and `LANG` (review focus 2). A timeout kills its whole
      process group.
- [ ] An interrupted agent's attempt counts, and the ledger says why it ended.

**Named test:** `go test -race ./internal/engine/`. **Layer:** `odin`. **Size:** M (383 lines).
**Depends on:** v0-T032.

- [ ] **Step 1:** write `internal/engine/engine_test.go`:

```go
package engine

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/odin/internal/ledger"
	"github.com/ouroboric-dev/odin/internal/run"
)

// start makes a realm with the given nodes and a prompt file, a script and a factory.yaml, and
// starts a run on them in a fresh project.
func start(t *testing.T, mode, gates, nodes, script string) *run.Run {
	t.Helper()
	realm, cfg, project := t.TempDir(), t.TempDir(), t.TempDir()
	files := map[string]string{
		filepath.Join(realm, "pack.yaml"):  "name: test\nversion: 0.1.0\ngraph: graph.yaml\n",
		filepath.Join(realm, "graph.yaml"): "name: test\nversion: 1.0.0\nnodes:\n" + nodes,
		filepath.Join(realm, "p.md"):       "Do the work.\n",
		filepath.Join(cfg, "script.yaml"):  script,
		filepath.Join(cfg, "factory.yaml"): "mode: " + mode + "\n" + gates +
			"roles:\n  planner: { agent: scripted, model: none, script: script.yaml }\n" +
			"budget:\n  per_run: { tokens: 100000, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\n",
	}
	for p, body := range files {
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	r, err := run.Start(run.Options{Project: project, Config: filepath.Join(cfg, "factory.yaml"), Realm: realm})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { r.Close() })
	return r
}

func ledgerText(t *testing.T, r *run.Run) string {
	t.Helper()
	if _, err := ledger.Verify(filepath.Join(r.Dir, "ledger.jsonl"), r.Ledger.Head()); err != nil {
		t.Fatalf("the ledger doesn't verify: %v", err)
	}
	b, _ := os.ReadFile(filepath.Join(r.Dir, "ledger.jsonl"))
	return string(b)
}

const okScript = `steps:
  a:
    - actions: [ { write: { path: out.txt, content: "done\n" } } ]
      result: { status: ok, summary: wrote out.txt, usage: { in: 100, out: 10, cache: 5, turns: 2, cost_usd: 0.5 } }
`

func TestAgentAndExecNodesRunInOrder(t *testing.T) {
	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md }\n  - { id: check, kind: exec, run: [grep, -q, done, out.txt] }\n", okScript)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v; want done", out, err)
	}
	s, _ := run.LoadState(r.Dir)
	if s.Status != run.StatusDone || s.Position != 2 || s.Usage.InTok != 100 || s.Usage.CostUSD != 0.5 {
		t.Errorf("run.json = %+v", s)
	}
	text := ledgerText(t, r)
	for _, want := range []string{`"event":"node_finished","ygg.attempt":1,"gen_ai.agent.name":"planner"`,
		`"gen_ai.usage.input_tokens":100`, `"event":"run_finished"`} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s:\n%s", want, text)
		}
	}
}

func TestAFailedNodeStopsTheRunAndResumeRerunsIt(t *testing.T) {
	script := "steps:\n  a:\n    - result: { status: failed, summary: tests fail }\n    - result: { status: ok, summary: fixed }\n"
	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md }\n", script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "tests fail") {
		t.Fatalf("Advance() = %+v, %v; want failed with the agent's summary", out, err)
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("the second Advance() = %+v, %v; want done", out, err)
	}
	if r.State.Attempts["a"] != 2 {
		t.Errorf("attempts = %d, want 2", r.State.Attempts["a"])
	}
}

func TestAMalformedAgentResultIsAFailureNotAPass(t *testing.T) {
	script := "steps:\n  a:\n    - result: { status: ok, usage: { turns: -1 } }\n"
	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md }\n", script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed {
		t.Errorf("Advance() = %+v, %v; want failed", out, err)
	}
}

func TestExecGetsNoCredentialsFromTheOperator(t *testing.T) {
	t.Setenv("CLAUDE_CODE_OAUTH_TOKEN", "operator-token")
	t.Setenv("ANTHROPIC_API_KEY", "operator-key")
	r := start(t, "key-points", "", "  - { id: env, kind: exec, run: [sh, -c, \"env > env.txt\"] }\n", "steps: {}\n")
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	b, err := os.ReadFile(filepath.Join(r.Workspace(), "env.txt"))
	if err != nil {
		t.Fatal(err)
	}
	for _, line := range strings.Split(strings.TrimSpace(string(b)), "\n") {
		name, _, _ := strings.Cut(line, "=")
		switch name {
		case "PATH", "HOME", "LANG", "PWD", "SHLVL", "_": // the last three are set by sh itself
		default:
			t.Errorf("the exec node saw %s", name)
		}
	}
}

func TestAnExecTimeoutKillsTheProcessGroup(t *testing.T) {
	r := start(t, "key-points", "",
		"  - { id: slow, kind: exec, run: [sh, -c, \"sleep 30 & echo $! > child.pid; wait\"], timeout: 300ms }\n", "steps: {}\n")
	began := time.Now()
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed {
		t.Fatalf("Advance() = %+v, %v; want failed", out, err)
	}
	if time.Since(began) > 10*time.Second {
		t.Errorf("Advance() took %v; the timeout didn't stop it", time.Since(began))
	}
	pid, _ := os.ReadFile(filepath.Join(r.Workspace(), "child.pid"))
	if _, err := os.Stat("/proc/" + strings.TrimSpace(string(pid))); err == nil {
		t.Errorf("the child %s outlived the timeout", strings.TrimSpace(string(pid)))
	}
}

func TestAnInterruptedAgentCountsItsAttempt(t *testing.T) {
	script := "steps:\n  a:\n    - hang: true\n    - result: { status: ok, summary: done }\n"
	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md }\n", script)
	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()
	if out, err := Advance(ctx, r); err != nil || out.Status != run.StatusFailed {
		t.Fatalf("Advance() = %+v, %v; want failed after the interrupt", out, err)
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("resume = %+v, %v; want done", out, err)
	}
	if r.State.Attempts["a"] != 2 {
		t.Errorf("attempts = %d, want 2", r.State.Attempts["a"])
	}
	if !strings.Contains(ledgerText(t, r), "context deadline exceeded") {
		t.Error("the ledger doesn't record why attempt 1 failed")
	}
}
```

- [ ] **Step 2:** run the named test; expect a build failure: `undefined: Advance`.
- [ ] **Step 3:** write `internal/engine/gates.go`, the placeholder:

```go
package engine

import (
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
)

// reachGate stops at every gate node. v0-T034 replaces this file with the approval-point table,
// gate files, Approve and Reject.
func reachGate(r *run.Run, n schema.Node) (bool, error) {
	r.State.Status, r.State.Pending = run.StatusStopped, n.ID
	return true, r.Save()
}
```

- [ ] **Step 4:** write `internal/engine/engine.go`:

```go
// Package engine walks a run's graph (spec §4): it runs exec and agent nodes, and stops or passes
// at gate nodes.
package engine

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
)

// ExecTimeout is an exec node's limit when the graph sets none.
const ExecTimeout = 10 * time.Minute

// Outcome is where Advance left the run.
type Outcome struct {
	Status run.Status // done, stopped or failed
	Gate   string     // stopped: the gate node waiting for a decision
	Err    error      // failed: why
}

// Advance runs nodes from the run's position until the graph ends, an approval point stops the
// run, or a node fails. It saves run.json after every node. Every node is safe to re-run: resume
// starts the interrupted node again from scratch (spec §4.3). The returned error is for failures
// of Odin itself (disk, ledger); a failing node is an Outcome.
func Advance(ctx context.Context, r *run.Run) (Outcome, error) {
	s := r.State
	if s.Pending != "" {
		return Outcome{Status: run.StatusStopped, Gate: s.Pending}, nil
	}
	s.Status, s.Error = run.StatusRunning, ""
	if err := r.Save(); err != nil {
		return Outcome{}, err
	}
	nodes := r.Setup.Graph.Nodes
	for s.Position < len(nodes) {
		n := nodes[s.Position]
		var stop bool
		var err error
		switch n.Kind {
		case schema.KindAgent:
			err = runAgent(ctx, r, n)
		case schema.KindExec:
			err = runExec(ctx, r, n)
		case schema.KindGate:
			stop, err = reachGate(r, n)
		}
		var nf *nodeFailure
		if errors.As(err, &nf) {
			return fail(r, n, nf.err)
		}
		if err != nil {
			return Outcome{}, err
		}
		if stop {
			return Outcome{Status: run.StatusStopped, Gate: n.ID}, nil
		}
		s.Position++
		if err := r.Save(); err != nil {
			return Outcome{}, err
		}
	}
	s.Status = run.StatusDone
	if err := r.Log(gungnir.Event{Name: gungnir.EventRunFinished, Result: "done"}.WithUsage(s.Usage)); err != nil {
		return Outcome{}, err
	}
	return Outcome{Status: run.StatusDone}, r.Save()
}

// nodeFailure is a node that failed; the run stops failed, and resume re-runs the node.
type nodeFailure struct{ err error }

func (f *nodeFailure) Error() string { return f.err.Error() }

func fail(r *run.Run, n schema.Node, cause error) (Outcome, error) {
	r.State.Status, r.State.Error = run.StatusFailed, fmt.Sprintf("node %s: %v", n.ID, cause)
	if err := r.Log(gungnir.Event{Name: gungnir.EventRunFailed, Node: n.ID, Result: r.State.Error}); err != nil {
		return Outcome{}, err
	}
	return Outcome{Status: run.StatusFailed, Err: errors.New(r.State.Error)}, r.Save()
}

// startAttempt counts a new attempt of n and saves it before the node runs, so an attempt that
// is interrupted still counts.
func startAttempt(r *run.Run, n schema.Node) (int, error) {
	r.State.Attempts[n.ID]++
	return r.State.Attempts[n.ID], r.Save()
}

func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
	s := r.State
	attempt, err := startAttempt(r, n)
	if err != nil {
		return err
	}
	role := r.Setup.Config.Roles[n.Role]
	prompt, err := os.ReadFile(filepath.Join(r.Setup.RealmDir, n.Prompt))
	if err != nil {
		return err
	}
	text := string(prompt)
	if r.Setup.BriefText != "" {
		text += "\n\n## Brief\n\n" + r.Setup.BriefText
	}
	if reason := s.Reasons[n.ID]; reason != "" {
		text += "\n\n## Rejected at the approval point\n\n" + reason + "\n"
	}
	ev := gungnir.Event{Node: n.ID, Attempt: attempt, Role: n.Role, Adapter: role.Agent, Model: role.Model}
	start := ev
	start.Name = gungnir.EventNodeStarted
	if err := r.Log(start); err != nil {
		return err
	}
	task := gungnir.Task{Role: n.Role, Node: n.ID, Attempt: attempt, Prompt: text, Workdir: r.Workspace(),
		Model: role.Model, ReadOnly: n.ReadOnly, MaxTurns: n.MaxTurns, Timeout: time.Duration(n.Timeout),
		TranscriptDir: filepath.Join(r.Dir, "transcripts")}
	actx, cancel := ctx, context.CancelFunc(func() {})
	if task.Timeout > 0 {
		actx, cancel = context.WithTimeout(ctx, task.Timeout)
	}
	began := time.Now()
	res, runErr := r.Setup.Agents[n.Role].Run(actx, task)
	cancel()
	if runErr == nil {
		if err := res.Validate(); err != nil {
			runErr = fmt.Errorf("the agent's result is malformed: %w", err)
		} else {
			// Only a well-formed result's usage counts; a malformed one is never trusted.
			s.Usage = s.Usage.Add(res.Usage)
			ev = ev.WithUsage(res.Usage)
			if res.Status != gungnir.StatusOK {
				runErr = fmt.Errorf("the agent reported %s: %s", res.Status, res.Summary)
			}
		}
	}
	ev.DurationMS = time.Since(began).Milliseconds()
	if runErr != nil {
		ev.Name, ev.Result = gungnir.EventNodeFailed, runErr.Error()
		if err := r.Log(ev); err != nil {
			return err
		}
		return &nodeFailure{runErr}
	}
	ev.Name, ev.Result = gungnir.EventNodeFinished, res.Summary
	if err := r.Log(ev); err != nil {
		return err
	}
	delete(s.Reasons, n.ID)
	s.Summaries[n.ID] = res.Summary
	return nil
}

// runExec runs n's command in the workspace, without a shell. The command gets only PATH, HOME
// (the workspace) and LANG, so no credential in the operator's environment reaches it. A cancel
// or timeout kills the command's whole process group (spec §6.2). Phase 3 moves leaf commands
// into the sandbox.
func runExec(ctx context.Context, r *run.Run, n schema.Node) error {
	attempt, err := startAttempt(r, n)
	if err != nil {
		return err
	}
	if err := r.Log(gungnir.Event{Name: gungnir.EventNodeStarted, Node: n.ID, Attempt: attempt}); err != nil {
		return err
	}
	logPath := filepath.Join(r.Dir, "logs", fmt.Sprintf("%s-%d.log", n.ID, attempt))
	if err := os.MkdirAll(filepath.Dir(logPath), 0o755); err != nil {
		return err
	}
	out, err := os.Create(logPath)
	if err != nil {
		return err
	}
	defer out.Close()
	timeout := time.Duration(n.Timeout)
	if timeout == 0 {
		timeout = ExecTimeout
	}
	cctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	cmd := exec.CommandContext(cctx, n.Run[0], n.Run[1:]...)
	cmd.Dir = r.Workspace()
	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + r.Workspace(), "LANG=C.UTF-8"}
	cmd.Stdout, cmd.Stderr = out, out
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = 5 * time.Second
	began := time.Now()
	runErr := cmd.Run()
	result := "exit 0"
	if runErr != nil {
		result = runErr.Error()
	}
	ev := gungnir.Event{Name: gungnir.EventNodeFinished, Node: n.ID, Attempt: attempt, Result: result,
		DurationMS: time.Since(began).Milliseconds()}
	if runErr != nil {
		ev.Name = gungnir.EventNodeFailed
	}
	if err := r.Log(ev); err != nil {
		return err
	}
	if runErr != nil {
		return &nodeFailure{fmt.Errorf("%s: %s (output: %s)", strings.Join(n.Run, " "), result, logPath)}
	}
	r.State.Summaries[n.ID] = result
	return nil
}
```

- [ ] **Step 5:** run the named test; expect `ok`. Land it.

---

### Task v0-T034: the engine, gate nodes

**Files (in `odin`):**

- Replace: `internal/engine/gates.go`
- Create: `internal/engine/gates_test.go`

**Interfaces:**

- Consumes: `gate.Decide` (v0-T030), `startAttempt` (v0-T033).
- Produces: `engine.Approve(r *run.Run, gateID, note string) error` and
  `engine.Reject(r *run.Run, gateID, reason string) error`. The gate file is
  `gates/<node>-<n>.md`.

**Acceptance criteria:**

- [ ] A stop writes the gate file with what happened, the cost so far, and the two commands; logs
      `gate_pending`; and leaves the run `stopped` until a decision.
- [ ] An auto-pass still writes the gate file and logs `gate_auto_passed` (spec §7.2).
- [ ] `Approve` refuses a gate that isn't waiting, and records the note.
- [ ] `Reject` needs a reason, re-runs the node the gate names with the reason in its prompt, and the
      second stop gets a gate file of its own.

**Named test:** `go test -race ./internal/engine/`. **Layer:** `odin`. **Size:** M (240 lines).
**Depends on:** v0-T033.

- [ ] **Step 1:** write `internal/engine/gates_test.go`:

```go
package engine

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/run"
)

const gateNodes = "  - { id: spec, kind: agent, role: planner, prompt: p.md }\n  - { id: check, kind: exec, run: [test, -s, spec.md] }\n  - { id: spec-gate, kind: gate, gate: spec, reruns: spec }\n"

const gateScript = `steps:
  spec:
    - actions: [ { write: { path: spec.md, content: "v1\n" } } ]
      result: { status: ok, summary: wrote spec v1 }
    - actions: [ { write: { path: spec.md, content: "v2\n" } } ]
      result: { status: ok, summary: wrote spec v2 }
`

func TestAStopWritesAGateFileAndWaits(t *testing.T) {
	r := start(t, "step-by-step", "", gateNodes, gateScript)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusStopped || out.Gate != "spec-gate" {
		t.Fatalf("Advance() = %+v, %v; want stopped at spec-gate", out, err)
	}
	s, _ := run.LoadState(r.Dir)
	if s.Status != run.StatusStopped || s.Pending != "spec-gate" {
		t.Errorf("run.json = %s, pending %q", s.Status, s.Pending)
	}
	gf, err := os.ReadFile(filepath.Join(r.Dir, "gates", "spec-gate-1.md"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"stopped for a decision", "spec (agent, attempt 1): wrote spec v1",
		"check (exec, attempt 1): exit 0", "ygg approve " + s.ID + " spec-gate", "ygg reject " + s.ID + " spec-gate"} {
		if !strings.Contains(string(gf), want) {
			t.Errorf("the gate file lacks %q:\n%s", want, gf)
		}
	}
	if !strings.Contains(ledgerText(t, r), `"event":"gate_pending"`) {
		t.Error("no gate_pending in the ledger")
	}
	if out, _ := Advance(context.Background(), r); out.Status != run.StatusStopped {
		t.Error("Advance() on a waiting run moved on without a decision")
	}
}

func TestAnAutoPassStillWritesTheGateFile(t *testing.T) {
	r := start(t, "key-points", "", gateNodes, gateScript)
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v; want done (spec passes in key-points)", out, err)
	}
	gf, err := os.ReadFile(filepath.Join(r.Dir, "gates", "spec-gate-1.md"))
	if err != nil || !strings.Contains(string(gf), "passed automatically") {
		t.Errorf("gate file = %q, %v", gf, err)
	}
	if !strings.Contains(ledgerText(t, r), `"event":"gate_auto_passed"`) {
		t.Error("no gate_auto_passed in the ledger")
	}
}

func TestApproveMovesPastTheGate(t *testing.T) {
	r := start(t, "step-by-step", "", gateNodes, gateScript)
	Advance(context.Background(), r)
	if err := Approve(r, "design-gate", ""); err == nil {
		t.Error("Approve() of a gate that isn't waiting succeeded")
	}
	if err := Approve(r, "spec-gate", "looks right"); err != nil {
		t.Fatal(err)
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v; want done", out, err)
	}
	if !strings.Contains(ledgerText(t, r), `"event":"gate_approved","ygg.gate.name":"spec-gate","ygg.note":"looks right"`) {
		t.Error("the ledger doesn't record the approval with its note")
	}
}

func TestRejectRerunsTheNodeWithTheReason(t *testing.T) {
	r := start(t, "step-by-step", "", gateNodes, gateScript)
	Advance(context.Background(), r)
	if err := Reject(r, "spec-gate", " "); err == nil {
		t.Error("Reject() without a reason succeeded")
	}
	if err := Reject(r, "spec-gate", "Name the users."); err != nil {
		t.Fatal(err)
	}
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusStopped || out.Gate != "spec-gate" {
		t.Fatalf("Advance() = %+v, %v; want stopped at spec-gate again", out, err)
	}
	var tr struct{ Prompt string }
	b, err := os.ReadFile(filepath.Join(r.Dir, "transcripts", "spec-2.json"))
	if err != nil {
		t.Fatal(err)
	}
	json.Unmarshal(b, &tr)
	if !strings.Contains(tr.Prompt, "Name the users.") {
		t.Errorf("attempt 2's prompt lacks the reason:\n%s", tr.Prompt)
	}
	if _, err := os.Stat(filepath.Join(r.Dir, "gates", "spec-gate-2.md")); err != nil {
		t.Errorf("the second stop has no gate file of its own: %v", err)
	}
	if r.State.Reasons["spec"] != "" {
		t.Error("the reason is kept after the node used it")
	}
}
```

- [ ] **Step 2:** run the named test; expect a build failure: `undefined: Approve`.
- [ ] **Step 3:** replace `internal/engine/gates.go`:

```go
package engine

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/gate"
	"github.com/ouroboric-dev/odin/internal/run"
)

// reachGate decides gate node n (spec §7.2). Both a stop and an auto-pass write a gate file, so
// unattended decisions can be audited. A stop saves the run as stopped and reports true.
func reachGate(r *run.Run, n schema.Node) (bool, error) {
	s := r.State
	attempt, err := startAttempt(r, n)
	if err != nil {
		return false, err
	}
	// Phase 1 has no conformance review and no contracts, so both facts are false. Block only
	// arises for pointer-contract, which Phase 2 brings; until then it stops like Stop.
	action := gate.Decide(s.Mode, n.Gate, r.Setup.Config.Gates, gate.Facts{})
	file, err := writeGateFile(r, n, attempt, action)
	if err != nil {
		return false, err
	}
	ev := gungnir.Event{Node: n.ID, Attempt: attempt, Gate: n.ID, GateFile: file}
	if action == gate.Auto {
		ev.Name = gungnir.EventGateAutoPassed
		return false, r.Log(ev)
	}
	ev.Name = gungnir.EventGatePending
	if err := r.Log(ev); err != nil {
		return false, err
	}
	s.Status, s.Pending = run.StatusStopped, n.ID
	return true, r.Save()
}

// writeGateFile writes gates/<node>-<attempt>.md and returns its path relative to the run.
func writeGateFile(r *run.Run, n schema.Node, attempt int, action gate.Action) (string, error) {
	s := r.State
	rel := filepath.Join("gates", fmt.Sprintf("%s-%d.md", n.ID, attempt))
	var b strings.Builder
	decision := "stopped for a decision"
	if action == gate.Auto {
		decision = "passed automatically"
	}
	fmt.Fprintf(&b, "# Approval point %s (%s)\n\n", n.ID, n.Gate)
	fmt.Fprintf(&b, "- Run: %s\n- Mode: %s\n- Decision: %s\n- Time: %s\n\n", s.ID, s.Mode, decision,
		time.Now().UTC().Format(time.RFC3339))
	b.WriteString("## What happened\n\n")
	nodes := r.Setup.Graph.Nodes
	start := 0
	for i := s.Position - 1; i >= 0; i-- {
		if nodes[i].Kind == schema.KindGate {
			start = i + 1
			break
		}
	}
	for _, m := range nodes[start:s.Position] {
		fmt.Fprintf(&b, "- %s (%s, attempt %d): %s\n", m.ID, m.Kind, s.Attempts[m.ID], s.Summaries[m.ID])
	}
	u := s.Usage
	fmt.Fprintf(&b, "\n## Cost so far\n\n- Tokens: %d in, %d out, %d from cache\n- Turns: %d\n- Cost: $%.4f",
		u.InTok, u.OutTok, u.CacheTok, u.Turns, u.CostUSD)
	if u.CostEstimated {
		b.WriteString(" (estimated)")
	}
	b.WriteString("\n")
	if action != gate.Auto {
		fmt.Fprintf(&b, "\n## Decide\n\n    ygg approve %s %s [--note \"...\"]\n    ygg reject %s %s --reason \"...\"\n\n"+
			"A rejection re-runs %s with the reason.\n", s.ID, n.ID, s.ID, n.ID, n.Reruns)
	}
	if err := os.MkdirAll(filepath.Join(r.Dir, "gates"), 0o755); err != nil {
		return "", err
	}
	return rel, os.WriteFile(filepath.Join(r.Dir, rel), []byte(b.String()), 0o644)
}

func pending(r *run.Run, gateID string) error {
	if r.State.Pending == "" {
		return fmt.Errorf("run %s isn't waiting at an approval point", r.State.ID)
	}
	if r.State.Pending != gateID {
		return fmt.Errorf("run %s is waiting at %s, not %s", r.State.ID, r.State.Pending, gateID)
	}
	return nil
}

// Approve records the decision on the pending gate and moves the run past it. Advance continues.
func Approve(r *run.Run, gateID, note string) error {
	if err := pending(r, gateID); err != nil {
		return err
	}
	s := r.State
	if err := r.Log(gungnir.Event{Name: gungnir.EventGateApproved, Node: gateID, Gate: gateID, Note: note}); err != nil {
		return err
	}
	s.Pending, s.Status = "", run.StatusRunning
	s.Position++
	return r.Save()
}

// Reject sends reason back into the node the gate re-runs (spec §7.2). Advance re-runs it with
// the reason in its prompt, then reaches the gate again.
func Reject(r *run.Run, gateID, reason string) error {
	if err := pending(r, gateID); err != nil {
		return err
	}
	if strings.TrimSpace(reason) == "" {
		return errors.New("a rejection needs a reason; it goes back to the node as input")
	}
	s := r.State
	g := r.Setup.Graph
	target := g.Nodes[g.Index(gateID)].Reruns
	if err := r.Log(gungnir.Event{Name: gungnir.EventGateRejected, Node: gateID, Gate: gateID, Note: reason}); err != nil {
		return err
	}
	s.Reasons[target] = reason
	s.Pending, s.Status = "", run.StatusRunning
	s.Position = g.Index(target)
	return r.Save()
}
```

- [ ] **Step 4:** run the named test; expect `ok`. Land it.

---

### Task v0-T035: the `ygg` command line

**Files (in `odin`):**

- Create: `cmd/ygg/main.go`, `internal/cli/cli.go`, `internal/cli/cli_test.go`
- Modify: `README.md`. A "Usage" section after "Build and test" gives the six commands and the exit
  codes, copied from `usage` in `cli.go`.

**Interfaces:**

- Produces: `cli.Main(ctx, args []string, stdout, stderr io.Writer) int`; `ExitDone`, `ExitFailed`,
  `ExitRefused`, `ExitStopped` (decision 10); the commands `run`, `resume`, `approve`, `reject` and
  `status`. Flags may come before or after the positional arguments.

**Acceptance criteria:**

- [ ] Usage errors exit 2 and create nothing, including a path as the run id and an unknown mode.
- [ ] `run` stops at the first gate with exit 3 and prints the two commands. `status` shows the
      waiting gate. `approve` continues the run, and `resume` of a done run is refused.
- [ ] `status` of a run that is `running` but unlocked says it was interrupted.

**Named test:** `go test ./internal/cli/`. **Layer:** `odin`. **Size:** M (367 lines). **Depends
on:** v0-T034.

- [ ] **Step 1:** write `internal/cli/cli_test.go`:

```go
package cli

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ygg runs one command in-process and returns its exit code, stdout and stderr.
func ygg(t *testing.T, args ...string) (int, string, string) {
	t.Helper()
	var out, errOut bytes.Buffer
	code := Main(context.Background(), args, &out, &errOut)
	return code, out.String(), errOut.String()
}

// project makes a project directory with a factory.yaml for the toy realm. Its roles use script,
// a file in testdata/toy; extra is added to the config as is.
func project(t *testing.T, script, extra string) (dir, config string) {
	t.Helper()
	toy, err := filepath.Abs("../../testdata/toy")
	if err != nil {
		t.Fatal(err)
	}
	dir = t.TempDir()
	config = filepath.Join(dir, "factory.yaml")
	s := filepath.Join(toy, script)
	body := extra + "roles:\n  planner: { agent: scripted, model: none, script: " + s + " }\n" +
		"  implementer: { agent: scripted, model: none, script: " + s + " }\n"
	if !strings.Contains(extra, "budget:") {
		body += "budget:\n  per_run: { tokens: 100000, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\n"
	}
	if err := os.WriteFile(config, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return dir, config
}

func toyRealm(t *testing.T) string {
	t.Helper()
	p, _ := filepath.Abs("../../testdata/toy")
	return p
}

// runID returns the id of the only run in dir.
func runID(t *testing.T, dir string) string {
	t.Helper()
	entries, err := os.ReadDir(filepath.Join(dir, ".factory", "runs"))
	if err != nil || len(entries) != 1 {
		t.Fatalf("want one run, got %v, %v", entries, err)
	}
	return entries[0].Name()
}

func TestUsageErrorsRefuseAndCreateNothing(t *testing.T) {
	dir, config := project(t, "script.yaml", "")
	cases := map[string][]string{
		"no command":            {},
		"an unknown command":    {"deploy"},
		"run without --realm":   {"run", "--project", dir, "--config", config},
		"run with a bad mode":   {"run", "--project", dir, "--config", config, "--realm", toyRealm(t), "--mode", "fast"},
		"approve without gate":  {"approve", "20261015-090000-a1b2c3", "--project", dir},
		"a path as the run id":  {"approve", "../../../tmp", "design-gate", "--project", dir},
		"status of a path":      {"status", "../..", "--project", dir},
		"resume of no such run": {"resume", "20261015-090000-a1b2c3", "--project", dir},
	}
	for name, args := range cases {
		if code, _, _ := ygg(t, args...); code != ExitRefused {
			t.Errorf("%s: exit %d, want %d", name, code, ExitRefused)
		}
	}
	if _, err := os.Stat(filepath.Join(dir, ".factory")); err == nil {
		t.Error("a refused command created .factory/")
	}
}

func TestRunStopsAndApproveContinues(t *testing.T) {
	dir, config := project(t, "script.yaml", "")
	code, out, _ := ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
	if code != ExitStopped || !strings.Contains(out, "stopped at approval point design-gate") {
		t.Fatalf("run: exit %d, %q; want 3 at design-gate", code, out)
	}
	id := runID(t, dir)
	code, out, _ = ygg(t, "status", id, "--project", dir)
	if code != ExitDone || !strings.Contains(out, "waiting:  design-gate") {
		t.Errorf("status: exit %d:\n%s", code, out)
	}
	// Flags may follow the positional arguments.
	if code, out, errOut := ygg(t, "approve", id, "design-gate", "--project", dir, "--note", "fine"); code != ExitDone {
		t.Errorf("approve: exit %d:\n%s%s", code, out, errOut)
	}
	if code, _, errOut := ygg(t, "resume", id, "--project", dir); code != ExitRefused || !strings.Contains(errOut, "is done") {
		t.Errorf("resume of a done run: exit %d, %q", code, errOut)
	}
}
```

- [ ] **Step 2:** run the named test; expect a build failure: `undefined: Main`.
- [ ] **Step 3:** write `internal/cli/cli.go`:

```go
// Package cli is the ygg command line.
package cli

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"path/filepath"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/engine"
	"github.com/ouroboric-dev/odin/internal/run"
)

// Exit codes.
const (
	ExitDone    = 0 // the run finished, or the command succeeded
	ExitFailed  = 1 // a node failed; fix the cause, then resume
	ExitRefused = 2 // bad usage or config: nothing ran
	ExitStopped = 3 // the run waits at an approval point
)

const usage = `usage:
  ygg run     --realm <dir> [--project <dir>] [--config <factory.yaml>] [--brief <file>] [--mode <mode>]
  ygg resume  <run-id> [--project <dir>] [--mode <mode>]
  ygg approve <run-id> <gate> [--note <text>] [--project <dir>] [--mode <mode>]
  ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
  ygg status  <run-id> [--project <dir>]
exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point
`

// Main runs one ygg command and returns its exit code.
func Main(ctx context.Context, args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprint(stderr, usage)
		return ExitRefused
	}
	c := &command{ctx: ctx, out: stdout, err: stderr}
	cmds := map[string]func([]string) int{
		"run": c.run, "resume": c.resume, "approve": c.approve, "reject": c.reject,
		"status": c.status,
	}
	f, ok := cmds[args[0]]
	if !ok {
		fmt.Fprintf(stderr, "ygg: unknown command %q\n%s", args[0], usage)
		return ExitRefused
	}
	return f(args[1:])
}

type command struct {
	ctx      context.Context
	out, err io.Writer
}

// flags holds every flag; each command reads the ones it defines.
type flags struct {
	project, config, realm, brief, mode, note, reason string
}

// parse parses flags that may come before, between or after the positional arguments, and
// checks that there are exactly want of those.
func (c *command) parse(name string, args []string, want int, define func(*flag.FlagSet, *flags)) (*flags, []string, bool) {
	fs := flag.NewFlagSet("ygg "+name, flag.ContinueOnError)
	fs.SetOutput(c.err)
	f := &flags{}
	fs.StringVar(&f.project, "project", ".", "the project directory")
	fs.StringVar(&f.mode, "mode", "", "step-by-step, key-points or unattended")
	define(fs, f)
	var pos []string
	for {
		if err := fs.Parse(args); err != nil {
			return nil, nil, false
		}
		args = fs.Args()
		if len(args) == 0 {
			break
		}
		pos, args = append(pos, args[0]), args[1:]
	}
	if len(pos) != want {
		fmt.Fprintf(c.err, "ygg %s: want %d argument(s), got %d\n%s", name, want, len(pos), usage)
		return nil, nil, false
	}
	return f, pos, true
}

func (c *command) mode(f *flags) (gungnir.Mode, bool) {
	if f.mode == "" {
		return "", true
	}
	m, err := gungnir.ParseMode(f.mode)
	if err != nil {
		fmt.Fprintf(c.err, "ygg: %v\n", err)
		return "", false
	}
	return m, true
}

func (c *command) refuse(err error) int {
	fmt.Fprintf(c.err, "ygg: %v\n", err)
	return ExitRefused
}

func (c *command) run(args []string) int {
	f, _, ok := c.parse("run", args, 0, func(fs *flag.FlagSet, f *flags) {
		fs.StringVar(&f.config, "config", "factory.yaml", "the factory config")
		fs.StringVar(&f.realm, "realm", "", "the realm directory (holds pack.yaml)")
		fs.StringVar(&f.brief, "brief", "", "the brief")
	})
	if !ok {
		return ExitRefused
	}
	if f.realm == "" {
		return c.refuse(errors.New("run needs --realm"))
	}
	mode, ok := c.mode(f)
	if !ok {
		return ExitRefused
	}
	r, err := run.Start(run.Options{Project: f.project, Config: f.config, Realm: f.realm, Brief: f.brief, Mode: mode})
	if err != nil {
		return c.refuse(err)
	}
	defer r.Close()
	fmt.Fprintf(c.out, "Run %s started in %s mode.\n", r.State.ID, r.State.Mode)
	return c.advance(r)
}

// open opens a run for resume, approve and reject.
func (c *command) open(f *flags, id string) (*run.Run, int) {
	mode, ok := c.mode(f)
	if !ok {
		return nil, ExitRefused
	}
	r, err := run.Open(f.project, id, mode)
	if err != nil {
		return nil, c.refuse(err)
	}
	return r, ExitDone
}

func (c *command) resume(args []string) int {
	f, pos, ok := c.parse("resume", args, 1, func(*flag.FlagSet, *flags) {})
	if !ok {
		return ExitRefused
	}
	r, code := c.open(f, pos[0])
	if r == nil {
		return code
	}
	defer r.Close()
	switch r.State.Status {
	case run.StatusDone:
		return c.refuse(fmt.Errorf("run %s is done; there is nothing to resume", r.State.ID))
	case run.StatusStopped:
		return c.advance(r) // reports the gate it waits at
	}
	if err := r.Log(gungnir.Event{Name: gungnir.EventRunResumed, Mode: r.State.Mode}); err != nil {
		return c.refuse(err)
	}
	return c.advance(r)
}

func (c *command) decide(name string, args []string) int {
	f, pos, ok := c.parse(name, args, 2, func(fs *flag.FlagSet, f *flags) {
		fs.StringVar(&f.note, "note", "", "a note on the approval")
		fs.StringVar(&f.reason, "reason", "", "why the work goes back")
	})
	if !ok {
		return ExitRefused
	}
	r, code := c.open(f, pos[0])
	if r == nil {
		return code
	}
	defer r.Close()
	var err error
	if name == "approve" {
		err = engine.Approve(r, pos[1], f.note)
	} else {
		err = engine.Reject(r, pos[1], f.reason)
	}
	if err != nil {
		return c.refuse(err)
	}
	return c.advance(r)
}

func (c *command) approve(args []string) int { return c.decide("approve", args) }
func (c *command) reject(args []string) int  { return c.decide("reject", args) }

// advance walks the run and reports where it stopped.
func (c *command) advance(r *run.Run) int {
	out, err := engine.Advance(c.ctx, r)
	if err != nil {
		fmt.Fprintf(c.err, "ygg: run %s: %v\n", r.State.ID, err)
		return ExitFailed
	}
	id := r.State.ID
	switch out.Status {
	case run.StatusDone:
		fmt.Fprintf(c.out, "Run %s is done.\n", id)
		return ExitDone
	case run.StatusStopped:
		fmt.Fprintf(c.out, "Run %s stopped at approval point %s. Read %s, then run one of:\n"+
			"  ygg approve %s %s [--note \"...\"]\n  ygg reject %s %s --reason \"...\"\n",
			id, out.Gate, filepath.Join(r.Dir, "gates"), id, out.Gate, id, out.Gate)
		return ExitStopped
	default:
		fmt.Fprintf(c.err, "Run %s failed: %v\nFix the cause, then run: ygg resume %s\n", id, out.Err, id)
		return ExitFailed
	}
}

func (c *command) status(args []string) int {
	f, pos, ok := c.parse("status", args, 1, func(*flag.FlagSet, *flags) {})
	if !ok {
		return ExitRefused
	}
	if !run.ValidID(pos[0]) {
		return c.refuse(fmt.Errorf("%q is not a run id", pos[0]))
	}
	project, err := filepath.Abs(f.project)
	if err != nil {
		return c.refuse(err)
	}
	dir := run.Dir(project, pos[0])
	s, err := run.LoadState(dir)
	if err != nil {
		return c.refuse(err)
	}
	status := string(s.Status)
	if s.Status == run.StatusRunning && !run.Locked(dir) {
		status += " (no ygg process holds it: interrupted; ygg resume " + s.ID + ")"
	}
	fmt.Fprintf(c.out, "run:      %s\nstatus:   %s\nmode:     %s\nrealm:    %s %s (graph %s)\nposition: %d\n",
		s.ID, status, s.Mode, s.Realm, s.RealmVersion, s.GraphVersion, s.Position)
	if s.Pending != "" {
		fmt.Fprintf(c.out, "waiting:  %s\n", s.Pending)
	}
	if s.Error != "" {
		fmt.Fprintf(c.out, "error:    %s\n", s.Error)
	}
	u := s.Usage
	fmt.Fprintf(c.out, "usage:    %d tokens in, %d out, %d from cache; %d turns; $%.4f\n",
		u.InTok, u.OutTok, u.CacheTok, u.Turns, u.CostUSD)
	return ExitDone
}
```

- [ ] **Step 4:** write `cmd/ygg/main.go`:

```go
// Command ygg is the Yggdrasil factory's command line.
package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/ouroboric-dev/odin/internal/cli"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	code := cli.Main(ctx, os.Args[1:], os.Stdout, os.Stderr)
	stop()
	os.Exit(code)
}
```

- [ ] **Step 5:** run the named test; expect `ok`. Check by hand:
      `go run ./cmd/ygg run --realm testdata/toy --config <a factory.yaml in a temp dir> --project <temp dir>`
      stops at `design-gate` with exit 3. Update `README.md`. Land it.

---

### Task v0-T036: `ygg doctor`

`ygg doctor` reports missing caps as an error. This is the `doctor` part of
`require-budget-caps-T001`, and it also checks every run's ledger.

**Files (in `odin`):**

- Create: `internal/cli/doctor.go`, `internal/cli/doctor_test.go`
- Modify: `internal/cli/cli.go`. Add `"doctor": c.doctor` to the command map, and the usage line
  `ygg doctor  [--project <dir>] [--config <factory.yaml>]`, indented two spaces like the other usage lines, after `status`.

**Interfaces:**

- Produces: `ygg doctor [--project] [--config]`. It prints `OK|WARN|ERROR <what>: <detail>` lines,
  and exits 1 if any line is an ERROR. Phase 3 adds leftover containers and processes.

**Acceptance criteria:**

- [ ] Incomplete caps print `ERROR caps:` with the missing fields, and the exit code is 1.
- [ ] A run whose ledger was changed prints `ERROR run <id>: ledger:` (review focus 5).
- [ ] A run left `running` with no lock prints `WARN … interrupted`, and a good run prints `OK`.

**Named test:** `go test ./internal/cli/ -run 'TestDoctor'`. **Layer:** `odin`. **Size:** S (105
lines). **Depends on:** v0-T035.

- [ ] **Step 1:** write `internal/cli/doctor_test.go`:

```go
package cli

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDoctorReportsMissingCaps(t *testing.T) {
	dir, config := project(t, "script.yaml", "budget:\n  per_run: { tokens: 100000, turns: 100 }\n")
	code, out, _ := ygg(t, "doctor", "--project", dir, "--config", config)
	if code != ExitFailed || !strings.Contains(out, "ERROR caps:") || !strings.Contains(out, "budget.per_day") {
		t.Errorf("doctor: exit %d:\n%s", code, out)
	}
}

func TestDoctorFindsAChangedLedger(t *testing.T) {
	dir, config := project(t, "script.yaml", "")
	ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
	id := runID(t, dir)
	if code, out, _ := ygg(t, "doctor", "--project", dir, "--config", config); code != ExitDone || !strings.Contains(out, "OK    run "+id+": stopped") {
		t.Fatalf("doctor on a good run: exit %d:\n%s", code, out)
	}
	path := filepath.Join(dir, ".factory", "runs", id, "ledger.jsonl")
	b, _ := os.ReadFile(path)
	os.WriteFile(path, bytes.Replace(b, []byte(`"gen_ai.usage.input_tokens":1000`), []byte(`"gen_ai.usage.input_tokens":1`), 1), 0o644)
	code, out, _ := ygg(t, "doctor", "--project", dir, "--config", config)
	if code != ExitFailed || !strings.Contains(out, "ERROR run "+id+": ledger:") {
		t.Errorf("doctor on a changed ledger: exit %d:\n%s", code, out)
	}
}
```

- [ ] **Step 2:** run the named test; expect both tests to fail with exit 2: `doctor` is still an
      unknown command.
- [ ] **Step 3:** write `internal/cli/doctor.go`, and add `doctor` to the map and the usage text:

```go
package cli

import (
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/ledger"
	"github.com/ouroboric-dev/odin/internal/run"
)

// doctor checks the config and every run in the project, and prints one line per finding. It
// exits 1 when anything is an ERROR. Phase 3 adds leftover containers and processes.
func (c *command) doctor(args []string) int {
	f, _, ok := c.parse("doctor", args, 0, func(fs *flag.FlagSet, f *flags) {
		fs.StringVar(&f.config, "config", "factory.yaml", "the factory config")
	})
	if !ok {
		return ExitRefused
	}
	bad := false
	report := func(level, what, msg string) {
		fmt.Fprintf(c.out, "%-5s %s: %s\n", level, what, msg)
		if level == "ERROR" {
			bad = true
		}
	}
	if _, err := schema.LoadFactory(f.config); err != nil {
		var ce *schema.CapsError
		if errors.As(err, &ce) {
			report("ERROR", "caps", err.Error())
		} else {
			report("ERROR", "config", err.Error())
		}
	} else {
		report("OK", "config", f.config)
	}
	runs := filepath.Join(f.project, ".factory", "runs")
	entries, err := os.ReadDir(runs)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		report("ERROR", "runs", err.Error())
	}
	for _, e := range entries {
		dir := filepath.Join(runs, e.Name())
		if !e.IsDir() || !run.ValidID(e.Name()) {
			report("WARN", "runs", e.Name()+" is not a run")
			continue
		}
		s, err := run.LoadState(dir)
		if err != nil {
			report("ERROR", "run "+e.Name(), err.Error())
			continue
		}
		if _, err := ledger.Verify(filepath.Join(dir, "ledger.jsonl"), s.Ledger); err != nil {
			report("ERROR", "run "+s.ID, "ledger: "+err.Error())
			continue
		}
		if s.Status == run.StatusRunning && !run.Locked(dir) {
			report("WARN", "run "+s.ID, "interrupted at node position "+fmt.Sprint(s.Position)+"; ygg resume "+s.ID)
			continue
		}
		report("OK", "run "+s.ID, string(s.Status))
	}
	if bad {
		return ExitFailed
	}
	return ExitDone
}
```

- [ ] **Step 4:** run the named test; expect `ok`. Land it.

---

### Task v0-T037: the end-to-end toy graph

The phase's exit criterion as a test, and the deterministic end-to-end run that CI executes
(spec §13).

**Files (in `odin`):**

- Create: `internal/cli/e2e_test.go`

**Interfaces:**

- Consumes: `cli.Main`, and the toy realm and helpers from `cli_test.go`.
- Produces: `TestMain`, which lets the test binary run as `ygg` when `YGG_E2E_MAIN=1`, so a test can
  kill a real `ygg` process.

**Acceptance criteria:**

- [ ] Step-by-step stops at all four gates. Key-points and unattended stop only at `design`.
      Unattended with `design: auto` never stops. `plan: stop` adds a stop in key-points. Every run
      ends with a verified ledger, four gate files, and the counts of `gate_pending`,
      `gate_auto_passed` and `gate_approved` that its stops imply.
- [ ] A rejection re-runs `spec` with the reason, and the approved second version is the one kept.
- [ ] A `ygg run` killed during `build` shows as interrupted, and `resume` finishes it, with `build`
      at attempt 2 and `design` not re-run.
- [ ] Without complete caps, `ygg run` exits 2, names the fields, and creates nothing. A stopped run
      whose caps were removed refuses both `resume` and `approve`.

**Named test:** `go test -race ./internal/cli/ -run TestToyGraphEndToEnd`. It was run 5 times in a
row with `-race`, and was stable. **Layer:** `odin`. **Size:** M (211 lines). **Depends on:**
v0-T036.

- [ ] **Step 1:** write `internal/cli/e2e_test.go`:

```go
package cli

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/odin/internal/ledger"
	"github.com/ouroboric-dev/odin/internal/run"
)

// TestMain lets a test run this binary as ygg: YGG_E2E_MAIN=1 <test binary> <ygg args>.
func TestMain(m *testing.M) {
	if os.Getenv("YGG_E2E_MAIN") == "1" {
		os.Exit(Main(context.Background(), os.Args[1:], os.Stdout, os.Stderr))
	}
	os.Exit(m.Run())
}

// walk starts the toy run and approves every stop. It returns the gates it stopped at, in order.
func walk(t *testing.T, dir, config string, runArgs ...string) (string, []string) {
	t.Helper()
	args := append([]string{"run", "--project", dir, "--config", config, "--realm", toyRealm(t)}, runArgs...)
	code, out, errOut := ygg(t, args...)
	id := runID(t, dir)
	var stops []string
	for code == ExitStopped {
		s, err := run.LoadState(run.Dir(dir, id))
		if err != nil {
			t.Fatal(err)
		}
		stops = append(stops, s.Pending)
		if len(stops) > 10 {
			t.Fatalf("more than 10 stops: %v", stops)
		}
		code, out, errOut = ygg(t, "approve", id, s.Pending, "--project", dir)
	}
	if code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	return id, stops
}

// events returns the event names in the run's ledger, after checking its chain against run.json.
func events(t *testing.T, dir, id string) []string {
	t.Helper()
	s, err := run.LoadState(run.Dir(dir, id))
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(run.Dir(dir, id), "ledger.jsonl")
	if _, err := ledger.Verify(path, s.Ledger); err != nil {
		t.Fatalf("the ledger doesn't verify: %v", err)
	}
	b, _ := os.ReadFile(path)
	var names []string
	for _, line := range bytes.Split(bytes.TrimSpace(b), []byte("\n")) {
		var e struct{ Event string }
		json.Unmarshal(line, &e)
		names = append(names, e.Event)
	}
	return names
}

func count(names []string, name string) int {
	n := 0
	for _, x := range names {
		if x == name {
			n++
		}
	}
	return n
}

func TestToyGraphEndToEnd(t *testing.T) {
	modes := []struct {
		name, extra, mode string
		stops             []string
	}{
		{"step-by-step stops at every approval point", "", "step-by-step",
			[]string{"design-gate", "spec-gate", "plan-gate", "feature-gate"}},
		{"key-points stops only at design", "", "key-points", []string{"design-gate"}},
		{"unattended stops at design by default", "", "unattended", []string{"design-gate"}},
		{"unattended with design: auto never stops", "gates: { design: auto }\n", "unattended", nil},
		{"a plan: stop override adds a stop in key-points", "gates: { plan: stop }\n", "key-points",
			[]string{"design-gate", "plan-gate"}},
	}
	for _, m := range modes {
		t.Run(m.name, func(t *testing.T) {
			dir, config := project(t, "script.yaml", "mode: "+m.mode+"\n"+m.extra)
			id, stops := walk(t, dir, config)
			if !slices.Equal(stops, m.stops) {
				t.Errorf("stops = %v, want %v", stops, m.stops)
			}
			names := events(t, dir, id)
			if got := count(names, "gate_pending"); got != len(m.stops) {
				t.Errorf("gate_pending = %d, want %d", got, len(m.stops))
			}
			if got := count(names, "gate_auto_passed"); got != 4-len(m.stops) {
				t.Errorf("gate_auto_passed = %d, want %d", got, 4-len(m.stops))
			}
			if got := count(names, "gate_approved"); got != len(m.stops) {
				t.Errorf("gate_approved = %d, want %d", got, len(m.stops))
			}
			gates, _ := os.ReadDir(filepath.Join(run.Dir(dir, id), "gates"))
			if len(gates) != 4 {
				t.Errorf("%d gate files, want 4 (one per approval point, stopped or not)", len(gates))
			}
			if names[len(names)-1] != "run_finished" {
				t.Errorf("the last event is %s, want run_finished", names[len(names)-1])
			}
			if b, err := os.ReadFile(filepath.Join(dir, "workspace", "build.txt")); err != nil || string(b) != "done\n" {
				t.Errorf("workspace/build.txt = %q, %v", b, err)
			}
		})
	}

	t.Run("a rejection re-runs the node with the reason", func(t *testing.T) {
		dir, config := project(t, "script.yaml", "mode: key-points\ngates: { spec: stop }\n")
		ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
		id := runID(t, dir)
		ygg(t, "approve", id, "design-gate", "--project", dir)
		code, _, errOut := ygg(t, "reject", id, "spec-gate", "--project", dir, "--reason", "Name the users.")
		if code != ExitStopped {
			t.Fatalf("reject: exit %d, %s; want 3 at spec-gate again", code, errOut)
		}
		b, _ := os.ReadFile(filepath.Join(run.Dir(dir, id), "transcripts", "spec-2.json"))
		if !strings.Contains(string(b), "Name the users.") {
			t.Errorf("spec's second attempt didn't get the reason:\n%s", b)
		}
		if code, _, _ := ygg(t, "approve", id, "spec-gate", "--project", dir); code != ExitDone {
			t.Errorf("approve: exit %d, want 0", code)
		}
		if spec, _ := os.ReadFile(filepath.Join(dir, "workspace", "spec.md")); !strings.Contains(string(spec), "photographers") {
			t.Errorf("spec.md = %q, want attempt 2's text", spec)
		}
	})

	t.Run("a killed run resumes at the interrupted node", func(t *testing.T) {
		dir, config := project(t, "script-hang.yaml", "mode: unattended\ngates: { design: auto }\n")
		cmd := exec.Command(os.Args[0], "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
		cmd.Env = append(os.Environ(), "YGG_E2E_MAIN=1")
		if err := cmd.Start(); err != nil {
			t.Fatal(err)
		}
		deadline := time.Now().Add(20 * time.Second)
		var id string
		for {
			if entries, _ := os.ReadDir(filepath.Join(dir, ".factory", "runs")); len(entries) == 1 {
				id = entries[0].Name()
				b, _ := os.ReadFile(filepath.Join(run.Dir(dir, id), "ledger.jsonl"))
				if strings.Contains(string(b), `"ygg.node.id":"build","event":"node_started"`) {
					break
				}
			}
			if time.Now().After(deadline) {
				cmd.Process.Kill()
				t.Fatal("build never started")
			}
			time.Sleep(20 * time.Millisecond)
		}
		cmd.Process.Kill()
		cmd.Wait()
		code, out, _ := ygg(t, "status", id, "--project", dir)
		if code != ExitDone || !strings.Contains(out, "interrupted") {
			t.Errorf("status after the kill: exit %d:\n%s", code, out)
		}
		if code, out, errOut := ygg(t, "resume", id, "--project", dir); code != ExitDone {
			t.Fatalf("resume: exit %d:\n%s%s", code, out, errOut)
		}
		s, _ := run.LoadState(run.Dir(dir, id))
		if s.Attempts["build"] != 2 || s.Attempts["design"] != 1 {
			t.Errorf("attempts = %v; want build 2 (the killed one counts) and design 1 (not re-run)", s.Attempts)
		}
		if names := events(t, dir, id); count(names, "run_resumed") != 1 {
			t.Errorf("run_resumed = %d, want 1", count(names, "run_resumed"))
		}
	})

	t.Run("no complete caps, no run", func(t *testing.T) {
		dir, config := project(t, "script.yaml", "budget:\n  per_run: { tokens: 100000, turns: 100 }\n")
		code, _, errOut := ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
		if code != ExitRefused || !strings.Contains(errOut, "budget.per_day") || !strings.Contains(errOut, "per_day: { tokens: <tokens>") {
			t.Errorf("run: exit %d:\n%s", code, errOut)
		}
		if _, err := os.Stat(filepath.Join(dir, ".factory")); err == nil {
			t.Error("a refused run created .factory/")
		}
	})

	t.Run("a stopped run refuses to continue once the caps are removed", func(t *testing.T) {
		dir, config := project(t, "script.yaml", "")
		ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
		id := runID(t, dir)
		b, _ := os.ReadFile(config)
		os.WriteFile(config, []byte(strings.Split(string(b), "budget:")[0]), 0o644)
		for _, args := range [][]string{{"resume", id}, {"approve", id, "design-gate"}} {
			code, _, errOut := ygg(t, append(args, "--project", dir)...)
			if code != ExitRefused || !strings.Contains(errOut, "budget.per_run") {
				t.Errorf("%s: exit %d:\n%s", args[0], code, errOut)
			}
		}
	})
}
```

- [ ] **Step 2:** run the named test with `-count=3`; expect `ok`. This task only adds a test over
      finished code, so prove it can fail. In `internal/engine/gates.go`, change
      `s.Reasons[target] = reason` to `_ = target`. Run the test, and expect
      `spec's second attempt didn't get the reason` (checked). Then undo the change.
- [ ] **Step 3:** land it. In the PR, quote the named test's output as the Phase 1 exit evidence.

---

### Task v0-T038: pointers and the exit check

**Files (in `yggdrasil`):**

- Modify: the `gungnir`, `gleipnir` and `odin` submodule pointers

**Acceptance criteria:**

- [ ] Each pointer is its repo's `main`, which holds v0-T020 to v0-T037 and the CI workflow.
- [ ] The exit criterion holds at those pointers: the end-to-end test passes through `go.work`; each
      repo's `test` check is green on `main` and required.
- [ ] `check-repos.sh` (all checks, all repos) exits 0.

**Named test:** in `yggdrasil`, `go test -race github.com/ouroboric-dev/gungnir/... github.com/ouroboric-dev/gleipnir/... github.com/ouroboric-dev/odin/...`
passes; `git submodule status gungnir gleipnir odin` matches each repo's `origin/main`; and
`as-bot.sh --read all ../ouroboric/scripts/check-repos.sh` exits 0. **Layer:** `yggdrasil`. **Size:**
S. **Depends on:** v0-T020 to v0-T037 merged; v0-H05.

- [ ] **Step 1:** branch `pointers/phase-1`; in each of the three submodules, fetch and check out
      `origin/main`.
- [ ] **Step 2:** run the named test; expect it to pass and exit 0.
- [ ] **Step 3:** stage the three paths; commit (`Move gungnir, gleipnir and odin to Phase 1
      (v0-T038)`); push and open the PR. Its body records the exit criterion, with the test output
      and the `check-repos.sh` result. When the founder merges it, Phase 1 is done, and Phase 2's
      `tasks.md` can be written.
