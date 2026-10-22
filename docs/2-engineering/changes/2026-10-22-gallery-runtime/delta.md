---
title: Delta for the gallery's product starting in the grader
status: draft
date: 2026-10-22
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../realm-readiness.md]
style: spec
---

# Delta: v0 spec §9.3, §9.4 and §11, and the realm readiness checklist

The lines about the release (§9.4's release contract, §11's release at export, RR-24) are assumed and wait for the
founder's answer to question 1 of the [proposal](proposal.md). The rest follows from option A and the answers the
proposal assumes.

## Added

- §9.3, "In the grader": the product MUST start from `/app/start.sh` in the task's image, with no network, as an
  ordinary user, and MUST serve everything on port 3000 on all interfaces within 2 minutes (`instruction.md` §6).
- §9.3: everything the browser loads MUST be served on port 3000, at the address the product was reached at. A
  presigned storage URL MUST use that address and the bucket's path (`/<S3_BUCKET>/<key>`).
- §9.3: the web leaf MUST forward a request whose path starts with `/<S3_BUCKET>/` to `S3_ENDPOINT` with its method,
  path, query and body unchanged and its `Host` header kept. That forward MUST NOT add an `X-Forwarded-*` header
  (SeaweedFS's signature check may read one before `Host`: to verify). It MUST forward a request whose path starts with `/api/`
  to `API_URL` without the `/api` prefix, with `X-Forwarded-Host` and `X-Forwarded-Proto` set from the request. It
  MUST answer any other path from the built bundle, with `index.html` for a path that names no file.
- §9.3: the API MUST build a public address (a presigned URL, a client link) from `X-Forwarded-Host` and
  `X-Forwarded-Proto` when the web leaf sets them.
- §9.3: the API MUST make its bucket at start when it is missing, with object versioning on when the store supports
  it. In the grading copy, a store without versioning is a deviation written in the run's report (proposal question 7).
- §9.3: the S3 store MUST refuse a request that carries no valid signature. Its key pair MUST be made at each start,
  MUST be kept only in the store's identity file under `/app/.data/` (readable by the product's user alone) and in
  the leaves' environment, and MUST NOT be written to git or to a log.
- §9.4, the runtime names: an API leaf MUST read `PORT`, `HOST`, `DATABASE_URL`, `S3_ENDPOINT`, `S3_REGION`,
  `S3_BUCKET`, `S3_ACCESS_KEY_ID` and `S3_SECRET_ACCESS_KEY`. A web leaf MUST read `PORT`, `HOST`, `API_URL`,
  `S3_ENDPOINT` and `S3_BUCKET`. A leaf MUST NOT need any other variable to start.
- §9.4, the release contract: a build realm's template MUST hold an executable `release.sh` at the leaf's root. Run
  in the leaf with `OUT` set to an empty folder, it MUST write into `OUT` everything the leaf needs to start with no
  network and no tool beyond the task image, and an executable `OUT/run.sh` that keeps the leaf run contract (`PORT`,
  `HOST`, 60 seconds, a message on failure). It MAY fetch packages through the realm's egress. It MUST write only
  regular files and folders, MUST NOT read a secret, and MUST NOT write outside the leaf, `OUT` and the temporary
  folders. A build realm's tests MUST run `release.sh` on a copy of the template and start `OUT/run.sh` with no
  build tool on the `PATH` (no Go, no `npm`) and no installed packages.
- §9.4, the acceptance run: it MUST give the API every name of the runtime, with the sandbox's SeaweedFS as the S3
  store, and MUST serve the web leaf with the realm's own copy of the web server, which forwards `/api/` and
  `/<S3_BUCKET>/` as above. The leaf's copy MUST NOT be the one the acceptance run uses.
- §9.4, the product start: a realm MAY name a product start script in `pack.yaml` (`product.start`, a path inside the
  pack). At most one realm of a project MAY name one. Odin's `init` node MUST write it at the project root as
  `start.sh`, executable, and commit it, and MUST add `.data/` to the project's `.gitignore`. No agent task MAY change
  the project root.
- §9.4: the product start script MUST find the leaves at `repos/api` and `repos/web`, the paths the spec stage
  requires, and MUST exit non-zero with a message when `repos/web` is missing. It MUST refuse to run as root; start
  Postgres and the S3 store from the task image, with
  their data under `/app/.data/`; start each leaf from `.ygg/release/<leaf>/run.sh`, or from `<leaf>/run.sh` when there
  is no release; give the web leaf `HOST=0.0.0.0` and `PORT=3000`; keep every other port on `127.0.0.1`; exit non-zero
  with a message naming the part when a part does not start; and stop every part when it is stopped.
- §11: when Odin exports `/app` (`ygg grade`, `ygg bridge`), it MUST build the release of each leaf that has a
  `release.sh`: in the project's acceptance sandbox, on a snapshot of the commits it exports, with no agent and no
  secret. It MUST place each release at `/app/.ygg/release/<leaf>/` and MUST NOT commit it. It MUST stop that sandbox
  before the grader starts.
- §11: a release MUST have its own bound, named in the code, and MUST NOT be held to the snapshot's limits for source
  (32 MiB per file, 256 MiB in all), which a static Go binary can come near.
- §11: a release that fails, times out, holds anything but regular files and folders, or passes its bound MUST fail
  the grade (`GradeFailed`, no `score.json`, a resume grades again). It MUST NOT count as a score of 0.
- §11: Odin MAY keep a release in the run folder by the commits it was built from, and reuse it for an export of the
  same commits.
- §11: a task version MAY add services to its image while its brief and brief hash stay the same. `score.json`
  already names the task version, which says which image graded the product.
- Realm readiness checklist: **RR-24** (build): "Does the template ship an executable `release.sh`, and does a test
  build the release from a copy of the template and start `OUT/run.sh` with no build tool on the `PATH`?" Check:
  auto, `YGG_REQUIRE_TEMPLATES=1 go test -run ReleaseScript ./...` in the leaf.
- Realm readiness checklist: **RR-25** (build, a realm that names `product.start`): "Does the product start script
  start the services and the leaves of a product made from the templates, and serve port 3000 on all interfaces?"
  Check: auto, `YGG_REQUIRE_TEMPLATES=1 go test -run ProductStart ./...` in the leaf, and `ygg-smoke-runtime.sh` in the
  task image.

## Modified

- §9.3, "Photo bytes MUST NOT pass through the API or Vercel" gains: "In grading, photo bytes pass through the web
  leaf's forward on port 3000, because the brief asks for one port. They still never pass through the API. Production
  stays direct between the browser and storage."
- §9.3, "Storage keys: MUST be bucket-scoped. Object versioning MUST be on." gains: "In the grading copy, the API makes
  the bucket at start; versioning is on when SeaweedFS supports it (to verify)."
- §9.3, the table of concerns gains a third column, **Grading (the task image)**: Web, the web leaf's release on port
  3000, all interfaces; API, the API's release on `127.0.0.1`; Database, Postgres 17 from the image, data under
  `/app/.data/`; Photos, SeaweedFS from the image, its S3 API on `127.0.0.1`, reached by the browser through port 3000.
- §9.4, the leaf run contract: `run.sh` listens on `HOST` when it is set. When it is not, a leaf listens where it does
  today: the web leaf on `127.0.0.1`, the API on all interfaces.
- §9.4, the pack layout line for `templates/`: "api and web leaf starters: lint/test/e2e config, AGENTS.md, init.sh,
  run.sh" gains `release.sh`, and a line for `templates/product/`: the product start script of a realm that names one.
- §9.4, last sentence: "The root `start.sh` that the grader runs belongs to a later infra realm." becomes "The root
  `start.sh` that the grader runs is the product start script of the realm that names one (`midgard-react` today). An
  infra realm may take it over later."
- §11, "graders MUST run in their own container, against the built app, after the agent containers have stopped"
  gains "and after the release sandbox has stopped".

## Removed

None.

## Outside the spec

- `mimir/client-gallery-lite` 4.1.0: the same `instruction.md` and brief hash; the image adds PostgreSQL 17 and
  SeaweedFS 4.45 on the `PATH` of the user `app`, and nothing else. The founder makes the version (`mimir/AGENTS.md`).
- The hidden suite is not changed by this delta. Which suite scores 4.1.0 is the founder's decision.
