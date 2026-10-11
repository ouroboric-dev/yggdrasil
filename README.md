# Yggdrasil docs

Yggdrasil is an open-source software factory by [Ouroboric](https://github.com/ouroboric-dev). It's
a Go orchestrator that turns a written brief into verified software. It runs coding agents in
sandboxes, through loops and human approval points. Start with the [charter](docs/1-product/charter.md) and
the [v0 design doc](docs/1-product/design/2026-10-11-yggdrasil-v0-design.md).

| Folder | What's there |
|---|---|
| [`1-product/`](docs/1-product/charter.md) | direction: vision, users, roadmap, design docs |
| [`2-engineering/`](docs/2-engineering/specs/README.md) | living spec, specs, change proposals, plans |
| [`3-using/`](docs/3-using/README.md) | for operators (Diátaxis) and runbooks |
| [`4-ways-of-working/`](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/4-ways-of-working/spec-driven-development.md) | [spec-driven development](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/4-ways-of-working/spec-driven-development.md) and the [docs standard](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/4-ways-of-working/docs-standard.md) |
| [`5-research/`](docs/5-research/curation.md) | research briefs and curated sources |
| [`6-journal/`](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/6-journal/README.md) | the journey: challenges, solutions, results |
| [`7-branding/`](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/7-branding/README.md) | story, identity, voice, prompts, assets |

This repo follows its own [documentation standard](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/4-ways-of-working/docs-standard.md).
Every product that Yggdrasil builds uses the same standard.

## Licence

- **Code:** [AGPL-3.0](LICENSE). Anyone may use, change and share it. Anyone who distributes a
  changed version, or runs one as a service, must publish their source under the same licence.
- **Anything the factory copies into what you build** (realm templates, scaffolds, skills): MIT, so your
  products stay yours. Those files live in their own repositories (for example `realm-web`, `havamal`).
- **Documentation:** [CC BY 4.0](LICENSES/CC-BY-4.0.txt).
- **Names and logos** are not licensed: see
  [TRADEMARKS.md](https://github.com/ouroboric-dev/ouroboric/blob/main/TRADEMARKS.md).
- The file-by-file map is [REUSE.toml](REUSE.toml).

**What you build is yours.** Products you build with Ouroboric factories belong to you. Templates add
a "Built with Ouroboric" notice by default; please keep it, but you may remove it.
