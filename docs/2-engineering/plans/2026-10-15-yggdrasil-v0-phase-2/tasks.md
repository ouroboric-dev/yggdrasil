---
title: Yggdrasil v0, Phase 2 tasks (instance tree and git)
status: accepted
date: 2026-10-15
related: [../2026-10-12-yggdrasil-v0/plan.md, ../2026-10-15-yggdrasil-v0-phase-1/tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../changes/2026-10-12-remote-creates-repos/tasks.md]
style: spec
---

# Yggdrasil v0, Phase 2: instance tree and git

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking. Tasks and steps marked **founder** are done by the founder,
> never by an agent.

**Goal:** the [plan](../2026-10-12-yggdrasil-v0/plan.md)'s Phase 2 exit criterion. The tree fixtures
pass, the deeper one included; both merge-gate tests of spec §13 pass; and the git escape tests pass
with the `scripted` adapter.

**Architecture:** Gungnir gets the `repo-admin` approval point, the `Remote` interface,
`umbrella.yaml`, and graph and pack fields for repos, leaves, merge nodes and pointer nodes. Odin gets
one host-git wrapper with hooks off, the tree walker, the local remote, leaf checkpoints, the shrink
guard, locks, the merge gate and pointer moves, and then runs that live in the instance tree: each
run works on its own branch in every leaf, commits a checkpoint after every node, lands its work on
the leaf's `main` through the merge gate, and moves the project's pointer one level. The toy realm
drives it end to end, and a scripted agent tries the git escapes.

**Tech stack:** Go 1.26; host git (2.34 on this machine, 2.39 in CI's image);
`go.yaml.in/yaml/v3`, `github.com/santhosh-tekuri/jsonschema/v6`; GitHub Actions.

**Spec:** [v0 engineering spec](../../specs/2026-10-11-yggdrasil-v0-spec.md) §2.2, §3, §4.1, §4.3,
§4.5, §7, §8.3, §12, §13, §14, and the accepted change
[remote creates repos](../../changes/2026-10-12-remote-creates-repos/tasks.md), whose
`remote-creates-repos-T001` is done here, in v0-T039, v0-T046 and v0-T053, and the change
[factory issues](../../changes/2026-10-15-factory-issues/proposal.md), whose rules about operators'
projects this phase follows (decision 19), and the change
[a project is its own tree](../../changes/2026-10-15-project-is-its-own-tree/proposal.md), which
replaces the operator's L0 (decision 15).

**Status:** accepted when the founder merges the pull request that adds this file.

**Code in this plan was run.** Every Go file, schema and test below was built and run in a scratch
Go workspace on 2026-10-15, one commit per task, with `go test -race` on Go 1.26.4 and on 1.26.9, CI's
version; `govulncheck` v1.8.0 found no vulnerability. Each task's end state was also built and tested
on its own, and each task's first test run was checked to fail as its step says. Copy the code as
written; if a step's expected result differs, stop and report it, because the plan is wrong.

Code blocks are of two kinds. A new file is shown whole. A change to an existing file is shown as a
git patch (`diff`); apply it with `git apply` from the repo's folder, or edit by hand: lines that
start with `+` are added, lines with `-` removed.

## Decisions for this phase

Each line is **Decided 2026-10-15** when the founder merges this plan.

1. **Tree metadata is `umbrella.yaml`.** Every umbrella (a project, a company umbrella above
   projects, any deeper one) has an `umbrella.yaml`, with a Gungnir schema: `root` (the tree's top
   only), `owner`, `visibility`, and its child nodes by path, each
   `{ kind: umbrella | leaf, owner, visibility }`. Spec §3.1 says every node records its owner and
   visibility; a node's record is in its parent, the root's in itself. A child must also be a
   submodule at the same path. A submodule the umbrella doesn't list is not a node, and the walker
   never touches it. Odin writes the file.
2. **The visibility warning covers every umbrella.** Spec §3.1 names a public L0 that lists private
   projects. A public umbrella at any level, a company umbrella or a project, leaks its private
   children's names through `.gitmodules` the same way, so `ygg doctor` warns for each one.
3. **Host git goes through one wrapper**, `odin/internal/git`. It runs with hooks and fsmonitor off;
   it ignores the operator's global and system git config and every `GIT_*` variable, so their
   hooks, URL rewrites and commit signing never apply; it allows only the https, ssh and file
   transports; and it commits as `Yggdrasil <ygg@localhost>`. Odin runs git on a leaf with the git
   dir its parent holds (`.git/modules/<name>`), never through the leaf's own `.git` file, which an
   agent can rewrite. A submodule's URL must be https, ssh or a local path: never `ext::` and similar
   helpers, never a leading `-`.
4. **`Remote` is `Name`, `Create` and `Protect`.** Spec §2.2 leaves the method set to the plan, and the
   change remote-creates-repos adds create and protect. Committing, branching, merging and moving
   pointers on the local tree are Odin's host git. The `github` remote (iteration 2) adds push, pull
   requests and merges when it exists.
5. **The local remote creates a leaf in place**, in its parent umbrella: a new repo whose one commit
   holds the realm's first-commit files, added as a submodule with a relative URL, its git dir moved
   into the parent's `.git/modules/`, and recorded in `umbrella.yaml`, with one parent commit. The
   submodule's URL is the relative path, so an operator who pushes the tree (decision 19) first
   creates the leaf's own repo and points the submodule at it with `git submodule set-url`; the
   `github` remote (iteration 2) will do both itself. `Protect` reports that it doesn't apply. The
   local remote needs no admin rights, so no `repo-admin` stop (as the change proposal says).
6. **A run creates the leaves its project lacks when it starts** (spec §4.1 step 1), through `Remote`,
   before any node runs. A pack declares its leaves:
   `leaves: { <path>: { description, template, first_commit } }`. The web realm's `init` node (Phase 5)
   scaffolds into a leaf that exists, which meets remote-creates-repos-T001's "init creates each new
   leaf through Remote before scaffolding it".
7. **A run lives in the instance tree.** `--project` names a project umbrella. A project is usually
   its own tree, its `umbrella.yaml` setting `root: true` (decision 15); inside a company umbrella,
   every umbrella above it lists the one below, up to the one with `root: true`. Odin refuses
   anything outside a tree (spec §4.3), because a resume resets leaves. Every exec and agent node names its `repo`, a
   path from the project (`.` is the project itself). Odin requires it; Gungnir keeps it optional,
   so odin's Phase 1 graphs still parse until odin's Phase 2 code lands. Agent, merge and pointer
   nodes work only in a leaf (spec §3.3 rule 1); an exec node may run in an umbrella, for Odin's own
   deterministic generators. An exec node's `HOME` is the run's own `home/`, never a repo.
8. **Branches and checkpoints** (spec §4.3). A run works on the branch `ygg/<run-id>` in each leaf,
   started from `main`, and refuses a leaf with uncommitted changes. After each agent or exec node in
   a leaf, Odin commits the leaf: the checkpoint, recorded in `run.json` and on the node's
   `node_finished` ledger line (`ygg.ref.commit`). A resume of an interrupted or failed run resets
   every leaf to its checkpoint (`reset --hard`, `clean -ffdx`). A run that waited at an approval
   point refuses a leaf that changed in the meantime: Odin never discards work it didn't make.
   `run.json` becomes `ygg.run/v2`; a Phase 1 run can't be resumed.
9. **A checkpoint refuses planted git**: a `.git` below the leaf's top level (a nested repository, the
   way to a submodule), or a rewritten `.git` file. Either stops the run at the hard approval point
   `policy-violation`, in every mode. The leaf is then quarantined (spec §12): opening the run leaves
   it as it is, approving the stop puts it back to its checkpoint and runs the node again, and a hard
   stop takes no rejection (to drop the work, start a new run).
10. **One advancing run per project.** `run`, `resume`, `approve` and `reject` hold
    `<project>/.factory/locks/runs.lock`. The merge gate locks the leaf (`repo-<path>.lock`), and a
    pointer move locks the parent umbrella (`project.lock` for the project itself). `status` and
    `doctor` read `/proc/locks` and never take a lock, so they can't make another command fail (a
    Phase 1 minor).
11. **The approval points `merge` and `pointer` come before the step they approve.** In a realm's
    graph the gate node comes first, then the merge or pointer node, which runs under its lock in one
    go. Spec §4.2's diagram draws them after; a decision before the irreversible step is what §7
    intends.
12. **The merge gate** (spec §4.5): lock the leaf; merge the current `main` into the run's branch; run
    the node's pack checks on the result; land only if the branch head is still the checked commit,
    moving `main` with `update-ref <new> <old>`, so a `main` that moved meanwhile fails it too. A
    refusal fails the node; the work goes back to the loop (Phase 4).
13. **Pointer moves** (spec §3.4): one level only. The leaf's checks run at the new commit and the
    parent's acceptance checks in the parent; the shrink guard (spec §8.3: fewer than half the rows,
    where a row is a line that isn't blank) reads the node's `generated` files; the commit holds only
    the pointer and those files, and an umbrella with staged changes Odin didn't make is refused. A
    shrunk file stops the run at the hard `shrink-guard`; approving lands that move once without the
    guard. `pointer-contract` needs the impact index (Phase 5), so Phase 2's pointer moves decide
    with no contract facts.
14. **Secret scanning before checkpoint commits** (spec §14, `gitleaks`) needs a container, so it
    comes with the sandbox in Phase 3. Until then only the `scripted` adapter makes checkpoints, in
    tests.
15. **A project is its own tree** (change project-is-its-own-tree). An operator has no L0 above
    their projects: by default a project umbrella is the tree's root, with its leaves below. A company
    umbrella holding products, Asgard's shape, is the nested case, and the code walks it the same
    way. A project MAY also hold sub-projects: company-shaped work is better done with Asgard, but
    nesting stays open, because exploring it may teach something (a run in a sub-project is tested in
    v0-T051). So Phase 2 creates no L0, and the plan's earlier founder task for one is dropped; the client
    gallery's project is created in Phase 5. What L0 held goes elsewhere: the factory version a
    project runs with is recorded on each run's report (Phase 6) and pinned at the project's root once
    there are releases; the benchmarks belong to the bench (`mimir`, `huldra`), never to an operator's
    tree; the list of an operator's projects, for `ygg board --all`, is local configuration
    (Phase 6).
16. **Phase 1 follow-ups**, from its ledger, fold in here:
    - a rejection always re-runs an agent: by default the nearest agent node before the gate, and an
      explicit `reruns` must name one, so the reason is never dropped;
    - a duration must be positive (`timeout: 0s` read two ways);
    - a stricter `--mode` switch is allowed: `ParseFactory` checks the gate overrides against the
      file's own mode, and `design: auto` applies only in unattended mode (Phase 1 decision 6
      refused it);
    - `approve` takes only `--note` and `reject` only `--reason`;
    - an unknown agent is named as unknown, before any spend-limit message;
    - `run.json`'s position, pending node and leaves are checked against the graph when a run opens;
    - the roles `run.json` records follow a config change;
    - a run that fails after it started is recorded as failed (exit 1), and a refused start leaves
      nothing behind;
    - `golang.org/x/text` v0.41.0 (2026-08-11), which fixes GO-2026-6629 and GO-2026-5970, in
      Gungnir.
17. **Sizes count insertions**, as git reports them.
18. **odin's Phase 2 pull request pins `gungnir` in its first commit**, v0-T043, once gungnir's Phase 2
    pull request is merged (Phase 1 decision 2).
19. **Operators' projects stay theirs** (change factory-issues). Odin writes only to the operator's
    tree: the project, its leaves, and any umbrella the operator keeps above it. `yggdrasil` and its components keep no
    reference to an operator's projects, and no run ever commits, pushes or opens a pull request
    against them. The tree uses git as usual by default, with its repos hosted where the operator
    chooses; keeping a project on one host is the operator's choice. In v0 Odin commits locally only,
    and an operator pushes the tree with git; Odin pushing and opening pull requests come with the
    `github` remote (spec §15.1, iteration 2).

## Global constraints

- **Local copies.** The component repos are submodules of `yggdrasil`, at
  `/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`, and `yggdrasil/go.work` builds them together.
  Each task works on a branch in the submodule it changes. The umbrella's pointers move once, in
  v0-T060.
- **GitHub.** Agents reach GitHub only as `ouroboric-pr-bot`, through
  `/home/brunogbv/brunogbv/ouroboric/ouroboric/scripts/as-bot.sh`. `as-bot.sh <repo> <command>` pushes
  and opens PRs; `as-bot.sh --read all <command>` reads. Every change lands through a PR the founder
  merges. Agents never merge and never push to `main`.
- **Commits.** Read `git status --short` first, and stage explicit paths, never `git add -A`. Commit
  messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commits and PRs carry
  no session links. Every repo runs the `gitleaks` hook.
- **Go.** `go.mod` says `go 1.26`. Code is `gofmt`-clean and `go vet`-clean. Before a PR opens, the
  repo passes `GOWORK=off go test -race ./...` in its own folder, as CI runs it. This machine has Go
  1.26.4; CI uses 1.26.9.
- **Tests and git.** The tests build real git repos in temporary directories, through Odin's own git
  wrapper, so they need `git` on `PATH` (2.34 or later) and nothing else.
- **Pins**, each at least two weeks old when pinned: Phase 1's, plus `golang.org/x/text` v0.41.0
  (2026-08-11).
- **Licences.** `reuse lint` (`reuse==5.0.2`) passes in every repo a task touches.
- **The hidden suite.** No agent reads, lists or searches `ouroboric-dev/huldra` or its clone under
  `~/brunogbv/ouroboric-private/`.
- **Deletions** (`rm`, `git branch -D`) are asked for first, one per command, after a read-only check.

## Review focus

1. **An agent reaching git or Odin's records from its leaf**: a hook in `.git/hooks`, a rewritten
   `.git` file, a nested submodule with a command as its URL, writes aimed at the ledger. Expected:
   blocked or ignored, nothing committed, nothing fetched, the ledger still verifies. Pinned by
   v0-T059's escape tests, each shown to fail when its defence is removed.
2. **A person's work in a leaf**: uncommitted edits when a run starts, or changes while a run waits at
   an approval point. Expected: refused, never discarded. Pinned by v0-T047
   `TestStartBranchRefusesALeafWithChanges` and v0-T054 `TestOpenPutsLeavesBackAtTheirCheckpoints`.
3. **`main` moving under a landing**: a commit on a leaf's `main` after the branch passed its checks,
   or a push to the run's branch during the gate. Expected: nothing stale lands. Pinned by v0-T049's
   two spec tests.
4. **The operator's own git setup**: a global `hooksPath`, URL rewrites, commit signing, or `GIT_DIR`
   in the shell. Expected: none of it applies to Odin's git. Pinned by v0-T043
   `TestTheOperatorsGitSettingsNeverApply`.
5. **Two `ygg` processes on one project**: a second run, or `status` while a `resume` runs. Expected:
   the second advancing command exits 2 with "another ygg process is advancing a run of this
   project", and a read-only command never takes a lock. Pinned by v0-T054
   `TestOneRunAdvancesAProjectAtATime` and v0-T049 `TestHeldNeitherLocksNorCreates`.

## Order

| Task | Repo | Size | Depends on |
|---|---|---|---|
| v0-T039 `repo-admin` and `Remote` | `gungnir` | M | Phase 1 |
| v0-T040 `umbrella.yaml` | `gungnir` | M | v0-T039 |
| v0-T041 graph and pack for the tree | `gungnir` | M | v0-T040 |
| v0-T042 an unknown agent; `x/text` | `gungnir` | S | v0-T041 |
| v0-T043 host git, hooks off | `odin` | M | v0-T039 to v0-T042 merged |
| v0-T044 the tree walker | `odin` | M | v0-T043 |
| v0-T045 walking the whole tree | `odin` | M | v0-T044 |
| v0-T046 the local remote | `odin` | M | v0-T044 |
| v0-T047 leaf checkpoints | `odin` | M | v0-T044 |
| v0-T048 the shrink guard | `odin` | S | v0-T043 |
| v0-T049 locks and the merge gate | `odin` | M | v0-T047 |
| v0-T050 pointer moves | `odin` | M | v0-T048, v0-T049 |
| v0-T051 a run finds its project | `odin` | M | v0-T045 |
| v0-T052 a branch per leaf | `odin` | S | v0-T051 |
| v0-T053 the realm creates leaves | `odin` | S | v0-T046, v0-T052 |
| v0-T054 checkpoints and resume | `odin` | M | v0-T049, v0-T053 |
| v0-T055 Phase 1 follow-ups in the run | `odin` | S | v0-T054 |
| v0-T056 merge and pointer nodes | `odin` | M | v0-T050, v0-T055 |
| v0-T057 hard stops | `odin` | M | v0-T056 |
| v0-T058 the command line | `odin` | M | v0-T057 |
| v0-T059 the toy graph and the escape tests | `odin` | M | v0-T058 |
| v0-T060 pointers and the exit check | `yggdrasil` | S | all above, merged |

Gungnir's four tasks go up as one pull request, one commit per task; odin's seventeen as one, opened
once gungnir's is merged and pinned. Inside a repo the tasks stack on one branch.

## Not in Phase 2

The `github` remote, its `repo-admin` stop and the move of `create-repo.sh` and `setup-repo.sh` into it
(iteration 2, `remote-creates-repos-T002`); the sandbox, the real adapters, secret scanning at
checkpoints, and `doctor`'s container and process checks (Phase 3); loops, retries and findings
(Phase 4); routing bundles, `REPOS.md` and its generator, the impact index and `pointer-contract`
decisions, the planner's scratch directory, `init` scaffolding and `features.json` (Phase 5); moving
pointers more than one level in a step, which spec §3.4 lets the operator allow explicitly (later);
the issue forms and settings of the change factory-issues, which aren't tied to a phase; pinning
the factory version at a project's root, which waits for releases, and the local list of an
operator's projects (Phase 6).

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
```

When the repo's last task is committed, push and open its pull request:

```bash
../../ouroboric/scripts/as-bot.sh <repo> git push -u origin <branch>
../../ouroboric/scripts/as-bot.sh <repo> gh pr create --repo ouroboric-dev/<repo> --title "<title>" --body-file <file>
```

The PR body names the tasks, lists their acceptance criteria with their evidence (the named tests'
output), and says which earlier PRs it needs merged first. CI's `test` check must be green before the
founder merges it.

To pin a sibling (Phase 1 decision 2), fetch it, then pin its `main`:

```bash
../../ouroboric/scripts/as-bot.sh --read all git -C ../gungnir fetch -q origin
GOWORK=off go get github.com/ouroboric-dev/gungnir@$(git -C ../gungnir rev-parse origin/main)
GOWORK=off go mod tidy
```

---

### Task v0-T039: `repo-admin` and the `Remote` interface

The Gungnir half of `remote-creates-repos-T001`: the hard approval point `repo-admin`, and the
`Remote` interface with `Create` and `Protect` (decision 4).

**Files (in `gungnir`):**
- Create: `gate_test.go`, `remote.go`
- Modify: `gate.go`, `gungnir_test.go`, `schema/factory.schema.json`, `schema/graph.schema.json`

**Interfaces:**
- Produces: `gungnir.GateRepoAdmin` (`"repo-admin"`, hard: 16 approval points, 9 hard).
  `gungnir.Remote` with `Name() string`, `Create(ctx, Repo) error` and
  `Protect(ctx, Repo) (applied bool, err error)`. `gungnir.Visibility` (`VisibilityPrivate`,
  `VisibilityPublic`), and `gungnir.Repo{Owner, Name string; Visibility Visibility; Description,
  Path string; Files map[string][]byte}` with `Validate() error`.

**Acceptance criteria:**
- [ ] `repo-admin` is a known, hard approval point, and no config can override it: the
      `factory.yaml` and `graph.yaml` schemas know the name, so the existing override test meets
      it as a hard point.
- [ ] `Repo.Validate` refuses an owner or name that isn't one, an unknown visibility, a path that
      leaves the parent umbrella, no first-commit file, and a first-commit file that climbs or sits
      in `.git`.

**Named test:** `go test ./... -run 'TestRepoAdminIsHard|TestRepoValidate|TestHardGates|TestFactoryGateOverrides|TestGraphSchemaKnowsEveryApprovalPoint'`
in `gungnir` (`TestRepoAdminIsHard` is the change's named test). **Layer:** `gungnir`. **Size:** M
(119). **Depends on:** Phase 1.

- [ ] **Step 1:** branch `contract/tree`; write `gate_test.go`:

```go
package gungnir

import (
	"strings"
	"testing"
)

// The named test of change task remote-creates-repos-T001.
func TestRepoAdminIsHard(t *testing.T) {
	if GateRepoAdmin != "repo-admin" || !GateRepoAdmin.Known() || !GateRepoAdmin.Hard() {
		t.Errorf("repo-admin: known %v, hard %v; want a known, hard approval point", GateRepoAdmin.Known(), GateRepoAdmin.Hard())
	}
}

func TestRepoValidate(t *testing.T) {
	good := Repo{Owner: "ouroboric-dev", Name: "gallery-api", Visibility: VisibilityPrivate,
		Description: "the gallery's API", Path: "repos/api", Files: map[string][]byte{"LICENSE": []byte("MIT\n")}}
	if err := good.Validate(); err != nil {
		t.Fatalf("good repo: %v", err)
	}
	bad := map[string]func(*Repo){
		"no owner":            func(r *Repo) { r.Owner = "" },
		"a name with a slash": func(r *Repo) { r.Name = "a/b" },
		"unknown visibility":  func(r *Repo) { r.Visibility = "internal" },
		"a path that climbs":  func(r *Repo) { r.Path = "../api" },
		"no first commit":     func(r *Repo) { r.Files = nil },
		"a file that climbs":  func(r *Repo) { r.Files = map[string][]byte{"../x": nil} },
		"a file in .git":      func(r *Repo) { r.Files = map[string][]byte{".git/hooks/pre-commit": nil} },
	}
	for name, change := range bad {
		r := good
		change(&r)
		if err := r.Validate(); err == nil {
			t.Errorf("%s: Validate() = nil, want an error", name)
		}
	}
	if err := (Repo{}).Validate(); err == nil || !strings.Contains(err.Error(), "owner") {
		t.Errorf("empty repo: Validate() = %v, want it to name the owner", err)
	}
}
```

and apply to `gungnir_test.go`:

```diff
diff --git a/gungnir_test.go b/gungnir_test.go
index e46d3a3..068fe20 100644
--- a/gungnir_test.go
+++ b/gungnir_test.go
@@ -38,7 +38,7 @@ func TestUsageAdd(t *testing.T) {
 
 func TestHardGatesAreTheSpecList(t *testing.T) {
 	hard := []Gate{"deploy-prod", "store-submit", "real-secrets-or-user-data", "budget-cap",
-		"external-input", "policy-violation", "shrink-guard", "guardrail-change"}
+		"external-input", "policy-violation", "shrink-guard", "guardrail-change", "repo-admin"}
 	for _, g := range Gates() {
 		if g.Hard() != slices.Contains(hard, g) {
 			t.Errorf("%s.Hard() = %v, want %v", g, g.Hard(), !g.Hard())
@@ -47,8 +47,8 @@ func TestHardGatesAreTheSpecList(t *testing.T) {
 			t.Errorf("%s.Known() = false", g)
 		}
 	}
-	if len(Gates()) != 15 {
-		t.Errorf("len(Gates()) = %d, want 15", len(Gates()))
+	if len(Gates()) != 16 {
+		t.Errorf("len(Gates()) = %d, want 16", len(Gates()))
 	}
 	if Gate("nope").Known() || Gate("nope").Hard() {
 		t.Error(`Gate("nope") is known or hard`)
```

- [ ] **Step 2:** run `go test ./...`; expect a build failure: `undefined: GateRepoAdmin`.
- [ ] **Step 3:** apply to `gate.go`:

```diff
diff --git a/gate.go b/gate.go
index a66b938..96e0568 100644
--- a/gate.go
+++ b/gate.go
@@ -26,12 +26,13 @@ const (
 	GatePolicyViolation Gate = "policy-violation"
 	GateShrinkGuard     Gate = "shrink-guard"
 	GateGuardrailChange Gate = "guardrail-change"
+	GateRepoAdmin       Gate = "repo-admin" // change remote-creates-repos: an action that needs admin rights on a hosted repo
 )
 
 var (
 	softGates = []Gate{GateDesign, GateSpec, GatePlan, GateFeature, GateMerge, GatePointer, GatePointerContract}
 	hardGates = []Gate{GateDeployProd, GateStoreSubmit, GateRealSecrets, GateBudgetCap, GateExternalInput,
-		GatePolicyViolation, GateShrinkGuard, GateGuardrailChange}
+		GatePolicyViolation, GateShrinkGuard, GateGuardrailChange, GateRepoAdmin}
 )
 
 // Hard reports whether g is a hard approval point.
```

and write `remote.go`:

```go
package gungnir

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"regexp"
	"strings"
)

// Remote creates and protects the repos of an instance tree (spec §2.2; change
// remote-creates-repos). v0 ships the local remote, which keeps every repo on this host; the github
// remote is iteration 2 (spec §15.1). Committing, branching, merging and moving pointers on the
// local tree are Odin's own host git; the github remote adds push, pull requests and merges.
type Remote interface {
	Name() string
	// Create makes repo r with one commit holding r.Files and nothing else. It refuses, and
	// creates nothing, if the repo exists. On a hosted remote it is a repo-admin action.
	Create(ctx context.Context, r Repo) error
	// Protect applies the standard settings and the protect-main ruleset, fixing drift. It is safe
	// to repeat. applied is false when the remote has nothing to protect (the local remote).
	Protect(ctx context.Context, r Repo) (applied bool, err error)
}

// Visibility is who can see a repo.
type Visibility string

const (
	VisibilityPrivate Visibility = "private"
	VisibilityPublic  Visibility = "public"
)

// Repo is a repo a Remote creates or protects.
type Repo struct {
	Owner       string            // the org or account
	Name        string            // the repo's name on the remote
	Visibility  Visibility        // private or public
	Description string            // one line
	Path        string            // where its working copy goes, relative to its parent umbrella
	Files       map[string][]byte // the first commit: path in the repo to content
}

var repoName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)

// Validate refuses a repo that a remote couldn't create exactly as described.
func (r Repo) Validate() error {
	var errs []error
	if !repoName.MatchString(r.Owner) {
		errs = append(errs, fmt.Errorf("owner %q is not an org or account name", r.Owner))
	}
	if !repoName.MatchString(r.Name) {
		errs = append(errs, fmt.Errorf("name %q is not a repo name", r.Name))
	}
	if r.Visibility != VisibilityPrivate && r.Visibility != VisibilityPublic {
		errs = append(errs, fmt.Errorf("visibility %q is neither private nor public", r.Visibility))
	}
	if !filepath.IsLocal(r.Path) {
		errs = append(errs, fmt.Errorf("path %q must be a relative path inside the parent umbrella", r.Path))
	}
	if len(r.Files) == 0 {
		errs = append(errs, errors.New("the first commit needs at least one file"))
	}
	for p := range r.Files {
		if !filepath.IsLocal(p) || p == ".git" || strings.HasPrefix(p, ".git/") {
			errs = append(errs, fmt.Errorf("first-commit file %q must be a relative path outside .git", p))
		}
	}
	return errors.Join(errs...)
}
```

- [ ] **Step 4:** run the named test. Expect `TestFactoryGateOverrides` and
      `TestGraphSchemaKnowsEveryApprovalPoint` to fail on `repo-admin` (checked): the schemas don't
      know the name yet. Apply to `schema/factory.schema.json`:

```diff
diff --git a/schema/factory.schema.json b/schema/factory.schema.json
index 33bbb97..cca77d4 100644
--- a/schema/factory.schema.json
+++ b/schema/factory.schema.json
@@ -13,7 +13,8 @@
       "propertyNames": {
         "enum": ["design", "spec", "plan", "feature", "merge", "pointer", "pointer-contract",
                  "deploy-prod", "store-submit", "real-secrets-or-user-data", "budget-cap",
-                 "external-input", "policy-violation", "shrink-guard", "guardrail-change"]
+                 "external-input", "policy-violation", "shrink-guard", "guardrail-change",
+                 "repo-admin"]
       },
       "additionalProperties": { "enum": ["stop", "auto"] }
     },
```

and to `schema/graph.schema.json`:

```diff
diff --git a/schema/graph.schema.json b/schema/graph.schema.json
index 3aefb32..b4c200e 100644
--- a/schema/graph.schema.json
+++ b/schema/graph.schema.json
@@ -52,7 +52,8 @@
             "gate": {
               "enum": ["design", "spec", "plan", "feature", "merge", "pointer", "pointer-contract",
                        "deploy-prod", "store-submit", "real-secrets-or-user-data", "budget-cap",
-                       "external-input", "policy-violation", "shrink-guard", "guardrail-change"]
+                       "external-input", "policy-violation", "shrink-guard", "guardrail-change",
+                       "repo-admin"]
             },
             "reruns": { "$ref": "#/$defs/id" }
           }
```

- [ ] **Step 5:** run the named test; expect `ok`. Commit (see "How each task lands").

---

### Task v0-T040: `umbrella.yaml`

**Files (in `gungnir`):**
- Create: `schema/umbrella.schema.json`, `schema/umbrella.go`, `schema/umbrella_test.go`

**Interfaces:**
- Consumes: `gungnir.Visibility` (v0-T039).
- Produces: `schema.Umbrella{Root bool; Owner string; Visibility gungnir.Visibility; Children
  map[string]Child}`, `schema.Child{Kind ChildKind; Owner string; Visibility gungnir.Visibility}`,
  `schema.ChildKind` (`ChildUmbrella`, `ChildLeaf`), `schema.UmbrellaFile`,
  `LoadUmbrella(dir) (*Umbrella, error)`, `ParseUmbrella(file, data) (*Umbrella, error)`, and on
  `*Umbrella`: `Paths() []string` (sorted), `Leaks() []string` and `Save(dir) error`. `Children` is
  never nil.

**Acceptance criteria:**
- [ ] A valid file parses; an umbrella with no children has an empty, non-nil `Children`.
- [ ] Refused: no owner, an unknown visibility or kind, an unknown field, a child without an owner, a
      child path that climbs, is absolute, is `.` or starts a segment with a dot (so never in `.git`
      or `.factory`), and a child inside another child.
- [ ] `Leaks` lists the private children of a public umbrella, and nothing for a private one
      (decision 2).
- [ ] `Save` writes a file `LoadUmbrella` reads back, with a header line, and refuses to write one
      that wouldn't parse.

**Named test:** `go test ./schema/ -run 'TestParseUmbrella|TestUmbrella'`. **Layer:** `gungnir`.
**Size:** M (235). **Depends on:** v0-T039.

- [ ] **Step 1:** write `schema/umbrella_test.go`:

```go
package schema

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

const company = `
root: true
owner: brunogbv
visibility: private
children:
  projects/gallery: { kind: umbrella, owner: ouroboric-dev, visibility: private }
  projects/site: { kind: umbrella, owner: ouroboric-dev, visibility: public }
`

func TestParseUmbrella(t *testing.T) {
	u, err := ParseUmbrella("umbrella.yaml", []byte(company))
	if err != nil {
		t.Fatalf("ParseUmbrella() = %v", err)
	}
	if !u.Root || u.Owner != "brunogbv" || u.Visibility != gungnir.VisibilityPrivate {
		t.Errorf("got %+v", u)
	}
	if got := u.Paths(); !slices.Equal(got, []string{"projects/gallery", "projects/site"}) {
		t.Errorf("Paths() = %q", got)
	}
	if c := u.Children["projects/gallery"]; c.Kind != ChildUmbrella || c.Visibility != gungnir.VisibilityPrivate {
		t.Errorf("projects/gallery = %+v", c)
	}
	if empty, err := ParseUmbrella("umbrella.yaml", []byte("owner: o\nvisibility: private\n")); err != nil || empty.Children == nil {
		t.Errorf("an umbrella with no children = %+v, %v; want an empty, non-nil Children", empty, err)
	}
	if len(u.Leaks()) != 0 {
		t.Errorf("a private umbrella leaks nothing, but Leaks() = %q", u.Leaks())
	}
}

func TestUmbrellaLeaksPrivateChildrenOfAPublicUmbrella(t *testing.T) {
	u, err := ParseUmbrella("umbrella.yaml", []byte(strings.Replace(company, "visibility: private\nchildren", "visibility: public\nchildren", 1)))
	if err != nil {
		t.Fatal(err)
	}
	if got := u.Leaks(); !slices.Equal(got, []string{"projects/gallery"}) {
		t.Errorf("Leaks() = %q, want the private child", got)
	}
}

func TestParseUmbrellaRefuses(t *testing.T) {
	head := "owner: brunogbv\nvisibility: private\nchildren:\n"
	cases := map[string]string{
		"no owner":                "visibility: private\n",
		"an unknown visibility":   "owner: brunogbv\nvisibility: internal\n",
		"an unknown field":        head + "  a: { kind: leaf, owner: o, visibility: private }\nsecrets: x\n",
		"an unknown kind":         head + "  a: { kind: folder, owner: o, visibility: private }\n",
		"a child without owner":   head + "  a: { kind: leaf, visibility: private }\n",
		"a child that climbs":     head + "  ../a: { kind: leaf, owner: o, visibility: private }\n",
		"an absolute child":       head + "  /srv/a: { kind: leaf, owner: o, visibility: private }\n",
		"a child inside a child":  head + "  a: { kind: umbrella, owner: o, visibility: private }\n  a/b: { kind: leaf, owner: o, visibility: private }\n",
		"a child in .git":         head + "  .git/x: { kind: leaf, owner: o, visibility: private }\n",
		"a child in .factory":     head + "  .factory/x: { kind: leaf, owner: o, visibility: private }\n",
		"the umbrella as a child": head + "  .: { kind: leaf, owner: o, visibility: private }\n",
	}
	for name, y := range cases {
		if _, err := ParseUmbrella("umbrella.yaml", []byte(y)); err == nil {
			t.Errorf("%s: ParseUmbrella() = nil error", name)
		}
	}
}

func TestUmbrellaRoundTrips(t *testing.T) {
	dir := t.TempDir()
	u, err := ParseUmbrella("umbrella.yaml", []byte(company))
	if err != nil {
		t.Fatal(err)
	}
	u.Children["projects/blog"] = Child{Kind: ChildUmbrella, Owner: "brunogbv", Visibility: gungnir.VisibilityPrivate}
	if err := u.Save(dir); err != nil {
		t.Fatal(err)
	}
	got, err := LoadUmbrella(dir)
	if err != nil {
		t.Fatalf("LoadUmbrella() after Save = %v", err)
	}
	if !slices.Equal(got.Paths(), []string{"projects/blog", "projects/gallery", "projects/site"}) || !got.Root {
		t.Errorf("round trip = %+v", got)
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "umbrella.yaml")); !strings.HasPrefix(string(b), "# The instance tree") {
		t.Errorf("umbrella.yaml lacks its header:\n%s", b)
	}
}
```

- [ ] **Step 2:** run `go test ./schema/`; expect a build failure: `undefined: ParseUmbrella`.
- [ ] **Step 3:** write `schema/umbrella.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/umbrella.schema.json",
  "title": "umbrella.yaml",
  "description": "An umbrella of the instance tree: who owns it, who can see it, and its child nodes (spec §3.1). Only the top of the tree sets root: a project, or a company umbrella holding projects. Submodules not listed under children are not nodes.",
  "type": "object",
  "additionalProperties": false,
  "required": ["owner", "visibility"],
  "properties": {
    "root": { "type": "boolean" },
    "owner": { "$ref": "#/$defs/owner" },
    "visibility": { "$ref": "#/$defs/visibility" },
    "children": {
      "type": "object",
      "propertyNames": { "pattern": "^[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)*$" },
      "additionalProperties": {
        "type": "object",
        "additionalProperties": false,
        "required": ["kind", "owner", "visibility"],
        "properties": {
          "kind": { "enum": ["umbrella", "leaf"] },
          "owner": { "$ref": "#/$defs/owner" },
          "visibility": { "$ref": "#/$defs/visibility" }
        }
      }
    }
  },
  "$defs": {
    "owner": { "type": "string", "pattern": "^[A-Za-z0-9][A-Za-z0-9._-]*$" },
    "visibility": { "enum": ["private", "public"] }
  }
}
```

and `schema/umbrella.go`:

```go
package schema

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/ouroboric-dev/gungnir"
	"go.yaml.in/yaml/v3"
)

// Umbrella is an umbrella's umbrella.yaml (spec §3.1): who owns it, who can see it, and its child
// nodes. Odin is its only writer.
type Umbrella struct {
	Root       bool               `yaml:"root,omitempty"` // the top of the tree: a project, or a company umbrella holding projects
	Owner      string             `yaml:"owner"`
	Visibility gungnir.Visibility `yaml:"visibility"`
	Children   map[string]Child   `yaml:"children,omitempty"` // path relative to the umbrella: child
}

// ChildKind is what a child node is.
type ChildKind string

const (
	ChildUmbrella ChildKind = "umbrella" // has children, holds no product code
	ChildLeaf     ChildKind = "leaf"     // holds product code; the only node an agent mounts
)

// Child is one child node of an umbrella. Its working copy is a submodule at the same path.
type Child struct {
	Kind       ChildKind          `yaml:"kind"`
	Owner      string             `yaml:"owner"`
	Visibility gungnir.Visibility `yaml:"visibility"`
}

// UmbrellaFile is the name of an umbrella's metadata file.
const UmbrellaFile = "umbrella.yaml"

// LoadUmbrella reads dir/umbrella.yaml.
func LoadUmbrella(dir string) (*Umbrella, error) {
	file := filepath.Join(dir, UmbrellaFile)
	data, err := os.ReadFile(file)
	if err != nil {
		return nil, err
	}
	return ParseUmbrella(file, data)
}

// ParseUmbrella parses umbrella.yaml. The schema keeps child paths inside the umbrella, with no
// segment that starts with a dot (so never in .git or .factory); no child may sit inside another.
func ParseUmbrella(file string, data []byte) (*Umbrella, error) {
	var u Umbrella
	if err := parseYAML(file, "umbrella.schema.json", data, &u); err != nil {
		return nil, err
	}
	paths := u.Paths()
	for i, p := range paths {
		if !filepath.IsLocal(p) {
			return nil, fmt.Errorf("%s: child %q must be a path inside the umbrella", file, p)
		}
		if i > 0 && strings.HasPrefix(p, paths[i-1]+"/") {
			return nil, fmt.Errorf("%s: child %q is inside child %q", file, p, paths[i-1])
		}
	}
	if u.Children == nil { // an umbrella with no children yet; Odin adds to the map
		u.Children = map[string]Child{}
	}
	return &u, nil
}

// Paths returns the child paths, sorted.
func (u *Umbrella) Paths() []string { return sortedKeys(u.Children) }

// Leaks returns the private children of a public umbrella. Their names are visible to anyone who
// can read the umbrella's .gitmodules, so the operator is warned (spec §3.1).
func (u *Umbrella) Leaks() []string {
	var leaks []string
	if u.Visibility != gungnir.VisibilityPublic {
		return nil
	}
	for _, p := range u.Paths() {
		if u.Children[p].Visibility == gungnir.VisibilityPrivate {
			leaks = append(leaks, p)
		}
	}
	return leaks
}

// Save writes dir/umbrella.yaml.
func (u *Umbrella) Save(dir string) error {
	var b bytes.Buffer
	b.WriteString("# The instance tree: this umbrella and its child nodes (spec §3.1). Odin writes this file.\n")
	enc := yaml.NewEncoder(&b)
	enc.SetIndent(2)
	if err := enc.Encode(u); err != nil {
		return err
	}
	if err := enc.Close(); err != nil {
		return err
	}
	if _, err := ParseUmbrella(UmbrellaFile, b.Bytes()); err != nil {
		return fmt.Errorf("refusing to write an umbrella.yaml that doesn't parse: %w", err)
	}
	return os.WriteFile(filepath.Join(dir, UmbrellaFile), b.Bytes(), 0o644)
}
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T041: the graph and the pack for the tree

`graph.yaml` gets the fields of decision 7 and the node kinds of decisions 12 and 13; `pack.yaml`
its leaves (decision 6); the ledger the `repo_created` event. Two Phase 1 follow-ups (decision 16):
a rejection re-runs an agent, and durations are positive.

**Files (in `gungnir`):**
- Modify: `event.go`, `schema/event_test.go`, `schema/graph.go`, `schema/graph.schema.json`,
  `schema/graph_test.go`, `schema/ledger-event.schema.json`, `schema/pack.go`,
  `schema/pack.schema.json`

**Interfaces:**
- Produces: `schema.KindMerge`, `schema.KindPointer`; `schema.Node` gains `Repo string`,
  `Checks, Acceptance, Generated []string`; `schema.Pack` gains `Leaves map[string]PackLeaf`, with
  `schema.PackLeaf{Description, Template string; FirstCommit []string}`; `gungnir.EventRepoCreated`
  (`"repo_created"`). After `ParseGraph`, a gate's `Reruns` is always an agent node before it.

**Acceptance criteria:**
- [ ] Merge and pointer nodes parse with their fields. A merge node needs a repo and a check;
      neither kind may name the project (`.`) as its repo; a generated file must stay inside the
      umbrella; a repo path can't climb. `repo` stays optional on exec and agent nodes (decision 7).
- [ ] A gate with no `reruns` re-runs the nearest agent node before it, skipping exec, merge and
      pointer nodes; a named `reruns` must be an agent node before it. A gate with no agent before it
      is refused.
- [ ] `timeout: 0s` is refused.
- [ ] A pack's leaf template and first-commit files must stay inside the realm, and each
      first-commit file must be a regular file; an empty first commit is refused.
- [ ] `repo_created` is a ledger event, and the ledger schema accepts it.

**Named test:** `go test ./schema/ -run 'TestParseGraph|TestGraphSchema|TestLoadPack|TestRepoCreatedIsAnEvent|TestLedgerEventSchema'`.
**Layer:** `gungnir`. **Size:** M (184). **Depends on:** v0-T040.

- [ ] **Step 1:** apply to `schema/graph_test.go`:

```diff
diff --git a/schema/graph_test.go b/schema/graph_test.go
index f733db9..e6ca91a 100644
--- a/schema/graph_test.go
+++ b/schema/graph_test.go
@@ -42,13 +42,16 @@ func TestParseGraphResolvesWhatARejectionReruns(t *testing.T) {
 
 func TestParseGraphRefuses(t *testing.T) {
 	head := "name: toy\nversion: 1.0.0\nnodes:\n"
+	agent := "  - { id: a, kind: agent, role: planner, prompt: p.md }\n"
 	const bySchema = "jsonschema validation failed"
 	cases := map[string]struct{ nodes, want string }{
 		"a duplicate id":                   {"  - { id: a, kind: exec, run: [echo] }\n  - { id: a, kind: exec, run: [echo] }\n", "used twice"},
 		"a loop node (not yet)":            {"  - { id: a, kind: loop }\n", bySchema},
-		"a gate with nothing before it":    {"  - { id: g, kind: gate, gate: design }\n", "no node before it"},
-		"a gate that re-runs a later node": {"  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: plan, reruns: b }\n  - { id: b, kind: exec, run: [echo] }\n", "must be a node before it"},
-		"a gate that re-runs a gate":       {"  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: plan }\n  - { id: h, kind: gate, gate: feature, reruns: g }\n", "must be a node before it"},
+		"a gate with nothing before it":    {"  - { id: g, kind: gate, gate: design }\n", "no agent node before it"},
+		"a gate after only exec nodes":     {"  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: plan }\n", "no agent node before it"},
+		"a gate that re-runs a later node": {agent + "  - { id: g, kind: gate, gate: plan, reruns: b }\n  - { id: b, kind: agent, role: planner, prompt: p.md }\n", "must be an agent node before it"},
+		"a gate that re-runs a gate":       {agent + "  - { id: g, kind: gate, gate: plan }\n  - { id: h, kind: gate, gate: feature, reruns: g }\n", "must be an agent node before it"},
+		"a gate that re-runs an exec node": {agent + "  - { id: e, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: plan, reruns: e }\n", "must be an agent node before it"},
 		"an unknown approval point":        {"  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: ship }\n", bySchema},
 		"exec without a command":           {"  - { id: a, kind: exec }\n", bySchema},
 		"agent with a command":             {"  - { id: a, kind: agent, role: planner, prompt: p.md, run: [echo] }\n", bySchema},
@@ -57,6 +60,13 @@ func TestParseGraphRefuses(t *testing.T) {
 		"an absolute prompt path":          {"  - { id: a, kind: agent, role: planner, prompt: /etc/passwd }\n", "inside the realm"},
 		"a timeout in words":               {"  - { id: a, kind: exec, run: [echo], timeout: 5 minutes }\n", bySchema},
 		"no nodes":                         {"  []\n", bySchema},
+		"a zero timeout":                   {"  - { id: a, kind: exec, run: [echo], timeout: 0s }\n", bySchema},
+		"a repo that climbs":               {"  - { id: a, kind: exec, run: [echo], repo: ../x }\n", bySchema},
+		"a merge without checks":           {"  - { id: m, kind: merge, repo: repos/app }\n", bySchema},
+		"a merge without a repo":           {"  - { id: m, kind: merge, checks: [unit] }\n", bySchema},
+		"a merge of the project itself":    {"  - { id: m, kind: merge, repo: ., checks: [unit] }\n", "must be a child"},
+		"a pointer for the project itself": {"  - { id: p, kind: pointer, repo: . }\n", "must be a child"},
+		"a generated file that climbs":     {"  - { id: p, kind: pointer, repo: repos/app, generated: [../REPOS.md] }\n", "inside the umbrella"},
 	}
 	for name, c := range cases {
 		_, err := ParseGraph("graph.yaml", []byte(head+c.nodes))
@@ -68,13 +78,46 @@ func TestParseGraphRefuses(t *testing.T) {
 
 func TestGraphSchemaKnowsEveryApprovalPoint(t *testing.T) {
 	for _, g := range gungnir.Gates() {
-		y := "name: toy\nversion: 1.0.0\nnodes:\n  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: " + string(g) + " }\n"
+		y := "name: toy\nversion: 1.0.0\nnodes:\n  - { id: a, kind: agent, role: planner, prompt: p.md }\n  - { id: g, kind: gate, gate: " + string(g) + " }\n"
 		if _, err := ParseGraph("graph.yaml", []byte(y)); err != nil {
 			t.Errorf("gate %s: %v", g, err)
 		}
 	}
 }
 
+const treeGraph = `
+name: toy
+version: 2.0.0
+nodes:
+  - { id: build, kind: agent, role: implementer, prompt: p.md, repo: repos/app }
+  - { id: test, kind: exec, run: [go, test, ./...], repo: repos/app }
+  - { id: index, kind: exec, run: [make-index], repo: . }
+  - { id: merge-gate, kind: gate, gate: merge }
+  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }
+  - { id: pointer-gate, kind: gate, gate: pointer }
+  - { id: pointer, kind: pointer, repo: repos/app, checks: [unit], acceptance: [e2e], generated: [REPOS.md] }
+`
+
+func TestParseGraphMergeAndPointerNodes(t *testing.T) {
+	g, err := ParseGraph("graph.yaml", []byte(treeGraph))
+	if err != nil {
+		t.Fatalf("ParseGraph() = %v", err)
+	}
+	if got := g.Nodes[3].Reruns; got != "build" {
+		t.Errorf("merge-gate reruns %q, want build (the nearest agent node; a rejection's reason is an agent's input)", got)
+	}
+	m, p := g.Nodes[4], g.Nodes[6]
+	if m.Kind != KindMerge || m.Repo != "repos/app" || len(m.Checks) != 1 {
+		t.Errorf("merge = %+v", m)
+	}
+	if p.Kind != KindPointer || p.Acceptance[0] != "e2e" || p.Generated[0] != "REPOS.md" {
+		t.Errorf("pointer = %+v", p)
+	}
+	if g.Nodes[2].Repo != "." {
+		t.Errorf("index runs in %q, want . (the project umbrella)", g.Nodes[2].Repo)
+	}
+}
+
 func TestLoadPack(t *testing.T) {
 	dir := t.TempDir()
 	write := func(s string) {
@@ -90,10 +133,30 @@ func TestLoadPack(t *testing.T) {
 	if p.Graph != "graph.yaml" || p.Roles["planner"].Agent != "scripted" || len(p.Checks["unit"]) != 3 {
 		t.Errorf("got %+v", p)
 	}
+	if err := os.MkdirAll(filepath.Join(dir, "templates", "app"), 0o755); err != nil {
+		t.Fatal(err)
+	}
+	for _, f := range []string{"LICENSE", "README.md"} {
+		if err := os.WriteFile(filepath.Join(dir, "templates", "app", f), []byte(f+"\n"), 0o644); err != nil {
+			t.Fatal(err)
+		}
+	}
+	write(leaves("templates/app", "LICENSE, README.md"))
+	if p, err = LoadPack(dir); err != nil {
+		t.Fatalf("LoadPack() with leaves = %v", err)
+	}
+	if l := p.Leaves["repos/app"]; l.Template != "templates/app" || len(l.FirstCommit) != 2 || l.Description != "the toy app" {
+		t.Errorf("leaves = %+v", p.Leaves)
+	}
 	for name, s := range map[string]string{
 		"a graph outside the realm": "name: toy\nversion: 0.1.0\ngraph: ../graph.yaml\n",
 		"no version":                "name: toy\ngraph: graph.yaml\n",
 		"an unknown field":          "name: toy\nversion: 0.1.0\ngraph: graph.yaml\nhooks: [x]\n",
+		"a template outside":        leaves("../templates/app", "LICENSE"),
+		"a missing first file":      leaves("templates/app", "NOTICE"),
+		"a first file that climbs":  leaves("templates/app", "../../pack.yaml"),
+		"an empty first commit":     "name: toy\nversion: 0.1.0\ngraph: graph.yaml\nleaves:\n  repos/app: { description: x, template: templates/app, first_commit: [] }\n",
+		"a leaf path that climbs":   "name: toy\nversion: 0.1.0\ngraph: graph.yaml\nleaves:\n  ../app: { description: x, template: templates/app, first_commit: [LICENSE] }\n",
 	} {
 		write(s)
 		if _, err := LoadPack(dir); err == nil {
@@ -101,3 +164,9 @@ func TestLoadPack(t *testing.T) {
 		}
 	}
 }
+
+// leaves returns a pack.yaml with one leaf, repos/app, made from template with the given first files.
+func leaves(template, first string) string {
+	return "name: toy\nversion: 0.1.0\ngraph: graph.yaml\nleaves:\n  repos/app: { description: the toy app, template: " +
+		template + ", first_commit: [" + first + "] }\n"
+}
```

and to `schema/event_test.go`:

```diff
diff --git a/schema/event_test.go b/schema/event_test.go
index a7be717..40da2cf 100644
--- a/schema/event_test.go
+++ b/schema/event_test.go
@@ -2,6 +2,7 @@ package schema
 
 import (
 	"encoding/json"
+	"slices"
 	"strings"
 	"testing"
 	"time"
@@ -81,3 +82,9 @@ func mustJSON(t *testing.T, v any) string {
 	}
 	return string(b)
 }
+
+func TestRepoCreatedIsAnEvent(t *testing.T) {
+	if !slices.Contains(gungnir.Events(), gungnir.EventRepoCreated) || gungnir.EventRepoCreated != "repo_created" {
+		t.Error("repo_created isn't a ledger event")
+	}
+}
```

- [ ] **Step 2:** run `go test ./schema/`; expect a build failure:
      `undefined: gungnir.EventRepoCreated` and `undefined: KindMerge`.
- [ ] **Step 3:** apply to `schema/graph.schema.json`:

```diff
diff --git a/schema/graph.schema.json b/schema/graph.schema.json
index b4c200e..95e7c6a 100644
--- a/schema/graph.schema.json
+++ b/schema/graph.schema.json
@@ -2,7 +2,7 @@
   "$schema": "https://json-schema.org/draft/2020-12/schema",
   "$id": "https://github.com/ouroboric-dev/gungnir/schema/graph.schema.json",
   "title": "graph.yaml",
-  "description": "A realm's graph: nodes run in order; a gate node is an approval point (spec §4.2, §7). Loop nodes come in a later schema version.",
+  "description": "A realm's graph: nodes run in order; a gate node is an approval point (spec §4.2, §7). Exec and agent nodes work in a repo of the project, merge nodes land a leaf's run branch through the merge gate (§4.5), pointer nodes move a leaf's pointer one level (§3.4). Loop nodes come in a later schema version.",
   "type": "object",
   "additionalProperties": false,
   "required": ["name", "version", "nodes"],
@@ -14,11 +14,13 @@
   "$defs": {
     "id": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
     "version": { "type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$" },
-    "duration": { "type": "string", "pattern": "^[0-9]+(ms|s|m|h)$" },
+    "duration": { "type": "string", "pattern": "^[1-9][0-9]*(ms|s|m|h)$" },
+    "repo": { "type": "string", "pattern": "^(\\.|[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)*)$" },
+    "names": { "type": "array", "items": { "$ref": "#/$defs/id" } },
     "node": {
       "type": "object",
       "required": ["id", "kind"],
-      "properties": { "kind": { "enum": ["exec", "agent", "gate"] } },
+      "properties": { "kind": { "enum": ["exec", "agent", "gate", "merge", "pointer"] } },
       "oneOf": [
         {
           "additionalProperties": false,
@@ -27,6 +29,7 @@
             "id": { "$ref": "#/$defs/id" },
             "kind": { "const": "exec" },
             "run": { "type": "array", "minItems": 1, "items": { "type": "string", "minLength": 1 } },
+            "repo": { "$ref": "#/$defs/repo" },
             "timeout": { "$ref": "#/$defs/duration" }
           }
         },
@@ -40,6 +43,7 @@
             "prompt": { "type": "string", "minLength": 1 },
             "read_only": { "type": "boolean" },
             "max_turns": { "type": "integer", "minimum": 1 },
+            "repo": { "$ref": "#/$defs/repo" },
             "timeout": { "$ref": "#/$defs/duration" }
           }
         },
@@ -57,6 +61,30 @@
             },
             "reruns": { "$ref": "#/$defs/id" }
           }
+        },
+        {
+          "additionalProperties": false,
+          "required": ["repo", "checks"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "merge" },
+            "repo": { "$ref": "#/$defs/repo" },
+            "checks": { "$ref": "#/$defs/names", "minItems": 1 },
+            "timeout": { "$ref": "#/$defs/duration" }
+          }
+        },
+        {
+          "additionalProperties": false,
+          "required": ["repo"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "pointer" },
+            "repo": { "$ref": "#/$defs/repo" },
+            "checks": { "$ref": "#/$defs/names" },
+            "acceptance": { "$ref": "#/$defs/names" },
+            "generated": { "type": "array", "items": { "type": "string", "minLength": 1 } },
+            "timeout": { "$ref": "#/$defs/duration" }
+          }
         }
       ]
     }
```

to `schema/graph.go`:

```diff
diff --git a/schema/graph.go b/schema/graph.go
index 3c5720a..60e88ef 100644
--- a/schema/graph.go
+++ b/schema/graph.go
@@ -21,9 +21,11 @@ type Graph struct {
 type NodeKind string
 
 const (
-	KindExec  NodeKind = "exec"  // runs a command
-	KindAgent NodeKind = "agent" // runs one agent session
-	KindGate  NodeKind = "gate"  // an approval point
+	KindExec    NodeKind = "exec"    // runs a command
+	KindAgent   NodeKind = "agent"   // runs one agent session
+	KindGate    NodeKind = "gate"    // an approval point
+	KindMerge   NodeKind = "merge"   // lands a leaf's run branch on its main, through the merge gate
+	KindPointer NodeKind = "pointer" // moves a leaf's pointer in its parent umbrella, one level
 )
 
 // Node is one step of a graph. Which fields apply depends on Kind.
@@ -35,9 +37,14 @@ type Node struct {
 	Prompt   string       `yaml:"prompt"`    // agent: the prompt file, relative to the graph
 	ReadOnly bool         `yaml:"read_only"` // agent
 	MaxTurns int          `yaml:"max_turns"` // agent
-	Timeout  Duration     `yaml:"timeout"`   // exec and agent
+	Timeout  Duration     `yaml:"timeout"`   // exec, agent, merge and pointer
 	Gate     gungnir.Gate `yaml:"gate"`      // gate: the approval point
-	Reruns   string       `yaml:"reruns"`    // gate: the node a rejection re-runs; set by ParseGraph
+	Reruns   string       `yaml:"reruns"`    // gate: the agent node a rejection re-runs; set by ParseGraph
+
+	Repo       string   `yaml:"repo"`       // exec, agent, merge, pointer: a repo of the project, relative to it; "." is the project umbrella
+	Checks     []string `yaml:"checks"`     // merge, pointer: pack checks run in the leaf
+	Acceptance []string `yaml:"acceptance"` // pointer: pack checks run in the leaf's parent umbrella
+	Generated  []string `yaml:"generated"`  // pointer: generated files of the parent umbrella, committed with the move under the shrink guard
 }
 
 // Duration is a time.Duration written as "30s", "10m" or "1h".
@@ -71,9 +78,10 @@ func LoadGraph(path string) (*Graph, error) {
 	return ParseGraph(path, data)
 }
 
-// ParseGraph parses graph.yaml. Ids must be unique, prompt files must stay inside the realm, and
-// every gate gets the node its rejection re-runs: the one it names, which must come before it and
-// not be a gate, or else the nearest non-gate node before it.
+// ParseGraph parses graph.yaml. Ids must be unique, prompt files must stay inside the realm, merge
+// and pointer nodes must name a child repo, and every gate gets the node its rejection re-runs: the
+// agent node it names, which must come before it, or else the nearest agent node before it. A
+// rejection's reason is input for an agent, so it never re-runs an exec node, which would drop it.
 func ParseGraph(file string, data []byte) (*Graph, error) {
 	var g Graph
 	if err := parseYAML(file, "graph.schema.json", data, &g); err != nil {
@@ -89,23 +97,31 @@ func ParseGraph(file string, data []byte) (*Graph, error) {
 		if n.Kind == KindAgent && !filepath.IsLocal(n.Prompt) {
 			return nil, fmt.Errorf("%s: node %s: prompt %q must be a path inside the realm", file, n.ID, n.Prompt)
 		}
+		if (n.Kind == KindMerge || n.Kind == KindPointer) && n.Repo == "." {
+			return nil, fmt.Errorf("%s: node %s: repo must be a child of the project, not the project itself", file, n.ID)
+		}
+		for _, f := range n.Generated {
+			if !filepath.IsLocal(f) {
+				return nil, fmt.Errorf("%s: node %s: generated file %q must be a path inside the umbrella", file, n.ID, f)
+			}
+		}
 		if n.Kind != KindGate {
 			continue
 		}
 		if n.Reruns == "" {
 			for j := i - 1; j >= 0 && n.Reruns == ""; j-- {
-				if g.Nodes[j].Kind != KindGate {
+				if g.Nodes[j].Kind == KindAgent {
 					n.Reruns = g.Nodes[j].ID
 				}
 			}
 			if n.Reruns == "" {
-				return nil, fmt.Errorf("%s: gate %s has no node before it to re-run when rejected", file, n.ID)
+				return nil, fmt.Errorf("%s: gate %s has no agent node before it to re-run when rejected", file, n.ID)
 			}
 			continue
 		}
 		j, ok := seen[n.Reruns]
-		if !ok || j == i || g.Nodes[j].Kind == KindGate {
-			return nil, fmt.Errorf("%s: gate %s re-runs %q, which must be a node before it and not a gate", file, n.ID, n.Reruns)
+		if !ok || j == i || g.Nodes[j].Kind != KindAgent {
+			return nil, fmt.Errorf("%s: gate %s re-runs %q, which must be an agent node before it", file, n.ID, n.Reruns)
 		}
 	}
 	return &g, nil
```

to `schema/pack.schema.json`:

```diff
diff --git a/schema/pack.schema.json b/schema/pack.schema.json
index 83252e5..97aec8a 100644
--- a/schema/pack.schema.json
+++ b/schema/pack.schema.json
@@ -2,7 +2,7 @@
   "$schema": "https://json-schema.org/draft/2020-12/schema",
   "$id": "https://github.com/ouroboric-dev/gungnir/schema/pack.schema.json",
   "title": "pack.yaml",
-  "description": "A realm pack: its name, version, graph, default roles and check commands (spec §9.4).",
+  "description": "A realm pack: its name, version, graph, default roles, check commands, and the leaves its graph works in, with each one's template and first-commit files (spec §9.4; change remote-creates-repos).",
   "type": "object",
   "additionalProperties": false,
   "required": ["name", "version", "graph"],
@@ -27,6 +27,20 @@
       "type": "object",
       "propertyNames": { "pattern": "^[a-z][a-z0-9-]*$" },
       "additionalProperties": { "type": "array", "minItems": 1, "items": { "type": "string", "minLength": 1 } }
+    },
+    "leaves": {
+      "type": "object",
+      "propertyNames": { "pattern": "^[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)*$" },
+      "additionalProperties": {
+        "type": "object",
+        "additionalProperties": false,
+        "required": ["description", "template", "first_commit"],
+        "properties": {
+          "description": { "type": "string", "minLength": 1 },
+          "template": { "type": "string", "minLength": 1 },
+          "first_commit": { "type": "array", "minItems": 1, "items": { "type": "string", "minLength": 1 } }
+        }
+      }
     }
   }
 }
```

to `schema/pack.go`:

```diff
diff --git a/schema/pack.go b/schema/pack.go
index cf5e9c0..416f8d7 100644
--- a/schema/pack.go
+++ b/schema/pack.go
@@ -12,7 +12,15 @@ type Pack struct {
 	Version string              `yaml:"version"`
 	Graph   string              `yaml:"graph"`  // relative to the pack
 	Roles   map[string]PackRole `yaml:"roles"`  // default roles; factory.yaml's roles are used from Phase 1
-	Checks  map[string][]string `yaml:"checks"` // check commands, used from Phase 4
+	Checks  map[string][]string `yaml:"checks"` // check commands: merge and pointer nodes run them from Phase 2
+	Leaves  map[string]PackLeaf `yaml:"leaves"` // the leaves the graph works in, by path relative to the project
+}
+
+// PackLeaf is a leaf the realm creates when a project lacks it (spec §4.1).
+type PackLeaf struct {
+	Description string   `yaml:"description"`  // the new repo's description
+	Template    string   `yaml:"template"`     // the leaf's template directory, relative to the pack
+	FirstCommit []string `yaml:"first_commit"` // files of the template that make the repo's first commit, such as its licence
 }
 
 // PackRole is a realm's default agent and model for a role.
@@ -21,7 +29,8 @@ type PackRole struct {
 	Model string `yaml:"model"`
 }
 
-// LoadPack reads dir/pack.yaml. The graph path must stay inside dir.
+// LoadPack reads dir/pack.yaml. The graph and every template must stay inside dir, and every
+// first-commit file must be a regular file inside its template.
 func LoadPack(dir string) (*Pack, error) {
 	file := filepath.Join(dir, "pack.yaml")
 	data, err := os.ReadFile(file)
@@ -35,5 +44,20 @@ func LoadPack(dir string) (*Pack, error) {
 	if !filepath.IsLocal(p.Graph) {
 		return nil, fmt.Errorf("%s: graph %q must be a path inside the realm", file, p.Graph)
 	}
+	for _, path := range sortedKeys(p.Leaves) {
+		l := p.Leaves[path]
+		if !filepath.IsLocal(l.Template) {
+			return nil, fmt.Errorf("%s: leaf %s: template %q must be a path inside the realm", file, path, l.Template)
+		}
+		for _, f := range l.FirstCommit {
+			if !filepath.IsLocal(f) {
+				return nil, fmt.Errorf("%s: leaf %s: first-commit file %q must be a path inside the template", file, path, f)
+			}
+			st, err := os.Lstat(filepath.Join(dir, l.Template, f))
+			if err != nil || !st.Mode().IsRegular() {
+				return nil, fmt.Errorf("%s: leaf %s: first-commit file %s/%s must be a regular file", file, path, l.Template, f)
+			}
+		}
+	}
 	return &p, nil
 }
```

to `event.go`:

```diff
diff --git a/event.go b/event.go
index d39a328..c8f0181 100644
--- a/event.go
+++ b/event.go
@@ -29,6 +29,7 @@ const (
 	EventPointerMoved    EventName = "pointer_moved"
 	EventModeChanged     EventName = "mode_changed"
 	EventConfigChanged   EventName = "config_changed"
+	EventRepoCreated     EventName = "repo_created" // a remote created a leaf (change remote-creates-repos)
 )
 
 // Events returns every event name, in the order above.
@@ -37,7 +38,7 @@ func Events() []EventName {
 		EventNodeStarted, EventNodeFinished, EventNodeFailed, EventCheckResult, EventGatePending,
 		EventGateApproved, EventGateRejected, EventGateAutoPassed, EventLoopAttempt, EventEscalation,
 		EventRoutingLookup, EventBudgetWarning, EventPolicyViolation, EventPointerMoved,
-		EventModeChanged, EventConfigChanged}
+		EventModeChanged, EventConfigChanged, EventRepoCreated}
 }
 
 // Event is one ledger line. Fields follow OpenTelemetry's GenAI attribute names (gen_ai.*) where
```

and to `schema/ledger-event.schema.json`:

```diff
diff --git a/schema/ledger-event.schema.json b/schema/ledger-event.schema.json
index 517044d..6f964a9 100644
--- a/schema/ledger-event.schema.json
+++ b/schema/ledger-event.schema.json
@@ -16,7 +16,8 @@
       "enum": ["run_started", "run_resumed", "run_finished", "run_failed", "node_started",
                "node_finished", "node_failed", "check_result", "gate_pending", "gate_approved",
                "gate_rejected", "gate_auto_passed", "loop_attempt", "escalation", "routing_lookup",
-               "budget_warning", "policy_violation", "pointer_moved", "mode_changed", "config_changed"]
+               "budget_warning", "policy_violation", "pointer_moved", "mode_changed", "config_changed",
+               "repo_created"]
     },
     "ygg.attempt": { "type": "integer", "minimum": 1 },
     "gen_ai.agent.name": { "type": "string" },
```

- [ ] **Step 4:** run the named test; expect `ok`. Then check that odin's Phase 1 code still builds
      and passes against this Gungnir through `go.work`, except one test:
      `cd ../odin && go test ./...` fails only `TestModeTimesApprovalPointTable` ("the table covers 7
      soft gates; gungnir knows 16 gates"), which v0-T043 fixes when odin pins this Gungnir. Commit.

---

### Task v0-T042: an unknown agent, and `golang.org/x/text`

Two Phase 1 follow-ups (decision 16).

**Files (in `gungnir`):**
- Modify: `schema/factory.go`, `schema/factory_test.go`, `go.mod`, `go.sum`

**Interfaces:**
- Produces: `schema.KnownAgent(agent string) bool`.

**Acceptance criteria:**
- [ ] A role with an unknown agent (such as `codex`) is refused by the schema, by name, and never as
      a `*CapsError` asking for a spend limit.
- [ ] `KnownAgent`'s list and the schema's agent enum agree.
- [ ] `golang.org/x/text` is v0.41.0, and `govulncheck` finds no vulnerability, in the code or in the
      modules it requires.

**Named test:** `go test ./schema/ -run TestFactoryNamesAnUnknownAgentBeforeAskingForASpendLimit`, and
`GOTOOLCHAIN=go1.26.9 GOWORK=off go run golang.org/x/vuln/cmd/govulncheck@v1.8.0 ./...` prints
`No vulnerabilities found.` **Layer:** `gungnir`. **Size:** S (34). **Depends on:** v0-T041.

- [ ] **Step 1:** apply to `schema/factory_test.go`:

```diff
diff --git a/schema/factory_test.go b/schema/factory_test.go
index 5737ae7..d0560d9 100644
--- a/schema/factory_test.go
+++ b/schema/factory_test.go
@@ -137,3 +137,26 @@ func TestFactoryGateOverrides(t *testing.T) {
 		t.Error("CheckGates(key-points) accepts design: auto; a --mode switch must re-check it")
 	}
 }
+
+// An unknown agent is reported as unknown, not as a paid API that needs a spend limit: the operator
+// would set usd only to learn the agent doesn't exist.
+func TestFactoryNamesAnUnknownAgentBeforeAskingForASpendLimit(t *testing.T) {
+	_, err := ParseFactory("factory.yaml", []byte("roles:\n  planner: { agent: codex, model: x }\n"+fullCaps))
+	var ce *CapsError
+	if err == nil || errors.As(err, &ce) || !strings.Contains(err.Error(), "agent") {
+		t.Errorf("ParseFactory() = %v, want the schema's refusal of the agent, not a *CapsError", err)
+	}
+	if !KnownAgent("scripted") || KnownAgent("codex") {
+		t.Error("KnownAgent is wrong")
+	}
+	for _, a := range agents { // the Go list and the schema's enum must agree
+		caps := "budget:\n  per_run: { tokens: 1, turns: 1, usd: 1 }\n  per_day: { tokens: 1, turns: 1, usd: 1 }\n"
+		script := ""
+		if a == "scripted" {
+			script = ", script: s.yaml"
+		}
+		if _, err := ParseFactory("factory.yaml", []byte("roles:\n  r: { agent: "+a+", model: m"+script+" }\n"+caps)); err != nil {
+			t.Errorf("known agent %s: %v", a, err)
+		}
+	}
+}
```

- [ ] **Step 2:** run `go test ./schema/`; expect a build failure: `undefined: KnownAgent`.
- [ ] **Step 3:** apply to `schema/factory.go`:

```diff
diff --git a/schema/factory.go b/schema/factory.go
index bde14f7..ab4308b 100644
--- a/schema/factory.go
+++ b/schema/factory.go
@@ -38,6 +38,12 @@ type Cap struct {
 	USD    float64 `yaml:"usd"`
 }
 
+// agents are the adapters factory.schema.json accepts.
+var agents = []string{"claude-code", "opencode", "scripted"}
+
+// KnownAgent reports whether agent is an adapter this schema accepts.
+func KnownAgent(agent string) bool { return slices.Contains(agents, agent) }
+
 // PaidAPI reports whether an adapter bills a paid API. Only adapters known to run on a
 // subscription or at no cost return false, so a new adapter needs a spend limit until it is listed.
 func PaidAPI(agent string) bool { return agent != "claude-code" && agent != "scripted" }
@@ -109,7 +115,8 @@ func checkCaps(file string, doc any) error {
 	paid := ""
 	for _, name := range sortedKeys(roles) {
 		role, _ := roles[name].(map[string]any)
-		if agent, ok := role["agent"].(string); ok && PaidAPI(agent) {
+		// An unknown agent is the schema's to refuse, by name; it never asks for a spend limit.
+		if agent, ok := role["agent"].(string); ok && KnownAgent(agent) && PaidAPI(agent) {
 			paid = fmt.Sprintf("role %s runs on %s, which bills a paid API", name, agent)
 			break
 		}
```

- [ ] **Step 4:** run `GOWORK=off go get golang.org/x/text@v0.41.0` and `GOWORK=off go mod tidy`.
      `go.mod` changes so:

```diff
diff --git a/go.mod b/go.mod
index d5a2070..10b9790 100644
--- a/go.mod
+++ b/go.mod
@@ -7,4 +7,4 @@ require (
 	go.yaml.in/yaml/v3 v3.0.5
 )
 
-require golang.org/x/text v0.14.0 // indirect
+require golang.org/x/text v0.41.0 // indirect
```

- [ ] **Step 5:** run the named test and `govulncheck`; expect `ok` and `No vulnerabilities found.`
      Commit. Gungnir's four tasks are done: land the branch as one pull request (see "How each
      task lands").

---

### Task v0-T043: host git with hooks off

The wrapper every host git call goes through (decision 3; spec §3.3 rule 5, §14). odin's branch
pins Gungnir here (decision 18).

**Files (in `odin`):**
- Create: `internal/git/git.go`, `internal/git/git_test.go`
- Modify: `internal/gate/decide_test.go` (Gungnir now has nine hard approval points); `go.mod`,
  `go.sum` (the pin)

**Interfaces:**
- Produces: `git.Run(ctx, dir string, args ...string) (string, error)` (standard output, trimmed; an
  error carries the command and git's message), `git.Repo{GitDir, WorkTree string}` with
  `Run(ctx, args...)`, `git.CheckURL(url string) error`, and the identity `git.Name`, `git.Email`.

**Acceptance criteria:**
- [ ] No hook runs: not in the repo's `.git/hooks`, not through its own `core.hooksPath`.
- [ ] `core.fsmonitor` never runs a command.
- [ ] The operator's global git config never applies (a `hooksPath`, `commit.gpgsign`, a
      `status.showUntrackedFiles`), nor `GIT_DIR` or `GIT_AUTHOR_NAME` from the environment; commits
      are Odin's (review focus 4).
- [ ] `git.Repo` uses its own git dir, whatever the work tree's `.git` file says.
- [ ] `CheckURL` accepts https, ssh (also `git@host:path`) and local paths, and refuses `ext::` and
      other helpers, a leading `-`, `http://`, `git://` and an empty URL.
- [ ] Each safety setting is shown to matter: with it removed, its test fails (checked: the hooks,
      fsmonitor, global-config and git-dir tests each fail without their setting).

**Named test:** `go test ./internal/git/ ./internal/gate/`. **Layer:** `odin`. **Size:** M (265).
**Depends on:** v0-T039 to v0-T042 merged.

- [ ] **Step 1:** branch `tree/phase-2`; pin `gungnir` (see "How each task lands"). Run
      `go test ./internal/gate/`: it fails ("the table covers 7 soft gates; gungnir knows 16 gates").
      Apply to `internal/gate/decide_test.go`:

```diff
diff --git a/internal/gate/decide_test.go b/internal/gate/decide_test.go
index 091937c..1c303a1 100644
--- a/internal/gate/decide_test.go
+++ b/internal/gate/decide_test.go
@@ -33,8 +33,14 @@ func TestModeTimesApprovalPointTable(t *testing.T) {
 			t.Errorf("%s: got %v, want %v", g, got, want)
 		}
 	}
-	if len(table)+8 != len(gungnir.Gates()) {
-		t.Errorf("the table covers %d soft gates; gungnir knows %d gates", len(table), len(gungnir.Gates()))
+	soft := 0
+	for _, g := range gungnir.Gates() {
+		if !g.Hard() {
+			soft++
+		}
+	}
+	if len(table) != soft {
+		t.Errorf("the table covers %d soft gates; gungnir knows %d", len(table), soft)
 	}
 }
 
```

- [ ] **Step 2:** write `internal/git/git_test.go`:

```go
package git

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

var ctx = context.Background()

// repo makes a repo with one commit and returns its directory.
func repo(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	if _, err := Run(ctx, dir, "init", "-q"); err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(dir, "a.txt"), "a\n")
	if _, err := Run(ctx, dir, "add", "a.txt"); err != nil {
		t.Fatal(err)
	}
	if _, err := Run(ctx, dir, "commit", "-q", "-m", "first"); err != nil {
		t.Fatal(err)
	}
	return dir
}

func write(t *testing.T, path, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0o755); err != nil {
		t.Fatal(err)
	}
}

// hook writes an executable hook script that leaves marker behind if it ever runs.
func hook(t *testing.T, path, marker string) {
	t.Helper()
	write(t, path, "#!/bin/sh\ntouch "+marker+"\n")
}

func TestHooksNeverRun(t *testing.T) {
	dir := repo(t)
	marker := filepath.Join(t.TempDir(), "hook-ran")
	hook(t, filepath.Join(dir, ".git", "hooks", "pre-commit"), marker)
	hook(t, filepath.Join(dir, "myhooks", "pre-commit"), marker)
	if _, err := Run(ctx, dir, "config", "core.hooksPath", "myhooks"); err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(dir, "b.txt"), "b\n")
	if _, err := Run(ctx, dir, "add", "b.txt"); err != nil {
		t.Fatal(err)
	}
	if _, err := Run(ctx, dir, "commit", "-q", "-m", "second"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Error("a hook ran during a host commit")
	}
}

func TestFsmonitorNeverRuns(t *testing.T) {
	dir := repo(t)
	tmp := t.TempDir()
	marker := filepath.Join(tmp, "fsmonitor-ran")
	hook(t, filepath.Join(tmp, "monitor"), marker)
	if _, err := Run(ctx, dir, "config", "core.fsmonitor", filepath.Join(tmp, "monitor")); err != nil {
		t.Fatal(err)
	}
	if _, err := Run(ctx, dir, "status", "--porcelain"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Error("core.fsmonitor ran a command during git status")
	}
}

func TestTheOperatorsGitSettingsNeverApply(t *testing.T) {
	home := t.TempDir()
	marker := filepath.Join(t.TempDir(), "hook-ran")
	hook(t, filepath.Join(home, "hooks", "pre-commit"), marker)
	write(t, filepath.Join(home, ".gitconfig"), "[core]\n\thooksPath = "+filepath.Join(home, "hooks")+
		"\n[commit]\n\tgpgsign = true\n[user]\n\tname = Operator\n[status]\n\tshowUntrackedFiles = no\n")
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", home)
	t.Setenv("GIT_DIR", "/nonexistent")
	t.Setenv("GIT_AUTHOR_NAME", "Somebody Else")
	dir := repo(t) // would fail on gpgsign with no key, or on GIT_DIR, if either applied
	if _, err := os.Stat(marker); err == nil {
		t.Error("the operator's hooksPath ran a hook")
	}
	if who, _ := Run(ctx, dir, "log", "-1", "--format=%an <%ae>|%cn"); who != Name+" <"+Email+">|"+Name {
		t.Errorf("commit author|committer = %q, want Odin's identity", who)
	}
	write(t, filepath.Join(dir, "new.txt"), "new\n")
	if st, _ := Run(ctx, dir, "status", "--porcelain"); !strings.Contains(st, "new.txt") {
		t.Errorf("git status hides an untracked file (%q): the operator's status.showUntrackedFiles applied", st)
	}
}

func TestRepoNeverTrustsTheWorkTreesGitFile(t *testing.T) {
	dir := repo(t)
	real := Repo{GitDir: filepath.Join(dir, ".git"), WorkTree: dir}
	moved := filepath.Join(t.TempDir(), "gitdir")
	if err := os.Rename(real.GitDir, moved); err != nil {
		t.Fatal(err)
	}
	real.GitDir = moved
	// The work tree's .git now points at a repo an agent could have planted, with a hook.
	evil := repo(t)
	marker := filepath.Join(t.TempDir(), "hook-ran")
	write(t, filepath.Join(evil, ".git", "config"), "[core]\n\trepositoryformatversion = 0\n\tbare = false\n\thooksPath = "+filepath.Join(evil, "h")+"\n")
	hook(t, filepath.Join(evil, "h", "pre-commit"), marker)
	write(t, filepath.Join(dir, ".git"), "gitdir: "+filepath.Join(evil, ".git")+"\n")
	write(t, filepath.Join(dir, "c.txt"), "c\n")
	if _, err := real.Run(ctx, "add", "c.txt"); err != nil {
		t.Fatal(err)
	}
	if _, err := real.Run(ctx, "commit", "-q", "-m", "third"); err != nil {
		t.Fatal(err)
	}
	if n, _ := real.Run(ctx, "rev-list", "--count", "HEAD"); n != "2" {
		t.Errorf("the real repo has %s commits, want 2", n)
	}
	if n, _ := Run(ctx, evil, "rev-list", "--count", "HEAD"); n != "1" {
		t.Errorf("the planted repo has %s commits, want 1 (untouched)", n)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Error("the planted repo's hook ran")
	}
}

func TestCheckURL(t *testing.T) {
	for _, ok := range []string{"https://github.com/ouroboric-dev/odin.git", "ssh://git@github.com/o/r.git",
		"git@github.com:o/r.git", "/srv/repos/r.git", "./repos/api", "../site"} {
		if err := CheckURL(ok); err != nil {
			t.Errorf("CheckURL(%q) = %v", ok, err)
		}
	}
	for _, bad := range []string{"ext::sh -c touch% /tmp/pwned", "fd::17", "-u./payload", "--upload-pack=touch /tmp/x",
		"http://example.com/r.git", "", "git://example.com/r.git"} {
		if err := CheckURL(bad); err == nil {
			t.Errorf("CheckURL(%q) = nil, want a refusal", bad)
		}
	}
}

func TestErrorsCarryGitsMessage(t *testing.T) {
	_, err := Run(ctx, t.TempDir(), "log")
	if err == nil || !strings.Contains(err.Error(), "git log") || !strings.Contains(err.Error(), "not a git repository") {
		t.Errorf("Run() error = %v, want the command and git's message", err)
	}
}
```

- [ ] **Step 3:** run `go test ./internal/git/`; expect a build failure: `undefined: Run`.
- [ ] **Step 4:** write `internal/git/git.go`:

```go
// Package git runs host git for Odin (spec §3.3). Every call disables hooks and fsmonitor, ignores
// the operator's global and system git config and GIT_* variables, allows only the https, ssh and
// file transports, and commits as Odin. Leaves are always run with an explicit git dir, so a leaf's
// own .git file, which an agent can rewrite, is never trusted.
package git

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// Odin's identity on every commit it makes.
const (
	Name  = "Yggdrasil"
	Email = "ygg@localhost"
)

// safe are the settings every host git call gets. -c settings reach the git processes git starts
// itself, such as a submodule clone.
var safe = []string{
	"-c", "core.hooksPath=/dev/null",
	"-c", "core.fsmonitor=false",
	"-c", "protocol.allow=never",
	"-c", "protocol.https.allow=always",
	"-c", "protocol.ssh.allow=always",
	"-c", "protocol.file.allow=always",
	"-c", "submodule.recurse=false",
	"-c", "commit.gpgsign=false",
	"-c", "tag.gpgsign=false",
	"-c", "init.defaultBranch=main",
	"-c", "user.name=" + Name,
	"-c", "user.email=" + Email,
}

// env is the operator's environment without any GIT_* variable, plus Odin's own.
func env() []string {
	var e []string
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, "GIT_") {
			e = append(e, kv)
		}
	}
	return append(e,
		"GIT_CONFIG_GLOBAL=/dev/null",
		"GIT_CONFIG_NOSYSTEM=1",
		"GIT_TERMINAL_PROMPT=0",
		"GIT_AUTHOR_NAME="+Name, "GIT_AUTHOR_EMAIL="+Email,
		"GIT_COMMITTER_NAME="+Name, "GIT_COMMITTER_EMAIL="+Email,
		"LC_ALL=C",
	)
}

// Run runs git with args in dir and returns its standard output, trimmed. An error carries the
// command and git's own message.
func Run(ctx context.Context, dir string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "git", append(append([]string{}, safe...), args...)...)
	cmd.Dir = dir
	cmd.Env = env()
	var out, errOut bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &errOut
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("git %s (in %s): %w: %s", strings.Join(args, " "), dir, err, strings.TrimSpace(errOut.String()))
	}
	return strings.TrimSpace(out.String()), nil
}

// Repo is a repo whose git dir Odin chose itself.
type Repo struct {
	GitDir   string // the repo's git dir, such as <parent>/.git/modules/<name>
	WorkTree string // its working copy
}

// Run runs git with args against r, with the git dir and work tree given explicitly.
func (r Repo) Run(ctx context.Context, args ...string) (string, error) {
	return Run(ctx, r.WorkTree, append([]string{"--git-dir=" + r.GitDir, "--work-tree=" + r.WorkTree}, args...)...)
}

// CheckURL refuses a repo URL that host git shouldn't fetch: anything but https, ssh (also in the
// git@host:path form) and local paths, and anything git could read as an option.
func CheckURL(url string) error {
	switch {
	case url == "":
		return errors.New("an empty repo URL")
	case strings.HasPrefix(url, "-"):
		return fmt.Errorf("repo URL %q starts with -, so git would read it as an option", url)
	case strings.Contains(url, "::"):
		return fmt.Errorf("repo URL %q uses a git remote helper (::)", url)
	case strings.HasPrefix(url, "https://"), strings.HasPrefix(url, "ssh://"),
		strings.HasPrefix(url, "/"), strings.HasPrefix(url, "./"), strings.HasPrefix(url, "../"):
		return nil
	case !strings.Contains(url, "://") && strings.Contains(url, "@") && strings.Contains(url, ":"):
		return nil // git@host:owner/repo
	}
	return fmt.Errorf("repo URL %q is not https, ssh or a local path", url)
}
```

- [ ] **Step 5:** run the named test; expect `ok`. Then prove the tests pin the settings: remove
      `"-c", "core.hooksPath=/dev/null",` from `safe` and run `go test ./internal/git/`; expect
      `TestHooksNeverRun` to fail. Do the same with `core.fsmonitor=false`
      (`TestFsmonitorNeverRuns`), `GIT_CONFIG_GLOBAL=/dev/null` in `env`
      (`TestTheOperatorsGitSettingsNeverApply`), and the `--git-dir`/`--work-tree` arguments in
      `Repo.Run` (`TestRepoNeverTrustsTheWorkTreesGitFile`). Undo each change. Commit.

---

### Task v0-T044: the tree walker

`tree.Resolve` walks from the root to a node, through `umbrella.yaml` files, checking out only the
submodules on the way (spec §3.1; §3.3 rule 6). `treetest` builds fixture trees for every later
test: each node a repo with its own bare remote, the root cloned without submodules.

**Files (in `odin`):**
- Create: `internal/tree/tree.go`, `internal/tree/tree_test.go`, `internal/tree/treetest/treetest.go`

**Interfaces:**
- Consumes: `schema.Umbrella`, `LoadUmbrella`, `ChildUmbrella`, `ChildLeaf` (v0-T040); `git.Run`,
  `git.CheckURL` (v0-T043).
- Produces: `tree.Node{Path, Dir, GitDir string; Kind schema.ChildKind; Owner string; Visibility
  gungnir.Visibility; Umbrella *schema.Umbrella; Present bool}`,
  `tree.FindRoot(ctx, dir) (root, rel string, err error)`,
  `tree.Resolve(ctx, root, rel) ([]Node, error)` (from the root down), and `treetest.Node`,
  `treetest.Standard()`, `treetest.Build(t, Node) string` (the root's fresh clone).

**Acceptance criteria:**
- [ ] `Resolve` checks out the path to its target and nothing else: not the sibling project, not the
      sibling leaf, not the submodules that aren't nodes (`assets/`, `tools/`).
- [ ] A leaf's git dir is its parent's `.git/modules/<name>`.
- [ ] `FindRoot` finds the root from a project, and refuses a directory outside any tree and one no
      umbrella lists.
- [ ] `Resolve` refuses a path no umbrella lists, a submodule that isn't a node, a path through a
      leaf, and a path that isn't clean.
- [ ] A submodule URL that runs a command (`ext::sh -c …`) is refused before git sees it; the command
      never runs.

**Named test:** `go test ./internal/tree/`. **Layer:** `odin`. **Size:** M (399). **Depends on:**
v0-T043.

- [ ] **Step 1:** write `internal/tree/treetest/treetest.go`:

```go
// Package treetest builds instance trees for tests: every node is a repo with its own bare
// "remote" in a temporary directory, and the root is cloned without its submodules, as an operator
// would clone a project.
package treetest

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/git"
)

// Node describes a node of a fixture tree.
type Node struct {
	Owner      string
	Visibility gungnir.Visibility
	Leaf       bool            // a leaf holds a README; an umbrella holds umbrella.yaml
	Children   map[string]Node // path relative to this umbrella: child node
	Plain      []string        // submodules that are not nodes, such as shared assets an umbrella vendors
}

// Standard is a company umbrella over two projects and their leaves, the shape Asgard's company
// trees have: one project is public with a private leaf, and assets/ and tools/ are submodules
// that are not nodes.
func Standard() Node {
	leaf := func(v gungnir.Visibility) Node { return Node{Owner: "ouroboric-dev", Visibility: v, Leaf: true} }
	return Node{Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Plain: []string{"assets", "tools"},
		Children: map[string]Node{
			"projects/gallery": {Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Children: map[string]Node{
				"repos/api": leaf(gungnir.VisibilityPrivate), "repos/web": leaf(gungnir.VisibilityPrivate)}},
			"projects/site": {Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPublic, Children: map[string]Node{
				"repos/www": leaf(gungnir.VisibilityPrivate)}},
		}}
}

// Build makes the tree's repos and returns the path of a fresh clone of the root, with no
// submodule initialised.
func Build(t *testing.T, root Node) string {
	t.Helper()
	ctx := context.Background()
	remotes := t.TempDir()
	url := build(t, ctx, remotes, "root", root, true)
	work := filepath.Join(t.TempDir(), "l0")
	run(t, ctx, filepath.Dir(work), "clone", "-q", url, work)
	return work
}

// build makes node's repo and its children's, and returns the URL of its bare remote.
func build(t *testing.T, ctx context.Context, remotes, name string, n Node, root bool) string {
	t.Helper()
	dir := filepath.Join(t.TempDir(), "src")
	run(t, ctx, t.TempDir(), "init", "-q", dir)
	if n.Leaf {
		write(t, filepath.Join(dir, "README.md"), "# "+name+"\n")
	} else {
		u := schema.Umbrella{Root: root, Owner: n.Owner, Visibility: n.Visibility, Children: map[string]schema.Child{}}
		for path, c := range n.Children {
			kind := schema.ChildUmbrella
			if c.Leaf {
				kind = schema.ChildLeaf
			}
			u.Children[path] = schema.Child{Kind: kind, Owner: c.Owner, Visibility: c.Visibility}
		}
		if err := u.Save(dir); err != nil {
			t.Fatal(err)
		}
		paths := make([]string, 0, len(n.Children))
		for p := range n.Children {
			paths = append(paths, p)
		}
		slices.Sort(paths)
		for _, p := range paths {
			child := build(t, ctx, remotes, name+"-"+filepath.Base(p), n.Children[p], false)
			run(t, ctx, dir, "submodule", "add", "-q", child, p)
		}
		for _, p := range n.Plain {
			child := build(t, ctx, remotes, name+"-"+p, Node{Leaf: true}, false)
			run(t, ctx, dir, "submodule", "add", "-q", child, p)
		}
	}
	run(t, ctx, dir, "add", "-A")
	run(t, ctx, dir, "commit", "-q", "-m", "fixture "+name)
	bare := filepath.Join(remotes, name+".git")
	run(t, ctx, remotes, "clone", "-q", "--bare", dir, bare)
	return bare
}

func run(t *testing.T, ctx context.Context, dir string, args ...string) {
	t.Helper()
	if _, err := git.Run(ctx, dir, args...); err != nil {
		t.Fatal(err)
	}
}

func write(t *testing.T, path, body string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}
```

and `internal/tree/tree_test.go`:

```go
package tree

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

var ctx = context.Background()

// initialised reports whether the submodule at path in dir is checked out.
func initialised(t *testing.T, dir, path string) bool {
	t.Helper()
	st, err := git.Run(ctx, dir, "submodule", "status", "--", path)
	if err != nil {
		t.Fatal(err)
	}
	return !strings.HasPrefix(st, "-")
}

func TestResolveChecksOutOnlyThePath(t *testing.T) {
	root := treetest.Build(t, treetest.Standard())
	nodes, err := Resolve(ctx, root, "projects/gallery/repos/api")
	if err != nil {
		t.Fatalf("Resolve() = %v", err)
	}
	var paths []string
	for _, n := range nodes {
		paths = append(paths, n.Path)
	}
	if !slices.Equal(paths, []string{"", "projects/gallery", "projects/gallery/repos/api"}) {
		t.Errorf("path = %q", paths)
	}
	leaf := nodes[2]
	if leaf.Kind != schema.ChildLeaf || leaf.Owner != "ouroboric-dev" || leaf.Dir != filepath.Join(root, "projects/gallery/repos/api") {
		t.Errorf("leaf = %+v", leaf)
	}
	if want := filepath.Join(root, ".git", "modules", "projects/gallery", "modules", "repos/api"); leaf.GitDir != want {
		t.Errorf("leaf git dir = %s, want %s (in its parent's .git/modules)", leaf.GitDir, want)
	}
	if _, err := os.Stat(filepath.Join(leaf.Dir, "README.md")); err != nil {
		t.Errorf("the leaf isn't checked out: %v", err)
	}
	for _, s := range [][2]string{{root, "projects/site"}, {root, "assets"}, {root, "tools"},
		{filepath.Join(root, "projects/gallery"), "repos/web"}} {
		if initialised(t, s[0], s[1]) {
			t.Errorf("%s was initialised; only the path to the target may be (spec §3.3 rule 6)", s[1])
		}
	}
}

func TestFindRoot(t *testing.T) {
	root := treetest.Build(t, treetest.Standard())
	if _, err := Resolve(ctx, root, "projects/gallery"); err != nil {
		t.Fatal(err)
	}
	if got, rel, err := FindRoot(ctx, filepath.Join(root, "projects/gallery")); err != nil || got != root || rel != "projects/gallery" {
		t.Errorf("FindRoot(L1) = %q, %q, %v", got, rel, err)
	}
	if got, rel, err := FindRoot(ctx, root); err != nil || got != root || rel != "" {
		t.Errorf("FindRoot(root) = %q, %q, %v", got, rel, err)
	}
	outside := t.TempDir()
	if _, _, err := FindRoot(ctx, outside); err == nil || !strings.Contains(err.Error(), "not inside an instance tree") {
		t.Errorf("FindRoot(outside) = %v, want not inside an instance tree", err)
	}
	stray := filepath.Join(root, "projects", "stray")
	if err := os.MkdirAll(stray, 0o755); err != nil {
		t.Fatal(err)
	}
	if _, _, err := FindRoot(ctx, stray); err == nil || !strings.Contains(err.Error(), "lists no child") {
		t.Errorf("FindRoot(a directory no umbrella lists) = %v", err)
	}
}

func TestResolveRefuses(t *testing.T) {
	root := treetest.Build(t, treetest.Standard())
	cases := map[string]struct{ path, want string }{
		"a path no umbrella lists":   {"projects/blog", "lists no child"},
		"a submodule that's no node": {"assets", "lists no child"},
		"a path through a leaf":      {"projects/gallery/repos/api/vendor/x", "is a leaf"},
		"a path that climbs":         {"projects/../projects/gallery", "not a clean path"},
	}
	for name, c := range cases {
		if _, err := Resolve(ctx, root, c.path); err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: Resolve(%q) = %v, want an error containing %q", name, c.path, err, c.want)
		}
	}
	if initialised(t, root, "assets") {
		t.Error("a refused Resolve initialised assets/")
	}
}

func TestResolveRefusesAMaliciousSubmoduleURL(t *testing.T) {
	root := treetest.Build(t, treetest.Standard())
	marker := filepath.Join(t.TempDir(), "pwned")
	if _, err := git.Run(ctx, root, "config", "-f", ".gitmodules", "submodule.projects/site.url", "ext::sh -c touch% "+marker); err != nil {
		t.Fatal(err)
	}
	if _, err := git.Run(ctx, root, "commit", "-q", "-am", "point projects/site at a command"); err != nil {
		t.Fatal(err)
	}
	if _, err := Resolve(ctx, root, "projects/site"); err == nil || !strings.Contains(err.Error(), "remote helper") {
		t.Errorf("Resolve() = %v, want the URL refused", err)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Error("the URL's command ran")
	}
}
```

- [ ] **Step 2:** run `go test ./internal/tree/`; expect a build failure: `undefined: Resolve`.
- [ ] **Step 3:** write `internal/tree/tree.go`:

```go
// Package tree walks the instance tree (spec §3.1): umbrellas, which list their child nodes in
// umbrella.yaml, and leaves. It walks any depth, and checks out only the submodules on the path to
// the node it is asked for (spec §3.3 rule 6). Submodules an umbrella doesn't list as children
// are not nodes, and are never touched. A tree's root is the umbrella with root: true: a project,
// or a company umbrella holding projects.
package tree

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"path/filepath"
	"strings"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/git"
)

// Node is a node of the instance tree.
type Node struct {
	Path       string             // relative to the root; "" is the root
	Dir        string             // its working copy
	GitDir     string             // the root's .git, or <parent's git dir>/modules/<name>
	Kind       schema.ChildKind   // the root is an umbrella
	Owner      string             // as its parent records it; the root's own
	Visibility gungnir.Visibility // likewise
	Umbrella   *schema.Umbrella   // an umbrella's umbrella.yaml; nil for a leaf, or one not checked out
	Present    bool               // checked out
}

// FindRoot walks up from dir, a node of the tree, to the root: every umbrella on the way must list
// the node below it, and the top one sets root: true. It returns the root and dir's path from it.
func FindRoot(ctx context.Context, dir string) (root, rel string, err error) {
	child, err := filepath.Abs(dir)
	if err != nil {
		return "", "", err
	}
	if u, err := schema.LoadUmbrella(child); err == nil && u.Root {
		return child, "", nil
	} else if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return "", "", err
	}
	for cur := child; ; {
		parent := filepath.Dir(cur)
		if parent == cur {
			return "", "", fmt.Errorf("%s is not inside an instance tree: no umbrella.yaml with root: true above it", dir)
		}
		cur = parent
		u, err := schema.LoadUmbrella(parent)
		if errors.Is(err, fs.ErrNotExist) {
			continue // a plain directory, such as repos/
		}
		if err != nil {
			return "", "", err
		}
		p, err := filepath.Rel(parent, child)
		if err != nil {
			return "", "", err
		}
		if _, ok := u.Children[p]; !ok {
			return "", "", fmt.Errorf("the umbrella %s lists no child %s", parent, p)
		}
		rel = filepath.Join(p, rel)
		if u.Root {
			return parent, rel, nil
		}
		child = parent
	}
}

// Resolve returns the nodes from root down to the node at rel, checking out any that aren't,
// and nothing else.
func Resolve(ctx context.Context, root, rel string) ([]Node, error) {
	if rel != "" && (!filepath.IsLocal(rel) || filepath.Clean(rel) != rel) {
		return nil, fmt.Errorf("%q is not a clean path inside the tree", rel)
	}
	top, err := rootNode(ctx, root)
	if err != nil {
		return nil, err
	}
	nodes := []Node{top}
	for rest := rel; rest != ""; {
		cur := nodes[len(nodes)-1]
		if cur.Kind == schema.ChildLeaf {
			return nil, fmt.Errorf("%s is a leaf; the tree has nothing below it", cur.Path)
		}
		var next string
		for _, p := range cur.Umbrella.Paths() {
			if rest == p || strings.HasPrefix(rest, p+"/") {
				next = p
			}
		}
		if next == "" {
			return nil, fmt.Errorf("the umbrella %q lists no child for %s", cur.Path, rest)
		}
		c, err := child(ctx, cur, next, true)
		if err != nil {
			return nil, err
		}
		nodes = append(nodes, c)
		rest = strings.TrimPrefix(strings.TrimPrefix(rest, next), "/")
	}
	return nodes, nil
}

func rootNode(ctx context.Context, root string) (Node, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return Node{}, err
	}
	u, err := schema.LoadUmbrella(root)
	if err != nil {
		return Node{}, err
	}
	if !u.Root {
		return Node{}, fmt.Errorf("%s is not an instance root: its umbrella.yaml doesn't set root: true", root)
	}
	gitDir, err := git.Run(ctx, root, "rev-parse", "--absolute-git-dir")
	if err != nil {
		return Node{}, err
	}
	return Node{Dir: root, GitDir: gitDir, Kind: schema.ChildUmbrella, Owner: u.Owner, Visibility: u.Visibility,
		Umbrella: u, Present: true}, nil
}

// child returns parent's child at path p, checking it out first if checkout is set.
func child(ctx context.Context, parent Node, p string, checkout bool) (Node, error) {
	rec := parent.Umbrella.Children[p]
	name, url, err := submodule(ctx, parent.Dir, p)
	if err != nil {
		return Node{}, err
	}
	if err := git.CheckURL(url); err != nil {
		return Node{}, fmt.Errorf("%s: submodule %s: %w", filepath.Join(parent.Dir, ".gitmodules"), p, err)
	}
	st, err := git.Run(ctx, parent.Dir, "submodule", "status", "--", p)
	if err != nil {
		return Node{}, err
	}
	present := !strings.HasPrefix(st, "-")
	if !present && checkout {
		// Only this submodule, and not recursively (spec §3.3 rules 5 and 6).
		if _, err := git.Run(ctx, parent.Dir, "submodule", "update", "--init", "--", p); err != nil {
			return Node{}, err
		}
		present = true
	}
	n := Node{Path: filepath.Join(parent.Path, p), Dir: filepath.Join(parent.Dir, p),
		GitDir: filepath.Join(parent.GitDir, "modules", name), Kind: rec.Kind, Owner: rec.Owner,
		Visibility: rec.Visibility, Present: present}
	if present && rec.Kind == schema.ChildUmbrella {
		if n.Umbrella, err = schema.LoadUmbrella(n.Dir); err != nil {
			return Node{}, fmt.Errorf("%s is listed as an umbrella: %w", n.Path, err)
		}
	}
	return n, nil
}

// submodule returns the name and URL that dir's .gitmodules records for path p.
func submodule(ctx context.Context, dir, p string) (name, url string, err error) {
	out, err := git.Run(ctx, dir, "config", "-f", ".gitmodules", "--get-regexp", `^submodule\..*\.path$`)
	if err != nil && !strings.Contains(err.Error(), "exit status 1") { // exit 1: no submodules at all
		return "", "", err
	}
	for _, line := range strings.Split(out, "\n") {
		key, value, _ := strings.Cut(line, " ")
		if value == p {
			name = strings.TrimSuffix(strings.TrimPrefix(key, "submodule."), ".path")
		}
	}
	if name == "" {
		return "", "", fmt.Errorf("the umbrella %s lists %s as a child, but has no submodule there", dir, p)
	}
	url, err = git.Run(ctx, dir, "config", "-f", ".gitmodules", "--get", "submodule."+name+".url")
	return name, url, err
}
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T045: walking the whole tree

`tree.Walk` visits every node without checking anything out, for `ygg doctor`; the deeper-tree
fixture proves the walker has no fixed depth (spec §3.1).

**Files (in `odin`):**
- Modify: `internal/tree/tree.go`, `internal/tree/tree_test.go`, `internal/tree/treetest/treetest.go`

**Interfaces:**
- Produces: `tree.Walk(ctx, root, fn func(Node) error) error`, and `treetest.Deep()`.

**Acceptance criteria:**
- [ ] `Resolve` walks the deeper fixture, a company umbrella → project → `services/backend` →
      `repos/api`, and `FindRoot` finds the root from that leaf.
- [ ] `Walk` visits checked-out nodes in path order, reports the others with `Present` false, enters
      none of them and checks nothing out; a public project's private leaf shows in `Leaks`.
- [ ] A child an umbrella lists but `.gitmodules` lacks is refused.

**Named test:** `go test ./internal/tree/`. **Layer:** `odin`. **Size:** M (107). **Depends on:**
v0-T044.

- [ ] **Step 1:** apply to `internal/tree/treetest/treetest.go`:

```diff
diff --git a/internal/tree/treetest/treetest.go b/internal/tree/treetest/treetest.go
index da6385d..9de5827 100644
--- a/internal/tree/treetest/treetest.go
+++ b/internal/tree/treetest/treetest.go
@@ -38,6 +38,15 @@ func Standard() Node {
 		}}
 }
 
+// Deep has an extra umbrella level: company → projects/gallery → services/backend → repos/api
+// (spec §3.1).
+func Deep() Node {
+	return Node{Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Children: map[string]Node{
+		"projects/gallery": {Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Children: map[string]Node{
+			"services/backend": {Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Children: map[string]Node{
+				"repos/api": {Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Leaf: true}}}}}}}
+}
+
 // Build makes the tree's repos and returns the path of a fresh clone of the root, with no
 // submodule initialised.
 func Build(t *testing.T, root Node) string {
```

and to `internal/tree/tree_test.go`:

```diff
diff --git a/internal/tree/tree_test.go b/internal/tree/tree_test.go
index c29b302..a6f3975 100644
--- a/internal/tree/tree_test.go
+++ b/internal/tree/tree_test.go
@@ -56,6 +56,24 @@ func TestResolveChecksOutOnlyThePath(t *testing.T) {
 	}
 }
 
+func TestResolveWalksADeeperTree(t *testing.T) {
+	root := treetest.Build(t, treetest.Deep())
+	nodes, err := Resolve(ctx, root, "projects/gallery/services/backend/repos/api")
+	if err != nil {
+		t.Fatalf("Resolve() = %v", err)
+	}
+	kinds := []schema.ChildKind{}
+	for _, n := range nodes {
+		kinds = append(kinds, n.Kind)
+	}
+	if !slices.Equal(kinds, []schema.ChildKind{schema.ChildUmbrella, schema.ChildUmbrella, schema.ChildUmbrella, schema.ChildLeaf}) {
+		t.Errorf("kinds = %v, want three umbrellas and a leaf", kinds)
+	}
+	if got, rel, err := FindRoot(ctx, nodes[3].Dir); err != nil || got != root || rel != "projects/gallery/services/backend/repos/api" {
+		t.Errorf("FindRoot(leaf) = %q, %q, %v", got, rel, err)
+	}
+}
+
 func TestFindRoot(t *testing.T) {
 	root := treetest.Build(t, treetest.Standard())
 	if _, err := Resolve(ctx, root, "projects/gallery"); err != nil {
@@ -114,3 +132,54 @@ func TestResolveRefusesAMaliciousSubmoduleURL(t *testing.T) {
 		t.Error("the URL's command ran")
 	}
 }
+
+func TestResolveRefusesAChildMissingFromGitmodules(t *testing.T) {
+	root := treetest.Build(t, treetest.Standard())
+	u, err := schema.LoadUmbrella(root)
+	if err != nil {
+		t.Fatal(err)
+	}
+	u.Children["projects/blog"] = schema.Child{Kind: schema.ChildUmbrella, Owner: "o", Visibility: "private"}
+	if err := u.Save(root); err != nil {
+		t.Fatal(err)
+	}
+	if _, err := Resolve(ctx, root, "projects/blog"); err == nil || !strings.Contains(err.Error(), "no submodule") {
+		t.Errorf("Resolve() = %v, want no submodule at projects/blog", err)
+	}
+}
+
+func TestWalkVisitsInitialisedNodesAndReportsLeaks(t *testing.T) {
+	root := treetest.Build(t, treetest.Standard())
+	if _, err := Resolve(ctx, root, "projects/site/repos/www"); err != nil {
+		t.Fatal(err)
+	}
+	var visited, absent, leaks []string
+	err := Walk(ctx, root, func(n Node) error {
+		if !n.Present {
+			absent = append(absent, n.Path)
+			return nil
+		}
+		visited = append(visited, n.Path)
+		if n.Umbrella != nil {
+			for _, l := range n.Umbrella.Leaks() {
+				leaks = append(leaks, filepath.Join(n.Path, l))
+			}
+		}
+		return nil
+	})
+	if err != nil {
+		t.Fatal(err)
+	}
+	if !slices.Equal(visited, []string{"", "projects/site", "projects/site/repos/www"}) {
+		t.Errorf("visited %q", visited)
+	}
+	if !slices.Equal(absent, []string{"projects/gallery"}) {
+		t.Errorf("not checked out: %q, want projects/gallery (Walk initialises nothing)", absent)
+	}
+	if !slices.Equal(leaks, []string{"projects/site/repos/www"}) {
+		t.Errorf("leaks = %q, want the private leaf of the public project", leaks)
+	}
+	if initialised(t, root, "projects/gallery") {
+		t.Error("Walk initialised a submodule")
+	}
+}
```

- [ ] **Step 2:** run `go test ./internal/tree/`; expect a build failure: `undefined: Walk`.
- [ ] **Step 3:** apply to `internal/tree/tree.go`:

```diff
diff --git a/internal/tree/tree.go b/internal/tree/tree.go
index 567df1f..2bd7eed 100644
--- a/internal/tree/tree.go
+++ b/internal/tree/tree.go
@@ -105,6 +105,35 @@ func Resolve(ctx context.Context, root, rel string) ([]Node, error) {
 	return nodes, nil
 }
 
+// Walk calls fn for every node of the tree, depth first, children in path order. It checks out
+// nothing: a child that isn't checked out is visited with Present false, and not entered.
+func Walk(ctx context.Context, root string, fn func(Node) error) error {
+	top, err := rootNode(ctx, root)
+	if err != nil {
+		return err
+	}
+	return walk(ctx, top, fn)
+}
+
+func walk(ctx context.Context, n Node, fn func(Node) error) error {
+	if err := fn(n); err != nil {
+		return err
+	}
+	if n.Umbrella == nil {
+		return nil
+	}
+	for _, p := range n.Umbrella.Paths() {
+		c, err := child(ctx, n, p, false)
+		if err != nil {
+			return err
+		}
+		if err := walk(ctx, c, fn); err != nil {
+			return err
+		}
+	}
+	return nil
+}
+
 func rootNode(ctx context.Context, root string) (Node, error) {
 	root, err := filepath.Abs(root)
 	if err != nil {
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T046: the local remote

The Odin half of `remote-creates-repos-T001`, its remote (decision 5).

**Files (in `odin`):**
- Create: `internal/remote/local.go`, `internal/remote/local_test.go`

**Interfaces:**
- Consumes: `gungnir.Remote`, `gungnir.Repo` (v0-T039); `tree.Node`, `tree.Resolve`, `treetest`
  (v0-T044).
- Produces: `remote.NewLocal(parent tree.Node) *remote.Local`, a `gungnir.Remote` named `local`.

**Acceptance criteria:**
- [ ] `Create` makes a leaf at the path, whose one commit holds the first-commit files and nothing
      else; its git dir is in the parent's `.git/modules`; the parent's `umbrella.yaml` lists it with
      its owner and visibility, and the parent has one commit for it and nothing uncommitted.
- [ ] `Create` refuses a path that exists, a leaf or a plain directory, and creates nothing; it
      refuses a repo `Validate` refuses.
- [ ] `Protect` reports that it doesn't apply, and changes nothing.

**Named test:** `go test ./internal/remote/ -run 'TestLocalCreateMakesLeafWithFirstCommit|TestLocalCreateRefusesExistingPath|TestLocalProtectDoesNotApply'`
(the change's named tests are the first two). **Layer:** `odin`. **Size:** M (217). **Depends on:**
v0-T044.

- [ ] **Step 1:** write `internal/remote/local_test.go`:

```go
package remote

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/tree"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

var ctx = context.Background()

// gallery returns the instance root and its projects/gallery umbrella, checked out.
func gallery(t *testing.T) (string, tree.Node) {
	t.Helper()
	root := treetest.Build(t, treetest.Standard())
	nodes, err := tree.Resolve(ctx, root, "projects/gallery")
	if err != nil {
		t.Fatal(err)
	}
	return root, nodes[1]
}

func blog() gungnir.Repo {
	return gungnir.Repo{Owner: "ouroboric-dev", Name: "gallery-blog", Visibility: gungnir.VisibilityPrivate,
		Description: "the gallery's blog", Path: "repos/blog",
		Files: map[string][]byte{"LICENSE": []byte("AGPL-3.0-only\n"), "LICENSES/AGPL-3.0-only.txt": []byte("...\n")}}
}

func TestLocalCreateMakesLeafWithFirstCommit(t *testing.T) {
	root, parent := gallery(t)
	before, _ := git.Run(ctx, parent.Dir, "rev-parse", "HEAD")
	if err := NewLocal(parent).Create(ctx, blog()); err != nil {
		t.Fatalf("Create() = %v", err)
	}
	nodes, err := tree.Resolve(ctx, root, "projects/gallery/repos/blog")
	if err != nil {
		t.Fatalf("the new leaf isn't in the tree: %v", err)
	}
	leaf := nodes[2]
	if leaf.Kind != schema.ChildLeaf || leaf.Owner != "ouroboric-dev" || leaf.Visibility != gungnir.VisibilityPrivate {
		t.Errorf("leaf = %+v", leaf)
	}
	repo := git.Repo{GitDir: leaf.GitDir, WorkTree: leaf.Dir}
	if files, _ := repo.Run(ctx, "ls-tree", "-r", "--name-only", "HEAD"); files != "LICENSE\nLICENSES/AGPL-3.0-only.txt" {
		t.Errorf("the first commit holds %q, want the two first-commit files and nothing else", files)
	}
	if n, _ := repo.Run(ctx, "rev-list", "--count", "HEAD"); n != "1" {
		t.Errorf("the leaf has %s commits, want 1", n)
	}
	if st, err := os.Stat(filepath.Join(leaf.Dir, ".git")); err != nil || st.IsDir() {
		t.Errorf("the leaf's .git must be a file pointing into the parent's .git/modules (stat: %v)", err)
	}
	if _, err := os.Stat(filepath.Join(leaf.GitDir, "HEAD")); err != nil {
		t.Errorf("the leaf's git dir isn't in its parent's .git/modules: %v", err)
	}
	after, _ := git.Run(ctx, parent.Dir, "rev-parse", "HEAD")
	if after == before {
		t.Error("the parent umbrella has no commit recording the new leaf")
	}
	if st, _ := git.Run(ctx, parent.Dir, "status", "--porcelain"); st != "" {
		t.Errorf("the parent umbrella has uncommitted changes:\n%s", st)
	}
	if msg, _ := git.Run(ctx, parent.Dir, "log", "-1", "--format=%s"); !strings.Contains(msg, "repos/blog") {
		t.Errorf("the parent's commit message %q doesn't name the leaf", msg)
	}
}

func TestLocalCreateRefusesExistingPath(t *testing.T) {
	_, parent := gallery(t)
	plain := filepath.Join(parent.Dir, "repos", "notes")
	if err := os.MkdirAll(plain, 0o755); err != nil {
		t.Fatal(err)
	}
	before, _ := git.Run(ctx, parent.Dir, "rev-parse", "HEAD")
	for _, path := range []string{"repos/api", "repos/notes"} {
		r := blog()
		r.Path = path
		if err := NewLocal(parent).Create(ctx, r); err == nil || !strings.Contains(err.Error(), "exists") {
			t.Errorf("Create(%s) = %v, want a refusal because it exists", path, err)
		}
	}
	if after, _ := git.Run(ctx, parent.Dir, "rev-parse", "HEAD"); after != before {
		t.Error("a refused Create committed in the parent")
	}
	if st, _ := git.Run(ctx, parent.Dir, "status", "--porcelain", "--untracked-files=no"); st != "" {
		t.Errorf("a refused Create changed the parent:\n%s", st)
	}
	r := blog()
	r.Files = nil
	if err := NewLocal(parent).Create(ctx, r); err == nil {
		t.Error("Create() accepted a repo without first-commit files")
	}
}

func TestLocalProtectDoesNotApply(t *testing.T) {
	_, parent := gallery(t)
	before, _ := git.Run(ctx, parent.Dir, "rev-parse", "HEAD")
	applied, err := NewLocal(parent).Protect(ctx, blog())
	if err != nil || applied {
		t.Errorf("Protect() = %v, %v; want false, nil: a local repo has no settings or rulesets", applied, err)
	}
	if after, _ := git.Run(ctx, parent.Dir, "rev-parse", "HEAD"); after != before {
		t.Error("Protect() changed the parent")
	}
}
```

- [ ] **Step 2:** run `go test ./internal/remote/`; expect a build failure: `undefined: NewLocal`.
- [ ] **Step 3:** write `internal/remote/local.go`:

```go
// Package remote holds Odin's remotes (spec §2.2; change remote-creates-repos). v0 has the local
// remote; the github remote is iteration 2.
package remote

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"slices"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/tree"
)

// Local creates repos in place, in an umbrella of the instance tree on this host. It needs no
// admin rights, so no repo-admin approval: the plan's approval covers it.
type Local struct {
	parent tree.Node // the umbrella new repos are created in
}

var _ gungnir.Remote = (*Local)(nil)

// NewLocal returns the local remote for the umbrella parent.
func NewLocal(parent tree.Node) *Local { return &Local{parent: parent} }

func (l *Local) Name() string { return "local" }

// Create makes r a leaf of the umbrella: a new repo at r.Path whose one commit holds r.Files, added
// as a submodule with its git dir moved into the umbrella's .git/modules, and recorded in the
// umbrella's umbrella.yaml. The umbrella gets one commit for it. The submodule's URL is the
// relative path, so the leaf lives on this host only.
func (l *Local) Create(ctx context.Context, r gungnir.Repo) error {
	if err := r.Validate(); err != nil {
		return err
	}
	p := l.parent
	if p.Kind != schema.ChildUmbrella || p.Umbrella == nil {
		return fmt.Errorf("%s is not a checked-out umbrella", p.Path)
	}
	dir := filepath.Join(p.Dir, r.Path)
	if _, err := os.Lstat(dir); !errors.Is(err, fs.ErrNotExist) {
		return fmt.Errorf("%s exists, so nothing was created", dir)
	}
	if _, listed := p.Umbrella.Children[r.Path]; listed {
		return fmt.Errorf("the umbrella %q already lists %s, so nothing was created", p.Path, r.Path)
	}
	if err := firstCommit(ctx, dir, r); err != nil {
		return fmt.Errorf("creating %s: %w (remove %s before trying again)", r.Path, err, dir)
	}
	steps := [][]string{
		{"submodule", "add", "-q", "./" + r.Path, r.Path},
		{"submodule", "absorbgitdirs", "--", r.Path},
	}
	for _, s := range steps {
		if _, err := git.Run(ctx, p.Dir, s...); err != nil {
			return fmt.Errorf("adding %s to %q: %w", r.Path, p.Path, err)
		}
	}
	p.Umbrella.Children[r.Path] = schema.Child{Kind: schema.ChildLeaf, Owner: r.Owner, Visibility: r.Visibility}
	if err := p.Umbrella.Save(p.Dir); err != nil {
		return err
	}
	if _, err := git.Run(ctx, p.Dir, "add", "--", ".gitmodules", schema.UmbrellaFile, r.Path); err != nil {
		return err
	}
	msg := fmt.Sprintf("Create leaf %s (%s/%s, %s)", r.Path, r.Owner, r.Name, r.Visibility)
	_, err := git.Run(ctx, p.Dir, "commit", "-q", "-m", msg, "--", ".gitmodules", schema.UmbrellaFile, r.Path)
	return err
}

// firstCommit makes the repo at dir with one commit holding r.Files.
func firstCommit(ctx context.Context, dir string, r gungnir.Repo) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	if _, err := git.Run(ctx, dir, "init", "-q"); err != nil {
		return err
	}
	paths := make([]string, 0, len(r.Files))
	for f := range r.Files {
		paths = append(paths, f)
	}
	slices.Sort(paths)
	for _, f := range paths { // Validate keeps every path inside dir and outside .git
		if err := os.MkdirAll(filepath.Dir(filepath.Join(dir, f)), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(filepath.Join(dir, f), r.Files[f], 0o644); err != nil {
			return err
		}
	}
	if _, err := git.Run(ctx, dir, append([]string{"add", "--"}, paths...)...); err != nil {
		return err
	}
	_, err := git.Run(ctx, dir, "commit", "-q", "-m", "First commit: "+r.Description)
	return err
}

// Protect does nothing: a repo on this host has no settings or rulesets to apply.
func (l *Local) Protect(ctx context.Context, r gungnir.Repo) (bool, error) { return false, nil }
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T047: leaf branches, checkpoints and resets

Host git on a leaf (decisions 8 and 9): a run's branch, checkpoint commits, and resets. Nothing in a
leaf is trusted.

**Files (in `odin`):**
- Create: `internal/leaf/leaf.go`, `internal/leaf/leaf_test.go`

**Interfaces:**
- Consumes: `tree.Node` (v0-T044), `git.Repo` (v0-T043).
- Produces: `leaf.Open(tree.Node) (*leaf.Leaf, error)`; on `*Leaf`: `Dir()`, `Head(ctx)`,
  `Rev(ctx, ref)`, `Git(ctx, args...)`, `StartBranch(ctx, branch, from) (string, error)`,
  `Checkpoint(ctx, msg) (head string, committed bool, err error)` and
  `Reset(ctx, branch, sha) error`; `leaf.PolicyError` and `leaf.IsPolicy(err) bool`.

**Acceptance criteria:**
- [ ] A checkpoint commits the leaf's work on the branch it has checked out; with nothing changed it
      commits nothing and returns the head.
- [ ] A checkpoint refuses, as a `*PolicyError`, a nested git repository built from plain file
      writes (with a `.gitmodules` whose URL runs a command) and a `.git` file pointing elsewhere: it
      commits and stages nothing, and the command never runs.
- [ ] `Reset` puts the leaf back to a commit on the run's branch: changes, untracked and ignored
      files are gone, the branch is checked out again, and the `.git` file is restored.
- [ ] `StartBranch` refuses a leaf with uncommitted changes, and leaves them as they are (review
      focus 2).

**Named test:** `go test ./internal/leaf/`. **Layer:** `odin`. **Size:** M (330). **Depends on:**
v0-T044.

- [ ] **Step 1:** write `internal/leaf/leaf_test.go`:

```go
package leaf

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/tree"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

var ctx = context.Background()

// api returns the api leaf of the standard fixture, on a fresh run branch.
func api(t *testing.T) *Leaf {
	t.Helper()
	root := treetest.Build(t, treetest.Standard())
	nodes, err := tree.Resolve(ctx, root, "projects/gallery/repos/api")
	if err != nil {
		t.Fatal(err)
	}
	l, err := Open(nodes[2])
	if err != nil {
		t.Fatal(err)
	}
	if _, err := l.StartBranch(ctx, "ygg/run1", "main"); err != nil {
		t.Fatal(err)
	}
	return l
}

func write(t *testing.T, l *Leaf, path, body string) {
	t.Helper()
	p := filepath.Join(l.Dir(), path)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestCheckpointCommitsTheLeafsWork(t *testing.T) {
	l := api(t)
	base, _ := l.Head(ctx)
	write(t, l, "src/app.go", "package app\n")
	sha, committed, err := l.Checkpoint(ctx, "ygg: run1 node build attempt 1")
	if err != nil || !committed {
		t.Fatalf("Checkpoint() = %s, %v, %v", sha, committed, err)
	}
	if sha == base {
		t.Error("the checkpoint is the old head")
	}
	if b, _ := l.repo.Run(ctx, "rev-parse", "--abbrev-ref", "HEAD"); b != "ygg/run1" {
		t.Errorf("the checkpoint is on %q, want the run branch", b)
	}
	if files, _ := l.repo.Run(ctx, "show", "--name-only", "--format=", sha); files != "src/app.go" {
		t.Errorf("the checkpoint holds %q", files)
	}
	again, committed, err := l.Checkpoint(ctx, "nothing new")
	if err != nil || committed || again != sha {
		t.Errorf("a checkpoint with no change = %s, %v, %v; want the same head, no commit", again, committed, err)
	}
}

func TestCheckpointRefusesANestedRepository(t *testing.T) {
	l := api(t)
	before, _ := l.Head(ctx)
	marker := filepath.Join(t.TempDir(), "pwned")
	// What an agent can do with file writes alone: a submodule entry with a command as its URL,
	// and the pieces of a git directory under it.
	write(t, l, ".gitmodules", "[submodule \"x\"]\n\tpath = vendor/x\n\turl = ext::sh -c touch% "+marker+"\n")
	write(t, l, "vendor/x/.git/HEAD", "ref: refs/heads/main\n")
	write(t, l, "vendor/x/.git/objects/.keep", "")
	write(t, l, "vendor/x/.git/refs/heads/.keep", "")
	_, _, err := l.Checkpoint(ctx, "a nested repo")
	var pe *PolicyError
	if !errors.As(err, &pe) || !strings.Contains(err.Error(), "vendor/x") {
		t.Fatalf("Checkpoint() = %v, want a *PolicyError naming vendor/x", err)
	}
	if after, _ := l.Head(ctx); after != before {
		t.Error("the refused checkpoint committed")
	}
	if staged, _ := l.repo.Run(ctx, "diff", "--cached", "--name-only"); staged != "" {
		t.Errorf("the refused checkpoint left files staged: %q", staged)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Error("the submodule URL's command ran")
	}
}

func TestCheckpointRefusesAChangedGitFile(t *testing.T) {
	l := api(t)
	evil := t.TempDir()
	write(t, l, ".git", "gitdir: "+evil+"\n")
	_, _, err := l.Checkpoint(ctx, "after a .git swap")
	var pe *PolicyError
	if !errors.As(err, &pe) || !strings.Contains(err.Error(), ".git") {
		t.Fatalf("Checkpoint() = %v, want a *PolicyError about .git", err)
	}
	entries, _ := os.ReadDir(evil)
	if len(entries) != 0 {
		t.Error("git wrote to the planted git dir")
	}
}

func TestResetGoesBackToTheCheckpoint(t *testing.T) {
	l := api(t)
	write(t, l, ".gitignore", "build/\n")
	write(t, l, "keep.txt", "kept\n")
	cp, _, err := l.Checkpoint(ctx, "checkpoint")
	if err != nil {
		t.Fatal(err)
	}
	write(t, l, "keep.txt", "changed\n")
	write(t, l, "new.txt", "untracked\n")
	write(t, l, "build/out.bin", "ignored\n")
	write(t, l, ".git", "gitdir: /tmp/elsewhere\n")
	if _, err := l.repo.Run(ctx, "switch", "-q", "-c", "elsewhere"); err != nil {
		t.Fatal(err)
	}
	if err := l.Reset(ctx, "ygg/run1", cp); err != nil {
		t.Fatalf("Reset() = %v", err)
	}
	if b, _ := os.ReadFile(filepath.Join(l.Dir(), "keep.txt")); string(b) != "kept\n" {
		t.Errorf("keep.txt = %q, want the checkpoint's", b)
	}
	for _, gone := range []string{"new.txt", "build/out.bin"} {
		if _, err := os.Stat(filepath.Join(l.Dir(), gone)); err == nil {
			t.Errorf("%s survived the reset", gone)
		}
	}
	if head, _ := l.Head(ctx); head != cp {
		t.Errorf("HEAD = %s, want the checkpoint %s", head, cp)
	}
	if b, _ := l.repo.Run(ctx, "rev-parse", "--abbrev-ref", "HEAD"); b != "ygg/run1" {
		t.Errorf("after the reset the leaf is on %q, want the run branch", b)
	}
	if _, _, err := l.Checkpoint(ctx, "after the reset"); err != nil {
		t.Errorf("the reset didn't restore the leaf's .git: %v", err)
	}
}

func TestStartBranchRefusesALeafWithChanges(t *testing.T) {
	root := treetest.Build(t, treetest.Standard())
	nodes, err := tree.Resolve(ctx, root, "projects/gallery/repos/api")
	if err != nil {
		t.Fatal(err)
	}
	l, err := Open(nodes[2])
	if err != nil {
		t.Fatal(err)
	}
	write(t, l, "README.md", "edited by hand\n")
	if _, err := l.StartBranch(ctx, "ygg/run1", "main"); err == nil || !strings.Contains(err.Error(), "uncommitted") {
		t.Errorf("StartBranch() = %v, want a refusal: a run never discards work it didn't make", err)
	}
	if _, err := Open(nodes[1]); err == nil {
		t.Error("Open() accepted an umbrella as a leaf")
	}
	if out, _ := git.Run(ctx, nodes[1].Dir, "status", "--porcelain"); !strings.Contains(out, "repos/api") {
		t.Errorf("the hand edit is gone: %q", out)
	}
}
```

- [ ] **Step 2:** run `go test ./internal/leaf/`; expect a build failure: `undefined: Leaf`.
- [ ] **Step 3:** write `internal/leaf/leaf.go`:

```go
// Package leaf runs host git on a leaf (spec §3.3, §4.3): the run's branch, checkpoint commits and
// resets. Agents work in a leaf, so nothing in it is trusted: git always gets the git dir Odin
// found in the tree, and a checkpoint refuses a planted git repository or a rewritten .git file.
package leaf

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/tree"
)

// Leaf is a leaf's working copy and the git dir its parent umbrella holds for it.
type Leaf struct {
	repo git.Repo
}

// PolicyError is work in a leaf that breaks a sandbox rule. Odin commits none of it, and the run
// stops at the hard approval point policy-violation.
type PolicyError struct{ Reason string }

func (e *PolicyError) Error() string { return "policy violation: " + e.Reason }

// Open returns the leaf of a checked-out leaf node.
func Open(n tree.Node) (*Leaf, error) {
	if n.Kind != schema.ChildLeaf || !n.Present {
		return nil, fmt.Errorf("%s is not a checked-out leaf", n.Path)
	}
	return &Leaf{repo: git.Repo{GitDir: n.GitDir, WorkTree: n.Dir}}, nil
}

// Dir is the leaf's working copy.
func (l *Leaf) Dir() string { return l.repo.WorkTree }

// Head returns the commit the leaf has checked out.
func (l *Leaf) Head(ctx context.Context) (string, error) { return l.Rev(ctx, "HEAD") }

// Rev returns the commit ref names.
func (l *Leaf) Rev(ctx context.Context, ref string) (string, error) {
	return l.repo.Run(ctx, "rev-parse", "--verify", "--quiet", ref+"^{commit}")
}

// Git runs git on the leaf.
func (l *Leaf) Git(ctx context.Context, args ...string) (string, error) {
	return l.repo.Run(ctx, args...)
}

// StartBranch creates branch at from and checks it out. It refuses a leaf with uncommitted
// changes, so a run never discards work it didn't make.
func (l *Leaf) StartBranch(ctx context.Context, branch, from string) (string, error) {
	if err := l.checkGitFile(); err != nil {
		return "", err
	}
	if st, err := l.repo.Run(ctx, "status", "--porcelain"); err != nil {
		return "", err
	} else if st != "" {
		return "", fmt.Errorf("the leaf %s has uncommitted changes; commit or remove them first:\n%s", l.Dir(), st)
	}
	if _, err := l.repo.Run(ctx, "switch", "-q", "-c", branch, from); err != nil {
		return "", err
	}
	return l.Head(ctx)
}

// Checkpoint commits everything in the leaf to the branch it is on, and returns the head. It
// commits nothing, and committed is false, when nothing changed. A nested git repository or a
// rewritten .git file is a *PolicyError, and nothing is committed.
func (l *Leaf) Checkpoint(ctx context.Context, msg string) (head string, committed bool, err error) {
	if err := l.checkGitFile(); err != nil {
		return "", false, err
	}
	if err := l.checkNested(); err != nil {
		return "", false, err
	}
	if _, err := l.repo.Run(ctx, "add", "-A"); err != nil {
		return "", false, err
	}
	if _, err := l.repo.Run(ctx, "diff", "--cached", "--quiet"); err == nil {
		head, err := l.Head(ctx)
		return head, false, err
	}
	if _, err := l.repo.Run(ctx, "commit", "-q", "-m", msg); err != nil {
		return "", false, err
	}
	head, err = l.Head(ctx)
	return head, true, err
}

// Reset puts the leaf back to commit sha on branch: the branch is moved to sha and checked out,
// changes and untracked files (ignored ones too) are removed, and the .git file is restored.
func (l *Leaf) Reset(ctx context.Context, branch, sha string) error {
	if err := l.restoreGitFile(); err != nil {
		return err
	}
	if _, err := l.repo.Run(ctx, "switch", "-q", "-f", "-C", branch, sha); err != nil {
		return err
	}
	_, err := l.repo.Run(ctx, "clean", "-q", "-ffdx")
	return err
}

// checkGitFile refuses a leaf whose .git no longer points at the git dir Odin holds for it.
func (l *Leaf) checkGitFile() error {
	b, err := os.ReadFile(filepath.Join(l.Dir(), ".git"))
	if err != nil {
		return &PolicyError{fmt.Sprintf("the leaf's .git is not the file git made: %v", err)}
	}
	target, ok := strings.CutPrefix(strings.TrimSpace(string(b)), "gitdir: ")
	if !ok {
		return &PolicyError{"the leaf's .git file was changed"}
	}
	if !filepath.IsAbs(target) {
		target = filepath.Join(l.Dir(), target)
	}
	got, err1 := filepath.EvalSymlinks(target)
	want, err2 := filepath.EvalSymlinks(l.repo.GitDir)
	if err1 != nil || err2 != nil || got != want {
		return &PolicyError{fmt.Sprintf("the leaf's .git file points at %s, not %s", target, l.repo.GitDir)}
	}
	return nil
}

func (l *Leaf) restoreGitFile() error {
	rel, err := filepath.Rel(l.Dir(), l.repo.GitDir)
	if err != nil {
		return err
	}
	p := filepath.Join(l.Dir(), ".git")
	if st, err := os.Lstat(p); err == nil && st.IsDir() {
		return &PolicyError{"the leaf's .git is a directory"}
	}
	return os.WriteFile(p, []byte("gitdir: "+rel+"\n"), 0o644)
}

// checkNested refuses any .git below the leaf's top level: an agent can build a repository from
// plain file writes, and git would record it as a submodule (spec §3.3 rule 5).
func (l *Leaf) checkNested() error {
	top := filepath.Join(l.Dir(), ".git")
	return filepath.WalkDir(l.Dir(), func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Name() != ".git" || p == top {
			return nil
		}
		rel, _ := filepath.Rel(l.Dir(), filepath.Dir(p))
		return &PolicyError{fmt.Sprintf("the leaf %s holds a git repository at %s", l.Dir(), rel)}
	})
}

// IsPolicy reports whether err is a *PolicyError.
func IsPolicy(err error) bool {
	var pe *PolicyError
	return errors.As(err, &pe)
}
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T048: the shrink guard

Spec §8.3: a generated file committed at a pointer move is refused when it has fewer than half of its
previous version's rows (decision 13).

**Files (in `odin`):**
- Create: `internal/shrink/shrink.go`, `internal/shrink/shrink_test.go`

**Interfaces:**
- Produces: `shrink.Check(path string, prev, next []byte) error` (a `*shrink.Error{Path; Old, New
  int}`), and `shrink.Rows([]byte) int`.

**Acceptance criteria:**
- [ ] A new file, growth, and exactly half pass; under half, an emptied file and a deleted one are
      refused; blank lines aren't rows; the refusal names the file and both counts.

**Named test:** `go test ./internal/shrink/`. **Layer:** `odin`. **Size:** S (79). **Depends on:**
v0-T043.

- [ ] **Step 1:** write `internal/shrink/shrink_test.go`:

```go
package shrink

import (
	"errors"
	"strings"
	"testing"
)

func rows(n int) []byte { return []byte(strings.Repeat("| row |\n", n)) }

func TestShrinkGuard(t *testing.T) {
	cases := []struct {
		name     string
		old, new []byte
		refused  bool
	}{
		{"a new file", nil, rows(3), false},
		{"growth", rows(10), rows(12), false},
		{"exactly half", rows(10), rows(5), false},
		{"under half", rows(10), rows(4), true},
		{"emptied", rows(10), []byte("\n\n"), true},
		{"deleted", rows(10), nil, true},
		{"blank lines aren't rows", []byte("a\n\n\nb\n\n"), []byte("a\n"), false},
		{"an old file with no rows", []byte("\n"), nil, false},
	}
	for _, c := range cases {
		err := Check("REPOS.md", c.old, c.new)
		var se *Error
		if c.refused != errors.As(err, &se) {
			t.Errorf("%s: Check() = %v, refused want %v", c.name, err, c.refused)
		}
	}
	err := Check("REPOS.md", rows(10), rows(4))
	if err == nil || !strings.Contains(err.Error(), "REPOS.md") || !strings.Contains(err.Error(), "4 of its 10 rows") {
		t.Errorf("the refusal doesn't say what shrank: %v", err)
	}
}
```

- [ ] **Step 2:** run `go test ./internal/shrink/`; expect a build failure: `undefined: Check`.
- [ ] **Step 3:** write `internal/shrink/shrink.go`:

```go
// Package shrink is the shrink guard (spec §8.3): a generated file committed at a pointer move,
// such as REPOS.md or a routing index, is refused when it has fewer than half of its previous
// version's rows. A buggy generator that empties an index then stops the move for a person,
// instead of merging the loss at every level.
package shrink

import (
	"bytes"
	"fmt"
)

// Error is a refused generated file. It stops the pointer move at the hard approval point
// shrink-guard.
type Error struct {
	Path     string
	Old, New int // rows before and after
}

func (e *Error) Error() string {
	return fmt.Sprintf("shrink guard: %s keeps %d of its %d rows, under half; a person decides whether the move goes ahead", e.Path, e.New, e.Old)
}

// Rows counts a file's rows: its lines that aren't blank.
func Rows(b []byte) int {
	n := 0
	for _, line := range bytes.Split(b, []byte("\n")) {
		if len(bytes.TrimSpace(line)) > 0 {
			n++
		}
	}
	return n
}

// Check refuses next if it has fewer than half of prev's rows. A file that is new, or whose last
// version had no rows, always passes. A deleted file has no rows.
func Check(path string, prev, next []byte) error {
	o, n := Rows(prev), Rows(next)
	if 2*n < o {
		return &Error{Path: path, Old: o, New: n}
	}
	return nil
}
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T049: locks and the merge gate

Spec §4.5 and decision 12, with both of its tests from spec §13. The lock package is Phase 1's flock
lock made general; `Held` reads `/proc/locks` (decision 10).

**Files (in `odin`):**
- Create: `internal/lock/lock.go`, `internal/lock/lock_test.go`, `internal/merge/merge.go`,
  `internal/merge/merge_test.go`

**Interfaces:**
- Consumes: `leaf.Leaf` (v0-T047).
- Produces: `lock.Take(path) (release func(), err error)`, `lock.Held(path) bool`, `lock.ErrHeld`;
  `merge.Spec{Leaf *leaf.Leaf; Branch, Base, Lock string; Check func(ctx) error}`,
  `merge.Land(ctx, Spec) (merge.Result, error)` with `Result{Base, Checked, Merged string}`, and
  `merge.Refused{Why string; Err error}` with `WhyConflict`, `WhyChecks`, `WhyMoved`.

**Acceptance criteria:**
- [ ] One holder at a time; `Take` creates the lock's directory; `Held` neither takes the lock nor
      creates the file, so a `Take` right after it never fails (review focus 5).
- [ ] Spec §13: a branch that passed against an old base but fails against the new one doesn't merge,
      and `main` stays where it was.
- [ ] Spec §13: a head that moved after the checks aborts, and `main` doesn't move.
- [ ] A clean landing moves `main` to the commit the checks ran on, which holds both the branch and
      the new base, and releases the lock.
- [ ] A conflict aborts the merge and leaves the branch as it was; a held lock is `lock.ErrHeld`, and
      nothing moves.

**Named test:** `go test ./internal/lock/ ./internal/merge/`. **Layer:** `odin`. **Size:** M (380).
**Depends on:** v0-T047.

- [ ] **Step 1:** write `internal/lock/lock_test.go`:

```go
package lock

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
)

func TestTakeAllowsOneHolder(t *testing.T) {
	path := filepath.Join(t.TempDir(), "locks", "repos-api.lock")
	release, err := Take(path)
	if err != nil {
		t.Fatalf("Take() = %v (it creates the directory too)", err)
	}
	if _, err := Take(path); !errors.Is(err, ErrHeld) {
		t.Errorf("a second Take() = %v, want ErrHeld", err)
	}
	release()
	again, err := Take(path)
	if err != nil {
		t.Fatalf("Take() after release = %v", err)
	}
	again()
}

func TestHeldNeitherLocksNorCreates(t *testing.T) {
	path := filepath.Join(t.TempDir(), "lock")
	if Held(path) {
		t.Error("Held() = true for a lock file that doesn't exist")
	}
	if _, err := os.Stat(path); err == nil {
		t.Error("Held() created the lock file")
	}
	release, err := Take(path)
	if err != nil {
		t.Fatal(err)
	}
	if !Held(path) {
		t.Error("Held() = false while held")
	}
	release()
	if Held(path) {
		t.Error("Held() = true after release")
	}
	// Held only reads /proc/locks, so a Take right after it never meets a lock Held took.
	for i := 0; i < 100; i++ {
		Held(path)
		r, err := Take(path)
		if err != nil {
			t.Fatalf("Take() after Held() = %v", err)
		}
		r()
	}
}
```

and `internal/merge/merge_test.go`:

```go
package merge

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/ouroboric-dev/odin/internal/leaf"
	"github.com/ouroboric-dev/odin/internal/lock"
	"github.com/ouroboric-dev/odin/internal/tree"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

var ctx = context.Background()

// setup returns the api leaf on run branch ygg/run1 with one feature commit, and the spec to land
// it with check as its checks.
func setup(t *testing.T, check func(context.Context) error) (*leaf.Leaf, Spec) {
	t.Helper()
	root := treetest.Build(t, treetest.Standard())
	nodes, err := tree.Resolve(ctx, root, "projects/gallery/repos/api")
	if err != nil {
		t.Fatal(err)
	}
	l, err := leaf.Open(nodes[2])
	if err != nil {
		t.Fatal(err)
	}
	if _, err := l.StartBranch(ctx, "ygg/run1", "main"); err != nil {
		t.Fatal(err)
	}
	commit(t, l, "feature.txt", "the feature\n")
	return l, Spec{Leaf: l, Branch: "ygg/run1", Base: "main",
		Lock: filepath.Join(nodes[1].Dir, ".factory", "locks", "repos-api.lock"), Check: check}
}

// commit writes path on the branch the leaf has checked out, and commits it.
func commit(t *testing.T, l *leaf.Leaf, path, body string) string {
	t.Helper()
	if err := os.WriteFile(filepath.Join(l.Dir(), path), []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	head, _, err := l.Checkpoint(ctx, "add "+path)
	if err != nil {
		t.Fatal(err)
	}
	return head
}

// moveMain puts a commit adding path on main while the run branch stays checked out, as a person
// working on main would.
func moveMain(t *testing.T, l *leaf.Leaf, path string) string {
	t.Helper()
	if _, err := l.Git(ctx, "switch", "-q", "main"); err != nil {
		t.Fatal(err)
	}
	head := commit(t, l, path, "on main\n")
	if _, err := l.Git(ctx, "switch", "-q", "ygg/run1"); err != nil {
		t.Fatal(err)
	}
	return head
}

func exists(l *leaf.Leaf, path string) bool {
	_, err := os.Stat(filepath.Join(l.Dir(), path))
	return err == nil
}

// Spec §13: a branch that passed against an old base but fails against the new one MUST NOT merge.
func TestMergeGateRefusesABranchThatFailsAgainstTheNewBase(t *testing.T) {
	l, spec := setup(t, nil)
	spec.Check = func(context.Context) error {
		if exists(l, "feature.txt") && exists(l, "breaks-feature.txt") {
			return errors.New("the feature's tests fail with breaks-feature.txt")
		}
		return nil
	}
	if err := spec.Check(ctx); err != nil {
		t.Fatalf("the branch fails its checks before main moved: %v", err)
	}
	moved := moveMain(t, l, "breaks-feature.txt")
	_, err := Land(ctx, spec)
	var r *Refused
	if !errors.As(err, &r) || r.Why != WhyChecks {
		t.Fatalf("Land() = %v, want refused on the checks", err)
	}
	if main, _ := l.Rev(ctx, "main"); main != moved {
		t.Errorf("main = %s, want it unmoved at %s", main, moved)
	}
}

// Spec §13: a head that moved after review MUST abort.
func TestMergeGateAbortsWhenTheHeadMovedAfterReview(t *testing.T) {
	l, spec := setup(t, nil)
	base, _ := l.Rev(ctx, "main")
	spec.Check = func(context.Context) error {
		commit(t, l, "late.txt", "pushed after the checks started\n") // the head moves under the gate
		return nil
	}
	_, err := Land(ctx, spec)
	var r *Refused
	if !errors.As(err, &r) || r.Why != WhyMoved {
		t.Fatalf("Land() = %v, want refused because the head moved", err)
	}
	if main, _ := l.Rev(ctx, "main"); main != base {
		t.Errorf("main moved to %s", main)
	}
}

func TestMergeGateLandsTheCheckedCommit(t *testing.T) {
	var checkedOn string
	l, spec := setup(t, nil)
	spec.Check = func(ctx context.Context) error {
		checkedOn, _ = l.Head(ctx)
		if !exists(l, "feature.txt") || !exists(l, "docs.txt") {
			return errors.New("the checks didn't run on the branch with the new base merged in")
		}
		return nil
	}
	moveMain(t, l, "docs.txt")
	res, err := Land(ctx, spec)
	if err != nil {
		t.Fatalf("Land() = %v", err)
	}
	if main, _ := l.Rev(ctx, "main"); main != res.Merged || res.Merged != checkedOn || res.Checked != checkedOn {
		t.Errorf("main = %s, result %+v, checked on %s; want main at the checked commit", main, res, checkedOn)
	}
	if lock.Held(spec.Lock) {
		t.Error("the gate kept its lock")
	}
}

func TestMergeGateRefusesAConflict(t *testing.T) {
	l, spec := setup(t, func(context.Context) error { return nil })
	before, _ := l.Head(ctx)
	if _, err := l.Git(ctx, "switch", "-q", "main"); err != nil {
		t.Fatal(err)
	}
	commit(t, l, "feature.txt", "main's own version\n")
	if _, err := l.Git(ctx, "switch", "-q", "ygg/run1"); err != nil {
		t.Fatal(err)
	}
	_, err := Land(ctx, spec)
	var r *Refused
	if !errors.As(err, &r) || r.Why != WhyConflict {
		t.Fatalf("Land() = %v, want refused on a conflict", err)
	}
	if head, _ := l.Head(ctx); head != before {
		t.Errorf("the branch moved to %s after the aborted merge", head)
	}
	if st, _ := l.Git(ctx, "status", "--porcelain"); st != "" {
		t.Errorf("the aborted merge left changes:\n%s", st)
	}
}

func TestMergeGateWaitsForNoOne(t *testing.T) {
	l, spec := setup(t, func(context.Context) error { return nil })
	base, _ := l.Rev(ctx, "main")
	release, err := lock.Take(spec.Lock)
	if err != nil {
		t.Fatal(err)
	}
	defer release()
	if _, err := Land(ctx, spec); !errors.Is(err, lock.ErrHeld) {
		t.Errorf("Land() = %v, want lock.ErrHeld while another process holds the target", err)
	}
	if main, _ := l.Rev(ctx, "main"); main != base {
		t.Error("main moved without the lock")
	}
}
```

- [ ] **Step 2:** run `go test ./internal/lock/ ./internal/merge/`; expect a build failure:
      `undefined: Take`.
- [ ] **Step 3:** write `internal/lock/lock.go`:

```go
// Package lock holds Odin's file locks: a run's, a project's, and a merge target's (spec §4.5).
// They are flock locks, so the kernel drops them when the process ends, and a killed ygg never
// leaves one behind.
package lock

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
)

// ErrHeld means another process holds the lock.
var ErrHeld = errors.New("another process holds the lock")

// Take takes the lock at path for this process, creating the file and its directory, and returns
// the function that releases it. It never waits: a held lock is ErrHeld.
func Take(path string) (release func(), err error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	f, err := os.OpenFile(path, os.O_RDWR|os.O_CREATE, 0o644)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		f.Close()
		if errors.Is(err, syscall.EWOULDBLOCK) {
			return nil, fmt.Errorf("%s: %w", path, ErrHeld)
		}
		return nil, err
	}
	return func() { f.Close() }, nil
}

// Held reports whether a process holds the lock at path. It reads /proc/locks and neither takes
// the lock nor creates the file, so a check never makes another process's Take fail.
func Held(path string) bool {
	var st syscall.Stat_t
	if err := syscall.Stat(path, &st); err != nil {
		return false
	}
	major := (st.Dev>>8)&0xfff | (st.Dev>>32)&^0xfff
	minor := st.Dev&0xff | (st.Dev>>12)&^0xff
	id := fmt.Sprintf("%02x:%02x:%d", major, minor, st.Ino)
	f, err := os.Open("/proc/locks")
	if err != nil {
		return false
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		// 1: FLOCK  ADVISORY  WRITE 4242 08:20:12345 0 EOF
		fields := strings.Fields(sc.Text())
		if len(fields) >= 6 && fields[1] == "FLOCK" && fields[5] == id {
			return true
		}
	}
	return false
}
```

and `internal/merge/merge.go`:

```go
// Package merge is the merge gate (spec §4.5). A branch can pass every check and then stop
// building after its base moves underneath it, so a run's branch lands on a leaf's main only
// through these steps: lock the target, merge the current base into the branch, re-run the
// checks on the result, and move main to the checked commit only if the branch head is still that
// commit and main is still the base that was merged.
package merge

import (
	"context"
	"fmt"

	"github.com/ouroboric-dev/odin/internal/leaf"
	"github.com/ouroboric-dev/odin/internal/lock"
)

// Spec is what to land.
type Spec struct {
	Leaf   *leaf.Leaf
	Branch string                          // the run's branch, checked out in the leaf
	Base   string                          // the branch it lands on, such as main
	Lock   string                          // the target's lock file, in <L1>/.factory/locks/
	Check  func(ctx context.Context) error // runs the checks on the commit the leaf has checked out
}

// Result is what landed.
type Result struct {
	Base    string // the base that was merged into the branch
	Checked string // the commit the checks passed on
	Merged  string // the commit Base now points at: Checked
}

// Why the gate refused.
const (
	WhyConflict = "conflict" // the base doesn't merge cleanly into the branch
	WhyChecks   = "checks"   // the checks fail on the branch with the base merged in
	WhyMoved    = "moved"    // the branch head or the base moved after the checks
)

// Refused is a gate that didn't land. The work goes back to the loop; nothing moved on Base.
type Refused struct {
	Why string
	Err error
}

func (r *Refused) Error() string { return fmt.Sprintf("merge gate refused (%s): %v", r.Why, r.Err) }
func (r *Refused) Unwrap() error { return r.Err }

// Land runs the gate. It returns a *Refused when the work must go back to the loop, and
// lock.ErrHeld when another process holds the target.
func Land(ctx context.Context, s Spec) (Result, error) {
	release, err := lock.Take(s.Lock)
	if err != nil {
		return Result{}, err
	}
	defer release()
	l := s.Leaf
	var res Result
	if res.Base, err = l.Rev(ctx, s.Base); err != nil {
		return res, err
	}
	if _, err := l.Git(ctx, "switch", "-q", s.Branch); err != nil {
		return res, err
	}
	msg := fmt.Sprintf("Merge %s into %s", s.Base, s.Branch)
	if _, err := l.Git(ctx, "merge", "-q", "--no-edit", "-m", msg, res.Base); err != nil {
		if _, abortErr := l.Git(ctx, "merge", "--abort"); abortErr != nil {
			return res, fmt.Errorf("%v; and the merge didn't abort: %v", err, abortErr)
		}
		return res, &Refused{Why: WhyConflict, Err: err}
	}
	if res.Checked, err = l.Head(ctx); err != nil {
		return res, err
	}
	if err := s.Check(ctx); err != nil {
		return res, &Refused{Why: WhyChecks, Err: err}
	}
	head, err := l.Rev(ctx, s.Branch)
	if err != nil {
		return res, err
	}
	if head != res.Checked {
		return res, &Refused{Why: WhyMoved, Err: fmt.Errorf("%s is at %s, not the checked %s", s.Branch, head, res.Checked)}
	}
	// update-ref with the old value moves the base only if it is still the base that was merged.
	if _, err := l.Git(ctx, "update-ref", "refs/heads/"+s.Base, res.Checked, res.Base); err != nil {
		return res, &Refused{Why: WhyMoved, Err: fmt.Errorf("%s moved during the checks: %w", s.Base, err)}
	}
	res.Merged = res.Checked
	return res, nil
}
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T050: pointer moves

Spec §3.4 and decision 13: one level, under the parent's lock.

**Files (in `odin`):**
- Create: `internal/pointer/pointer.go`, `internal/pointer/pointer_test.go`

**Interfaces:**
- Consumes: `tree.Node` (v0-T044), `leaf.Leaf` (v0-T047), `shrink.Check` (v0-T048), `lock.Take`
  (v0-T049).
- Produces: `pointer.Spec{Parent tree.Node; Child string; Leaf *leaf.Leaf; To, Lock string; Check,
  Acceptance func(ctx) error; Generated []string; SkipShrink bool; Message string}`,
  `pointer.Move(ctx, Spec) (pointer.Result, error)` with `Result{From, To, Commit string}` (`Commit`
  is empty when the pointer was already there), and `pointer.Refused{Why string; Err error}`.

**Acceptance criteria:**
- [ ] A move commits in the parent only, with the given message; the root gets no commit (one level); a
      second move to the same commit commits nothing.
- [ ] Failing leaf checks or acceptance checks refuse the move, and the pointer stays.
- [ ] A generated file under half its rows is a `*shrink.Error` and nothing moves; with `SkipShrink`
      the move lands, and its commit holds the generated file and the pointer.
- [ ] An umbrella with staged changes Odin didn't make is refused, and the changes stay staged.

**Named test:** `go test ./internal/pointer/`. **Layer:** `odin`. **Size:** M (262). **Depends on:**
v0-T048, v0-T049.

- [ ] **Step 1:** write `internal/pointer/pointer_test.go`:

```go
package pointer

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/leaf"
	"github.com/ouroboric-dev/odin/internal/shrink"
	"github.com/ouroboric-dev/odin/internal/tree"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

var ctx = context.Background()

func ok(context.Context) error { return nil }

// landed returns the instance root, the gallery umbrella, and a spec moving its repos/api pointer
// to a new commit on the leaf's main.
func landed(t *testing.T) (string, tree.Node, Spec) {
	t.Helper()
	root := treetest.Build(t, treetest.Standard())
	nodes, err := tree.Resolve(ctx, root, "projects/gallery/repos/api")
	if err != nil {
		t.Fatal(err)
	}
	l, err := leaf.Open(nodes[2])
	if err != nil {
		t.Fatal(err)
	}
	if _, err := l.StartBranch(ctx, "ygg/run1", "main"); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(l.Dir(), "feature.txt"), []byte("x\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	head, _, err := l.Checkpoint(ctx, "feature")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := l.Git(ctx, "update-ref", "refs/heads/main", head); err != nil { // as the merge gate lands it
		t.Fatal(err)
	}
	return root, nodes[1], Spec{Parent: nodes[1], Child: "repos/api", Leaf: l, To: head,
		Lock: filepath.Join(nodes[1].Dir, ".factory", "locks", "project.lock"), Check: ok, Acceptance: ok,
		Message: "Move repos/api (run run1)"}
}

func gitlink(t *testing.T, dir, path string) string {
	t.Helper()
	sha, err := git.Run(ctx, dir, "rev-parse", "HEAD:"+path)
	if err != nil {
		t.Fatal(err)
	}
	return sha
}

func count(t *testing.T, dir string) string {
	t.Helper()
	n, err := git.Run(ctx, dir, "rev-list", "--count", "HEAD")
	if err != nil {
		t.Fatal(err)
	}
	return n
}

func TestMoveCommitsOneLevelOnly(t *testing.T) {
	root, parent, spec := landed(t)
	rootCommits := count(t, root)
	res, err := Move(ctx, spec)
	if err != nil {
		t.Fatalf("Move() = %v", err)
	}
	if got := gitlink(t, parent.Dir, "repos/api"); got != spec.To || res.To != spec.To || res.Commit == "" {
		t.Errorf("the gallery points at %s (result %+v), want %s", got, res, spec.To)
	}
	if msg, _ := git.Run(ctx, parent.Dir, "log", "-1", "--format=%s"); msg != spec.Message {
		t.Errorf("commit message = %q", msg)
	}
	if count(t, root) != rootCommits {
		t.Error("the move committed in the root too; a move spans one level (spec §3.4)")
	}
	if again, err := Move(ctx, spec); err != nil || again.Commit != "" {
		t.Errorf("a second Move() to the same commit = %+v, %v; want no commit", again, err)
	}
}

func TestMoveRunsTheChecksAndTheAcceptanceTests(t *testing.T) {
	_, parent, spec := landed(t)
	before := gitlink(t, parent.Dir, "repos/api")
	for name, change := range map[string]func(*Spec){
		"leaf checks fail": func(s *Spec) { s.Check = func(context.Context) error { return errors.New("unit tests fail") } },
		"acceptance fails": func(s *Spec) { s.Acceptance = func(context.Context) error { return errors.New("e2e fails") } },
	} {
		s := spec
		change(&s)
		_, err := Move(ctx, s)
		var r *Refused
		if !errors.As(err, &r) {
			t.Errorf("%s: Move() = %v, want *Refused", name, err)
		}
		if got := gitlink(t, parent.Dir, "repos/api"); got != before {
			t.Errorf("%s: the pointer moved", name)
		}
	}
}

func TestMoveCommitsGeneratedFilesUnderTheShrinkGuard(t *testing.T) {
	_, parent, spec := landed(t)
	repos := filepath.Join(parent.Dir, "REPOS.md")
	write := func(rows int) {
		t.Helper()
		if err := os.WriteFile(repos, []byte(strings.Repeat("| repo | api |\n", rows)), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write(10)
	if _, err := git.Run(ctx, parent.Dir, "add", "REPOS.md"); err != nil {
		t.Fatal(err)
	}
	if _, err := git.Run(ctx, parent.Dir, "commit", "-q", "-m", "REPOS.md"); err != nil {
		t.Fatal(err)
	}
	spec.Generated = []string{"REPOS.md"}
	write(3)
	_, err := Move(ctx, spec)
	var se *shrink.Error
	if !errors.As(err, &se) {
		t.Fatalf("Move() = %v, want the shrink guard's refusal", err)
	}
	if got := gitlink(t, parent.Dir, "repos/api"); got == spec.To {
		t.Error("the pointer moved past the shrink guard")
	}
	spec.SkipShrink = true // the operator approved shrink-guard for this move
	if _, err := Move(ctx, spec); err != nil {
		t.Fatalf("Move() with the guard approved = %v", err)
	}
	if files, _ := git.Run(ctx, parent.Dir, "show", "--name-only", "--format=", "HEAD"); files != "REPOS.md\nrepos/api" {
		t.Errorf("the move commits %q, want the generated file and the pointer", files)
	}
}

func TestMoveRefusesOtherStagedChanges(t *testing.T) {
	_, parent, spec := landed(t)
	if err := os.WriteFile(filepath.Join(parent.Dir, "notes.md"), []byte("a person's note\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := git.Run(ctx, parent.Dir, "add", "notes.md"); err != nil {
		t.Fatal(err)
	}
	if _, err := Move(ctx, spec); err == nil || !strings.Contains(err.Error(), "notes.md") {
		t.Errorf("Move() = %v, want a refusal naming the staged notes.md", err)
	}
	if staged, _ := git.Run(ctx, parent.Dir, "diff", "--cached", "--name-only"); staged != "notes.md" {
		t.Errorf("the person's staged change was touched: %q", staged)
	}
}
```

- [ ] **Step 2:** run `go test ./internal/pointer/`; expect a build failure: `undefined: Spec`.
- [ ] **Step 3:** write `internal/pointer/pointer.go`:

```go
// Package pointer moves a leaf's pointer in its parent umbrella (spec §3.4). A move means "this
// child, at this commit, passed this level's checks", so it spans one level only: the parent gets
// one commit, and nothing above it moves.
package pointer

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/leaf"
	"github.com/ouroboric-dev/odin/internal/lock"
	"github.com/ouroboric-dev/odin/internal/shrink"
	"github.com/ouroboric-dev/odin/internal/tree"
)

// Spec is the move.
type Spec struct {
	Parent     tree.Node                       // the umbrella whose pointer moves
	Child      string                          // the leaf's path in it
	Leaf       *leaf.Leaf                      // the leaf, checked out at To
	To         string                          // the commit the pointer moves to
	Lock       string                          // the parent's lock file
	Check      func(ctx context.Context) error // the leaf's checks, at To
	Acceptance func(ctx context.Context) error // the parent's acceptance tests, with the leaf at To
	Generated  []string                        // generated files of the parent, committed with the move
	SkipShrink bool                            // the operator approved shrink-guard for this move
	Message    string                          // the commit message
}

// Result is the move made.
type Result struct {
	From, To string // the pointer before and after
	Commit   string // the parent's commit; "" when the pointer was already at To
}

// Refused is a move whose checks failed. Nothing was committed.
type Refused struct {
	Why string
	Err error
}

func (r *Refused) Error() string { return fmt.Sprintf("pointer move refused (%s): %v", r.Why, r.Err) }
func (r *Refused) Unwrap() error { return r.Err }

// Move moves the pointer under the parent's lock. A generated file under half its rows is a
// *shrink.Error unless SkipShrink is set; failed checks are a *Refused. Either way nothing moves.
func Move(ctx context.Context, s Spec) (Result, error) {
	release, err := lock.Take(s.Lock)
	if err != nil {
		return Result{}, err
	}
	defer release()
	p := s.Parent.Dir
	res := Result{To: s.To}
	if res.From, err = git.Run(ctx, p, "rev-parse", "HEAD:"+s.Child); err != nil {
		return res, err
	}
	if res.From == s.To {
		return res, nil
	}
	if head, err := s.Leaf.Head(ctx); err != nil || head != s.To {
		return res, fmt.Errorf("the leaf %s is at %s, not %s; check it out at the commit the pointer moves to", s.Child, head, s.To)
	}
	if staged, err := git.Run(ctx, p, "diff", "--cached", "--name-only"); err != nil {
		return res, err
	} else if staged != "" {
		return res, fmt.Errorf("the umbrella %s has staged changes Odin didn't make (%s); commit or unstage them first", p, strings.ReplaceAll(staged, "\n", ", "))
	}
	if err := s.Check(ctx); err != nil {
		return res, &Refused{Why: "checks", Err: err}
	}
	if err := s.Acceptance(ctx); err != nil {
		return res, &Refused{Why: "acceptance", Err: err}
	}
	if !s.SkipShrink {
		for _, f := range s.Generated {
			prev, _ := git.Run(ctx, p, "show", "HEAD:"+f) // a file new in this move has no rows
			next, err := os.ReadFile(filepath.Join(p, f))
			if err != nil && !errors.Is(err, os.ErrNotExist) {
				return res, err
			}
			if err := shrink.Check(f, []byte(prev), next); err != nil {
				return res, err
			}
		}
	}
	paths := append([]string{s.Child}, s.Generated...)
	if _, err := git.Run(ctx, p, append([]string{"add", "-A", "--"}, paths...)...); err != nil {
		return res, err
	}
	if _, err := git.Run(ctx, p, append([]string{"commit", "-q", "-m", s.Message, "--"}, paths...)...); err != nil {
		return res, err
	}
	res.Commit, err = git.Run(ctx, p, "rev-parse", "HEAD")
	return res, err
}
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T051: a run finds its project in the tree

A run's project is an umbrella of an instance tree, and every node that does work names its repo
(decision 7). Phase 1's `workspace/` goes. Every test that starts a run moves onto a tree fixture.

**Files (in `odin`):**
- Create: `internal/run/tree_test.go`
- Modify: `internal/run/run.go`, `internal/run/state.go`, `internal/engine/engine.go`,
  `internal/cli/cli.go`, `internal/tree/treetest/treetest.go`, `testdata/toy/graph.yaml`,
  `testdata/toy/pack.yaml`, and the tests that start runs: `internal/run/caps_test.go`,
  `internal/run/open_test.go`, `internal/run/leftover_test.go`, `internal/engine/engine_test.go`,
  `internal/engine/gates_test.go`, `internal/cli/cli_test.go`, `internal/cli/e2e_test.go`

**Interfaces:**
- Consumes: `tree.FindRoot`, `tree.Resolve` (v0-T044); `leaf.Open` (v0-T047).
- Produces: `run.Prepare(ctx, Options)`, `run.Start(ctx, Options)`, `run.Open(ctx, project, id,
  mode)` (a context added to each); `run.Setup` gains `Root`, `ProjectPath`, `Project tree.Node`,
  `Repos map[string]tree.Node` and `Leaves() []string`; `run.Run` gains `RepoDir(repo) string`,
  `Leaf(repo) (*leaf.Leaf, error)` and `Home() string`, and loses `Workspace()`; `run.State` gains
  `Root` and `ProjectPath`, and `run.StateSchema` is `ygg.run/v2`;
  `treetest.Project(t, leaves ...string) string`: a project that is its own tree's root (decision 15);
  `treetest.SubProject(t, leaves ...string) (root, sub string)`: a project holding a sub-project.

**Acceptance criteria:**
- [ ] A run starts only in a project umbrella inside an instance tree; outside one it is refused with
      "not inside an instance tree" and nothing is created, and a leaf as `--project` is refused.
- [ ] Prepare resolves each node's repo, checking out only those, and refuses a node with no repo, an
      agent in an umbrella, a repo the project lacks, and a check the pack doesn't define.
- [ ] Exec and agent nodes work in their repo, and an exec node's `HOME` is the run's `home/`.
- [ ] `run.json` records the root and the project's path, and a run in a sub-project finds the root
      above it and works in the sub-project's own leaves.
- [ ] The toy realm's nodes name `repos/app`, and every Phase 1 test passes on tree fixtures.

**Named test:** `go test ./internal/run/ ./internal/engine/ ./internal/cli/`. **Layer:** `odin`.
**Size:** M (355; most of the deleted lines are the tests' project setup, rewritten).
**Depends on:** v0-T045.

- [ ] **Step 1:** apply to `internal/tree/treetest/treetest.go`:

```diff
diff --git a/internal/tree/treetest/treetest.go b/internal/tree/treetest/treetest.go
index 9de5827..345c2c2 100644
--- a/internal/tree/treetest/treetest.go
+++ b/internal/tree/treetest/treetest.go
@@ -47,6 +47,17 @@ func Deep() Node {
 				"repos/api": {Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Leaf: true}}}}}}}
 }
 
+// Project builds a project umbrella that is its own tree's root, with the given leaves (path from
+// the project), and returns its fresh clone. The leaves stay unchecked-out, as in a fresh clone.
+func Project(t *testing.T, leaves ...string) string {
+	t.Helper()
+	project := Node{Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Children: map[string]Node{}}
+	for _, l := range leaves {
+		project.Children[l] = Node{Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Leaf: true}
+	}
+	return Build(t, project)
+}
+
 // Build makes the tree's repos and returns the path of a fresh clone of the root, with no
 // submodule initialised.
 func Build(t *testing.T, root Node) string {
@@ -112,3 +123,17 @@ func write(t *testing.T, path, body string) {
 		t.Fatal(err)
 	}
 }
+
+// SubProject builds a project that holds a sub-project, projects/sub, with the given leaves, and
+// returns the root and the sub-project's directory, checked out. A project MAY hold sub-projects
+// (change project-is-its-own-tree), though company-shaped work belongs in Asgard.
+func SubProject(t *testing.T, leaves ...string) (root, sub string) {
+	t.Helper()
+	child := Node{Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Children: map[string]Node{}}
+	for _, l := range leaves {
+		child.Children[l] = Node{Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Leaf: true}
+	}
+	root = Build(t, Node{Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Children: map[string]Node{"projects/sub": child}})
+	run(t, context.Background(), root, "submodule", "update", "--init", "--", "projects/sub")
+	return root, filepath.Join(root, "projects", "sub")
+}
```

write `internal/run/tree_test.go`:

```go
package run

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/tree"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

// startToyRun starts a toy run in a fresh project and returns it, open.
func startToyRun(t *testing.T, config string) *Run {
	t.Helper()
	project := treetest.Project(t, "repos/app")
	r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), config), Realm: toy(t)})
	if err != nil {
		t.Fatalf("Start() = %v", err)
	}
	return r
}

func TestARunFindsItsProjectAndReposInTheTree(t *testing.T) {
	project := treetest.Project(t, "repos/app")
	r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
	if err != nil {
		t.Fatalf("Start() = %v", err)
	}
	id := r.State.ID
	r.Close()
	nodes, err := tree.Resolve(ctx, project, "repos/app")
	if err != nil {
		t.Fatal(err)
	}
	if r.RepoDir("repos/app") != nodes[1].Dir || r.RepoDir(".") != project {
		t.Errorf("the run's repos are %s and %s", r.RepoDir("repos/app"), r.RepoDir("."))
	}
	s, err := LoadState(Dir(project, id))
	if err != nil {
		t.Fatal(err)
	}
	if s.Root != project || s.ProjectPath != "" {
		t.Errorf("run.json places the run at %s in %s", s.ProjectPath, s.Root)
	}
}

func TestStartRefusesAProjectOutsideTheTree(t *testing.T) {
	outside := t.TempDir()
	_, err := Start(ctx, Options{Project: outside, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
	if err == nil || !strings.Contains(err.Error(), "not inside an instance tree") {
		t.Errorf("Start() = %v, want a refusal: a resume resets leaves, so Odin works only in the tree", err)
	}
	if _, err := os.Stat(filepath.Join(outside, ".factory")); !errors.Is(err, fs.ErrNotExist) {
		t.Error("the refused Start created .factory/")
	}
	r := startToyRun(t, scriptedRoles+fullCaps)
	r.Close()
	leafDir := r.RepoDir("repos/app")
	if _, err := Start(ctx, Options{Project: leafDir, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)}); err == nil || !strings.Contains(err.Error(), "is a leaf") {
		t.Errorf("Start() in a leaf = %v, want a refusal", err)
	}
}

func TestPrepareRefusesAGraphTheProjectCantRun(t *testing.T) {
	project := treetest.Project(t, "repos/app")
	cases := map[string]struct{ nodes, want string }{
		"a node with no repo":       {"  - { id: a, kind: exec, run: [echo] }\n", "names no repo"},
		"an agent in the umbrella":  {"  - { id: a, kind: agent, role: planner, prompt: p.md, repo: . }\n", "is an umbrella"},
		"a repo the project lacks":  {"  - { id: a, kind: exec, run: [echo], repo: repos/other }\n", "the project lacks"},
		"a check the pack lacks":    {"  - { id: m, kind: merge, repo: repos/app, checks: [lint] }\n", "doesn't define"},
		"a pointer for an umbrella": {"  - { id: p, kind: pointer, repo: repos/app }\n  - { id: q, kind: pointer, repo: sub }\n", "the project lacks"},
	}
	for name, c := range cases {
		realm := t.TempDir()
		files := map[string]string{
			"pack.yaml":                     "name: t\nversion: 0.1.0\ngraph: graph.yaml\nchecks:\n  unit: [echo]\nleaves:\n  repos/app: { description: d, template: tpl, first_commit: [LICENSE] }\n",
			"graph.yaml":                    "name: t\nversion: 1.0.0\nnodes:\n" + c.nodes,
			"p.md":                          "Do it.\n",
			filepath.Join("tpl", "LICENSE"): "AGPL-3.0-only\n",
		}
		for f, body := range files {
			os.MkdirAll(filepath.Dir(filepath.Join(realm, f)), 0o755)
			if err := os.WriteFile(filepath.Join(realm, f), []byte(body), 0o644); err != nil {
				t.Fatal(err)
			}
		}
		_, err := Prepare(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: realm})
		if err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: Prepare() = %v, want an error containing %q", name, err, c.want)
		}
	}
}

// A project MAY hold sub-projects (change project-is-its-own-tree): a run in one finds the root
// above it, and works in the sub-project's own leaves.
func TestARunWorksInASubProject(t *testing.T) {
	root, sub := treetest.SubProject(t, "repos/app")
	r, err := Start(ctx, Options{Project: sub, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
	if err != nil {
		t.Fatalf("Start() in a sub-project = %v", err)
	}
	defer r.Close()
	if r.State.Root != root || r.State.ProjectPath != "projects/sub" {
		t.Errorf("run.json places the run at %q in %s, want projects/sub in %s", r.State.ProjectPath, r.State.Root, root)
	}
	if got := r.RepoDir("repos/app"); got != filepath.Join(sub, "repos", "app") {
		t.Errorf("the run works in %s, want the sub-project's own leaf", got)
	}
}
```

and move the tests that start runs onto the fixture. Apply to `internal/run/caps_test.go`:

```diff
diff --git a/internal/run/caps_test.go b/internal/run/caps_test.go
index f217b50..0477269 100644
--- a/internal/run/caps_test.go
+++ b/internal/run/caps_test.go
@@ -1,6 +1,7 @@
 package run
 
 import (
+	"context"
 	"errors"
 	"io/fs"
 	"os"
@@ -10,8 +11,11 @@ import (
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
+	"github.com/ouroboric-dev/odin/internal/tree/treetest"
 )
 
+var ctx = context.Background()
+
 const (
 	scriptedRoles = "roles:\n  planner: { agent: scripted, model: none, script: SCRIPT }\n  implementer: { agent: scripted, model: none, script: SCRIPT }\n"
 	paidRoles     = "roles:\n  planner: { agent: opencode, model: openrouter/qwen }\n  implementer: { agent: scripted, model: none, script: SCRIPT }\n"
@@ -49,8 +53,8 @@ func TestRunRefusesWithoutCompleteCaps(t *testing.T) {
 	}
 	for _, c := range cases {
 		t.Run(c.name, func(t *testing.T) {
-			project := t.TempDir()
-			_, err := Start(Options{Project: project, Config: writeConfig(t, t.TempDir(), c.config), Realm: toy(t)})
+			project := treetest.Project(t, "repos/app")
+			_, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), c.config), Realm: toy(t)})
 			var ce *schema.CapsError
 			if !errors.As(err, &ce) {
 				t.Fatalf("Start() error = %v, want a *schema.CapsError", err)
@@ -66,23 +70,24 @@ func TestRunRefusesWithoutCompleteCaps(t *testing.T) {
 		})
 	}
 	t.Run("resume refuses in the same cases", func(t *testing.T) {
-		project, cfgDir := t.TempDir(), t.TempDir()
-		r, err := Start(Options{Project: project, Config: writeConfig(t, cfgDir, scriptedRoles+fullCaps), Realm: toy(t)})
+		project := treetest.Project(t, "repos/app")
+		cfgDir := t.TempDir()
+		r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, cfgDir, scriptedRoles+fullCaps), Realm: toy(t)})
 		if err != nil {
 			t.Fatal(err)
 		}
 		id := r.State.ID
 		r.Close()
 		writeConfig(t, cfgDir, scriptedRoles+"budget:\n  per_run: { tokens: 100000, turns: 100 }\n")
-		_, err = Open(project, id, "")
+		_, err = Open(ctx, project, id, "")
 		var ce *schema.CapsError
 		if !errors.As(err, &ce) || !strings.Contains(err.Error(), "budget.per_day") {
 			t.Errorf("Open() error = %v, want a *schema.CapsError naming budget.per_day", err)
 		}
 	})
 	t.Run("complete caps start a run", func(t *testing.T) {
-		project := t.TempDir()
-		r, err := Start(Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
+		project := treetest.Project(t, "repos/app")
+		r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
 		if err != nil {
 			t.Fatalf("Start() = %v", err)
 		}
```

to `internal/run/open_test.go`:

```diff
diff --git a/internal/run/open_test.go b/internal/run/open_test.go
index b9eccb7..e27e7ef 100644
--- a/internal/run/open_test.go
+++ b/internal/run/open_test.go
@@ -8,15 +8,17 @@ import (
 	"testing"
 
 	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/odin/internal/tree/treetest"
 )
 
 func TestOpenRefusesWhatWouldMisleadARun(t *testing.T) {
 	start := func(t *testing.T) (project, id, realm string) {
-		project, realm = t.TempDir(), t.TempDir()
+		project = treetest.Project(t, "repos/app")
+		realm = t.TempDir()
 		if err := os.CopyFS(realm, os.DirFS(toy(t))); err != nil {
 			t.Fatal(err)
 		}
-		r, err := Start(Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: realm})
+		r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: realm})
 		if err != nil {
 			t.Fatal(err)
 		}
@@ -25,12 +27,12 @@ func TestOpenRefusesWhatWouldMisleadARun(t *testing.T) {
 	}
 	t.Run("a run another process holds", func(t *testing.T) {
 		project, id, _ := start(t)
-		r, err := Open(project, id, "")
+		r, err := Open(ctx, project, id, "")
 		if err != nil {
 			t.Fatal(err)
 		}
 		defer r.Close()
-		if _, err := Open(project, id, ""); !errors.Is(err, ErrInUse) {
+		if _, err := Open(ctx, project, id, ""); !errors.Is(err, ErrInUse) {
 			t.Errorf("a second Open() = %v, want ErrInUse", err)
 		}
 	})
@@ -38,27 +40,27 @@ func TestOpenRefusesWhatWouldMisleadARun(t *testing.T) {
 		project, id, realm := start(t)
 		g := filepath.Join(realm, "graph.yaml")
 		b, _ := os.ReadFile(g)
-		os.WriteFile(g, []byte(strings.Replace(string(b), "  - { id: dor,", "  - { id: lint, kind: exec, run: [echo] }\n  - { id: dor,", 1)), 0o644)
-		if _, err := Open(project, id, ""); err == nil || !strings.Contains(err.Error(), "graph changed") {
+		os.WriteFile(g, []byte(strings.Replace(string(b), "  - { id: dor,", "  - { id: lint, kind: exec, run: [echo], repo: repos/app }\n  - { id: dor,", 1)), 0o644)
+		if _, err := Open(ctx, project, id, ""); err == nil || !strings.Contains(err.Error(), "graph changed") {
 			t.Errorf("Open() = %v, want a refusal because the graph changed", err)
 		}
 	})
 	t.Run("a path as the run id", func(t *testing.T) {
 		project, _, _ := start(t)
-		if _, err := Open(project, "../../../tmp", ""); err == nil || !strings.Contains(err.Error(), "not a run id") {
+		if _, err := Open(ctx, project, "../../../tmp", ""); err == nil || !strings.Contains(err.Error(), "not a run id") {
 			t.Errorf("Open() = %v, want not a run id", err)
 		}
 	})
 	t.Run("a ledger cut short", func(t *testing.T) {
 		project, id, _ := start(t)
 		os.WriteFile(filepath.Join(Dir(project, id), "ledger.jsonl"), nil, 0o644)
-		if _, err := Open(project, id, ""); err == nil || !strings.Contains(err.Error(), "lines were removed") {
+		if _, err := Open(ctx, project, id, ""); err == nil || !strings.Contains(err.Error(), "lines were removed") {
 			t.Errorf("Open() = %v, want lines were removed", err)
 		}
 	})
 	t.Run("a looser mode is logged", func(t *testing.T) {
 		project, id, _ := start(t)
-		r, err := Open(project, id, gungnir.ModeUnattended)
+		r, err := Open(ctx, project, id, gungnir.ModeUnattended)
 		if err != nil {
 			t.Fatal(err)
 		}
```

to `internal/run/leftover_test.go`:

```diff
diff --git a/internal/run/leftover_test.go b/internal/run/leftover_test.go
index b0af974..640511e 100644
--- a/internal/run/leftover_test.go
+++ b/internal/run/leftover_test.go
@@ -9,6 +9,8 @@ import (
 	"syscall"
 	"testing"
 	"time"
+
+	"github.com/ouroboric-dev/odin/internal/tree/treetest"
 )
 
 // leftover starts script in its own process group, as the engine starts exec nodes, and records
@@ -47,8 +49,8 @@ func leftover(t *testing.T, project, id, script string) (pgid, child int) {
 
 func startToy(t *testing.T) (project, id string) {
 	t.Helper()
-	project = t.TempDir()
-	r, err := Start(Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
+	project = treetest.Project(t, "repos/app")
+	r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
 	if err != nil {
 		t.Fatal(err)
 	}
@@ -64,7 +66,7 @@ func alive(pid int) bool {
 func TestOpenStopsAnExecProcessAKilledYggLeftBehind(t *testing.T) {
 	project, id := startToy(t)
 	pgid, child := leftover(t, project, id, "sleep 30 & echo $! > pid; wait")
-	r, err := Open(project, id, "")
+	r, err := Open(ctx, project, id, "")
 	if err != nil {
 		t.Fatalf("Open() = %v", err)
 	}
@@ -83,7 +85,7 @@ func TestOpenRefusesWhenItCantTellALeftoverGroupIsTheRuns(t *testing.T) {
 	project, id := startToy(t)
 	// The leader exits at once, so only its background child keeps the group alive.
 	_, child := leftover(t, project, id, "sleep 30 & echo $! > pid")
-	if _, err := Open(project, id, ""); err == nil || !strings.Contains(err.Error(), "may still be running") {
+	if _, err := Open(ctx, project, id, ""); err == nil || !strings.Contains(err.Error(), "may still be running") {
 		t.Errorf("Open() = %v, want a refusal that names the running group", err)
 	}
 	if !alive(child) {
```

to `internal/engine/engine_test.go`:

```diff
diff --git a/internal/engine/engine_test.go b/internal/engine/engine_test.go
index 3d24ddb..f6a953b 100644
--- a/internal/engine/engine_test.go
+++ b/internal/engine/engine_test.go
@@ -10,13 +10,15 @@ import (
 
 	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/run"
+	"github.com/ouroboric-dev/odin/internal/tree/treetest"
 )
 
 // start makes a realm with the given nodes and a prompt file, a script and a factory.yaml, and
-// starts a run on them in a fresh project.
+// starts a run on them in a fresh project, whose nodes work in the leaf repos/app.
 func start(t *testing.T, mode, gates, nodes, script string) *run.Run {
 	t.Helper()
-	realm, cfg, project := t.TempDir(), t.TempDir(), t.TempDir()
+	realm, cfg := t.TempDir(), t.TempDir()
+	project := treetest.Project(t, "repos/app")
 	files := map[string]string{
 		filepath.Join(realm, "pack.yaml"):  "name: test\nversion: 0.1.0\ngraph: graph.yaml\n",
 		filepath.Join(realm, "graph.yaml"): "name: test\nversion: 1.0.0\nnodes:\n" + nodes,
@@ -31,7 +33,7 @@ func start(t *testing.T, mode, gates, nodes, script string) *run.Run {
 			t.Fatal(err)
 		}
 	}
-	r, err := run.Start(run.Options{Project: project, Config: filepath.Join(cfg, "factory.yaml"), Realm: realm})
+	r, err := run.Start(context.Background(), run.Options{Project: project, Config: filepath.Join(cfg, "factory.yaml"), Realm: realm})
 	if err != nil {
 		t.Fatal(err)
 	}
@@ -55,7 +57,7 @@ const okScript = `steps:
 `
 
 func TestAgentAndExecNodesRunInOrder(t *testing.T) {
-	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md }\n  - { id: check, kind: exec, run: [grep, -q, done, out.txt] }\n", okScript)
+	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n  - { id: check, kind: exec, run: [grep, -q, done, out.txt], repo: repos/app }\n", okScript)
 	out, err := Advance(context.Background(), r)
 	if err != nil || out.Status != run.StatusDone {
 		t.Fatalf("Advance() = %+v, %v; want done", out, err)
@@ -75,7 +77,7 @@ func TestAgentAndExecNodesRunInOrder(t *testing.T) {
 
 func TestAFailedNodeStopsTheRunAndResumeRerunsIt(t *testing.T) {
 	script := "steps:\n  a:\n    - result: { status: failed, summary: tests fail }\n    - result: { status: ok, summary: fixed }\n"
-	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md }\n", script)
+	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n", script)
 	out, err := Advance(context.Background(), r)
 	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "tests fail") {
 		t.Fatalf("Advance() = %+v, %v; want failed with the agent's summary", out, err)
@@ -90,7 +92,7 @@ func TestAFailedNodeStopsTheRunAndResumeRerunsIt(t *testing.T) {
 
 func TestAMalformedAgentResultIsAFailureNotAPass(t *testing.T) {
 	script := "steps:\n  a:\n    - result: { status: ok, usage: { turns: -1 } }\n"
-	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md }\n", script)
+	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n", script)
 	out, err := Advance(context.Background(), r)
 	if err != nil || out.Status != run.StatusFailed {
 		t.Errorf("Advance() = %+v, %v; want failed", out, err)
@@ -100,11 +102,11 @@ func TestAMalformedAgentResultIsAFailureNotAPass(t *testing.T) {
 func TestExecGetsNoCredentialsFromTheOperator(t *testing.T) {
 	t.Setenv("CLAUDE_CODE_OAUTH_TOKEN", "operator-token")
 	t.Setenv("ANTHROPIC_API_KEY", "operator-key")
-	r := start(t, "key-points", "", "  - { id: env, kind: exec, run: [sh, -c, \"env > env.txt\"] }\n", "steps: {}\n")
+	r := start(t, "key-points", "", "  - { id: env, kind: exec, run: [sh, -c, \"env > env.txt\"], repo: repos/app }\n", "steps: {}\n")
 	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
 		t.Fatalf("Advance() = %+v, %v", out, err)
 	}
-	b, err := os.ReadFile(filepath.Join(r.Workspace(), "env.txt"))
+	b, err := os.ReadFile(filepath.Join(r.RepoDir("repos/app"), "env.txt"))
 	if err != nil {
 		t.Fatal(err)
 	}
@@ -120,7 +122,7 @@ func TestExecGetsNoCredentialsFromTheOperator(t *testing.T) {
 
 func TestAnExecTimeoutKillsTheProcessGroup(t *testing.T) {
 	r := start(t, "key-points", "",
-		"  - { id: slow, kind: exec, run: [sh, -c, \"sleep 30 & echo $! > child.pid; wait\"], timeout: 300ms }\n", "steps: {}\n")
+		"  - { id: slow, kind: exec, run: [sh, -c, \"sleep 30 & echo $! > child.pid; wait\"], timeout: 300ms, repo: repos/app }\n", "steps: {}\n")
 	began := time.Now()
 	out, err := Advance(context.Background(), r)
 	if err != nil || out.Status != run.StatusFailed {
@@ -129,7 +131,7 @@ func TestAnExecTimeoutKillsTheProcessGroup(t *testing.T) {
 	if time.Since(began) > 10*time.Second {
 		t.Errorf("Advance() took %v; the timeout didn't stop it", time.Since(began))
 	}
-	pid := strings.TrimSpace(string(must(os.ReadFile(filepath.Join(r.Workspace(), "child.pid")))))
+	pid := strings.TrimSpace(string(must(os.ReadFile(filepath.Join(r.RepoDir("repos/app"), "child.pid")))))
 	// A killed child is dead once it is gone or a zombie: in a container whose PID 1 doesn't
 	// reap orphans, such as CI's, it stays a zombie.
 	for deadline := time.Now().Add(2 * time.Second); running(pid); time.Sleep(20 * time.Millisecond) {
@@ -155,7 +157,7 @@ func must(b []byte, err error) []byte {
 
 func TestAnInterruptedAgentCountsItsAttempt(t *testing.T) {
 	script := "steps:\n  a:\n    - hang: true\n    - result: { status: ok, summary: done }\n"
-	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md }\n", script)
+	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n", script)
 	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
 	defer cancel()
 	if out, err := Advance(ctx, r); err != nil || out.Status != run.StatusFailed {
@@ -174,12 +176,12 @@ func TestAnInterruptedAgentCountsItsAttempt(t *testing.T) {
 
 func TestRunJSONRecordsTheRunningExecProcess(t *testing.T) {
 	// The node waits up to 5s for the record, since the engine saves it just after the node starts.
-	peek := `for i in $(seq 50); do grep -q pgid ../.factory/runs/*/run.json && break; sleep 0.1; done; cat ../.factory/runs/*/run.json > seen.json`
-	r := start(t, "key-points", "", "  - { id: peek, kind: exec, run: [sh, -c, '"+peek+"'] }\n", "steps: {}\n")
+	peek := `for i in $(seq 50); do grep -q pgid ../.factory/runs/*/run.json && break; sleep 0.1; done; cat ../../.factory/runs/*/run.json > seen.json`
+	r := start(t, "key-points", "", "  - { id: peek, kind: exec, run: [sh, -c, '"+peek+"'], repo: repos/app }\n", "steps: {}\n")
 	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
 		t.Fatalf("Advance() = %+v, %v", out, err)
 	}
-	seen, err := os.ReadFile(filepath.Join(r.Workspace(), "seen.json"))
+	seen, err := os.ReadFile(filepath.Join(r.RepoDir("repos/app"), "seen.json"))
 	if err != nil {
 		t.Fatal(err)
 	}
```

to `internal/engine/gates_test.go`:

```diff
diff --git a/internal/engine/gates_test.go b/internal/engine/gates_test.go
index 942cd9b..80567ac 100644
--- a/internal/engine/gates_test.go
+++ b/internal/engine/gates_test.go
@@ -11,7 +11,7 @@ import (
 	"github.com/ouroboric-dev/odin/internal/run"
 )
 
-const gateNodes = "  - { id: spec, kind: agent, role: planner, prompt: p.md }\n  - { id: check, kind: exec, run: [test, -s, spec.md] }\n  - { id: spec-gate, kind: gate, gate: spec, reruns: spec }\n"
+const gateNodes = "  - { id: spec, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n  - { id: check, kind: exec, run: [test, -s, spec.md], repo: repos/app }\n  - { id: spec-gate, kind: gate, gate: spec, reruns: spec }\n"
 
 const gateScript = `steps:
   spec:
```

to `internal/cli/cli_test.go`:

```diff
diff --git a/internal/cli/cli_test.go b/internal/cli/cli_test.go
index 6bf5dd4..13b047c 100644
--- a/internal/cli/cli_test.go
+++ b/internal/cli/cli_test.go
@@ -7,6 +7,8 @@ import (
 	"path/filepath"
 	"strings"
 	"testing"
+
+	"github.com/ouroboric-dev/odin/internal/tree/treetest"
 )
 
 // ygg runs one command in-process and returns its exit code, stdout and stderr.
@@ -17,16 +19,16 @@ func ygg(t *testing.T, args ...string) (int, string, string) {
 	return code, out.String(), errOut.String()
 }
 
-// project makes a project directory with a factory.yaml for the toy realm. Its roles use script,
-// a file in testdata/toy; extra is added to the config as is.
+// project makes a project umbrella in a fresh instance tree, and a factory.yaml for the toy realm
+// beside it. Its roles use script, a file in testdata/toy; extra is added to the config as is.
 func project(t *testing.T, script, extra string) (dir, config string) {
 	t.Helper()
 	toy, err := filepath.Abs("../../testdata/toy")
 	if err != nil {
 		t.Fatal(err)
 	}
-	dir = t.TempDir()
-	config = filepath.Join(dir, "factory.yaml")
+	dir = treetest.Project(t, "repos/app")
+	config = filepath.Join(t.TempDir(), "factory.yaml")
 	s := filepath.Join(toy, script)
 	body := extra + "roles:\n  planner: { agent: scripted, model: none, script: " + s + " }\n" +
 		"  implementer: { agent: scripted, model: none, script: " + s + " }\n"
```

and to `internal/cli/e2e_test.go`:

```diff
diff --git a/internal/cli/e2e_test.go b/internal/cli/e2e_test.go
index 4a9c0cb..df31526 100644
--- a/internal/cli/e2e_test.go
+++ b/internal/cli/e2e_test.go
@@ -116,8 +116,8 @@ func TestToyGraphEndToEnd(t *testing.T) {
 			if names[len(names)-1] != "run_finished" {
 				t.Errorf("the last event is %s, want run_finished", names[len(names)-1])
 			}
-			if b, err := os.ReadFile(filepath.Join(dir, "workspace", "build.txt")); err != nil || string(b) != "done\n" {
-				t.Errorf("workspace/build.txt = %q, %v", b, err)
+			if b, err := os.ReadFile(filepath.Join(dir, "repos", "app", "build.txt")); err != nil || string(b) != "done\n" {
+				t.Errorf("repos/app/build.txt = %q, %v", b, err)
 			}
 		})
 	}
@@ -138,7 +138,7 @@ func TestToyGraphEndToEnd(t *testing.T) {
 		if code, _, _ := ygg(t, "approve", id, "spec-gate", "--project", dir); code != ExitDone {
 			t.Errorf("approve: exit %d, want 0", code)
 		}
-		if spec, _ := os.ReadFile(filepath.Join(dir, "workspace", "spec.md")); !strings.Contains(string(spec), "photographers") {
+		if spec, _ := os.ReadFile(filepath.Join(dir, "repos", "app", "spec.md")); !strings.Contains(string(spec), "photographers") {
 			t.Errorf("spec.md = %q, want attempt 2's text", spec)
 		}
 	})
```

- [ ] **Step 2:** run `go test ./internal/run/`; expect a build failure:
      `too many arguments in call to Start`.
- [ ] **Step 3:** apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index 4422c77..9d3789f 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -23,7 +23,7 @@ import (
 )
 
 // StateSchema names the run.json format.
-const StateSchema = "ygg.run/v1"
+const StateSchema = "ygg.run/v2" // v2: runs live in the instance tree (Phase 2)
 
 // Status is where a run stands.
 type Status string
@@ -57,9 +57,11 @@ type State struct {
 	Brief        string                `json:"brief,omitempty"`
 	BriefSHA256  string                `json:"brief_sha256,omitempty"`
 	Roles        map[string]RoleRecord `json:"roles"`
+	Root         string                `json:"root"`                // the instance root, L0
+	ProjectPath  string                `json:"project"`             // the project's path from the root
 	Position     int                   `json:"position"`            // index of the next node to run
 	Attempts     map[string]int        `json:"attempts"`            // node id: attempts started
-	Pending      string                `json:"pending,omitempty"`   // the gate node waiting for a decision
+	Pending      string                `json:"pending,omitempty"`   // the node waiting for a decision
 	Reasons      map[string]string     `json:"reasons,omitempty"`   // node id: rejection reason for its next attempt
 	Summaries    map[string]string     `json:"summaries,omitempty"` // node id: its last result
 	Usage        gungnir.Usage         `json:"usage"`
```

to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index ee8a651..5a190dd 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -1,24 +1,28 @@
 package run
 
 import (
+	"context"
 	"crypto/sha256"
 	"encoding/hex"
 	"errors"
 	"fmt"
 	"os"
 	"path/filepath"
+	"slices"
 	"syscall"
 	"time"
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/odin/internal/agents"
+	"github.com/ouroboric-dev/odin/internal/leaf"
 	"github.com/ouroboric-dev/odin/internal/ledger"
+	"github.com/ouroboric-dev/odin/internal/tree"
 )
 
 // Options say what to run.
 type Options struct {
-	Project string       // the directory that holds .factory/ and workspace/
+	Project string       // the project umbrella (L1), inside an instance tree
 	Config  string       // factory.yaml
 	Realm   string       // the directory that holds pack.yaml
 	Brief   string       // optional
@@ -39,12 +43,19 @@ type Setup struct {
 	BriefSHA256  string
 	Mode         gungnir.Mode
 	Agents       map[string]gungnir.Agent // role: adapter, for every role the graph uses
+
+	Root        string               // the tree's root: the project, or an umbrella above it
+	ProjectPath string               // the project's path from the root
+	Project     tree.Node            // the project umbrella
+	Repos       map[string]tree.Node // every repo the graph names, by path from the project; "." is the project
 }
 
-// Prepare loads and checks the config, the realm and the brief, and builds the agents. It writes
-// nothing. Incomplete caps give a *schema.CapsError (change require-budget-caps).
-func Prepare(o Options) (*Setup, error) {
-	s := &Setup{Agents: map[string]gungnir.Agent{}}
+// Prepare loads and checks the config, the realm, the brief and the project's place in the
+// instance tree, and builds the agents. It writes nothing, and checks out only the submodules on
+// the paths to the project and its repos. Incomplete caps give a *schema.CapsError (change
+// require-budget-caps).
+func Prepare(ctx context.Context, o Options) (*Setup, error) {
+	s := &Setup{Agents: map[string]gungnir.Agent{}, Repos: map[string]tree.Node{}}
 	var err error
 	if s.ConfigPath, err = filepath.Abs(o.Config); err != nil {
 		return nil, err
@@ -79,22 +90,12 @@ func Prepare(o Options) (*Setup, error) {
 		return nil, err
 	}
 	s.GraphSHA256 = sum(graphData)
+	if err := s.findProject(ctx, o.Project); err != nil {
+		return nil, err
+	}
 	for _, n := range s.Graph.Nodes {
-		if n.Kind != schema.KindAgent {
-			continue
-		}
-		if _, err := os.Stat(filepath.Join(s.RealmDir, n.Prompt)); err != nil {
-			return nil, fmt.Errorf("%s: node %s: %w", graphPath, n.ID, err)
-		}
-		if s.Agents[n.Role] != nil {
-			continue
-		}
-		role, ok := s.Config.Roles[n.Role]
-		if !ok {
-			return nil, fmt.Errorf("%s: node %s uses role %s, which %s doesn't define", graphPath, n.ID, n.Role, s.ConfigPath)
-		}
-		if s.Agents[n.Role], err = agents.New(role, filepath.Dir(s.ConfigPath)); err != nil {
-			return nil, fmt.Errorf("role %s: %w", n.Role, err)
+		if err := s.checkNode(ctx, graphPath, n); err != nil {
+			return nil, err
 		}
 	}
 	if o.Brief != "" {
@@ -110,6 +111,80 @@ func Prepare(o Options) (*Setup, error) {
 	return s, nil
 }
 
+// findProject places the project in the instance tree: Odin runs on nothing outside it, because a
+// resume resets leaves (spec §4.3).
+func (s *Setup) findProject(ctx context.Context, project string) error {
+	var err error
+	if s.Root, s.ProjectPath, err = tree.FindRoot(ctx, project); err != nil {
+		return err
+	}
+	nodes, err := tree.Resolve(ctx, s.Root, s.ProjectPath)
+	if err != nil {
+		return err
+	}
+	s.Project = nodes[len(nodes)-1]
+	if s.Project.Kind != schema.ChildUmbrella {
+		return fmt.Errorf("%s is a leaf; --project names a project umbrella", project)
+	}
+	s.Repos["."] = s.Project
+	return nil
+}
+
+// checkNode checks that node n can run in this project: its repo, its role and prompt, its checks.
+func (s *Setup) checkNode(ctx context.Context, graphPath string, n schema.Node) error {
+	if n.Kind == schema.KindGate {
+		return nil
+	}
+	if n.Repo == "" {
+		return fmt.Errorf("%s: node %s names no repo; every node that does work runs in a repo of the project", graphPath, n.ID)
+	}
+	if _, ok := s.Repos[n.Repo]; !ok {
+		nodes, err := tree.Resolve(ctx, s.Root, filepath.Join(s.ProjectPath, n.Repo))
+		if err != nil {
+			return fmt.Errorf("%s: node %s works in %s, which the project lacks: %w", graphPath, n.ID, n.Repo, err)
+		}
+		s.Repos[n.Repo] = nodes[len(nodes)-1]
+	}
+	if n.Kind != schema.KindExec && s.Repos[n.Repo].Kind != schema.ChildLeaf {
+		return fmt.Errorf("%s: node %s works in %s, which is an umbrella; agents, merges and pointer moves work in a leaf (spec §3.3)", graphPath, n.ID, n.Repo)
+	}
+	for _, c := range slices.Concat(n.Checks, n.Acceptance) {
+		if _, ok := s.Pack.Checks[c]; !ok {
+			return fmt.Errorf("%s: node %s runs check %s, which the pack doesn't define", graphPath, n.ID, c)
+		}
+	}
+	if n.Kind != schema.KindAgent {
+		return nil
+	}
+	if _, err := os.Stat(filepath.Join(s.RealmDir, n.Prompt)); err != nil {
+		return fmt.Errorf("%s: node %s: %w", graphPath, n.ID, err)
+	}
+	if s.Agents[n.Role] != nil {
+		return nil
+	}
+	role, ok := s.Config.Roles[n.Role]
+	if !ok {
+		return fmt.Errorf("%s: node %s uses role %s, which %s doesn't define", graphPath, n.ID, n.Role, s.ConfigPath)
+	}
+	var err error
+	if s.Agents[n.Role], err = agents.New(role, filepath.Dir(s.ConfigPath)); err != nil {
+		return fmt.Errorf("role %s: %w", n.Role, err)
+	}
+	return nil
+}
+
+// Leaves returns the paths of the leaves the graph works in, sorted.
+func (s *Setup) Leaves() []string {
+	var ls []string
+	for p, n := range s.Repos {
+		if n.Kind == schema.ChildLeaf {
+			ls = append(ls, p)
+		}
+	}
+	slices.Sort(ls)
+	return ls
+}
+
 // Run is an open run: its directory, state, setup, ledger and lock.
 type Run struct {
 	Project string
@@ -121,8 +196,15 @@ type Run struct {
 	changes []gungnir.Event // a mode or config switch Open found, not yet in the ledger
 }
 
-// Workspace is the directory agents and exec nodes work in. Phase 2 replaces it with the leaf.
-func (r *Run) Workspace() string { return filepath.Join(r.Project, "workspace") }
+// RepoDir is the working copy of a repo the graph names.
+func (r *Run) RepoDir(repo string) string { return r.Setup.Repos[repo].Dir }
+
+// Leaf returns a leaf the graph works in.
+func (r *Run) Leaf(repo string) (*leaf.Leaf, error) { return leaf.Open(r.Setup.Repos[repo]) }
+
+// Home is the HOME of exec nodes: the run's own directory, never a repo, so caches don't end up
+// in a commit.
+func (r *Run) Home() string { return filepath.Join(r.Dir, "home") }
 
 // Log appends e to the ledger, with the run's id. A switch Open found is logged first.
 func (r *Run) Log(e gungnir.Event) error {
@@ -164,28 +246,32 @@ func (r *Run) Close() error {
 	return err
 }
 
-// Start prepares a new run, then creates its directory, run.json and first ledger line. If
-// Prepare refuses, nothing is created.
-func Start(o Options) (*Run, error) {
-	setup, err := Prepare(o)
-	if err != nil {
-		return nil, err
-	}
-	project, err := filepath.Abs(o.Project)
+// Start prepares a new run, then creates its directory, run.json and first ledger line. If Prepare
+// refuses, or the run can't be recorded, nothing is left behind.
+func Start(ctx context.Context, o Options) (*Run, error) {
+	setup, err := Prepare(ctx, o)
 	if err != nil {
 		return nil, err
 	}
+	project := setup.Project.Dir
 	id, err := NewIDNow()
 	if err != nil {
 		return nil, err
 	}
 	dir := Dir(project, id)
-	if err := os.MkdirAll(dir, 0o755); err != nil {
+	if err := os.MkdirAll(filepath.Join(dir, "home"), 0o755); err != nil {
 		return nil, err
 	}
-	if err := os.MkdirAll(filepath.Join(project, "workspace"), 0o755); err != nil {
+	r, err := record(project, dir, id, setup)
+	if err != nil {
+		os.RemoveAll(dir) // the run's own new directory: nothing ran
 		return nil, err
 	}
+	return r, nil
+}
+
+// record locks the new run and writes its run.json and first ledger line.
+func record(project, dir, id string, setup *Setup) (*Run, error) {
 	unlock, err := Lock(dir)
 	if err != nil {
 		return nil, err
@@ -196,16 +282,13 @@ func Start(o Options) (*Run, error) {
 		return nil, err
 	}
 	now := time.Now().UTC()
-	roles := map[string]RoleRecord{}
-	for name := range setup.Agents {
-		roles[name] = RoleRecord{Agent: setup.Config.Roles[name].Agent, Model: setup.Config.Roles[name].Model}
-	}
 	r := &Run{Project: project, Dir: dir, Setup: setup, Ledger: l, unlock: unlock, State: &State{
 		ID: id, Status: StatusRunning, Mode: setup.Mode,
 		Realm: setup.Pack.Name, RealmVersion: setup.Pack.Version, RealmDir: setup.RealmDir,
 		GraphVersion: setup.Graph.Version, GraphSHA256: setup.GraphSHA256,
 		ConfigPath: setup.ConfigPath, ConfigSHA256: setup.ConfigSHA256,
-		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles,
+		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles(setup),
+		Root: setup.Root, ProjectPath: setup.ProjectPath,
 		Attempts: map[string]int{}, Reasons: map[string]string{}, Summaries: map[string]string{},
 		Created: now, Updated: now,
 	}}
@@ -213,13 +296,25 @@ func Start(o Options) (*Run, error) {
 		r.Close()
 		return nil, err
 	}
-	return r, r.Save()
+	if err := r.Save(); err != nil {
+		r.Close()
+		return nil, err
+	}
+	return r, nil
+}
+
+func roles(setup *Setup) map[string]RoleRecord {
+	roles := map[string]RoleRecord{}
+	for name := range setup.Agents {
+		roles[name] = RoleRecord{Agent: setup.Config.Roles[name].Agent, Model: setup.Config.Roles[name].Model}
+	}
+	return roles
 }
 
 // Open locks and loads run id for resume, approve or reject, and checks that it may continue: the
-// caps are still complete, the graph and brief are unchanged, and the ledger reaches the anchor in
+// caps are still complete, the graph and brief are unchanged, the ledger reaches the anchor in
 // run.json. mode switches the run's mode at this pause ("" keeps it); a switch is logged.
-func Open(project, id string, mode gungnir.Mode) (*Run, error) {
+func Open(ctx context.Context, project, id string, mode gungnir.Mode) (*Run, error) {
 	if !ValidID(id) {
 		return nil, fmt.Errorf("%q is not a run id", id)
 	}
@@ -235,7 +330,7 @@ func Open(project, id string, mode gungnir.Mode) (*Run, error) {
 	if err != nil {
 		return nil, err
 	}
-	r, err := open(project, dir, mode)
+	r, err := open(ctx, project, dir, mode)
 	if err != nil {
 		unlock()
 		return nil, err
@@ -244,7 +339,7 @@ func Open(project, id string, mode gungnir.Mode) (*Run, error) {
 	return r, nil
 }
 
-func open(project, dir string, mode gungnir.Mode) (*Run, error) {
+func open(ctx context.Context, project, dir string, mode gungnir.Mode) (*Run, error) {
 	s, err := LoadState(dir)
 	if err != nil {
 		return nil, err
@@ -252,7 +347,7 @@ func open(project, dir string, mode gungnir.Mode) (*Run, error) {
 	if mode == "" {
 		mode = s.Mode
 	}
-	setup, err := Prepare(Options{Project: project, Config: s.ConfigPath, Realm: s.RealmDir, Brief: s.Brief, Mode: mode})
+	setup, err := Prepare(ctx, Options{Project: project, Config: s.ConfigPath, Realm: s.RealmDir, Brief: s.Brief, Mode: mode})
 	if err != nil {
 		return nil, err
 	}
@@ -262,6 +357,9 @@ func open(project, dir string, mode gungnir.Mode) (*Run, error) {
 	if setup.BriefSHA256 != s.BriefSHA256 {
 		return nil, errors.New("the brief changed since the run started; a brief is frozen, so start a new run")
 	}
+	if setup.Root != s.Root || setup.ProjectPath != s.ProjectPath {
+		return nil, fmt.Errorf("the run belongs to %s in %s, not this project", s.ProjectPath, s.Root)
+	}
 	l, err := ledger.Open(filepath.Join(dir, "ledger.jsonl"), s.Ledger)
 	if err != nil {
 		return nil, err
@@ -273,7 +371,7 @@ func open(project, dir string, mode gungnir.Mode) (*Run, error) {
 		}
 		s.Exec = nil
 	}
-	r := &Run{Project: project, Dir: dir, State: s, Setup: setup, Ledger: l, unlock: func() {}}
+	r := &Run{Project: setup.Project.Dir, Dir: dir, State: s, Setup: setup, Ledger: l, unlock: func() {}}
 	// The switches apply in memory now, and reach the ledger and run.json with the command's first
 	// write (Log or Save). A refused command writes nothing, so it switches nothing.
 	if setup.ConfigSHA256 != s.ConfigSHA256 {
```

to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index ec41098..413004b 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -120,7 +120,7 @@ func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 	if err := r.Log(start); err != nil {
 		return err
 	}
-	task := gungnir.Task{Role: n.Role, Node: n.ID, Attempt: attempt, Prompt: text, Workdir: r.Workspace(),
+	task := gungnir.Task{Role: n.Role, Node: n.ID, Attempt: attempt, Prompt: text, Workdir: r.RepoDir(n.Repo),
 		Model: role.Model, ReadOnly: n.ReadOnly, MaxTurns: n.MaxTurns, Timeout: time.Duration(n.Timeout),
 		TranscriptDir: filepath.Join(r.Dir, "transcripts")}
 	actx, cancel := ctx, context.CancelFunc(func() {})
@@ -159,8 +159,8 @@ func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 	return nil
 }
 
-// runExec runs n's command in the workspace, without a shell. The command gets only PATH, HOME
-// (the workspace) and LANG, so no credential in the operator's environment reaches it. A cancel
+// runExec runs n's command in its repo, without a shell. The command gets only PATH, HOME (the
+// run's own directory, so caches never land in a repo) and LANG, so no credential in the operator's environment reaches it. A cancel
 // or timeout kills the command's whole process group (spec §6.2). Phase 3 moves leaf commands
 // into the sandbox.
 func runExec(ctx context.Context, r *run.Run, n schema.Node) error {
@@ -187,8 +187,8 @@ func runExec(ctx context.Context, r *run.Run, n schema.Node) error {
 	cctx, cancel := context.WithTimeout(ctx, timeout)
 	defer cancel()
 	cmd := exec.CommandContext(cctx, n.Run[0], n.Run[1:]...)
-	cmd.Dir = r.Workspace()
-	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + r.Workspace(), "LANG=C.UTF-8"}
+	cmd.Dir = r.RepoDir(n.Repo)
+	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + r.Home(), "LANG=C.UTF-8"}
 	cmd.Stdout, cmd.Stderr = out, out
 	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
 	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
```

to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index c3e251c..43467e7 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -121,7 +121,7 @@ func (c *command) run(args []string) int {
 	if !ok {
 		return ExitRefused
 	}
-	r, err := run.Start(run.Options{Project: f.project, Config: f.config, Realm: f.realm, Brief: f.brief, Mode: mode})
+	r, err := run.Start(c.ctx, run.Options{Project: f.project, Config: f.config, Realm: f.realm, Brief: f.brief, Mode: mode})
 	if err != nil {
 		return c.refuse(err)
 	}
@@ -136,7 +136,7 @@ func (c *command) open(f *flags, id string) (*run.Run, int) {
 	if !ok {
 		return nil, ExitRefused
 	}
-	r, err := run.Open(f.project, id, mode)
+	r, err := run.Open(c.ctx, f.project, id, mode)
 	if err != nil {
 		return nil, c.refuse(err)
 	}
```

to `testdata/toy/graph.yaml`:

```diff
diff --git a/testdata/toy/graph.yaml b/testdata/toy/graph.yaml
index 7884535..b18d58c 100644
--- a/testdata/toy/graph.yaml
+++ b/testdata/toy/graph.yaml
@@ -1,14 +1,15 @@
-# The toy graph: every node kind and four approval points, with a scripted agent (spec §13).
+# The toy graph: every node kind and four approval points, with a scripted agent (spec §13). Its
+# nodes work in one leaf of the project, repos/app.
 name: toy
-version: 1.0.0
+version: 2.0.0
 nodes:
-  - { id: design, kind: agent, role: planner, prompt: prompts/design.md }
+  - { id: design, kind: agent, role: planner, prompt: prompts/design.md, repo: repos/app }
   - { id: design-gate, kind: gate, gate: design }
-  - { id: spec, kind: agent, role: planner, prompt: prompts/spec.md }
+  - { id: spec, kind: agent, role: planner, prompt: prompts/spec.md, repo: repos/app }
   - { id: spec-gate, kind: gate, gate: spec }
-  - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md }
-  - { id: dor, kind: exec, run: [test, -s, plan.md] }
+  - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md, repo: repos/app }
+  - { id: dor, kind: exec, run: [test, -s, plan.md], repo: repos/app }
   - { id: plan-gate, kind: gate, gate: plan, reruns: plan }
-  - { id: build, kind: agent, role: implementer, prompt: prompts/build.md }
-  - { id: check, kind: exec, run: [grep, -q, done, build.txt] }
+  - { id: build, kind: agent, role: implementer, prompt: prompts/build.md, repo: repos/app }
+  - { id: check, kind: exec, run: [grep, -q, done, build.txt], repo: repos/app }
   - { id: feature-gate, kind: gate, gate: feature }
```

and to `testdata/toy/pack.yaml`:

```diff
diff --git a/testdata/toy/pack.yaml b/testdata/toy/pack.yaml
index 7945315..62ea3c4 100644
--- a/testdata/toy/pack.yaml
+++ b/testdata/toy/pack.yaml
@@ -1,3 +1,3 @@
 name: toy
-version: 0.1.0
+version: 0.2.0
 graph: graph.yaml
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T052: a branch per leaf

A run works on its own branch in every leaf (decision 8), and a run that fails once it has started is
recorded as failed (decision 16).

**Files (in `odin`):**
- Modify: `internal/run/run.go`, `internal/run/state.go`, `internal/run/tree_test.go`

**Interfaces:**
- Produces: `run.Branch(id) string` (`ygg/<id>`); `run.State.Leaves map[string]run.LeafRecord`, with
  `LeafRecord{Branch, Base, Checkpoint string}`; `run.Failed{ID string; Err error}`.

**Acceptance criteria:**
- [ ] Start checks out `ygg/<run-id>` from `main` in each leaf the graph names, and records the
      branch, the base and the checkpoint (the base, so far) in `run.json`.
- [ ] A leaf with a person's uncommitted edit fails the start: `Start` returns a `*Failed`,
      `run.json` records the run as failed with why, and the edit stays.

**Named test:** `go test ./internal/run/ -run 'TestARunWorksInItsProjectsLeaves|TestAFailureAfterTheRunStartedIsRecorded'`.
**Layer:** `odin`. **Size:** S (80). **Depends on:** v0-T051.

- [ ] **Step 1:** apply to `internal/run/tree_test.go`:

```diff
diff --git a/internal/run/tree_test.go b/internal/run/tree_test.go
index b84fef7..45b9a1e 100644
--- a/internal/run/tree_test.go
+++ b/internal/run/tree_test.go
@@ -8,6 +8,7 @@ import (
 	"strings"
 	"testing"
 
+	"github.com/ouroboric-dev/odin/internal/git"
 	"github.com/ouroboric-dev/odin/internal/tree"
 	"github.com/ouroboric-dev/odin/internal/tree/treetest"
 )
@@ -23,7 +24,7 @@ func startToyRun(t *testing.T, config string) *Run {
 	return r
 }
 
-func TestARunFindsItsProjectAndReposInTheTree(t *testing.T) {
+func TestARunWorksInItsProjectsLeaves(t *testing.T) {
 	project := treetest.Project(t, "repos/app")
 	r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
 	if err != nil {
@@ -35,13 +36,17 @@ func TestARunFindsItsProjectAndReposInTheTree(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
-	if r.RepoDir("repos/app") != nodes[1].Dir || r.RepoDir(".") != project {
-		t.Errorf("the run's repos are %s and %s", r.RepoDir("repos/app"), r.RepoDir("."))
-	}
+	app := git.Repo{GitDir: nodes[1].GitDir, WorkTree: nodes[1].Dir}
 	s, err := LoadState(Dir(project, id))
 	if err != nil {
 		t.Fatal(err)
 	}
+	rec := s.Leaves["repos/app"]
+	head, _ := app.Run(ctx, "rev-parse", "HEAD")
+	branch, _ := app.Run(ctx, "rev-parse", "--abbrev-ref", "HEAD")
+	if rec.Branch != "ygg/"+id || branch != rec.Branch || rec.Base != head || rec.Checkpoint != head {
+		t.Errorf("leaf record = %+v; the leaf is on %s at %s", rec, branch, head)
+	}
 	if s.Root != project || s.ProjectPath != "" {
 		t.Errorf("run.json places the run at %s in %s", s.ProjectPath, s.Root)
 	}
@@ -94,6 +99,26 @@ func TestPrepareRefusesAGraphTheProjectCantRun(t *testing.T) {
 	}
 }
 
+func TestAFailureAfterTheRunStartedIsRecorded(t *testing.T) {
+	project := treetest.Project(t, "repos/app")
+	nodes, err := tree.Resolve(ctx, project, "repos/app")
+	if err != nil {
+		t.Fatal(err)
+	}
+	if err := os.WriteFile(filepath.Join(nodes[1].Dir, "README.md"), []byte("a person's edit\n"), 0o644); err != nil {
+		t.Fatal(err)
+	}
+	_, err = Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
+	var f *Failed
+	if !errors.As(err, &f) || !strings.Contains(err.Error(), "uncommitted") {
+		t.Fatalf("Start() = %v, want a *Failed: the leaf has a person's uncommitted edit", err)
+	}
+	s, err := LoadState(Dir(project, f.ID))
+	if err != nil || s.Status != StatusFailed || !strings.Contains(s.Error, "uncommitted") {
+		t.Errorf("run.json = %+v, %v; want the run recorded as failed, with why", s, err)
+	}
+}
+
 // A project MAY hold sub-projects (change project-is-its-own-tree): a run in one finds the root
 // above it, and works in the sub-project's own leaves.
 func TestARunWorksInASubProject(t *testing.T) {
```

- [ ] **Step 2:** run `go test ./internal/run/`; expect a build failure:
      `s.Leaves undefined (type *State has no field or method Leaves)`.
- [ ] **Step 3:** apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index 9d3789f..98939ff 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -59,6 +59,7 @@ type State struct {
 	Roles        map[string]RoleRecord `json:"roles"`
 	Root         string                `json:"root"`                // the instance root, L0
 	ProjectPath  string                `json:"project"`             // the project's path from the root
+	Leaves       map[string]LeafRecord `json:"leaves"`              // leaf path from the project: the run's branch and checkpoint in it
 	Position     int                   `json:"position"`            // index of the next node to run
 	Attempts     map[string]int        `json:"attempts"`            // node id: attempts started
 	Pending      string                `json:"pending,omitempty"`   // the node waiting for a decision
@@ -72,6 +73,13 @@ type State struct {
 	Updated      time.Time             `json:"updated"`
 }
 
+// LeafRecord is where a run stands in one leaf (spec §4.3).
+type LeafRecord struct {
+	Branch     string `json:"branch"`     // the run's branch: ygg/<run id>
+	Base       string `json:"base"`       // the leaf's main when the run started
+	Checkpoint string `json:"checkpoint"` // the last checkpoint commit; resume resets the leaf to it
+}
+
 var idPattern = regexp.MustCompile(`^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$`)
 
 // NewID returns a run id: the UTC time and six random hex digits, such as 20261015-142233-a1b2c3.
@@ -152,6 +160,9 @@ func LoadState(dir string) (*State, error) {
 	if s.Summaries == nil {
 		s.Summaries = map[string]string{}
 	}
+	if s.Leaves == nil {
+		s.Leaves = map[string]LeafRecord{}
+	}
 	return &s, nil
 }
 
```

and to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 5a190dd..9c03e18 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -196,6 +196,9 @@ type Run struct {
 	changes []gungnir.Event // a mode or config switch Open found, not yet in the ledger
 }
 
+// Branch is the branch a run works on in every leaf.
+func Branch(id string) string { return "ygg/" + id }
+
 // RepoDir is the working copy of a repo the graph names.
 func (r *Run) RepoDir(repo string) string { return r.Setup.Repos[repo].Dir }
 
@@ -246,8 +249,18 @@ func (r *Run) Close() error {
 	return err
 }
 
-// Start prepares a new run, then creates its directory, run.json and first ledger line. If Prepare
-// refuses, or the run can't be recorded, nothing is left behind.
+// Failed is a run that started and then failed before its first node; run.json records why.
+type Failed struct {
+	ID  string
+	Err error
+}
+
+func (f *Failed) Error() string { return fmt.Sprintf("run %s failed: %v", f.ID, f.Err) }
+func (f *Failed) Unwrap() error { return f.Err }
+
+// Start prepares a new run, then creates its directory, run.json and first ledger line, and starts
+// the run's branch in every leaf. If Prepare refuses, or the run can't be recorded, nothing is left
+// behind. A failure after that is a *Failed.
 func Start(ctx context.Context, o Options) (*Run, error) {
 	setup, err := Prepare(ctx, o)
 	if err != nil {
@@ -267,7 +280,14 @@ func Start(ctx context.Context, o Options) (*Run, error) {
 		os.RemoveAll(dir) // the run's own new directory: nothing ran
 		return nil, err
 	}
-	return r, nil
+	if err := r.begin(ctx); err != nil {
+		r.State.Status, r.State.Error = StatusFailed, err.Error()
+		r.Log(gungnir.Event{Name: gungnir.EventRunFailed, Result: r.State.Error})
+		r.Save()
+		r.Close()
+		return nil, &Failed{ID: id, Err: err}
+	}
+	return r, r.Save()
 }
 
 // record locks the new run and writes its run.json and first ledger line.
@@ -288,7 +308,7 @@ func record(project, dir, id string, setup *Setup) (*Run, error) {
 		GraphVersion: setup.Graph.Version, GraphSHA256: setup.GraphSHA256,
 		ConfigPath: setup.ConfigPath, ConfigSHA256: setup.ConfigSHA256,
 		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles(setup),
-		Root: setup.Root, ProjectPath: setup.ProjectPath,
+		Root: setup.Root, ProjectPath: setup.ProjectPath, Leaves: map[string]LeafRecord{},
 		Attempts: map[string]int{}, Reasons: map[string]string{}, Summaries: map[string]string{},
 		Created: now, Updated: now,
 	}}
@@ -311,6 +331,22 @@ func roles(setup *Setup) map[string]RoleRecord {
 	return roles
 }
 
+// begin starts the run's branch in every leaf.
+func (r *Run) begin(ctx context.Context) error {
+	for _, p := range r.Setup.Leaves() {
+		l, err := r.Leaf(p)
+		if err != nil {
+			return err
+		}
+		head, err := l.StartBranch(ctx, Branch(r.State.ID), "main")
+		if err != nil {
+			return err
+		}
+		r.State.Leaves[p] = LeafRecord{Branch: Branch(r.State.ID), Base: head, Checkpoint: head}
+	}
+	return nil
+}
+
 // Open locks and loads run id for resume, approve or reject, and checks that it may continue: the
 // caps are still complete, the graph and brief are unchanged, the ledger reaches the anchor in
 // run.json. mode switches the run's mode at this pause ("" keeps it); a switch is logged.
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T053: the realm creates the leaves a project lacks

The Odin half of `remote-creates-repos-T001`, its `init` criterion (decision 6).

**Files (in `odin`):**
- Create: `testdata/toy/templates/app/LICENSE`
- Modify: `internal/run/run.go`, `internal/run/tree_test.go`, `testdata/toy/graph.yaml`,
  `testdata/toy/pack.yaml`

**Interfaces:**
- Consumes: `remote.NewLocal` (v0-T046); `schema.Pack.Leaves` (v0-T041).
- Produces: `run.Setup.Create []string`, the leaves Start creates.

**Acceptance criteria:**
- [ ] A run in a project that lacks the toy realm's leaf creates it through the local remote, before
      any node: its first commit holds the template's `LICENSE` only, the project has a commit for
      it, and the ledger has `repo_created`.
- [ ] A second run in the project uses the leaf and creates nothing.
- [ ] A repo the project lacks and the realm doesn't declare is refused.

**Named test:** `go test ./internal/run/ -run 'TestTheRealmCreatesTheLeavesAProjectLacks|TestPrepareRefusesAGraphTheProjectCantRun'`.
**Layer:** `odin`. **Size:** S (95). **Depends on:** v0-T046, v0-T052.

- [ ] **Step 1:** apply to `internal/run/tree_test.go`:

```diff
diff --git a/internal/run/tree_test.go b/internal/run/tree_test.go
index 45b9a1e..c5e753a 100644
--- a/internal/run/tree_test.go
+++ b/internal/run/tree_test.go
@@ -74,7 +74,7 @@ func TestPrepareRefusesAGraphTheProjectCantRun(t *testing.T) {
 	cases := map[string]struct{ nodes, want string }{
 		"a node with no repo":       {"  - { id: a, kind: exec, run: [echo] }\n", "names no repo"},
 		"an agent in the umbrella":  {"  - { id: a, kind: agent, role: planner, prompt: p.md, repo: . }\n", "is an umbrella"},
-		"a repo the project lacks":  {"  - { id: a, kind: exec, run: [echo], repo: repos/other }\n", "the project lacks"},
+		"a repo nobody creates":     {"  - { id: a, kind: exec, run: [echo], repo: repos/other }\n", "the realm doesn't create"},
 		"a check the pack lacks":    {"  - { id: m, kind: merge, repo: repos/app, checks: [lint] }\n", "doesn't define"},
 		"a pointer for an umbrella": {"  - { id: p, kind: pointer, repo: repos/app }\n  - { id: q, kind: pointer, repo: sub }\n", "the project lacks"},
 	}
@@ -119,6 +119,38 @@ func TestAFailureAfterTheRunStartedIsRecorded(t *testing.T) {
 	}
 }
 
+func TestTheRealmCreatesTheLeavesAProjectLacks(t *testing.T) {
+	project := treetest.Project(t) // no leaves yet
+	commits, _ := git.Run(ctx, project, "rev-list", "--count", "HEAD")
+	r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
+	if err != nil {
+		t.Fatalf("Start() = %v", err)
+	}
+	r.Close()
+	nodes, err := tree.Resolve(ctx, project, "repos/app")
+	if err != nil {
+		t.Fatalf("the toy realm's leaf isn't in the tree: %v", err)
+	}
+	app := git.Repo{GitDir: nodes[1].GitDir, WorkTree: nodes[1].Dir}
+	if files, _ := app.Run(ctx, "ls-tree", "-r", "--name-only", r.State.Leaves["repos/app"].Base); files != "LICENSE" {
+		t.Errorf("the leaf's first commit holds %q, want the template's LICENSE only", files)
+	}
+	if after, _ := git.Run(ctx, project, "rev-list", "--count", "HEAD"); after == commits {
+		t.Error("the project has no commit recording the new leaf")
+	}
+	if b, _ := os.ReadFile(filepath.Join(r.Dir, "ledger.jsonl")); !strings.Contains(string(b), `"event":"repo_created"`) {
+		t.Error("the ledger doesn't record the created leaf")
+	}
+	second, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
+	if err != nil {
+		t.Fatalf("a second run in the project = %v", err)
+	}
+	second.Close()
+	if b, _ := os.ReadFile(filepath.Join(second.Dir, "ledger.jsonl")); strings.Contains(string(b), "repo_created") {
+		t.Error("the second run created the leaf again")
+	}
+}
+
 // A project MAY hold sub-projects (change project-is-its-own-tree): a run in one finds the root
 // above it, and works in the sub-project's own leaves.
 func TestARunWorksInASubProject(t *testing.T) {
```

- [ ] **Step 2:** run the named test; expect `TestTheRealmCreatesTheLeavesAProjectLacks` to fail with
      `node design works in repos/app, which the project lacks`, and
      `TestPrepareRefusesAGraphTheProjectCantRun` with `a repo nobody creates`.
- [ ] **Step 3:** apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 9c03e18..edab2f1 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -17,6 +17,7 @@ import (
 	"github.com/ouroboric-dev/odin/internal/agents"
 	"github.com/ouroboric-dev/odin/internal/leaf"
 	"github.com/ouroboric-dev/odin/internal/ledger"
+	"github.com/ouroboric-dev/odin/internal/remote"
 	"github.com/ouroboric-dev/odin/internal/tree"
 )
 
@@ -48,6 +49,7 @@ type Setup struct {
 	ProjectPath string               // the project's path from the root
 	Project     tree.Node            // the project umbrella
 	Repos       map[string]tree.Node // every repo the graph names, by path from the project; "." is the project
+	Create      []string             // leaves the project lacks, which Start creates from the realm's templates
 }
 
 // Prepare loads and checks the config, the realm, the brief and the project's place in the
@@ -138,14 +140,18 @@ func (s *Setup) checkNode(ctx context.Context, graphPath string, n schema.Node)
 	if n.Repo == "" {
 		return fmt.Errorf("%s: node %s names no repo; every node that does work runs in a repo of the project", graphPath, n.ID)
 	}
-	if _, ok := s.Repos[n.Repo]; !ok {
+	if _, ok := s.Repos[n.Repo]; !ok && !slices.Contains(s.Create, n.Repo) {
 		nodes, err := tree.Resolve(ctx, s.Root, filepath.Join(s.ProjectPath, n.Repo))
-		if err != nil {
-			return fmt.Errorf("%s: node %s works in %s, which the project lacks: %w", graphPath, n.ID, n.Repo, err)
+		switch _, creatable := s.Pack.Leaves[n.Repo]; {
+		case err == nil:
+			s.Repos[n.Repo] = nodes[len(nodes)-1]
+		case creatable:
+			s.Create = append(s.Create, n.Repo)
+		default:
+			return fmt.Errorf("%s: node %s works in %s, which the project lacks and the realm doesn't create: %w", graphPath, n.ID, n.Repo, err)
 		}
-		s.Repos[n.Repo] = nodes[len(nodes)-1]
 	}
-	if n.Kind != schema.KindExec && s.Repos[n.Repo].Kind != schema.ChildLeaf {
+	if n.Kind != schema.KindExec && !s.isLeaf(n.Repo) {
 		return fmt.Errorf("%s: node %s works in %s, which is an umbrella; agents, merges and pointer moves work in a leaf (spec §3.3)", graphPath, n.ID, n.Repo)
 	}
 	for _, c := range slices.Concat(n.Checks, n.Acceptance) {
@@ -173,6 +179,14 @@ func (s *Setup) checkNode(ctx context.Context, graphPath string, n schema.Node)
 	return nil
 }
 
+// isLeaf reports whether repo is a leaf: one the tree records as a leaf, or one Start creates.
+func (s *Setup) isLeaf(repo string) bool {
+	if n, ok := s.Repos[repo]; ok {
+		return n.Kind == schema.ChildLeaf
+	}
+	return slices.Contains(s.Create, repo)
+}
+
 // Leaves returns the paths of the leaves the graph works in, sorted.
 func (s *Setup) Leaves() []string {
 	var ls []string
@@ -258,9 +272,9 @@ type Failed struct {
 func (f *Failed) Error() string { return fmt.Sprintf("run %s failed: %v", f.ID, f.Err) }
 func (f *Failed) Unwrap() error { return f.Err }
 
-// Start prepares a new run, then creates its directory, run.json and first ledger line, and starts
-// the run's branch in every leaf. If Prepare refuses, or the run can't be recorded, nothing is left
-// behind. A failure after that is a *Failed.
+// Start prepares a new run, then creates its directory, run.json and first ledger line, creates
+// the leaves the project lacks, and starts the run's branch in every leaf. If Prepare refuses, or
+// the run can't be recorded, nothing is left behind. A failure after that is a *Failed.
 func Start(ctx context.Context, o Options) (*Run, error) {
 	setup, err := Prepare(ctx, o)
 	if err != nil {
@@ -331,9 +345,15 @@ func roles(setup *Setup) map[string]RoleRecord {
 	return roles
 }
 
-// begin starts the run's branch in every leaf.
+// begin creates the leaves the project lacks and starts the run's branch in every leaf.
 func (r *Run) begin(ctx context.Context) error {
-	for _, p := range r.Setup.Leaves() {
+	s := r.Setup
+	for _, p := range s.Create {
+		if err := r.createLeaf(ctx, p); err != nil {
+			return err
+		}
+	}
+	for _, p := range s.Leaves() {
 		l, err := r.Leaf(p)
 		if err != nil {
 			return err
@@ -347,6 +367,34 @@ func (r *Run) begin(ctx context.Context) error {
 	return nil
 }
 
+// createLeaf creates leaf p in the project through the remote, from the realm's template (spec
+// §4.1; change remote-creates-repos).
+func (r *Run) createLeaf(ctx context.Context, p string) error {
+	s := r.Setup
+	pl := s.Pack.Leaves[p]
+	files := map[string][]byte{}
+	for _, f := range pl.FirstCommit {
+		b, err := os.ReadFile(filepath.Join(s.RealmDir, pl.Template, f))
+		if err != nil {
+			return err
+		}
+		files[f] = b
+	}
+	repo := gungnir.Repo{Owner: s.Project.Owner, Name: filepath.Base(p), Visibility: s.Project.Visibility,
+		Description: pl.Description, Path: p, Files: files}
+	rem := remote.NewLocal(s.Project)
+	if err := rem.Create(ctx, repo); err != nil {
+		return err
+	}
+	nodes, err := tree.Resolve(ctx, s.Root, filepath.Join(s.ProjectPath, p))
+	if err != nil {
+		return err
+	}
+	s.Repos[p] = nodes[len(nodes)-1]
+	s.Create = slices.DeleteFunc(s.Create, func(c string) bool { return c == p })
+	return r.Log(gungnir.Event{Name: gungnir.EventRepoCreated, Note: fmt.Sprintf("%s (%s remote)", p, rem.Name())})
+}
+
 // Open locks and loads run id for resume, approve or reject, and checks that it may continue: the
 // caps are still complete, the graph and brief are unchanged, the ledger reaches the anchor in
 // run.json. mode switches the run's mode at this pause ("" keeps it); a switch is logged.
```

write `testdata/toy/templates/app/LICENSE`:

```text
The toy app is a test fixture of Odin, AGPL-3.0-only.
```

and apply to `testdata/toy/pack.yaml`:

```diff
diff --git a/testdata/toy/pack.yaml b/testdata/toy/pack.yaml
index 62ea3c4..0f0daeb 100644
--- a/testdata/toy/pack.yaml
+++ b/testdata/toy/pack.yaml
@@ -1,3 +1,5 @@
 name: toy
 version: 0.2.0
 graph: graph.yaml
+leaves:
+  repos/app: { description: the toy app, template: templates/app, first_commit: [LICENSE] }
```

and to `testdata/toy/graph.yaml`:

```diff
diff --git a/testdata/toy/graph.yaml b/testdata/toy/graph.yaml
index b18d58c..1bd8e8b 100644
--- a/testdata/toy/graph.yaml
+++ b/testdata/toy/graph.yaml
@@ -1,5 +1,5 @@
 # The toy graph: every node kind and four approval points, with a scripted agent (spec §13). Its
-# nodes work in one leaf of the project, repos/app.
+# nodes work in one leaf, repos/app, which the realm creates when a project lacks it.
 name: toy
 version: 2.0.0
 nodes:
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T054: checkpoints, resume, one run per project

Decisions 8 and 10: a checkpoint after every node in a leaf, leaves put back on resume, a waiting run's
leaves left alone, one advancing run per project, and the run lock on the `lock` package. Also two
Phase 1 follow-ups: `run.json` is checked when a run opens, and `status` no longer takes the lock.

**Files (in `odin`):**
- Modify: `internal/run/run.go`, `internal/run/state.go`, `internal/run/tree_test.go`,
  `internal/engine/engine.go`, `internal/engine/gates.go`, `internal/engine/engine_test.go`

**Interfaces:**
- Consumes: `leaf.Checkpoint`, `leaf.Reset`, `leaf.IsPolicy` (v0-T047); `lock.Take`, `lock.Held`
  (v0-T049).
- Produces: `run.ErrProjectBusy`; `run.LockFile(project, repo) string` and `(*Run).LockFile(repo)`;
  `run.State.PendingGate gungnir.Gate`.

**Acceptance criteria:**
- [ ] Every agent or exec node in a leaf ends with a checkpoint commit on the run's branch, named
      after the run, node and attempt; `run.json` records it, the node's `node_finished` line carries
      it, and the leaf has nothing uncommitted.
- [ ] A planted repository fails the node, and nothing is committed (v0-T057 makes it a stop).
- [ ] A second run in a project another process is advancing is refused with `ErrProjectBusy`, and
      leaves no run directory.
- [ ] Opening an interrupted run puts its leaves back to their checkpoints; opening a run that waits
      at an approval point refuses a leaf that changed meanwhile, and keeps the change (review
      focus 2).
- [ ] Open refuses a `run.json` whose position, pending node or leaves don't fit the graph.

**Named test:** `go test ./internal/run/ ./internal/engine/`. **Layer:** `odin`. **Size:** M (250).
**Depends on:** v0-T049, v0-T053.

- [ ] **Step 1:** apply to `internal/run/tree_test.go`:

```diff
diff --git a/internal/run/tree_test.go b/internal/run/tree_test.go
index c5e753a..95d1592 100644
--- a/internal/run/tree_test.go
+++ b/internal/run/tree_test.go
@@ -8,6 +8,7 @@ import (
 	"strings"
 	"testing"
 
+	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/odin/internal/git"
 	"github.com/ouroboric-dev/odin/internal/tree"
 	"github.com/ouroboric-dev/odin/internal/tree/treetest"
@@ -151,6 +152,49 @@ func TestTheRealmCreatesTheLeavesAProjectLacks(t *testing.T) {
 	}
 }
 
+func TestOneRunAdvancesAProjectAtATime(t *testing.T) {
+	r := startToyRun(t, scriptedRoles+fullCaps)
+	defer r.Close()
+	_, err := Start(ctx, Options{Project: r.Project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
+	if !errors.Is(err, ErrProjectBusy) {
+		t.Errorf("a second run in a busy project = %v, want ErrProjectBusy", err)
+	}
+	entries, _ := os.ReadDir(filepath.Join(r.Project, ".factory", "runs"))
+	if len(entries) != 1 {
+		t.Errorf("the refused run left a directory: %d runs", len(entries))
+	}
+}
+
+func TestOpenPutsLeavesBackAtTheirCheckpoints(t *testing.T) {
+	r := startToyRun(t, scriptedRoles+fullCaps)
+	id, project, app := r.State.ID, r.Project, r.RepoDir("repos/app")
+	r.Close()
+	if err := os.WriteFile(filepath.Join(app, "half-done.txt"), []byte("an interrupted node's work\n"), 0o644); err != nil {
+		t.Fatal(err)
+	}
+	r, err := Open(ctx, project, id, "") // the run is "running": it was interrupted, so its node restarts
+	if err != nil {
+		t.Fatalf("Open() = %v", err)
+	}
+	if _, err := os.Stat(filepath.Join(app, "half-done.txt")); err == nil {
+		t.Error("Open() kept an interrupted node's work; the node restarts from its checkpoint")
+	}
+	r.State.Status, r.State.Position, r.State.Pending, r.State.PendingGate = StatusStopped, 1, "design-gate", gungnir.GateDesign
+	if err := r.Save(); err != nil {
+		t.Fatal(err)
+	}
+	r.Close()
+	if err := os.WriteFile(filepath.Join(app, "LICENSE"), []byte("changed by hand\n"), 0o644); err != nil {
+		t.Fatal(err)
+	}
+	if _, err := Open(ctx, project, id, ""); err == nil || !strings.Contains(err.Error(), "changed while the run waited") {
+		t.Errorf("Open() of a waiting run with a changed leaf = %v, want a refusal", err)
+	}
+	if b, _ := os.ReadFile(filepath.Join(app, "LICENSE")); string(b) != "changed by hand\n" {
+		t.Error("Open() discarded a person's change")
+	}
+}
+
 // A project MAY hold sub-projects (change project-is-its-own-tree): a run in one finds the root
 // above it, and works in the sub-project's own leaves.
 func TestARunWorksInASubProject(t *testing.T) {
```

and to `internal/engine/engine_test.go`:

```diff
diff --git a/internal/engine/engine_test.go b/internal/engine/engine_test.go
index f6a953b..ddc3ac1 100644
--- a/internal/engine/engine_test.go
+++ b/internal/engine/engine_test.go
@@ -192,3 +192,44 @@ func TestRunJSONRecordsTheRunningExecProcess(t *testing.T) {
 		t.Errorf("run.json still records an exec process after the node ended: %+v", s.Exec)
 	}
 }
+
+func TestEveryNodeInALeafEndsWithACheckpoint(t *testing.T) {
+	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n  - { id: check, kind: exec, run: [grep, -q, done, out.txt], repo: repos/app }\n", okScript)
+	base := r.State.Leaves["repos/app"].Base
+	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+	l, err := r.Leaf("repos/app")
+	if err != nil {
+		t.Fatal(err)
+	}
+	head, _ := l.Head(context.Background())
+	if cp := r.State.Leaves["repos/app"].Checkpoint; cp != head || cp == base {
+		t.Errorf("checkpoint = %s, head %s, base %s; want the agent's commit recorded", cp, head, base)
+	}
+	if files, _ := l.Git(context.Background(), "show", "--name-only", "--format=%s", head); files != "ygg: run "+r.State.ID+", node a, attempt 1\n\nout.txt" {
+		t.Errorf("the checkpoint commit is %q, want the agent's out.txt under a message naming the node", files)
+	}
+	if st, _ := l.Git(context.Background(), "status", "--porcelain"); st != "" {
+		t.Errorf("the leaf has uncommitted work after the run: %q", st)
+	}
+	if !strings.Contains(ledgerText(t, r), `"ygg.node.id":"a","event":"node_finished"`) || !strings.Contains(ledgerText(t, r), `"ygg.ref.commit":"`+head+`"`) {
+		t.Error("node a's node_finished line doesn't carry its checkpoint commit")
+	}
+}
+
+func TestAPlantedRepositoryFailsTheNodeAndNothingIsCommitted(t *testing.T) {
+	script := "steps:\n  a:\n    - actions:\n        - write: { path: vendor/x/.git/HEAD, content: \"ref: refs/heads/main\\n\" }\n" +
+		"        - write: { path: vendor/x/.git/objects/.keep, content: \"\" }\n        - write: { path: vendor/x/.git/refs/heads/.keep, content: \"\" }\n" +
+		"      result: { status: ok, summary: planted a repo }\n"
+	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n", script)
+	base := r.State.Leaves["repos/app"].Checkpoint
+	out, err := Advance(context.Background(), r)
+	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "policy violation") {
+		t.Fatalf("Advance() = %+v, %v; want the node failed for a policy violation", out, err)
+	}
+	l, _ := r.Leaf("repos/app")
+	if head, _ := l.Head(context.Background()); head != base {
+		t.Error("Odin committed the planted repository")
+	}
+}
```

- [ ] **Step 2:** run `go test ./internal/run/ ./internal/engine/`; expect a build failure in `run`
      (`undefined: ErrProjectBusy`) and, in `engine`, `TestEveryNodeInALeafEndsWithACheckpoint` to
      fail.
- [ ] **Step 3:** apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index 98939ff..cd369fb 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -13,13 +13,14 @@ import (
 	"os"
 	"path/filepath"
 	"regexp"
+	"slices"
 	"strconv"
 	"strings"
-	"syscall"
 	"time"
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/odin/internal/ledger"
+	"github.com/ouroboric-dev/odin/internal/lock"
 )
 
 // StateSchema names the run.json format.
@@ -57,14 +58,15 @@ type State struct {
 	Brief        string                `json:"brief,omitempty"`
 	BriefSHA256  string                `json:"brief_sha256,omitempty"`
 	Roles        map[string]RoleRecord `json:"roles"`
-	Root         string                `json:"root"`                // the instance root, L0
-	ProjectPath  string                `json:"project"`             // the project's path from the root
-	Leaves       map[string]LeafRecord `json:"leaves"`              // leaf path from the project: the run's branch and checkpoint in it
-	Position     int                   `json:"position"`            // index of the next node to run
-	Attempts     map[string]int        `json:"attempts"`            // node id: attempts started
-	Pending      string                `json:"pending,omitempty"`   // the node waiting for a decision
-	Reasons      map[string]string     `json:"reasons,omitempty"`   // node id: rejection reason for its next attempt
-	Summaries    map[string]string     `json:"summaries,omitempty"` // node id: its last result
+	Root         string                `json:"root"`                   // the tree's root: the project, or an umbrella above it
+	ProjectPath  string                `json:"project"`                // the project's path from the root
+	Leaves       map[string]LeafRecord `json:"leaves"`                 // leaf path from the project: the run's branch and checkpoint in it
+	Position     int                   `json:"position"`               // index of the next node to run
+	Attempts     map[string]int        `json:"attempts"`               // node id: attempts started
+	Pending      string                `json:"pending,omitempty"`      // the node waiting for a decision
+	PendingGate  gungnir.Gate          `json:"pending_gate,omitempty"` // the approval point it waits at
+	Reasons      map[string]string     `json:"reasons,omitempty"`      // node id: rejection reason for its next attempt
+	Summaries    map[string]string     `json:"summaries,omitempty"`    // node id: its last result
 	Usage        gungnir.Usage         `json:"usage"`
 	Ledger       ledger.Anchor         `json:"ledger"`
 	Error        string                `json:"error,omitempty"`
@@ -229,26 +231,31 @@ var ErrInUse = errors.New("another ygg process is using this run")
 // Lock takes dir/lock for this process. The kernel drops the lock when the process ends, so a
 // killed run never stays locked.
 func Lock(dir string) (unlock func(), err error) {
-	f, err := os.OpenFile(filepath.Join(dir, "lock"), os.O_RDWR|os.O_CREATE, 0o644)
-	if err != nil {
-		return nil, err
-	}
-	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
-		f.Close()
-		if errors.Is(err, syscall.EWOULDBLOCK) {
-			return nil, ErrInUse
-		}
-		return nil, err
+	unlock, err = lock.Take(filepath.Join(dir, "lock"))
+	if errors.Is(err, lock.ErrHeld) {
+		return nil, ErrInUse
 	}
-	return func() { f.Close() }, nil
+	return unlock, err
 }
 
-// Locked reports whether another process holds dir/lock.
-func Locked(dir string) bool {
-	unlock, err := Lock(dir)
-	if err != nil {
-		return errors.Is(err, ErrInUse)
+// Locked reports whether a process holds dir/lock. It never takes the lock, so a status check
+// can't make another process's resume fail.
+func Locked(dir string) bool { return lock.Held(filepath.Join(dir, "lock")) }
+
+// check refuses a run.json whose position, pending node or leaves don't fit setup's graph and
+// tree. Odin wrote it, but a hand-edited file must not crash the engine.
+func (s *State) check(setup *Setup) error {
+	nodes := setup.Graph.Nodes
+	if s.Position < 0 || s.Position > len(nodes) {
+		return fmt.Errorf("position %d is outside the graph's %d nodes", s.Position, len(nodes))
 	}
-	unlock()
-	return false
+	if s.Pending != "" && (s.Position >= len(nodes) || nodes[s.Position].ID != s.Pending) {
+		return fmt.Errorf("pending %q is not the node at position %d", s.Pending, s.Position)
+	}
+	for p := range s.Leaves {
+		if !slices.Contains(setup.Leaves(), p) {
+			return fmt.Errorf("leaf %s is not one the graph works in", p)
+		}
+	}
+	return nil
 }
```

to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index edab2f1..7904d20 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -6,9 +6,11 @@ import (
 	"encoding/hex"
 	"errors"
 	"fmt"
+	"maps"
 	"os"
 	"path/filepath"
 	"slices"
+	"strings"
 	"syscall"
 	"time"
 
@@ -17,6 +19,7 @@ import (
 	"github.com/ouroboric-dev/odin/internal/agents"
 	"github.com/ouroboric-dev/odin/internal/leaf"
 	"github.com/ouroboric-dev/odin/internal/ledger"
+	"github.com/ouroboric-dev/odin/internal/lock"
 	"github.com/ouroboric-dev/odin/internal/remote"
 	"github.com/ouroboric-dev/odin/internal/tree"
 )
@@ -199,7 +202,7 @@ func (s *Setup) Leaves() []string {
 	return ls
 }
 
-// Run is an open run: its directory, state, setup, ledger and lock.
+// Run is an open run: its directory, state, setup, ledger and locks.
 type Run struct {
 	Project string
 	Dir     string
@@ -223,6 +226,22 @@ func (r *Run) Leaf(repo string) (*leaf.Leaf, error) { return leaf.Open(r.Setup.R
 // in a commit.
 func (r *Run) Home() string { return filepath.Join(r.Dir, "home") }
 
+// LockFile returns the lock file of a repo of the project, in <project>/.factory/locks/.
+func (r *Run) LockFile(repo string) string { return LockFile(r.Project, repo) }
+
+// LockFile returns the lock file of a repo of project.
+func LockFile(project, repo string) string {
+	name := "project"
+	if repo != "." {
+		name = "repo-" + filepath.ToSlash(repo)
+	}
+	return filepath.Join(project, ".factory", "locks", filepath.FromSlash(name)+".lock")
+}
+
+// ErrProjectBusy means another ygg process is advancing a run of the same project. One run at a
+// time walks a project's leaves, which share their working copies.
+var ErrProjectBusy = errors.New("another ygg process is advancing a run of this project")
+
 // Log appends e to the ledger, with the run's id. A switch Open found is logged first.
 func (r *Run) Log(e gungnir.Event) error {
 	if err := r.logChanges(); err != nil {
@@ -256,13 +275,31 @@ func (r *Run) Save() error {
 	return r.State.Save(r.Dir)
 }
 
-// Close closes the ledger and releases the lock.
+// Close closes the ledger and releases the locks.
 func (r *Run) Close() error {
 	err := r.Ledger.Close()
 	r.unlock()
 	return err
 }
 
+// takeLocks takes the run's lock, then the project's, and returns the function that releases
+// both. Neither waits, so the order can't deadlock; run first names the precise conflict.
+func takeLocks(project, dir string) (func(), error) {
+	releaseRun, err := Lock(dir)
+	if err != nil {
+		return nil, err
+	}
+	releaseProject, err := lock.Take(LockFile(project, "."))
+	if err != nil {
+		releaseRun()
+		if errors.Is(err, lock.ErrHeld) {
+			return nil, ErrProjectBusy
+		}
+		return nil, err
+	}
+	return func() { releaseProject(); releaseRun() }, nil
+}
+
 // Failed is a run that started and then failed before its first node; run.json records why.
 type Failed struct {
 	ID  string
@@ -306,7 +343,7 @@ func Start(ctx context.Context, o Options) (*Run, error) {
 
 // record locks the new run and writes its run.json and first ledger line.
 func record(project, dir, id string, setup *Setup) (*Run, error) {
-	unlock, err := Lock(dir)
+	unlock, err := takeLocks(project, dir)
 	if err != nil {
 		return nil, err
 	}
@@ -397,7 +434,9 @@ func (r *Run) createLeaf(ctx context.Context, p string) error {
 
 // Open locks and loads run id for resume, approve or reject, and checks that it may continue: the
 // caps are still complete, the graph and brief are unchanged, the ledger reaches the anchor in
-// run.json. mode switches the run's mode at this pause ("" keeps it); a switch is logged.
+// run.json, and every leaf is at its checkpoint. A run that was interrupted or failed has its
+// leaves reset to their checkpoints, since its node restarts from scratch (spec §4.3). mode
+// switches the run's mode at this pause ("" keeps it); a switch is logged.
 func Open(ctx context.Context, project, id string, mode gungnir.Mode) (*Run, error) {
 	if !ValidID(id) {
 		return nil, fmt.Errorf("%q is not a run id", id)
@@ -410,7 +449,7 @@ func Open(ctx context.Context, project, id string, mode gungnir.Mode) (*Run, err
 	if _, err := os.Stat(filepath.Join(dir, "run.json")); err != nil {
 		return nil, fmt.Errorf("no run %s in %s", id, project)
 	}
-	unlock, err := Lock(dir)
+	unlock, err := takeLocks(project, dir)
 	if err != nil {
 		return nil, err
 	}
@@ -444,6 +483,9 @@ func open(ctx context.Context, project, dir string, mode gungnir.Mode) (*Run, er
 	if setup.Root != s.Root || setup.ProjectPath != s.ProjectPath {
 		return nil, fmt.Errorf("the run belongs to %s in %s, not this project", s.ProjectPath, s.Root)
 	}
+	if err := s.check(setup); err != nil {
+		return nil, fmt.Errorf("%s/run.json: %w", dir, err)
+	}
 	l, err := ledger.Open(filepath.Join(dir, "ledger.jsonl"), s.Ledger)
 	if err != nil {
 		return nil, err
@@ -456,6 +498,10 @@ func open(ctx context.Context, project, dir string, mode gungnir.Mode) (*Run, er
 		s.Exec = nil
 	}
 	r := &Run{Project: setup.Project.Dir, Dir: dir, State: s, Setup: setup, Ledger: l, unlock: func() {}}
+	if err := r.restoreLeaves(ctx); err != nil {
+		l.Close()
+		return nil, err
+	}
 	// The switches apply in memory now, and reach the ledger and run.json with the command's first
 	// write (Log or Save). A refused command writes nothing, so it switches nothing.
 	if setup.ConfigSHA256 != s.ConfigSHA256 {
@@ -469,6 +515,43 @@ func open(ctx context.Context, project, dir string, mode gungnir.Mode) (*Run, er
 	return r, nil
 }
 
+// restoreLeaves puts every leaf back to its checkpoint when the run's node restarts (interrupted,
+// failed, or stopped for a policy violation), and otherwise refuses a leaf that changed while the
+// run waited: Odin never discards work it didn't make.
+func (r *Run) restoreLeaves(ctx context.Context) error {
+	s := r.State
+	if s.Status == StatusDone {
+		return nil
+	}
+	restart := s.Status == StatusRunning || s.Status == StatusFailed || s.PendingGate == gungnir.GatePolicyViolation
+	for _, p := range slices.Sorted(maps.Keys(s.Leaves)) {
+		rec := s.Leaves[p]
+		l, err := r.Leaf(p)
+		if err != nil {
+			return err
+		}
+		if restart {
+			if err := l.Reset(ctx, rec.Branch, rec.Checkpoint); err != nil {
+				return fmt.Errorf("resetting %s to its checkpoint: %w", p, err)
+			}
+			continue
+		}
+		head, err := l.Head(ctx)
+		if err != nil {
+			return err
+		}
+		st, err := l.Git(ctx, "status", "--porcelain")
+		if err != nil {
+			return err
+		}
+		if head != rec.Checkpoint || st != "" {
+			return fmt.Errorf("the leaf %s changed while the run waited: it is at %s, with %d uncommitted changes, and the run's checkpoint is %s; put it back, or start a new run",
+				p, head, strings.Count(st, "\n")+min(len(st), 1), rec.Checkpoint)
+		}
+	}
+	return nil
+}
+
 // stopLeftover stops the process group of an exec node that outlived its ygg process (killed, or
 // its terminal closed), so the node never runs again beside its old copy. It kills the group only
 // when the group's leader is the process run.json recorded. A group it can't tell is the run's is
```

to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 413004b..064fa95 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -15,6 +15,7 @@ import (
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
+	"github.com/ouroboric-dev/odin/internal/leaf"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
 
@@ -150,6 +151,9 @@ func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 		}
 		return &nodeFailure{runErr}
 	}
+	if ev.Commit, err = checkpoint(ctx, r, n, attempt); err != nil {
+		return failCheckpoint(r, ev, err)
+	}
 	ev.Name, ev.Result = gungnir.EventNodeFinished, res.Summary
 	if err := r.Log(ev); err != nil {
 		return err
@@ -215,6 +219,8 @@ func runExec(ctx context.Context, r *run.Run, n schema.Node) error {
 		DurationMS: time.Since(began).Milliseconds()}
 	if runErr != nil {
 		ev.Name = gungnir.EventNodeFailed
+	} else if ev.Commit, err = checkpoint(ctx, r, n, attempt); err != nil {
+		return failCheckpoint(r, ev, err)
 	}
 	if err := r.Log(ev); err != nil {
 		return err
@@ -225,3 +231,37 @@ func runExec(ctx context.Context, r *run.Run, n schema.Node) error {
 	r.State.Summaries[n.ID] = result
 	return nil
 }
+
+// checkpoint commits node n's work in its leaf to the run's branch, and records the commit in
+// run.json: resume resets the leaf to it (spec §4.3). A node that works in an umbrella has no
+// checkpoint; the commit that records an umbrella's change is Odin's own, at a pointer move.
+func checkpoint(ctx context.Context, r *run.Run, n schema.Node, attempt int) (string, error) {
+	rec, ok := r.State.Leaves[n.Repo]
+	if !ok {
+		return "", nil
+	}
+	l, err := r.Leaf(n.Repo)
+	if err != nil {
+		return "", err
+	}
+	head, _, err := l.Checkpoint(ctx, fmt.Sprintf("ygg: run %s, node %s, attempt %d", r.State.ID, n.ID, attempt))
+	if err != nil {
+		return "", err
+	}
+	rec.Checkpoint = head
+	r.State.Leaves[n.Repo] = rec
+	return head, nil
+}
+
+// failCheckpoint logs a node whose work Odin refused to commit, such as a leaf with a planted git
+// repository, and fails it. A failure of Odin itself stays an error.
+func failCheckpoint(r *run.Run, ev gungnir.Event, err error) error {
+	if !leaf.IsPolicy(err) {
+		return err
+	}
+	ev.Name, ev.Result, ev.Commit = gungnir.EventNodeFailed, err.Error(), ""
+	if lerr := r.Log(ev); lerr != nil {
+		return lerr
+	}
+	return &nodeFailure{err}
+}
```

and to `internal/engine/gates.go`:

```diff
diff --git a/internal/engine/gates.go b/internal/engine/gates.go
index 24d70f3..40bf0f9 100644
--- a/internal/engine/gates.go
+++ b/internal/engine/gates.go
@@ -38,7 +38,7 @@ func reachGate(r *run.Run, n schema.Node) (bool, error) {
 	if err := r.Log(ev); err != nil {
 		return false, err
 	}
-	s.Status, s.Pending = run.StatusStopped, n.ID
+	s.Status, s.Pending, s.PendingGate = run.StatusStopped, n.ID, n.Gate
 	return true, r.Save()
 }
 
@@ -102,7 +102,7 @@ func Approve(r *run.Run, gateID, note string) error {
 	if err := r.Log(gungnir.Event{Name: gungnir.EventGateApproved, Node: gateID, Gate: gateID, Note: note}); err != nil {
 		return err
 	}
-	s.Pending, s.Status = "", run.StatusRunning
+	s.Pending, s.PendingGate, s.Status = "", "", run.StatusRunning
 	s.Position++
 	return r.Save()
 }
@@ -123,7 +123,7 @@ func Reject(r *run.Run, gateID, reason string) error {
 		return err
 	}
 	s.Reasons[target] = reason
-	s.Pending, s.Status = "", run.StatusRunning
+	s.Pending, s.PendingGate, s.Status = "", "", run.StatusRunning
 	s.Position = g.Index(target)
 	return r.Save()
 }
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T055: Phase 1 follow-ups in the run

Two of decision 16's items.

**Files (in `odin`):**
- Modify: `internal/run/run.go`, `internal/run/tree_test.go`

**Acceptance criteria:**
- [ ] A run whose config is `unattended` with `design: auto` opens with `--mode step-by-step`.
- [ ] After `factory.yaml` changes a role's model, `run.json` records the new one.

**Named test:** `go test ./internal/run/ -run 'TestAStricterModeSwitchIsAllowed|TestRolesFollowAConfigChange'`.
**Layer:** `odin`. **Size:** S (37). **Depends on:** v0-T054.

- [ ] **Step 1:** apply to `internal/run/tree_test.go`:

```diff
diff --git a/internal/run/tree_test.go b/internal/run/tree_test.go
index 95d1592..ea1b776 100644
--- a/internal/run/tree_test.go
+++ b/internal/run/tree_test.go
@@ -195,6 +195,40 @@ func TestOpenPutsLeavesBackAtTheirCheckpoints(t *testing.T) {
 	}
 }
 
+func TestAStricterModeSwitchIsAllowed(t *testing.T) {
+	r := startToyRun(t, "mode: unattended\ngates: { design: auto }\n"+scriptedRoles+fullCaps)
+	id, project := r.State.ID, r.Project
+	r.Close()
+	r, err := Open(ctx, project, id, gungnir.ModeStepByStep)
+	if err != nil {
+		t.Fatalf("Open() with a stricter mode = %v, want it allowed: design: auto applies only in unattended mode", err)
+	}
+	defer r.Close()
+	if r.State.Mode != gungnir.ModeStepByStep {
+		t.Errorf("mode = %s", r.State.Mode)
+	}
+}
+
+func TestRolesFollowAConfigChange(t *testing.T) {
+	cfgDir := t.TempDir()
+	project := treetest.Project(t)
+	r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, cfgDir, scriptedRoles+fullCaps), Realm: toy(t)})
+	if err != nil {
+		t.Fatal(err)
+	}
+	id := r.State.ID
+	r.Close()
+	writeConfig(t, cfgDir, strings.ReplaceAll(scriptedRoles, "model: none", "model: other")+fullCaps)
+	r, err = Open(ctx, project, id, "")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer r.Close()
+	if got := r.State.Roles["planner"].Model; got != "other" {
+		t.Errorf("run.json records the planner's model as %q after the config changed, want other", got)
+	}
+}
+
 // A project MAY hold sub-projects (change project-is-its-own-tree): a run in one finds the root
 // above it, and works in the sub-project's own leaves.
 func TestARunWorksInASubProject(t *testing.T) {
```

- [ ] **Step 2:** run the named test; expect `TestAStricterModeSwitchIsAllowed` to fail with
      `gates.design: auto is allowed only in unattended mode, not step-by-step`, and
      `TestRolesFollowAConfigChange` with `records the planner's model as "none"`.
- [ ] **Step 3:** apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 7904d20..a919e95 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -73,13 +73,12 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 		return nil, err
 	}
 	s.ConfigSHA256 = sum(cfgData)
+	// ParseFactory checked the gate overrides against the file's own mode. A --mode switch needs no
+	// second check: design: auto, the one loosening, applies only in unattended mode (gate.Decide).
 	s.Mode = s.Config.Mode
 	if o.Mode != "" {
 		s.Mode = o.Mode
 	}
-	if err := s.Config.CheckGates(s.Mode); err != nil {
-		return nil, fmt.Errorf("%s: %w", s.ConfigPath, err)
-	}
 	if s.RealmDir, err = filepath.Abs(o.Realm); err != nil {
 		return nil, err
 	}
@@ -506,6 +505,7 @@ func open(ctx context.Context, project, dir string, mode gungnir.Mode) (*Run, er
 	// write (Log or Save). A refused command writes nothing, so it switches nothing.
 	if setup.ConfigSHA256 != s.ConfigSHA256 {
 		s.ConfigSHA256 = setup.ConfigSHA256
+		s.Roles = roles(setup)
 		r.changes = append(r.changes, gungnir.Event{Name: gungnir.EventConfigChanged, ConfigHash: setup.ConfigSHA256})
 	}
 	if mode != s.Mode {
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T056: merge and pointer nodes

The engine runs the merge gate and pointer moves as nodes (decisions 11 to 13). A pack check runs the
way an exec node's command does. The run's own lock moves to `runs.lock`, so a pointer move into the
project can take `project.lock` while the run holds its own (decision 10).

**Files (in `odin`):**
- Create: `internal/engine/land.go`, `internal/engine/land_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/engine_test.go`, `internal/run/run.go`

**Interfaces:**
- Consumes: `merge.Land` (v0-T049), `pointer.Move` (v0-T050), `schema.KindMerge`,
  `schema.KindPointer` (v0-T041).
- Produces: `run.RunsLock(project) string`; in the engine, merge and pointer nodes; a
  `check_result` ledger line for each pack check, and `pointer_moved` for a move.

**Acceptance criteria:**
- [ ] A merge node lands the run's branch: the leaf's `main` is the run's head, and it is the leaf's
      new checkpoint; the ledger has the check's `check_result` and the node's `node_finished` with
      the commit.
- [ ] A failing check fails the merge node, and `main` doesn't move.
- [ ] A pointer node moves the project's pointer to the leaf's `main`, after the leaf's checks and the
      project's acceptance check, and logs `pointer_moved`.

**Named test:** `go test ./internal/engine/ -run 'TestAMergeNode|TestAPointerNode'`. **Layer:** `odin`.
**Size:** M (284). **Depends on:** v0-T050, v0-T055.

- [ ] **Step 1:** apply to `internal/engine/engine_test.go`:

```diff
diff --git a/internal/engine/engine_test.go b/internal/engine/engine_test.go
index ddc3ac1..ff45eab 100644
--- a/internal/engine/engine_test.go
+++ b/internal/engine/engine_test.go
@@ -16,11 +16,17 @@ import (
 // start makes a realm with the given nodes and a prompt file, a script and a factory.yaml, and
 // starts a run on them in a fresh project, whose nodes work in the leaf repos/app.
 func start(t *testing.T, mode, gates, nodes, script string) *run.Run {
+	t.Helper()
+	return startPack(t, mode, gates, "", nodes, script)
+}
+
+// startPack is start with extra lines for the realm's pack.yaml, such as its checks.
+func startPack(t *testing.T, mode, gates, pack, nodes, script string) *run.Run {
 	t.Helper()
 	realm, cfg := t.TempDir(), t.TempDir()
 	project := treetest.Project(t, "repos/app")
 	files := map[string]string{
-		filepath.Join(realm, "pack.yaml"):  "name: test\nversion: 0.1.0\ngraph: graph.yaml\n",
+		filepath.Join(realm, "pack.yaml"):  "name: test\nversion: 0.1.0\ngraph: graph.yaml\n" + pack,
 		filepath.Join(realm, "graph.yaml"): "name: test\nversion: 1.0.0\nnodes:\n" + nodes,
 		filepath.Join(realm, "p.md"):       "Do the work.\n",
 		filepath.Join(cfg, "script.yaml"):  script,
```

and write `internal/engine/land_test.go`:

```go
package engine

import (
	"context"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
)

var bg = context.Background()

// checks are the pack checks of these tests: unit passes when the agent wrote out.txt, and e2e runs
// in the project umbrella.
const checks = "checks:\n  unit: [test, -f, out.txt]\n  e2e: [test, -f, umbrella.yaml]\n  broken: [\"false\"]\n"

const build = "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n"

func TestAMergeNodeLandsTheBranchThroughTheGate(t *testing.T) {
	r := startPack(t, "key-points", "", checks, build+"  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n", okScript)
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	l, _ := r.Leaf("repos/app")
	main, _ := l.Rev(bg, "main")
	head, _ := l.Head(bg)
	if main != head || r.State.Leaves["repos/app"].Checkpoint != main {
		t.Errorf("main %s, head %s, checkpoint %s; want main landed at the run's head", main, head, r.State.Leaves["repos/app"].Checkpoint)
	}
	text := ledgerText(t, r)
	for _, want := range []string{`"event":"check_result","ygg.attempt":1,"ygg.result":"unit: exit 0"`,
		`"ygg.node.id":"merge","event":"node_finished"`, `"ygg.ref.commit":"` + main + `"`} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s", want)
		}
	}
}

func TestAMergeNodeFailsWhenTheChecksFail(t *testing.T) {
	r := startPack(t, "key-points", "", checks, build+"  - { id: merge, kind: merge, repo: repos/app, checks: [broken] }\n", okScript)
	base := r.State.Leaves["repos/app"].Base
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "check broken") {
		t.Fatalf("Advance() = %+v, %v; want failed on the broken check", out, err)
	}
	l, _ := r.Leaf("repos/app")
	if main, _ := l.Rev(bg, "main"); main != base {
		t.Error("main moved although the merge gate's checks failed")
	}
}

func TestAPointerNodeMovesTheProjectsPointer(t *testing.T) {
	nodes := build + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
		"  - { id: move, kind: pointer, repo: repos/app, checks: [unit], acceptance: [e2e] }\n"
	r := startPack(t, "key-points", "", checks, nodes, okScript)
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	l, _ := r.Leaf("repos/app")
	main, _ := l.Rev(bg, "main")
	if got, _ := git.Run(bg, r.Project, "rev-parse", "HEAD:repos/app"); got != main {
		t.Errorf("the project points at %s, want the leaf's main %s", got, main)
	}
	if !strings.Contains(ledgerText(t, r), `"event":"pointer_moved"`) {
		t.Error("the ledger doesn't record the pointer move")
	}
}
```

- [ ] **Step 2:** run the named test; expect `TestAMergeNodeLandsTheBranchThroughTheGate` to fail:
      the merge node is skipped, so `main` stays at the base, and the ledger lacks its lines.
- [ ] **Step 3:** apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 064fa95..71fc933 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -54,6 +54,10 @@ func Advance(ctx context.Context, r *run.Run) (Outcome, error) {
 			err = runExec(ctx, r, n)
 		case schema.KindGate:
 			stop, err = reachGate(r, n)
+		case schema.KindMerge:
+			err = runMerge(ctx, r, n)
+		case schema.KindPointer:
+			err = runPointer(ctx, r, n)
 		}
 		var nf *nodeFailure
 		if errors.As(err, &nf) {
@@ -163,10 +167,7 @@ func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 	return nil
 }
 
-// runExec runs n's command in its repo, without a shell. The command gets only PATH, HOME (the
-// run's own directory, so caches never land in a repo) and LANG, so no credential in the operator's environment reaches it. A cancel
-// or timeout kills the command's whole process group (spec §6.2). Phase 3 moves leaf commands
-// into the sandbox.
+// runExec runs n's command in its repo (see command), and checkpoints the leaf it works in.
 func runExec(ctx context.Context, r *run.Run, n schema.Node) error {
 	attempt, err := startAttempt(r, n)
 	if err != nil {
@@ -176,41 +177,11 @@ func runExec(ctx context.Context, r *run.Run, n schema.Node) error {
 		return err
 	}
 	logPath := filepath.Join(r.Dir, "logs", fmt.Sprintf("%s-%d.log", n.ID, attempt))
-	if err := os.MkdirAll(filepath.Dir(logPath), 0o755); err != nil {
-		return err
-	}
-	out, err := os.Create(logPath)
+	began := time.Now()
+	runErr, err := command(ctx, r, n.ID, n.Run, r.RepoDir(n.Repo), time.Duration(n.Timeout), logPath)
 	if err != nil {
 		return err
 	}
-	defer out.Close()
-	timeout := time.Duration(n.Timeout)
-	if timeout == 0 {
-		timeout = ExecTimeout
-	}
-	cctx, cancel := context.WithTimeout(ctx, timeout)
-	defer cancel()
-	cmd := exec.CommandContext(cctx, n.Run[0], n.Run[1:]...)
-	cmd.Dir = r.RepoDir(n.Repo)
-	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + r.Home(), "LANG=C.UTF-8"}
-	cmd.Stdout, cmd.Stderr = out, out
-	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
-	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
-	cmd.WaitDelay = 5 * time.Second
-	began := time.Now()
-	runErr := cmd.Start()
-	if runErr == nil {
-		// Record the group before waiting, so if this ygg dies the next one can stop it (run.Open).
-		pid := cmd.Process.Pid
-		r.State.Exec = &run.ExecProcess{Node: n.ID, PGID: pid, Start: run.ProcStart(pid)}
-		if err := r.Save(); err != nil {
-			syscall.Kill(-pid, syscall.SIGKILL)
-			cmd.Wait()
-			return err
-		}
-		runErr = cmd.Wait()
-		r.State.Exec = nil
-	}
 	result := "exit 0"
 	if runErr != nil {
 		result = runErr.Error()
@@ -232,6 +203,71 @@ func runExec(ctx context.Context, r *run.Run, n schema.Node) error {
 	return nil
 }
 
+// command runs args in dir, without a shell, for node. The command gets only PATH, HOME (the run's
+// own directory, so caches never land in a repo) and LANG, so no credential in the operator's
+// environment reaches it. Its output goes to logPath. A cancel or timeout (ExecTimeout when 0)
+// kills its whole process group (spec §6.2), and run.json records the group while it runs, so a
+// later ygg can stop it if this one dies. cmdErr is the command's failure; err is Odin's. Phase 3
+// moves leaf commands into the sandbox.
+func command(ctx context.Context, r *run.Run, node string, args []string, dir string, timeout time.Duration, logPath string) (cmdErr, err error) {
+	if err := os.MkdirAll(filepath.Dir(logPath), 0o755); err != nil {
+		return nil, err
+	}
+	out, err := os.Create(logPath)
+	if err != nil {
+		return nil, err
+	}
+	defer out.Close()
+	if timeout == 0 {
+		timeout = ExecTimeout
+	}
+	cctx, cancel := context.WithTimeout(ctx, timeout)
+	defer cancel()
+	cmd := exec.CommandContext(cctx, args[0], args[1:]...)
+	cmd.Dir = dir
+	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + r.Home(), "LANG=C.UTF-8"}
+	cmd.Stdout, cmd.Stderr = out, out
+	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
+	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
+	cmd.WaitDelay = 5 * time.Second
+	if err := cmd.Start(); err != nil {
+		return err, nil
+	}
+	pid := cmd.Process.Pid
+	r.State.Exec = &run.ExecProcess{Node: node, PGID: pid, Start: run.ProcStart(pid)}
+	if err := r.Save(); err != nil {
+		syscall.Kill(-pid, syscall.SIGKILL)
+		cmd.Wait()
+		return nil, err
+	}
+	cmdErr = cmd.Wait()
+	r.State.Exec = nil
+	return cmdErr, nil
+}
+
+// runChecks runs the pack checks names in dir, in order, for the given attempt of node n, and logs
+// each result. The first failing check is the error.
+func runChecks(ctx context.Context, r *run.Run, n schema.Node, attempt int, names []string, dir string) error {
+	for _, c := range names {
+		logPath := filepath.Join(r.Dir, "logs", fmt.Sprintf("%s-%d-%s.log", n.ID, attempt, c))
+		cmdErr, err := command(ctx, r, n.ID, r.Setup.Pack.Checks[c], dir, time.Duration(n.Timeout), logPath)
+		if err != nil {
+			return err
+		}
+		result := c + ": exit 0"
+		if cmdErr != nil {
+			result = c + ": " + cmdErr.Error()
+		}
+		if err := r.Log(gungnir.Event{Name: gungnir.EventCheckResult, Node: n.ID, Attempt: attempt, Result: result}); err != nil {
+			return err
+		}
+		if cmdErr != nil {
+			return fmt.Errorf("check %s failed: %v (output: %s)", c, cmdErr, logPath)
+		}
+	}
+	return nil
+}
+
 // checkpoint commits node n's work in its leaf to the run's branch, and records the commit in
 // run.json: resume resets the leaf to it (spec §4.3). A node that works in an umbrella has no
 // checkpoint; the commit that records an umbrella's change is Odin's own, at a pointer move.
```

write `internal/engine/land.go`:

```go
package engine

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/lock"
	"github.com/ouroboric-dev/odin/internal/merge"
	"github.com/ouroboric-dev/odin/internal/pointer"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/shrink"
	"github.com/ouroboric-dev/odin/internal/tree"
)

// runMerge lands the run's branch of n's leaf on the leaf's main through the merge gate (spec
// §4.5). The gate's checks are n's pack checks, run in the leaf on the branch with main merged in.
// The merged commit becomes the leaf's checkpoint. A refusal fails the node: the work goes back to
// the loop (Phase 4), and a resume starts the gate again from the last checkpoint.
func runMerge(ctx context.Context, r *run.Run, n schema.Node) error {
	attempt, err := startAttempt(r, n)
	if err != nil {
		return err
	}
	if err := r.Log(gungnir.Event{Name: gungnir.EventNodeStarted, Node: n.ID, Attempt: attempt}); err != nil {
		return err
	}
	l, err := r.Leaf(n.Repo)
	if err != nil {
		return err
	}
	rec := r.State.Leaves[n.Repo]
	began := time.Now()
	res, landErr := merge.Land(ctx, merge.Spec{Leaf: l, Branch: rec.Branch, Base: "main", Lock: r.LockFile(n.Repo),
		Check: func(ctx context.Context) error { return runChecks(ctx, r, n, attempt, n.Checks, l.Dir()) }})
	ev := gungnir.Event{Name: gungnir.EventNodeFinished, Node: n.ID, Attempt: attempt,
		DurationMS: time.Since(began).Milliseconds()}
	if landErr != nil {
		return failLanding(r, ev, landErr)
	}
	rec.Checkpoint = res.Merged
	r.State.Leaves[n.Repo] = rec
	ev.Result, ev.Commit = "merged into main", res.Merged
	if err := r.Log(ev); err != nil {
		return err
	}
	r.State.Summaries[n.ID] = fmt.Sprintf("merged %s into main at %s", rec.Branch, res.Merged)
	return nil
}

// runPointer moves n's leaf pointer in the leaf's parent umbrella to the leaf's main, one level
// (spec §3.4), under the parent's lock: n's pack checks run in the leaf at that commit, its
// acceptance checks in the parent, and the shrink guard reads the parent's generated files. A
// shrunk file or failed checks fail the node.
func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
	attempt, err := startAttempt(r, n)
	if err != nil {
		return err
	}
	if err := r.Log(gungnir.Event{Name: gungnir.EventNodeStarted, Node: n.ID, Attempt: attempt}); err != nil {
		return err
	}
	nodes, err := tree.Resolve(ctx, r.Setup.Root, filepath.Join(r.Setup.ProjectPath, n.Repo))
	if err != nil {
		return err
	}
	parent, leafNode := nodes[len(nodes)-2], nodes[len(nodes)-1]
	child, err := filepath.Rel(parent.Dir, leafNode.Dir)
	if err != nil {
		return err
	}
	parentRepo, err := filepath.Rel(r.Project, parent.Dir)
	if err != nil {
		return err
	}
	l, err := r.Leaf(n.Repo)
	if err != nil {
		return err
	}
	to, err := l.Rev(ctx, "main")
	if err != nil {
		return err
	}
	s := r.State
	began := time.Now()
	res, moveErr := pointer.Move(ctx, pointer.Spec{Parent: parent, Child: child, Leaf: l, To: to,
		Lock:       r.LockFile(parentRepo),
		Check:      func(ctx context.Context) error { return runChecks(ctx, r, n, attempt, n.Checks, l.Dir()) },
		Acceptance: func(ctx context.Context) error { return runChecks(ctx, r, n, attempt, n.Acceptance, parent.Dir) },
		Generated:  n.Generated,
		Message:    fmt.Sprintf("Move %s to %.12s (run %s, node %s)", child, to, s.ID, n.ID)})
	ev := gungnir.Event{Name: gungnir.EventNodeFinished, Node: n.ID, Attempt: attempt,
		DurationMS: time.Since(began).Milliseconds()}
	if moveErr != nil {
		return failLanding(r, ev, moveErr)
	}
	if res.Commit != "" {
		moved := gungnir.Event{Name: gungnir.EventPointerMoved, Node: n.ID, Attempt: attempt, Commit: res.Commit,
			Note: fmt.Sprintf("%s: %.12s -> %.12s", filepath.Join(parentRepo, child), res.From, res.To)}
		if err := r.Log(moved); err != nil {
			return err
		}
	}
	ev.Result, ev.Commit = "moved "+child, res.Commit
	if err := r.Log(ev); err != nil {
		return err
	}
	s.Summaries[n.ID] = fmt.Sprintf("moved %s to %s", child, to)
	return nil
}

// failLanding fails a merge or pointer node that the gate or the shrink guard refused, or whose
// target another process holds. Anything else is a failure of Odin itself.
func failLanding(r *run.Run, ev gungnir.Event, err error) error {
	var mr *merge.Refused
	var pr *pointer.Refused
	var se *shrink.Error
	if !errors.As(err, &mr) && !errors.As(err, &pr) && !errors.As(err, &se) && !errors.Is(err, lock.ErrHeld) {
		return err
	}
	ev.Name, ev.Result = gungnir.EventNodeFailed, err.Error()
	if lerr := r.Log(ev); lerr != nil {
		return lerr
	}
	return &nodeFailure{err}
}
```

and apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index a919e95..016a000 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -228,7 +228,8 @@ func (r *Run) Home() string { return filepath.Join(r.Dir, "home") }
 // LockFile returns the lock file of a repo of the project, in <project>/.factory/locks/.
 func (r *Run) LockFile(repo string) string { return LockFile(r.Project, repo) }
 
-// LockFile returns the lock file of a repo of project.
+// LockFile returns the lock file of a repo of project: the merge gate's for a leaf, the pointer
+// move's for an umbrella ("." is the project umbrella).
 func LockFile(project, repo string) string {
 	name := "project"
 	if repo != "." {
@@ -237,6 +238,10 @@ func LockFile(project, repo string) string {
 	return filepath.Join(project, ".factory", "locks", filepath.FromSlash(name)+".lock")
 }
 
+// RunsLock returns the lock that one advancing run of project holds. It is not the project
+// umbrella's own lock, which a pointer move into the umbrella takes while the run holds this one.
+func RunsLock(project string) string { return filepath.Join(project, ".factory", "locks", "runs.lock") }
+
 // ErrProjectBusy means another ygg process is advancing a run of the same project. One run at a
 // time walks a project's leaves, which share their working copies.
 var ErrProjectBusy = errors.New("another ygg process is advancing a run of this project")
@@ -288,7 +293,7 @@ func takeLocks(project, dir string) (func(), error) {
 	if err != nil {
 		return nil, err
 	}
-	releaseProject, err := lock.Take(LockFile(project, "."))
+	releaseProject, err := lock.Take(RunsLock(project))
 	if err != nil {
 		releaseRun()
 		if errors.Is(err, lock.ErrHeld) {
```

- [ ] **Step 4:** run the named test; expect `ok`, then `go test ./...`. Commit.

---

### Task v0-T057: hard stops

A node itself stops the run at a hard approval point: `policy-violation` for planted git (decision 9),
`shrink-guard` for a shrunk generated file (decision 13). The quarantine of spec §12.

**Files (in `odin`):**
- Modify: `internal/engine/engine.go`, `internal/engine/gates.go`, `internal/engine/land.go`,
  `internal/engine/engine_test.go`, `internal/engine/gates_test.go`, `internal/engine/land_test.go`,
  `internal/run/run.go`, `internal/run/state.go`, `internal/cli/cli.go`

**Interfaces:**
- Produces: `engine.Approve(ctx, r, gateID, note)` and `engine.Reject(ctx, r, gateID, reason)` (a
  context added); `run.State.Waived map[string]bool`.

**Acceptance criteria:**
- [ ] A planted repository stops the run at `policy-violation`, in unattended mode too, and nothing is
      committed; opening the run leaves the leaf as it is; approving puts the leaf back to its
      checkpoint, and the node runs again.
- [ ] A shrunk generated file stops a pointer move at `shrink-guard`, in unattended mode too, with a
      gate file that gives the rows; `reject` is refused; `approve` lands the move with the shrunk
      file.
- [ ] Phase 1's gate nodes work as before.

**Named test:** `go test ./internal/engine/ ./internal/run/`. **Layer:** `odin`. **Size:** M (180).
**Depends on:** v0-T056.

- [ ] **Step 1:** apply to `internal/engine/land_test.go`:

```diff
diff --git a/internal/engine/land_test.go b/internal/engine/land_test.go
index 7370d5f..15bdc2b 100644
--- a/internal/engine/land_test.go
+++ b/internal/engine/land_test.go
@@ -2,9 +2,12 @@ package engine
 
 import (
 	"context"
+	"os"
+	"path/filepath"
 	"strings"
 	"testing"
 
+	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/odin/internal/git"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
@@ -66,3 +69,74 @@ func TestAPointerNodeMovesTheProjectsPointer(t *testing.T) {
 		t.Error("the ledger doesn't record the pointer move")
 	}
 }
+
+func TestAShrunkGeneratedFileStopsAtTheShrinkGuard(t *testing.T) {
+	nodes := build + "  - { id: index, kind: exec, run: [sh, -c, \"echo '| one |' > REPOS.md\"], repo: . }\n" +
+		"  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
+		"  - { id: move, kind: pointer, repo: repos/app, generated: [REPOS.md] }\n"
+	r := startPack(t, "unattended", "", checks, nodes, okScript)
+	if err := os.WriteFile(filepath.Join(r.Project, "REPOS.md"), []byte(strings.Repeat("| row |\n", 10)), 0o644); err != nil {
+		t.Fatal(err)
+	}
+	for _, args := range [][]string{{"add", "REPOS.md"}, {"commit", "-q", "-m", "REPOS.md"}} {
+		if _, err := git.Run(bg, r.Project, args...); err != nil {
+			t.Fatal(err)
+		}
+	}
+	out, err := Advance(bg, r)
+	if err != nil || out.Status != run.StatusStopped || out.Gate != "move" || r.State.PendingGate != gungnir.GateShrinkGuard {
+		t.Fatalf("Advance() = %+v, %v (pending %s); want a stop at shrink-guard, even in unattended mode", out, err, r.State.PendingGate)
+	}
+	if b, err := os.ReadFile(filepath.Join(r.Dir, "gates", "move-1.md")); err != nil || !strings.Contains(string(b), "keeps 1 of its 10 rows") {
+		t.Errorf("gate file = %q, %v", b, err)
+	}
+	if err := Reject(bg, r, "move", "no"); err == nil {
+		t.Error("Reject() of a hard stop succeeded; a hard stop takes approve, or a new run")
+	}
+	if err := Approve(bg, r, "move", "the index shrank on purpose"); err != nil {
+		t.Fatal(err)
+	}
+	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() after approval = %+v, %v", out, err)
+	}
+	if files, _ := git.Run(bg, r.Project, "show", "--name-only", "--format=", "HEAD"); files != "REPOS.md\nrepos/app" {
+		t.Errorf("the approved move commits %q, want the shrunk REPOS.md with the pointer", files)
+	}
+}
+
+func TestAPlantedRepositoryStopsAtPolicyViolation(t *testing.T) {
+	script := "steps:\n  a:\n    - actions:\n        - write: { path: vendor/x/.git/HEAD, content: \"ref: refs/heads/main\\n\" }\n" +
+		"        - write: { path: vendor/x/.git/objects/.keep, content: \"\" }\n        - write: { path: vendor/x/.git/refs/heads/.keep, content: \"\" }\n" +
+		"      result: { status: ok, summary: planted a repo }\n" +
+		"    - actions: [ { write: { path: out.txt, content: \"done\\n\" } } ]\n      result: { status: ok, summary: clean }\n"
+	r := startPack(t, "unattended", "", "", build, script)
+	base := r.State.Leaves["repos/app"].Checkpoint
+	out, err := Advance(bg, r)
+	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GatePolicyViolation {
+		t.Fatalf("Advance() = %+v, %v; want a stop at policy-violation, even in unattended mode", out, err)
+	}
+	l, _ := r.Leaf("repos/app")
+	if head, _ := l.Head(bg); head != base {
+		t.Error("Odin committed the planted repository")
+	}
+	planted := filepath.Join(r.RepoDir("repos/app"), "vendor", "x", ".git", "HEAD")
+	id, project := r.State.ID, r.Project
+	r.Close()
+	reopened, err := run.Open(bg, project, id, "")
+	if err != nil {
+		t.Fatalf("Open() of a quarantined run = %v", err)
+	}
+	if _, err := os.Stat(planted); err != nil {
+		t.Error("Open() cleaned the quarantined leaf before anyone decided; the evidence is gone")
+	}
+	if err := Approve(bg, reopened, "a", "investigated"); err != nil {
+		t.Fatal(err)
+	}
+	if _, err := os.Stat(planted); err == nil {
+		t.Error("approving the stop didn't put the leaf back to its checkpoint")
+	}
+	if out, err := Advance(bg, reopened); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() after approval = %+v, %v; want the node re-run from its checkpoint", out, err)
+	}
+	reopened.Close()
+}
```

to `internal/engine/engine_test.go` (its planted-repository test moves to `land_test.go`, as a stop):

```diff
diff --git a/internal/engine/engine_test.go b/internal/engine/engine_test.go
index ff45eab..43963ea 100644
--- a/internal/engine/engine_test.go
+++ b/internal/engine/engine_test.go
@@ -223,19 +223,3 @@ func TestEveryNodeInALeafEndsWithACheckpoint(t *testing.T) {
 		t.Error("node a's node_finished line doesn't carry its checkpoint commit")
 	}
 }
-
-func TestAPlantedRepositoryFailsTheNodeAndNothingIsCommitted(t *testing.T) {
-	script := "steps:\n  a:\n    - actions:\n        - write: { path: vendor/x/.git/HEAD, content: \"ref: refs/heads/main\\n\" }\n" +
-		"        - write: { path: vendor/x/.git/objects/.keep, content: \"\" }\n        - write: { path: vendor/x/.git/refs/heads/.keep, content: \"\" }\n" +
-		"      result: { status: ok, summary: planted a repo }\n"
-	r := start(t, "key-points", "", "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n", script)
-	base := r.State.Leaves["repos/app"].Checkpoint
-	out, err := Advance(context.Background(), r)
-	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "policy violation") {
-		t.Fatalf("Advance() = %+v, %v; want the node failed for a policy violation", out, err)
-	}
-	l, _ := r.Leaf("repos/app")
-	if head, _ := l.Head(context.Background()); head != base {
-		t.Error("Odin committed the planted repository")
-	}
-}
```

and to `internal/engine/gates_test.go`:

```diff
diff --git a/internal/engine/gates_test.go b/internal/engine/gates_test.go
index 80567ac..460be22 100644
--- a/internal/engine/gates_test.go
+++ b/internal/engine/gates_test.go
@@ -66,10 +66,10 @@ func TestAnAutoPassStillWritesTheGateFile(t *testing.T) {
 func TestApproveMovesPastTheGate(t *testing.T) {
 	r := start(t, "step-by-step", "", gateNodes, gateScript)
 	Advance(context.Background(), r)
-	if err := Approve(r, "design-gate", ""); err == nil {
+	if err := Approve(context.Background(), r, "design-gate", ""); err == nil {
 		t.Error("Approve() of a gate that isn't waiting succeeded")
 	}
-	if err := Approve(r, "spec-gate", "looks right"); err != nil {
+	if err := Approve(context.Background(), r, "spec-gate", "looks right"); err != nil {
 		t.Fatal(err)
 	}
 	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
@@ -83,10 +83,10 @@ func TestApproveMovesPastTheGate(t *testing.T) {
 func TestRejectRerunsTheNodeWithTheReason(t *testing.T) {
 	r := start(t, "step-by-step", "", gateNodes, gateScript)
 	Advance(context.Background(), r)
-	if err := Reject(r, "spec-gate", " "); err == nil {
+	if err := Reject(context.Background(), r, "spec-gate", " "); err == nil {
 		t.Error("Reject() without a reason succeeded")
 	}
-	if err := Reject(r, "spec-gate", "Name the users."); err != nil {
+	if err := Reject(context.Background(), r, "spec-gate", "Name the users."); err != nil {
 		t.Fatal(err)
 	}
 	out, err := Advance(context.Background(), r)
```

- [ ] **Step 2:** run `go test ./internal/engine/`; expect a build failure:
      `too many arguments in call to Approve`.
- [ ] **Step 3:** apply to `internal/engine/gates.go`:

```diff
diff --git a/internal/engine/gates.go b/internal/engine/gates.go
index 40bf0f9..f4ac299 100644
--- a/internal/engine/gates.go
+++ b/internal/engine/gates.go
@@ -1,6 +1,7 @@
 package engine
 
 import (
+	"context"
 	"errors"
 	"fmt"
 	"os"
@@ -93,31 +94,52 @@ func pending(r *run.Run, gateID string) error {
 	return nil
 }
 
-// Approve records the decision on the pending gate and moves the run past it. Advance continues.
-func Approve(r *run.Run, gateID, note string) error {
+// Approve records the decision on the pending approval point, and Advance continues: past a gate
+// node; or, at a hard stop a node raised, with that node again. At policy-violation the leaf goes
+// back to its checkpoint first; at shrink-guard the move lands once without the guard.
+func Approve(ctx context.Context, r *run.Run, gateID, note string) error {
 	if err := pending(r, gateID); err != nil {
 		return err
 	}
 	s := r.State
+	n := r.Setup.Graph.Nodes[s.Position]
 	if err := r.Log(gungnir.Event{Name: gungnir.EventGateApproved, Node: gateID, Gate: gateID, Note: note}); err != nil {
 		return err
 	}
+	switch {
+	case n.Kind == schema.KindGate:
+		s.Position++
+	case s.PendingGate == gungnir.GatePolicyViolation:
+		rec := s.Leaves[n.Repo]
+		l, err := r.Leaf(n.Repo)
+		if err != nil {
+			return err
+		}
+		if err := l.Reset(ctx, rec.Branch, rec.Checkpoint); err != nil {
+			return err
+		}
+	case s.PendingGate == gungnir.GateShrinkGuard:
+		s.Waived[n.ID] = true
+	}
 	s.Pending, s.PendingGate, s.Status = "", "", run.StatusRunning
-	s.Position++
 	return r.Save()
 }
 
 // Reject sends reason back into the node the gate re-runs (spec §7.2). Advance re-runs it with
-// the reason in its prompt, then reaches the gate again.
-func Reject(r *run.Run, gateID, reason string) error {
+// the reason in its prompt, then reaches the gate again. A hard stop a node raised takes no
+// rejection: approve it, or start a new run to drop the work.
+func Reject(ctx context.Context, r *run.Run, gateID, reason string) error {
 	if err := pending(r, gateID); err != nil {
 		return err
 	}
+	s := r.State
+	g := r.Setup.Graph
+	if n := g.Nodes[s.Position]; n.Kind != schema.KindGate {
+		return fmt.Errorf("%s stopped at the hard approval point %s, which takes approve; to drop the work, start a new run", gateID, s.PendingGate)
+	}
 	if strings.TrimSpace(reason) == "" {
 		return errors.New("a rejection needs a reason; it goes back to the node as input")
 	}
-	s := r.State
-	g := r.Setup.Graph
 	target := g.Nodes[g.Index(gateID)].Reruns
 	if err := r.Log(gungnir.Event{Name: gungnir.EventGateRejected, Node: gateID, Gate: gateID, Note: reason}); err != nil {
 		return err
@@ -127,3 +149,45 @@ func Reject(r *run.Run, gateID, reason string) error {
 	s.Position = g.Index(target)
 	return r.Save()
 }
+
+// hardStop is a node that stops the run at a hard approval point itself: work it left breaks a
+// sandbox rule (policy-violation), or a generated file shrank (shrink-guard). Hard approval points
+// stop in every mode.
+type hardStop struct {
+	gate gungnir.Gate
+	err  error
+}
+
+func (h *hardStop) Error() string { return h.err.Error() }
+
+// stopHard stops the run at node n for the hard approval point h, as a gate node stops: a gate file,
+// gate_pending, and the run saved as stopped.
+func stopHard(r *run.Run, n schema.Node, h *hardStop) (Outcome, error) {
+	s := r.State
+	attempt := s.Attempts[n.ID]
+	rel := filepath.Join("gates", fmt.Sprintf("%s-%d.md", n.ID, attempt))
+	var b strings.Builder
+	fmt.Fprintf(&b, "# Hard stop at node %s (%s)\n\n", n.ID, h.gate)
+	fmt.Fprintf(&b, "- Run: %s\n- Mode: %s\n- Time: %s\n\n## Why\n\n%v\n\n", s.ID, s.Mode,
+		time.Now().UTC().Format(time.RFC3339), h.err)
+	fmt.Fprintf(&b, "## Decide\n\n    ygg approve %s %s [--note \"...\"]\n\n", s.ID, n.ID)
+	if h.gate == gungnir.GatePolicyViolation {
+		fmt.Fprintf(&b, "Until then the leaf %s stays as the node left it, for investigation. Approving puts it back to its last checkpoint and runs %s again.\n", n.Repo, n.ID)
+	} else {
+		b.WriteString("Approving lands this move with the generated files as they are.\n")
+	}
+	b.WriteString("A hard stop takes no rejection: to drop the work, start a new run.\n")
+	if err := os.MkdirAll(filepath.Join(r.Dir, "gates"), 0o755); err != nil {
+		return Outcome{}, err
+	}
+	if err := os.WriteFile(filepath.Join(r.Dir, rel), []byte(b.String()), 0o644); err != nil {
+		return Outcome{}, err
+	}
+	ev := gungnir.Event{Name: gungnir.EventGatePending, Node: n.ID, Attempt: attempt, Gate: n.ID, GateFile: rel,
+		Note: fmt.Sprintf("%s: %v", h.gate, h.err)}
+	if err := r.Log(ev); err != nil {
+		return Outcome{}, err
+	}
+	s.Status, s.Pending, s.PendingGate = run.StatusStopped, n.ID, h.gate
+	return Outcome{Status: run.StatusStopped, Gate: n.ID}, r.Save()
+}
```

to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 71fc933..59816b9 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -63,6 +63,10 @@ func Advance(ctx context.Context, r *run.Run) (Outcome, error) {
 		if errors.As(err, &nf) {
 			return fail(r, n, nf.err)
 		}
+		var hs *hardStop
+		if errors.As(err, &hs) {
+			return stopHard(r, n, hs)
+		}
 		if err != nil {
 			return Outcome{}, err
 		}
@@ -290,7 +294,8 @@ func checkpoint(ctx context.Context, r *run.Run, n schema.Node, attempt int) (st
 }
 
 // failCheckpoint logs a node whose work Odin refused to commit, such as a leaf with a planted git
-// repository, and fails it. A failure of Odin itself stays an error.
+// repository, and stops the run at the hard approval point policy-violation. A failure of Odin
+// itself stays an error.
 func failCheckpoint(r *run.Run, ev gungnir.Event, err error) error {
 	if !leaf.IsPolicy(err) {
 		return err
@@ -299,5 +304,5 @@ func failCheckpoint(r *run.Run, ev gungnir.Event, err error) error {
 	if lerr := r.Log(ev); lerr != nil {
 		return lerr
 	}
-	return &nodeFailure{err}
+	return &hardStop{gate: gungnir.GatePolicyViolation, err: err}
 }
```

to `internal/engine/land.go`:

```diff
diff --git a/internal/engine/land.go b/internal/engine/land.go
index a272409..0661ea7 100644
--- a/internal/engine/land.go
+++ b/internal/engine/land.go
@@ -55,7 +55,7 @@ func runMerge(ctx context.Context, r *run.Run, n schema.Node) error {
 // runPointer moves n's leaf pointer in the leaf's parent umbrella to the leaf's main, one level
 // (spec §3.4), under the parent's lock: n's pack checks run in the leaf at that commit, its
 // acceptance checks in the parent, and the shrink guard reads the parent's generated files. A
-// shrunk file or failed checks fail the node.
+// shrunk file stops the run at the hard approval point shrink-guard; failed checks fail the node.
 func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 	attempt, err := startAttempt(r, n)
 	if err != nil {
@@ -91,13 +91,18 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 		Lock:       r.LockFile(parentRepo),
 		Check:      func(ctx context.Context) error { return runChecks(ctx, r, n, attempt, n.Checks, l.Dir()) },
 		Acceptance: func(ctx context.Context) error { return runChecks(ctx, r, n, attempt, n.Acceptance, parent.Dir) },
-		Generated:  n.Generated,
-		Message:    fmt.Sprintf("Move %s to %.12s (run %s, node %s)", child, to, s.ID, n.ID)})
+		Generated:  n.Generated, SkipShrink: s.Waived[n.ID],
+		Message: fmt.Sprintf("Move %s to %.12s (run %s, node %s)", child, to, s.ID, n.ID)})
+	var se *shrink.Error
+	if errors.As(moveErr, &se) {
+		return &hardStop{gate: gungnir.GateShrinkGuard, err: moveErr}
+	}
 	ev := gungnir.Event{Name: gungnir.EventNodeFinished, Node: n.ID, Attempt: attempt,
 		DurationMS: time.Since(began).Milliseconds()}
 	if moveErr != nil {
 		return failLanding(r, ev, moveErr)
 	}
+	delete(s.Waived, n.ID)
 	if res.Commit != "" {
 		moved := gungnir.Event{Name: gungnir.EventPointerMoved, Node: n.ID, Attempt: attempt, Commit: res.Commit,
 			Note: fmt.Sprintf("%s: %.12s -> %.12s", filepath.Join(parentRepo, child), res.From, res.To)}
@@ -113,13 +118,12 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 	return nil
 }
 
-// failLanding fails a merge or pointer node that the gate or the shrink guard refused, or whose
-// target another process holds. Anything else is a failure of Odin itself.
+// failLanding fails a merge or pointer node that the gate refused, or whose target another process
+// holds. Anything else is a failure of Odin itself.
 func failLanding(r *run.Run, ev gungnir.Event, err error) error {
 	var mr *merge.Refused
 	var pr *pointer.Refused
-	var se *shrink.Error
-	if !errors.As(err, &mr) && !errors.As(err, &pr) && !errors.As(err, &se) && !errors.Is(err, lock.ErrHeld) {
+	if !errors.As(err, &mr) && !errors.As(err, &pr) && !errors.Is(err, lock.ErrHeld) {
 		return err
 	}
 	ev.Name, ev.Result = gungnir.EventNodeFailed, err.Error()
```

to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index cd369fb..20cf6d6 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -67,6 +67,7 @@ type State struct {
 	PendingGate  gungnir.Gate          `json:"pending_gate,omitempty"` // the approval point it waits at
 	Reasons      map[string]string     `json:"reasons,omitempty"`      // node id: rejection reason for its next attempt
 	Summaries    map[string]string     `json:"summaries,omitempty"`    // node id: its last result
+	Waived       map[string]bool       `json:"waived,omitempty"`       // pointer node id: shrink-guard approved for its next move
 	Usage        gungnir.Usage         `json:"usage"`
 	Ledger       ledger.Anchor         `json:"ledger"`
 	Error        string                `json:"error,omitempty"`
@@ -162,6 +163,9 @@ func LoadState(dir string) (*State, error) {
 	if s.Summaries == nil {
 		s.Summaries = map[string]string{}
 	}
+	if s.Waived == nil {
+		s.Waived = map[string]bool{}
+	}
 	if s.Leaves == nil {
 		s.Leaves = map[string]LeafRecord{}
 	}
```

to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 016a000..724a52d 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -365,7 +365,7 @@ func record(project, dir, id string, setup *Setup) (*Run, error) {
 		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles(setup),
 		Root: setup.Root, ProjectPath: setup.ProjectPath, Leaves: map[string]LeafRecord{},
 		Attempts: map[string]int{}, Reasons: map[string]string{}, Summaries: map[string]string{},
-		Created: now, Updated: now,
+		Waived: map[string]bool{}, Created: now, Updated: now,
 	}}
 	if err := r.Log(gungnir.Event{Name: gungnir.EventRunStarted, Mode: setup.Mode, ConfigHash: setup.ConfigSHA256}); err != nil {
 		r.Close()
@@ -520,15 +520,16 @@ func open(ctx context.Context, project, dir string, mode gungnir.Mode) (*Run, er
 	return r, nil
 }
 
-// restoreLeaves puts every leaf back to its checkpoint when the run's node restarts (interrupted,
-// failed, or stopped for a policy violation), and otherwise refuses a leaf that changed while the
-// run waited: Odin never discards work it didn't make.
+// restoreLeaves puts every leaf back to its checkpoint when the run's node restarts (interrupted
+// or failed), and otherwise refuses a leaf that changed while the run waited: Odin never discards
+// work it didn't make. A run stopped at policy-violation is quarantined: its leaves stay as they
+// are for investigation, and only approving the stop resets them (spec §12).
 func (r *Run) restoreLeaves(ctx context.Context) error {
 	s := r.State
-	if s.Status == StatusDone {
+	if s.Status == StatusDone || s.PendingGate == gungnir.GatePolicyViolation {
 		return nil
 	}
-	restart := s.Status == StatusRunning || s.Status == StatusFailed || s.PendingGate == gungnir.GatePolicyViolation
+	restart := s.Status == StatusRunning || s.Status == StatusFailed
 	for _, p := range slices.Sorted(maps.Keys(s.Leaves)) {
 		rec := s.Leaves[p]
 		l, err := r.Leaf(p)
```

and to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 43467e7..391c287 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -184,9 +184,9 @@ func (c *command) decide(name string, args []string) int {
 	defer r.Close()
 	var err error
 	if name == "approve" {
-		err = engine.Approve(r, pos[1], f.note)
+		err = engine.Approve(c.ctx, r, pos[1], f.note)
 	} else {
-		err = engine.Reject(r, pos[1], f.reason)
+		err = engine.Reject(c.ctx, r, pos[1], f.reason)
 	}
 	if err != nil {
 		return c.refuse(err)
```

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T058: the command line

`ygg doctor` checks the instance tree (decision 2), and with `--root` a tree without a project;
`approve` takes only `--note` and `reject` only `--reason`; `status` shows the approval point and the
leaves.

**Files (in `odin`):**
- Modify: `internal/cli/cli.go`, `internal/cli/doctor.go`, `internal/cli/cli_test.go`,
  `internal/cli/doctor_test.go`, `README.md`

**Acceptance criteria:**
- [ ] In a project, `doctor` prints `OK tree: <root>: <n> nodes, <m> checked out`; outside a tree,
      `ERROR tree:` and exit 1.
- [ ] `doctor --root <dir>` checks the tree only, with no config, and warns
      (`WARN tree:`, exit 0) when a public umbrella lists a private child.
- [ ] `approve --reason` and `reject --note` exit 2 and decide nothing.
- [ ] `status` prints `waiting:  <gate> (<approval point>)` and a `leaf:` line per leaf, with its
      branch and checkpoint.
- [ ] The README's Usage gives `--root` and how a run lives in the tree.

**Named test:** `go test ./internal/cli/ -run 'TestDoctor|TestRunStopsAndApproveContinues'`.
**Layer:** `odin`. **Size:** M (119). **Depends on:** v0-T057.

- [ ] **Step 1:** apply to `internal/cli/doctor_test.go`:

```diff
diff --git a/internal/cli/doctor_test.go b/internal/cli/doctor_test.go
index 4f5e762..e0b8c7d 100644
--- a/internal/cli/doctor_test.go
+++ b/internal/cli/doctor_test.go
@@ -6,6 +6,9 @@ import (
 	"path/filepath"
 	"strings"
 	"testing"
+
+	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/odin/internal/tree/treetest"
 )
 
 func TestDoctorReportsMissingCaps(t *testing.T) {
@@ -31,3 +34,27 @@ func TestDoctorFindsAChangedLedger(t *testing.T) {
 		t.Errorf("doctor on a changed ledger: exit %d:\n%s", code, out)
 	}
 }
+
+func TestDoctorChecksTheInstanceTree(t *testing.T) {
+	dir, config := project(t, "script.yaml", "")
+	code, out, _ := ygg(t, "doctor", "--project", dir, "--config", config)
+	if code != ExitDone || !strings.Contains(out, "OK    tree: ") || !strings.Contains(out, "nodes") {
+		t.Errorf("doctor in a project: exit %d:\n%s", code, out)
+	}
+	code, out, _ = ygg(t, "doctor", "--project", t.TempDir(), "--config", config)
+	if code != ExitFailed || !strings.Contains(out, "ERROR tree: ") {
+		t.Errorf("doctor outside a tree: exit %d:\n%s", code, out)
+	}
+}
+
+func TestDoctorWarnsWhenAPublicUmbrellaListsAPrivateChild(t *testing.T) {
+	root := treetest.Build(t, treetest.Node{Owner: "brunogbv", Visibility: gungnir.VisibilityPublic, Children: map[string]treetest.Node{
+		"projects/secret": {Owner: "brunogbv", Visibility: gungnir.VisibilityPrivate}}})
+	code, out, _ := ygg(t, "doctor", "--root", root)
+	if code != ExitDone || !strings.Contains(out, "WARN  tree: ") || !strings.Contains(out, "projects/secret") {
+		t.Errorf("doctor --root: exit %d:\n%s", code, out)
+	}
+	if strings.Contains(out, "config") {
+		t.Errorf("doctor --root alone checked a config:\n%s", out)
+	}
+}
```

and to `internal/cli/cli_test.go`:

```diff
diff --git a/internal/cli/cli_test.go b/internal/cli/cli_test.go
index 13b047c..1d7fd51 100644
--- a/internal/cli/cli_test.go
+++ b/internal/cli/cli_test.go
@@ -87,9 +87,16 @@ func TestRunStopsAndApproveContinues(t *testing.T) {
 	}
 	id := runID(t, dir)
 	code, out, _ = ygg(t, "status", id, "--project", dir)
-	if code != ExitDone || !strings.Contains(out, "waiting:  design-gate") {
+	if code != ExitDone || !strings.Contains(out, "waiting:  design-gate (design)") || !strings.Contains(out, "leaf:     repos/app on ygg/"+id+" at ") {
 		t.Errorf("status: exit %d:\n%s", code, out)
 	}
+	// Each decision takes only its own flag.
+	if code, _, _ := ygg(t, "approve", id, "design-gate", "--project", dir, "--reason", "x"); code != ExitRefused {
+		t.Errorf("approve --reason: exit %d, want %d", code, ExitRefused)
+	}
+	if code, _, _ := ygg(t, "reject", id, "design-gate", "--project", dir, "--note", "x"); code != ExitRefused {
+		t.Errorf("reject --note: exit %d, want %d", code, ExitRefused)
+	}
 	// Flags may follow the positional arguments.
 	if code, out, errOut := ygg(t, "approve", id, "design-gate", "--project", dir, "--note", "fine"); code != ExitDone {
 		t.Errorf("approve: exit %d:\n%s%s", code, out, errOut)
```

- [ ] **Step 2:** run the named test; expect `TestRunStopsAndApproveContinues` to fail at `status`
      (and `approve --reason` to approve the gate), and both doctor tests to fail.
- [ ] **Step 3:** apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 391c287..f7c020d 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -7,7 +7,9 @@ import (
 	"flag"
 	"fmt"
 	"io"
+	"maps"
 	"path/filepath"
+	"slices"
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/odin/internal/engine"
@@ -28,7 +30,7 @@ const usage = `usage:
   ygg approve <run-id> <gate> [--note <text>] [--project <dir>] [--mode <mode>]
   ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
   ygg status  <run-id> [--project <dir>]
-  ygg doctor  [--project <dir>] [--config <factory.yaml>]
+  ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
 exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point
 `
 
@@ -58,7 +60,8 @@ type command struct {
 
 // flags holds every flag; each command reads the ones it defines.
 type flags struct {
-	project, config, realm, brief, mode, note, reason string
+	project, config, realm, brief, mode, note, reason, root string
+	set                                                     map[string]bool // the flags given
 }
 
 // parse parses flags that may come before, between or after the positional arguments, and
@@ -85,6 +88,8 @@ func (c *command) parse(name string, args []string, want int, define func(*flag.
 		fmt.Fprintf(c.err, "ygg %s: want %d argument(s), got %d\n%s", name, want, len(pos), usage)
 		return nil, nil, false
 	}
+	f.set = map[string]bool{}
+	fs.Visit(func(fl *flag.Flag) { f.set[fl.Name] = true })
 	return f, pos, true
 }
 
@@ -171,8 +176,11 @@ func (c *command) resume(args []string) int {
 
 func (c *command) decide(name string, args []string) int {
 	f, pos, ok := c.parse(name, args, 2, func(fs *flag.FlagSet, f *flags) {
-		fs.StringVar(&f.note, "note", "", "a note on the approval")
-		fs.StringVar(&f.reason, "reason", "", "why the work goes back")
+		if name == "approve" {
+			fs.StringVar(&f.note, "note", "", "a note on the approval")
+		} else {
+			fs.StringVar(&f.reason, "reason", "", "why the work goes back")
+		}
 	})
 	if !ok {
 		return ExitRefused
@@ -244,7 +252,10 @@ func (c *command) status(args []string) int {
 	fmt.Fprintf(c.out, "run:      %s\nstatus:   %s\nmode:     %s\nrealm:    %s %s (graph %s)\nposition: %d\n",
 		s.ID, status, s.Mode, s.Realm, s.RealmVersion, s.GraphVersion, s.Position)
 	if s.Pending != "" {
-		fmt.Fprintf(c.out, "waiting:  %s\n", s.Pending)
+		fmt.Fprintf(c.out, "waiting:  %s (%s)\n", s.Pending, s.PendingGate)
+	}
+	for _, p := range slices.Sorted(maps.Keys(s.Leaves)) {
+		fmt.Fprintf(c.out, "leaf:     %s on %s at %.12s\n", p, s.Leaves[p].Branch, s.Leaves[p].Checkpoint)
 	}
 	if s.Error != "" {
 		fmt.Fprintf(c.out, "error:    %s\n", s.Error)
```

to `internal/cli/doctor.go`:

```diff
diff --git a/internal/cli/doctor.go b/internal/cli/doctor.go
index b3ab0cb..6e75f43 100644
--- a/internal/cli/doctor.go
+++ b/internal/cli/doctor.go
@@ -11,6 +11,7 @@ import (
 	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/run"
+	"github.com/ouroboric-dev/odin/internal/tree"
 )
 
 // doctor checks the config and every run in the project, and prints one line per finding. It
@@ -18,6 +19,7 @@ import (
 func (c *command) doctor(args []string) int {
 	f, _, ok := c.parse("doctor", args, 0, func(fs *flag.FlagSet, f *flags) {
 		fs.StringVar(&f.config, "config", "factory.yaml", "the factory config")
+		fs.StringVar(&f.root, "root", "", "a tree's root to check, without a project")
 	})
 	if !ok {
 		return ExitRefused
@@ -29,15 +31,22 @@ func (c *command) doctor(args []string) int {
 			bad = true
 		}
 	}
-	if _, err := schema.LoadFactory(f.config); err != nil {
-		var ce *schema.CapsError
-		if errors.As(err, &ce) {
-			report("ERROR", "caps", err.Error())
-		} else {
-			report("ERROR", "config", err.Error())
+	rootOnly := f.set["root"] && !f.set["project"] // an instance root alone: its tree, no runs
+	if !rootOnly || f.set["config"] {
+		checkConfig(f.config, report)
+	}
+	root := f.root
+	if root == "" {
+		var err error
+		if root, _, err = tree.FindRoot(c.ctx, f.project); err != nil {
+			report("ERROR", "tree", err.Error())
 		}
-	} else {
-		report("OK", "config", f.config)
+	}
+	if root != "" {
+		c.checkTree(root, report)
+	}
+	if rootOnly {
+		return exit(bad)
 	}
 	runs := filepath.Join(f.project, ".factory", "runs")
 	entries, err := os.ReadDir(runs)
@@ -65,8 +74,52 @@ func (c *command) doctor(args []string) int {
 		}
 		report("OK", "run "+s.ID, string(s.Status))
 	}
+	return exit(bad)
+}
+
+func exit(bad bool) int {
 	if bad {
 		return ExitFailed
 	}
 	return ExitDone
 }
+
+func checkConfig(path string, report func(level, what, msg string)) {
+	if _, err := schema.LoadFactory(path); err != nil {
+		var ce *schema.CapsError
+		if errors.As(err, &ce) {
+			report("ERROR", "caps", err.Error())
+		} else {
+			report("ERROR", "config", err.Error())
+		}
+		return
+	}
+	report("OK", "config", path)
+}
+
+// checkTree walks the instance tree from root, checking out nothing, and warns when a public
+// umbrella lists a private child: its name shows in .gitmodules (spec §3.1).
+func (c *command) checkTree(root string, report func(level, what, msg string)) {
+	nodes, present := 0, 0
+	err := tree.Walk(c.ctx, root, func(n tree.Node) error {
+		where := n.Path
+		if where == "" {
+			where = "."
+		}
+		nodes++
+		if n.Present {
+			present++
+		}
+		if n.Umbrella != nil {
+			for _, p := range n.Umbrella.Leaks() {
+				report("WARN", "tree", fmt.Sprintf("the public umbrella %s lists the private child %s; its name shows in .gitmodules", where, p))
+			}
+		}
+		return nil
+	})
+	if err != nil {
+		report("ERROR", "tree", err.Error())
+		return
+	}
+	report("OK", "tree", fmt.Sprintf("%s: %d nodes, %d checked out", root, nodes, present))
+}
```

and to `README.md`:

````diff
diff --git a/README.md b/README.md
index 7f5f708..64c3601 100644
--- a/README.md
+++ b/README.md
@@ -21,7 +21,7 @@ ygg resume  <run-id> [--project <dir>] [--mode <mode>]
 ygg approve <run-id> <gate> [--note <text>] [--project <dir>] [--mode <mode>]
 ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
 ygg status  <run-id> [--project <dir>]
-ygg doctor  [--project <dir>] [--config <factory.yaml>]
+ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
 ```
 
 Exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point.
@@ -29,6 +29,12 @@ Exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point.
 `factory.yaml` must set both budget caps, `per_run` and `per_day`, each with `tokens` and `turns`.
 The factory ships no defaults, so a config without them runs nothing.
 
+`--project` names a project umbrella. A project is usually its own tree, its `umbrella.yaml` setting
+`root: true`; inside a company umbrella, every umbrella above it lists the one below, up to the one
+that sets `root: true`. A run works on its
+own branch, `ygg/<run-id>`, in each leaf its graph names, and commits a checkpoint after every node.
+The realm creates a leaf the project lacks. `ygg doctor --root <dir>` checks a tree without a project.
+
 ## Docs
 
 - Architecture: [docs/architecture.md](docs/architecture.md)
````

- [ ] **Step 4:** run the named test; expect `ok`. Commit.

---

### Task v0-T059: the toy graph lands its work; the git escape tests

The phase's exit criterion as tests. The toy graph gains the merge gate and the pointer move, so a run
ends with its work on the leaf's `main` and the project pointing at it, across six approval points.
A scripted agent tries the git escapes of spec §13 that need no sandbox.

**Files (in `odin`):**
- Create: `internal/cli/escape_test.go`
- Modify: `internal/cli/cli_test.go`, `internal/cli/e2e_test.go`, `testdata/toy/graph.yaml`,
  `testdata/toy/pack.yaml`

**Acceptance criteria:**
- [ ] Step-by-step stops at all six approval points; key-points and unattended only at `design`;
      unattended with `design: auto` never; `plan: stop` adds `plan`. Every run ends with the
      project pointing at the leaf's merged commit, one `pointer_moved`, one `repo_created`, a
      verified ledger and six gate files.
- [ ] The command-line tests start from a project without the leaf, so the realm creates it.
- [ ] Escape tests (review focus 1): a hook written to the leaf's `.git` fails the node, and no hook
      runs; a hook in the leaf's real git dir never runs; a rewritten `.git` file stops the run at
      `policy-violation`, and git never touches the planted git dir; a nested submodule with a
      command as its URL stops the run, nothing is committed, and the command never runs; a script
      that writes out of its leaf is refused before anything runs, and a file named like a record
      inside the leaf leaves the ledger verified.
- [ ] Each escape test fails when its defence is removed.

**Named test:** `go test -race ./internal/cli/ -run 'TestToyGraphEndToEnd|TestAnAgent|TestAHook|TestARewritten|TestANested'`,
five times in a row (`-count=5`), stable (checked). **Layer:** `odin`. **Size:** M (194).
**Depends on:** v0-T058.

- [ ] **Step 1:** apply to `internal/cli/e2e_test.go`:

```diff
diff --git a/internal/cli/e2e_test.go b/internal/cli/e2e_test.go
index df31526..b46e914 100644
--- a/internal/cli/e2e_test.go
+++ b/internal/cli/e2e_test.go
@@ -12,6 +12,7 @@ import (
 	"testing"
 	"time"
 
+	"github.com/ouroboric-dev/odin/internal/git"
 	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
@@ -85,7 +86,7 @@ func TestToyGraphEndToEnd(t *testing.T) {
 		stops             []string
 	}{
 		{"step-by-step stops at every approval point", "", "step-by-step",
-			[]string{"design-gate", "spec-gate", "plan-gate", "feature-gate"}},
+			[]string{"design-gate", "spec-gate", "plan-gate", "feature-gate", "merge-gate", "pointer-gate"}},
 		{"key-points stops only at design", "", "key-points", []string{"design-gate"}},
 		{"unattended stops at design by default", "", "unattended", []string{"design-gate"}},
 		{"unattended with design: auto never stops", "gates: { design: auto }\n", "unattended", nil},
@@ -103,15 +104,15 @@ func TestToyGraphEndToEnd(t *testing.T) {
 			if got := count(names, "gate_pending"); got != len(m.stops) {
 				t.Errorf("gate_pending = %d, want %d", got, len(m.stops))
 			}
-			if got := count(names, "gate_auto_passed"); got != 4-len(m.stops) {
-				t.Errorf("gate_auto_passed = %d, want %d", got, 4-len(m.stops))
+			if got := count(names, "gate_auto_passed"); got != 6-len(m.stops) {
+				t.Errorf("gate_auto_passed = %d, want %d", got, 6-len(m.stops))
 			}
 			if got := count(names, "gate_approved"); got != len(m.stops) {
 				t.Errorf("gate_approved = %d, want %d", got, len(m.stops))
 			}
 			gates, _ := os.ReadDir(filepath.Join(run.Dir(dir, id), "gates"))
-			if len(gates) != 4 {
-				t.Errorf("%d gate files, want 4 (one per approval point, stopped or not)", len(gates))
+			if len(gates) != 6 {
+				t.Errorf("%d gate files, want 6 (one per approval point, stopped or not)", len(gates))
 			}
 			if names[len(names)-1] != "run_finished" {
 				t.Errorf("the last event is %s, want run_finished", names[len(names)-1])
@@ -119,6 +120,15 @@ func TestToyGraphEndToEnd(t *testing.T) {
 			if b, err := os.ReadFile(filepath.Join(dir, "repos", "app", "build.txt")); err != nil || string(b) != "done\n" {
 				t.Errorf("repos/app/build.txt = %q, %v", b, err)
 			}
+			// The run's work landed: the leaf's main holds it, and the project points at it.
+			s, _ := run.LoadState(run.Dir(dir, id))
+			app := s.Leaves["repos/app"]
+			if gitlink, _ := git.Run(context.Background(), dir, "rev-parse", "HEAD:repos/app"); gitlink != app.Checkpoint {
+				t.Errorf("the project points repos/app at %s, want the run's merged commit %s", gitlink, app.Checkpoint)
+			}
+			if count(names, "pointer_moved") != 1 || count(names, "repo_created") != 1 {
+				t.Errorf("pointer_moved %d, repo_created %d; want 1 of each", count(names, "pointer_moved"), count(names, "repo_created"))
+			}
 		})
 	}
 
```

and to `internal/cli/cli_test.go`:

```diff
diff --git a/internal/cli/cli_test.go b/internal/cli/cli_test.go
index 1d7fd51..9802964 100644
--- a/internal/cli/cli_test.go
+++ b/internal/cli/cli_test.go
@@ -27,7 +27,7 @@ func project(t *testing.T, script, extra string) (dir, config string) {
 	if err != nil {
 		t.Fatal(err)
 	}
-	dir = treetest.Project(t, "repos/app")
+	dir = treetest.Project(t) // the toy realm creates its leaf, repos/app
 	config = filepath.Join(t.TempDir(), "factory.yaml")
 	s := filepath.Join(toy, script)
 	body := extra + "roles:\n  planner: { agent: scripted, model: none, script: " + s + " }\n" +
```

- [ ] **Step 2:** run `go test ./internal/cli/ -run TestToyGraphEndToEnd`; expect
      `stops = [design-gate spec-gate plan-gate feature-gate], want [design-gate spec-gate plan-gate feature-gate merge-gate pointer-gate]`,
      and `pointer_moved 0`.
- [ ] **Step 3:** apply to `testdata/toy/graph.yaml`:

```diff
diff --git a/testdata/toy/graph.yaml b/testdata/toy/graph.yaml
index 1bd8e8b..12bcd2e 100644
--- a/testdata/toy/graph.yaml
+++ b/testdata/toy/graph.yaml
@@ -1,7 +1,8 @@
-# The toy graph: every node kind and four approval points, with a scripted agent (spec §13). Its
-# nodes work in one leaf, repos/app, which the realm creates when a project lacks it.
+# The toy graph: every node kind and six approval points, with a scripted agent (spec §13). Its
+# nodes work in one leaf, repos/app, which the realm creates when a project lacks it. The work lands
+# on the leaf's main through the merge gate, and the project's pointer moves to it.
 name: toy
-version: 2.0.0
+version: 3.0.0
 nodes:
   - { id: design, kind: agent, role: planner, prompt: prompts/design.md, repo: repos/app }
   - { id: design-gate, kind: gate, gate: design }
@@ -13,3 +14,7 @@ nodes:
   - { id: build, kind: agent, role: implementer, prompt: prompts/build.md, repo: repos/app }
   - { id: check, kind: exec, run: [grep, -q, done, build.txt], repo: repos/app }
   - { id: feature-gate, kind: gate, gate: feature }
+  - { id: merge-gate, kind: gate, gate: merge }
+  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }
+  - { id: pointer-gate, kind: gate, gate: pointer }
+  - { id: pointer, kind: pointer, repo: repos/app, checks: [unit], acceptance: [e2e] }
```

and to `testdata/toy/pack.yaml`:

```diff
diff --git a/testdata/toy/pack.yaml b/testdata/toy/pack.yaml
index 0f0daeb..68fd0e6 100644
--- a/testdata/toy/pack.yaml
+++ b/testdata/toy/pack.yaml
@@ -1,5 +1,8 @@
 name: toy
-version: 0.2.0
+version: 0.3.0
 graph: graph.yaml
+checks:
+  unit: [grep, -q, done, build.txt]          # in the leaf
+  e2e: [grep, -q, done, repos/app/build.txt] # in the project, with the leaf at its new pointer
 leaves:
   repos/app: { description: the toy app, template: templates/app, first_commit: [LICENSE] }
```

- [ ] **Step 4:** run `go test ./internal/cli/`; expect `ok`. Write `internal/cli/escape_test.go`:

```go
package cli

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/ledger"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/tree"
)

// The escape-attempt tests of spec §13 that need no sandbox: a scripted agent tries to reach git
// or Odin's records from inside its leaf, and Odin blocks or ignores it. The sandbox's own tests
// (initializeCommand, ~/.ssh) come with Phase 3.

// escape starts a toy run in unattended mode, with design: auto so it never stops at a gate, whose
// design node is the given scripted step, and returns the project, the run's id and ygg's exit.
func escape(t *testing.T, designStep string) (dir, id string, code int) {
	t.Helper()
	toy, _ := filepath.Abs("../../testdata/toy/script.yaml")
	b, err := os.ReadFile(toy)
	if err != nil {
		t.Fatal(err)
	}
	// The toy script with design's step replaced.
	i := strings.Index(string(b), "  design:\n")
	j := strings.Index(string(b), "  spec:\n")
	script := filepath.Join(t.TempDir(), "script.yaml")
	if err := os.WriteFile(script, []byte(string(b[:i])+"  design:\n"+designStep+string(b[j:])), 0o644); err != nil {
		t.Fatal(err)
	}
	dir, config := project(t, "script.yaml", "mode: unattended\ngates: { design: auto }\n")
	cfg, _ := os.ReadFile(config)
	if err := os.WriteFile(config, []byte(strings.ReplaceAll(string(cfg), toy, script)), 0o644); err != nil {
		t.Fatal(err)
	}
	code, _, _ = ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
	entries, _ := os.ReadDir(filepath.Join(dir, ".factory", "runs"))
	if len(entries) == 1 {
		id = entries[0].Name()
	}
	return dir, id, code
}

// app returns the repos/app leaf of the project in dir, as the tree records it.
func app(t *testing.T, dir string) tree.Node {
	t.Helper()
	root, rel, err := tree.FindRoot(context.Background(), dir)
	if err != nil {
		t.Fatal(err)
	}
	nodes, err := tree.Resolve(context.Background(), root, filepath.Join(rel, "repos/app"))
	if err != nil {
		t.Fatal(err)
	}
	return nodes[len(nodes)-1]
}

func verifies(t *testing.T, dir, id string) {
	t.Helper()
	s, err := run.LoadState(run.Dir(dir, id))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := ledger.Verify(filepath.Join(run.Dir(dir, id), "ledger.jsonl"), s.Ledger); err != nil {
		t.Errorf("the ledger doesn't verify: %v", err)
	}
}

const ok = "      result: { status: ok, summary: wrote design.md }\n"

func TestAnAgentCannotPlantAHookInTheLeaf(t *testing.T) {
	marker := filepath.Join(t.TempDir(), "hook-ran")
	dir, id, code := escape(t, "    - actions: [ { write: { path: .git/hooks/pre-commit, content: \"#!/bin/sh\\ntouch "+marker+"\\n\" } } ]\n"+ok)
	if code != ExitFailed {
		t.Errorf("exit %d, want %d: the leaf's .git is a file, so the write fails and the node with it", code, ExitFailed)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Error("a planted hook ran")
	}
	verifies(t, dir, id)
}

func TestAHookInTheLeafsGitDirNeverRuns(t *testing.T) {
	// As if the agent could reach the git dir, which the sandbox mounts read-only (Phase 3): a
	// hook there still never runs, because host git runs with hooks off.
	marker := filepath.Join(t.TempDir(), "hook-ran")
	dir, config := project(t, "script.yaml", "")
	code, _, _ := ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
	if code != ExitStopped {
		t.Fatalf("run: exit %d", code)
	}
	hook := filepath.Join(app(t, dir).GitDir, "hooks", "pre-commit")
	if err := os.WriteFile(hook, []byte("#!/bin/sh\ntouch "+marker+"\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	id := runID(t, dir)
	if code, out, errOut := ygg(t, "approve", id, "design-gate", "--project", dir); code != ExitDone {
		t.Fatalf("approve: exit %d:\n%s%s", code, out, errOut)
	}
	if _, err := os.Stat(marker); err == nil {
		t.Error("the hook ran during a checkpoint commit")
	}
}

func TestARewrittenGitFileStopsTheRun(t *testing.T) {
	evil := t.TempDir()
	dir, id, code := escape(t, "    - actions: [ { write: { path: .git, content: \"gitdir: "+evil+"\\n\" } } ]\n"+ok)
	if code != ExitStopped {
		t.Fatalf("exit %d, want %d: a stop at policy-violation", code, ExitStopped)
	}
	s, _ := run.LoadState(run.Dir(dir, id))
	if s.PendingGate != gungnir.GatePolicyViolation {
		t.Errorf("the run waits at %q, want policy-violation", s.PendingGate)
	}
	if entries, _ := os.ReadDir(evil); len(entries) != 0 {
		t.Error("git wrote to the git dir the agent planted")
	}
	verifies(t, dir, id)
}

func TestANestedSubmoduleIsNeverFetched(t *testing.T) {
	marker := filepath.Join(t.TempDir(), "pwned")
	plant := "    - actions:\n" +
		"        - write: { path: .gitmodules, content: \"[submodule \\\"x\\\"]\\n\\tpath = vendor/x\\n\\turl = ext::sh -c touch% " + marker + "\\n\" }\n" +
		"        - write: { path: vendor/x/.git/HEAD, content: \"ref: refs/heads/main\\n\" }\n" +
		"        - write: { path: vendor/x/.git/objects/.keep, content: \"\" }\n" +
		"        - write: { path: vendor/x/.git/refs/heads/.keep, content: \"\" }\n" + ok
	dir, id, code := escape(t, plant)
	if code != ExitStopped {
		t.Fatalf("exit %d, want %d: a stop at policy-violation", code, ExitStopped)
	}
	leaf := app(t, dir)
	l := git.Repo{GitDir: leaf.GitDir, WorkTree: leaf.Dir}
	s, _ := run.LoadState(run.Dir(dir, id))
	if head, _ := l.Run(context.Background(), "rev-parse", "HEAD"); head != s.Leaves["repos/app"].Checkpoint {
		t.Error("Odin committed the planted submodule")
	}
	if _, err := os.Stat(marker); err == nil {
		t.Error("the submodule's URL ran a command")
	}
	verifies(t, dir, id)
}

func TestAnAgentCannotWriteOdinsRecords(t *testing.T) {
	// A path out of the leaf is refused when the script loads, before anything runs.
	dir, _, code := escape(t, "    - actions: [ { write: { path: ../../.factory/runs/x/ledger.jsonl, content: \"{}\\n\" } } ]\n"+ok)
	if code != ExitRefused {
		t.Errorf("a script that writes out of its leaf: exit %d, want %d", code, ExitRefused)
	}
	if _, err := os.Stat(filepath.Join(dir, ".factory")); err == nil {
		t.Error("the refused run created .factory/")
	}
	// A file named like a record, inside the leaf, is only a file in the leaf: Odin's records are
	// in the project's .factory/, and the run's ledger still verifies.
	dir, id, code := escape(t, "    - actions: [ { write: { path: .factory/runs/x/ledger.jsonl, content: \"{}\\n\" } } ]\n"+ok)
	if code != ExitDone {
		t.Errorf("exit %d, want %d", code, ExitDone)
	}
	verifies(t, dir, id)
}
```

- [ ] **Step 5:** run the named test; expect `ok`. These tests run over finished code, so prove each
      can fail: in `internal/leaf/leaf.go`, remove `Checkpoint`'s call to `l.checkGitFile()`, and
      expect `TestARewrittenGitFileStopsTheRun` to fail; restore it, remove the call to
      `l.checkNested()`, and expect `TestANestedSubmoduleIsNeverFetched` to fail; restore it, remove
      `"-c", "core.hooksPath=/dev/null",` from `internal/git/git.go`, and expect
      `TestAHookInTheLeafsGitDirNeverRuns` to fail (all three checked). Undo each change.
- [ ] **Step 6:** run the named test with `-count=5`; expect `ok`. Commit. odin's tasks are done: land
      the branch as one pull request, and quote the named test's output in it as the Phase 2 exit
      evidence.

---

### Task v0-T060: pointers and the exit check

**Files (in `yggdrasil`):**
- Modify: the `gungnir` and `odin` submodule pointers (`gleipnir` has no Phase 2 change)

**Acceptance criteria:**
- [ ] Each pointer is its repo's `main`, which holds its Phase 2 tasks, and `test` is green on that
      commit.
- [ ] The exit criterion holds at those pointers, through `go.work`: the tree fixtures pass, the
      deeper one included (v0-T044, v0-T045); both merge-gate tests of spec §13 pass (v0-T049); the
      git escape tests pass with the `scripted` adapter (v0-T059).
- [ ] `check-repos.sh` (all checks, all repos) exits 0.

**Named test:** in `yggdrasil`,
`go test -race github.com/ouroboric-dev/gungnir/... github.com/ouroboric-dev/gleipnir/... github.com/ouroboric-dev/odin/...`
passes, and so does the exit criterion on its own:
`go test -race github.com/ouroboric-dev/odin/internal/tree/... github.com/ouroboric-dev/odin/internal/merge/ github.com/ouroboric-dev/odin/internal/cli/ -run 'TestResolve|TestFindRoot|TestWalk|TestMergeGate|TestAnAgent|TestAHook|TestARewritten|TestANested'`;
`git submodule status gungnir odin` matches each repo's `origin/main`; and
`as-bot.sh --read all ../ouroboric/scripts/check-repos.sh` exits 0. **Layer:** `yggdrasil`. **Size:**
S. **Depends on:** v0-T039 to v0-T059 merged.

- [ ] **Step 1:** branch `pointers/phase-2`; in `gungnir` and `odin`, fetch and check out `origin/main`.
- [ ] **Step 2:** run the named test; expect it to pass and exit 0. Check that each repo's latest
      `ci` run on `main` is green, at the commit its pointer names:
      `as-bot.sh --read all gh run list --repo ouroboric-dev/<repo> --branch main --workflow ci --limit 1`.
- [ ] **Step 3:** stage the two paths; commit (`Move gungnir and odin to Phase 2 (v0-T060)`); push
      and open the PR. Its body records the exit criterion, with the tests' output and the
      `check-repos.sh` result. When the founder merges it, Phase 2 is done.

---
