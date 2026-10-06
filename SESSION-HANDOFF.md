# Kfn8 session handoff

Saved: 2026-09-19; amended 2026-09-22 (see the dated section at the end, which supersedes older status lines). Purpose: restore working context after the founder reboots to get Xcode 27 running. This is a filesystem handoff, not automatic conversation memory. Read it before doing anything; do not repeat the 55-question interview.

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

## 2026-09-22 resume amendment (supersedes the status lines above)

- Xcode 27 licence is accepted and `xcode-select -p` now points at Xcode 27 (founder did this). Readiness CLI exits 0 with `toolchain_ready_device_unverified`; SDKs xros27.0/xrsimulator27.0; Swift 6.4.
- The client source directory is now `_Kfn8-frontend-avp/_Kfn8-frontend-avp-src/` (renamed from the empty misspelled directory). It contains `project.yml`, the nonshipping `Kfn8M0Probe` app and the `Kfn8M0ProbeCore` package with Swift Testing. Builds succeed for device and simulator SDKs under strict concurrency; package tests pass on host and simulator. `Kfn8.xcodeproj` is generated and ignored; regenerate with `xcodegen generate`.
- SDK API evidence is in `reports/M0-SDK-API-EVIDENCE.md`. Key facts: `PointLightComponent.SurroundingsLight`/`SpotLightComponent.SurroundingsLight` are the visionOS 27 physical-space-lighting API; `EnvironmentBlendingComponent.occluded(by: .surroundings)` is occlusion; `ManipulationComponent.releaseBehavior = .stay` exists but there is no API to keep a manipulation alive after `WillRelease` or to start one programmatically, so invalid-release continuation without re-grab is a founder product decision after device evidence; export route is ScreenCaptureKit picker + `SCStream` (device-only question whether passthrough pixels are included); `GaussianSplatResource` has no file loader.
- Splat budget spent: Box-only PLY sample, not ingestible without a conversion step. Do not research further.
- Blockers: no Apple account signed into Xcode 27 (signing fails for both G7Y435RZV6 and G4Y5TXVX4P); no physical Vision Pro paired. Founder must sign in, pair the M2, run the protocol in `_Kfn8-frontend-avp-src/README.md`, and return `M0-EVIDENCE.json`.
- Task status: E0.S1.T4, E0.S2.T1, E0.S2.T2, E0.S3.T2 done; E0.S1.T3 blocked; E0.S3.T1/T3 in progress; E0.S2.T3–T6 await device runs. No Git operations were run today; nothing is committed.
- Later on 2026-09-22: founder signed into Xcode 27 (one Apple ID stored) but its team is neither G4Y5TXVX4P nor G7Y435RZV6; ask for the Team ID and set `DEVELOPMENT_TEAM` in `project.yml`. Simulator smoke run passed with launch arguments `--open-immersive --lamp-on`; three defects found and fixed (Info.plist generated by xcodegen, system registration timing, frame-time readout). Simulator screenshots are in `reports/evidence/`. Simulator runs are not device evidence.
- 2026-09-22 evening: M2 headset paired, Developer Mode on, updated to visionOS 27.0 (24M362); developer disk image now compatible. Only signing (Team ID) blocks the first device run.
- 2026-09-22 late: team resolved to OffsideAI Inc. 9L38FSU6M7 (set in project.yml); signed device build succeeded and was installed on the M2 with devicectl. E0.S1 done. Next: founder runs the device protocol in `_Kfn8-frontend-avp-src/README.md` and returns `M0-EVIDENCE.json` plus screenshots; then E0.S2.T3–T6 and E0.S3.T1/T3 get recorded.
- 2026-09-23: founder decision D5 — implement all Epics on the simulator now; no more headset sessions requested. Device-only acceptance stays open. See ROADMAP “Founder decision D5”.

## 2026-09-23 D5 implementation session (supersedes earlier "NOT built" notes)

Built and tested on the Mac host and visionOS 27.0 simulator (not device evidence). Consolidated report: `_Kfn8-frontend-avp/reports/IMPLEMENTATION-2026-09-23.md`. One-command checks: `_Kfn8-frontend-avp/tools/ci.sh [--with-ui]`.

- Backend `_Kfn8-backend-fastapi/`: uv venv `venv`; contract v1 + `kfn8-validate`; FastAPI v1 API; SQLAlchemy/Alembic (0001 schema, 0002 tenant seed); `kfn8-ingest` operator pipeline; constrained converter; redacted telemetry; ops spec/runbook. Tests spin a throwaway Postgres cluster (`kfn8.db.ephemeral`); never a long-running server.
- Assets: four Poly Haven fixtures conformed with Blender 5.2.1 (`tools/blender_conform.py`), manifests in `assets-conformed/`, evidence in `ledger/`. Approvals pending founder (`approved_by: pending-founder`).
- Client `_Kfn8-frontend-avp-src/`: `Packages/Kfn8Kit` (Domain, Persistence, Catalogue), app target `Kfn8`, UI tests `Kfn8UITests`, M0 probe unchanged. Regenerate the project with `./setup.sh`. Team 9L38FSU6M7.
- Simulator uses a labelled synthetic room (ARKit unsupported there). Device path uses ARKit planes, scene reconstruction and a persisted world anchor.
- Still blocked on founder: fixture approvals, DigitalOcean provisioning/credentials/billing alert, launch-library budget, release name, M0 device outcomes (occlusion, manipulation, export), all device-only acceptance.
- No Git operations were run.

## 2026-09-23 D7 iPhone + iPad client (supersedes “no iOS target” for this separate track only)

- **Decision.** The founder directed an iPhone + iPad version reusing as much code as possible (decision D7, recorded in SALIENT-NOTES, ROADMAP and AGENTS). It is a separate track (ROADMAP “Track IE”, 23 tasks); MVP1 visionOS scope and acceptance are unchanged.
- **Layout.** Client sources are split into `Kfn8/Shared`, `Kfn8/visionOS` and `Kfn8/iOS`. The schemes are `Kfn8` (visionOS), `Kfn8iOS` (iPhone/iPad) and `Kfn8M0Probe`. UI-test helpers are shared from `UITestSupport/`.
- **Tests.** `tools/ci.sh --with-ui` covers visionOS, iPhone 18 Pro and iPad Pro 11-inch simulators; the last run was 15/15 PASS.
- **Next.** Physical iPhone/iPad run (IE6.T2): LiDAR and non-LiDAR capture, relocalization, touch, occlusion, accessibility. Also add UI coverage for the turn-button tap and the preview sheet.
- **Other visionOS changes this session.** New items face the user when added. The main window title is plain text. There is an in-room 45° turn button per item.
- No Git operations were run.

## 2026-10-04

- Founder deferred the M0 export probe (E0.S3.T1 now ⏸️). E3.S3 export stays blocked until the device run or an export re-scope decision.
- ROADMAP progress snapshot corrected to match the task records (it still said no headset tests had run). MVP1 counts: 0 ⬜ · 17 🟡 · 35 ✅ · 19 ⏸️ · 0 🟢. Track IE is unchanged.
- The headset is now on visionOS 27.0.1 (24M372); earlier M0 evidence was on 27.0 (24M362). Record the version with each new result.
- Device defect: “Add <item>” did nothing on the M2. The app's real-world collision check had no scan-mesh tolerance (the probe's M0 run 1 fix was never carried over). Fixed in shared `OrientedBox.realWorldContactTest`, used by visionOS and iOS. A failed add now shows its message beside the pressed button. Needs a device re-test.
- No Git operations were run.

## 2026-10-05 D8 iPhone + iPad app (supersedes the D7 notes above)

- **Decision D8.** The iPhone + iPad app is a fresh, independent codebase in `_Kfn8-frontend-avp/_Kfn8-frontend-ios-src`, at feature parity with the Vision Pro app (room photo export, online catalogue, realism/performance, TestFlight + App Store), on all iOS 27 devices. It starts from a copy of Kfn8Kit that may diverge.
- **Roadmap.** `_Kfn8-frontend-avp/ROADMAP-IOS.md`: Epics I0–I4 and I7, 56 tasks (1 ✅, 55 ⬜). Open founder decisions ID-1 to ID-4; the App Store relationship (separate vs universal purchase) is deferred until before TestFlight.
- **Removed.** The D7 `Kfn8iOS` target, `Kfn8/iOS`, `Kfn8iOSUITests`, the iOS CI steps and `.iOS` from the Vision Pro Kfn8Kit. The code is in Git history (parent commit `0db5593`). The Vision Pro app still regenerates, builds and passes Kfn8Kit 67/67.
- **Next.** I0.S1.T2–T6 (project, Kfn8Kit copy, bundle, CI, simulated room), then the I0.S2 device probes on the iPhone 13 Pro Max (iOS 27.0, LiDAR). The iPhone 16 Pro Max is on iOS 18.5 and must be updated before use. No iPad or non-LiDAR iPhone is paired.
- **I0.S1 (later on 2026-10-05).** T2–T5 done and T6 partial; see `reports/IOS-I0-FOUNDATION-2026-10-05.md`.
  - Project: `_Kfn8-frontend-ios-src` (xcodegen `Kfn8iOS`, `setup.sh`).
  - Kfn8Kit copy: 72/72 host tests, including the new checksum-verified `BundledCatalogue`.
  - Bundle: nine fixtures (9/9 `kfn8-validate --bundle`), fonts and icon.
  - CI: `tools/ci-ios.sh --with-ui` PASSED, UI test 1/1 on iPhone 18 Pro and on iPad Pro 11-inch (M5). The backend's `generate_swift_client.py` gained `--out` for the iOS drift check.
  - Vision Pro after the D7 removal: visionOS UI tests 4/4.
  - Next: I0.S2, starting with the iOS 27 SDK API evidence (T1).
- **I0.S2 (2026-10-05).** T1 and T2 done; T3–T6 have the probe ready and wait for the founder's run on the iPhone 13 Pro Max (`00008110-001E55660E8B801E`).
  - **Stack:** ARKit `ARSession` + RealityKit `ARView`, because `SpatialTrackingSession` has no world maps (`reports/IOS-SDK-API-EVIDENCE.md`).
  - **ID-3:** `SurroundingsLight` is iOS-unavailable; the candidate is LiDAR mesh `receivesLighting`.
  - **Probe:** nonshipping `Kfn8iOSProbe` (`com.appliaison.kfn8.ios.probe`), core tests 10/10, simulator smoke test 1/1; `ci-ios.sh --with-ui` PASSED, 11 steps. Install steps and protocol are in `_Kfn8-frontend-ios-src/README.md`. Pull `Documents/IOS-PROBE-EVIDENCE.json` after the run and record it in `reports/IOS-I0-FINDINGS.md`.
  - **Roadmap:** iOS counts 44 ⬜ · 5 🟡 · 7 ✅.

## 2026-10-06 iPhone + iPad app: I1–I7 implemented on the simulators

- **Status:** `ROADMAP-IOS.md` reads 56 tasks: 30 ✅ · 18 🟡 · 8 ⏸️ · 0 ⬜ · 0 🟢.
  - 🟡 means device-only acceptance pending.
  - ⏸️ means a founder decision or external dependency: ID-1, DigitalOcean, the launch library, TestFlight.
  - Details: `_Kfn8-frontend-avp/reports/IOS-IMPLEMENTATION-2026-10-06.md`.
- **Tests:** `tools/ci-ios.sh --with-ui` PASSED, with 6/6 UI tests on iPhone 18 Pro and 6/6 on iPad Pro 11-inch (M5), the probe smoke test, and 84 Kfn8Kit + 10 probe-core host tests. UI tests run serially (`-parallel-testing-enabled NO`) because parallel clones were killed under load. The repo-wide `tools/ci.sh` also passes.
- **Defects found and fixed while testing:**
  - a Photos save crash (Swift 6 isolation) that also affected the probe: the founder must install a fresh probe build before the I0.S2 run;
  - dark-mode text;
  - presentations blocked behind the iPhone panel sheet;
  - largest-text layouts;
  - the inventory label for withdrawn items;
  - missing search/filter/paging;
  - the panel dismissing on swipe-down.
- **Debug-only test hooks:** `--catalogue-fixtures <dir>` and `--force-revocation-sync`, compiled out of Release (Release build verified).
- **Release drafts:** `_Kfn8-frontend-avp/release/IOS-LIMITATIONS-AND-PRIVACY.md` and `IOS-RELEASE-CHECKLIST.md`.
- **Next, founder:**
  - run the probe protocol (README) and the app demo on the iPhone 13 Pro Max;
  - decide ID-1 to ID-4;
  - DigitalOcean;
  - the launch-library budget.
- No Git operations were run.
