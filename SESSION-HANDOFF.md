# Kfn8 session handoff — before reboot

Saved: 2026-09-19. Purpose: restore working context after the founder reboots to get Xcode 27 running. This is a filesystem handoff, not automatic conversation memory. Read it before doing anything; do not repeat the 55-question interview.

## Immediate situation

The founder is rebooting. They requested memory/context saved as Markdown files at this repository root. No Git operations are authorised by this request. No app implementation or cloud deployment is running that must be resumed from an in-memory process.

Repository root:
`/Users/coder/repos/offsideai/bitbucketrepos_appliaison_workspace_active_2/kfn8`

The previous agent's tool session defaulted to a DIFFERENT directory:
`/Users/coder/repos/offsideai/githubrepos_workspace_active_1`.
Always set the correct working directory explicitly. Writes to this repo previously required sandbox escalation because it was outside the session's writable root. Use normal approval tooling if that constraint persists; do not create a second copy in the default workspace.

## Read order / sources of truth

1. [AGENTS.md](AGENTS.md): current operating restrictions.
2. [PRD.md](_Kfn8-frontend-avp/PRD.md), v0.3: product scope, including interview amendments.
3. [SALIENT-NOTES.md](_Kfn8-frontend-avp/SALIENT-NOTES.md), especially Part C/D: rationale and stop conditions.
4. [TECHNICAL-PLAN.md](_Kfn8-frontend-avp/TECHNICAL-PLAN.md): implementation design and effort estimates.
5. [ROADMAP.md](_Kfn8-frontend-avp/ROADMAP.md): task-by-task status and acceptance.
6. [M0-FINDINGS.md](_Kfn8-frontend-avp/reports/M0-FINDINGS.md) and [M0-READINESS.json](_Kfn8-frontend-avp/reports/M0-READINESS.json): actual evidence, not assumptions.

The original PROMPT.md is historical. Later interview answers and monorepo/no-Git instructions supersede it. Do not revive accounts/sync, mandatory splat gates, tenant console, separate repos or routine milestone sign-off from old text.

## What actually exists

- Technical plan, amended PRD/decision notes, and roadmap: seven Epics mapping 1:1 to M0, M1, M2, M3, M4, M6, M7; 71 Tasks.
- Current task counts: 66 ⬜ not started, 1 🟡 in progress, 2 ✅ done, 2 ⏸️ blocked, 0 🟢 on-device verified.
- Done: E0.S1.T1 repository/toolchain inspection; E0.S1.T2 read-only readiness tool and tests.
- Partial: M0 findings report (readiness only); setup is blocked, not complete.
- `tools/check_m0_readiness.py`: explicit DEVELOPER_DIR, Xcode version/SDK/Swift checks, JSON command evidence, nonzero exit on failure, no licence acceptance or global configuration changes.
- `tests/test_m0_readiness.py`: 8 passing tests, including missing command, timeout, licence refusal, old SDK/Swift, simulator-only SDK, required CLI argument and toolchain success that explicitly does NOT mean M0 passed.
- Root `.gitignore` consolidated for Xcode/Swift/Python/local config/signing credentials, redundant child ignore removed; model/media/source/lockfiles/shared settings remain versionable.
- README and source documents corrected to monorepo. Latest housekeeping verified 34 JSON files, 5 plist files, legacy Xcode project syntax and all 8 tests. No whole-app build or device validation was claimed.

**NOT built:** AVP application target, FastAPI implementation, database, API, ingestion, asset validation/conversion, production assets, cloud resources, signed app, spatial probes. No assets downloaded. No physical-device tests, rendering measurements or export tests run. Do not imply that the roadmap is implemented.

## Filesystem layout / pending spelling

- `_Kfn8-frontend-avp/`: active plan/docs, tools, tests, reports and 56 user-supplied specification PNGs.
- `_Kfn8-frontend-avp/_Kfn8-frontent-avp-src/`: empty, still misspelled. Founder said they would rename it to `_Kfn8-frontend-avp-src` before implementation. Check filesystem after reboot; do not silently create a parallel source tree.
- `_Kfn8-frontend-avp/_Kfn8-backend-fastapi/`: currently empty backend directory, still nested physically. It is a component of this monorepo. No directory move was performed.
- `Kfn8-main-ios/`: existing historical iOS project; preserve it, do not use it as authority to build an MVP1 iPhone/iPad target.
- `assets/`, `assets-usdz/`, `screenshots/`, `screenshots_1_2_0/`: historical/reference material, not the approved MVP1 starter library.
- Only the parent `.git` remained in the last filesystem inventory. Never recreate a child `.git`.

## Critical Git history and restrictions

The agent mistakenly interpreted an earlier separate-repo answer as permission to initialise a nested client repository and made three LOCAL commits there: 24eb623, 0c42434, b231041. The founder objected, prohibited Git operations without explicit approval, then explicitly requested removal of the nested `.git`. It was removed, preserving every project file and the parent's `.git`. Those three IDs are historical, not parent repository revisions. No agent push occurred.

The founder subsequently ran their own parent-repo commit and amend. Supplied terminal output showed local branch literally named `origin/main`, commit 2d00d87 amended to bccc1da. `git push origin main` returned “Everything up-to-date” because it addressed local `main`, not the local branch named `origin/main`.

The agent EXPLAINED (did not run) these commands:

```sh
git switch main
git merge --ff-only refs/heads/origin/main
git push origin main
```

The founder has not confirmed running them. Current branch/push state is UNKNOWN. Target branch is main, but do not assert it is checked out. Do not run even read-only Git commands without explicit approval. Never force-push to solve this. The root handoff files were written without staging, committing or pushing; local disk persistence suffices for reboot, not remote backup.

## Xcode blocker — verify again after reboot

Last globally selected path:
`/Users/coder/Developer/Xcode/Xcode_26_5_0/Xcode_26_5_0.app/Contents/Developer`

Separate installed Xcode 27:
`/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app`

Under its DEVELOPER_DIR, `xcodebuild -version` reported Xcode 27.0 / 27A266a. `xcodebuild -showsdks` exited 69 with “You have not agreed to the Xcode license agreements.” Readiness CLI exited 1 with status blocked and m0_passed=false. This is the LAST OBSERVATION, not a claim that the founder has not since accepted it. Reboot alone is not proof of licence acceptance or SDK readiness.

Founder has an M2 Vision Pro and active Apple Developer membership; device signing/deployment still need verification. Founder performs device demos and returns local observations/traces. M5 untested, not a launch blocker; M2 success is not measured M5 success.

Do not accept legal terms on founder's behalf. Use explicit DEVELOPER_DIR for commands; do not change global xcode-select unnecessarily. No fallback to SDK/OS 26.

## First actions on resume

1. Read the source documents fully and inspect current ordinary files without Git. Check whether the founder renamed the source directory. Do not redo or overwrite existing work.
2. From the monorepo root, run the existing tests and actual readiness command:

```sh
python3 -m unittest discover -s _Kfn8-frontend-avp/tests -v
python3 _Kfn8-frontend-avp/tools/check_m0_readiness.py --developer-dir /Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer
```

3. If licence/setup remains blocked, report exact output and necessary founder action. If ready, record fresh output and update roadmap/report. Exit 0 only means toolchain_ready_device_unverified, never a passed M0.
4. Continue E0.S1.T3/T4: signing/M2 pairing and the Swift 6 strict-concurrency nonshipping M0 target in the agreed source folder. Establish actual public API symbols/permissions from installed SDK/docs before implementing probes. No imaginary APIs or old-OS shims.
5. Implement/test the three blocking M0 probes and obtain real M2 evidence. Unit tests/simulator behavior cannot close them. Continue milestone order only once the gate actually passes. Routine approval pauses were waived, but true technical/product decisions remain the founder's.
6. Keep ROADMAP status symbols, rollups, counts, evidence and this handoff current. Do not commit changes without explicit Git approval.

## M0 gate details that must not drift

Blocking: physical space lighting, Environment Occlusion, ManipulationComponent. A failed or insufficient-quality result permits ONE short investigation (minutes, not hours) for scene/entity/component/asset/API setup mistakes. If unresolved, STOP with expected vs observed, captures/numbers, and options with costs. Founder decides scope/D1/stop. No workaround/fallback/partial shipping feature silently proceeds.

Manipulation must test the precise invalid-release requirement: keep manipulation alive without requiring re-grab; validate actual platform behavior rather than promise unsupported gesture lifecycle.

Nonblocking still export: actually write a file, OPEN it and confirm passthrough room plus furniture. Record permissions/distribution restrictions. If unavailable, raise export re-scope before M3; no furniture-only substitute. Export has explicit home-image consent and no automatic upload.

Nonblocking splat: approved Postshot sample is best-effort only, one attempt, a few minutes total including availability. No more research. If Box does not quickly yield an ingestible file, record “no readily available splat asset in a RealityKit-ingestable form” and stop. If it works, note file bytes/load time/frame behavior with a few meshes and 3–4 sentences. No debugging, comparison, LOD, streaming, capture or conversion tooling. ~2M splats running poorly is an asset-size observation, not a renderer verdict. One line on possible v1.1 conversion cost. Outside mesh/PBR contract; never blocks M1 or reopens D1. This budget has NOT been used yet.

## Essential accepted product/architecture decisions

Detailed rules live in the technical plan; preserve these in particular:

- Anonymous MVP1, no accounts/sync/CloudKit/entitlements/paywall/limits/watermark/client analytics. Local Spaces/Rooms/Designs/scans only. Email/password accounts and explicit FastAPI sync are v1.1, no third-party login. No conflict copies or cross-device recovery implementation now.
- Retain schema fields: client-generated stable IDs, monotonic Design counter (no history), Room.kind, outdoor affinity, tenant_id, delivery_mode public/restricted. These reduce future migration work, not eliminate all migrations.
- SwiftData domain records isolated to persistence actor; @Model values never cross actors. Filesystem geometry/assets with relative references, sizes/checksums; repository protocols. Design graph authoritative, RealityKit transient projection; only completed edits save. No per-frame persistence.
- Room-local transforms from floor/stable wall reference; session anchor separate. Alignment verified after rescan, never assumed. Bound guided retries, then rescan into same Room or contents-only review. No positions/clearances/passthrough claims in review.
- One affinity-driven attachment system: floor/tabletop support and wall/ceiling normal orientation/gravity suppression. Four real fixture models persisted across sessions are M1 acceptance. Base-centre pivot remains distinct from mount point.
- Continuous soft drag feedback; hard real-world collision, soft virtual overlap, rugs/mats exempt from virtual collision. Invalid release tries validated nearby push-out within ~25cm, otherwise stays unsaved/held. Cancel restores pre-drag or removes new placement. No distant jump, error modal or red styling.
- Clearances are gaps, never fit verdicts; sensible rounding/ranges, explicit insufficient-coverage explanation. No tape-measure onboarding.
- Volume preview 1:1 if it fits, otherwise uniform fit with real dimensions shown. Room placement always 1:1.
- Autosave current Design, cheap obvious duplication, session undo/redo, no user revision history. Permanent counted delete removes files/records; no trash/archive. No portable export/restore; app deletion/device loss loses local work.
- Pin exact asset revisions and necessary LOD/variant files by surviving references; bundled never evicted, only unreferenced LRU. Checksum before load, redownload corruption; explicitly identify incomplete offline Designs. Never silently evict pinned files.
- Commercial delisting retains geometry; rights revocation stops serving/removes cache on notification, but already loaded scene stays until next load. Show labelled absence then, retain Placement record, offer newer version as item action. Cursor delta checks launch/foreground/infrequent online opportunities, no heartbeat; offline revocation best-effort.
- Inventory defaults to generics with quantity/dimensions, no fake price/link, no all-unpriced subtotal. Priced path still implemented/tested. Item retrieval dates; subtotal date/range collapsed same-day; “priced items only” only when mixed. Independent quiet refresh, dated delisted prices.
- Minimal accessibility checks inline: VoiceOver reaches every control; Dynamic Type no clipping; reduced-motion alternatives. Non-gesture alternative for every spatial-only action. No independent audit claimed.

## Assets and backend

Four approved engineering candidates, not downloaded yet, all Poly Haven CC0 1.0 (attribution not required but ledger still mandatory):
- Floor: https://polyhaven.com/a/modern_arm_chair_01 (~9k triangles).
- Wall: https://polyhaven.com/a/industrial_caged_sconce (~27k).
- Ceiling: https://polyhaven.com/a/hanging_industrial_lamp (~10k).
- Tabletop: https://polyhaven.com/a/ceramic_vase_02 (~3k).
- One nonshipping splat candidate: https://note.com/steam_studio/n/ne9736d94f162 (publisher CC0; optional credit, PLY, ~2M splats; Box link on page).

Mesh sources are listed as glTF, not confirmed ready-made GLB/USDZ. Conform before use: metres, base-centre, +Y up, front −Z, PBR metallic-roughness, texture/triangle budgets and ±1% spec agreement for master/every LOD/USDZ. Generic dimensions from source after furniture-scale sanity check, with authority/source/values/approver/date first-class. No manufacturer measurement exercise, no self-comparison without approval. Provenance/licence approval always required; separate visual/dimension approval mandatory at launch. Record who/when/evidence hash, not a checkbox. No external standards-conformance/certification claim.

~200-asset launch library is separate, budget after M0; no purchases authorised. It or realistic conformed stand-ins gate M4 performance: 20 mixed placements, two active virtual lights, 15 minutes moving/turning on M2, 90 Hz target with zero drops, distributions/worst spikes/memory. Four repeated low-poly fixtures cannot prove this.

Backend: async FastAPI, SQLAlchemy 2.x/Alembic, DigitalOcean App Platform + Managed Postgres + Spaces CDN. Smallest fixed tiers, no autoscaling/replicas/HA/tested restore claim. Baseline plan estimate ~US$25/month, reverify before provisioning; separate storage/egress variables, billing notification at 125% of estimate. No credentials/resources provisioned yet.

Public immutable URLs only for approved published generic assets; source/review/rejected files private. Content hashes are integrity/identity, NOT access control. No API byte proxy, no DB binaries. restricted mode is a field, not implemented authorisation. Rights revocation verifies origin deletion/CDN purge; cannot remotely erase offline bytes. Presigned URLs do not give Spaces edge caching, so that proposal was superseded.

Operator-invoked ingestion stages with persisted stage state/fingerprints/reports, resume, independent stage functions and idempotent publish. No Procrastinate/queue/deployed worker now. Tenant onboarding/feed connectors/roles/dashboard deferred. Backend owns versioned OpenAPI/asset schemas; generate Swift transport models even in monorepo because deployed versions are independent.

## Maintenance boundaries

No urgent need to recreate docs or rerun the interview. Treat future changes to these decisions as explicit product decisions. Do not modify unrelated legacy app files or silently acquire launch assets. Update actual status, not optimistic predictions. Filesystem handoff files contain no credentials. No Git operations were performed to save them.

Suggested founder prompt after reboot:
“Read AGENTS.md and SESSION-HANDOFF.md in the kfn8 repo root, re-check Xcode 27 readiness, and resume M0. Keep ROADMAP.md updated. Do not run Git operations.”
