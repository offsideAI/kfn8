# M0 findings — readiness only, milestone incomplete

Date: 2026-09-19. Status: **BLOCKED on Xcode 27 licence acceptance; no device gates executed.**

## Implemented

- Created TECHNICAL-PLAN.md and ROADMAP.md from interview Q1–Q55; updated PRD v0.3 and SALIENT-NOTES. Seven Epics map exactly to M0, M1, M2, M3, M4, M6, M7. Routine approval stops removed; actual feasibility/dependency gates preserved.
- Implemented read-only `tools/check_m0_readiness.py`, explicit DEVELOPER_DIR, JSON command evidence and nonzero exit on missing/incorrect toolchain, licence errors and timeouts. Never accepts legal terms, changes xcode-select, or calls tooling readiness a device pass.
- Eight tests first failed because implementation was absent, then all eight passed. Tests cover wrong SDK, simulator-only SDK, old Swift, licence refusal, missing executable, timeout, explicit CLI argument and successful toolchain with device still unverified.

## Real environment evidence

Global selected developer path: `/Users/coder/Developer/Xcode/Xcode_26_5_0/Xcode_26_5_0.app/Contents/Developer`. Its SDK listing contains xros26.5 and xrsimulator26.5. No 26 fallback was built.

Separate installation: `/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer`.

- `xcodebuild -version`: exit 0, Xcode 27.0, build 27A266a.
- `xcodebuild -showsdks` under that DEVELOPER_DIR: exit 69, “You have not agreed to the Xcode license agreements.”
- Real readiness CLI: exit 1, `status=blocked`, `m0_passed=false`.
- Full raw output is in [M0-READINESS.json](M0-READINESS.json). Sandbox filesystem/cache warnings are retained alongside the specific licence failure rather than hidden.

This is environment readiness, not a platform-quality failure and not grounds for changing D1. The founder must review/accept the agreement. No licence acceptance, downloads, model preparation, paid provisioning or device evidence was fabricated.

## Actual feature measurements

| Probe | Result | Measurement |
|---|---|---|
| Physical space lighting | Not run | None |
| Environment Occlusion | Not run | None |
| ManipulationComponent / invalid-release continuation | Not run | None |
| Passthrough export file | Not run | None |
| One-attempt splat | Not attempted | None; budget not consumed |
| 20-placement / 2-light / 15-minute M2 performance | Not run; M4 dependency | None |

No frame rate, memory, lighting, occlusion or visual-quality pass is claimed. No M1 or later implementation has started.

## Reproduce / unblock

1. Open `/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app` and review/accept its licence yourself; complete prompted first-launch setup. Do not switch to 26 as a workaround.
2. From the client repository run:

```sh
python3 -m unittest discover -s tests -v
python3 tools/check_m0_readiness.py --developer-dir /Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer
```

3. Expected after setup: exit 0 with `toolchain_ready_device_unverified`. This is not an M0 pass. Next verify signing and M2 pairing, implement exact SDK-backed probes, then run founder-operated on-device demos.
4. Record physical test OS/build, expected/observed behavior, traces and permitted captures. Unresolved failure after the one short obvious-setup check stops dependent implementation; splat/export findings remain separately nonblocking for M0.

## Plan deviations

The previous conversation announced but did not create TECHNICAL-PLAN.md. It was created in this execution before roadmap decomposition. Xcode 27 was present in a separate directory despite 26.5 being selected; the actual blocker is licence acceptance. No SDK downgrade or speculative rendering code was introduced.

## Repository housekeeping amendment

The founder superseded separate repositories with the parent `kfn8` monorepo. Nested client `.git` was removed on explicit instruction. Historical nested commit IDs are no longer resolvable here and do not identify parent revisions. Root ignore rules now cover Swift/Xcode and Python artifacts; source assets and evidence are retained. No Git commands were run during housekeeping. M0 device status is unchanged.
