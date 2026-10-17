---
title: Roadmap
status: accepted
date: 2026-10-12
related: [design/2026-10-11-yggdrasil-v0-design.md]
style: direction
---

# Roadmap

This roadmap sets the order of work, not dates. Each step has its own design doc or change proposal.

0. **Kickstart (tier 0):** charter, shape, brand seed, roadmap. Done retroactively on 2026-10-11.
1. **v0:** core (Odin, Gleipnir, Jormungandr, Gungnir), the web realms (`midgard-react`, `helheim-go`),
   metrics; builds client gallery
   lite and shows at least one measured self-improvement. Built by hand following the spec-driven
   development (SDD) process (self-hosting stage 0).
2. **Asgard v0:** the Asgard realm's kickstart journey, company template, kickstart skills (in
   Havamal) and scripts, used by hand; a photographer's company and her three products as the
   acceptance test. Its design doc is `design/2026-10-17-asgard-v0-design.md`.
3. **Iteration 2:** GitHub remote, bot identities and tracker. Then candidates, chosen by what v0's
   runs measure: terminal UI; OpenTelemetry export; a Next.js comparison flavor of Midgard (`midgard-next`); Spec Kit planning
   strategy; Ponytail cleanup job.
4. **Self-hosting stage 1:** Yggdrasil builds one of its own features. It requires the change graph,
   the Go flavor of Helheim (`helheim-go`) and the `guardrail-change` hard approval point, built first: the factory must not
   change its own code before any change to its guardrails stops for a human.
5. **Games realm (Jotunheim):** its own design doc and spec.
6. **Benchmark kit (Mimir):** its own design doc and spec; then self-hosting stage 2.
7. **Later:** the Ginnungagap graph on Odin (Asgard automation), parallel agents, deployment,
   the mobile realm (Muspelheim), promotion (Bragi).
