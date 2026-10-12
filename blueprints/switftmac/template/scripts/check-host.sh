#!/bin/bash
set -euo pipefail

fail() {
    printf '\033[31m%s\033[0m\n' "$1" >&2
    exit 1
}

[ "$(uname -s)" = Darwin ] || fail 'switftmac requires macOS.'
[ "$(uname -m)" = arm64 ] || fail 'Xcode 27 development requires Apple Silicon.'
version="$(sw_vers -productVersion)"
major="${version%%.*}"
remainder="${version#*.}"
minor="${remainder%%.*}"
[ -n "$major" ] && [ -n "$minor" ] || fail 'Cannot determine macOS version.'
if [ "$major" -lt 26 ] || { [ "$major" -eq 26 ] && [ "$minor" -lt 6 ]; }; then
    fail "Xcode 27 requires macOS 26.6 or newer; found $version. The application deployment target remains 26.0."
fi
command -v xcodebuild >/dev/null || fail 'Full Xcode 27 is required, not only Command Line Tools.'
xcode_version="$(xcodebuild -version)"
[ "$xcode_version" = $'Xcode 27.0\nBuild version 27A266a' ] || fail "Expected Xcode 27.0 (27A266a); found: $xcode_version"
swift_version="$(xcrun swiftc --version)"
case "$swift_version" in
    *'Swift version 6.4'*) ;;
    *) fail "Expected the bundled Swift 6.4 compiler; found: $swift_version" ;;
esac
for tool in swiftc swift-format xccov xcresulttool llvm-cov llvm-profdata docc lldb xctrace notarytool stapler; do
    xcrun --find "$tool" >/dev/null
done
for tool in git just curl tar unzip shasum plutil codesign open leaks vmmap; do
    command -v "$tool" >/dev/null || fail "Missing prerequisite: $tool"
done
printf '\033[32mHost toolchain verified\033[0m\n'
