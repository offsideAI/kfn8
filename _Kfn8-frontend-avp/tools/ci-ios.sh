#!/bin/zsh
# Kfn8 iPhone/iPad checks (decision D8). Short-lived only: no servers are started.
# Usage: _Kfn8-frontend-avp/tools/ci-ios.sh [--with-ui]   (UI tests need the iPhone 18 Pro and iPad Pro 11-inch (M5) iOS 27 simulators)
# Backend tests stay in tools/ci.sh; this script only checks what the iOS app depends on.
set -u
ROOT="${0:A:h:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer}"
BACKEND="$ROOT/_Kfn8-backend-fastapi"; CLIENT="$ROOT/_Kfn8-frontend-ios-src"
DERIVED="${TMPDIR:-/tmp}/kfn8-ios-ci"
failures=()
step() { local name=$1; shift; printf '\n==> %s\n' "$name"; if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failures+=$name; fi }
# Runs the UI tests on one simulator and fails unless the result bundle reports at least one executed test, all passed.
# Usage: ui_tests <scheme> <UI test target> <simulator name>
ui_tests() {
  local scheme=$1 target=$2 device=$3
  local bundle="$DERIVED/ui-$scheme-${device//[^A-Za-z0-9]/-}.xcresult"
  rm -rf "$bundle"
  xcodebuild -quiet -project "$CLIENT/Kfn8iOS.xcodeproj" -scheme "$scheme" -destination "platform=iOS Simulator,name=$device,OS=27.0" \
    -derivedDataPath "$DERIVED" -resultBundlePath "$bundle" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
    test -only-testing:"$target" || return 1 # one simulator, tests in turn: parallel clones were killed under load
  xcrun xcresulttool get test-results summary --path "$bundle" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(str(d["passedTests"]) + "/" + str(d["totalTestCount"]) + " UI tests passed")
sys.exit(0 if d["result"] == "Passed" and d["totalTestCount"] > 0 and d["failedTests"] == 0 else 1)'
}

step "Swift transport models match the API contract" "$BACKEND/venv/bin/python" "$BACKEND/tools/generate_swift_client.py" --check \
  --out "$CLIENT/Packages/Kfn8Kit/Sources/Kfn8Catalogue/Generated/CatalogueAPI.swift"
step "bundled catalogue == backend manifests" "$BACKEND/venv/bin/kfn8-validate" --bundle "$CLIENT"/Kfn8iOS/Resources/Catalogue/*/
step "Kfn8Kit Swift tests (host)" zsh -c "cd '$CLIENT/Packages/Kfn8Kit' && xcrun swift test -q"
step "probe core Swift tests (host)" zsh -c "cd '$CLIENT/Packages/Kfn8iOSProbeCore' && xcrun swift test -q"
step "project generation" zsh -c "cd '$CLIENT' && ./setup.sh --no-open >/dev/null"
step "app build (iOS device SDK, unsigned)" xcodebuild -quiet -project "$CLIENT/Kfn8iOS.xcodeproj" -scheme Kfn8iOS \
  -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build
step "app build (iOS simulator SDK)" xcodebuild -quiet -project "$CLIENT/Kfn8iOS.xcodeproj" -scheme Kfn8iOS \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build
step "probe build (iOS device SDK, unsigned)" xcodebuild -quiet -project "$CLIENT/Kfn8iOS.xcodeproj" -scheme Kfn8iOSProbe \
  -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build
step "probe build (iOS simulator SDK)" xcodebuild -quiet -project "$CLIENT/Kfn8iOS.xcodeproj" -scheme Kfn8iOSProbe \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build
if [[ "${1:-}" == "--with-ui" ]]; then
  step "UI tests (iPhone 18 Pro, iOS 27 simulator)" ui_tests Kfn8iOS Kfn8iOSUITests "iPhone 18 Pro"
  step "UI tests (iPad Pro 11-inch (M5), iOS 27 simulator)" ui_tests Kfn8iOS Kfn8iOSUITests "iPad Pro 11-inch (M5)"
  step "probe smoke test (iPhone 18 Pro, iOS 27 simulator)" ui_tests Kfn8iOSProbe Kfn8iOSProbeUITests "iPhone 18 Pro"
fi
printf '\n'
if (( ${#failures} )); then echo "iOS CI FAILED: ${failures[*]}"; exit 1; fi
echo "iOS CI PASSED (simulator and host checks only; not device evidence)"
