# M7 release checklist (E7)

Each line needs evidence (file, trace, screenshot or command output) before it is ticked. Simulator runs do not count for device items.

## Founder decisions and external dependencies

- [ ] Consumer release name chosen (E7.S1.T1). Bundle ID today: `com.appliaison.kfn8.visionos`; team OffsideAI Inc. (9L38FSU6M7).
- [ ] Launch-library budget and acquisition decision (E4.S1.T1); ~200 conformed assets published through `kfn8-ingest`.
- [ ] Provenance and visual/dimension approvals recorded for every published revision (`kfn8-ingest approve`).
- [ ] Backend provisioned per `_Kfn8-backend-fastapi/ops/OPERATIONS.md`; billing alert at 125 % confirmed.
- [ ] `Kfn8APIBaseURL` set in `project.yml` to the deployed API.
- [ ] Still export re-scope decision if the M0 export probe did not show real room pixels (E3.S3.T1).

## Build and CI

- [ ] `_Kfn8-frontend-avp/tools/ci.sh --with-ui` passes on the release commit.
- [ ] Font licences (OFL) bundled; asset licence ledger complete for every shipped model.
- [ ] Privacy manifest and App Store privacy answers match `LIMITATIONS-AND-PRIVACY.md` (no data collected; no tracking).
- [ ] Signed archive: `xcodebuild archive -scheme Kfn8 -destination 'generic/platform=visionOS' -archivePath build/Kfn8.xcarchive`.

## Device evidence on the M2 (founder-run)

- [ ] M0 occlusion and manipulation outcomes recorded (lighting already recorded passed).
- [ ] Full E2E on device: scan, four affinities, manipulation, save/relaunch, lost alignment and both recovery paths, duplicate, A/B, inventory, export if supported, delete, download, revocation.
- [ ] Accessibility checks in the same demo: VoiceOver reaches every control, Dynamic Type largest without clipping, Reduce Motion.
- [ ] M4 performance trace: 20 representative placements, two virtual lights, 15 minutes moving; p50/p95/p99/max, zero dropped frames at 90 Hz, peak memory (`Documents/perf-*.json`).

## Distribution

- [ ] TestFlight build uploaded; founder feedback collected (no population analytics claims).
- [ ] Blocking TestFlight findings fixed; submission made; actual review outcome recorded. Submission is not approval.
