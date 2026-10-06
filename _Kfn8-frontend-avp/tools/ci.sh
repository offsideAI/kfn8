#!/bin/zsh
# Kfn8 monorepo checks. Short-lived only: no servers are started (tests use a throwaway Postgres cluster and in-process
# ASGI clients). Usage: _Kfn8-frontend-avp/tools/ci.sh [--with-ui]   (UI tests need the visionOS 27 simulator)
set -u
ROOT="${0:A:h:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app/Contents/Developer}"
BACKEND="$ROOT/_Kfn8-backend-fastapi"; CLIENT="$ROOT/_Kfn8-frontend-avp-src"
failures=()
step() { local name=$1; shift; printf '\n==> %s\n' "$name"; if "$@"; then echo "PASS $name"; else echo "FAIL $name"; failures+=$name; fi }

step "readiness tool tests" python3 -m unittest discover -s "$ROOT/tests" -q
step "backend tests (real Postgres)" "$BACKEND/venv/bin/python" -m pytest -q "$BACKEND/tests"
step "OpenAPI contract pinned" "$BACKEND/venv/bin/python" "$BACKEND/tools/export_openapi.py" --check
step "Swift transport models regenerated" "$BACKEND/venv/bin/python" "$BACKEND/tools/generate_swift_client.py" --check
step "asset manifests (contract v1)" "$BACKEND/venv/bin/kfn8-validate" "$BACKEND"/assets-conformed/*/manifest.json
step "client bundle == manifests" "$BACKEND/venv/bin/kfn8-validate" --bundle "$CLIENT"/Kfn8/Resources/Catalogue/*/
step "Kfn8Kit Swift tests" zsh -c "cd '$CLIENT/Packages/Kfn8Kit' && xcrun swift test -q"
step "M0 probe core tests" zsh -c "cd '$CLIENT/Packages/Kfn8M0ProbeCore' && xcrun swift test -q"
step "project generation" zsh -c "cd '$CLIENT' && ./setup.sh --no-open >/dev/null"
step "app build (device SDK, unsigned)" xcodebuild -quiet -project "$CLIENT/Kfn8.xcodeproj" -scheme Kfn8 -destination 'generic/platform=visionOS' CODE_SIGNING_ALLOWED=NO build
step "app build (simulator SDK)" xcodebuild -quiet -project "$CLIENT/Kfn8.xcodeproj" -scheme Kfn8 -destination 'generic/platform=visionOS Simulator' CODE_SIGNING_ALLOWED=NO build
if [[ "${1:-}" == "--with-ui" ]]; then
  step "end-to-end UI tests (visionOS 27 simulator)" xcodebuild -quiet -project "$CLIENT/Kfn8.xcodeproj" -scheme Kfn8 \
    -destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=27.0' CODE_SIGNING_ALLOWED=NO test -only-testing:Kfn8UITests
fi
printf '\n'
if (( ${#failures} )); then echo "CI FAILED: ${failures[*]}"; exit 1; fi
echo "CI PASSED (simulator and host checks only; not device evidence)"
