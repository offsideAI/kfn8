#!/bin/zsh
# Kfn8 client setup: regenerate Kfn8.xcodeproj from project.yml with xcodegen, then open it in Xcode 27
# after asking first. Never runs the app, never touches Git, never changes global xcode-select.
#
# Usage: ./setup.sh            interactive (prompts before opening Xcode)
#        ./setup.sh --no-open  generate only
#        ./setup.sh --yes      generate and open without prompting

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

REQUIRED_XCODE_MAJOR=27
XCODE_27_APP_DEFAULT="/Users/coder/Developer/Xcode/Xcode_27_0_0/Xcode_27_0_0.app"

OPEN_MODE="prompt"
for arg in "$@"; do
  case "$arg" in
    --no-open) OPEN_MODE="never" ;;
    --yes|-y) OPEN_MODE="always" ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '\n==> %s\n' "$1"; }
fail() { printf '\nERROR: %s\n' "$1" >&2; exit 1; }

# 1. Locate an Xcode 27 installation without changing the global selection.
find_xcode_app() {
  local candidate
  if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    candidate="${DEVELOPER_DIR%/Contents/Developer}"
    [[ -d "$candidate" ]] && { echo "$candidate"; return; }
  fi
  candidate="$(xcode-select -p 2>/dev/null || true)"
  candidate="${candidate%/Contents/Developer}"
  [[ -d "$candidate" ]] && { echo "$candidate"; return; }
  [[ -d "$XCODE_27_APP_DEFAULT" ]] && { echo "$XCODE_27_APP_DEFAULT"; return; }
  echo ""
}

XCODE_APP="$(find_xcode_app)"
[[ -n "$XCODE_APP" ]] || fail "No Xcode found. Install Xcode $REQUIRED_XCODE_MAJOR or set DEVELOPER_DIR."
export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"

# Capture full output first: with pipefail, `| head`/`| grep -q` would end the script with SIGPIPE (exit 141).
XCODE_VERSION_OUTPUT="$(xcodebuild -version 2>/dev/null || true)"
XCODE_VERSION="$(printf '%s\n' "$XCODE_VERSION_OUTPUT" | sed -n '1s/^Xcode //p')"
XCODE_MAJOR="${XCODE_VERSION%%.*}"
[[ "$XCODE_MAJOR" =~ ^[0-9]+$ ]] || fail "Could not read the Xcode version from $XCODE_APP (licence not accepted?). Run: sudo xcodebuild -license"
(( XCODE_MAJOR >= REQUIRED_XCODE_MAJOR )) || fail "Xcode $XCODE_VERSION found at $XCODE_APP; Kfn8 requires Xcode $REQUIRED_XCODE_MAJOR or later (visionOS 27 SDK)."
say "Using Xcode $XCODE_VERSION at $XCODE_APP"

SDK_LIST="$(xcodebuild -showsdks 2>/dev/null || true)"
if [[ "$SDK_LIST" != *"-sdk xros${REQUIRED_XCODE_MAJOR}"* ]]; then
  fail "The visionOS ${REQUIRED_XCODE_MAJOR} device SDK is not listed by xcodebuild -showsdks. Install the visionOS platform in Xcode → Settings → Components."
fi

# 2. xcodegen must exist; offer the Homebrew install command rather than running it silently.
if ! command -v xcodegen >/dev/null 2>&1; then
  fail "xcodegen is not installed. Install it with:  brew install xcodegen   then re-run this script."
fi
say "xcodegen $(xcodegen --version | awk '{print $2}')"

# 3. Generate the project. Kfn8.xcodeproj is disposable and ignored by Git.
say "Generating Kfn8.xcodeproj from project.yml"
xcodegen generate --spec project.yml --quiet
[[ -d Kfn8.xcodeproj ]] || fail "xcodegen did not produce Kfn8.xcodeproj"
echo "Generated $(pwd)/Kfn8.xcodeproj"

# 4. Ask before opening Xcode.
case "$OPEN_MODE" in
  never) say "Skipping Xcode (--no-open). Open it later with: open -a \"$XCODE_APP\" Kfn8.xcodeproj"; exit 0 ;;
  always) ;;
  prompt)
    printf '\nOpen Kfn8.xcodeproj in Xcode %s now? [y/N] ' "$XCODE_VERSION"
    read -r answer
    case "$answer" in
      y|Y|yes|YES) ;;
      *) echo "Not opening Xcode. Open it later with: open -a \"$XCODE_APP\" Kfn8.xcodeproj"; exit 0 ;;
    esac
    ;;
esac

say "Opening in Xcode"
open -a "$XCODE_APP" "$SCRIPT_DIR/Kfn8.xcodeproj"
echo "Select the Kfn8M0Probe scheme and your Apple Vision Pro (or the visionOS 27 simulator) as the run destination."
