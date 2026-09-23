# Kfn8 asset contract v1

Owned by the backend. Every published asset revision, and every asset bundled in the client, satisfies this contract. The validator (`kfn8-validate`) enforces it; CI runs the same validator on bundled and remote manifests. No certification or Khronos-conformance claim is made.

## Geometry

- Units: metres. USDZ stages declare `metersPerUnit = 1`; glTF is metres by specification.
- Up axis: +Y. USDZ stages declare `upAxis = "Y"`.
- Front: −Z, declared as `front_axis: "-Z"` in the manifest and confirmed by the visual/dimension approval.
- Pivot: base-centre. World-space bounds satisfy `min.y ≈ 0` and `centre.x ≈ centre.z ≈ 0` (tolerance: 0.5 % of the axis extent, minimum 2 mm).
- Mount points for wall/ceiling items are metadata (`attachment.mount_point_m`), never a moved pivot.

## Dimensions

- The declared `dimension_spec` (width = X, height = Y, depth = Z) has an authority (retailer or operator), source, approver, approval time and evidence hash.
- World-space bounds of **every** rendition (GLB master, each LOD, each USDZ) are within ±1 % of the spec per axis.
- Renditions are also compared with each other: any pair differing by more than 1 % on an axis fails, which catches opposite-direction drift.

## Materials and budgets

- PBR metallic-roughness only (glTF `pbrMetallicRoughness`, no spec-gloss extension; USD `UsdPreviewSurface`).
- Maximum texture edge: 2048 px at LOD0, 1024 px at LOD1–2.
- Triangle budgets: LOD0 ≤ 150 000, LOD1 ≤ 50 000, LOD2 ≤ 15 000.

## Provenance and approval

- Every revision has a licence ledger entry (source URL, author, licence id, attribution, evidence reference and SHA-256) even for CC0.
- Publication requires two approvals bound to the exact revision: `provenance` and `visual_dimensions`, each with actor, time and evidence hash. A checkbox is not an approval.
- Content hashes identify bytes; they are not access control.

## Files

- Every rendition declares `sha256` and `size_bytes`; the validator recomputes both.
- Revisions are immutable: changed geometry, materials, dimensions or source create a new revision.
