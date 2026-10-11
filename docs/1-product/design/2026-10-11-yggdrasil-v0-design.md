---
title: Yggdrasil v0 — design doc
status: draft
date: 2026-10-11
related: [../charter.md, ../roadmap.md, ../../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md]
---

# Yggdrasil v0 — design doc

| | |
|---|---|
| **Status** | Draft for review |
| **Date** | 2026-10-11 |
| **Author** | Bruno Valério, with Claude Code (Opus 5.5), from brainstorming sessions held 2026-10-10 and 2026-10-11 |
| **Within** | the [charter](../charter.md); milestone 1 of the [roadmap](../roadmap.md) |
| **Engineering spec** | [2026-10-11-yggdrasil-v0-spec.md](../../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md) |
| **Process** | tier 3, [spec-driven development](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/4-ways-of-working/spec-driven-development.md) |

## 1. Summary

v0 is the first working Yggdrasil: a factory that turns a written brief into working, verified
software by running coding agents inside sandboxes, through loops that check and fix their work and
approval points where a human decides direction.

v0 delivers the core (orchestration, harness, loop, contract), one domain recipe (web SaaS), and the
metrics needed to compare runs. It proves itself by building **client gallery lite** (§4) from a
one-page brief, at least once with a different model or agent tool.

## 2. Goals, non-goals and success criteria

### 2.1 Goals

v0 serves the charter's principles. Specifically, it must:

- **Prove the loop works end to end:** brief → design → spec → plan → build → verified product, with
  humans approving direction only.
- **Prove no lock-in:** at least one role runs on a different agent tool or model.
- **Prove it can be measured:** every run produces metrics usable as benchmarks.
- **Prove it is safe by default:** agents sandboxed, no unnecessary secrets, hard approval points.
- **Start the record:** keep the journal that later promotion will be written from.

### 2.2 Non-goals for v0

- Parallel agents (features run one at a time).
- A dashboard or terminal UI (v0 has a live status view and a board command).
- Pushing to GitHub, bot identities and the GitHub tracker (specified, built in iteration 2).
- Production deployment (the web realm is deploy-ready; deploying is outside v0).
- The game realm and the full benchmark kit (their own design docs).
- Mobile.
- Promotion and content: no posts, no blog, no content-generation component (future module Bragi).

### 2.3 Success criteria

1. The factory builds **client gallery lite** from its frozen brief, and the result passes rungs 1–6
   of the check ladder ([spec §9.5](../../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md#95-the-check-ladder)).
   The hidden suite (rung 7) is run and its score recorded; v0 sets no pass threshold, because the
   score is a benchmark result, not a gate.
2. The same brief is built at least once with a different agent tool or model for at least one role,
   for example the implementer on OpenCode with an OpenRouter model.
3. Every run produces a complete, hash-chained ledger, and `ygg metrics` reports the metrics in
   [spec §10.2](../../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md#102-metrics-ygg-metrics-runrange),
   including the hidden acceptance score.
4. All three autonomy modes ([spec §7](../../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md#7-approval-points-and-autonomy-modes))
   complete a run with the `scripted` adapter, and at least one real-agent run completes in
   key-points mode.
5. The escape-attempt tests ([spec §13](../../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md#13-testing-the-factory))
   pass.
6. Every significant challenge met during v0 has a journal entry
   ([spec §10.5](../../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md#105-journey-journal)) with
   its evidence links, and every factory change made in response to a run cites before/after runs from
   `ygg metrics --compare`.

## 3. Context and constraints

From the charter's boundaries, the ones that shape v0:

- **Targets:** web SaaS first (this milestone); browser games next; mobile later.
- **Models:** start on a Claude subscription; other providers (including OpenRouter) through the same
  adapters.
- **Runtime:** local first (WSL2, rootless Podman); cloud later.
- **Open source:** the factory will become open source; products may be public or private, at the
  operator's choice.
- **Built by hand:** v0 is built by a human with an interactive agent following the SDD process
  (self-hosting stage 0).

## 4. The demonstration product: client gallery lite

The first product Yggdrasil builds, and benchmark brief #1. A Pixieset Client Gallery–style SaaS.

- **Photographer:** sign up and log in; create galleries; upload many large photos (resumable, sent
  straight to storage); thumbnails and web sizes; cover photo; per-gallery password, download PIN and
  downloads on/off.
- **Client:** opens a private link; enters the password if set; responsive grid and full-screen
  viewer; favourites (no account, identified by email); single downloads (PIN if set) and
  download-all as a zip.
- **Photographer dashboard:** each client's favourites and download activity (who downloaded what,
  when).
- **Out of scope:** watermarks, comments, branding themes, video, translations, Lightroom sync, print
  store and payments, email campaigns.

It was chosen over a simpler task tracker because it carries real-world traps that agents often get
wrong, which make it a better benchmark: guessable gallery links, public storage buckets, GPS data in
photos, oversized images, and unthrottled PINs.

## 5. Decisions

- **Decided 2026-10-10:** narrow first, extract the generic core later; web SaaS and browser games
  side by side, mobile later.
- **Decided 2026-10-10:** v0 success is two kinds of evidence: a working product, and factory metrics
  that work as benchmarks.
- **Decided 2026-10-10:** autonomy is configurable (step-by-step, key-points by default, unattended);
  some approval points can never be switched off.
- **Decided 2026-10-11:** the first product is client gallery lite (§4).
- **Decided 2026-10-11:** GitHub integration, bot identities and the GitHub tracker come in iteration 2;
  v0 uses local git only.
- **Decided 2026-10-11:** v0 keeps a journal from day one; promotion comes later.

Engineering decisions are in the [spec's decision log](../../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md#18-decision-log).

## 6. Open questions

None at the design level. Engineering open items (the first spike) are in
[spec §16](../../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md#16-open-items-and-first-spike).
