# Kfn8 repository instructions

## Read first

Before resuming work, read `SESSION-HANDOFF.md`, then `_Kfn8-frontend-avp/PRD.md` and `_Kfn8-frontend-avp/SALIENT-NOTES.md` fully, followed by `TECHNICAL-PLAN.md`, `ROADMAP.md`, and the current milestone findings under that directory. The handoff records recent decisions that supersede older interview answers or historical prompts. `_Kfn8-frontend-avp/PROMPT.md` is historical; it does not override later decisions.

## Repository and Git authority

This is ONE monorepo rooted at `kfn8`. The intended branch is the parent repository's `main`. Never initialise a nested repository or create a worktree/branch without explicit approval.

The founder explicitly prohibits ALL Git operations without explicit approval, including read-only Git commands, staging, commits, amendments, merges, pushes and branch changes. General permission to implement is not permission to operate Git. Do not inspect or manipulate `.git` through other tools to circumvent this restriction. A previous push issue remains unverified; see the handoff. Do not assume the current branch is main.

## Execution and evidence

The founder authorised continuous implementation without routine milestone approval pauses. Preserve milestone order M0, M1, M2, M3, M4, M6, M7. M0 blocking capability failures still require the founder's product/platform decision; no fallback or workaround. Legal agreements are reviewed/accepted by the founder. Missing physical-device evidence cannot be replaced by unit-test results.

Keep `_Kfn8-frontend-avp/ROADMAP.md` updated alongside work using exactly:

> Status legend: ⬜ not started · 🟡 in progress · ✅ done · ⏸️ blocked/deferred · 🟢 verified on-device

Update Tasks, Story/Epic rollups, summary counts and evidence links together. Only use 🟢 for actual physical-headset verification. Report failures as well as passes. Do not claim complete app functionality from readiness tooling.

## Hard product constraints

- Apple Vision Pro, visionOS 27 minimum, Swift 6 strict concurrency; no older-OS checks, shims or degraded renderer.
- Indoor, live passthrough, Mixed Immersive Space only. No iOS target, capture companion, Full Immersive Space or offsite scaffold in MVP1.
- Anonymous consumer app; device-local Spaces/Rooms/Designs/scans; no accounts, sync, CloudKit, subscriptions, commercial limits, watermark or client analytics.
- Asset contract enforced: metres, base-centre pivot, +Y up, front −Z, PBR metallic-roughness, approved dimension authority, ±1% across representations. Never generate/approximate a named purchasable SKU.
- Showroom palette: bone/paper, walnut/clay, brass, ink; no purple/indigo/cyan UI. Fraunces display and Hanken Grotesk UI.
- Private operator ingestion without queue/worker/tenant frontend; anonymous catalogue, immutable approved public assets from Spaces CDN; no FastAPI byte proxy.
- Accessibility inline, including a non-gesture path for every spatial-gesture-only action. No silent stubs or swallowed errors.

Legacy iOS code, old assets, screenshots and user specification images are preserved. Their existence does not make them MVP1 requirements or approved launch assets.
