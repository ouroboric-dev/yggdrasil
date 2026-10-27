---
title: Delta for the firewall's resolvers
status: draft
date: 2026-10-27
related: [proposal.md, tasks.md, ../../specs/2026-10-25-local-models.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: local models spec §3.7, v0 spec §6.2

## Added

- Local models spec §3.7, a new item: the firewall MUST ask outside names of the resolver of the network that
  carries its default route, and the name of a container on an internal network of the sandbox (a service, the
  model server) of that network's resolver. Its own lookups MUST go to those resolvers directly. It MUST allow DNS
  to those resolvers and no other.
- v0 spec §6.2, **Egress**, a sentence: the firewall's DNS MUST NOT depend on an internal network's resolver
  forwarding outside names.

## Modified

- Local models spec §9, item 5: it stays confirmed, and names this change as the rule that relies on it.

## Removed

None.
