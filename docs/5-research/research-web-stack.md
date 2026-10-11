---
title: Research: web SaaS stack for the web realm
status: draft
date: 2026-10-11
related: []
style: research
---

# Web stack brief for the software-factory "pack": Pixieset Client Gallery clone-lite

Research date: 2026-10-11. Every factual claim has a source link. Items marked **[UNVERIFIED]** came only from secondary sources or could not be confirmed. Items marked **[ANALYSIS]** are my own reasoning, not sourced facts.

---

## 0. TL;DR

- **What agentic builders default to in 2026:** React + TypeScript + Tailwind + shadcn/ui is close to universal. The server side splits between **Next.js**, which v0 uses, and **Vite/TanStack plus a BaaS**. Lovable used React + Vite + Supabase and moved new projects to **TanStack Start** on 2026-05-13. Postgres is the default database everywhere.
- **Agent proficiency:** Next.js has the strongest measured evidence. Vercel's public Next.js agent evals put the top harnesses at 97%. Next.js ships version-matched docs, a managed AGENTS.md and a dev-server MCP endpoint. It also has the largest share of coding-agent PRs (16%). No comparable cross-framework benchmark exists for SvelteKit, Laravel or Rails.
- **Security:** Next.js has the heaviest recent security load:
  - CVE-2025-29927, a middleware auth bypass (CVSS 9.1).
  - CVE-2025-55182/66478 "React2Shell", an unauthenticated RCE (CVSS 10) that was exploited within hours.
  - A *monthly* security-release cadence since July 2026.
  - Three critical RCEs in Aug–Sep 2026. Two of them are in **image paths**: `/_next/image` via libheif/AVIF, and `next/og`.
- **Recommendation [ANALYSIS]:**
  - **Primary pack: option (c).** A React 19 + Vite + TanStack Router/Query + Tailwind + shadcn SPA with a **Go API**. It matches the user's existing projects and the factory language. It has no RSC/Server-Action attack surface, and Go is well suited to presigning, streaming ZIPs and image workers. SEO does not matter for private client galleries.
  - **Control pack: option (a)**, Next.js full-stack. It is the mainstream agent default and has the best agent tooling. It is worth running for comparability, but it needs a strict patch policy.
  - **Image pipeline:** direct-to-S3 presigned multipart uploads (Uppy), then **imgproxy** (Go/libvips, Apache-2.0, signed URLs) or a Go libvips worker in an isolated container, behind a CDN.
  - **Local S3:** do **not** use MinIO, which was archived 2026-04-25. Use **SeaweedFS** (Apache-2.0); Garage is the alternative.

---

## 1. What AI app builders and agent workflows generate by default

| Builder / source | Frontend | Backend / data | Auth | Confidence |
|---|---|---|---|---|
| **Lovable** | **TanStack Start** with SSR for apps created from 2026-05-13 (Enterprise from 2026-06-22). Older apps use React + Vite (browser-rendered). Code is TypeScript + Tailwind + shadcn/ui. | Built-in "Cloud" backend: managed Postgres, login, file storage. You can also use your own Supabase. "Lovable does not offer a choice of framework or database." | Built in: email/password, Google, Apple, Microsoft, SAML | Primary: [Lovable FAQ](https://docs.lovable.dev/introduction/faq), [Lovable blog](https://lovable.dev/blog/building-apps-using-tanstack-start). Lovable cites SSR for crawlers, end-to-end types as "guardrails" for the AI, and host portability. [TanStack partnership post](https://tanstack.com/blog/lovable-partnership) |
| **Vercel v0** | "v0 uses Next.js, React, TypeScript, Tailwind CSS, and shadcn/ui", and "runs on Next.js" | "Connect databases…", with no specific DB named in the FAQ | — | Primary: [v0 FAQ](https://v0.app/docs/faqs) |
| **Bolt.new** | Any browser-runnable JS framework. Node backends only (no PHP/Python). Expo for mobile. | Bolt Cloud (Aug 2025) adds managed DB and hosting | — | [Bolt support: supported technologies](https://support.bolt.new/faq/supported-technologies). The React/Node/Postgres default is **[UNVERIFIED]** ([banani review](https://www.banani.co/./blog/bolt-new-ai-review-and-alternatives)) |
| **Replit Agent** | Official docs only say "every web app includes a frontend and backend". | "API routes, a database" | Replit Auth (OIDC) | [Replit docs](https://docs.replit.com/replitai/web-apps.md). React + Tailwind + shadcn + Express + Postgres (+ Drizzle) is **[UNVERIFIED]** ([RapidDev tutorial](https://www.rapidevelopers.com/md/replit-tutorial/how-to-set-up-a-full-stack-javascript-application-on-replit-with-proper-routing)) |
| **Anthropic quickstarts** | Only one quickstart names a frontend framework, and it is Next.js ("Road Trip Planner") | — | — | [anthropics/claude-quickstarts](https://github.com/anthropics/claude-quickstarts) |
| **Cursor / Claude Code / Codex (unopinionated agents)** | No default stack. What agents actually touch: Next.js is the largest framework by agent-PR volume (16%), with React at 15.9%. | — | — | [Amplifying, "Coding agents by framework" (2026-09-14 → 10-04)](https://s.amplifying.ai/coding-agents/frameworks). This is "portfolio tilt, not market share". |
| **Auth library trend (TS)** | Auth.js/NextAuth has been maintained by the Better Auth team since 2025-09-22, and Better Auth is recommended for new projects. **Better Auth joined Vercel on 2026-07-07**; Vercel commits to keeping it "framework and platform agnostic". | | | [Better Auth: Auth.js joins](https://www.better-auth.com/blog/authjs-joins-better-auth), [Better Auth joins Vercel](https://better-auth.com/blog/better-auth-joins-vercel) |

**Surveys**
- **State of JS 2025:**
  - Next.js is used by 59% of respondents, with 21% positive and 17% negative sentiment. It drew the most comments of any project, with complaints about complexity and Vercel's motives ([InfoQ](https://www.infoq.com/news/2026/03/state-of-js-survey-2025)).
  - Next.js's satisfaction is 39% below Astro's, the leader. TanStack Start is "going to make a very strong entrance" next year ([stateofjs](https://2025.stateofjs.com/en-US/libraries/meta-frameworks/)).
  - Vite satisfaction is 98%. Claude usage doubled to 44% and Cursor reached 26% ([InfoQ](https://www.infoq.com/news/2026/03/state-of-js-survey-2025)).
- **Stack Overflow 2025** (all / professional): React 44.7/46.9%, Next.js 20.8/21.5%, Express 19.9%, Laravel 8.9%, Svelte 7.2%, Rails 5.9%. PostgreSQL leads databases at 55.6/58.2% ([SO 2025](https://survey.stackoverflow.co/2025/technology)).
- **Stack Overflow 2026:** PostgreSQL 57.9% ([SO 2026](https://survey.stackoverflow.co/2026/technology)). I could not find framework percentages for 2026 **[UNVERIFIED]**.
- **Agent-driven deploys:** Vercel reports that coding agents triggered fewer than 3% of deploys a year ago and now trigger a majority **[UNVERIFIED, vendor claim via press]** ([IT Brief](https://itbrief.co.uk/story/vercel-unveils-agent-tools-as-deployments-turn-ai-led)). I found no Vercel or Netlify report that breaks agent sites down by framework.

**Takeaway [ANALYSIS]:** React + TS + Tailwind + shadcn/ui + Postgres is the consensus "agent dialect". Next.js is the most common full-stack shell. The momentum among builders is toward TanStack (Lovable) and toward framework-agnostic auth (Better Auth).

---

## 2. Evidence on how well agents write each framework, and the tooling available

| Framework | Measured evidence | Agent tooling |
|---|---|---|
| **Next.js** | [Next.js agent evals](https://nextjs.org/evals) (pass@4, last run 2026-09-25): Claude Opus 5.5 + Claude Code 97%, GPT 6 Sol + Codex 97%, OpenCode + Grok 4.7 94%. Bundled docs/AGENTS.md lift weaker models, e.g. Composer 2.5 from 81% to 94%; earlier Sonnet 4.6 went from 45% to 74%. | Next 16.2+ bundles version-matched docs in `node_modules/next/dist/docs`. 16.3+ writes a managed AGENTS.md block ("This is NOT the Next.js you know"). Also available: `next upgrade --agent`, Skills such as `next-dev-loop`, and `agent-browser` ([AI agents guide](https://nextjs.org/docs/app/guides/ai-agents)). The dev server exposes MCP at `/_next/mcp` (`get_errors`, `get_routes`, `get_compilation_issues`…) via `next-devtools-mcp` ([MCP guide](https://nextjs.org/docs/app/guides/mcp)). |
| **React + Vite / TanStack** | No public framework eval found. Lovable chose TanStack Start partly because end-to-end types give its AI "tighter guardrails" ([Lovable](https://lovable.dev/blog/building-apps-using-tanstack-start)). | Official TanStack MCP serves version-specific docs ([TanStack MCP](https://tanstack.com/mcp/latest/docs)). TanStack "Intent" skills ([blog index](https://tanstack.com/blog)). |
| **SvelteKit** | None found. | Official Svelte MCP (`@sveltejs/mcp` / `mcp.svelte.dev`) with a `svelte-autofixer` static-analysis loop ([svelte.dev/docs/ai](https://svelte.dev/docs/ai/tools)). |
| **Laravel** | None found. | **Laravel Boost**: composable guidelines, skills, an MCP server, and a docs-search API keyed to installed packages ([Laravel Boost](https://laravel.com/docs/13.x/boost)). |
| **Rails 8** | None found. | Nothing official comparable found. |
| **shadcn/ui (all React options)** | — | shadcn MCP server to browse, search and install from registries in `components.json` ([shadcn MCP](https://ui.shadcn.com/docs/mcp)). |
| **General web-dev quality** | LMArena WebDev, now Code Arena, enforces React + TS + Tailwind in its stack ([AI Wiki](https://www.aiwiki.ai/wiki/webdev_arena)), so it measures models, not frameworks. Current standings **[UNVERIFIED]** ([leaderboard](https://lmarena.ai/leaderboard/webdev)). | |

**Takeaway [ANALYSIS]:** Next.js is the only framework with a public, maintained agent benchmark and first-party agent runtime tooling. React SPA code is widespread in the training data (React is 44.7% in SO 2025), but nobody publishes evals for it. Go is the factory language; I did not research agent benchmarks for Go specifically.

---

## 3. Comparison of options for the client-gallery product

Product requirements, checked against the [Pixieset Client Gallery page](https://pixieset.com/client-gallery/):
- Galleries with password protection and download PINs.
- Single-photo and full-gallery downloads at selectable sizes.
- Favourites and comments.
- Watermark, download analytics, store and print sales.

### 3.1 Summary table

Scores run 1 (worst) to 5 (best) and are **[ANALYSIS]** grounded in the cited facts in 3.2.

| Criterion | (a) Next.js full-stack + Drizzle + Better Auth + S3 | (b) Next.js FE + Go API | (c) React+Vite SPA (TanStack) + Go API | (d) TanStack Start full-stack | (e) SvelteKit | (f1) Rails 8 / Laravel 13 | (f2) Supabase-as-backend (Lovable-style) |
|---|---|---|---|---|---|---|---|
| Agent proficiency / training data | **5** (evals, MCP, AGENTS.md, top agent-PR share) | 4 (two codebases, two mental models) | **4–5** (React is ubiquitous; Go is strong; no published eval) | 3–4 (Lovable bet; less training data; still "RC" label) | 3 (Svelte 7.2% SO; good MCP) | 3 (Boost for Laravel; new language for factory) | 4 (very common in builders) |
| Large uploads (presigned multipart) | 4 (Route Handler signs; Uppy) | 5 (Go signs) | 5 (Go signs) | 4 | 4 | 4 (Active Storage direct uploads) | 3 (Supabase Storage; TUS) |
| Thumbnails / responsive serving | 3: `next/image` + sharp works but carries an RCE/SSRF/DoS history. Use imgproxy/custom loader instead. | 4 (Go worker / imgproxy) | **5** (Go worker / imgproxy) | 4 (bring your own) | 4 (bring your own) | 4 (libvips variants) | 2 (transforms on Pro: $5 per 1k origin images, 25 MB / 50 MP caps) |
| Auth + public-link/password model | 4 (Better Auth for photographers; custom gallery-token check in data layer) | 3 (auth split across two runtimes) | 4 (Go sessions + signed gallery cookie; simple, one place) | 4 | 4 | 5 (Rails auth generator / Laravel kits) | 3 (RLS footgun; anonymous gallery access awkward) |
| Playwright testability | 5 | 4 (two servers; `webServer` array) | 5 | 5 | 5 | 5 | 4 |
| Self-hosting vs lock-in | 3 (self-hostable; Adapter API stable in 16.2; multi-instance caching needs work) | 4 | **5** (static SPA + Go binary) | 5 (any JS host) | 5 (adapters) | 5 (Kamal etc.) | 2–3 (self-host Supabase is heavy) |
| Framework churn (2024–26) | 2 (15→16 in a year; middleware renamed proxy; monthly security releases) | 2–3 | **4** (Vite/TanStack Router stable; Go very stable) | 2 (still 1.168.x "RC"; XSS CVE in Sep 2026) | 2 (SvelteKit 3.0 shipped 2026-10-01) | 4 | 3 |
| Devcontainer with local S3 | 4 | 4 | 5 | 4 | 4 | 4 | 3 (Supabase CLI stack) |
| Security surface for unattended shipping | **2** (see section 5) | 3 (Next.js still present, but holds no data or secrets if it is a thin BFF) | **4** (no RSC/Server Actions; Go stdlib) | 3 (no RSC yet; reflected XSS CVE-2026-102989) | 3 (Jan 2026 CVE batch) | 4 | 2–3 (CVE-2025-48757 RLS) |

### 3.2 Per-option notes, with sources

**(a) Next.js App Router full-stack (Tailwind, shadcn, Drizzle, Postgres, Better Auth, S3)**
- **Pros:**
  - Best measured agent performance and tooling ([evals](https://nextjs.org/evals), [AI guide](https://nextjs.org/docs/app/guides/ai-agents)).
  - It is v0's native stack ([v0 FAQ](https://v0.app/docs/faqs)).
  - Self-hosting with `next start` / Docker works with "zero configuration" for image optimization and proxy ([self-hosting guide](https://nextjs.org/docs/app/guides/self-hosting)).
  - The Adapter API became stable in 16.2 ([Next.js across platforms](https://nextjs.org/nextjs-across-platforms)).
- **Cons:**
  - Multi-instance self-hosting needs a shared cache handler, a shared `NEXT_SERVER_ACTIONS_ENCRYPTION_KEY`, `deploymentId` and `refreshTags` coordination ([self-hosting guide](https://nextjs.org/docs/app/guides/self-hosting)). Agents often miss this **[ANALYSIS]**.
  - Version churn: 15.0 shipped 2024-10-21, 16.0 on 2025-10-22, 16.3 on 2026-08-03 and 16.4 on 2026-10-06 (npm registry timestamps).
  - The security record is in section 5.
  - Drizzle's npm `latest` is still 0.45.4 while 1.0 sits in RC (npm dist-tags), so another migration is coming **[ANALYSIS]**.
  - Better Auth is now Vercel-owned ([post](https://better-auth.com/blog/better-auth-joins-vercel)). That is not lock-in by itself, but it is worth noting **[ANALYSIS]**.
- **Image specifics:** Do not route user uploads through `/_next/image`. Use a custom loader pointing at imgproxy, or pre-generated renditions **[ANALYSIS]**. This is also how Netlify avoided the AVIF RCE: it rewrites `/_next/image` to its own image CDN ([Netlify changelog](https://www.netlify.com/changelog/2026-08-25-nextjs-security-vulnerabilities.md)).

**(b) Next.js frontend + Go API**
- **Pros:** Go owns data, auth, presigning, ZIP streaming and image workers, which suits the factory's language **[ANALYSIS]**.
- **Cons [ANALYSIS]:** You inherit Next.js's patch treadmill while using little of its server value. Auth spans two runtimes, so cookie and session sharing becomes a source of bugs. There are two test harnesses. If Next.js is only a BFF/SSR shell, its compromise is less catastrophic as long as it holds no DB credentials. React2Shell still gave RCE on the Next.js box ([Next.js advisory](https://nextjs.org/blog/CVE-2025-66478)).

**(c) React 19 + Vite SPA (TanStack Router/Query) + Go API**
- **Pros:**
  - The same stack as the user's projects.
  - It was Lovable's stack until May 2026 ([Lovable FAQ](https://docs.lovable.dev/introduction/faq)).
  - Vite has 98% satisfaction ([InfoQ](https://www.infoq.com/news/2026/03/state-of-js-survey-2025)).
  - **No React Server Components runtime**, so it is not in the React2Shell affected list, which covers next, react-router, waku, @parcel/rsc, @vitejs/plugin-rsc and rwsdk ([React blog](https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components)).
  - Go streams uploads, ZIPs and image processing natively. Static SPA plus a Go binary is the easiest thing to self-host **[ANALYSIS]**.
  - Client galleries are private links, so SSR and SEO add almost nothing **[ANALYSIS]**.
- **Cons:**
  - No first-party agent runtime tool like `/_next/mcp`. Mitigate with Playwright, TanStack MCP and shadcn MCP **[ANALYSIS]**.
  - The API contract must be kept in sync. Use OpenAPI codegen on both sides **[ANALYSIS]**.
  - Better Auth is TS-only, so Go needs its own session code. This is small for this product: photographer accounts plus gallery tokens **[ANALYSIS]**.
  - Marketing/SEO pages, if needed, can be a separate static site **[ANALYSIS]**.

**(d) TanStack Start full-stack**
- **Pros:**
  - Lovable's 2026 default ([Lovable blog](https://lovable.dev/blog/building-apps-using-tanstack-start)).
  - Typed server functions.
  - Deploys on any JS host.
  - RSC is not shipped in v1 ([TanStack v1 RC post](https://tanstack.com/blog/announcing-tanstack-start-v1)).
- **Cons:**
  - The v1.0 RC was announced 2025-09-23 and **no GA post** has been found. npm `latest` is 1.168.61 (2026-10-10), so the minor-version churn is high **[ANALYSIS]**.
  - Critical reflected XSS in server-function responses: CVE-2026-102989, fixed in react-start 1.168.60 ([TanStack advisory](https://tanstack.com/blog/tanstack-start-security-update-cve-2026-102989)).
  - Less training data than Next.js **[ANALYSIS]**.

**(e) SvelteKit**
- **Pros:** Official MCP with an autofixer loop ([svelte docs](https://svelte.dev/docs/ai/tools)). Small bundles. Adapters for many hosts.
- **Cons:**
  - **SvelteKit 3.0 shipped 2026-10-01** (npm) after an August RC. It moves config into `vite.config`, changes `$lib`→`#lib`, and requires Node 22.17 and TS 6 ([RC post](https://svelte.dev/blog/sveltekit-3-release-candidate)). Agents' training data is mostly SvelteKit 2 / Svelte 4–5 **[ANALYSIS]**.
  - Five CVEs in January 2026: devalue DoS, kit SSRF/DoS, svelte XSS ([Svelte blog](https://svelte.dev/blog/cves-affecting-the-svelte-ecosystem), [Netlify](https://www.netlify.com/changelog/2026-01-15-sveltekit-security-vulnerabilities/)).
  - Smallest usage share of the JS options (SO 7.2%).

**(f1) Rails 8 / Laravel 13 (batteries included)**
- **Pros:**
  - Rails 8 ships an auth generator, Solid Queue/Cache (DB-backed, no Redis) and Kamal deploys ([Rails 8 announcement](https://rubyonrails.org/2024/11/7/rails-8-no-paas-required)).
  - Active Storage does browser-to-S3-compatible direct uploads and proxy or redirect serving ([Rails guide](https://guides.rubyonrails.org/active_storage_overview.html)).
  - Laravel Boost gives first-party agent guidelines and MCP ([Laravel Boost](https://laravel.com/docs/13.x/boost)). Laravel starter kits now ship Laravel 13 + Inertia v3 ([Laravel blog](https://laravel.com/blog/laravel-march-product-updates)).
- **Cons:**
  - A third language, unrelated to Go and TS.
  - Lower agent-PR volume.
  - Active Storage controllers are "publicly accessible by default", and redirect URLs are "permanent" signed IDs ([Rails guide](https://guides.rubyonrails.org/active_storage_overview.html)). That is the wrong default for private galleries unless overridden **[ANALYSIS]**.

**(f2) Supabase-as-backend (Lovable-style)**
- **Pros:** The fastest path to auth + Postgres + storage **[ANALYSIS]**. A common builder default.
- **Cons:**
  - Image transformations require Pro, cost $5 per 1,000 origin images beyond 100, cap at 25 MB and 50 MP, and resize up to 2,500 px ([Supabase docs](https://supabase.com/docs/guides/storage/serving/image-transformations)). High-resolution cameras routinely exceed 50 MP **[ANALYSIS / general knowledge]**, so this is a poor fit for a photographer product.
  - Security footgun: CVE-2025-48757. A researcher found 170 of 1,645 Lovable showcase apps with Supabase tables readable or writable via the public anon key because RLS was off ([Superblocks](https://www.superblocks.com/blog/lovable-rls-breach), [CVE record](https://cvemon.intruder.io/cves/CVE-2025-48757)). Lovable disputes it as customer responsibility.

---

## 4. Storage and image pipeline recommendation

### 4.1 Uploads

- Photographers upload many large JPEGs, possibly RAW files. Pixieset mentions RAW sharing ([Pixieset](https://pixieset.com/client-gallery/)).
- Use **browser-direct presigned multipart uploads** **[ANALYSIS]**:
  - **Uppy AwsS3** with a `signRequest` endpoint signs PutObject, CreateMultipartUpload, UploadPart, ListParts, CompleteMultipartUpload and AbortMultipartUpload.
  - Multipart is the default above 100 MiB and resumes interrupted uploads.
  - The bucket CORS must expose `ETag` and allow GET and DELETE ([Uppy docs](https://uppy.io/docs/aws-s3/)).
- **Security example:** if the signer signs any `key` the client asks for, photographer A can overwrite photographer B's originals by requesting `galleries/B/IMG_001.jpg` ([Uppy docs](https://uppy.io/docs/aws-s3/)). The server must derive the key from the authenticated user and gallery, never from client input **[ANALYSIS]**.

### 4.2 Thumbnails and responsive serving

Two viable patterns **[ANALYSIS]**:
1. **Pre-generate a fixed set of renditions.** For example, long edge 400 / 1200 / 2048 in WebP, plus a JPEG fallback and watermarked variants. A Go worker built on libvips does this, triggered after the upload completes. Bindings: [vipsgen](https://github.com/cshum/vipsgen) or the maintained [govips fork](https://pkg.go.dev/github.com/getshuttle/govips/v2). Benefit: predictable cost, CDN-friendly immutable URLs, and no public transform endpoint.
2. **On-the-fly with imgproxy** behind a CDN. [imgproxy](https://github.com/imgproxy/imgproxy) is Apache-2.0, written in Go and uses libvips. It offers **signed URLs**, image-bomb protection (it checks real dimensions before decoding), source restriction and watermarking in OSS.

**Recommendation [ANALYSIS]:** use imgproxy, with signed URLs only and source restricted to your bucket, behind a CDN. Optionally pre-warm the 2–3 gallery sizes at upload time. This works the same for every option (a)–(e) and keeps image decoding out of the web-app process.

**Avoid `next/image`'s built-in optimizer for user content** **[ANALYSIS]**. Its history includes:
- An AVIF/libheif RCE (GHSA-2xp9-vwfh-vxw4, CVSS 9.5).
- SSRF via `remotePatterns`, where DNS changes on an allow-listed host lead to internal requests (CVE-2026-94483).
- An SVG DoS (CVE-2026-64644) ([advisories](https://github.com/vercel/next.js/security/advisories), [July release](https://nextjs.org/blog/july-2026-security-release)).

**The decoder risk applies to every libvips-based tool, Go included** **[ANALYSIS]**. The August 2026 bug was in **libheif**, which sharp bundles: CVE-2026-84383, a heap overflow and possible RCE on glibc Linux, fixed in sharp 0.35.4 / libheif 1.23.2 ([sharp advisory](https://github.com/lovell/sharp/security/advisories/GHSA-rgj7-g3m4-5g8c)). sharp also had libvips CVEs in July 2026 and a librsvg CVE in Sep 2026 ([sharp advisories](https://github.com/lovell/sharp/security/advisories)).

**Mitigations [ANALYSIS]:**
- Run the image worker or imgproxy in its own container with no DB credentials. Give it read access to originals and write access to derivatives only, and no egress.
- Allow-list input formats; for example, block HEIF/AVIF/SVG decoding unless needed. sharp's own workaround is `sharp.block({ operation: ["VipsForeignLoadHeif"] })`.
- Cap pixel count.
- Track libvips/libheif advisories as factory-level dependencies.

**Relatable example:** a "client" uploads `wedding_001.avif` to a proofing gallery. When the server makes the thumbnail, the file overflows memory in the decoder, and the attacker gets a shell on the box that holds your S3 keys and every client's photos.

### 4.3 "Download all"

**[ANALYSIS]** Stream a ZIP from Go: read objects from S3 and write `archive/zip` entries with the Store method, since JPEGs are already compressed. For very large galleries, build the ZIP asynchronously into S3 and email a short-lived presigned GET link.

**Gallery access [ANALYSIS]:**
- An unguessable slug plus an optional password hashed with argon2id.
- A short-lived, signed, HttpOnly gallery cookie scoped to that gallery.
- Every image and download URL is a short-lived presigned or signed URL.
- Enforce the check in the data layer or handler, **not only in middleware or proxy**; see CVE-2025-29927 in section 5.

### 4.4 Local S3 in the devcontainer

The Verdict column is **[ANALYSIS]**.

| Option | Status / license | S3 features relevant here | Verdict |
|---|---|---|---|
| **MinIO (community)** | Console stripped May 2025. Binaries and Docker images stopped Oct 2025. Maintenance mode Dec 2025. **Repo archived 2026-04-25.** "Distributed as source code only"; AGPLv3 ([GitHub](https://github.com/minio/minio), [InfoQ](https://infoq.com/news/2025/12/minio-s3-api-alternatives/)) | Full | **Do not use.** A pinned image never gets patches. |
| **SeaweedFS** | Apache-2.0, Go ([InfoQ](https://infoq.com/news/2025/12/minio-s3-api-alternatives/)) | Presigned, multipart, CORS, POST policy, versioning, lifecycle (no transitions) ([wiki](https://github.com/seaweedfs/seaweedfs/wiki/Amazon-S3-API)) | **Recommended** for the devcontainer |
| **Garage** | AGPLv3, Rust, small/self-hosted ([InfoQ](https://infoq.com/news/2025/12/minio-s3-api-alternatives/)) | Presigned, multipart, CORS, PostObject. Lifecycle partial (Expiration, AbortIncompleteMultipartUpload). **No versioning** ([Garage docs](https://garagehq.deuxfleurs.fr/documentation/reference-manual/s3-compatibility/)) | Good alternative |
| **RustFS** | Apache-2.0. 1.0 GA reported 2026-09-16 **[UNVERIFIED, secondary]** ([linuxiac](https://linuxiac.com/?p=219580)). Default creds `rustfsadmin` ([skills.sh](https://skills.sh/mikkelkrogsholm/dev-skills/rustfs)) | S3 API; some interop features still in preview | Watch |
| **LocalStack** | Since 2026-03-23, latest images **require an account and auth token**, including in CI. A free Hobby plan exists for non-commercial use ([LocalStack blog](https://blog.localstack.cloud/localstack-single-image-next-steps/), [release notes](https://blog.localstack.cloud/localstack-for-aws-release-2026-03-0/)) | Broad AWS emulation | Not worth the token friction for S3-only |

**Production [ANALYSIS]:** use any S3-compatible service, such as AWS S3, Cloudflare R2 or Backblaze B2. Keep code to the portable S3 subset: presign, multipart, CORS, GET/PUT/HEAD/DELETE, and lifecycle Expiration. This keeps SeaweedFS-in-dev equal to the cloud in prod.

---

## 5. Security track record and why it matters for an autonomous factory

### 5.1 CVE-2025-29927: Next.js middleware authorization bypass (verified)

- **Advisory:** GHSA-f82v-jwr5-mffw, published 2025-03-21, **CVSS 9.1 Critical**, CWE-285.
- **Affected:** 11.1.4 up to (not including) 12.3.5, 13.0–13.5.8, 14.0–14.2.24 and 15.0–15.2.2.
- **Fixed in:** 12.3.5, 13.5.9, 14.2.25 and 15.2.3.
- Vercel-hosted apps were protected automatically. The workaround for unpatched apps is to strip the `x-middleware-subrequest` header at the edge ([advisory](https://github.com/vercel/next.js/security/advisories/GHSA-f82v-jwr5-mffw)).

**What went wrong** ([discoverer write-up](https://zhero-web-sec.github.io/research-and-things/nextjs-and-the-corrupt-middleware)):
- Next.js used an internal header, `x-middleware-subrequest`, to mark recursive internal calls and skip middleware. It **trusted that header on external requests**.
- Sending `x-middleware-subrequest: middleware:middleware:middleware:middleware:middleware` reached `MAX_RECURSION_DEPTH = 5`. With a `src/` directory the value is `src/middleware` repeated. Next.js then skipped middleware entirely.
- That disables auth checks, redirects and rewrites, and security headers such as CSP. It can also poison a CDN cache with a 404.

**Gallery example:** if "is this visitor allowed into `/g/smith-wedding`?" lives only in `middleware.ts`, one curl with that header returns the private gallery, with no password and no PIN.

**The recurrence:** the same class came back as CVE-2026-64642, a middleware/proxy bypass with Turbopack and a single i18n locale, fixed in 16.2.11 / 15.5.21 ([Next.js July 2026 release](https://nextjs.org/blog/july-2026-security-release)). **Lesson for agents [ANALYSIS]:** never let middleware or proxy be the only authorization layer.

### 5.2 CVE-2025-55182 "React2Shell" (React) / CVE-2025-66478 (Next.js): unauthenticated RCE (verified)

- **Severity:** CVSS 10.0. Reported 2025-11-29, disclosed 2025-12-03.
- **Affected React packages:** `react-server-dom-webpack`, `-parcel` and `-turbopack` 19.0, 19.1.0, 19.1.1 and 19.2.0. **Fixed in** 19.0.1, 19.1.2 and 19.2.1.
- **Affected frameworks:** next, react-router (RSC), waku, @parcel/rsc, @vitejs/plugin-rsc and rwsdk.
- Apps were vulnerable "even if it doesn't define Server Functions" as long as RSC is supported ([React blog](https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components)).
- **Next.js scope:** the App Router on 15.x, 16.x and 14.3 canaries; Pages Router and Edge are not affected. Fixed in 15.0.5 … 16.0.7. There is **no workaround**. Vercel told unpatched-and-online apps to **rotate all secrets** ([Next.js advisory](https://nextjs.org/blog/CVE-2025-66478)).
- **Exploitation:** within hours of disclosure, by China-nexus groups (Earth Lamia, Jackpot Panda) ([AWS Security Blog](https://aws.amazon.com/blogs/security/china-nexus-cyber-threat-groups-rapidly-exploit-react2shell-vulnerability-cve-2025-55182/)).
- **Root cause:** unsafe deserialization of Flight-protocol payloads sent to Server Function endpoints. Secondary analyses describe missing `hasOwnProperty` checks that allow `__proto__` prototype pollution ([Armis](https://www.armis.com/blog/priority-zero-patching-event-react2shell/)) **[root-cause detail UNVERIFIED against primary source; the React advisory intentionally withheld details]**.
- **Follow-up CVEs:** DoS (CVE-2025-55184, -67779, CVE-2026-23864) and source-code exposure (CVE-2025-55183) ([React blog](https://react.dev/blog/2025/12/03/critical-security-vulnerability-in-react-server-components)).

**Gallery example:** one unauthenticated POST to any page of the app runs code on the server. The attacker reads `.env`: the DB URL, S3 keys and Stripe key from the later print store. They then download every client's private photos straight from the bucket and keep a backdoor after you patch.

### 5.3 The 2026 cadence (verified)

- Next.js formalized a **monthly pre-announced security release** program on 2026-07-13. It cites rising "LLM-assisted discovery" ([Next.js blog](https://nextjs.org/blog/next-security-release-program)).
- **July 2026:** nine CVEs (four high), including the middleware/proxy bypass, SSRF in rewrites and Server Actions, and Server-Action DoS ([July release](https://nextjs.org/blog/july-2026-security-release)).
- **Aug 25, 2026:** two critical unauthenticated RCEs, fixed in 15.5.24 / 16.3.3 ([Netlify](https://www.netlify.com/changelog/2026-08-25-nextjs-security-vulnerabilities.md), [Canadian Cyber Centre AV26-851](https://cyber.gc.ca/en/alerts-advisories/nextjs-security-advisory-av26-851)):
  - Windows-hosted servers (CVE-2026-75604).
  - Image Optimization with AVIF (GHSA-2xp9-vwfh-vxw4, CVSS 9.5).
- **Sep 2026** ([advisories list](https://github.com/vercel/next.js/security/advisories)):
  - Critical RCE in `next/og` `ImageResponse` when user input reaches SVG (CVE-2026-94545, 16.2.0–16.3.5, fixed in 16.3.6) ([GHSA-vcvr-r3jv-pc5j](https://github.com/vercel/next.js/security/advisories/GHSA-vcvr-r3jv-pc5j)).
  - High-severity Image Optimization SSRF (CVE-2026-94483) ([GHSA-cjq9-62q9-8jv4](https://github.com/vercel/next.js/security/advisories/GHSA-cjq9-62q9-8jv4)).
  - Several cache-poisoning and leak issues.
  - A **low-severity info disclosure in the dev server's MCP endpoint**, relevant because agents run `next dev` in devcontainers.
- **Other stacks are not immune:**
  - TanStack Start: critical reflected XSS, Sep 2026 ([advisory](https://tanstack.com/blog/tanstack-start-security-update-cve-2026-102989)).
  - SvelteKit/devalue: five CVEs, Jan 2026 ([Svelte blog](https://svelte.dev/blog/cves-affecting-the-svelte-ecosystem)).
  - sharp/libvips/libheif/librsvg: Jul–Sep 2026 ([sharp advisories](https://github.com/lovell/sharp/security/advisories)).

### 5.4 Why this matters for a factory that pins and ships versions [ANALYSIS]

- **Pinning freezes vulnerabilities in place.**
  - A pack pinned to `next@16.0.6` in November 2025 would have shipped every product with an unauthenticated RCE that was exploited within hours of disclosure.
  - A pack pinned to the MinIO image ships storage that will never be patched again.
  - Reproducibility (same versions on every run) and safety (latest patch) pull in opposite directions. Resolve it with **pinned minor line + mandatory patch floor**: e.g. `next@16.3.x >= 16.3.6`. Enforce it with an `npm audit` / `osv-scanner` / `govulncheck` gate before any artifact ships.
- **Snowball effect.**
  - The pack is a template, so one vulnerable pin is copied into every product the factory generates. With N products live, one advisory means N emergency rebuilds, N secret rotations (React2Shell required rotating *all* secrets) and N redeploys.
  - The reverse also cascades. A bulk "bump Next.js across all products" run is a write to every repo at once. If the bump crosses a breaking line, such as 15→16 or the middleware→proxy rename, every product's build or auth can break simultaneously.
  - Roll out patch bumps one canary product first, run the Playwright suite, then fan out in batches.
- **Agents' default patterns hit exactly these classes:**
  - Auth only in middleware (CVE-2025-29927, CVE-2026-64642).
  - Passing query params into OG images or SVG (CVE-2026-94545).
  - Broad `images.remotePatterns` (SSRF).
  - Supabase tables without RLS (CVE-2025-48757).
  - Make the factory's review gate check for these explicitly: authz in the data layer, no user input in SVG, signed image URLs, RLS or server-side checks.
- **Attack surface choice:**
  - Option (c) removes the RSC/Server-Action deserialization surface entirely. The Go stdlib and `govulncheck` give a slower-moving server dependency set.
  - The image decoder remains the highest-risk component in *any* option and should be isolated.
- **Monitor feeds per pack:**
  - Next.js blog / GHSA, React blog, TanStack blog, Svelte blog.
  - sharp / libvips / libheif advisories.
  - Go vulndb.
  - Next.js now pre-announces releases monthly, which lets the factory schedule pack refreshes ([program](https://nextjs.org/blog/next-security-release-program)).

---

## 6. Current versions (npm registry, queried 2026-10-11)

| Package | Version and date |
|---|---|
| next | 16.4.0 (2026-10-06); canary 16.5.0-canary.8; backport line 15.5.27 |
| react | 19.3.0 |
| @tanstack/react-start | 1.168.61 (2026-10-10); no 1.0 GA tag |
| @tanstack/react-router | 1.170.42 |
| @sveltejs/kit | 3.0.1 (3.0.0 published 2026-10-01) |
| better-auth | 1.7.7 (2026-09-30) |
| drizzle-orm | `latest` 0.45.4; `rc` 1.0.0-rc.4 |
| sharp | 0.35.5, at or above the 0.35.4 libheif fix |

---

## 7. Unverified / gaps

- Bolt.new and Replit Agent default stacks: secondary sources only.
- Stack Overflow 2026 web-framework percentages: not found.
- LMArena/Code Arena current rankings: not confirmed on the official page.
- RustFS 1.0 GA date: secondary sources.
- React2Shell root-cause internals: secondary analyses; the official advisory withheld details.
- Vercel's "majority of deploys are agent-triggered" stat: press coverage of a vendor claim.
- No public agent benchmarks found for SvelteKit, Laravel, Rails, TanStack Start or React+Vite SPAs. Comparative proficiency beyond Next.js is inferred from usage share, not measured.
- Lovable/TanStack partnership dates: Lovable says new projects switched on 2026-05-13 (blog dated 2026-06-01); the TanStack partnership post is dated 2026-07-01.
