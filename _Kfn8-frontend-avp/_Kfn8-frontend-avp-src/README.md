# Kfn8 client source (visionOS 27, Swift 6)

`project.yml` is the source of truth; `Kfn8.xcodeproj` is generated and ignored. Nonshipping M0 probe target only for now.

## Layout

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

The generator uses only the Showroom palette (bone/paper, walnut/clay, brass, ink). visionOS adds the circular mask, depth and specular itself; the preview sheet is a flat approximation. When the shipping app target exists it should reference the same catalog.

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

## Founder device protocol (M2 Vision Pro, visionOS 27)

Simulator results are never device evidence; the evidence file records `isSimulator` and the gate logic ignores simulator records.

1. Open `Kfn8.xcodeproj` in Xcode 27, select the paired Apple Vision Pro, run the `Kfn8M0Probe` scheme. Note the build number shown in the Environment section.
2. Accept the world-sensing prompt. Wait until the Environment section shows planes and mesh anchors for the room.
3. Open the immersive space. Fixtures appear about 1.2 m in front of you: walnut floor block with brass lamp, brass wall block at 1.4 m, brass ceiling block at 2.0 m, clay tabletop block at 0.75 m, and a clay occlusion cube to the left.
4. **Lighting (blocking).** Drag the floor lamp next to a real wall. Turn the lamp on and off with the button, with SurroundingsLight enabled, then disabled. Try point and spot. Take system screenshots (top button plus crown) in each state. Type what you saw on the wall and floor, pick an outcome, press Record.
5. **Occlusion (blocking).** Drag the clay cube behind a real sofa or table. Walk and turn while looking at the boundary. Toggle blending mode to compare. Record edge quality and moving artifacts, pick an outcome, press Record.
6. **Manipulation (blocking).** For each fixture: drag with indirect pinch and with a direct grab. Release on its proper surface (floor, wall, ceiling, table) and somewhere invalid (inside a real object, or off its surface). Observe: does it stay where released (`.stay`), does it turn translucent when invalid, does anything jump farther than 25 cm, and can you continue moving it without pinching again? Use the 5 cm buttons and Cancel as the non-gesture path. Record your observations; the transcript counters are appended automatically.
7. **Export (nonblocking).** Grant consent, present the picker, choose the app content, wait for the first frame. Share the PNG to yourself and open it. Does it show your real room plus the fixtures, only the fixtures, or nothing? Record.
8. Share `M0-EVIDENCE.json` from the Evidence section and return it with the screenshots.

Accessibility checks to fold in: VoiceOver reaches every button in the window; Dynamic Type at the largest size does not clip labels; with Reduce Motion enabled nothing in the probe animates differently (the probe has no animations).
