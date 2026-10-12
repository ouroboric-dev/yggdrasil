---
title: Charter
status: accepted
date: 2026-10-12
related: [users.md, roadmap.md, design/2026-10-11-yggdrasil-v0-design.md]
style: direction
---

# Yggdrasil product charter

This charter sets direction for Yggdrasil, the software factory, within the
[Ouroboric charter](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/1-company/charter.md).
Every Yggdrasil design doc must conform to it; a design doc that doesn't stops for a human. It was
written retroactively on 2026-10-11 from the founding brainstorming sessions (the product kickstart).

## Vision

Anyone can assemble a trustworthy software factory for their own use case: agents build, humans
steer.

## Mission

Build an open, modular software factory that measurably improves with every run, and document every
lesson of building it, so anyone can run, adapt and trust their own.

## Principles

Yggdrasil follows the [Ouroboric principles](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/1-company/charter.md#principles).
It adds three product-specific principles:

1. **No lock-in.** Models, agent tools, sandboxes, state stores, remotes and trackers are swappable.
   State lives in files and git, where every agent can read it.
2. **Modular by contract.** A factory is built from components that honour the Gungnir contract.
   Specialised factories are assembled, not rewritten.
3. **Guardrails are part of the product.** Sandboxing, approval points and the escape-attempt suite
   are features, tested like any other, and never weakened by the factory's own changes.

## Users and problems

Yggdrasil serves three groups (details in [users](users.md)): operators who want to build software
with agents without giving up control, safety or the ability to measure what they get; readers
following the journey; and other factory builders comparing approaches.

It addresses three problems: agents left alone drift, grade their own work and break things in ways
that compound; frameworks hide the parts worth understanding; and there is little shared, measurable
ground for comparing factories.

## North-star measures

- **Hidden acceptance score per unit of cost** (tokens, turns, dollars) on the benchmark set.
- **Human interventions per feature**, trending down without quality trending down.
- **First-pass rate**: features that pass their checks on the first attempt.
- **Escaped defects**: hidden tests failing where visible tests passed, trending to zero.

## Boundaries

- **Learning first** (from the Ouroboric charter); we measure success by shipping products and
  benchmarking.
- **Open source.** AGPL-3.0 for the factory code, MIT for templates copied into the products it builds.
  Products may be public or private, and hosted anywhere, at each operator's choice.
- **Narrow first.** Grow from specific realms (web SaaS, then games, then mobile) and extract what is
  truly shared; no "one factory for everything" up front.
- **Cost-conscious.** Start on a Claude subscription and free tiers; hard budget caps on every run.
- **Language and runtime:** Go; local first, cloud-ready through swappable interfaces.
