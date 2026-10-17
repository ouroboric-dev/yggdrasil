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
Amended on 2026-10-17 to admit the **Asgard realm**, which kickstarts companies and products. It
takes over the direction of the superseded
[Asgard product charter](https://github.com/ouroboric-dev/asgard/blob/main/docs/1-product/charter.md).

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

Yggdrasil serves four groups (details in [users](users.md)): operators who want to build software
with agents without giving up control, safety or the ability to measure what they get; founders who
kickstart a company or a product through the Asgard realm, including people who have never used a
terminal; readers following the journey; and other factory builders comparing approaches.

It addresses four problems: agents left alone drift, grade their own work and break things in ways
that compound; frameworks hide the parts worth understanding; there is little shared, measurable
ground for comparing factories; and new ventures start building before they settle direction, legal
ground and brand, and pay for it later.

## North-star measures

- **Hidden acceptance score per unit of cost** (tokens, turns, dollars) on the benchmark set.
- **Human interventions per feature**, trending down without quality trending down.
- **First-pass rate**: features that pass their checks on the first attempt.
- **Escaped defects**: hidden tests failing where visible tests passed, trending to zero.
- **Late readiness gaps**: gaps found after building rather than before, trending down kickstart
  over kickstart, because every late gap becomes a checklist item for the next one.

## Boundaries

- **Learning first** (from the Ouroboric charter); we measure success by shipping products and
  benchmarking.
- **Open source.** AGPL-3.0 for the factory code, MIT for templates copied into the products it builds.
  Products may be public or private, and hosted anywhere, at each operator's choice.
- **Narrow first.** Grow from specific realms and extract what is truly shared; no "one factory for
  everything" up front. The Asgard realm kickstarts every company and product (tier 0); the build
  realms follow: web SaaS, then games, then mobile.
- **Direction is human, and Asgard is not a lawyer.** The Asgard realm drafts and checks; founders
  decide, and charter approval stops for a human in every mode. It scaffolds legal material and flags
  what needs a qualified person; it never presents its output as legal advice.
- **Cost-conscious.** Start on a Claude subscription and free tiers; hard budget caps on every run.
- **Language and runtime:** Go; local first, cloud-ready through swappable interfaces.
