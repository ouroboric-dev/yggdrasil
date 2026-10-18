---
title: Asgard v0 design doc
status: accepted
date: 2026-10-17
related: [../charter.md, ../roadmap.md, 2026-10-11-yggdrasil-v0-design.md]
style: direction
---

# Asgard v0 design doc

| | |
|---|---|
| **Author** | Bruno Valério, with Claude Code (Opus 5.5), from a brainstorming session held 2026-10-17 |
| **Within** | the [charter](../charter.md), as amended to admit the Asgard realm (§5.3); a new roadmap step (§5.3) |
| **Engineering spec** | to be written after this design doc is accepted |
| **Process** | tier 3, [spec-driven development](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/4-ways-of-working/spec-driven-development.md) |

**Note added 2026-10-18** (the [Ginnungagap and Voluspa design doc](2026-10-18-ginnungagap-design.md),
§8.3 and §9): Asgard's kickstart graph is now named **`kickstart`**, because Ginnungagap became the
realm that creates realms. The readiness check script of §8 is `ygg readiness`, built once for Asgard
and Ginnungagap, and it keeps the offline rules of §8. The text below keeps the old name.

## 1. Summary

Asgard becomes a **realm of Yggdrasil**: the realm that kickstarts companies and products (tier 0).
Its kickstart graph is **Ginnungagap**. v0 builds everything that graph will need except the graph
itself: a guided **user journey**, the **templates** of a company umbrella, the **skills** an agent
follows at each step (in Havamal, with evals), and the **scripts** that scaffold, rename, check it
and turn a logo into usable files. A person and an interactive agent use them by hand, as Ouroboric was
built before the factory existed.

v0 proves itself when a **real, non-technical founder**, a self-employed photographer, uses it to
create her company's documentation: what the business is, its brand and its basics, checked ready to
build, and a charter for each of her three products. Yggdrasil then builds those products from that
documentation, starting with the client gallery.

## 2. Why

- **Ouroboric's kickstart had no journey.** The founder had to supply the structure by hand. The
  result is good, but nobody else could repeat it.
- **Yggdrasil can't build the right product without the company behind it.** It needs the charter,
  the look and feel, the voice and the logos before it can build a product that fits.
- **Starting a company should be open to anyone.** The long-term goal is to make company and software
  creation accessible to people who have never opened a terminal. v0 tests that with a real founder,
  not a simulated one.

## 3. Goals, non-goals and success criteria

### 3.1 Goals

v0 must:

- **Guide a founder from intent to "ready to build"** through a written journey of nine steps (§6)
  that a non-technical founder can complete with an agent.
- **Give every company the same shape:** a company umbrella template (§7) that keeps Ouroboric's
  structure as the minimum and adds what a company of one or two founders needs.
- **Produce documentation Yggdrasil can use:** a charter, an offer, brand tokens, logo files, a voice
  guide and imagery guidelines, in files the web realm can read.
- **Kickstart her products:** an accepted product charter for each of her three products, the
  portfolio page, the client gallery and the gallery manager, each conforming to her company
  charter.
- **Turn her logo into usable files:** scripts that take the PNG she brings and produce SVG logos,
  favicon and app icons, in light and dark versions.
- **Check readiness with evidence:** a script that checks the readiness items marked "auto" (§8),
  which nobody checks today.
- **Ship the kickstart skills in Havamal:** the agent instructions for each journey step are our own
  skills, each with an eval that shows it measurably improves the agent's work (Yggdrasil spec §5.1).
- **Prepare the graph:** every journey step has defined inputs, outputs, an approval rule and safe
  re-runs, so it maps onto a Ginnungagap node later without redesign.
- **Learn from the first run:** every time the founder needs help is recorded and becomes an
  improvement (§9).

### 3.2 Non-goals for v0

- `graph.yaml`, `pack.yaml` and any Odin integration (§10 lists what Yggdrasil needs later).
- Hiring, org charts and the structure of larger companies.
- Readiness levels 2 and 3 in practice. The checklist keeps them; v0 exercises level 1 only.
- Documentation in languages other than English (§6.2).
- Creating the logo. She makes it outside Asgard, with a tool or a designer of her choice, and brings
  it as PNG; Asgard processes it (§8).
- Buying domains, opening accounts, or registering anything on the founder's behalf.
- Building her products. v0 ends with the three accepted product charters. Each product's design
  doc is the web realm's first step, and the builds come after Yggdrasil v0, outside both v0s.
  Yggdrasil v0's Phase 6 proof runs stay on the frozen benchmark brief.

### 3.3 Anti-goals

v0 fails, even if every file exists, if:

- **Asgard decides for the founder.** It drafts, asks and checks; she chooses.
- **The founder meets jargon.** She reads "what your business is for", not "charter: vision and
  mission".
- **Anything presents itself as legal advice.** Legal material is scaffolded and flagged for a
  qualified person.
- **Ouroboric's own content leaks into the templates:** its charter text, Norse naming, factory
  budget or AGPL licensing.
- **The journey works only with the founder's helper at the keyboard.**

### 3.4 Success criteria

1. The photographer completes steps 1 to 9 (§6) and the product kickstarts up to three accepted
   product charters: portfolio page, client gallery and gallery manager. Her company umbrella passes the readiness check script for every company-level "auto"
   item at level 1 (§8), and she has judged every "human" item.
2. She gives every approval herself (charter, brand, readiness), by her own action, recorded with her
   name and date.
3. Every intervention by her helper is logged with its step and its cause, and each one becomes a
   backlog item, a journey change or a checklist item. v0 sets no target count: like the hidden
   score in Yggdrasil v0, it is a measurement, not a gate.
4. Her umbrella holds the brand in files: design tokens (JSON and CSS) with light and dark palettes,
   SVG logos in light and dark versions with a favicon, a voice guide and imagery guidelines, ready
   for the web realm.
5. Every kickstart skill passes its eval in Havamal's eval harness before the photographer's run.
6. The readiness check script, run on the Ouroboric umbrella, agrees with its
   [hand-written assessment](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/1-company/readiness/2026-10-11-ready-to-build.md),
   or each disagreement is explained.
7. Each significant challenge has a journal entry.

## 4. Context and constraints

- **A realm of Yggdrasil.** Asgard runs on Odin and has no engine of its own.
- **Built by hand** (self-hosting stage 0): a person and an interactive agent, following spec-driven
  development.
- **Licences:** MIT for the templates copied into companies, AGPL-3.0 for scripts, CC BY 4.0 for docs.
  What the founder produces is hers.
- **Founder capacity:** one person builds both Yggdrasil v0 and Asgard v0. Timing follows (§11).
- **Cost:** the Ouroboric budget covers building Asgard, not the photographer's own use of it (the
  budget's scope excludes operators). In v0 her sessions, and the later Yggdrasil runs that build
  her products, run on her helper's machine and subscription, by the helper's choice, under the same caps. Her
  budget document records this.
- **Machines:** her helper's WSL machine, or a shared MacBook with Podman. The journey itself needs
  only the agent chat app, so it must work on both.

## 5. Asgard as a realm

### 5.1 Tiers and realms

A **tier** is how much process a piece of work gets. A **realm** is a recipe for one kind of thing.
Each realm implements the tiers it needs as graphs. No realm has a tier 0 graph yet; Asgard adds it.

| Realm | Tier 0: kickstart | Tiers 1–2: fix, change | Tier 3: initiative |
|---|---|---|---|
| **Asgard** (direction) | Ginnungagap (v0: by hand) | later: amend a charter or a brand | — |
| **Web** | — | the change graph (later) | the web graph (Yggdrasil v0) |
| Game, mobile | — | later | later |

For the photographer: Asgard kickstarts her company, then each of her three products: the portfolio
page, the client gallery and the gallery manager (a product charter each, conforming to the company
charter). The web realm then takes each product from design doc to built software, reading the brand
from the company umbrella.

### 5.2 The leaf

The `asgard` repository changes from a product umbrella into a leaf of the `yggdrasil` umbrella,
next to the web realm's leaf. It keeps its history and its links.

- It holds the journey, the templates, the scripts and the checks.
- The kickstart skills live in Havamal, the skill library, with their evals, like every skill of
  our own.
- Following the [docs standard](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/4-ways-of-working/docs-standard.md#2-leaf-template),
  it keeps only `README.md`, `AGENTS.md` and `docs/architecture.md` as docs. Direction (this design
  doc, the spec and the plan) lives in the `yggdrasil` umbrella.
- Its `AGENTS.md` carries Asgard's three principles as invariants: direction is human; readiness is
  evidence; Asgard is not a lawyer.
- Wiring it in as a submodule waits until Yggdrasil v0 ships, so the v0 plan isn't disturbed.
- Its name stays `asgard` until the realms' naming convention is decided (§10).

### 5.3 Direction changes that come first

These go through the `charter` approval point before this design doc is accepted:

- **Yggdrasil charter:** the "narrow first" boundary admits the Asgard realm, as the tier 0 realm
  every product starts from. Yggdrasil v0's scope does not change.
- **Yggdrasil roadmap:** a step for Asgard v0.
- **Ouroboric charter and docs:** the portfolio shows Asgard as a realm of Yggdrasil, not a second
  factory; the company roadmap, the naming table, the docs standard's examples, the README and the
  diagrams follow. Dated records (the 2026-10-11 readiness assessment, journal entries, research)
  stay as written. The repository scripts (`check-repos.sh`, `setup-repo.sh`) change with the
  submodule wiring after Yggdrasil v0 (§5.2), not before.
- **Spec-driven development §3.1:** tier 0 gains the nine steps and the `brand` stop (§6.1).
- **Asgard's product charter** is marked superseded, not deleted.

## 6. The user journey

### 6.1 The steps

Each step feeds the next: the business comes before the brand, and the name comes once the business
is understood.

| # | Step | The founder describes or decides | Output | Stop |
|---|---|---|---|---|
| 1 | **Intent** | what she wants to do and why; her time, money, country; solo or with a partner | intent notes in `5-research/` | — |
| 2 | **Customers and offer** | who her clients are, the moment they need her, what she sells and roughly for how much | customers, offer and a competitor brief (the agent researches) | — |
| 3 | **Charter** | edits the agent's draft from steps 1–2 | vision, mission, principles, products, north star, boundaries | **`charter`** |
| 4 | **Name** | the name | domain, handle and trademark screening; the placeholder replaced everywhere; her GitHub organisation created | — |
| 5 | **Brand: words** | personality, how she sounds | positioning line, tagline, short pitch, about text, voice guide | — |
| 6 | **Brand: look** | taste: reactions to a moodboard, choices between options | imagery guidelines, light and dark palettes with checked contrast, fonts with checked licences, her logo turned into light and dark SVGs, design tokens | **`brand`** |
| 7 | **Business basics** | facts only she knows | founders' agreement (two founders only), admin checklist, accounts inventory, budget, client terms, client data; legal items flagged for a qualified person | — |
| 8 | **Roadmap** | which product comes first | the company roadmap | approved at the `brand` stop |
| 9 | **Readiness** | judges the human items | a level 1 assessment: the script checks the auto items | **readiness** |
| → | **Product kickstarts** | what each product is for | a product charter for the portfolio page, the client gallery and the gallery manager (v0 ends here); the web realm writes their design docs after v0 | `charter`, one per product |

- **Before step 1, she opens her own GitHub account,** with her helper beside her and a short guide.
  It is hers from the first minute. In v0 the agent chat app runs on her helper's subscription
  (§4).
- **Step 1 scaffolds silently.** Its first action creates the company umbrella from the template, as
  a private repository in her own GitHub account under a neutral placeholder name. Her company
  repositories stay private. Documents say "the company" until step 4.
- **Step 4 renames.** A script replaces the placeholder in every file and folder; the repository is
  renamed and moved into her new organisation. Renaming is mechanical and does not reopen the
  charter approval.
- **Asgard stays outside her repository.** The agent reads the journey and scripts from the Asgard
  leaf and the skills from Havamal, each at a pinned version, and her umbrella records those
  versions. Only the templates are copied in.
- **Step 7 runs alongside steps 5 and 6.** It depends only on the charter.
- **Sessions, not one sitting.** Steps 1–3 end with an accepted charter, steps 4–6 with a brand,
  steps 7–9 with readiness.
- **Every step can be re-run.** Re-running a step redrafts its outputs from its inputs and keeps
  what the founder already approved unless she reopens it.

The `brand` stop is new. Spec-driven development today approves the brand seed together with the
charter. For a company whose look is half the business, taste deserves its own stop after the
business is settled. Spec-driven development §3.1 changes to match.

### 6.2 For a founder who has never used a terminal

- **She talks; the agent does the mechanics.** She never types a command, reads a diff or uses git.
  She works in an agent chat app that works on her repository without a terminal; the spec picks
  which.
- **She reviews rendered pages,** never raw files: the charter as a readable page, and a **brand
  board** that shows palette, fonts, logo and sample images together.
- **Her approval is her own action,** recorded with her name and date. Her helper never approves for
  her: "direction is human" means her direction. In v0, approving is merging a pull request in the
  GitHub web page from her account. The agent's pull request already sets the document's status to
  `accepted` and links the rendered page; her merge makes it true. Her `main` branch is protected
  (changes only through pull requests), and GitHub push protection scans for secrets, so nothing
  needs a terminal.
- **She owns everything:** her GitHub organisation, domain and accounts. Her helper is a
  collaborator at most. No Ouroboric identity, including `ouroboric-pr-bot`, touches her repositories.
- **Plain words.** File names follow the docs standard, because agents need them; everything she
  reads uses plain words.
- **Language is her choice, asked once.** She can talk in any language. Company docs are English in
  v0. Words her clients read (tagline, pitch, about text, the voice guide's examples) follow her
  clients' language.

## 7. The company template

Ouroboric is the floor. The template keeps its structure without its content, and adds what a small
company needs. It has a **core** that every company gets and **add-ons**.

| Area | Document | From Ouroboric | New |
|---|---|---|---|
| Direction | charter, roadmap | yes | — |
| Business | customers, offer and pricing, first customers | — | yes |
| Research | intent notes, competitor brief, name checks | name checks | yes |
| Founders | founders' agreement (two founders only), decision log | — | yes |
| Admin | entity and admin checklist (legal form, tax, bank, invoicing, bookkeeping, insurance), budget | budget | checklist |
| Legal | client terms (service agreement, usage licence, model release), client data (what, where, how long) | — | yes |
| Assets | accounts inventory: each account, its owner and where its recovery details are kept (never the details themselves) | — | yes |
| Brand | story, messaging, voice guide, imagery guidelines, identity (palette, type, logo, tokens) | story, identity | messaging, imagery; voice filled, not empty |
| Record | journal, readiness assessments | yes | — |
| Agents | `AGENTS.md` with invariants from the charter's principles | yes | — |

**Add-ons:**

- **Builds with Yggdrasil** (on by default, since every Asgard company is a Yggdrasil company): the
  standards products inherit (spec-driven development, docs standard, writing styles, diagrams), the
  factory budget and caps, and the build items of the checklist. The standards are **linked, not
  copied**: her `4-ways-of-working/` holds one page that points to Ouroboric's standards at a pinned
  version, plus any rules of her own. Nothing Norse or Ouroboric-specific lands in her files, and
  nothing drifts.
- **Open source** (opt-in): licence map, contribution terms, trademark policy.

The founder's helper can turn add-ons on or off at step 1; the photographer gets core plus Yggdrasil.

## 8. Readiness

- **The checklist moves into the leaf** and gains an "applies to" column: core, Yggdrasil add-on or
  open-source add-on. Items for an add-on that is off are `n/a` with that reason.
- **Company items and product items split.** Step 9 checks the company items. The product items
  (today RB-02, RB-03, RB-18 to RB-20) are checked at each product's kickstart and before its first
  spec.
- **Items written around Ouroboric's own setup become general.** For example, RB-12 checks the docs
  standard with the check script, not `check-repos.sh`; RB-14 accepts GitHub push protection in
  place of a pre-commit hook; RB-20 is `n/a` for a product without a benchmark.
- **New level 1 items** cover the new core documents: customers and offer, founders' agreement (when
  there are two founders), admin checklist, accounts inventory, messaging, imagery guidelines.
- **The voice guide moves to level 1.** It is RP-01 (ready to promote) today, but the web realm needs
  the voice to write interface text, and Ouroboric's own voice folder is still empty.
- **A readiness check script** checks every "auto" item: the document exists, has the right status,
  and links its evidence. It works offline, on one umbrella's files: it never calls GitHub, and it
  reports links to other repositories as present but not verified. It writes the assessment's
  table; a person judges the human items. Its first fixture is Ouroboric, run against the checklist
  version Ouroboric's assessment used (success criterion 6).
- **Brand checks** run as scripts: contrast between palette pairs in both light and dark mode, and
  font licences.
- **Logo processing.** She brings her logo as PNG, made outside Asgard; one file, or one per mode.
  The journey asks for flat colours on a transparent background at high resolution, because tracing
  works best on those.
  A script traces it into SVG, recolours it with the palette tokens to make the light and dark
  versions (deriving the missing one when she brings one file), and exports the favicon and app
  icons. The brand board shows her PNG and the SVGs side by side, and she approves them at the
  `brand` stop. A trace that isn't faithful is logged as a gap, not hidden. The spec picks the
  tracing tool, which must have a licence that allows this use.
- **A logo at level 1** is the approved SVG in light and dark versions, plus a favicon. The full
  logo system and usage rules stay at level 2 (RL-06).

## 9. The acceptance run

The photographer runs the journey with her helper present. Every intervention is logged with the
step, what went wrong and what fixed it, in a run log. The Asgard leaf is public, so the run log
goes there anonymised and only with her consent; anything that identifies her or her clients stays
in her private repository.
After the run, each entry becomes a journey change, a template change, a checklist item or a backlog
item. That loop is what makes Asgard ouroboric: every late gap becomes a check for the next company.

## 10. What Yggdrasil needs later

These go into Yggdrasil's backlog. None is v0 work.

- Odin loads a realm from the Asgard leaf, as it loads the web realm.
- A realm whose output is documentation: no code leaves, no stack layer, a check ladder of document
  checks.
- Gate nodes a non-technical founder can approve.
- A naming convention for realm leaves; the current `realm-web` name may change.
- Running the factory on macOS with Podman, for the shared MacBook; v0 targets WSL2.

## 11. Timing

- **Now:** this design doc and the direction changes in §5.3.
- **After the web realm exists** (Yggdrasil v0 Phase 5): the spec, the plan and the build, so the
  Asgard leaf copies a real realm's conventions, not guessed ones.
- **During Yggdrasil v0 Phase 6** (proof runs): the photographer's run.

## 12. Decisions

- **Decided 2026-10-17:** Asgard becomes a realm of Yggdrasil, not a separate factory; its kickstart
  graph is Ginnungagap.
- **Decided 2026-10-17:** this design doc lives in the `yggdrasil` umbrella; the `asgard` leaf holds no
  direction.
- **Decided 2026-10-17:** v0 is the journey, templates and scripts, usable by hand; no graph.
- **Decided 2026-10-17:** the journey runs intent, customers and offer, charter, then name; the name
  comes out of understanding the business, so there is no separate naming step before it.
- **Decided 2026-10-17:** a real, non-technical photographer is the first founder; her helper assists;
  the goal is to make company and software creation accessible.
- **Decided 2026-10-17:** direction now; build after the web realm exists; her run during Phase 6.
- **Decided 2026-10-17:** language is the founder's choice; English assumed.
- **Decided 2026-10-17:** her company repositories are private.
- **Decided 2026-10-17:** v0, and the later runs that build her products, run on her helper's
  machine and subscription; she may later run on a shared MacBook with Podman.
- **Decided 2026-10-17:** the kickstart skills ship in Havamal, with evals, in v0.
- **Decided 2026-10-17:** v0 kickstarts all three of her products: portfolio page, client gallery and
  gallery manager.
- **Decided 2026-10-17:** she creates her logo outside Asgard and brings it as PNG; Asgard turns it
  into SVG. Logos and palettes come in light and dark versions.

## 13. Calls made while writing

The author made these calls while writing; the founder approved them on 2026-10-17.

- A separate `brand` stop after the charter (§6.1).
- Core and add-ons, with the Yggdrasil add-on on by default and its standards linked, not copied (§7).
- Her own GitHub account first; a private placeholder repository from step 1; approval by merging a
  pull request in the GitHub web page (§6).
- The voice guide moves to level 1; company and product items split (§8).
- The readiness check script works offline (§8).
- When she brings one logo file, the script derives the other mode's version from the palette (§8).
- The run log goes into the public Asgard leaf anonymised and only with her consent (§9).

## 14. Open questions

None at the design level.
