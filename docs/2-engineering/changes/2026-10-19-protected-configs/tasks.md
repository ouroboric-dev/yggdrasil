---
title: Tasks for the protected configs
status: draft
date: 2026-10-19
related: [proposal.md, delta.md, ../2026-10-18-realm-readiness/tasks.md]
style: spec
---

# Protected configs: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for
> tracking. Steps marked **founder** are done by the founder, never by an agent.

**Goal:** every rung of both build realms refuses a task's change to the files that check a product: the
base-CI files, the licensing files, the realm's tool configs, `.github/` and `.devcontainer/`.

**Architecture:** a shared list of git pathspecs, `devcontainer/checks/protected-common`, byte for byte the same
in both realms. Each realm's protected check reads it and adds its own names. `go-static.sh` takes the stricter
behaviour of `web-protected.sh`. The B-049 tests keep proving the baked configs, with the weakened config on the
leaf's `main`. `check-repos.sh --check shared` keeps the two lists the same.

**Tech stack:** bash, git pathspecs, Go tests (standard library only), `check-repos.sh`'s test harness.

**Spec:** [proposal](proposal.md) and [delta](delta.md). Where this plan and the proposal differ, this plan
wins.

**Status:** accepted when the founder merges the pull request that adds this file.

## Global constraints

- `devcontainer/checks/protected-common`, exact contents (one git pathspec a line; `#` starts a comment; blank
  lines are skipped):

  ```text
  # The files that check every product. Every rung refuses a task's change to them (spec §9.5).
  # One git pathspec a line. The same file in every build realm: check-repos.sh --check shared compares them.
  .github/
  .devcontainer/
  .pre-commit-config.yaml
  :(glob)**/.markdownlint*
  :(glob)**/.yamllint
  :(glob)**/.yamllint.yaml
  :(glob)**/.yamllint.yml
  :(glob)**/.shellcheckrc
  :(glob)**/.gitleaks.toml
  :(glob)**/.gitleaksignore
  :(glob)**/REUSE.toml
  .reuse/
  LICENSES/
  LICENSE
  :(glob)**/*.license
  ```

- The Go realm adds: `:(glob)**/.golangci.yml`, `:(glob)**/.golangci.yaml`, `:(glob)**/.golangci.toml`,
  `:(glob)**/.golangci.json`.
- The web realm adds: `:(glob)**/.npmrc`, `:(glob)**/eslint.config.*`, `:(glob)**/.eslintrc*`,
  `:(glob)**/tsconfig*.json`, `:(glob)**/vite.config.*`, `:(glob)**/vitest.config.*`,
  `:(glob)**/vitest.workspace.*`, `:(glob)**/playwright.config.*`. It keeps the `package.json` scripts check
  as it is.
- Both checks find the list beside themselves (`$(dirname "${BASH_SOURCE[0]}")/protected-common`), so the copy
  baked into `/opt/ygg/checks` is the one read. A missing or empty list fails the rung.
- Both checks, against `base="$(git merge-base HEAD main)"`:
  - fail when there is no `main`;
  - list `git diff --no-renames --name-only "$base" -- <pathspecs>` with no `--diff-filter`;
  - add `git ls-files --others -- <pathspecs>`, with no `--exclude-standard`, so ignored files are listed too;
  - add `:(exclude,glob)**/node_modules/**` to the pathspecs. Installed packages carry their own `tsconfig.json`,
    `.eslintrc*` and `*.license` files, and no tool reads a config from there for the leaf;
  - print every path, and end with "Put them back as they were; if the check is wrong, say so in your report."
- The web template's `lint` script becomes exactly `eslint --no-config-lookup -c eslint.config.js .`.
- Tests must not skip in the realm's own CI. A refusal test needs no linter, and asserts that no tool was called.
  midgard-react's rung tests pass `YGG_E2E_WAIT=1`.
- Go tests use the standard library only. No new module goes into `go.mod`.
- Write each test first and watch it fail (invariant 2). Never weaken a guardrail (invariant 7): everything
  protected today stays protected.
- Commits end with `(protected-configs-T00n)` and `Co-Authored-By: Claude <model> <noreply@anthropic.com>`. No
  session links.
- A docs file passes the docs check and the repo's pre-commit (`uvx -q --from 'pre-commit==4.6.2' pre-commit run
  --files <changed>`).

## Review focus

1. **A legitimate task file is refused.** `docs/licensing.md`, `src/license.ts`, `src/vite-env.d.ts`,
   `src/eslint-rules.ts` and `internal/lint/golangci_test.go` must pass the protected check. So must a web leaf
   whose gitignored `node_modules/` holds packages with their own `tsconfig.json`, `.eslintrc.json`, `LICENSE` and
   `*.license` files (T001, T002).
2. **A config hidden from git slips past**: ignored by `.gitignore`, a symlink swapped in (a type change), a
   nested copy, a rename. Each is refused (T001, T002).
3. **No `main`, or no list** (`protected-common` deleted or empty in the image): the rung fails, never passes
   (T001, T002).
4. **The two lists drift.** `check-repos.sh --check shared` fails when they differ (T003).
5. **The product's CI looks up a nested ESLint config.** `TestTemplateCI` pins the `lint` script (T002).

## How each task lands

One pull request per task, in its repo, from a branch `protected-configs-T00n` made from `origin/main`. Rebase
on `main` before starting, because Phase 5c changes the same realms. Push and open the PR with
`../ouroboric/scripts/as-bot.sh <repo> git push -u origin <branch>` and `as-bot.sh <repo> gh pr create ...`.
None of these tasks touches a root `.github/workflows/` file, so the pr-bot can push each one.

---

### Task protected-configs-T001: the Go ladder's protected files

**Files (in `helheim-go`):**

- Create: `devcontainer/checks/protected-common` (the exact contents in Global constraints)
- Modify: `devcontainer/checks/go-static.sh` (the `== protected paths` block and its comment),
  `checks_test.go`, `docs/architecture.md`, `templates/api/AGENTS.md`, `prompts/implementer.md`

**Interfaces:**

- Produces: `devcontainer/checks/protected-common`, the source that T002 copies byte for byte.

- [ ] **Step 1: Write the failing tests** in `checks_test.go`.
  - `TestStaticRefusesAChangeToAProtectedFile`: a table over each line of `protected-common` and each Go name.
    For each one: a task that adds the file at the top folder, one that adds it nested (`a/b/<name>` for the
    `**/` entries), one that changes it, one that deletes it, one that leaves it untracked and gitignored, and one
    that replaces it with a symlink. Each fails `go-static.sh` with the path in the output and no linter call.
  - In the same test, the review-focus cases (`docs/licensing.md`, `src/license.ts`,
    `internal/lint/golangci_test.go`): a task that adds them passes the protected step.
  - `TestStaticFailsClosedWithoutMainOrList`: a leaf with no `main`, and a checks folder whose `protected-common`
    is missing or empty, each fail with a message.
  - Fold `TestStaticRefusesAChangeToTheDevContainer` and `TestStaticRefusesAWorkflowChange` into the table, or
    keep them. Either way, `.devcontainer/` and `.github/` stay covered.
  - Change `TestStaticLintsWithTheBakedConfigAndSkipsOnlyVerifiedSqlcOutput` and
    `TestStaticLintsWhatTheLeafTriedToHide`: put the permissive `.golangci.yml` (the edited, symlinked and
    gitignored cases) on the leaf's `main`, before the work branch. The rung must still fail on the lint error,
    which proves that the baked config runs. Add one case: the same permissive config in the task's diff is
    refused.
- [ ] **Step 2:** Run `go test -run 'Protected|FailsClosed|LintsWith|TriedToHide|DevContainer|Workflow' ./...`.
  Expected: FAIL. The new paths aren't refused, and there's no fail-closed.
- [ ] **Step 3:** Write `protected-common`. Change the block in `go-static.sh`: read the list beside the script,
  add the Go names, and apply the Global constraints' behaviour. Update its comment.
- [ ] **Step 4:** Run the named tests, then the whole suite in the realm-CI setup: the pinned Go image, non-root,
  `-race -v`, `YGG_REQUIRE_TEMPLATES=1`. Expected: `ok`, and the new tests ran (not SKIP).
- [ ] **Step 5: Docs.**
  - `templates/api/AGENTS.md` and `prompts/implementer.md` say which files a task may not change, and what to do
    instead: say so in the report.
  - `docs/architecture.md` describes the list, and that `protected-common` is shared.
- [ ] **Step 6:** Commit, push and open the PR.

**Acceptance criteria:**

- [ ] Every file in the list, and every Go name, is refused in all six forms. The review-focus files pass.
- [ ] No `main`, a missing list or an empty list fails the rung.
- [ ] The B-049 tests still fail on the lint error with the weak config on `main`.
- [ ] The suite passes in the realm CI, and the new tests ran.

**Named tests:** `helheim-go/checks_test.go:TestStaticRefusesAChangeToAProtectedFile`,
`TestStaticFailsClosedWithoutMainOrList`. **Size:** M.

### Task protected-configs-T002: the web ladder's protected files

**Files (in `midgard-react`):**

- Create: `devcontainer/checks/protected-common` (byte for byte T001's)
- Modify: `devcontainer/checks/web-protected.sh` (the list and its header comment), `checks_test.go`,
  `ci_test.go`, `templates/web/package.json` (the `lint` script), `docs/architecture.md`,
  `templates/web/AGENTS.md`, `prompts/implementer.md`

**Interfaces:**

- Consumes: T001's `protected-common`. Copy it from T001's reviewed branch with `git show`. If T001 changes it
  later, copy it again.

- [ ] **Step 1: Write the failing tests** in `checks_test.go`.
  - `TestEveryRungRefusesAChangeToAProtectedFile`: for every rung in `pack.yaml`'s `leaf.checks` (rung
    `web-<check>.sh`; read the pack as the realm's other tests do, which fixes B-066), and for each line of
    `protected-common` and each web name, the same six forms as T001. Each fails before any tool runs, with the
    path in the output. It includes `.devcontainer/` (B-063), and a deleted and a gitignored workflow (B-063's
    minors).
  - In the same test, the review-focus cases (`docs/licensing.md`, `src/license.ts`, `src/vite-env.d.ts`,
    `src/eslint-rules.ts`) pass the protected step. So does a leaf whose gitignored `node_modules/pkg/` holds
    `tsconfig.json`, `.eslintrc.json`, `LICENSE` and `x.license`.
  - A fail-closed case: a missing or empty `protected-common` fails every rung.
  - Make `TestEveryWebRungRefusesAChangeToTheScriptsAndNpmrc` and `TestEveryRungRefusesAWorkflowChange` take their
    rungs from `pack.yaml` too, or fold them into the new test.
  - Change `TestRealRungsIgnoreAnyConfigTheLeafHas`: each weakened config (in `src/`, `.mjs`, a symlink,
    gitignored, edited, planted at `.ygg-*`, the empty tsconfig, the vite config with no tests) goes on the leaf's
    `main`. The rung must still fail with the case's `want`. Add one case: the same config in the task's diff is
    refused.
  - `TestTemplateCI` (`ci_test.go`): the template's `lint` script is exactly
    `eslint --no-config-lookup -c eslint.config.js .`. Also check `hasLine`'s parent keys (B-063's minor).
- [ ] **Step 2:** Run the named tests. Expected: FAIL.
- [ ] **Step 3:** Copy `protected-common`. Change `web-protected.sh`: read the list beside the script, add the web
  names, and keep the `package.json` scripts check. Change the template's `lint` script.
- [ ] **Step 4:** Run the named tests, then the whole suite in the realm-CI setup (the Node image, the CI's apt
  step, Go 1.26.9, user `node`, `-race -v`). Expected: `ok`, with no skips. Also run the template's five CI
  commands on a fresh copy in the Node image: `npm run lint` must exit 0.
- [ ] **Step 5: Docs.** As in T001, for the web template, prompt and architecture page. Name `.devcontainer/` too.
- [ ] **Step 6:** Commit, push and open the PR.

**Acceptance criteria:**

- [ ] Every rung that `pack.yaml` names refuses every listed file, in all six forms. The review-focus files pass.
- [ ] A missing or empty list fails every rung.
- [ ] The B-049 tests still fail with the weak configs on `main`.
- [ ] `protected-common` is byte for byte T001's. The suite passes in the realm CI, with no skips.

**Named tests:** `midgard-react/checks_test.go:TestEveryRungRefusesAChangeToAProtectedFile`,
`ci_test.go:TestTemplateCI`. **Size:** M. **Depends on:** T001 (reviewed).

### Task protected-configs-T003: the shared check covers the list

**Files (in `ouroboric`):**

- Modify: `scripts/check-repos.sh` (`SHARED`), `scripts/tests/check-repos.test.sh`

- [ ] **Step 1:** Add a test case: two realms with the same `docs.sh` but a different `protected-common` give
  `FAIL ... protected-common differs from helheim-go's`. Run the test file. Expected: that line fails.
- [ ] **Step 2:** Set `SHARED=(devcontainer/checks/docs.sh devcontainer/checks/protected-common)`. Run the test
  file: every line is `ok`. Then run shellcheck as `check-repos.sh`'s other tasks do.
- [ ] **Step 3:** Commit, push and open the PR.
- [ ] **Step 4:** After T001 and T002 merge: `--check shared midgard-react helheim-go` on both realms' `main`
  (copy the shared files into a `CHECK_REPOS_ROOT`, as realm-readiness T007 step 6 did). Expected: two `PASS`
  lines.

**Named test:** `ouroboric/scripts/tests/check-repos.test.sh`. **Size:** S. **Depends on:** T001, T002 for step 4.

### Task protected-configs-T004: the record

**Files (in `yggdrasil`):**

- Modify: `docs/2-engineering/backlog.md` (B-055, B-063, B-066 and B-070 move to Done, with their PRs),
  `docs/2-engineering/realm-readiness.md` (RR-09 names `protected-common`; RR-15 says the protected files are
  refused), the `helheim-go` and `midgard-react` pointers (the merge commits of T001 and T002)

- [ ] **Step 1:** Edit the backlog and the checklist. Set the pointers with
  `git update-index --cacheinfo 160000,<sha>,<leaf>` and check them with `git ls-tree HEAD <leaf>`.
- [ ] **Step 2:** The docs check and pre-commit on the changed files.
- [ ] **Step 3:** Commit, push and open the PR.

**Size:** S. **Depends on:** T001 to T003 merged.
