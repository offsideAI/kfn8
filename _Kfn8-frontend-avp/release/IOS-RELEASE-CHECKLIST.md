# Kfn8 for iPhone and iPad: release checklist (I7)

Status: prepared, not started. Each line needs evidence (command output, build number, device) before it is ticked. Submission is not approval.

## Founder decisions before TestFlight

- [ ] **ID-1:** separate App Store app or universal purchase with the Vision Pro app. Final bundle ID (working: `com.appliaison.kfn8.ios`) and App Store Connect record.
- [ ] **Release name:** shared with the Vision Pro release (E7.S1.T1).
- [ ] **ID-2:** performance target, and an M4-equivalent device trace against it.
- [ ] **ID-3:** lighting of real surfaces. Update `IOS-LIMITATIONS-AND-PRIVACY.md` to match what shipped.
- [ ] **ID-4:** physical iPad and camera-only iPhone results, or an explicit decision to ship without them.

## Build

- [ ] `tools/ci-ios.sh --with-ui` passes on the release commit (record the commit ID once a commit is authorised).
- [ ] Release configuration builds without the Debug-only catalogue fixtures (`--catalogue-fixtures` is compiled out).
- [ ] `Kfn8APIBaseURL` set to the deployed catalogue, and the deployed end-to-end run passes (I2.S1.T5).
- [ ] Every bundled and launch-library asset carries the founder's provenance and visual/dimension approvals (`kfn8-validate --require-approvals`).
- [ ] Font (OFL) and model (CC0 or licensed) attributions present where required.
- [ ] Signed archive (team 9L38FSU6M7):

  ```sh
  xcodebuild -project Kfn8iOS.xcodeproj -scheme Kfn8iOS -configuration Release -destination 'generic/platform=iOS' -archivePath ~/kfn8-ios.xcarchive archive
  ```

## Device evidence (🟢 only from these)

- [ ] I0.S2 probe results on the iPhone 13 Pro Max are recorded in `reports/IOS-I0-FINDINGS.md`.
- [ ] I1.S6.T2 demo: scan, four affinities, touch move/twist/turn, held invalid release, relaunch, recovery, delete.
- [ ] I3.S3.T2: an exported photo opened in Photos shows the real room and the furniture.
- [ ] I7.S1.T3: full device end-to-end run, with VoiceOver, the largest text size and Reduce Motion folded in.

## Distribution

- [ ] TestFlight upload: the founder approves the upload and runs the demo.
- [ ] Blocking TestFlight findings fixed and re-verified.
- [ ] App Review submission and the actual outcome recorded (I7.S2.T2).
