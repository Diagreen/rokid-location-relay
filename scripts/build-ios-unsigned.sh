#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This build requires macOS/Xcode. Use the supplied GitHub Actions workflow.' >&2
  exit 1
fi
command -v xcodegen >/dev/null
command -v python3 >/dev/null
(cd ios && xcodegen generate)
xcodebuild \
  -project ios/RokidLocation.xcodeproj \
  -scheme RokidLocation \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios-unsigned \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
  build
APP="$ROOT/build/ios-unsigned/Build/Products/Release-iphoneos/RokidLocation.app"
test -f "$APP/Info.plist"
test -f "$APP/RokidLocation"
# Fresh staging avoids stale provisioning/signature files from previous builds.
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/rokid-ipa.XXXXXX")"
trap 'rm -rf -- "$STAGE"' EXIT
mkdir -p "$STAGE/Payload" "$ROOT/dist"
ditto "$APP" "$STAGE/Payload/RokidLocation.app"
if [[ -e "$STAGE/Payload/RokidLocation.app/embedded.mobileprovision" || -e "$STAGE/Payload/RokidLocation.app/_CodeSignature" ]]; then
  echo 'Unexpected signing material in unsigned build.' >&2
  exit 1
fi
(cd "$STAGE" && ditto -c -k --keepParent Payload "$ROOT/dist/RokidLocation-unsigned.ipa")
python3 scripts/verify_ipa.py dist/RokidLocation-unsigned.ipa
shasum -a 256 dist/RokidLocation-unsigned.ipa > dist/RokidLocation-unsigned.ipa.sha256
{
  xcodebuild -version
  xcodegen --version
  echo "Commit: ${GITHUB_SHA:-local}"
  echo 'Unsigned device IPA. Sign locally with AltStore Classic before installing.'
} > dist/ios-build-info.txt
