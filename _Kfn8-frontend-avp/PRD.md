# Kfn8 — Product Requirements Document

**Version:** 0.3 (2026-09-19 interview amendments: anonymous, local-only MVP1)
**Date:** September 2026
**Owner:** OffsideAI / Platform6ix Inc.
**Status:** Implementation authorised against TECHNICAL-PLAN.md and ROADMAP.md. Routine approval pauses waived; M0 feasibility gates remain.

**Decision precedence:** This revision incorporates Q1–Q55. Roadmap checkboxes report evidence, not intent. Later-version concepts below are explicitly deferred. SDK feature claims require M0 verification, not acceptance on documentation alone.

---

## 1. One-line description

Kfn8 is an Apple Vision Pro app that lets you place furniture, lighting and decor (approved generics in MVP1; purchasable retailer SKUs in v1.1) into your actual home at true scale — room by room — and see it lit, shadowed and occluded by your real space before you spend a dollar.

**MVP1 is indoor rooms only, visionOS 27 only.** Yards, patios and other outdoor spaces are designed for (§8) and deferred to v1.1.

## 2. Why this, why now

Furniture is the highest-consideration, highest-return-rate category in retail that people still buy from a 2D photo on a white background. The two questions every buyer has — *does it fit* and *does it go* — are spatial questions answered today with a tape measure and imagination.

Phone AR has attacked this for six years (IKEA Place, Amazon "View in Your Room", Wayfair View in Room) and plateaued, because a phone gives you a keyhole: one object, held at arm's length, on a 6-inch screen, with no sense of the room as a whole. You cannot evaluate a *room* through a keyhole.

Vision Pro removes the keyhole. You stand in the room. The sofa is the size of a sofa. You walk around it. And as of **visionOS 27**, the platform closed the three gaps that made earlier headset attempts feel like stickers pasted on video:

- **Physical space lighting** — virtual objects now cast light onto your real walls and floor, using the LiDAR mesh of the room plus the ambient light sensor. A virtual floor lamp now actually lights the corner it's standing in.
- **Environment Occlusion** — real geometry occludes virtual objects properly, so a chair can sit *behind* your real coffee table.
- **3D Gaussian Splat rendering in RealityKit** — photoreal captures of real objects can be rendered efficiently, which is a v1.1 candidate. MVP1 has only a minutes-long, nonblocking feasibility check; no splat assets ship.

Add **Reality Composer Pro 3** (AI-assisted asset generation, animation/script graphs) and the asset pipeline cost curve bends too.

The window: headset installed base is still small, but the *enterprise* side of this product doesn't depend on headset volume. A furniture brand's 3D catalogue is an asset they already pay to produce for web AR. Kfn8 is a new, premium surface for it.

### Platform baseline: visionOS 27 only

**Decided.** Kfn8 targets visionOS 27 and above, on Apple Vision Pro (M2 and M5). There is no visionOS 26 fallback path, no availability checks, no degraded rendering mode.

Physical space lighting, Environment Occlusion and ManipulationComponent are the blocking M0 capabilities. visionOS 27 is the chosen floor, not a claim that platform behavior has already been verified. Splats are nonblocking and production splat assets are deferred to v1.1. No fallback path is authorised.

Rationale in full: `SALIENT-NOTES.md`.

## 3. Naming note

`Kfn8` was previously the working placeholder for the trades-training app now shipping as **ScannerDarkly**. That frees the name, but there are two live issues: (a) internal docs and old repos may still reference KFN8 meaning the trades app, and (b) "Kfn8" is hard to say, hard to spell from speech, and unsearchable in the App Store. Recommend treating it as a codename and resolving a consumer-facing name before TestFlight. Tracked in §16.

## 4. Goals and non-goals

### Goals
1. Let a person furnish and decorate a real room in their home, at true scale, in under five minutes from app launch.
2. Make the result believable enough to change a purchase decision — correct scale, correct materials, correct lighting, correct occlusion.
3. Let them save, revisit, compare and share designs of a persistent space.
4. Ship an onboard USDZ library that makes the app useful with zero network, and a FastAPI-backed catalogue that makes it endlessly extensible.
5. Build private, operator-invoked ingestion and recorded approval tooling for our own catalogue. Tenant self-service arrives in v1.1.

### Non-goals (MVP1)
- **No outdoor spaces.** Yards, patios, decks and balconies are out of scope for MVP1. The design exists (§8) and ships in v1.1.
- **No backward compatibility.** visionOS 27 is the floor. No conditional code paths for older releases.
- Not a CAD/architecture tool. No wall-moving, no structural editing, no construction documents. (That's adjacent to **Offside Plan** — see §14 for the relationship.)
- Not a marketplace. Kfn8 does not process furniture transactions in v1; it hands off to the retailer.
- Not a social network. MVP1 sharing is still-image export only if the M0 probe proves real-room capture; links/web viewer arrive in v1.1.
- Not cross-platform at launch. iPhone/iPad appear only as **capture companions** (§8), not as full editors.
- No generative "design my room for me" autopilot in v1. Assisted suggestions arrive in v1.2 once we can trust the catalogue metadata.

## 5. Target users

**Primary — The Homeowner Mid-Renovation ("Priya").** Bought a house, three rooms unfurnished, a real budget, a partner with opinions. Owns a Vision Pro or has access to one. Her pain is committing $4,000 to a sectional she's seen only as a photo. She wants *confidence*, and she wants to settle an argument.

**Secondary — The Renter Optimizer ("Dev").** 700 sq ft, everything must earn its place. Wants to know if the desk fits between the window and the radiator, and whether the whole thing reads as coherent. High engagement, low spend per item, high frequency.

**Tertiary — The Pro-sumer Designer ("Marie").** Freelance interior decorator or stager with a handful of clients. Needs to present options to a client, in the client's actual home, without a mood board. She's the one who'll pay a Pro tier and who generates the case studies that sell the enterprise deals.

**Buyer, not user — The Retail Digital Merchandising Lead.** At IKEA, Wayfair, Article, EQ3, Structube. Already owns 3D assets for web AR. Measured on conversion and return rate. Buys the Enterprise tier. Never wears the headset except in a demo.

## 6. Competitive landscape

| Product | What it does | Where it leaves room |
|---|---|---|
| IKEA Kreativ | Phone capture → replace-your-room with IKEA product | Single-brand, phone-only, 2D compositing feel |
| Amazon / Wayfair "View in Room" | Single-item phone AR | One object at a time, no scene, no persistence |
| Houzz, Planner 5D, Morpholio Board | 2D/3D planning on a screen | Not in the space, not at scale, imagination still required |
| RoomPlan-based scan apps | Produce a room model | Stop at the model; no shopping, no decoration |
| Shapr3D / CAD on Vision Pro | Precise spatial modelling | Professional tool, wrong job, wrong price |

**Kfn8's wedge:** multi-brand catalogue + whole-room composition + true-scale presence + real lighting, on the one device where all four are possible simultaneously.

## 7. Core concepts (domain model)

A shared vocabulary for the product and, later, the API.

- **Space** — a persistent real-world location belonging to the user. "Home". Contains Rooms.
- **Room** — a scanned, anchored region within a Space. "Living room", "Main bedroom". Has geometry (mesh, planes, dimensions) and a geometry-derived room-local frame. Session world anchors locate that frame; loss of an anchor never deletes the Design. Geometry, frame references and structured scan elements stay local.
- **Design** — a named, continuously autosaved current arrangement of Placements within a Room; alternatives use duplication. A monotonic counter is reserved for future sync conflicts, with no stored or user-facing revision history. Users can hold several ("Warm option", "Minimal option") and flip between them.
- **Placement** — one Asset instance in a Design: stable client-generated ID, room-local rigid transform, pinned asset revision, material/colour variant, and provenance (which catalogue, which SKU).
- **Asset** — a 3D model with metadata: real-world dimensions, placement affinity (floor / wall / ceiling / tabletop / freestanding-outdoor), pivot convention, material variants, LODs, licence terms.
- **Catalogue** — a named collection of Assets from one source. `kfn8://core` (onboard), `kfn8://community`, `tenant://ikea-ca`.
- **Tenant** — an enterprise customer with their own Catalogue, entitlements, branding and analytics.

## 8. Outdoors — designed, deferred to v1.1

**Status: out of scope for MVP1.** Recorded here so the MVP1 data model doesn't foreclose it. Nothing in this section gets built in MVP1 except the two schema allowances noted at the end.

Yards and backyards deserve an explicit decision because they're the one place the platform fights us.

Vision Pro is a poor *outdoor* device: direct sunlight degrades IR-based tracking and hand detection, glare washes out passthrough, the battery is tethered, and it is socially conspicuous on a driveway. Pretending otherwise produces a feature that demos badly.

**The decision: capture outdoors on iPhone, compose indoors in the headset.**

1. **Kfn8 Capture** (companion iOS app, minimal) uses the iPhone/iPad LiDAR + photogrammetry to capture the yard, deck or patio — producing both a geometric mesh and a **3D Gaussian Splat** for photoreal appearance.
2. The capture syncs to the backend and becomes an **Offsite Room** in the user's Space.
3. In the headset, the user opens that Offsite Room in a **Full Immersive Space** — they are standing in a photoreal reconstruction of their own back yard — and furnishes it with patio sets, planters, pergolas, outdoor lighting.
4. On-site verification, if wanted, happens back on the phone in ordinary AR.

This is a feature, not a workaround: it means you can shop for your patio furniture in January, from the sofa, standing in a summer capture of your own yard. It also gives us the architecture for **remote spaces** generally — a designer furnishing a client's home from her own studio, which is the Pro-tier story.

Indoor rooms use live passthrough (Mixed immersion). Outdoor rooms use captured reconstruction (Full immersion). Same Design model underneath.

**What MVP1 must allow for (and nothing more):**
1. `Room` carries a `kind` discriminator (`live` | `offsite`) from day one, even though only `live` is implemented. Retrofitting this into a synced schema later is painful; adding one enum case now is free.
2. Placement affinity already includes `freestanding-outdoor` in the asset contract (§11.1), so outdoor SKUs can be catalogued and validated ahead of the client work.

Everything else — the capture companion app, splat reconstruction, Full Immersive Space rendering, offsite sync — waits for v1.1.

## 9. Key user journeys

### J1 — First run to first placed object (target: under 5 minutes)
1. Launch → short spatial onboarding in a Window explaining what Kfn8 does.
2. **Scan this room** — guided placement-ready capture, targeting 60–90 seconds, with live coverage feedback. Classify floor, wall, ceiling and horizontal supports. Preserve structured elements returned by the same scan locally, without semantic UI or dependent features.
3. Room is named and saved as a persistent anchored Room.
4. The **Catalogue** opens as a floating Window beside the user; the **Staging Volume** shows an inspection preview: 1:1 when it fits, otherwise uniformly scaled to fit the Volume, with real dimensions shown. Room placement is always 1:1.
5. User pinches an item and drags it into the room. It snaps to the floor, orients sensibly, casts shadow and light.
6. Prompt: "Save this as a Design?"

### J2 — Furnishing a room
- Browse catalogue by room type, category, style, colour, price, brand, with **"fits here"** deferred to v1.1.
- Place, move, rotate with `ManipulationComponent`; one attachment system parameterised by affinity. Real-geometry intersections are rejected; virtual overlap is permitted with a subtle cue, with rugs/mats exempt. Invalid release searches only about 25 cm, then retains an unsaved manipulation preview. Cancel restores the pre-drag state or removes a new object.
- Swap material/finish variants in place without re-placing.
- Measure: a lightweight distance/clearance readout when an object is selected (gap to wall, gap to neighbour, walkway width).
- Undo/redo.

### J3 — Comparing and deciding
- Duplicate a Design, change five things, then **A/B flip** between them with a gesture — the whole room changes at once. This is the single most persuasive interaction in the product.
- *(v1.1)* **Daylight scrub**: preview the room under morning / midday / evening / lamps-only lighting, using the room's window positions from the scan. Depends on physical space lighting and projective textures.
- **Shopping list / room inventory:** all placements with quantities and dimensions. Generics have no invented price/link and an all-generic list has no subtotal. Priced items refresh independently; cached prices carry dates, subtotals a collapsed date/range and “priced items only” when needed. Delisted items retain dated last prices and unavailable status.

### J4 — Sharing
- MVP1: still-image export of the actual room plus placements, only if M0 concretely writes and opens such a file through a permitted API. Explicit home-image consent at export; no automatic upload, watermark or furniture-only substitute.
- v1.1: spatial video, Design links/web viewer, portable data export/restore.
- v1.2: SharePlay.

### J5 — Private ingestion (MVP1)
The founder runs a command that resumes persisted validation/conversion/approval stages. Provenance/licence approval and visual/dimension approval are separate evidence records: approver, date, source and evidence hash. Publication is idempotent. Unpublished, rejected and in-review sources remain private.

Tenant onboarding, self-service feeds, roles/invitations and analytics dashboards are v1.1; no tenant account system or queue in MVP1.

## 10. Feature scope

### MVP1 (v1.0) — the thing that has to be good

*Indoor rooms only. visionOS 27 only. Apple Vision Pro only.*

- Room scanning and persistent anchoring; multi-room Spaces.
- Onboard USDZ starter library (~150–250 curated assets across seating, tables, storage, beds, lighting, rugs, plants, wall art).
- Remote catalogue browse/search/download with on-device caching.
- Place / move / rotate / delete, with floor-wall-surface snapping and collision.
- Material and colour variants.
- Designs: save, name, duplicate, A/B flip.
- Lighting realism: physical space lighting, environment occlusion, contact shadows.
- Measurements and clearance readouts.
- Shopping list with retailer handoff links.
- Still-image export.
- Anonymous use; all Spaces, Rooms and Designs remain device-local. No account, sync, subscription gating, commercial limits, watermark or product analytics.

### v1.1
- Email/password accounts, explicit FastAPI sync, Free/Plus limits and watermark; no third-party login.
- Tenant console, self-service ingestion and analytics; queue only when needed.
- Production splat assets, Design links/web viewer, portable export/restore and consented product analytics.
- Kfn8 Capture companion app; outdoor/Offsite Rooms via Gaussian splats.
- Daylight scrub.
- Spatial video export.
- "Fits here" filtering and clearance warnings (door swing, walkway minimums).

### v1.2
- SharePlay co-presence.
- Style suggestions: given what's in the room, recommend complements from the catalogue (metadata-driven, not generative).
- Pro tier: client spaces, branded presentation mode, PDF/deck export.
- Object Capture ingestion: let a user scan *their own existing* furniture into the room so designs include what they already own. This is a quiet killer feature — the room isn't empty.

### v2.0 and beyond
- Wall/floor finish replacement (paint, tile, flooring) via projective textures — opens the paint and flooring verticals.
- Generative layout assistance.
- Trade/contractor mode and handoff to **Offside Plan** for measured drawings.

## 11. 3D model strategy — obtain, curate, generate

This is the real product. The app is a viewer; the catalogue is the moat. Five sources, in the order they should be built.

### 11.1 The asset contract (write this first)

Nothing enters the catalogue without passing a single specification. Every source below is judged against it.

- **Format:** authored/stored as glTF 2.0 (GLB) as the neutral master; USDZ generated from it for delivery. Both kept.
- **Scale:** metres. Every asset has a first-class declared dimension specification with authority, source, approver and date alongside its licence record. Generics use approved source dimensions after a furniture-scale sanity check; named SKUs use published retailer dimensions. Validate GLB, every LOD and USDZ within ±1% of the spec and check cross-format consistency. This establishes declared-spec consistency, not independent physical accuracy.
- **Origin and orientation:** pivot at the base centre of the object's footprint; +Y up; front face toward −Z. Non-negotiable — this is what makes snapping and rotation feel right.
- **Topology:** clean normals, no flipped faces, non-overlapping UV channel for AO/lightmaps, watertight where it matters.
- **Triangle budget:** LOD0 ≤ 150k for a hero sofa, ≤ 50k typical; LOD1 and LOD2 generated automatically. Vision Pro renders a whole room at 90 Hz — budget is per-scene, not per-asset.
- **Materials:** PBR metallic-roughness, channel-packed, no baked-in lighting, texture sets ≤ 2k with 1k variants for distance.
- **Variants:** material/colour options expressed as a variant set on one mesh, not as duplicate assets.
- **Metadata:** dimensions, weight class, placement affinity, category taxonomy, style tags, dominant colour (for filtering), price, availability, retailer URL, licence and attribution, source provenance.
- **Validation:** automated gate in CI. Validate against our published asset contract. No Khronos certification or standards-conformance claims. Preserve aligned conventions, but revisit external certification only with a real enterprise opportunity. Recorded human approvals bind to the exact asset revision; provenance approval remains mandatory for every asset; visual/dimension review is also universal at launch and sampling changes require a later evidence-based decision.

### 11.2 Sources, in build order

**(1) Licensed core library — buy it, don't build it.** The fastest path to a credible onboard library is licensing existing, well-made furniture sets from marketplaces (TurboSquid/Shutterstock, CGTrader, Sketchfab) under commercial/extended licences, plus genuinely permissive CC0 sources (Poly Haven, ambientCG for materials, the CC0 furniture sets that already ship GLB/USDZ). Budget: a curated 200-asset launch library, remastered to the §11.1 contract, is a five-figure exercise, not six. Every licence goes into a **licence ledger** table from day one, because an enterprise buyer's legal team will ask, and because mixed-provenance libraries are how startups acquire IP liabilities.

**(2) Commissioned generics.** For the gaps — and for anything that will appear in marketing — commission a small, consistent modelling studio (or two reliable contractors) working to the contract. 40–80 hero assets at consistent quality does more for perceived catalogue quality than 2,000 scraped ones. Consistency of style and scale is the thing users notice; they just call it "this app feels good".

**(3) In-house photogrammetry via Object Capture.** Apple's Object Capture (RealityKit, Mac + iPhone) turns a turntable session into a production USDZ. This is how you (a) build out decor, plants, lamps, vases, and small goods cheaply, (b) produce the "scan your own furniture" feature in v1.2 as a user-facing capability, and (c) offer retailers a *service*: send us the product, we'll produce the asset. That service is also the wedge into enterprise deals — it's the thing a merchandising lead will pay for before they'll pay for distribution. Production Gaussian splat capture and assets are deferred to v1.1; they are outside the MVP1 mesh contract.

**(4) Generative 3D — as an accelerator, not a source.** Text/image-to-3D (Reality Composer Pro 3's AI asset generation, plus Meshy, Tripo, Rodin and similar) is now good enough for three specific jobs: background and filler props nobody inspects closely, rapid greybox placeholders while a real asset is commissioned, and *variation* on an approved base mesh (different cushion, different finish). It is not yet good enough for a $3,000 sofa that the user is deciding whether to buy — current output tends to jagged or bloated geometry, baked-in lighting, and textures that fail QA. Policy: generative assets are permitted, must pass the same validation gate, and must carry a `provenance: generated` flag. Never present a generated approximation of a real, named, purchasable SKU. That's the line where a helpful visualisation becomes a misrepresentation, and it's also the line that loses you the IKEA deal.

**(5) Retailer-supplied — the endgame.** Most large furniture retailers already commission GLB/USDZ for web AR. The enterprise product is a pipe that ingests those assets, normalises them to the contract, and distributes them with live price and availability. Kfn8 supplies the surface and the QA; the retailer supplies the truth. Long term this is where catalogue breadth comes from, and it costs us ingestion engineering rather than modelling spend.

### 11.3 The ingestion pipeline

```
submit → format detect → geometry validation → scale check vs declared dims
   → material/PBR normalisation → LOD generation → USDZ conversion
   → thumbnail + turntable render → metadata enrichment → human spot-check
   → licence ledger entry → publish to catalogue → CDN
```

Runs as a private operator command, without queue infrastructure or a deployed worker. Each stage persists state, input fingerprint and structured report in Postgres. Rerun resumes the first incomplete/invalidated stage. Stage functions are independent of invocation. Publication is idempotent and requires both recorded approval kinds; failures explain the fix. Approval sampling is a later decision, not a launch compromise.

### 11.4 Curation

Breadth is not the goal; *coherence* is. Ship the library organised by named style collections rather than an undifferentiated grid — a user furnishing a room wants things that go together, and a curated collection is also merchandisable surface for enterprise tenants later. Each asset carries style tags that drive the v1.2 suggestion engine.

## 12. Spatial UX and design language

**Window / Volume / Immersive Space split:**
- **Window** — catalogue browser, search, shopping list, Design manager. Ordinary SwiftUI, familiar, dense.
- **Volume** — the Staging Volume: an inspection preview, scaled to fit, with true dimensions shown. Fits within the envelope remain 1:1; larger objects downscale uniformly. Placed objects are always true scale.
- **Mixed Immersive Space** — the room itself, with the scene mesh, placements, lighting and occlusion. This is the whole of MVP1.
- **Full Immersive Space** — Offsite Rooms (yard, remote client space) rendered from capture. *v1.1, not built in MVP1.*

**Interaction principles:**
- Indirect pinch-and-drag for everything reachable; direct touch when the user walks up to an object.
- Gravity is always on: objects land on the floor or the surface under them, never float, unless the affinity says wall or ceiling.
- Snapping is felt, not seen — subtle haptic-equivalent audio cue and a brief alignment guide, no persistent grid.
- The room's real furniture is respected: collision against the scene mesh, so a virtual sofa won't sit inside a real wall.
- Nothing occludes the user's view of their own room by default. UI docks to the side and dims when they walk.

**Visual identity:** warm and gallery-like, not technical. Bone and paper neutrals, walnut and clay mid-tones, a brass accent for selection and active state, ink-black for text. Deliberately avoids the cool blue-violet default palette of spatial demos — this app should feel like a showroom, not a HUD. Typeface pairing in the house direction: Fraunces for display, Hanken Grotesk for UI, mono only in the partner console.

Working name for the design language: **Showroom**.

## 13. Backend

`_Kfn8-backend-fastapi` backend component in the parent `kfn8` monorepo: async FastAPI, SQLAlchemy 2.x, Alembic and Managed PostgreSQL on DigitalOcean App Platform. Private operator ingestion/approval tooling lives alongside it. No queue/worker or tenant-facing frontend in MVP1. Backend owns versioned API/asset contracts; Swift transport models are generated from them. Breaking APIs are versioned for independently deployed clients.

Postgres holds catalogue metadata, revisions, dimension authority, approvals, stage state and licence ledger, never binaries. Include tenant_id (Kfn8 only initially) and delivery_mode (public/restricted; restricted publication unimplemented/rejected). Anonymous catalogue reads have no account entitlement logic. No scan or Design upload endpoints.

Published public assets use immutable revision-qualified content-addressed Spaces CDN URLs; private sources/review/rejected assets never use a public prefix. Hashes identify bytes, not access control. No asset-byte proxy through FastAPI. Commercial delisting leaves downloads/cache usable; rights revocation removes origin objects, verifies CDN purge and publishes cursor-based deltas. Devices remove cached bytes when notified, preserving already loaded scene entities until next Design load. Offline revocation is best-effort.

Pin required revision/LOD files while any saved Design references them. Bundled assets never evict; unreferenced downloads evict by recency. Verify hashes before load; recover corruption by download or identify specific missing items. Never silently discard pinned content for storage pressure.

Smallest viable managed tiers, no autoscaling/replicas/high availability. Report baseline and usage-driven storage/egress costs; billing notification at 125% of estimate, no shutdown. Server operational telemetry only; no client usage collection.

## 14. Relationship to the rest of the portfolio

- **Offside Plan** (LiDAR scan → blueprint) shares the capture and room-geometry problem end-to-end. Same scanning core, different output: Offside Plan produces measured drawings, Kfn8 produces furnished scenes. Shared-package extraction remains deferred; MVP1 does not scaffold speculative portfolio reuse.
- **ScannerDarkly** shares the visionOS shell, RealityKit patterns, asset pipeline and 3D-model QA tooling. The ingestion pipeline built here serves both.
- The enterprise catalogue-hosting pattern (tenant, feed, entitlement, analytics) is reusable infrastructure.

## 15. Privacy

- MVP1 is anonymous. Scans, geometry, structured scan elements, Spaces, Rooms, Designs and placement coordinates remain on this device. No opt-in geometry upload, CloudKit sync, analytics SDK, usage collection endpoint or consent flow for analytics.
- Accurate claim: “We never upload your scan.” Do not claim design coordinates reveal nothing about a home. Future v1.1 Design sync must explain coordinates separately from scans.
- Still-image export, if feasible, requires explicit consent at export and never uploads automatically.
- Permanent deletion removes actual scan files and domain records with counted confirmation and “can't be undone”; no archive/trash. Shared asset pins survive while referenced elsewhere.
- Full portable data export and restore are deferred to v1.1. MVP1 user work is local-only and is lost on device loss or app deletion; there is no Kfn8 recovery copy.
- Local development diagnostics may be read from a dev headset; no collection endpoint. Server health metrics are operational observability, not product analytics.
- No selling of spatial data. Future enterprise analytics must never expose customer scans or per-user trails.

## 16. Business model

**MVP1:** no Free/Plus enforcement, commercial Space/Room/Design limits, subscriptions, upgrade prompts or export watermark. The consumer tiers below begin with accounts in v1.1 (Pro features remain v1.2); do not implement enforcement early.

**Consumer — future tiers**
- **Free:** one Space, up to three Rooms, onboard library plus a rotating slice of the remote catalogue, image export with a small watermark.
- **Kfn8 Plus — ~$9.99/mo or $79/yr:** unlimited Spaces and Rooms, full catalogue, unlimited Designs, spatial video export, daylight scrub, no watermark.
- **Kfn8 Pro — ~$39/mo:** client Spaces, branded presentation mode, PDF/deck export, SharePlay sessions, priority Object Capture turnaround.

**Enterprise (the real revenue line)**
- **Catalogue Hosting — annual contract, tiered by SKU count:** the retailer's on-sale catalogue lives in Kfn8 with live price and availability, brand-presented collections, and placement analytics. Indicative: $25k/yr entry (up to 500 SKUs) → $150k+/yr (full catalogue, multi-region).
- **Asset Production Services:** we model or capture their SKUs to the contract. Per-asset pricing. Often the first contract signed, and it de-risks the hosting deal.
- **Featured Placement:** merchandised collections and category sponsorship inside the catalogue browser — disclosed as sponsored, always.
- **Affiliate / referral:** revenue share on handoff-attributed purchases. Meaningful later, not a launch assumption.

**Why a retailer buys it:** they already spend on 3D assets; this is incremental distribution on a premium surface with a demonstrably high-intent audience, plus placement analytics they cannot get anywhere else — *which of our SKUs do people actually put in their living rooms, next to what, in which finish*. That dataset is the pitch. Not the headset count.

**Beachhead:** Canadian mid-market furniture retail (Article, EQ3, Structube, Elte, CB2 Canada) is reachable, decision-makers are accessible from Toronto, and a signed logo makes the IKEA conversation possible. IKEA is the aspiration, not the first call.

## 17. Success metrics

**MVP1 measurement limitation:** no client usage analytics. Population product-health, retention and conversion metrics below are future targets, not measured launch claims. Use qualitative TestFlight feedback and direct observation; supervised first-placement timings are possible. No high availability, no tested database restore path, M5 untested, and no independent accessibility testing.

**Product health — future population targets**
- Time from launch to first placed object (target < 5 min on first run, < 60 s thereafter).
- Objects placed per session (target ≥ 8).
- Designs saved per active user per month (target ≥ 2).
- Return rate to a previously scanned Room (target ≥ 40 % of users within 14 days) — this is the retention signal that matters; a one-shot novelty app doesn't get this.
- Session length in immersive space (target ≥ 12 min).

**Commercial**
- Free → Plus conversion (target 6–9 %).
- Handoff click-through per Design containing catalogue items.
- Enterprise: tenants live, SKUs hosted, ARR, and *placements per hosted SKU* (the number we report back to them).

**Catalogue health**
- Assets passing automated validation first time (target ≥ 80 % by month 6).
- Median ingestion time from submission to live (target < 24 h).
- Share of catalogue validated against approved declared dimensions (target 100 %).

## 18. Risks

| Risk | Severity | Response |
|---|---|---|
| Vision Pro installed base is small, and visionOS 27-only narrows it further | High | Enterprise revenue does not depend on consumer volume; build the asset pipeline as a standalone business asset; Vision Pro update adoption is fast and the gap closes monthly; keep an iPad path open for v2 |
| Asset quality is the product, and it's expensive | High | Licence + remaster before commissioning; strict contract; generative only where it can't hurt |
| Retailers already have AR and may see us as a competitor | Medium | Position as distribution + analytics, never as a storefront; no transactions in v1 |
| Scale/realism errors destroy trust in one bad placement | High | Dimension verification is a hard gate; clearance warnings; never generate a real SKU's geometry |
| Privacy backlash over home scans | Medium | On-device default, aggregate-only enterprise analytics, stated plainly |
| Outdoor use fails on-device | Low (MVP1) | Out of scope for MVP1; designed around for v1.1 (§8) |
| Required spatial capabilities underdeliver | **High** | Physical space lighting, Environment Occlusion and ManipulationComponent gate M0. After one minutes-long obvious-setup check, stop with measurements and founder options. Splats never block M1 or reopen D1. |

## 19. Open questions

**Deferred by decision (Sept 2026).** These are parked, not forgotten — revisit after M0. None of them is expected to block M0–M4.

1. **Name.** Resolve `Kfn8` before TestFlight; it collides with the ScannerDarkly heritage and is unsearchable.
2. **Resolved in interview:** MVP1 launch library is generics only. Budget/acquisition follows M0, separate from the four engineering test models.
3. **Community catalogue in v1 or not?** User-submitted assets add breadth and a moderation burden. Recommend deferring to v1.2.
4. **How much of Offside Plan's capture core is reusable today**, and should it be extracted into a shared package now rather than later?
5. **Pricing of Asset Production Services** — needs a real cost model per asset before it goes in a deck.
6. **Region/availability handling** for tenant catalogues: is a SKU's price/stock per-country in v1, or single-region?

**Resolved since v0.1:** minimum OS (visionOS 27 only, §2); outdoor scope (deferred to v1.1, §8).

## 20. Milestones

MVP1 order: M0 → M1 → M2 → M3 → M4 → M6 → M7. ROADMAP.md has one Epic per milestone. Routine approval pauses are waived by the 2026-09-19 execution instruction; unresolved feasibility/product decisions still stop dependent work.

- **M0 — Feasibility.** Blocking: physical space lighting, Environment Occlusion, ManipulationComponent on M2/visionOS 27. One short obvious-setup investigation, then measured failure/quality shortfall goes to founder; no workaround/fallback. Nonblocking: real passthrough export file; one few-minutes splat attempt (no debug/search/production), recording size/load/frame observations or unavailable ingestible asset. SDK licence/setup/signing/device access are prerequisites.
- **M1 — Scan and place.** Four conformed real engineering models (floor/wall/ceiling/tabletop), early backend-owned contract/ledger gate, room-local persistence/recovery, one attachment system, non-gesture controls. Whole library is not required to prove these four paths.
- **M2 — Catalogue.** Anonymous API, generated Swift contract, public CDN delivery, cache/pins/revocations and operations. The monorepo revision (when explicitly authorised), component build IDs and contract hash identify completion; no accounts/entitlements/sync.
- **M3 — Designs.** Autosave, duplicate, A/B flip, session undo/redo, generic-first inventory and priced path; still export only if concretely feasible or explicitly re-scoped.
- **M4 — Realism.** Lighting, shadows, materials, clearances, representative M2 performance. 20 mixed placements, two active virtual lights, 15 continuous minutes of walking/turning, target 90 Hz and zero dropped frames. Report distributions/worst spikes/memory, not averages. Launch-library acquisition or realistic conformed stand-ins gates this; four low-poly fixtures are insufficient. No daylight scrub.
- **M6 — Private ingestion.** Operator command, durable resumable stage state, evidence-based approvals, idempotent immutable publication. No worker/queue/tenant console/connectors/dashboard.
- **M7 — TestFlight and launch.** Complete approved library, device E2E, qualitative feedback, signed release, truthful privacy/limitations. M2 gates launch; M5 untested, not assumed proven.
- **M5 — Capture companion/outdoor.** v1.1 only; not an MVP1 Epic or scaffold.

Accessibility is inline in every UI milestone: VoiceOver reaches controls, text scales without clipping, reduced-motion alternatives exist, and every spatial-only gesture has a non-gesture path. No independent audit is claimed.

## 21. Interview amendment record

2026-09-19: Q1–Q55 resolve the MVP1 scope reflected above. Rationale: local anonymous use avoids speculative auth/sync/paywall; public generic assets permit CDN caching; operator ingestion matches a single submitter; room-local frames preserve Designs across anchor loss; immutable revisions preserve composition; declared dimensions make conversion drift testable; no telemetry trades population metrics for qualitative feedback. Launch assets and toolchain/device readiness remain external dependencies. TECHNICAL-PLAN.md contains implementation details; ROADMAP.md tracks evidence and outstanding work.

**Repository amendment:** the founder superseded the separate-repository decision with a single `kfn8` monorepo targeting `main`. No nested Git repositories or Git operations without explicit approval.
