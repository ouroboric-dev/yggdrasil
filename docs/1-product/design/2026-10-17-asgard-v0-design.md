---
title: Asgard v0 design doc
status: accepted
date: 2026-10-17
related: [../charter.md, ../roadmap.md, 2026-10-11-yggdrasil-v0-design.md]
style: direction
---

# Asgard v0 design doc

| | |
| --- | --- |
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
| --- | --- | --- | --- |
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
| --- | --- | --- | --- | --- |
| 1 | **Intent** | what she wants to do and why; her time, money, country; solo or with a partner | intent notes in `5-research/` | — |
| 2 | **Customers and offer** | who her clients are, the moment they need her, what she sells and roughly for how much | customers, offer and a competitor brief (the agent researches) | — |
| 3 | **Charter** | edits the agent's draft from steps 1–2 | vision, mission, principles, products, north star, boundaries | **`charter`** |
| 4 | **Name** | the name | domain, handle and trademark screening; the placeholder replaced everywhere; her GitHub organisation created | — |
| 5 | **Brand: words** | personality, how she sounds | positioning line, tagline, short pitch, about text, voice guide | — |
| 6 | **Brand: look** | taste: her logo concept, then reactions and choices between options, in seven sub-steps (below) | logo design, light and dark palettes with checked contrast, typography by role with checked licences and glyph coverage, imagery guidelines, foundations, a playground she settles the system in, design tokens, the board, the first applications and the reference | **`brand`** |
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

#### Step 6 in seven sub-steps

*Amended 2026-10-28 by the change proposal [Asgard's design system process](../../2-engineering/changes/2026-10-27-asgard-design-system/proposal.md).*

Step 6, **Brand: look**, runs as seven sub-steps, in this order. The logo's design is settled first, because the rest
of the system is built around it. Every sub-step works the same way: the agent proposes valid candidates by a stated
method, checks them before showing them, and shows them side by side in light and dark with the company's own name
and words; the founder reacts and chooses, and may mix and match; each choice records its reason in the decision log.
Every page that offers a choice **saves** it: the founder confirms her choice on the page, with a reason if she has
one, and the agent reads it from there; a choice that lives only in her browser, or that she must copy and paste, is
a defect. Facts shown about a candidate (a typeface's weights and italics, its licence, the languages it covers) come
from the source when the page is built, not from the agent's memory. An export carries the checks still open, so a
choice that fails a check cannot travel as if it passed.

Checks support the founder's decision; they do not make it. It is her company. When a choice fails a check, the page
says so plainly, with what it costs; she may keep it. A kept failure becomes an **accepted exception**: the check, her
reason and the date, in the decision log and in `tokens.json` (`accepted`). The company's check then reports it as
accepted, not as a failure, and does not stop the build; readiness lists every accepted exception, so a reviewer sees
it. An exception names one check on one value: changing the value reopens the check.
The methods of the pages Ouroboric used for its own typeface and logo choices are the starting point, not the limit.

**6a Logo design (first).** The founder brings an initial concept: her own logo in any format and any quality, a
sketch, or an image from a generator. The agent prepares it (cut out, flat background removed, resolution raised),
then critiques it plainly: legibility at small sizes, how it reads in light and dark, distinctiveness in her trade,
irregular geometry, and lettering that is not a real typeface. The critique names the **mark**: the part that stands
alone as the favicon and icon, which may be only a piece of the concept (a symbol inside the name). It offers two to
four alternatives: the concept as drawn and cleaned, a refined version, and one or two variations that explore the
idea further. They are shown as Ouroboric's logo page shows them: each proposal in its own panel, panels side by side
where the screen allows, identical in order and parts, each with a plain Strength and Risk (with the size at which it
fails, if it does); the logo at 16, 24, 32 and 48 pixels in a light and a dark row; the mark at 16, 32 and 64 pixels
with an enlarged 16, also in a light and a dark row.

When the concept has lettering, the lettering is part of the logo's look, most of all where the mark and the name are
one piece. The page then has a **lettering picker**: candidate typefaces chosen for the voice's personality words,
with open licences, in two groups, *serious* (calm and clear, they hold up at any size) and *stylised* (more
character, more care at small sizes); picking one redraws every alternative in it. The agent checks every pairing of
alternative and typeface before showing it, and a pairing that does not work (a symbol that does not fit the face's
letters, a join it breaks, a detail lost at small sizes) carries a visible note on its panel instead of being hidden.

The founder chooses one alternative and one typeface. What she chooses is the logo's **design**: its shapes and their
composition. Its colours come from the palette (6b) and change with it. Its lettering is the wordmark: the typeface
picked here becomes the starting face of the typography's wordmark role (6c), where it can still change.

**6b Palette.** Presets first: two to four named palettes seeded from the founder's mood words (step 5), the colours
of her logo concept, a colour she already uses, and her references, each with light and dark versions and checked
before it is shown. Then per role: every colour token (background, surface, border, text, muted, accent, the text on
the accent, and the message colours) can be changed on its own, from candidate values the agent proposes for that
role, or freely; changing any role turns the preset into "Custom". The logo is shown recoloured throughout. After
three rounds without a choice, the agent asks what is missing instead of offering more. The message colours are toned
to the palette and kept off the brand board.

**6c Typography, the wordmark included.** (The wordmark role starts at the typeface picked in 6a.) Criteria, in order:
the voice's personality words; legibility at interface sizes; every glyph of the clients' languages; the weights and
italics each role needs; an open licence that allows web use and self-hosting. Candidates come from an open library as
named presets ("looks": a pairing with a one-line character), each a starting point; every role has its own picker among
valid candidates, and changing any role turns the look into "Custom". Roles come in two groups, each with its job, where
it appears and how often it is seen: *character* faces (the **wordmark**, display, initial) and *system* faces (heading,
body, interface), with mono and ornament where the company needs them; the rarer the role, the more character it can
afford. The wordmark role sets the company's name in the logo wherever the logo has lettering. An "In use" view shows
the look in light and dark with a fact card per role (family, weights, licence), and a "Contexts" view shows it where
people meet the company (its social profile and posts, a link preview in a chat app, an email, a page of its website),
noting where its own fonts cannot reach. A five-second test flashes each look without its label and reveals the labels
at the end. Four lessons from Ouroboric's own choice apply: think in roles; check that the body face has bold and
italic; check where a style's label comes from; show candidates where people meet the brand, not only in a specimen.

**6d Imagery.** The guidelines (what images look like, never look like, how they are used), and up to six sample
images with their consent records.

**6e Foundations.** Each foundation offered as a few valid candidates for the founder to react to, proposed from the
typefaces and the voice: the type scale (base size and ratio, line heights per role, a minimum body size), spacing,
corner radius, elevation, motion (with reduced motion), breakpoints, and interaction states (focus, hover, active,
disabled). Every candidate is shown, not described: a foundation that cannot be seen on a still page gets a
view that shows it, such as motion played side by side on a loop (and still where the device asks for reduced
motion), or breakpoints as a ruler of screen widths with the layout in each range, the usual devices marked and a
width slider.

**6f Playground.** An interactive prototype of the whole design system on fake content, where the founder sees and
adjusts everything together before it is final. It is a prototype for looking, not a website.

- **Content:** a few page sections (navigation, a hero, a grid of images, an about block, service cards, a contact
  block, a footer) and every component of the system: buttons, links, fields, cards, messages, navigation, image
  treatments, icons, and the focus, hover, active and disabled states; the type scale and the foundations; light and
  dark.
- **Adjustable, by mixing and matching valid candidates the agent proposes:** every palette role (presets and per
  role, as 6b); every typography role, the wordmark included (as 6c); every foundation (as 6e); and each component's
  variants (for example a filled, outlined or soft button; a flat or raised card; a framed or borderless image).
  New candidates can be added to the playground when the founder asks for something none of them gives.
- **Fixed:** the logo's design (6a). It follows the palette live, and its lettering follows the wordmark role.
- **Live checks:** the company's checks run as she changes anything. A pair under its contrast minimum, a focus
  indicator under 3:1, a body size under the minimum, or a typeface without the weights or italics its role needs
  shows a visible warning next to what it affects, and in a list of every open check. The playground and the
  company's checks share one rule set, so they cannot disagree.
- **Export:** the founder's final settings are saved where the agent reads them, as every choice page saves its
  choice: a token file with the checks still open. The agent applies it, and the company's own checks then decide.

**6g Board and applications.** Generated only from the playground's saved settings, nothing chosen by hand: the
brand board, and the first applications (a square social profile picture from the mark, a link preview image, an
email signature). The board shows logo usage too: clear space (the mark's width on every side, for a logo built
around its mark), the minimum sizes of the logo and of the mark, and the misuses; and the kept exceptions with their
reasons.

6g also writes the **reference**: the design system as products will build it, so a product starts from the
founder's look and a check can prove it stayed there. In `identity/reference/`, generated from the saved settings
and never edited by hand: a component stylesheet (each component variant she chose, built from the tokens, with its
states); the final playground as one self-contained page, without saving; and screenshots of that page in light and
dark at phone, tablet and desktop widths. The stylesheet and the tokens are what products and checks read; the
screenshots are for people reviewing and for agents that read images, and are made again whenever the settings
change.

The `brand` stop approves the board, after the founder has settled the system in the playground.

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
| --- | --- | --- | --- |
| Direction | charter, roadmap | yes | — |
| Business | customers, offer and pricing, first customers | — | yes |
| Research | intent notes, competitor brief, name checks | name checks | yes |
| Founders | founders' agreement (two founders only), decision log | — | yes |
| Admin | entity and admin checklist (legal form, tax, bank, invoicing, bookkeeping, insurance), budget | budget | checklist |
| Legal | client terms (service agreement, usage licence, model release), client data (what, where, how long) | — | yes |
| Assets | accounts inventory: each account, its owner and where its recovery details are kept (never the details themselves) | — | yes |
| Brand | story, messaging, voice guide, imagery guidelines, identity (palette, typography with its reason, logo, foundations, tokens, applications) | story, identity | messaging, imagery, foundations, applications; voice filled, not empty |
| Record | journal, readiness assessments | yes | — |
| Agents | `AGENTS.md` with invariants from the charter's principles | yes | — |

The identity's foundations are a type scale, spacing, radius, elevation, motion, breakpoints and interaction states,
as tokens and as sections of the identity page. `tokens.json` gains `type.scale` (filled), `space`, `radius`,
`elevation`, `motion`, `breakpoints` and `focus`, and the clients' languages that the glyph check reads. It also
holds the `accepted` exceptions of step 6.

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
- **Brand checks** run as scripts: contrast between palette pairs in both light and dark mode, font
  licences, glyph coverage of every shipped font for the clients' languages, the minimum body size, the
  focus indicator's contrast and the presence of the foundations. A failure the founder keeps becomes an
  accepted exception, listed in readiness (§6.1, step 6).
- **The design system's items** replace RB-21 at level 1:

  | ID | Question | Check |
  | --- | --- | --- |
  | RB-21 | Is the identity defined: logo and mark in light and dark, a palette whose pairs pass WCAG 2.2 AA in both modes? | auto + human |
  | RB-22 | Is the typography chosen for every role, the wordmark included, with its reason, under a licence that allows web use, covering every glyph of the clients' languages? | auto + human |
  | RB-23 | Are the foundations set as tokens: type scale with a minimum body size, spacing, radius, elevation, motion, breakpoints? | auto |
  | RB-24 | Are interaction states defined, with a focus indicator that reaches 3:1, and is reduced motion honoured? | auto + human |
  | RB-25 (product) | Does the product's theme come from the company's tokens, through the token contract, and does its styleguide match the company's reference? | auto |

  RL-06 (level 2) grows to the full visual identity: the component baseline (buttons, links, fields, cards,
  messages) in both modes, an icon set with its licence, logo usage rules (clear space, minimum size, misuse)
  and the brand's applications.
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
