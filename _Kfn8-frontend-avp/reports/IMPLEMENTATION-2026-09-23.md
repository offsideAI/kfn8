# Implementation report — 2026-09-23 (founder decision D5: simulator-first)

Scope: all Epics, implemented and tested on the Mac host and the visionOS 27.0 simulator. Nothing here is device evidence. Device-only acceptance stays open and is listed at the end.

## Components delivered

| Component | Location | What it is |
|---|---|---|
| Asset contract v1 | `_Kfn8-backend-fastapi/contracts/v1/` | JSON schema, contract text, pinned OpenAPI |
| Contract validator | `kfn8-validate` | Measures real GLB (node transforms, triangles, embedded textures, material model) and USDZ (metersPerUnit, upAxis, world bounds, UsdPreviewSurface); ±1 % per axis and across representations; bundle mode |
| Four engineering fixtures | `assets-conformed/*` | Poly Haven CC0 chair, sconce, pendant, vase, conformed with Blender (−Z front, base-centre pivot, LOD0–2 GLB + USDZ); ledger evidence hashed; approvals pending founder |
| Catalogue API v1 | `kfn8.api` | Anonymous read-only FastAPI + SQLAlchemy 2 async + Alembic; signed cursors; structured errors; health; redacted request telemetry |
| Operator pipeline | `kfn8-ingest` | Staged, resumable, fingerprinted, advisory-locked; approvals bound to input hash; content-addressed idempotent publish; verified rights revocation; delisting |
| Client core | `Kfn8Kit` (Domain, Persistence, Catalogue) | Sendable domain, room frames, attachment/collision/release rules, edits/undo, inventory/pricing, A/B switcher, update offers, clearance readings, performance trace; SwiftData actor store with deletion journal; API client, pinned asset cache, revocation sync |
| visionOS app | `Kfn8` target | Window + volumetric preview + Mixed Immersive Space; ARKit capture/relocalization on device, labelled simulated room on the simulator; non-gesture controls for every spatial action; Showroom palette and fonts; layered app icon |
| M0 probe | `Kfn8M0Probe` target | Unchanged from M0 work; tap-only evidence recording |
| Ops | `ops/app.yaml`, `ops/OPERATIONS.md` | Smallest fixed tiers, runbook, cost estimate, billing alert instructions (not executed) |
| CI | `_Kfn8-frontend-avp/tools/ci.sh` | Every host/simulator check in one command |

## Test results (latest runs)

| Suite | Result |
|---|---|
| Backend pytest (real Postgres 17, throwaway cluster) | 49 passed |
| Kfn8Kit Swift Testing (host) | 63 passed (Domain 42, Persistence 9, Catalogue 12) |
| M0 probe core Swift Testing | 43 passed |
| Readiness tool | 8 passed |
| Contract validation of 4 fixtures + bundle check | 4/4 pass, 4/4 bundle pass |
| App builds | device SDK and simulator SDK succeed (strict concurrency, warnings as errors) |
| End-to-end UI tests on the visionOS 27.0 simulator | 3 of 3 pass: scan → place all four affinities → move/rotate/undo/redo → push into the table obstacle (resolved by ≤25 cm push-out) → relaunch → duplicate → counted delete; lost alignment → rescan into the same Room and review contents, A/B flip, inventory without totals; largest accessibility text size keeps every control reachable |

## Defects found by tests and fixed

- Validator rejected 2–3 % LOD2 silhouette drift on two fixtures → bound-preserving decimation.
- `source_sha256` accepted malformed hashes → CHECK constraint added.
- Room tracking started before its session existed (UI test: never "Aligned") → start moved into the RealityView make closure.
- Floor items were not dropping under gravity (diagnostics) → gravity drop onto the highest support beneath.
- xcodegen regenerated Info.plist without the scene manifest → keys moved into `project.yml`.
- Ceiling items measured from the base instead of the mount point → fixed with tests.
- New items spawned between the user and the window and swallowed its taps (the same problem the founder hit in the M0 probe) → new placements appear 2.4 m ahead, beyond the window.
- Window layout squeezed labels mid-word and clipped the catalogue column → wrapping grids, widths scaled with Dynamic Type, single column at accessibility sizes.

Evidence: `reports/evidence/2026-09-23-simulator-*.png` (window and immersive-scene captures from the UI tests). The held-invalid state is covered by unit tests only; in the UI run the push into the table was correctly resolved by push-out. Window captures are cropped at the simulator's 1280 × 1080 viewport; the window itself is wider.

## Blocked on founder or external dependencies

- Provenance and visual/dimension approvals for the four fixtures (`kfn8-ingest approve`).
- DigitalOcean provisioning, credentials, billing alert; real Spaces/CDN smoke test.
- Launch-library budget and acquisition (gates M4 performance and M7).
- Still export: the M0 export probe never ran on device; E3.S3 stays blocked pending that finding or a re-scope decision.
- Release name, TestFlight, App Review.

## Device-only acceptance still open (never closed by simulator results)

M0 occlusion and manipulation outcomes; capture coverage and relocalization on real rooms; physical lighting/occlusion quality in M4; the 20-placement / two-light / 15-minute 90 Hz trace; accessibility checks in the device demo; export pixels.

## Addendum: orientation defect caught by the founder review sheet

The first conform run left the chair and sconce facing +Z (backwards): Blender's glTF importer uses quaternion rotation mode, so the Euler 180° turn was ignored, and the contract validator cannot see which way an object faces. The review renders exposed it before any approval. Fixed by rotating mesh data directly and measuring bounds from vertices; all four fixtures re-conformed, re-validated (4/4) and re-bundled (4/4). A raw-coordinate check confirms the chair's backrest now sits at +Z (front −Z). Review sheet: `_Kfn8-backend-fastapi/ledger/review-sheet-2026-09-23.png`.
