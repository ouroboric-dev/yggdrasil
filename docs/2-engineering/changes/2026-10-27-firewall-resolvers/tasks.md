---
title: Tasks for the firewall's resolvers
status: draft
date: 2026-10-27
related: [proposal.md, delta.md]
style: spec
---

# Firewall resolvers: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first. Engine work only through `ouroboric/scripts/ygg-engine.sh run`. The founder approves the pull
> request: the firewall is a guardrail.

**Goal:** the firewall asks each name of the resolver that owns it, allows DNS to those resolvers alone, and no
longer depends on an internal network forwarding outside names.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `gleipnir`, the probe:** extend `refreshResolves` in `sandbox/integration_models_test.go` (it already
  logs the firewall's `resolv.conf` and each network's gateway) to record, for each resolver, whether it answers an
  outside host, a service's name and the model server's name. Write the result in the pull request. If the default
  network's resolver answers the container names, item 2 of the proposal shrinks to "one resolver for all", and the
  pull request says so.
- [ ] **T2 `gleipnir`, the failing tests:** on the real engine, with the services and the model network joined:
  every outside host, service and model server resolves in the work container; a refresh resolves; and the
  firewall's own lookups send no query to a resolver other than the ones the proposal names (read the packet
  counters of the DNS rules, and of a counting rule for DNS to any other address). The unit tests of the script's
  generated `dnsmasq.conf` (where they exist) name the resolver per name.
- [ ] **T3 `gleipnir`, the script:** `egress.sh` as the proposal says. Keep it POSIX `sh` and the tools the
  firewall image already holds; if a lookup tool is missing, the pull request names what it adds to the image and
  why.
- [ ] **T4 `yggdrasil`:** fold the delta, mark B-209 done, move the pointers, archive this folder.

## Open for the builder

- How to tell an internal network's resolver from its subnet when the firewall has two interfaces in the same
  range. If that can happen, `gleipnir` writes each network's name and subnet into the firewall's files instead.
