---
title: Delta for the protected configs
status: draft
date: 2026-10-19
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../2026-10-18-realm-readiness/delta.md]
style: spec
---

# Delta: v0 spec §9.4, §9.5

## Added

- §9.5: every rung MUST refuse a task that adds, changes, deletes, renames or changes the type of a protected
  file, or leaves one untracked (ignored or not). It MUST do so before it installs or runs anything, and its
  output MUST name the files.
- §9.5: the protected files of a build realm MUST include:
  - `.github/` and `.devcontainer/`;
  - the base-CI files: `.pre-commit-config.yaml`, and the configs of markdownlint, yamllint, shellcheck and
    gitleaks;
  - the licensing files: `REUSE.toml`, `LICENSES/`, `LICENSE` and REUSE's `*.license` files;
  - every config the realm's own tools read in the product's CI.
- §9.5: a config name MUST be matched anywhere in the leaf, not only at its top folder.
- §9.5: when the leaf has no `main` to compare with, the rung MUST fail.
- §9.4: the shared protected list (`devcontainer/checks/protected-common`) is one of the shared check scripts.
  `check-repos.sh --check shared` MUST fail when the realms' copies differ.

## Modified

- §9.5 rung 1 (realm-readiness delta): "the paths that the ladder refuses to let a task change MUST include
  `.github/`" becomes the protected files above.

## Removed

None.
