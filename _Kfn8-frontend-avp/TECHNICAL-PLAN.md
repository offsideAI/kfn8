# Kfn8 Technical Plan

Date: 2026-09-19. Implements PRD v0.3 and interview decisions Q1–Q55.
Execution authority: the founder authorised continuous implementation on 2026-09-19, superseding routine plan/milestone approval pauses. This does not waive feasibility gates, truthful evidence, asset acquisition decisions, or legal agreements.

## 1. Scope and delivery

MVP1 is anonymous, indoor-only, Apple Vision Pro-only, visionOS 27 minimum, with no older-OS availability branches or fallback renderer. M2 is the acceptance device; M5 remains supported but untested. No inference of an M5 performance pass from M2 results.

Implement M0 → M1 → M2 → M3 → M4 → M6 → M7. ROADMAP.md has exactly one Epic per milestone, numbered stories/tasks, dependencies, acceptance and demo evidence. Later milestone implementation does not bypass M0. Each milestone report records changes, tests including failures, monorepo revision (when a commit is explicitly authorised) and separate client/backend build IDs, and device evidence. Human-operated device tests are genuine dependencies, not approval ceremony.

No accounts, sync, subscriptions, commercial limits, watermark, product telemetry, geometry upload, tenant console, worker deployment or queue. No capture companion, Full Immersive Space, offsite implementation, daylight scrub, spatial video, web viewer, portable backup/restore or production splats. Preserve only agreed future-facing fields: Room.kind, outdoor affinity, stable IDs, Design counter, tenant_id and delivery_mode. Offside Plan extraction remains deferred; do not scaffold a shared portfolio capture package.

### Effort estimates (engineering effort, not elapsed deadlines)

| Milestone | Estimate | Dependencies outside engineering pace |
|---|---|---|
| M0 | 3–7 working days, excluding the minutes-only splat check | Xcode 27 licence/setup, signing and M2 access; documented public APIs |
| M1 | 3–5 weeks | Four approved/conformed test models; measured M0 pass |
| M2 | 2–3 weeks | DigitalOcean access, deployment credentials and contract release |
| M3 | 2–3 weeks | M0 export finding; valid room/Design core |
| M4 | 2–4 weeks | Launch library or genuinely representative conformed assets |
| M6 | 2–3 weeks | Operator evidence/approvals and catalogue assets |
| M7 | 1–2 weeks plus external review time | TestFlight feedback, release identity/signing, library readiness |

Estimates include automated tests and reports. Asset purchasing/remastering, procurement and App Review are separate. Initial M1 ships four engineering fixtures; the complete launch library is an M7 dependency. Minimal contract/validation and operator import functionality must exist by M1/M2; M6 finishes resumable batch ingestion, not the first validation gate. This resolves the original late-ingestion ordering without postponing the contract.

## 2. Repository layout and provenance

**Current decision supersedes Q29:** one `kfn8` monorepo, targeting its `main` branch. No nested repositories. No Git operations without explicit founder approval, including read-only Git commands, staging, commits and branch changes.

Client component: `_Kfn8-frontend-avp/`, containing the source documents, roadmap, reports, tools and future AVP source.
Backend component: the currently existing empty `_Kfn8-frontend-avp/_Kfn8-backend-fastapi/` directory. Planned contents remain `contracts/v1/`, `src/kfn8/`, `tests/`, `alembic/`, `ops/` and `pyproject.toml`. It is not a separate Git repository. No backend code or directory relocation is part of the monorepo housekeeping change.

The empty source directory is still `_Kfn8-frontent-avp-src`; the founder previously said they would rename it to `_Kfn8-frontend-avp-src`. Preserve source/reference assets, screenshots and legacy iOS code. The root `.gitignore` owns common rules; source assets and diagnostic evidence are not blanket-ignored. Nested client metadata created earlier was removed at the founder's request; its old commit IDs are historical only, not parent-repository revisions.

Swift packages (inside client source): `Kfn8Domain` (Sendable value types and edit rules), `Kfn8Persistence` (SwiftData/files), `Kfn8Catalogue` (generated transport types and downloads), `Kfn8Spatial` (ARKit/RealityKit integration). App target owns scenes, navigation and Showroom UI. No iOS targets. M0 probes are a separate nonshipping target rather than placeholder shipping features.

Backend owns versioned OpenAPI, JSON asset metadata schema and asset-contract text. Generate Swift transport models using a pinned OpenAPI generator after validating Swift 6 output; CI regenerates and rejects diffs. Map generated DTOs into domain values rather than persisting transport objects. Record the contract release/hash consumed by each component. Breaking changes use a new API major path and contract release; published v1 clients continue working. M2 completion records the monorepo revision when an authorised commit exists, separate client/backend build identifiers, and the contract hash. Independently deployed components still require compatibility checks.

## 3. M0 evidence and hard stop

Check actual toolchain version, device and simulator SDKs, Swift compiler, signing and deployability before writing feature probes. Use an explicit DEVELOPER_DIR, not global xcode-select changes. Observed Xcode 27.0 build 27A266a exists, but `xcodebuild -showsdks` is blocked by its unaccepted licence. Xcode 26.5 is globally selected. A licence blocker is not an API failure or a reason to reopen D1; the founder must review/accept the agreement.

Blocking probes: physical space lighting of real surfaces, Environment Occlusion, and ManipulationComponent. For each: cite the exact installed SDK API/sample, compile without compatibility checks, run on the M2, record OS/build, room conditions, expected versus observed behavior, frame-time evidence and captures where supported. Never invent an API from a marketing feature name. One short check for obvious scene/entity/component/asset/API mistakes is allowed; unresolved failure or insufficient quality stops progression and goes to the founder with options and costs. Do not add a custom fallback.

Manipulation probe includes all affinities, orientation/gravity policy, indirect/direct input, volume-to-room transfer, and the agreed invalid-release requirement: retain manipulation without a re-grab. If physical release semantics cannot support that requirement, report it as a product decision, not a quietly altered interaction.

Nonblocking export probe: write a real file and open it to verify actual room pixels plus placements. Record permissions, distribution restrictions and SDK path. If unavailable, flag export for explicit re-scope before M3; no furniture-only substitute.

Nonblocking splat: one best-effort Postshot sample, one attempt, a few minutes total. If the Box folder does not quickly yield a RealityKit-ingestable file, record that finding and stop. If usable, render alongside a few meshes; note size, load time and frame behavior in 3–4 sentences. No debugging, production, format-conversion tool, quality tuning, LOD, streaming, capture or comparisons. A ~2M-splat slow load is an asset-size observation, not a general renderer verdict. Note any apparent conversion dependency for v1.1. This test never gates M1 or reopens D1.

## 4. Client state, scenes and spatial model

Window: catalogue, Rooms/Design manager, inventory and controls. Volume: inspection preview; uniform scale = min(1, bounds-width/item-width, bounds-height/item-height, bounds-depth/item-depth), using usable bounds after padding. Downscaled previews show real W×D×H, never a misleading ratio. Mixed Immersive Space: real room plus true-scale placements. Placed scale is exactly one; reject scale gestures. No full immersion.

`@MainActor` app/scene coordinator owns scene lifecycle and transient selection. SwiftData models/ModelContext stay within one dedicated persistence actor (`@ModelActor` where validated); never send @Model instances across actors. Repository protocols accept/return immutable Sendable snapshots, IDs and edit commands. File IO/checksums/downloads run outside the UI actor. RealityKit entities stay within the isolation required by the installed SDK. Strict concurrency is a build requirement from the first Swift target.

Persist Space(id,name), Room(id,spaceID,name,kind,localScanReference), Design(id,roomID,name,version), Placement(id,designID,assetID,revisionID,roomLocalTranslation,roomLocalQuaternion,variantID). Client-generated UUIDs. Design.version is a monotonic local committed-edit counter, not revision history. No sync/conflict engine. ScanFile records relative path, byte size, SHA-256, capture timestamp and room-frame version; structured scan elements returned by the same scan are persisted locally with no feature/UI/misdetection handling.

Room-local frame: floor plane establishes up; a stable wall establishes yaw and origin. Store frame definition separately from the session world transform and anchor identifiers. Entity world transform = sessionFromRoom × placementRoomTransform. Rescanning replaces the local scan/frame mapping only after alignment is verified; never rewrite placements merely because an anchor changes. Ambiguous/repeated walls are a real alignment risk: withhold spatial content until verified. Plane classifications floor/wall/ceiling/horizontal support are mandatory; no promise of a RoomPlan-equivalent semantic API.

Entity projection: root carries Placement identity/revision; child holds immutable model, collision proxies and ephemeral attachment/manipulation/selection components. Load records into entities; only completed operations write back. No per-frame saves. Persist each completed edit atomically before reporting saved; retain prior state and an actionable message on failure. Crash during a drag restores the last committed operation, not an impossible zero-loss guarantee for uncommitted state. Session-local undo/redo uses inverse domain operations; each undo/redo also commits durably.

### Attachment and recovery

One policy-driven attachment system: floor/tabletop drop to support; wall/ceiling orient using surface normal and suppress gravity. Explicit mounting points are metadata distinct from the invariant base-centre pivot. Real geometry intersections are hard constraints; virtual overlap is permitted with a subtle cue, and rugs/mats are exempt from virtual overlap cues.

Dragging is never physically blocked. At invalid release, try shortest-axis penetration resolution then validate against all nearby real obstacles and attachment constraints, limited to 25 cm. If no candidate is valid, retain unsaved preview/manipulation with quiet text: “There isn't enough space here”. No red, modal or distant jump. Cancel restores pre-drag placement or removes a newly introduced item. The exact post-release interaction must first pass M0.

After a small bounded number (plan default: two) of guided alignment attempts, offer rescan into the same Room or non-anchored review. Plain copy: “I can't tell where this room is yet”. Review is contents, item details and inventory; no passthrough composition, clearances or spatial position claims. No separate new-device flow in MVP1.

Clearances are gaps, not “fits” verdicts. Round to supported centimetre precision or ranges; withhold when coverage/uncertainty cannot justify the reading and explain the corner/surface to rescan. Do not pretend ARKit supplies a calibrated measurement-confidence score unless the SDK actually does; derive conservative evidence from observed coverage and repeated measurements, validate on device and document limitations.

## 5. Persistence, cache and deletion

SwiftData only stores domain/catalogue/file records. Meshes, scans, USDZ and textures are filesystem files. CloudKit is disabled. Exclude sensitive scan/Design storage from automatic app-managed cloud transfer and review OS backup behavior before making privacy claims; no upload endpoint exists. MVP1 has no portable backup/restore: device loss or app deletion loses user work.

Asset identity is (assetID, revisionID, rendition, SHA-256). Pin the necessary placement LOD/variant files while any saved Design references that revision, not one copy per Design. Bundled files are permanent. LRU eviction touches unreferenced downloads only; never evict an old pinned revision because an update exists. Use staging files, streaming SHA-256 and atomic rename. Verify checksums before load; recover corrupt files through re-download, or explicitly identify missing items offline. Reserve required bytes before download and show which Designs lack offline completeness if storage is insufficient. No arbitrary automatic eviction of pinned content.

Start with a measured 2 GiB unreferenced-cache budget (implementation tuning value, not a user-facing limit); pinned bytes may exceed it. Reassess against real library size. LOD selection uses projected screen size with hysteresis; initial implementation thresholds are tuned against measured M2 frame/texture memory results, with no claim that per-asset triangle limits alone guarantee 90 Hz. Keep only active resources resident; release superseded models/textures outside manipulation.

Commercial delisting changes purchase availability only. Rights revocation prevents future download, removes cached files, records the revision as unavailable, and does not yank a currently displayed entity. Next Design load shows a labelled absence marker, not approximate replacement geometry; never measure against absent geometry. Placement record remains unchanged; latest revision is an optional item action. Check monotonic revocation deltas on launch/foreground and infrequent online opportunities (initial 6-hour eligible interval); no continuous polling loop. Apply deletions durably before advancing the cursor; retry after crash. Offline cached assets keep working until notification.

Deletion confirmation contains real Room/Design counts and “can't be undone”. Cascade records, remove actual scan files, release references without evicting shared assets. Use an idempotent local deletion journal so crashes between DB and filesystem operations finish deletion on restart; no user-facing trash or archive. Report permission/IO failure, never claim deletion completed when files remain.

## 6. Catalogue service and table definitions

One async FastAPI service on App Platform; SQLAlchemy 2.x async sessions per request, Alembic migrations, Managed PostgreSQL. No microservices or queue. No client account identity or user entitlement resolution. Device-scoped means local cache/preferences, not tracking a stable device identifier in backend analytics. Public reads are anonymous; rate limits are operational abuse protection, not identity. Administrative operations are local/private operator commands with scoped credentials, never anonymous HTTP writes.

Proposed initial relational schema (all IDs UUID unless noted; times UTC timestamptz; explicit migrations; FK deletion defaults RESTRICT for published records):

| Table | Columns and constraints |
|---|---|
| tenant | id PK, name text NOT NULL; seed Kfn8 only; no membership tables |
| catalogue | id PK, tenant_id FK, slug text UNIQUE, name text NOT NULL |
| asset | id PK, tenant_id FK, catalogue_id FK, sku text NULL, name text, category text, affinity text CHECK floor/wall/ceiling/tabletop/freestanding-outdoor, delivery_mode text CHECK public/restricted, provenance text CHECK licensed/commissioned/captured/generated, style_tags text[], dominant_colour text, weight_class text; UNIQUE(tenant_id,sku) |
| asset_revision | id PK, asset_id FK, revision integer CHECK >0, state text CHECK draft/validating/review/approved/publishing/published/revoking/revoked/rejected, contract_version text, source_sha256 char(64), dimension_spec_id FK, attachment_metadata jsonb, created_at, published_at NULL; UNIQUE(asset_id,revision) |
| dimension_spec | id PK, width_m/depth_m/height_m numeric CHECK >0, authority_kind text CHECK retailer/operator, source text, approved_by text, approved_at; evidence_sha256 char(64) |
| licence_ledger | id PK, revision_id FK UNIQUE, source_url text, author text, licence_id text, attribution_required boolean, attribution_text text NULL, evidence_reference text, evidence_sha256 char(64), recorded_at |
| approval | id PK, revision_id FK, kind text CHECK provenance/visual_dimensions, actor text, decided_at, evidence_reference text, evidence_sha256 char(64), approved boolean; approvals bound to immutable revision/input hash, never a UI checkbox |
| rendition | id PK, revision_id FK, lod smallint CHECK 0..2, format text CHECK glb/usdz, variant_key text, object_key text UNIQUE, sha256 char(64), size_bytes bigint CHECK >0, triangles integer CHECK >=0, max_texture_edge integer CHECK <=2048; UNIQUE(revision_id,lod,format,variant_key) |
| material_variant | id text, revision_id FK, label text, material_mapping jsonb; PK(revision_id,id) |
| offer | asset_id FK, market text, currency char(3), amount_minor bigint CHECK >=0, available boolean, retailer_url text NULL, fetched_at; PK(asset_id,market,currency); no offers for unpriced generics |
| ingestion_stage | revision_id FK, stage text, input_fingerprint char(64), tool_version text, state text CHECK pending/running/passed/failed, started_at NULL, ended_at NULL, report jsonb, output_manifest jsonb; PK(revision_id,stage) |
| revocation | sequence bigint identity PK, revision_id FK UNIQUE, reason text CHECK rights, effective_at, removal_verified_at NULL, purge_verified_at NULL |

No binary blobs in jsonb or columns. Index catalogue filters, published revision selection, offer asset lookup and revocation sequence. A composite tenant/catalogue integrity constraint prevents an asset being assigned a mismatched tenant. Dimension and approval records are immutable; changed source/spec/materials create a new revision and invalidate affected prior stage results. Prices use integer minor units; never aggregate across currencies into a fictitious total.

### API v1

Errors use `{code,message,request_id}` with correct 400/404/409/410/429/503 status; avoid internal paths/secrets. Limits max 100, default 30. Opaque cursor contains last sort tuple and filter fingerprint; stable ordering (name,id), reject cursor/filter mismatch.

| Endpoint | Request | Response |
|---|---|---|
| GET /health/live | none | `{status:"ok"}` without DB call |
| GET /health/ready | none | 200 if DB reachable, 503 otherwise |
| GET /v1/catalogues | cursor,limit | `{items:[{id,name}],next_cursor}` |
| GET /v1/assets | q,category,affinity,style,colour,catalogue_id,cursor,limit | `{items:[AssetSummary],next_cursor}`; published public assets only |
| GET /v1/assets/{id} | none | summary, approved dimensions, variants, latest revision, nullable offer |
| GET /v1/assets/{id}/revisions/{revision} | none | pinned metadata/renditions with immutable CDN URLs, hashes, lengths; 410 rights-revoked, 404 unknown/private |
| GET /v1/revocations | cursor,limit | `{items:[{sequence,revision_id,reason}],next_cursor,has_more}`; durable tombstones, no silent history expiry |

AssetSummary: id, tenant_id, name, category, affinity, delivery_mode, latest_revision_id, dimensions_m `{width,depth,height}`, nullable thumbnail_url and nullable offer `{amount_minor,currency,available,retailer_url,fetched_at}`. Revision responses include contract_version and immutable material variant IDs. Do not represent unknown price as zero. Identity/auth can wrap these routes in v1.1, but do not implement dormant authentication now. No Design or scan endpoints.

## 7. Ingestion and immutable publication

Operator command resumes explicit stages: register private source and licence record → detect/parse → validate topology/units/orientation/dimensions → normalize PBR/textures → generate LODs → convert USDZ → revalidate every representation → thumbnails/metadata → recorded provenance approval + visual/dimension approval → publish. CI runs the same validators against bundled and remote manifests. All original/review/rejected files remain private; publication is the only path to a public key.

Stages take revision/input manifests, not HTTP requests/job objects; persist outputs and structured failures. Re-run starts at first incomplete/invalidated stage. Advisory lock per revision avoids accidental duplicate invocations even with one operator. Tool exit failures/timeouts and unsupported materials are failures, never placeholder passes. Execute untrusted converters as constrained subprocesses with file/size/time limits and no arbitrary source URL fetching; single-operator input does not make parser bugs safe.

Dimension gate compares world-space bounds after transforms for master, each LOD and USDZ against an independently approved declared spec within ±1% per axis; also compare representations to catch opposite-direction drift. Metres, base-centre pivot, +Y up, front −Z, PBR metallic-roughness, packed channels, 2k max/1k distance textures, clean normals, appropriate watertightness and AO UV non-overlap. Record exceptions requiring judgement as approval evidence, not disabled validation. No certification or Khronos-conformance claims.

Publisher: require all gates/evidence on the exact hash; write content-addressed revision-qualified public objects conditionally; verify checksum/size; then atomically mark catalogue revision published. Retries reuse verified objects and do not duplicate rows. Crash before DB publication leaves unlisted approved objects, recovered or cleaned by the operator; never expose unapproved objects. Rights revocation immediately hides delivery metadata and creates a delta, removes origin objects, purges edge cache, verifies absence and records evidence. Public hashes are not access controls. Reject restricted-mode publication in MVP1.

Approved engineering candidates: Modern Arm Chair 01 (Poly Haven, ~9k triangles), Industrial Caged Sconce (~27k), Hanging Industrial Lamp (~10k), Ceramic Vase 02 (~3k), all CC0 1.0. Source URLs are https://polyhaven.com/a/modern_arm_chair_01, https://polyhaven.com/a/industrial_caged_sconce, https://polyhaven.com/a/hanging_industrial_lamp, https://polyhaven.com/a/ceramic_vase_02. All need contract verification/remastering; ledger entries even for CC0. Splat candidate: https://note.com/steam_studio/n/ne9736d94f162 (publisher CC0, optional credit; PLY, outside mesh contract). No additional splat research. No named purchasable SKU geometry generation/approximation. Launch library remains separately budgeted after M0.

## 8. Designs, inventory and presentation

Autosave current state; prominent cheap duplication creates new Design/Placement IDs sharing immutable asset references. No saved revision history. A/B flip uses two named Designs, swaps their entity projections atomically when resources are ready; preserve current view until the next is ready, no partial-room flash. Include a button alternative to every gesture. Variant change is a committed edit. Update offers are per Design with an explicit summary; no silent geometry/material replacement.

Inventory defaults to generic quantity/dimensions, no price or purchase link and no subtotal if nothing is priced. Priced path is tested with synthetic clearly identified test metadata, never fabricated commercial claims. Item prices have individual retrieval dates; subtotal uses earliest/latest range, collapsed to one date for the same day. “priced items only” appears only if some items are unpriced. Refresh each item independently, quietly; delisted items retain dated prices and unavailable status. Multiple currencies have separate subtotals pending deferred region policy; do not invent FX conversions.

Showroom: bone/paper, walnut/clay, brass active state, ink text. Fraunces display and Hanken Grotesk UI with bundled font licences. No purple/indigo/cyan UI. VoiceOver reaches controls, Dynamic Type avoids clipping, reduced-motion alternatives for animation; each spatial-only action gets non-gesture controls. Minimal checks are part of demos, not a separate audit. Still-image export (only after M0 evidence) explicitly asks consent to an image of the home at export, saves/shares only on user action, no auto-upload or watermark.

## 9. Verification and demos

Unit (Swift Testing): edit/undo/cancel semantics, rigid room-frame transforms, duplicate IDs/reference counts, preview fit, price/date formatting, cache accounting, revocation cursor crash recovery, deletion journal, uncertainty presentation. Persistence integration: real temporary SwiftData store and files, failed writes/full storage/restart. Backend pytest: real Postgres transactions/migrations, resume/invalidation, approvals/hash binding, public/private queries, pagination, immutable publication crash/retry and rights revocation. Do not replace these with mocks that merely repeat implementation.

Cross-component E2E: ingest approved fixture → publish → browse through generated Swift client → download/checksum → place/save/relaunch offline → duplicate/delete reference → rights revoke → next online check removes cache → next Design load shows absence. CI verifies OpenAPI regeneration, contract versions and malformed/oversize/corrupt inputs. Use local S3-compatible storage for repeatable integration and a real Spaces smoke test for actual CDN behavior; the former does not prove the latter.

Device only: physical lighting, environment occlusion, hand input/post-release semantics, scan coverage, re-localization, permission/capture exports, display pacing and thermal/memory behavior. Founder operates M2; report build, scene, movement route, frame times p50/p95/p99/max, missed frames, memory peak/resident, texture bytes and sustained duration. Performance acceptance: 20 representative placements, two active virtual lights, 15 minutes walking/turning/culling, 90 Hz with no dropped frames. Four low-poly fixtures cannot prove this. M4 uses real contract-conformant LODs and texture budgets; library acquisition blocks that evidence.

Visual QA is comparative evidence: fixed room/light/pose protocol, captures where permitted, named observations and repeated checks. No “looks good” pass. No fleet analytics: first-placement/session counts can be observed in supervised demos, population retention/conversion cannot be claimed. Local diagnostics only, no collection endpoint/SDK. CI/tooling pass is never called device E2E pass.

## 10. Operations, cost and limitations

Smallest viable fixed App Platform container, Managed PostgreSQL single node, Spaces+CDN; no replicas, autoscaling, queue or worker deployment. Start $5/month 512 MiB App Platform + approximately $15/month Managed PostgreSQL + $5/month Spaces = approximately US$25/month baseline, excluding tax/FX/domain. Verify capacity via startup/load/memory tests; if 512 MiB is insufficient, report measured reason before increasing tier. Set billing notification at 1.25 × estimated total (initial $31.25), never automatic shutdown.

Variable costs: Spaces stored bytes across masters/LODs/revisions, CDN/origin download egress, API transfer above included allowance, database storage growth. Public asset URLs permit unexpected third-party egress: alert and inspect operational volume, not user tracking. Current pricing sources (checked 2026-09-19): https://docs.digitalocean.com/products/app-platform/details/pricing/, https://docs.digitalocean.com/products/spaces/details/pricing/, https://www.digitalocean.com/pricing/managed-databases. Reconfirm rate/allowance at provisioning, estimate library bytes from actual manifest, and separately estimate downloads = testers × new rendition bytes × refreshes. Presigned downloads are not edge cached on Spaces; public published URLs are the agreed solution (https://docs.digitalocean.com/products/spaces/how-to/manage-cdn-cache/).

Limitations: M5 untested; no independent accessibility testing; no high availability or tested database restore path; no portable local backup/restore; no client usage telemetry; no fleet product metrics; device revocation best-effort offline; no guaranteed recovery from ambiguous scans. Managed backups existing is not evidence of successful restoration. Credentials/signing, licence acceptance, physical device evidence and asset budget cannot be manufactured by an agent.

## 11. Risks and stop conditions

- Public API names/capabilities must be proven using installed visionOS 27 SDK; marketing terminology is not an interface contract.
- Invalid-release continuation may conflict with system gesture lifecycle; resolve in M0, never silently replace with re-grab.
- Passthrough export may require unavailable permissions; nonblocking for M0 but an explicit M3 scope decision.
- Floor/wall frame ambiguities can misalign whole Designs; verify alignment and preserve data rather than display false precision.
- Filesystem and SwiftData writes are not one transaction; journals and restart tests are necessary for deletion/publication/cache integrity.
- CPU/file checksum and decoding spikes must be profiled alongside GPU work; immutable files still require corruption detection.
- Public asset revocation cannot erase already distributed copies; legal acquisition must accept this model.
- Library readiness sits outside engineering sequence and gates representative performance, M4 and release. No claim of completion based on placeholders.
