---
title: The base CI on every existing non-realm repo, with lint required
status: proposed
date: 2026-10-18
related: [../2026-10-18-repo-bootstrap/proposal.md, ../2026-10-18-realm-readiness/proposal.md]
style: spec
---

# The base CI on every existing non-realm repo, with lint required

**Proposed 2026-10-18 (founder, from a brainstorming session with Claude Code):** every existing
public `ouroboric-dev` repo except the realms gets the full base CI that `new-repo.sh` gives new repos.
That is `.pre-commit-config.yaml` with every piece, and `.github/workflows/lint.yml`. Each repo's
existing files are fixed until `lint` passes, then `lint` becomes a required check. Where the linters
and the house style disagree, the linter bends when the house style has a real reason. Otherwise the
files change to the linter's default. The founder runs two commands, each covering every repo.

This is future-work item 1 of [repo bootstrap](../2026-10-18-repo-bootstrap/proposal.md#future-work-documented-not-built).

## Why

- **Only new repos are checked in CI.** Repo bootstrap (ouroboric #46, #47) gives every new repo a
  required `lint` check. The ten existing non-realm repos still check secrets, licences and formatting
  only on the founder's machine, through a gitleaks-only pre-commit hook and `check-repos.sh`.
- **The founder wants the full set at once.** Every repo gets every piece now, and its docs get fixed.
  The alternative was a required `lint` early, with fewer pieces at first, and the founder rejected it.
- **The realms are covered elsewhere.** The realm-readiness session (`ouroboric-6e`) rolls the same
  base CI out to `asgard`, `midgard-react` and `helheim-go`. It will copy this method and this script.

## Scope

In scope: the ten public repos that are not realms. These are `.github`, `ouroboric`, `yggdrasil`,
`ouroboric-packages`, `mimir`, `gungnir`, `odin`, `gleipnir`, `jormungandr` and `havamal`.

Out of scope:

- `huldra`. It is private and agents must never read it. The founder can run the same steps on it by
  hand.
- `asgard`, `midgard-react` and `helheim-go`. The realm-readiness session handles them.
- `check-repos.sh`. The realm-readiness session is changing it (a `shared` check). This change leaves
  it alone, and its `ruleset` check already requires `lint` wherever `lint.yml` exists.

## What the recon found

On 2026-10-18 the full base CI ran on a fresh clone of each repo's `main`: every piece
(`reuse,markdown,shell,actions,yaml`, plus gitleaks), `pre-commit run --all-files`, then
`gitleaks-history`.

| Repo | markdownlint | yamllint | shellcheck |
|---|---|---|---|
| yggdrasil | 33,051 in 31 files | 0 | 9 |
| ouroboric | 544 in 50 files | 6 | 44 |
| odin | 28 | 519 | 0 |
| .github | 14 | 1 | 0 |
| ouroboric-packages | 15 | 0 | 0 |
| havamal | 6 | 2 | 0 |
| mimir | 6 | 0 | 0 |
| gleipnir | 2 | 2 | 8 |
| gungnir | 2 | 2 | 0 |
| jormungandr | 2 | 2 | 0 |

- **gitleaks** (the staged hook and the full-history scan), **`reuse lint`** and **actionlint** pass
  in every repo.
- **yggdrasil:** 31,977 of its markdownlint findings are MD010 (hard tabs) in the six phase plans
  (`docs/2-engineering/plans/*/tasks.md`). They are Go code inside fenced code blocks. The rest are
  mostly MD032 (831), MD060 (716) and MD034 (131), spread across the docs.
- **ouroboric:** MD060 table style (250), MD022 blank lines around headings (188), MD032 blank lines
  around lists (47), MD041 (30, all in `docs/6-journal/`), MD033 inline HTML (24, the `<picture>`
  element the docs standard prescribes), MD040 (4) and MD038 (1). Its shellcheck findings are info
  and style codes (SC2329, SC2015, SC2016, SC1091, SC2012) in `scripts/check-repos.sh` and older
  tests.
- **odin:** almost all of its yamllint findings are in `testdata/` (flow-style `{…}` script and graph
  fixtures). 24 of its markdownlint findings are MD041 in `testdata/**/prompts/`.
- **The Go leaves** (gungnir, gleipnir, jormungandr, havamal, odin) share two findings:
  - one MD034 bare URL in `AGENTS.md`, the same link the scaffold template fix (#46, D5) covers;
  - in `.github/workflows/ci.yml`, one space before `# v7.0.1` where yamllint wants two, and one long
    line.
- **Every repo's existing `.pre-commit-config.yaml`** is the same gitleaks-only file that the scaffold
  wrote. The ten files are identical (sha256 `7119399c…`, measured with the trailing newline
  normalised), and none has other hooks. No repo has a `.markdownlint.yaml`, a `.yamllint.yaml` or a
  `lint.yml` yet.
- **The recon matches CI.**
  - The clones were not recursive. A submodule is a gitlink in its umbrella, not a set of files, so
    the umbrellas' counts cover only their own files. `actions/checkout` doesn't fetch submodules
    either, so CI lints the same set. Each submodule is linted in its own repo.
  - The hooks ran at their pinned revs, the same ones the `lint` job installs.
- **The pr-bot is installed on all ten repos.** `check-repos.sh --check bot` passes for each, so
  `as-bot.sh` can open every pull request.

## Goals

1. Each of the ten repos has the full base CI on `main`: `.pre-commit-config.yaml` with gitleaks
   (including `gitleaks-history`), reuse, markdown, shell, actions and yaml, and `lint.yml`.
2. `lint` passes on each repo's `main` and is a required check from GitHub Actions (app 15368), on a
   strict branch.
3. The founder's hands-on work is two commands, each covering every repo, plus reviewing and merging
   the pull requests.
4. The method and the script are reusable, so the realm-readiness session can run them on the three
   realms unchanged.
5. Each place the shared lint configs bend to the house style says why, in a comment in the config.

## Non-goals

- Changing gitleaks, reuse or actionlint behaviour. They already pass.
- A general `--merge` mode for `add-ci.sh`. No existing repo needs one (see [the upgrade
  path](#the-existing-pre-commit-config)).
- Language CI (`ci.yml`). The existing `ci.yml` files change only where yamllint requires it.
- Making `check-repos.sh` org-agnostic, or adding a `lint` check to it.
- Rewriting the meaning of any document. The fixes are formatting only.

## Anti-goals

The work fails, even if every check passes, when any of these is true:

- `lint` becomes required on a repo before `lint.yml` is on its `main`, which would block every pull
  request.
- Any file or folder is excluded from gitleaks or reuse.
- An exclusion hides prose or config that people write and read, rather than test inputs.
- A config change loosens a rule without a stated reason.
- The code inside the phase plans changes, which would break `plan-blocks.py` and the plan replay.
- A token appears in a command line, a log, an error message or a file, or the pr-bot gains Workflows
  permission.
- The founder needs more than the two commands, plus reviews and merges.

## What changes

### Bend or default: the rule

For each finding, the builder asks whether the house style gets real value from doing it its own way:

- **Yes:** the linter bends. The shared config gets a setting, or the repo excludes a folder of test
  inputs, with a comment that gives the reason.
- **No:** the files change to the linter's default.

The founder decided this rule. The cases the brainstorm sorted:

| Finding | Decision | Reason |
|---|---|---|
| MD010 hard tabs in Go code blocks | bend: MD010 ignores code blocks | gofmt requires tabs; the plan tools extract that code verbatim |
| odin `testdata/` YAML and prompt `.md` files | bend: exclude `testdata/` from markdownlint and yamllint only | they are test inputs read by code, not docs or config |
| MD022, MD032 blank lines | default | the habit carries no value |
| MD034 bare URLs, the yamllint comment spacing | default | no value in the current form |
| MD033 `<picture>`, `<source>`, `<img>` | bend: allow those elements | the docs standard prescribes `<picture>` for themed images |

Left to the builder, by the same rule:

- MD060 (table style);
- MD041 in the journal, whose entries open with front matter and `##` sections by design (see
  `docs/6-journal/README.md`);
- MD040 and MD038;
- the remaining yggdrasil findings;
- the shellcheck findings.

Each decision goes in the plan with its reason.

**Formatting-only edits to old records are fine** (the founder's words). This covers merged plans,
archived proposals and journal entries. Rewording is not.

### The shared configs

- The changes go into `ouroboric/scripts/templates/ci/pieces/markdown.files/.markdownlint.yaml` and
  `yaml.files/.yamllint.yaml`. They therefore also apply to every new repo and to the realms. The
  piece contract does not change.
- Each repo gets these configs from `add-ci.sh`. A repo's copy must not drift from the piece.
- A test in `add-ci.test.sh` (or a new one) runs the configs on fixtures that show each bend, so a
  later edit can't silently undo one.

### Per-repo exclusions

- odin's `testdata/` is the one exclusion the brainstorm found. The builder picks the mechanism, for
  example a per-linter ignore (`ignores` in a markdownlint-cli2 config, `ignore:` in yamllint), or
  `exclude:` on those two hooks only.
- An exclusion applies to markdownlint and yamllint only. It never applies to gitleaks or reuse (see
  the anti-goals).
- An exclusion lives in the repo that needs it, not in the shared piece. `add-ci.sh` and its piece
  contract stay as they are, unless the plan shows a change is needed.
- An exclusion lives in a repo-owned file of its own, never edited into the repo's copies of the
  shared `.markdownlint.yaml` or `.yamllint.yaml`, so those copies never drift from the piece. One
  example is a `.markdownlint-cli2.yaml` holding only `ignores:`. *(Executor's call, settling the
  builder check's question about drift.)*

### The existing pre-commit config

- `add-ci.sh` refuses any existing target today. It gains one narrow upgrade path. It may replace an
  existing `.pre-commit-config.yaml` only when that file is byte for byte the known gitleaks-only file
  that every repo has today:

  ```yaml
  repos:
    - repo: https://github.com/gitleaks/gitleaks
      rev: v8.30.1
      hooks:
        - id: gitleaks
  ```

  The builder confirms the exact bytes, including comments, from the repos.
- Any other existing file is still refused, so a person's own hooks are never overwritten.
- Whether this is a flag (such as `--upgrade`) or automatic is the builder's call. The plan states it.
  The header and `templates/ci/README.md` document it.

### The founder's two commands

One new founder-run script in `ouroboric/scripts`, with a test against the fakes (`fake-github.py`,
`fake-gh`), named by the builder (for example `rollout-ci.sh`). It has two modes.

1. **Push.** It pushes each repo's prepared rollout branch with the founder's token, then opens the
   pull request as the pr-bot through `as-bot.sh`. The founder pushes because the pr-bot can't push
   `.github/workflows/`.
   - The token reaches git only through the credential helper that `new-repo.sh` uses.
   - It refuses a repo whose local branch is missing, and pushes nothing for it.
   - The branch is `base-ci` in every repo.
   - It prints each PR's URL.
   - **Running it twice is safe.** It pushes with `--force-with-lease` when the remote branch
     differs, and does nothing when the two match. If a PR is already open for the branch, it prints
     that PR's URL instead of opening another. *(Executor's call.)*
   - **A PR that falls behind `main`.** The Go leaves already require `test` on a strict branch, so a
     PR that falls behind must be updated before it can merge. The agent rebases the branch, and the
     founder runs push mode again for that repo (the same command). Or the founder clicks "Update
     branch" on GitHub. *(Executor's call.)*
2. **Protect.** For each named repo whose `main` holds `.github/workflows/lint.yml`, it runs
   `setup-repo.sh --org ouroboric-dev <repo>`, so `lint` becomes required.
   - It skips, and names, any repo whose `lint.yml` isn't on `main` yet, so `lint` is never required
     early.
   - Then it runs `check-repos.sh --check ruleset <repo>` and prints the result.

Both modes take a list of repos, so the founder can run them on all ten at once or on a few. Both are
safe to run twice. The script's header says which token each mode needs (the same short-lived admin
token as `new-repo.sh`).

### The agent's work per repo

For each repo, on a branch made from `origin/main`:

1. Replace the gitleaks-only config: `add-ci.sh --org ouroboric-dev --ci reuse,markdown,shell,actions,yaml`,
   through the upgrade path.
2. Add any exclusion the repo needs.
3. Fix the files the hooks flag, formatting only, until `pre-commit run --all-files` and the
   `gitleaks-history` hook pass on the branch.
4. Commit, staging by path.
   - The commit that adds `lint.yml` can't be pushed by the pr-bot, so the founder's push mode pushes
     the branch.
   - The fixes may go in earlier commits, or in a separate pr-bot PR first, if the builder finds that
     simpler to review. The plan says which.

`markdownlint-cli2 --fix` may do the mechanical fixes. Every automated fix is reviewed in the diff
before commit.

The umbrellas need extra care, because their fixes are large. *(Executor's call.)*

- **The fixes ship first.** In `ouroboric` and `yggdrasil`, the formatting fixes go first in pr-bot
  PRs, split by top-level docs folder so each diff can be reviewed. The founder's pushed PR then
  holds only the config switch and `lint.yml`.
- **The fixes are proven formatting-only.** The plan names a check that compares each changed
  document's rendered text before and after, ignoring whitespace.
- **The plans still extract the same code.** For the phase plans, `plan-blocks.py`'s output must be
  identical before and after the fixes. This proves the code the plan tools extract did not change.

### Order

1. A pilot on one small Go leaf (gungnir, for example) goes end to end first: branch, push, PR, `lint`
   green, merge, protect. It proves the script and the upgrade path.
2. Then the other leaves and the small repos.
3. Last, the two umbrellas, which have the most fixes: `ouroboric`, then `yggdrasil`. The shared
   config bends land before them.

### Docs

- `ouroboric/docs/4-ways-of-working/docs-standard.md` §9: existing repos have the base CI too. Name
  the script's two modes, and the bend-or-default rule for lint configs.
- `ouroboric/scripts/templates/ci/README.md`: the upgrade path, and each config bend with its reason.
- `ouroboric/AGENTS.md`: a row for the new script, founder-only.
- When it lands, the executing session sends the realm-readiness session (`ouroboric-6e`) this
  proposal's path and the script's usage, by cross-session message. If that session has ended, it goes
  in a handover note.
- The shared config bends ship in the first `ouroboric` PR, before any repo is rolled out. The realm
  session copies the method after that, so it sees the final configs.

## Done when

- All ten repos have the full base CI on `main`, `lint` passes there, and `lint` is required (app
  15368, strict).
- `check-repos.sh --check ruleset --check gitleaks --check reuse` passes for each of the ten.
- The new script and the upgrade path have tests, and the whole `scripts/tests` suite passes.
- The realm-readiness session has the method.

## Left to the builder

- The script's name, and the flag names for the push and protect modes.
- The upgrade path's exact trigger: a flag, or automatic on an exact match.
- The decisions on MD060, MD041 in the journal, MD040, MD038, the remaining yggdrasil findings and the
  shellcheck findings, each by the bend-or-default rule, with its reason in the plan.
- The exclusion mechanism for odin's `testdata/`.
- Where each rollout branch is prepared: the local clones, worktrees or fresh clones. `.github` has no
  local clone today. Never touch a checkout another session is using.
- For the smaller repos, whether the formatting fixes ship in the same PR as `lint.yml` or in a pr-bot
  PR first. The umbrellas ship them first (see above).

## Interactions

- **The realm-readiness session** copies this method for the realms, and it is changing
  `check-repos.sh`. This change leaves `check-repos.sh` alone.
- **New repos** get the same config bends, because they live in the shared pieces. The real-run tests
  in `add-ci.test.sh` and `scaffold-component.test.sh` must still pass.
- **The org Actions allowlist** already holds both of `lint.yml`'s actions (repo bootstrap H01), so
  `lint` can start in every repo.
