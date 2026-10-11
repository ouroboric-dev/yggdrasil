---
title: Charter
status: draft
date: 2026-10-11
related: [users.md, roadmap.md, design/2026-10-11-yggdrasil-v0-design.md]
---

# Yggdrasil charter

The highest-level direction for Yggdrasil. Every design doc must conform to it; a design doc that
doesn't stops for a human. Written retroactively on 2026-10-11 from the founding brainstorming
sessions (the kickstart, tier 0).

## Vision

Anyone can assemble a trustworthy software factory for their own use case: agents build, humans
steer.

## Mission

Build an open, modular and measurable software factory, and document every lesson of building it, so
others can build their own.

## Principles

1. **Humans approve direction.** Deviations from approved direction stop; building within it is
   automatic.
2. **Checks, not promises.** Readiness, conformance, test-first, isolation and drift are checked
   mechanically wherever possible. An agent saying "done" proves nothing.
3. **No lock-in.** Models, agent tools, sandboxes, state stores, remotes and trackers are swappable.
   State lives in files and git, where every agent can read it.
4. **Modular by contract.** A factory is a composition of components honouring the Gungnir contract;
   specialised factories are assembled, not rewritten.
5. **Measure everything.** Every run produces metrics usable as benchmarks; claims about the factory
   are backed by runs.
6. **Safe by default.** Agents run sandboxed with only the secrets they need; some approval points can
   never be switched off; cascades are designed against, not discovered.
7. **Ouroboric.** The factory documents itself the way it documents what it builds, and in time builds
   and improves itself, without ever weakening its own guardrails.
8. **Read before you borrow.** Learn from other projects freely; reuse their code only when the
   licence allows it.

## Users and problems

See [users](users.md). In short: operators who want to build software with agents without giving up
control, safety or the ability to measure what they get; readers following the journey; and other
factory builders comparing approaches.

The problems: agents left alone drift, grade their own work, and break things in ways that compound;
frameworks hide the parts worth understanding; and there is little shared, measurable ground for
comparing factories.

## North-star measures

- **Hidden acceptance score per unit of cost** (tokens, turns, dollars) on the benchmark set.
- **Human interventions per feature**, trending down without quality trending down.
- **First-pass rate**: features that pass their checks on the first attempt.
- **Escaped defects**: hidden tests failing where visible tests passed, trending to zero.

## Boundaries

- **Learning first.** Commercial use isn't a goal for now; shipping products and benchmarking are how
  success is measured.
- **Open source.** The factory becomes open source. Products it builds may be public or private, and
  hosted anywhere, at each operator's choice.
- **Narrow first.** Grow from specific realms (web SaaS, then games, then mobile) and extract what is
  truly shared; no "one factory for everything" up front.
- **Cost-conscious.** Start on a Claude subscription and free tiers; hard budget caps on every run.
- **Language and runtime:** Go; local first, cloud-ready through swappable interfaces.
