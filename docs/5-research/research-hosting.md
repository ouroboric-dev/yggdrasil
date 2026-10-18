---
title: Research: low-cost hosting
status: draft
date: 2026-10-11
related: []
style: research
---

# Hosting research: client-gallery SaaS (Go API + React/Vite + DB + S3 photos)

Research date: **2026-10-11**. All URLs below were accessed on 2026-10-11 unless noted.
Legend: **[V]** = verified on official page today. **[U]** = unverified (page didn't render the number, or taken from a third-party source or prior knowledge). Re-check [U] items before you commit. **[ANALYSIS]** = the author's own judgement, recommendation or estimate, not a sourced fact.

---

## TL;DR

1. **Egress decides everything** **[ANALYSIS]**. Photo storage costs $0.007–0.015/GB-month. Egress ranges from **$0** (Cloudflare R2) to **$0.09/GB** (AWS S3, Supabase). At 20 TB/month that is roughly **$0 vs ~$1,800**.
2. **Never stream full-gallery zips through a compute platform that bills egress per GB** **[ANALYSIS]**. For example, Cloud Run internet egress is about $0.12/GB [U], so 1 TB of zips is about $120 per month. Serve downloads straight from the bucket with presigned URLs. You can pre-build each zip into R2, or zip in the browser from presigned URLs. Or stream zips from a VPS that has a large included-traffic allowance, such as Hetzner with 20 TB.
3. **Best value [ANALYSIS]:** Cloudflare R2 for photos, plus either a ~€6 Hetzner VPS (Go + SQLite + Litestream to R2) or Cloud Run free tier + Neon free. Put the frontend on Cloudflare Pages. Generate thumbnails in Go at upload time.

---

## 1. Databases

| Option | Free tier (today) | Pausing / data-loss risk | Paid entry | Protocol / Go driver | Notes |
| --- | --- | --- | --- | --- | --- |
| **Neon** [V] | 100 projects; **1 GB storage per project, 20 GB total**; 100 CU-hours/month per project; autoscale to 2 CU; 5 GB egress; 6 h history | Scales to zero after 5 min (can't disable on free). Over limits, compute suspends or writes block until next period. **Data is not deleted** | Launch: pay-as-you-go, $0.106/CU-h, $0.35/GB-month, 500 GB egress then $0.10/GB | Standard Postgres. `pgx` | Cold start on wake is typically a few hundred ms [U]. Plenty for 1 photographer **[ANALYSIS]**. |
| **Supabase** [V] | 500 MB DB, 1 GB file storage, 5 GB egress (+5 GB cached), 50 MB max upload, 2 active projects | **Pauses after 1 week of inactivity.** Restorable from dashboard for up to 1 year per current docs (a 2024 changelog said 90 days). After that, backup download only [V/conflicting] | Pro $25/month: 100 GB storage ($0.0213/GB after), 250 GB egress ($0.09/GB after). Spend cap on by default | Standard Postgres. `pgx` | The weekly pause makes free unusable for a live client site **[ANALYSIS]**. |
| **Turso (libSQL)** [V] | 100 DBs, 5 GB storage, 500M rows read, 10M rows written per month, 3 GB syncs | Not stated | Developer $4.99/month (9 GB) | libSQL (SQLite fork) over HTTP. Go: `tursodatabase/go-libsql` (CGO) or `libsql-client-go` [U] | SQLite-compatible, so the exit path is easy (dump to a `.db` file) **[ANALYSIS]**. |
| **Cloudflare D1** [V] | 5M rows read per day, 100k rows written per day, 5 GB total | Hitting a daily limit **blocks all queries until 00:00 UTC** | Workers Paid $5/month: 25B reads, 50M writes, 5 GB, then $0.75/GB-month | **No wire protocol.** Outside Workers it's HTTP REST API only. No native Go driver | Lock-in risk and extra latency from a Go container. **Not recommended [ANALYSIS].** |
| **Prisma Postgres** [V] | 200k operations per month, 1.01 GB, 50 DBs, 10 direct connections | Not stated | Starter $10, Pro $49 | Postgres. Plan table lists direct connections, so `pgx` should work [U: confirm TCP support in docs] | Operation-metered, so it's hard to predict **[ANALYSIS]**. |
| **Xata** [V] | **No free cloud tier**: 14-day trial, open source self-host is free | n/a | micro (1 GB) about $9/month + $0.28/GB storage | Postgres (wire protocol not stated on pricing page) [U] | |
| **Aiven free PostgreSQL** [V] | 1 CPU, 1 GB RAM, **1 GB storage**, single node, backups included | **Powered off after inactivity** (email warning first) | Paid plans [U] | Standard Postgres. `pgx` | 1 GB fills quickly once you add audit or event tables **[ANALYSIS]**. |
| **SQLite + Litestream on a small VM** | Free software. You pay only for the VM and a few cents of R2 | Data lives on the VM disk. Litestream streams the WAL to S3/R2 continuously (seconds of RPO) [U: no official pricing page applies] | VM cost only | `modernc.org/sqlite` (pure Go) or `mattn/go-sqlite3` (CGO) | Zero lock-in, zero cold start, single-writer. Easily handles 50 photographers **[ANALYSIS]**. Restore = `litestream restore`. **Test restores [ANALYSIS].** |

**Recommendation [ANALYSIS]:** start with **SQLite + Litestream** on the VPS, or **Neon free** if you run serverless (Cloud Run). Keep SQL portable (sqlc + standard SQL) so you can move SQLite to Postgres later.

Sources: <https://neon.com/pricing> · <https://supabase.com/pricing> · <https://supabase.com/docs/guides/platform/free-project-pausing> · <https://supabase.com/changelog/27497-paused-free-plan-projects-are-restorable-for-90-days> · <https://turso.tech/pricing> · <https://developers.cloudflare.com/d1/platform/pricing/> · <https://www.prisma.io/pricing> · <https://xata.io/pricing> · <https://aiven.io/free-postgresql-database>

> Note on Neon: the pricing page today lists **1 GB storage per project / 20 GB across projects** and **5 GB egress** on Free (older docs said 0.5 GB). [V]

---

## 2. Object storage and egress

| Provider | Free tier | Storage $/GB-month | Egress | Ops | Minimums / gotchas |
| --- | --- | --- | --- | --- | --- |
| **Cloudflare R2** [V] | 10 GB-month, 1M Class A, 10M Class B per month | **$0.015** (IA $0.01 + $0.01/GB retrieval) | **$0** via S3 API, Workers, or r2.dev / custom domain | A $4.50/M, B $0.36/M | None. S3 API compatible. |
| **Backblaze B2** [V] | First 10 GB free | **$6.95/TB ≈ $0.00695/GB** | Free up to **3× average stored data**, then **$0.01/GB**. Free via Cloudflare, Fastly, bunny.net and other partners | Class A/B/C free; Class D $0.004/10k (2,500/day free) | No minimum size or duration. |
| **Wasabi** [V] | None | **$7.99/TB** | "Free" only while **monthly egress ≤ active storage**. Repeated excess can lead to service being limited or suspended | No API fees | **1 TB minimum charge** and **90-day minimum retention** (early deletes billed). Both scenarios exceed the egress ratio (10× and 4×), so **unsuitable** **[ANALYSIS]**. |
| **Supabase Storage** [V] | 1 GB, 5 GB egress (Free) | Pro: 100 GB incl., then $0.0213 | 250 GB incl., then **$0.09/GB** | n/a | Free project pauses weekly. |
| **AWS S3** (reference) [U: table didn't render] | 100 GB/month internet egress free (all AWS services) [V] | ~$0.023 (Standard, us-east-1) [U] | ~$0.09/GB first 10 TB, ~$0.085 next 40 TB [U] | PUT $5/M, GET $0.40/M [U] | |
| **Hetzner Object Storage** [U prices] | n/a | Base price includes **1 TB storage + 1 TB egress** [V]. Amount: ~€4.99/month, extra ~€1/TB egress [U: pre-June-2026 prices, page didn't render] | see left | | EU only. Prices changed June 2026, so re-check. |

**Cloudflare CDN in front of B2: terms risk [U].** Cloudflare's CDN service-specific terms let it limit plans that serve "a disproportionate percentage of pictures… or other large files" without a paid service such as R2 or Images. Full-resolution 25 MB downloads proxied through free CDN in front of B2 are a gray area **[ANALYSIS]**. R2 avoids the issue.

Sources: <https://developers.cloudflare.com/r2/pricing/> · <https://www.backblaze.com/cloud-storage/pricing> · <https://wasabi.com/pricing> · <https://wasabi.com/paygo-pricing-faq> · <https://supabase.com/pricing> · <https://aws.amazon.com/s3/pricing/> · <https://www.hetzner.com/storage/object-storage>

---

## 3. Compute (Go container) and static frontend

| Platform | Free allowance | Cheapest always-on | Egress | Spending cap? |
| --- | --- | --- | --- | --- |
| **Google Cloud Run** [V free tier] | 2M requests, 180k vCPU-s, 360k GiB-s per month (request-based); **1 GB egress from North America** | Scales to zero. Small API usually stays in free tier | ~$0.12/GB internet [U] | **No hard cap.** Budgets only alert. Set `--max-instances` |
| **Fly.io** [V] | **No free tier** for new orgs. Trial: 2 machine-hours or 7 days | shared-cpu-1x: 256 MB $2.19, 512 MB $3.69, 1 GB $6.70/month | **$0.02/GB** NA/EU | **No caps, no billing alerts** ("We don't support billing alerts (yet)") |
| **Render** [V] | 750 free instance hours/month. **Spins down after 15 min idle.** Docs: "Do not use them for production" | Starter plan [U: price not rendered] | [U] | Free stops when hours run out |
| **Railway** [V] | Free: $1/month credit (0.5 GB RAM, no custom domain) | Hobby $5/month incl. $5 usage. ~$10/GB RAM, ~$20/vCPU per month | **$0.05/GB** | **Yes: hard limit** (min $10). Takes all workloads offline when reached |
| **Koyeb** [V] | Free compute instance **not listed** on pricing page today. Free Postgres: 5 h, 1 GB | Pro $29/month + compute | 1 TB incl. on Pro, then $0.02/GB | [U] |
| **Hetzner Cloud** [V] | n/a | **CX23 (2 vCPU/4 GB/40 GB) €5.49**, CAX11 €5.99, CX33 (4/8 GB) €8.49 per month excl. VAT, + ~€0.50 IPv4 [U]. **20 TB traffic included (EU)** | Overage ~€1/TB [U] | Fixed monthly price cap per server. Note: CX/CAX shown "currently unavailable" on 2026-10-11 (capacity limits since June 2026). US region only has CPX11 at €17.49 |
| **Cloudflare Containers** [V] | Needs Workers Paid ($5/month): 25 GiB-h memory, 375 vCPU-min, 200 GB-h disk | Pay-per-use, sleeps when idle | **1 TB NA/EU included**, then $0.025/GB | [U] |

### Static frontend

| Host | Free terms | Commercial use on free? |
| --- | --- | --- |
| **Cloudflare Pages** [V] | 500 builds/month, 20k files, 25 MiB per file. No bandwidth cap listed | Not restricted on the limits page [U: check ToS] |
| **Netlify** [V] | 300 credits/month. Bandwidth = 20 credits/GB (~15 GB). **When credits run out, all sites are paused until the next cycle** | Not addressed [U] |
| **Vercel Hobby** [V] | 100 GB fast data transfer | **Prohibited.** "Hobby teams are restricted to non-commercial personal use only." A paid gallery SaaS needs Pro |

**Recommendation [ANALYSIS]:** Cloudflare Pages for the SPA. For the API, use a Hetzner CX23 (predictable, 20 TB traffic) or Cloud Run (free at low volume). Fly.io is cheap but has no billing alerts. Avoid Render free and Vercel Hobby for production or commercial use.

Sources: <https://docs.cloud.google.com/free/docs/free-cloud-features> · <https://cloud.google.com/run/pricing> · <https://docs.fly.io/about/pricing> · <https://docs.fly.io/about/cost-management> · <https://render.com/docs/free> · <https://railway.com/pricing> · <https://docs.railway.com/reference/usage-limits> · <https://www.koyeb.com/pricing> · <https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/> · <https://www.hetzner.com/cloud/cost-optimized> · <https://developers.cloudflare.com/containers/pricing/> · <https://developers.cloudflare.com/pages/platform/limits/> · <https://docs.netlify.com/manage/accounts-and-billing/billing/billing-for-credit-based-plans/how-credits-work/> · <https://www.netlify.com/pricing/> · <https://vercel.com/docs/limits/fair-use-guidelines>

---

## 4. Image resizing

| Approach | Cost | Pros | Cons |
| --- | --- | --- | --- |
| **Generate at upload in Go, store in R2** (recommended **[ANALYSIS]**) | Storage only. 3 sizes (e.g. 400px, 1200px, 2048px) add about 3–5% on top of originals | Zero runtime cost, CDN- and cache-friendly, no lock-in | Upload job needs RAM. A 45 MP JPEG decoded with pure Go `image` uses about 180 MB. Use **libvips** (`govips` / `bimg`, CGO), cap concurrency, run as a background job |
| **Self-hosted imgproxy** on the same VM | Free (open source), uses VM CPU/RAM | On-demand sizes, fast (libvips) | First request is CPU-heavy. Needs a cache in front. **Sign URLs** (imgproxy key/salt), or anyone can make your server resize 25 MB files in a loop (denial of service) |
| **Cloudflare Images** (transform R2 images) [V] | Free: 5,000 unique transformations/month (beyond that, new ones error, no charge). Paid: $0.50 per 1,000 unique transformations | Zero ops | A: about 6,700 photos × 3 sizes ≈ 20k transforms ≈ $7.50/month in an upload month. **B: about 200k/month ≈ $97/month** |

Source: <https://developers.cloudflare.com/images/pricing/>

---

## 5. Worked monthly cost estimates

**[ANALYSIS]** The estimates in this section are calculations from the prices above. Assumptions: originals about 15 MB average. Thumbnails add about 5% storage. Scenario A uploads about 6,700 photos/month, B about 1 TB new uploads/month (~67k photos). Downloads go **directly from object storage via presigned URLs**. Zips are built in the browser or streamed from the VPS, so there is no duplicate zip storage. If you instead pre-build zips into R2, double the storage line. USD; €1 ≈ $1.17 [U]. Excludes VAT and domain.

### Combo 1: Hetzner VPS + SQLite/Litestream + Cloudflare R2 + Cloudflare Pages (recommended)

| Line | A (100 GB / 1 TB egress) | B (5 TB / 20 TB egress) |
| --- | --- | --- |
| Hetzner CX23 (A) / CX33 (B) + IPv4 | €6.0 ≈ $7.0 | €9.0 ≈ $10.5 |
| R2 storage (105 GB−10 free; 5.25 TB) | $1.43 | $78.6 |
| R2 ops (A: ~30k Class A, ~100k Class B; B: ~300k A, ~5M B) | $0 (in free tier) | $0 (in free tier) |
| R2 egress | $0 | $0 |
| Litestream backups in R2 | <$0.05 | <$0.10 |
| Pages | $0 | $0 |
| **Total** | **≈ $8.5/month** | **≈ $89/month** |

If zips are streamed **through the VPS** instead of from R2, B uses about 20 TB of the 20 TB included Hetzner traffic. That is still about $0 extra (~€1/TB over [U]).

### Combo 2: Serverless "near $0": Cloud Run + Neon Free + R2 + Pages

| Line | A | B |
| --- | --- | --- |
| Cloud Run (API only, photos never proxied) | $0 (free tier) | ~$0–10 [U: depends on traffic] |
| Neon | $0 (Free, 1 GB) | $0–10 (Launch, ~1–2 GB, low CU-h) |
| R2 storage | $1.43 | $78.6 |
| Pages | $0 | $0 |
| **Total** | **≈ $1.5/month** | **≈ $80–100/month** |

**Warning:** if the Go service streams zips or originals, Cloud Run egress (~$0.12/GB [U]) adds about **$120 (A)** or **$2,400 (B)** per month.

### Combo 3: Lowest storage $/GB: Hetzner VPS + Backblaze B2 (direct, no CDN)

| Line | A | B |
| --- | --- | --- |
| VPS | $7.0 | $10.5 |
| B2 storage | ~$0.66 | ~$36.5 |
| B2 egress (3× free = 315 GB / 15.75 TB) | 685 GB × $0.01 ≈ $6.9 | 4.25 TB × $10 ≈ $42.5 |
| **Total** | **≈ $14.5/month** | **≈ $90/month** |

Through Cloudflare (bandwidth alliance) egress drops to $0, but that carries the CDN terms risk for large images.

*Alternative to watch:* **Hetzner Object Storage** (base ~€5 including 1 TB storage + 1 TB egress [U]). B would be roughly €5 + 4.25 TB × ~€5 + 19 TB × ~€1 ≈ €45 ≈ **$53 + VPS ≈ $64/month**, but every price is pre-June-2026 and unverified.

### Reference (do not use)

| Stack | A | B |
| --- | --- | --- |
| AWS S3 Standard + internet egress [U rates] | ~$2.4 + ~$81 = **~$83** | ~$121 + ~$1,750 = **~$1,870** |
| Supabase Pro storage | $25 + 750 GB × $0.09 = **~$93** | $25 + $105 + 19.75 TB × $0.09 ≈ **~$1,900** |
| Wasabi | $7.99 (1 TB minimum), but egress 10× storage breaks the fair-use terms | $40, egress 4× storage breaks the fair-use terms |

---

## 6. Gotchas: data loss, commercial terms, surprise bills, caps

### Free tiers that pause or delete data

- **Supabase Free:** pauses after 7 days of inactivity. Your clients see a dead gallery until you click "resume". Restorable for 1 year (docs) or 90 days (2024 changelog).
- **Render Free Postgres:** **deleted 30 days after creation + 14-day grace.** Real client records vanish.
- **Aiven Free:** powered off after inactivity.
- **Neon Free:** suspends on limits but **keeps data**. Scales to zero, so expect a cold start.
- **D1 Free:** daily limit hit = **all queries blocked until 00:00 UTC.** One bulk import can take the app down for the day.
- **Netlify Free:** credits exhausted = **every site shows "Site not available"** until the next cycle.
- **Wasabi:** 90-day minimum retention. Delete a 1 TB gallery on day 10 and you still pay about 80 more days for it.

### Commercial-use restrictions

- **Vercel Hobby:** explicitly non-commercial. A paid photographer gallery violates it.
- **Render Free:** "Do not use them for production applications."
- Others (Cloudflare Pages, Neon, Netlify): nothing restrictive found on the pages read [U: read the ToS].

### Egress surprise bills: concrete scenarios

- **Zip streaming through the API container:** 50 zips × 20 GB = 1 TB. Free on R2 direct or Hetzner. **About $120 on Cloud Run** [U], about $50 on Railway, about $20 on Fly.
- **Leaked presigned URL or public bucket:** a client posts a "download all" link on a forum and 500 people download a 20 GB gallery, which is 10 TB. On R2 that costs $0 (only Class B ops). On S3 it is about $900. On B2 it is about $100 beyond the 3× allowance. **Mitigation [ANALYSIS]:** short presigned-URL expiry (e.g. 15 min to 24 h), issued per gallery password or session, buckets never public-listable, per-gallery download counters and rate limits.
- **Leaked S3 access key:** someone commits `.env` to GitHub and bots find it within minutes. They can then delete every client's photos, which is unrecoverable unless you have versioning or backups. Separately, they can turn your bucket into free hosting. **Mitigation [ANALYSIS]:** scoped keys (one bucket, minimal permissions), key rotation, object versioning or lifecycle, secrets kept out of the frontend bundle.
- **Unsigned imgproxy or resize endpoint:** a bot requests `/resize?w=1..5000` on 25 MB originals and pegs CPU. On Cloud Run or Containers that is billable autoscaling. On a VPS it means downtime.
- **Bulk operations snowball:** a "regenerate all thumbnails" or "delete gallery" job over 5 TB triggers hundreds of thousands of Class A ops, CPU hours, and Wasabi-style early-delete fees if applicable. Run on one gallery first and add a dry-run flag **[ANALYSIS]**.

### Spending caps and alerts per provider

The "What to set" column is **[ANALYSIS]**.

| Provider | Hard cap? | What to set |
| --- | --- | --- |
| Cloudflare (R2, Workers, Images) | No hard dollar cap [U] | Billing/usage notifications in dashboard [U]. Images free plan hard-stops at 5k transforms (no charge) [V] |
| Google Cloud Run | **No** [V]: budgets only alert | Budget alerts at 50/90/100%. `--max-instances`. Optionally a Pub/Sub-triggered function that disables billing [U] |
| AWS | No (Budgets alert, Budget Actions can attach deny policies) [U] | AWS Budgets + Cost Anomaly Detection |
| Fly.io | **No caps, no alerts** [V] | Check dashboard manually. Fixed machine counts |
| Railway | **Yes, hard limit** (min $10; stops all services) [V] | Email alert + hard limit above normal peak |
| Supabase | **Spend cap on by default** (Pro) [V] | Keep it on |
| Neon Free | Hard limits (suspends, data kept) [V] | Paid: usage alerts [U] |
| Backblaze B2 | "Caps & Alerts" for storage, download, transactions [U: from prior knowledge] | Set a daily download cap |
| Hetzner | Server price is capped monthly. Traffic overage billed [V/U] | Traffic alerts in console [U] |
| Vercel Pro / Netlify | Vercel spend management [U]. Netlify Free hard-stops (site paused) [V] | |

---

## Unverified items to re-check before deciding

- AWS S3 storage and egress rates (table didn't render). Cloud Run per-GB egress rate.
- Hetzner IPv4 price, traffic overage €/TB, Object Storage prices after June 2026. CX/CAX availability ("currently unavailable" on 2026-10-11).
- Cloudflare CDN terms on large-image serving (B2 + Cloudflare combo). Cloudflare billing alerts.
- Backblaze Caps & Alerts. Prisma Postgres direct TCP for `pgx`. Turso Go driver status. Koyeb free compute instance (no longer listed).
