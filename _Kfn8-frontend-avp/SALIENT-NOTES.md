# Kfn8 — Salient Notes

**Companion to:** `PRD.md` v0.3
**Subject:** Why MVP1 is visionOS 27 only, and why outdoor spaces are deferred
**Date:** September 2026
**Status:** Rationale record. Read this when someone asks "why didn't you support visionOS 26?" or "where's the backyard feature?"

---

**2026-09-19 amendment:** Q1–Q55 supersede earlier release assumptions. Blocking M0 capabilities are physical space lighting, Environment Occlusion and ManipulationComponent. Splats are nonblocking and production splats are v1.1. No accounts, sync or geometry uploads in MVP1. Platform descriptions below are rationale, not measured proof; M0 verifies the installed SDK and M2 behavior.

## Part A — visionOS 27 only

### A.1 The short version

MVP1 commits to one visionOS 27 rendering path. Physical space lighting, Environment Occlusion and ManipulationComponent must meet the product claim on M2 before M1. No backwards compatibility or degraded fallback. Production Gaussian splats are deferred to v1.1 and do not justify or gate MVP1.

### A.2 Product benefits

**1. The core claim survives contact with a real room.**
Kfn8's pitch is "believable enough to change a purchase decision." That claim rests entirely on three things happening automatically: a virtual floor lamp casting real light onto the user's real wall (physical space lighting), a virtual chair being properly hidden behind the user's real coffee table (Environment Occlusion), and shadows landing where physics says they should. On visionOS 26 all three are absent or approximated. A user who sees a lamp that emits no light has learned, in two seconds, that this is a toy.

**2. One rendering path means one quality bar.**
Every dual-path app eventually tunes for the lowest common denominator, because that's the build that generates the support tickets. The premium path becomes "the same thing but slightly nicer," which is not a reason to buy a Vision Pro app. A single path means every hour of realism work lands for every user.

**3. Design can commit.**
Interaction design for spatial apps is mostly a series of bets about what the system will do for you. If lighting might or might not be present, the UI needs a manual lighting control, a preview disclaimer, and a settings toggle. Deleting the fallback deletes all three. The interface gets quieter, which on this platform is the whole game.

**4. `ManipulationComponent` and the visionOS 27 manipulation stack come for free.**
Placement, grab, rotate and release — the single most-used interaction in the app — are handled by first-party components with correct physics, correct haptics-equivalent feedback and correct hand-off between direct and indirect input. Hand-rolling that for a 26 fallback is weeks of work producing something measurably worse.

**5. Gaussian splats are a v1.1 investigation, not an MVP1 hero tier.**
No splat assets ship in MVP1 and no hero-SKU/App Store screenshot benefit is claimed. M0 allows one best-effort attempt with the approved sample, a few minutes maximum, no debugging or additional search. Report size/load/frame behavior if ingestible; otherwise record no readily available ingestible asset. A large (~2M) sample's poor performance is not a renderer verdict. Findings inform v1.1 and never reopen D1 or block M1.

**6. v1.1 still has unproven splat/capture dependencies.**
Do not assume public PLY samples match RealityKit input. Record an apparent conversion dependency in M0 rather than budgeting an unrequested pipeline. Capture, streaming, LOD and production tuning belong to v1.1.

### A.3 Engineering benefits

**7. No `if #available` sprawl.**
Availability checks metastasise. They start in the renderer, spread to the view models, then to the asset pipeline (two texture sets), then to the tests (two matrices), then to QA (two device pools). Setting the floor at 27 keeps the codebase honest for the entire life of MVP1.

**8. Half the test surface.**
One OS, two supported hardware revisions (M2, M5), one rendering path. M2 alone gates milestones/release; M5 is explicitly untested. A conservative M2 target is not proof of M5 frame timing. QA effort goes into *depth* on the interactions that matter rather than *breadth* across configurations that few users are in.

**9. Reality Composer Pro 3 as the authoring standard.**
Animation graphs, script graphs, the AI-assisted asset generation, PBR Surface 2 with sheen and subsurface scattering — sheen and subsurface are exactly what upholstery and fabric need. If the runtime has to support 26, the authoring has to target the older shader surface, and every fabric in the catalogue looks flatter. The OS floor is therefore also an *asset quality* decision, not just a code decision.

**10. Modern Swift without apology.**
Swift 6 strict concurrency, typed throws, current SwiftUI scene and immersion APIs, and the current RealityKit entity/component surface — all usable without shims. Meaningful for a solo-founder codebase where every compatibility shim is permanent maintenance nobody else will pick up.

**11. Smaller binary, faster launch.**
One shader set, one material library, one code path.

**12. The M0 spike becomes a real decision gate.**
With no fallback, the feasibility spike genuinely gates the project rather than being a curiosity. If physical space lighting doesn't behave as documented, that's information worth having in week one — and the response is to re-open the platform decision, not to quietly ship the degraded path. This is a benefit: it forces the risk forward instead of letting it leak into month four.

### A.4 Commercial and strategic benefits

**13. The addressable-base cost is small and self-correcting.**
visionOS 27 shipped this fall to both M2 and M5 Vision Pro. Vision Pro owners are early adopters on a device with no carrier gatekeeping and an aggressive update prompt; adoption curves on this platform are steep. The users excluded in month one are largely the same users included by month four. Compatibility debt, by contrast, never expires.

**14. The enterprise pitch is "best possible," not "widely compatible."**
A merchandising lead at a furniture brand is not asking what fraction of headsets we support. They're asking whether their sofa looks like their sofa. "We target the newest OS so your product renders with real light and real occlusion" is a stronger sentence than any installed-base number we could offer, and it frames Kfn8 as premium surface rather than mass channel — which is also how the pricing in PRD §16 is justified.

**15. It sharpens the App Store positioning.**
"Requires visionOS 27" reads as current and serious. In a store where much spatial content is warmed-over iPad software, it's a signal.

**16. Enterprise catalogue economics get simpler.**
One target means one asset spec (PRD §11.1), one validation gate, one LOD strategy. Every tenant integration is the same integration. Supporting two shader surfaces would mean two validation gates and a per-asset question of which tier it was authored for — exactly the kind of catalogue inconsistency that makes a library feel cheap.

**17. Faster to revenue.**
Rough estimate: the fallback path would add 25–35 % to MVP1 engineering time and roughly the same to QA. On a solo-founder timeline that's the difference between one shipped product and one nearly-shipped product.

### A.5 What it costs us (stated honestly)

- Users on visionOS 26 who don't or can't update are excluded outright. There is no partial experience for them, and no App Store presence either — the listing simply won't install.
- The M0 spike carries more weight. If a documented feature underdelivers, there's no graceful degradation to fall back on and the schedule absorbs a real decision.
- Any marketing screenshot or demo depends on visionOS 27 behaviour, so the demo rig has to stay current.
- If Apple changes behaviour in a 27.x point release, we have no older path to pin to.

None of these outweigh items 1–17. But they should be re-checked at M0 rather than assumed away.

---

## Part B — Outdoor deferred to v1.1

### B.1 The short version

Vision Pro is a poor outdoor device — sunlight degrades IR tracking and hand detection, glare washes out passthrough, the battery is tethered, and standing on your own driveway in a headset is socially conspicuous. Solving that properly requires a second app (iOS capture companion), a second rendering mode (Full Immersive), a second reconstruction pipeline (splat + mesh), and a second sync path. That's a product, not a feature. Building it alongside MVP1 would put the riskiest, least-demoable work directly in the critical path of the thing that has to be good.

### B.2 Benefits of deferring

**18. MVP1 gets one mode, done well.**
Mixed immersion with live passthrough, end to end. No mode switching, no "which kind of room is this" branching in the UI, no two sets of lighting assumptions.

**19. The hardest technical risk moves out of the launch path.**
Photogrammetry and splat reconstruction quality is the least predictable part of the whole product. Outside MVP1, a disappointing reconstruction is a delayed feature. Inside MVP1, it's a delayed launch.

**20. No second app to build, sign, review and support.**
Kfn8 Capture is a whole iOS target with its own App Store listing, its own review cycle, its own crash reports and its own support burden — for a solo founder, that's a meaningful fraction of a person.

**21. The privacy story at launch is unusually clean.**
MVP1 uploads no scans, room geometry or Designs: all remain device-local, with no accounts/sync/CloudKit. The precise claim is “We never upload your scan.” A future synced Design reveals arrangement through coordinates, so never claim we cannot infer anything about a room. Outdoor capture necessarily uploads, which introduces the first asterisk. Better to establish the trust position first and then extend it carefully.

**22. Indoors is where the money is anyway.**
Living rooms, bedrooms, dining rooms and kitchens are the overwhelming majority of furniture spend and of enterprise catalogue SKUs. Patio furniture is seasonal, lower-priced, and a smaller slice of any retailer's 3D asset inventory. MVP1 addresses the core of the market.

**23. v1.1 gets a better foundation.**
By the time outdoor work starts, the local Design model, placement system and asset pipeline can be proven in production. Sync is itself v1.1 work, not an already-proven MVP1 subsystem. The offsite-room feature becomes a new *source of rooms* plugged into working machinery, rather than a parallel construction effort.

**24. It becomes a real launch beat.**
Shipped separately, "furnish your backyard in January" is a press-worthy, screenshot-worthy update. Bundled into MVP1, it's a bullet point that competes for attention with the core story.

**25. The cost of deferring is two lines of schema.**
`Room.kind` (`live` | `offsite`) and the `freestanding-outdoor` placement affinity, both added in MVP1. That's the entire price of keeping the door open — no dead code, no unused subsystems, no speculative abstraction.

### B.3 What it costs us

- The demo that makes people gasp ("I'm standing in my summer yard in January") isn't available at launch.
- Users who ask for yards get told to wait, and some will assume it doesn't exist.
- Outdoor SKUs can be catalogued but not placed, so enterprise tenants with patio lines see a partial fit in year one.

---

## Part C — Decision record

| # | Decision | Date | Status | Re-open if |
|---|---|---|---|---|
| D1 | visionOS 27 is the minimum supported OS; no fallback path | Sept 2026 | Accepted | Measured physical space lighting, Environment Occlusion or ManipulationComponent failure/quality shortfall survives one short obvious-setup check; splats excluded |
| D2 | Outdoor and offsite spaces deferred to v1.1 | Sept 2026 | Accepted | An enterprise contract makes patio SKUs a signing condition |
| D3 | `Room.kind` and `freestanding-outdoor` affinity land in MVP1 schema anyway | Sept 2026 | Accepted | — |
| D4 | Apple Vision Pro only (M2, M5); no iPad or iPhone editor | Sept 2026 | Accepted | Revisit at v2 |


## Part D — Operational amendments, 2026-09-19

- M0 prerequisite checks found a separate Xcode 27 installation with an unaccepted licence; founder reviews legal terms and configures signing. This is a readiness blocker, not evidence of platform failure.
- Private operator ingestion, public approved generic CDN assets, immutable revision pinning and rights-revocation deltas are MVP1. tenant_id and delivery_mode are schema fields, not permission enforcement by themselves. Unpublished assets remain private; restricted delivery is not implemented.
- Consumer accounts/email-password auth, Design sync/conflict copies, subscriptions/limits/watermark, tenant console, product analytics, daylight scrub, links/web viewer, production splats and portable export/restore are v1.1. No third-party consumer login is planned.
- Local geometry-derived room frames and durable Design edits survive anchor loss, not device loss or app deletion. No portable recovery copy in MVP1. Deletion removes files and records with counted irreversible confirmation.
- Smallest managed DigitalOcean tiers; no autoscaling, replicas, HA or tested DB restore. Billing alert at 125% of estimate. Operational service metrics are not client analytics. M5 and independent accessibility tests remain unverified.
- Launch library budget is decided after M0 and gates representative 20-placement/two-light/15-minute moving-room performance evidence. Four fixture models do not prove launch performance.
- Latest execution instruction waives routine milestone approval stops. Unresolved blocking M0 findings still go to founder with evidence/options/costs; neither outright failure nor quality shortfall authorises a workaround.

- Repository decision amended after Q29: single parent `kfn8` monorepo targeting `main`; no nested repository metadata. All Git operations require explicit approval. Versioned backend-owned contracts remain required across independently deployed components.
