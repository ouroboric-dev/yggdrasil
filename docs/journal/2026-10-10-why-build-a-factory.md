---
date: 2026-10-10
tags: [purpose, scope]
status: open
post-candidate: yes
evidence: [../specs/2026-10-11-yggdrasil-v0-design.md#2-goals-non-goals-and-success-criteria]
---
## Challenge
Build a "software factory" based on harness, loop and graph engineering, with no prior experience
of building one, and without knowing how generic it could be. Targets: games, SaaS, web apps,
eventually mobile.

## Context
The goal is learning: becoming an expert who can build factories specialised per use case. Shipping
products, or selling the factory, are ways to measure success, not the goal itself. Quality was
expected to need several iterations.

## Options
- **Generic from day one:** one factory for every product type. Maximum ambition, but the generic
  core would be guessed before any real pipeline exists.
- **Narrow first, extract later:** build one or two narrow pipelines and pull out what turns out to
  be shared.

## Decision
Narrow first. Build web SaaS and browser game pipelines side by side, with mobile later, so the game
pipeline shows early where "generic" stops being true. Success for v0 is two small builds plus
factory metrics that work as benchmarks.

## Result
Pending: the v0 builds.

## Lessons
State the real goal before choosing an architecture. "Learning" and "shipping" lead to different
designs: learning favours building the fundamentals yourself and measuring everything.
