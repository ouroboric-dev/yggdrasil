---
title: Documentation standard
status: accepted
date: 2026-10-11
related: [spec-driven-development.md]
---

# Documentation standard

One documentation template for **Yggdrasil and every product it builds**: the factory documents
itself the way it documents what it makes. Agents learn one map, and Odin's routing and docs checks
work the same everywhere.

## 1. Umbrella template

Every umbrella (the factory's `yggdrasil`, each product's project umbrella) uses this layout:

```
docs/
  README.md                landing page: what this is, and a map of the folders
  1-product/               DIRECTION (human-approved)
    vision.md, users.md, roadmap.md
    design/                design docs, dated
    legal/                 products: privacy, terms, data map, deletion process
  2-engineering/           HANDOVER AND BUILD
    system/                the living spec: how the system works today
    specs/                 specs (RFC-like), dated, not edited after acceptance
    changes/               change proposals with spec deltas
      archive/             merged proposals
    plans/                 implementation plans and tasks
  3-using/                 for users and operators (Diátaxis)
    tutorials/  how-to/  reference/  explanation/
    operations/            runbooks: install, upgrade, deploy, restore, rotate keys, incidents
  4-ways-of-working/       process: SDD, this standard, contributing, agent conventions
  5-research/              research briefs, curated sources
  6-journal/               challenges, solutions, measured results (the sagas)
  7-branding/              everything identity flows from
    story/                 naming, mythology, narrative
    identity/              logo system, icon, palette, typography: the design language
    voice/                 tone, vocabulary, messaging pillars, copywriting rules
    prompts/               image-generation and copy prompts
    assets/                source SVG and PNG files
```

The numeric prefixes order the rendered navigation. `3-using/` follows [Diátaxis](https://diataxis.fr/):
tutorials teach, how-to guides solve a task, reference describes, explanation gives the why.

## 2. Leaf template

```
README.md                  what the repo is, how to run it, where the docs are
AGENTS.md                  about 100 lines: a map into docs/, never a manual
docs/
  architecture.md          this repo's part of the system
  how-to/                  repo-specific tasks
  reference/               e.g. generated API docs from openapi.yaml
```

Direction, journal and branding live in the umbrella above the leaf.

## 3. Required and optional sections

| Section | Factory umbrella | Product umbrella | Leaf |
|---|---|---|---|
| `README.md` | required | required | required |
| `1-product/vision.md`, `design/` | required | required | — |
| `1-product/legal/` | optional (licence, contribution terms) | optional while in development; **required before `deploy-prod`** | — |
| `2-engineering/*` | required | required | — |
| `3-using/` | required once there are users | required once there are users | `how-to/`, `reference/` |
| `3-using/operations/` | required once operable | required before `deploy-prod` | — |
| `4-ways-of-working/` | required | inherits from the factory; may add rules | — |
| `5-research/` | optional | optional | — |
| `6-journal/` | required | optional (build in public) | — |
| `7-branding/` | required | required before a public launch | — |
| `AGENTS.md`, `docs/architecture.md` | — | — | required |

Folders without content yet hold a short `README.md` saying what belongs there.

## 4. How products differ

- **`1-product/`** describes the product's vision, users and competitors.
- **`1-product/legal/`** holds the privacy policy, terms, **data map** (every place personal data
  lives: database rows, object storage originals and derivatives, zips, preview databases, backups)
  and the deletion process. A product that stores people's photos or emails handles personal data;
  without a data map, a deletion request is guesswork, and a forgotten backup or preview branch can
  still hold the data. Reviewers raise a finding when a feature stores a new kind of personal data
  without updating the data map.
- **`7-branding/` is an input to the build.** Implementers read `voice/` for interface copy and
  `identity/` for design tokens (the palette and type become the Tailwind theme).
- **The journal is optional.** Lessons about the factory learned on a private product go to the
  operator's private instance first, and only anonymised summaries reach the public factory journal.

## 5. Conventions

- **Front matter on every doc:**

  ```yaml
  ---
  title: <title>
  status: draft | accepted | implemented | superseded
  date: YYYY-MM-DD
  related: [relative links]
  ---
  ```

  Journal entries use their own front matter (see `6-journal/README.md`).
- **File names:** dated for decisions and records (`YYYY-MM-DD-<slug>.md`: design docs, specs, change
  proposals, plans, journal); undated for living docs.
- **Decisions** inside any doc: `**Decided YYYY-MM-DD:** <decision>`.
- **Links:** relative within a repo; absolute URLs across repos.
- **Generated files** (`REPOS.md` wiring blocks, doc↔code, decisions indexes) say so at the top and
  have a `--check` mode that fails when they're stale.
- **Writing style:** short sentences, active voice, concrete examples, no undefined jargon.
- **Diagrams:** Mermaid or ASCII in Markdown, so they diff and render anywhere.

## 6. Docs are checked like code

A docs rung in every realm's check ladder:

- front matter present and valid;
- file naming and required sections per node type (§3);
- no broken links;
- a strict site build (once the renderer integration is in place).

As marola puts it, writing a doc is a deploy.

## 7. Rendering

- **Renderer: Zensical**, the successor to Material for MkDocs from the same
  team. It reads `mkdocs.yml`. Material for MkDocs is in maintenance mode, with security fixes only until
  about November 2026.
- **Stay renderer-agnostic:** plain Markdown, front matter, Mermaid. No renderer-specific syntax in the
  docs themselves, so switching renderers means a new config file, not rewriting docs.
- **Aggregation:** each umbrella's site includes its children's docs at their pinned SHAs, recursively
  down the tree (marola's `prepare-docs.sh` pattern). The site shows what has actually been validated.
- **Known gaps:** Zensical doesn't yet have every Material plugin (redirects, blog, RSS, social cards).
  When the blog arrives, choose between Zensical's blog support (if it exists by then) and a separate
  site.

## 8. Public repos

The journal's scrubbing rules apply to every doc in a public repo: no secrets, no private product
names or code, no client data, no raw transcripts or ledger excerpts from private runs.
