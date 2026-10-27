---
title: The firewall asks each name of the resolver that owns it
status: draft
date: 2026-10-27
related: [delta.md, tasks.md, ../../backlog.md, ../../specs/2026-10-25-local-models.md]
style: spec
---

# The firewall asks each name of the resolver that owns it

**Proposed 2026-10-27.** It fixes backlog [B-209](../../backlog.md). The shape below is a proposal; the founder
has not decided it. It changes a guardrail, the sandbox's egress firewall, so it needs the founder's approval.

## Why

- `gleipnir/sandbox/assets/egress.sh` takes the first `nameserver` line of `/etc/resolv.conf` as `ns`. The rules
  allow DNS to `ns` alone, and dnsmasq forwards the services' names to `ns`.
- The firewall joins up to three networks: `default` (the route out), `services` (internal) and the model server's
  network (internal, external to the project). Each network's resolver is aardvark-dns on its gateway. With the
  model network joined, the first nameserver is often an internal network's.
- Outside names then resolve only because aardvark-dns forwards them on an internal network. If a later netavark
  stops forwarding there, every refresh fails closed ("keeping the earlier addresses") and the sandbox loses its
  hosts as their addresses change. LM-T06's integration test proves today's forwarding.
- The fix the backlog names ("take the resolver of the network that carries the default route") is not enough on
  its own:
  - the script's own lookups use `getent`, which asks every nameserver of `/etc/resolv.conf` in order. With the
    rules allowing one resolver, a lookup first waits out a dropped query to the internal one;
  - the services' names and the model server's name are those of containers on the internal networks. Whether the
    default network's resolver answers them is not proved.

## What changes

1. **Outside names go to the default network's resolver.** `egress.sh` finds the interface of the default route,
   and takes as `ns_out` the nameserver inside that interface's subnet. It refuses to start when there is none.
2. **Container names go to the resolver of their network.** For each internal network the firewall is on, the
   nameserver inside its subnet answers the names of the containers on it: the services on `services`, the model
   server on its network. dnsmasq forwards each such name to that resolver.
3. **The script's own lookups ask the chosen resolver directly**, not through `/etc/resolv.conf`'s list, so a
   lookup never waits on a dropped query and never reaches a resolver the rules do not name.
4. **The rules allow DNS to exactly those resolvers**: `ns_out`, and the resolver of each internal network the
   firewall joined. Nothing else changes: deny by default, 443 to the listed hosts' addresses, the listed service
   ports, the redirect of every other process's DNS to dnsmasq.

## Not in this change

- The DNS-only channel out that aardvark-dns's forwarding gives a container on an internal network, such as a
  service container. This change stops the firewall depending on that forwarding; it does not close it. It is
  backlog B-216.
- IPv6 resolvers. The firewall resolves and allows IPv4 alone, as today.

## Impact

- **Repos:** `gleipnir` (`egress.sh`, the integration tests), `yggdrasil` (spec, backlog, pointers).
- **Approval points:** none.
- **Guardrail:** the egress firewall. The change narrows what the script depends on and what DNS it allows; it
  opens nothing new. The proof is `TestIntegrationModelNetwork` and the services test on the real engine, with a
  probe that the firewall's lookups reach only the resolvers the rules name.
- **Risk:** a resolver that answers names the proposal assumes it does not (or the reverse) would break the
  services or the model server by name. The first task proves which resolver answers which name before the script
  changes.
