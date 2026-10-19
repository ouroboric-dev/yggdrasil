---
title: Voluspa name screening
status: draft
date: 2026-10-19
related: [../2-engineering/changes/2026-10-19-voluspa/proposal.md, ../1-product/design/2026-10-18-ginnungagap-design.md, https://github.com/ouroboric-dev/ouroboric/blob/main/docs/5-research/2026-10-12-name-checks.md]
style: research
---

# Voluspa name screening

The screening of the name `voluspa` for the graph library, asked for by the
[Ginnungagap and Voluspa design doc](../1-product/design/2026-10-18-ginnungagap-design.md) §8.2. It follows the
method of the company's [name checks](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/5-research/2026-10-12-name-checks.md)
of 2026-10-12, which live in `ouroboric`. This one lives here, beside the change proposal it serves. Everything
was checked on 2026-10-19. The trademark part is a web screening, **not a clearance search**.

## Forms screened

- `voluspa`: the form a repo, a Go module, a package or an image would use.
- `völuspá`: the Old Norse spelling. npm, PyPI, crates.io, Docker Hub and Homebrew allow only ASCII names, so it
  can't be a package name there. It was searched on GitHub and the web.
- `voluspa-cli` and the misspelling `volospa` on npm.

## Registries and GitHub

Each registry's public API, queried on 2026-10-19. "Free" means the lookup found no such name. Each lookup was
first tried with a name known to be taken (`yggdrasil` on npm, `asgard` on PyPI, `mimir` on crates.io,
`gleipnir` on Docker Hub, `odin` on Homebrew), and each answered "taken".

| Where | Lookup | Result |
| --- | --- | --- |
| npm | `https://registry.npmjs.org/voluspa`, `/volospa`, `/voluspa-cli` | free (404) |
| npm search | `https://registry.npmjs.org/-/v1/search?text=voluspa` | 2 packages, both under the scope `@voluspalabs` (see below) |
| npm scope | `https://registry.npmjs.org/-/org/voluspa/package` | 404; the endpoint may need a login, so a free `@voluspa` scope is unconfirmed |
| PyPI | `https://pypi.org/pypi/voluspa/json` | free (404) |
| crates.io | `https://crates.io/api/v1/crates/voluspa`, and a search for `voluspa` | free; the search finds no crate |
| Docker Hub | `https://hub.docker.com/v2/users/voluspa/`, `/v2/orgs/voluspa/` | free (404), unconfirmed (see below) |
| Docker Hub search | `https://hub.docker.com/v2/search/repositories/?query=voluspa` | 3 small repos: `ghostproxy/voluspa`, `andy92pac/voluspa`, `jalmeflo/voluspa-bot` |
| Homebrew | `https://formulae.brew.sh/api/formula/voluspa.json`, `/api/cask/voluspa.json` | free (404) |
| GitHub account | `https://api.github.com/users/voluspa` | taken: organisation `voluspa`, created 2014-01-13, 2 public repos, last push 2016-04-02 |
| GitHub, our org | `https://api.github.com/repos/ouroboric-dev/voluspa` | free (404) |
| GitHub repos | `https://api.github.com/search/repositories?q=voluspa+in:name` | 24 repos; the largest has 13 stars |

Method notes:

- The 2026-10-12 checks found that Docker Hub's `users` endpoint misses organisations and reserved names. The
  `orgs` endpoint was added here, but the Docker column's "free" is still unconfirmed. Ouroboric publishes images
  on GHCR only, so this does not matter for us.
- The GitHub repos are small personal projects: Destiny 2 Discord bots (Voluspa is an AI in that game's story), a
  Rust toy kernel, a Haskell game server, a university Go demo, and personal Kubernetes manifests. The
  `voluspa` organisation holds two dormant repos (`vilive`, `yggdrasil`). A search for `völuspá` finds 4 repos, the
  largest with 6 stars.

## Voluspa Labs

The npm search found two packages under the scope `@voluspalabs`: `env-vault` ("environment vault CLI and SDK")
and `env-vault-mcp` ("MCP server exposing the Voluspa Labs environment vault to agents"). Both were created on
2026-08-02, are marked `UNLICENSED`, and name no repository. `env-vault` had 49 downloads from 2026-09-17 to
2026-10-16 (`https://api.npmjs.org/downloads/point/last-month/@voluspalabs/env-vault`).

The GitHub organisation `voluspalabs` ("Voluspa Labs", created 2025-02-14, `https://api.github.com/users/voluspalabs`)
has 4 public repos with no stars: React components, utilities, a lint config and icons. Its site `voluspa.io` is
titled "Voluspa - Services, Research & Development". A web search for "Voluspa Labs" found nothing else.

It is the only software use of the name found, and it is in the same field: developer tools for agents.

## Trademarks

Web searches on 2026-10-19 found:

- **VOLUSPA, the candle and fragrance brand.** Flame & Wax, Inc. (Irvine, California, founded 1999) sells
  candles, diffusers and fragrances as Voluspa, through Sephora, Anthropologie and others. Justia's US trademark
  index lists, among others:
  - **VOLUSPA**, standard characters, registration 3078789 (serial 78493222), filed 2004-10-01, registered
    2006-04-11 and renewed, class 3: incense, perfumes, soaps, room sprays
    (`https://trademarks.justia.com/784/93/voluspa-78493222.html`);
  - **V EST. 1999 VOLUSPA**, design marks, registrations 5189853 (class 4, scented candles), 5189850 (class 3,
    fragrances and reed diffusers) and 5189854 (class 35, online retail of candles and fragrances), granted
    2017 (`https://trademarks.justia.com/871/62/est-1999-87162455.html`).
  - The owner's full list (`https://trademarks.justia.com/owners/flame-wax-inc-3388108`) refused the fetch (HTTP
    403). Its contents were read from search snippets only.
- **No VOLUSPA mark for software** (classes 9 or 42) turned up in a web search.
- **EUIPO and the EU:** no Voluspa record turned up in a web search.

What could not be checked:

- **TMview (EUIPO):** its search API did not answer from this machine (no HTTP response).
- **USPTO trademark search:** the site is a script-driven page, and its search API refused a direct query (HTTP
  405). The US results above come from Justia's index of USPTO data, not from the USPTO.
- **WIPO Global Brand Database:** the page loads (HTTP 200), but its results are drawn by scripts, so no result
  could be read.
- **The UK register:** a UK IPO journal page that a search linked to refused the fetch (HTTP 403).

## Analysis

[ANALYSIS] Voluspa is a common word from myth, like Havamal. Every package registry has the name free, and our
org has the repo name free. The factory needs no registry name: Voluspa ships as a Go module under
`github.com/ouroboric-dev/voluspa`, as the other components do.

[ANALYSIS] The best-known use is a consumer brand of candles and fragrances, with registered US marks in classes
3, 4 and 35. Those cover other goods, so a component of a software factory, named inside the Ouroboric umbrella,
is unlikely to conflict. The brand does mean that "Voluspa" alone will never be a findable product name: web
searches are full of candles.

[ANALYSIS] Voluspa Labs is the closest software use: a small company making developer tools for agents under
`@voluspalabs` and `voluspa.io`. It is young and small, and it holds no registry name `voluspa`. It is a reason
not to use Voluspa as a standalone product brand, not a reason to drop it as a component name.

## Verdict

**A common word from myth, usable under the Ouroboric umbrella** as the name of the graph-library component
(`ouroboric-dev/voluspa`, Go module), not as a product brand. No collision blocks it. The founder decides in the
[Voluspa proposal](../2-engineering/changes/2026-10-19-voluspa/proposal.md#name). If Voluspa ever becomes
something Ouroboric markets on its own, a formal search in the official registers comes first, as the 2026-10-12
decisions require for "Ouroboric".
