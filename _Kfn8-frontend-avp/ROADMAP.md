# Kfn8 Implementation Roadmap

> Execution: use the executing-plans workflow task by task. Routine approval pauses were waived by the founder on 2026-09-19. Feasibility failures and missing external dependencies still stop dependent work.

**Goal:** deliver the agreed anonymous, indoor visionOS 27 MVP1 with measured spatial accuracy, durable local Designs and a validated generic catalogue.
**Architecture:** Swift 6/SwiftUI/RealityKit/ARKit with SwiftData domain records and local files; separate async FastAPI/Postgres catalogue and private operator ingestion; published assets from Spaces CDN.
**Spec:** [TECHNICAL-PLAN.md](TECHNICAL-PLAN.md), [PRD.md](PRD.md), [SALIENT-NOTES.md](SALIENT-NOTES.md), interview Q1–Q55.

> Status legend: ⬜ not started · 🟡 in progress · ✅ done · ⏸️ blocked/deferred · 🟢 verified on-device

## Repository maintenance

✅ Root `.gitignore` consolidated for Swift/Xcode, Python and local configuration; redundant client ignore file removed. Source assets, shared project configuration and evidence remain versionable. Only the parent `.git` remains. Plan/PRD/README now describe one monorepo. No Git commands were run in this review; tracked-file state and branch identity were not inspected. Existing readiness tests: 8 passed; legacy project file syntax: valid. These housekeeping results do not close device-gated milestone tasks.

## Tracking rules

Exactly seven Epics map one-to-one to M0, M1, M2, M3, M4, M6, M7. M5 and v1.1 work are excluded, not hidden in future tasks. IDs: E{milestone}.S{story}.T{task}. Assign a status to every Epic, Story and Task. Mark ✅ only when its acceptance evidence exists; reserve 🟢 for completed acceptance verified on a physical headset, with device/build and evidence linked in the milestone report. Record actual commands/results, build/commit IDs and demo evidence in `reports/M{n}-FINDINGS.md`. Mark ⏸️ when a concrete blocker or deliberate deferral prevents progress, and name the dependency. Future work awaiting the normal milestone sequence stays ⬜; dependency order alone does not mean work has started. Use 🟡 for partially implemented work that is still progressing. An Epic or Story is complete only when every required child and its acceptance criteria are complete; device-dependent acceptance cannot close on tooling tests alone. Update task statuses, Story/Epic rollups, the status table and progress snapshot in the same change as implementation or new verification evidence. Preserve evidence links and record blockers when they change. Estimates are effort, not deadlines.

Global constraints apply to every task: visionOS 27 only, Swift 6 strict concurrency, no older-OS branch, AVP only, indoor Mixed Immersive Space, no account/sync/paywall/telemetry/geometry upload, no queue/worker/tenant frontend, no generated named-SKU geometry, no UI purple/indigo/cyan. Asset revisions immutable; mesh contract ±1% across all representations. Accessibility built inline. No silent stubs; any unavoidable incomplete code gets `TODO(kfn8)` and is reported, never counted done.

## Progress snapshot

Last updated: 2026-09-19. **71 tasks: 66 ⬜ not started · 1 🟡 in progress · 2 ✅ done · 2 ⏸️ blocked/deferred · 0 🟢 verified on-device.** Counts cover Tasks only, not Story/Epic rollups.

Completed: repository/toolchain inspection and readiness tooling (8 tests passed). Partial work: readiness findings report and remaining M0 setup. Current blocker: Xcode 27 licence acceptance; no headset tests have run. Evidence: [M0 findings](reports/M0-FINDINGS.md), [readiness command output](reports/M0-READINESS.json). Earlier nested-repository commit IDs are historical only; that metadata was removed at the founder’s request. They are not revisions in the parent monorepo.

## Status / critical path

| Epic | Milestone | Status | Effort estimate | Exit dependency |
|---|---|---|---|---|
| E0 | M0 Feasibility | ⏸️ blocked — Xcode 27 licence | 3–7 days | Accepted Xcode 27 licence, signing, M2 measurements |
| E1 | M1 Scan and place | ⬜ not started | 3–5 weeks | All three blocking M0 probes pass |
| E2 | M2 Catalogue | ⬜ not started | 2–3 weeks | M1, cloud access, paired contract/client build |
| E3 | M3 Designs | ⬜ not started | 2–3 weeks | M2 and export feasibility decision |
| E4 | M4 Realism | ⬜ not started | 2–4 weeks | Representative launch assets, M3 |
| E6 | M6 Private ingestion | ⬜ not started | 2–3 weeks | Earlier contract/import foundation, M4 |
| E7 | M7 Release | ⬜ not started | 1–2 weeks + external review | All preceding evidence, launch library |

External dependencies: Xcode 27 toolchain/signing/headset readiness gates M0; launch-library budgeting/acquisition follows M0 and gates E4/performance/release. Do not mistake the four low-poly fixtures for a launch library. M2/M6 completion records the monorepo revision when a commit is explicitly authorised, component build IDs and contract hash; the milestone report is not evidence that the backend was deployed.

## ⏸️ Epic E0 — M0: prove the platform

### ⏸️ E0.S1 — Reproducible development readiness

As the operator, I can determine why the exact supported toolchain/device is or is not ready.

- ✅ E0.S1.T1 Inspect both source documents, interview decisions, repository status and installed toolchains; record paths/version evidence without altering global Xcode selection.
- ✅ E0.S1.T2 Implement `tools/check_m0_readiness.py` and tests: explicit developer directory, Xcode version, device/simulator SDKs, Swift 6+, command errors/timeouts, fail-closed exit code, explicit device-evidence warning. Test valid/wrong SDK, licence refusal, missing executable and timeout. Capture a real run in the M0 report.
- ⏸️ E0.S1.T3 Complete founder's Xcode licence review/acceptance, first-launch components, signing and M2 pairing; verify a signed visionOS 27-only build deploys. No automated agreement acceptance. **Blocked:** Xcode 27 SDK listing exits 69 until the founder reviews/accepts its licence; signing and M2 deployment remain unverified.
- ⏸️ E0.S1.T4 Set up client/backend component boundaries inside the existing `kfn8` monorepo; retain source/assets/screenshots and use shared root ignore rules. Await the founder’s source-directory rename, then set up the Swift 6 strict-concurrency M0 target. **Partial / blocked:** nested client `.git` removed; monorepo rules and documents corrected. Source-folder spelling and Swift target remain unresolved; SDK build validation awaits E0.S1.T3. No nested repositories or Git operations without explicit approval.

Acceptance: readiness reports actual command failures; signed build runs on M2. Tools passing in isolation does not complete this story.
Demo: run readiness command with Xcode 27; inspect SDK/version evidence; launch signed probe on headset.

### ⬜ E0.S2 — Blocking spatial-capability evidence

- ⬜ E0.S2.T1 Read exact installed SDK declarations and Apple samples for physical-space lighting, Environment Occlusion and ManipulationComponent; record public API names and permissions in report. Fail rather than invent APIs.
- ⬜ E0.S2.T2 Implement minimal nonshipping Mixed Immersive probe with Swift Testing for its pure control state; build device/simulator configurations with strict concurrency and no shims.
- ⬜ E0.S2.T3 Measure virtual lamp contribution on a real wall/floor: recorded room/light setup, on/off comparison, capture/numerical evidence and frame behavior. No appearance-only assertion.
- ⬜ E0.S2.T4 Walk a virtual object behind real furniture and inspect occlusion edges while turning/moving; record repeatable artifacts, not just static screenshots.
- ⬜ E0.S2.T5 Exercise direct/indirect manipulation, all four attachment policies, invalid-release continuation without re-grab, cancel, and volume handoff; capture expected/observed behavior.
- ⬜ E0.S2.T6 For any failure allow one minutes-long obvious-setup check; if unresolved, document options/costs and STOP before M1. Do not write a fallback renderer/gesture system.

Acceptance: three capability gates have device evidence and meet intended behavior; persistent quality shortfall is a failure, not “partial pass”.
Demo: founder executes T3–T5 on M2 with probe build ID and returns local traces/observations.

### 🟡 E0.S3 — Bounded nonblocking investigations and findings

- ⬜ E0.S3.T1 Test an actual passthrough-plus-placements export: write file, open file, inspect real room pixels, permissions and distribution restrictions. Record unavailable rather than substitute furniture-only image.
- ⬜ E0.S3.T2 Spend only a few minutes on the approved Postshot candidate: obtain an ingestible file quickly or record “no readily available splat asset in a RealityKit-ingestable form”; one attempt, no debugging/search/conversion project. If it works record bytes/load time/frame behavior alongside meshes; note ~2M size and v1.1 conversion implication.
- 🟡 E0.S3.T3 Complete `reports/M0-FINDINGS.md` with exact versions, methodology, measurements, captures, separate blocking/nonblocking outcomes and M1 go/no-go. Export limitation requires a product scope decision before M3, not an M0 failure. **Progress:** readiness findings are written; device measurements and final M0 conclusions are not yet available.

Exit: E0.S1/S2 accepted by evidence, S3 findings recorded. No routine sign-off pause, but founder decisions remain required for unresolved product/platform failures.

## ⬜ Epic E1 — M1: scan, attach and preserve a room

### ⬜ E1.S1 — First four assets and early contract gate

- ⬜ E1.S1.T1 Acquire only approved chair/sconce/pendant/vase; record source/licence/author/attribution/evidence and dimension authority for each in backend ledger. No launch-library purchases.
- ⬜ E1.S1.T2 Establish backend-owned `contracts/v1/asset.schema.json`, contract document, minimal ledger/approval migrations and validator CLI; tests reject missing evidence, wrong units/pivot/orientation, malformed data, dimension drift and texture/triangle overages.
- ⬜ E1.S1.T3 Conform four meshes, produce GLB master/LODs/USDZ, verify ±1% dimensions against declared spec across formats, record approvals. Fail unsupported conversion rather than ship a placeholder.
- ⬜ E1.S1.T4 Bundle four verified placement renditions and manifests; CI validates same manifests/bytes. Keep the splat out of the shipping bundle and mesh gate.

Acceptance: exactly four functional engineering models cover all affinities with traceable evidence and validator reports.
Demo: inspect each item's source/licence, dimensions and variant/rendition manifest; deliberately corrupt a copy and observe rejection.

### ⬜ E1.S2 — Durable domain and local files

- ⬜ E1.S2.T1 Add Sendable domain values, repository protocols and explicit persistence actor/ModelContext isolation. Swift Testing verifies completed-edit counter, immutable revision references and rigid transforms.
- ⬜ E1.S2.T2 Implement SwiftData Space/Room/Design/Placement records plus file references; no CloudKit. Integration tests create/open/restart a real temporary store and verify schema migration baseline.
- ⬜ E1.S2.T3 Implement atomic completed-edit saves, surfaced save failures and interrupted-drag recovery; test failed write preserves committed state. No revision-history table.
- ⬜ E1.S2.T4 Implement counted permanent-delete confirmation and restart-safe file deletion journal; verify actual scan removal and surviving Design references. No trash/archive.

Acceptance: terminated sessions recover committed state; files and records remain consistent; sensitive records never uploaded.
Demo: save placement, terminate/relaunch, delete Room with another Room sharing an asset, inspect retained asset and removed scan.

### ⬜ E1.S3 — Capture and verified room recovery

- ⬜ E1.S3.T1 Implement permission-aware capture/classification for floor/wall/ceiling/horizontal support, coverage feedback and local file storage. Preserve structured elements returned by the same scan without UI/features.
- ⬜ E1.S3.T2 Establish floor/wall-derived room frame and separate session alignment/world anchor; test transform composition and reattachment without modifying placement transforms.
- ⬜ E1.S3.T3 Implement bounded guided alignment, then same-Room rescan or content-only review. Verify ambiguity does not display false positioning; no separate new-device flow.

Acceptance: same Room survives lost anchor without lost Designs; review has no clearances or passthrough composition.
Demo: save in a room, return/relocalize, force missing alignment and exercise both recovery choices.

### ⬜ E1.S4 — Affinity-driven manipulation and accessible shell

- ⬜ E1.S4.T1 Implement Window/Volume/Mixed scene ownership, Showroom tokens/fonts/licences and deterministic preview fit; pure tests cover oversized and 1:1 previews.
- ⬜ E1.S4.T2 Implement one attachment policy system, mounting metadata separate from pivot, permanent placement scale 1; verify real wall asset, pendant, chair and vase on device.
- ⬜ E1.S4.T3 Implement hard real collision / soft virtual overlap / rug exemption, continuous cue, validated ≤25cm release resolution and unsaved invalid preview. Test multi-obstacle/ceiling constraints; device-test the M0-proven input path.
- ⬜ E1.S4.T4 Add non-gesture placement/move/rotate/cancel controls; check VoiceOver reachability, Dynamic Type clipping and reduced-motion alternatives in the same demo.
- ⬜ E1.S4.T5 Record M1 report and component build IDs and contract hash. Demonstrate one actual asset per affinity persisted across a session; no cube-only acceptance.

Exit/demo: scan → place all four → move/cancel → save/relaunch → lose alignment/recover → delete, with no older-OS branch or geometry upload.

## ⬜ Epic E2 — M2: anonymous catalogue and reliable offline assets

### ⬜ E2.S1 — Versioned API and database

- ⬜ E2.S1.T1 Add SQLAlchemy/Alembic tables from plan §6, constraints/indexes, public-read filtering and private operator credentials. Real Postgres tests reject inconsistent tenant/revision/approval rows.
- ⬜ E2.S1.T2 Implement `/v1/catalogues`, assets/filter/search/detail/revision and health routes, stable opaque pagination, structured errors and nullable offers; no user accounts or Design routes.
- ⬜ E2.S1.T3 Export pinned OpenAPI contract, generate Swift transport models and map to domain; CI detects schema drift and incompatible changes. Add contract round-trip/error decoding tests.

Acceptance: anonymous clients can see published public assets only; unknown/private/revoked resources have defined errors; v1 schema is reproducible.
Demo: query facets/pages, verify no duplicates, query a private asset, consume same response using generated client.

### ⬜ E2.S2 — Storage, delivery and cache

- ⬜ E2.S2.T1 Configure smallest fixed App Platform, Managed Postgres and private/public Spaces separation; record actual provisioning/credentials prerequisites. FastAPI never proxies bytes; reject restricted publication.
- ⬜ E2.S2.T2 Implement immutable content-addressed/revision-qualified publication and CDN URLs, byte size/hash metadata, conditional writes; verify real Spaces smoke delivery.
- ⬜ E2.S2.T3 Implement streamed downloads/checksum/atomic install, reference-counted revision/LOD pins and unreferenced LRU; test corruption, interrupted downloads, duplicate Designs and insufficient storage.
- ⬜ E2.S2.T4 Implement cursor revocation deltas and client durable apply/cursor advancement; launch/foreground/infrequent opportunity checks, no heartbeat. Test offline behavior, mid-session retention and next-load absence marker.
- ⬜ E2.S2.T5 Implement verified origin removal/CDN purge for rights revocation; commercial delisting only changes offer metadata. Test deletion/purge partial failures and retry.

Acceptance: saved Design assets remain offline; revoked active scene is not yanked; later load indicates exact missing item without substitution.
Demo: download → disconnect → load → corrupt/recover → rights revoke → reconnect → reload; repeat with commercial delisting to prove difference.

### ⬜ E2.S3 — Operations and end-to-end release pair

- ⬜ E2.S3.T1 Enable server request/latency/error/download-volume telemetry without client usage SDK or event endpoint; redact credentials and sensitive payloads.
- ⬜ E2.S3.T2 Record baseline + storage/egress estimates; configure billing notification at 125% of estimated total, verify setting without inducing spend. No autoscaling/replicas/worker.
- ⬜ E2.S3.T3 Run full ingest/publish/generated-client/download/offline/revocation E2E; record monorepo revision if authorised, contract hash and component/deployment build IDs. Do not call local S3 tests a CDN test.

Exit: deployable catalogue + client integration, component build IDs, explicit untaken deployment steps if access is missing.

## ⬜ Epic E3 — M3: compose, compare and inventory

### ⬜ E3.S1 — Saved Designs and ordinary edits

- ⬜ E3.S1.T1 Implement name/autosave/duplicate with new IDs and shared revision references; no history/conflict/sync features. Tests prove independence and pin lifetime.
- ⬜ E3.S1.T2 Implement session undo/redo, variant changes and atomic A/B switch after loading; keep old composition until next ready. Test failed loads/edits and explicit update acceptance.
- ⬜ E3.S1.T3 Offer asset updates per Design with change summary, never automatic; unavailable-item action can accept a newer revision. Test committed edit/version/pin transition.

Acceptance/demo: duplicate a furnished room, edit five items, flip with gesture and button, cancel invalid placement, undo/redo and relaunch with last committed arrangement.

### ⬜ E3.S2 — Inventory and honest pricing

- ⬜ E3.S2.T1 Build default unpriced inventory: quantities/dimensions, no fabricated prices/links, no subtotal if all unpriced.
- ⬜ E3.S2.T2 Build priced path using test-only synthetic offers: independent refresh, dated cached prices, conditional “priced items only”, collapsed/ranged dates, unavailable status, retailer handoff; separate currency totals.
- ⬜ E3.S2.T3 Add Swift tests for generic-only/mixed/priced, partial refresh, multi-day dates, currency and delisting combinations. Device demo includes accessibility checks.

Acceptance: generic-only library reads as a complete inventory, not an error state; no bare stale prices.

### ⬜ E3.S3 — Conditional still export

- ⬜ E3.S3.T1 Resolve M0 export outcome before coding. If restricted/unavailable, founder decides re-scope; do not silently mark exported imagery complete or substitute furniture-only render.
- ⬜ E3.S3.T2 If supported, implement explicit home-image consent and local save/share, no watermark/automatic upload; exercise denial/cancel/write failure.
- ⬜ E3.S3.T3 Open real exported file on device and inspect room+placements; record M3 findings and evidence of zero client analytics/geometry transfer.

Exit: Designs/inventory acceptance plus actual export evidence or explicit documented scope decision. No portable data export/restore.

## ⬜ Epic E4 — M4: believable rendering under representative load

### ⬜ E4.S1 — Representative assets and realism

- ⬜ E4.S1.T1 After M0, obtain separate launch-library budget/acquisition decision; secure representative conformed models at real LOD/texture costs. Do not buy assets without that decision.
- ⬜ E4.S1.T2 Verify PBR conversions/material variants/contact shadows/physical lighting/occlusion against source evidence in repeatable room conditions. Fix assets rather than hiding contract violations.
- ⬜ E4.S1.T3 Implement conservative clearance readings, precision/ranges and explicit insufficient-scan guidance. Validate against observed reference distances for engineering QA; no user calibration requirement or fit verdict.

Acceptance: documented real-room comparisons with specific defects resolved; no daylight scrub or production splats.

### ⬜ E4.S2 — M2 performance evidence

- ⬜ E4.S2.T1 Instrument frame-time distribution/missed frames/CPU-GPU/memory/texture residency/load times locally; no telemetry upload.
- ⬜ E4.S2.T2 Tune measured LOD thresholds/hysteresis, draw calls/texture residency and per-frame allocations with actual representative assets, staying within contract.
- ⬜ E4.S2.T3 Run 20 mixed placements + two active virtual lights for 15 continuous minutes walking/turning/entering-leaving view on M2. Report p50/p95/p99/max, spikes, dropped frames and memory; target 90 Hz and zero drops.
- ⬜ E4.S2.T4 Record M4 report; if target missed, report measured bottleneck and remediate within agreed requirements, never claim an average-only pass or assume M5 evidence.

Exit/demo: replay named movement route and inspect local traces alongside scene manifest; four repeated low-poly fixtures are not acceptable proof.

## ⬜ Epic E6 — M6: private resumable catalogue production

### ⬜ E6.S1 — Durable staged operator ingestion

- ⬜ E6.S1.T1 Extend earlier validators/importer into invocation-independent stages with Postgres running/passed/failed records, input fingerprints, tool versions and actionable reports. No queue or hosted worker.
- ⬜ E6.S1.T2 Implement resume/invalidation, per-revision lock and constrained converter subprocess limits; test crash between stages, rerun, changed input and malformed source.
- ⬜ E6.S1.T3 Bind separate provenance and visual/dimension approvals to exact revision evidence, approver/time/hash. All assets require both at launch; no sampling reduction yet.
- ⬜ E6.S1.T4 Exercise private source → conversion/LODs → every-format gate → approvals → immutable publish; failed/rejected/in-review assets never enter public storage.

Acceptance/demo: deliberately fail stage, inspect report, correct source, resume, reject missing approval, approve with evidence and publish twice without duplicates.

### ⬜ E6.S2 — Batch readiness and removal evidence

- ⬜ E6.S2.T1 Run representative multi-asset batch and capture per-stage timing, failure/pass counts and idempotency results. No enterprise dashboard.
- ⬜ E6.S2.T2 Verify rights revocation end to end through operator command, origin absence, CDN purge and client next-load state; keep delisting distinct.
- ⬜ E6.S2.T3 Record backend/client build IDs and authorised monorepo revision if available and approval/validation outputs in M6 report; operator documentation covers retries and credential handling.

Exit: a single operator can build the library reproducibly, with recorded approvals and no tenant auth/feed connector/queue infrastructure.

## ⬜ Epic E7 — M7: TestFlight and MVP1 launch

### ⬜ E7.S1 — Release candidate and founder demos

- ⬜ E7.S1.T1 Resolve consumer release name before TestFlight without reopening other deferred §19 decisions; verify signing/app identity/font/asset licences and accurate privacy declarations.
- ⬜ E7.S1.T2 Integrate complete approved launch library, rerun contract CI and cold-start/first-placement/offline tests; no silent placeholder library.
- ⬜ E7.S1.T3 Execute complete device E2E: scan/four affinities/manipulation/save/relaunch/recovery/duplicate/A-B/inventory/export-if-supported/delete/download/revocation. Fold three accessibility checks and non-gesture actions into demo.
- ⬜ E7.S1.T4 Re-run representative performance only if release changes affect it; capture new evidence for any material change. Fix regressions and report failed runs as well as passes.

### ⬜ E7.S2 — Distribution and honest release evidence

- ⬜ E7.S2.T1 Produce signed archive and TestFlight build; founder runs demo and gathers qualitative feedback. No population analytics claims.
- ⬜ E7.S2.T2 Publish limitations: M5 untested, no independent accessibility audit, no HA/tested DB restore, no recoverable local backup, best-effort offline revocation. Privacy says no scan upload; no certification claims.
- ⬜ E7.S2.T3 Verify billing notification and operational health, retain build/contract/repository manifest and rollback deployment instructions. Existing managed backups are not a tested restore claim.
- ⬜ E7.S2.T4 Address blocking TestFlight findings, submit launch build and record actual external review/distribution outcome. Submission is not approval; roadmap stays open until launch outcome exists.

Exit: all prior Epic evidence exists, release is actually distributed, limitations and privacy match shipped behavior. No item is marked ✅ or 🟢 on “should work”.
