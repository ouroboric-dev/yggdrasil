---
title: Delta for the gallery's product starting in the grader
status: accepted
date: 2026-10-22
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../realm-readiness.md]
style: spec
---

# Delta: v0 spec §6.1, §7.2, §9.3, §9.4 and §11, and the realm readiness checklist

**Amended 2026-10-23.** The founder answered the [proposal](proposal.md)'s questions, so the release lines are no
longer waiting. The product start and the services move to a runtime realm, `niflheim-local` (question 2, B-158);
the product's data folder is `/app/.data/` (question 4); an approval's note reaches later stages (finding F1). The
founder also confirmed, on 2026-10-23, the names `needs`, `provides` and `runtime`, the two needs, `DATA_DIR`, and
the name `s3` for the store's service.

## Added

### The runtime in the grader (§9.3)

- §9.3, "In the grader": the product MUST start from `/app/start.sh` in the task's image, with no network, as an
  ordinary user, and MUST serve everything on port 3000 on all interfaces within 2 minutes (`instruction.md` §6).
- §9.3: in the grader, the product MUST keep all its data, files and services' data under `/app/.data/`. The project's
  `.gitignore` MUST hold `.data/`, and nothing under it MUST be committed. A restart of `start.sh` in the same grading
  copy MUST find the data it left.
- §9.3: everything the browser loads MUST be served on port 3000, at the address the product was reached at. A
  presigned storage URL MUST use that address and the bucket's path (`/<S3_BUCKET>/<key>`).
- §9.3: the web leaf MUST forward a request whose path starts with `/<S3_BUCKET>/` to `S3_ENDPOINT` with its method,
  path, query and body unchanged and its `Host` header kept. That forward MUST NOT add an `X-Forwarded-*` header
  (SeaweedFS's signature check may read one before `Host`: to verify). It MUST forward a request whose path starts with `/api/`
  to `API_URL` without the `/api` prefix, with `X-Forwarded-Host` and `X-Forwarded-Proto` set from the request. It
  MUST answer any other path from the built bundle, with `index.html` for a path that names no file. The API MUST NOT
  serve the web app.
- §9.3: the API MUST build a public address (a presigned URL, a client link) from `X-Forwarded-Host` and
  `X-Forwarded-Proto` when the web leaf sets them.
- §9.3: the API MUST make its bucket at start when it is missing, with object versioning on when the store supports
  it. In the grading copy, a store without versioning is a deviation written in the run's report (proposal question 7:
  best effort).
- §9.3: the S3 store MUST refuse a request that carries no valid signature. Its key pair MUST be made at each start,
  MUST be kept only in the store's identity file under `/app/.data/` (readable by the product's user alone) and in
  the leaves' environment, and MUST NOT be written to git or to a log.
- §9.3: a reviewer MUST report an API that streams a photo's bytes or a zip of photos as a violation of "Photo bytes
  MUST NOT pass through the API".

### The runtime names and the release (§9.4)

- §9.4, the runtime names: an API leaf MUST read `PORT`, `HOST`, `DATABASE_URL`, `DATA_DIR`,
  `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID` and `S3_SECRET_ACCESS_KEY`. A web leaf MUST read `PORT`,
  `HOST`, `API_URL`, `S3_ENDPOINT` and `S3_BUCKET`. A leaf MUST NOT need any other variable to start. `DATA_DIR` is
  the only folder the API MAY write files in (a reset outbox, say); the product start sets it under `/app/.data/`.
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
- §9.5, rung 5 and the acceptance run: a Playwright spec MUST be told whether a real store is behind `/<S3_BUCKET>/`.
  The acceptance run MUST set `YGG_E2E_STORE=1`; the e2e rung MUST leave it unset. A spec MAY stub the store only when
  it is unset.

### The runtime realm, needs and the product start (§9.4, §6.1)

- §9.4, kinds of realm: a **runtime realm** (Niflheim; `niflheim-local` today, one machine with no cloud) provides no
  leaf and no stack. It MAY name services, MUST say which need each of them provides (`provides`, a need:
  a service of its own), and MAY name a product start script (`product.start`, a path inside the pack). A pack that
  names `leaf` MUST NOT name `provides` or `product`.
- §9.4, needs: a build realm MUST declare the services its leaves need as needs (`needs`), from the list
  `gungnir` holds: `postgres` ("a Postgres-compatible database") and `s3` ("an S3 API"). A build realm SHOULD NOT name
  services of its own; the readiness checklist checks it (RR-27).
- §9.4, the contract of a need, which the checks rely on: the provider of `postgres` MUST be the service `postgres` on
  port 5432, with a database `app`, the user `postgres` and no password; the provider of `s3` MUST be the service
  `s3`, its S3 API on port 8333 (SeaweedFS in `niflheim-local`). A need and its service share one name (the founder,
  2026-10-23). `helheim-go`'s checks and `midgard-react`'s acceptance run reach the store at `http://s3:8333`.
- §9.4, the runtime pin: a project MUST pin at most one runtime realm. The spec stage names it in
  `docs/leaves.yaml` (`runtime: {realm, realm_version}`), and Odin's `init` MUST record it in `umbrella.yaml`
  (`runtime` and `runtime_version`, both or neither), as it records each leaf's realm. Once recorded, a later run's
  leaves file MUST name the same pin or none.
- §6.1, a sandbox's services: Odin MUST start, beside a leaf's work container, the runtime realm's service for each
  need of the leaf's realm and of the realms of the leaves it consumes; and, in the sandbox of a snapshot, for each
  need of the realms of the project's leaves. A service keeps the name it has in the runtime realm's pack. A need that
  the project's runtime realm does not provide, or a need in a project that pins no runtime realm, MUST stop the run
  before any leaf is created or any leaf sandbox starts, with a message that names the need and the realm that has it.
  The node that reads the leaves file before `init` (`ready` in the `software` graph) MUST check it too. The scratch
  sandboxes of the design, spec and plan stages have run by then.
- §9.4, the product start: only the runtime realm MAY name a product start script. Odin's `init` node MUST write it at
  the project root as `start.sh`, executable, and commit it, and MUST add `.data/` to the project's `.gitignore`. No
  agent task MAY change the project root.
- §9.4: the product start script MUST find the leaves at `repos/api` and `repos/web`, the paths the spec stage
  requires, and MUST exit non-zero with a message when `repos/web` is missing. It MUST refuse to run as root; start
  Postgres and the S3 store from the task image, with their data under `/app/.data/`; start each leaf from
  `.ygg/release/<leaf>/run.sh`, or from `<leaf>/run.sh` when there is no release; give the API `DATA_DIR` under
  `/app/.data/`; give the web leaf `HOST=0.0.0.0` and `PORT=3000`; keep every other port on `127.0.0.1`; exit non-zero
  with a message naming the part when a part does not start; and stop every part when it is stopped.
- §11, the grader image's services: a task image that bakes in services MUST bake in the versions of the runtime realm
  the factory's projects pin: the same SeaweedFS image digest, and the same Postgres major version. The minor MAY
  differ. `ouroboric`'s `check-repos.sh --check services` MUST compare them, and the Postgres image of a build realm's
  template CI, and MUST fail on a difference.

### The approval's note (§7.2)

- §7.2: the note of an approval at a gate node MUST be kept in the run's state with the gate it was given at; a note
  given when approving another stop (a loop that gave up, `policy-violation`, `shrink-guard`) MUST NOT be. A note
  MUST be one line: Odin MUST refuse a note with a control character. Every agent session that
  starts after the approval (an agent or scratch node, an implementer, a reviewer) MUST get every note kept so far in
  its prompt, after the brief, under the heading "The product owner's decisions", in the order the approvals were
  given, each with its gate.
- §7.2: a rejection that sends the run back to a node before a gate MUST drop the notes of the gates between that node
  and the rejecting gate, because the run meets those gates again. A resumed run MUST keep the notes.
- §7.2: an approval with no note MUST add nothing to later prompts.

### The release at export (§11)

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

### The realm readiness checklist

- A new kind of realm, `runtime`: "a realm that provides services and the product start. It has no stack, template or
  ladder."
- **RR-24** (build): "Does the template ship an executable `release.sh`, and does a test build the release from a copy
  of the template and start `OUT/run.sh` with no build tool on the `PATH`?" Check: auto,
  `YGG_REQUIRE_TEMPLATES=1 go test -run ReleaseScript ./...` in the leaf.
- **RR-25** (runtime): "Does the product start script start the services and the leaves of a product made from the
  templates, and serve port 3000 on all interfaces?" Check: auto, `go test -run ProductStart ./...` in the leaf, and
  `ygg-smoke-runtime.sh` in the task image.
- **RR-26** (runtime): "Does the pack provide every need of the build realms, with each service pinned by digest, and
  does every task image that bakes in services hold the same versions?" Check: auto, `go test -run Pack ./...` in the
  leaf, and `check-repos.sh --check services`.
- **RR-27** (build): "Does the pack declare its needs, and name no service of its own?" Check: auto,
  `go test -run Pack ./...` in the leaf.

## Modified

- §9.3, "Photo bytes MUST NOT pass through the API or Vercel" gains: "In grading, photo bytes pass through the web
  leaf's forward on port 3000, because the brief asks for one port. They still never pass through the API. Production
  stays direct between the browser and storage."
- §9.3, "Storage keys: MUST be bucket-scoped. Object versioning MUST be on." gains: "In the grading copy, the API makes
  the bucket at start; versioning is on when SeaweedFS supports it (best effort)."
- §9.3, the table of concerns gains a third column, **Grading (the task image)**: Web, the web leaf's release on port
  3000, all interfaces; API, the API's release on `127.0.0.1`; Database, Postgres 18 from the image, data under
  `/app/.data/`; Photos, SeaweedFS from the image, its S3 API on `127.0.0.1`, reached by the browser through port 3000.
- §9.3, the "Development (in the sandbox)" column: Database, "Postgres container", becomes "the runtime realm's
  Postgres 18 container (`niflheim-local`)"; Photos, "SeaweedFS (S3 API)", becomes "the runtime realm's SeaweedFS
  4.45 (S3 API)".
- §6.1, "Each run gets one rootless container per leaf, plus the realm's services (§9.3) via compose" becomes "plus
  the runtime realm's services for the needs of the leaf's realm and of the realms of the leaves it consumes (§9.3,
  §9.4), via compose". The rule that two realms offering a service of the same name must offer it alike stays, for a
  pack that still names services.
- §9.4, the leaf run contract: `run.sh` listens on `HOST` when it is set. When it is not, a leaf listens where it does
  today: the web leaf on `127.0.0.1`, the API on all interfaces.
- §9.4, the pack layout line for `templates/`: "api and web leaf starters: lint/test/e2e config, AGENTS.md, init.sh,
  run.sh" gains `release.sh`, and a line for a runtime realm's `templates/product/`: the product start script.
- §9.4, the pack layout: the `pack.yaml` line, "name, version, default roles/models, check commands", gains "a build
  realm's `needs`"; the `devcontainer/` line, "stack layer (Dockerfile, devcontainer.json, compose services)", loses
  "compose services". A second block shows a runtime realm: `pack.yaml` (name, version, `services`, `provides`,
  `product.start`) and `templates/product/start.sh`.
- §9.4, last sentence: "The root `start.sh` that the grader runs belongs to a later infra realm." becomes "The root
  `start.sh` that the grader runs is the product start script of the project's runtime realm (`niflheim-local`
  today)."
- §7.2, "Decide": "`ygg reject <run> <gate> --reason …` sends the reason back into the previous node as input" gains
  "The note of an approval reaches every later stage as the product owner's decisions."
- §11, "graders MUST run in their own container, against the built app, after the agent containers have stopped"
  gains "and after the release sandbox has stopped".

## Removed

None in the spec. Outside it, `helheim-go/pack.yaml` loses its `services:` block: `niflheim-local` names them.

## Outside the spec

- `mimir/client-gallery-lite` 4.1.0 replaces 4.0.0 in place: the same `instruction.md` and brief hash, `suite = "v2"`;
  the image adds PostgreSQL 18 and SeaweedFS 4.45 on the `PATH` of the user `app`, and nothing else. 4.0.0 stays in
  `mimir`'s history, and the README lists both. The founder makes the version (`mimir/AGENTS.md`).
- `niflheim-local`'s `postgres` service is `postgres:18.x` by digest, so that the realm's sandbox and the grading image
  share a Postgres major. The spec names no Postgres version.
- The founder's five product decisions are product input, not factory spec: the proof-runs runbook holds them, and
  every proof run gives them word for word.
- The hidden suite is not changed by this delta. The founder keeps `v2` for 4.1.0.
