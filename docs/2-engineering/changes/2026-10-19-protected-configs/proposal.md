---
title: The ladder refuses a task's change to the configs that check a product
status: draft
date: 2026-10-19
related: [delta.md, tasks.md, ../2026-10-18-realm-readiness/proposal.md, ../2026-10-18-base-ci-rollout/proposal.md, ../../backlog.md]
style: spec
---

# The ladder refuses a task's change to the configs that check a product

**Proposed 2026-10-19.** It fixes backlog [B-055](../../backlog.md), B-063, B-066 and B-070, which the
[realm readiness](../2026-10-18-realm-readiness/proposal.md) assessments and their final review found.

## Why

- A product has two lines of defence. The factory's check ladder runs during a run, and the product's own CI
  (`ci.yml`, `lint.yml`) runs after it. The ladder lints with configs baked into its image, and ignores the
  leaf's copies (B-049). The product's CI reads the copies in the repo.
- So a factory run can weaken the product's CI and keep every rung green. For example, it can turn off an
  ESLint rule, empty `.pre-commit-config.yaml`, or add a `.gitleaksignore`. Only the reviewers would see it.
- Rung 1 refuses a change to `.github/` already. It does not refuse the files that `.github/`'s workflows read.
- Two smaller holes are in the same code:
  - the web ladder does not protect `.devcontainer/` (B-063);
  - the Go ladder's protection is weaker than the web one (B-070): it skips when there is no `main`, misses a
    type change, and misses ignored files.

## Decisions (the founder, 2026-10-19)

- **The realm owns a product's tool configs and base-CI files during a factory run.** A task never changes them.
  This matches B-049: the ladder already ignores the leaf's copies, so a task gains nothing by editing them.
- **Every rung refuses the change.** This applies to licensing files too (`REUSE.toml`, `LICENSES/`, `LICENSE`,
  `*.license`). There is no approval path.
- **The product's CI keeps reading the files in the repo.** Moving them to protected copies (for example under
  `.github/`) was rejected: it doubles every config and changes the org-wide base CI.

## What changes

- **One shared list of protected files**, `devcontainer/checks/protected-common`, byte for byte the same in both
  build realms. It holds the base-CI and licensing files every product has. `check-repos.sh --check shared` keeps
  the copies the same.
- **Each realm adds its own names**: the Go configs (`.golangci.*`) or the web configs (`eslint.config.*`,
  `tsconfig*.json`, `vite.config.*`, `vitest.config.*`, `playwright.config.*`, `.npmrc`), and `.devcontainer/`
  in both.
- **Names match anywhere in the tree** (git's `:(glob)**/<name>`), so a config added in a subfolder is refused
  too. ESLint, markdownlint and shellcheck all read the nearest config.
- **Both protected-path checks behave the same**: they fail closed with no `main`, and they list every change
  (added, changed, deleted, renamed, a type change), and untracked files, ignored ones too.
- **The web template's `lint` script names its config** (`eslint --no-config-lookup -c eslint.config.js .`),
  so the product's CI never looks one up.
- **The B-049 tests still prove the baked configs**: the weakened config now sits on the leaf's `main`, where
  the protected check doesn't see it, and the rung must still fail.
- **Docs**: each template's `AGENTS.md`, each implementer prompt and each realm's architecture page name the
  refused files.

## Not in this change

- **Inline suppressions** (`//nolint`, `eslint-disable`, `# shellcheck disable`, `gitleaks:allow`,
  `<!-- markdownlint-disable -->`). They weaken the ladder and the product's CI alike, and the reviewers read
  them. That is a separate question.
- **Protected copies of the configs** (option B, rejected above).
- **The dependency list of `package.json`, and the lock files.** Phase 5c's dependency policy owns them.

## Impact

- **Repos:** `helheim-go`, `midgard-react` (the checks, tests, the web template's `lint` script, docs);
  `ouroboric` (`check-repos.sh`'s `SHARED`); `yggdrasil` (backlog, pointers).
- **Approval points:** none added. The ladder refuses more paths.
- **A task that needs a config change** fails rung 1 with the paths and "say so in your report". The change then
  goes into the realm, through a realm PR.
- **Phase 5c** works in both realms at the same time. Each task rebases on `main` before it starts.
