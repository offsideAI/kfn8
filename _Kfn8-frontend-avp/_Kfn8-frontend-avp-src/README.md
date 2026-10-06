# Kfn8 client source (visionOS 27, Swift 6)

`project.yml` is the source of truth; `Kfn8.xcodeproj` is generated and ignored.

| Scheme | Target(s) | Platform |
|---|---|---|
| `Kfn8` | `Kfn8`, `Kfn8UITests` | visionOS 27 (MVP1, Apple Vision Pro) |
| `Kfn8M0Probe` | `Kfn8M0Probe` | visionOS 27, nonshipping M0 probe |

## Layout

- `Packages/Kfn8Kit/`: Domain, Persistence and Catalogue libraries (no RealityKit/ARKit), tested on the macOS host. The iPhone/iPad app is a separate codebase in `../_Kfn8-frontend-ios-src` with its own copy (decision D8, [ROADMAP-IOS.md](../ROADMAP-IOS.md)).
- `Kfn8/Shared/`: platform-neutral app code: `AppModel` and launch, catalogue loaders, Showroom theme, the main window and its Design/Inventory/Catalogue panels, and the RealityKit placement scene, room-capture rules and labelled simulated room.
- `Kfn8/visionOS/`: visionOS only: app entry, Mixed Immersive Space, visionOS ARKit providers, ManipulationComponent input, in-room turn buttons, preview volume.
- `Kfn8/Resources/`: bundled approved catalogue and fonts, shared.
- `UITestSupport/`: helpers for `Kfn8UITests`.
- `Packages/Kfn8M0ProbeCore/`: pure probe control state (attachment policy, release resolver, manipulation lifecycle, lighting/occlusion/export state, frame-time statistics, evidence log). Swift Testing, runs on the macOS host.
- `Kfn8M0Probe/`: the nonshipping Mixed Immersive Space probe app. Window with all controls (non-gesture path for every action), immersive space with fixtures for the four affinities, a lamp, and an occlusion object.

## Quick start

```sh
cd _Kfn8-frontend-avp/_Kfn8-frontend-avp-src
./setup.sh              # checks Xcode 27 + visionOS 27 SDK + xcodegen, regenerates Kfn8.xcodeproj, asks before opening Xcode
./setup.sh --no-open    # generate only
./setup.sh --yes        # generate and open without the prompt
```

The script never runs the app, never runs Git and never changes the global `xcode-select`. If xcodegen is missing it prints the `brew install xcodegen` command instead of installing anything.

## App icon

`Kfn8M0Probe/Assets.xcassets/AppIcon.solidimagestack` is the visionOS three-layer icon (Back: paper gradient and clay floor wash; Middle: walnut armchair; Front: brass pendant with a light pool). It is generated, not hand-drawn, so it can be regenerated or restyled reproducibly:

```sh
python3 ../tools/make_app_icon.py --preview /tmp/icon-preview.png   # needs Pillow
```

The generator uses only the Showroom palette (bone/paper, walnut/clay, brass, ink). visionOS adds the circular mask, depth and specular itself; the preview sheet is a flat approximation. The `Kfn8` app target references the same catalog. Pass `--ios-catalog <path>/Assets.xcassets` to also write the three layers flattened into one opaque 1024 px iPhone/iPad icon.

## Commands (Xcode 27 toolchain, explicit DEVELOPER_DIR)

```sh
export DEVELOPER_DIR=/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer
cd _Kfn8-frontend-avp/_Kfn8-frontend-avp-src

# Pure package tests on the host
(cd Packages/Kfn8M0ProbeCore && xcrun swift test)

# Regenerate the project after editing project.yml
xcodegen generate

# Compile checks (no signing)
xcodebuild -project Kfn8.xcodeproj -scheme Kfn8M0Probe -destination 'generic/platform=visionOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Kfn8.xcodeproj -scheme Kfn8M0Probe -destination 'generic/platform=visionOS Simulator' CODE_SIGNING_ALLOWED=NO build

# Package tests through the scheme on the visionOS 27 simulator
xcodebuild -project Kfn8.xcodeproj -scheme Kfn8M0Probe -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=27.0' CODE_SIGNING_ALLOWED=NO test
```

## Simulator smoke run (not device evidence)

```sh
S=/path/to/scratch
xcodebuild -project Kfn8.xcodeproj -scheme Kfn8M0Probe -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=27.0' CODE_SIGNING_ALLOWED=NO -derivedDataPath $S/DerivedData build
UDID=$(xcrun simctl list devices available | grep -A1 "visionOS 27" | grep -o -E "[0-9A-F-]{36}" | head -1)
xcrun simctl boot $UDID; xcrun simctl install $UDID $S/DerivedData/Build/Products/Debug-xrsimulator/Kfn8M0Probe.app
xcrun simctl launch $UDID com.appliaison.kfn8.m0probe --open-immersive --lamp-on            # optional: --occlusion-default
xcrun simctl io $UDID screenshot $S/shot.png
```

Launch arguments are the only automation hook: `--open-immersive`, `--lamp-on`, `--occlusion-default`. Without them the app behaves exactly as on device. ARKit plane detection and scene reconstruction report "unsupported" on the simulator, and ScreenCaptureKit is absent from the simulator SDK, so attachment, collision and export can only be judged on the headset.

## Remote-driven runs (agent drives, founder wears)

The probe polls `Documents/commands.json` in its container twice a second and executes each command file once, writing `Documents/status.json` after every poll. `../tools/probe_remote.py` writes commands with `devicectl copy to`, pulls status, and can capture the Mac screen, which shows the headset view when the founder turns on **Mirror My View** (Control Center → Mirror My View → this Mac).

```sh
python3 ../tools/probe_remote.py status
python3 ../tools/probe_remote.py run '[{"op":"openSpace"}]' --wait 4
python3 ../tools/probe_remote.py run '[{"op":"lamp","on":true,"type":"point","intensity":40000,"surroundings":true}]' --capture on.png
python3 ../tools/probe_remote.py run '[{"op":"occlusion","mode":"occluded"},{"op":"move","fixture":"cube","to":[0.2,0.3,-2.5]}]' --capture occ.png
python3 ../tools/probe_remote.py run '[{"op":"record","probe":"lighting","outcome":"passed","observed":"agent: wall brightened in mirrored view"}]'
python3 ../tools/probe_remote.py evidence ./M0-EVIDENCE.json
```

Ops: `openSpace`, `closeSpace`, `lamp` (on/type/intensity/radius/surroundings), `occlusion` (mode occluded|default), `move` (fixture floor|wall|ceiling|tabletop|cube, to [x,y,z] in metres, immersive-space origin at the floor under the user), `nudge` (fixture, by [dx,dy,dz]), `cancel` (fixture), `record` (probe, outcome, observed; tagged `recordedBy: agent-mirrored-view`), `note`, `resetFrames`, `status`. Hand manipulation events cannot be scripted; the ManipulationComponent probe still needs real pinches and grabs.

Limits found on device: `devicectl device capture screenshot` is refused by Vision Pro, and `devicectl device process launch` hangs while the headset is not being worn. The founder opens the app from the Home View and keeps the headset on; everything else can be driven from the Mac.

## Founder device protocol (M2 Vision Pro, visionOS 27)

Simulator results are never device evidence; the evidence file records `isSimulator` and the gate logic ignores simulator records.

**No typing.** Each probe section has observation chips (tap the ones that are true) and three buttons: Record passed, Record failed, Record inconclusive. One tap writes the record with the selected chips plus the app's automatic context (intensity, components, surfaces, transcripts, frame times). Free-form remarks go to the agent in chat and are written into the findings as founder-reported. The evidence file is written automatically on launch, after every drag, on every lamp toggle and on immersive close; the agent pulls it with:

```sh
xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer \
  --domain-identifier com.appliaison.kfn8.m0probe --source Documents/M0-EVIDENCE.json --destination ./M0-EVIDENCE.json
```

1. Room lights on. Open "Kfn8 M0 Probe". Environment section: OS 27.0, Simulator no.
2. Tap "Open immersive space", allow world sensing, look around for 20 seconds until Surfaces shows planes and mesh anchors and "Scene understanding" says running.
3. **Lighting.** Drag the lamp (walnut block) near a real wall. Tap "Turn lamp on" and off a few times; raise Intensity if faint. Tap the chips that are true, then one Record button. Screenshot with the lamp on and off (top button + Digital Crown).
4. **Occlusion.** Drag the clay cube behind a sofa or table. Look at the edge while still, then while walking and turning. Tap "Toggle blending mode" to compare. Chips, then Record.
5. **Manipulation.** For each of the four fixtures: indirect pinch drag, direct grab, release on its proper surface, release somewhere invalid (inside furniture or off its surface), try to keep moving it without re-pinching, tap Cancel, tap a 5 cm button. Chips, then Record.
6. **Export.** Consent, present picker, pick this app, wait for "captured", share the PNG to the Mac, open it. No chips; the agent records the result from the file and your description.
7. Tap "Close immersive space". Tell the agent you are done; the file is pulled from the headset.

Accessibility checks to fold in: VoiceOver reaches every button and chip; Dynamic Type at the largest size does not clip; Reduce Motion changes nothing (the probe has no animations).
