#!/bin/bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
    printf 'Usage: xcode.sh CONFIGURATION ACTION [ARGUMENTS...]\n' >&2
    exit 1
fi
configuration="$1"
shift
case "$configuration" in
    Debug | Test | AddressSanitizer | ThreadSanitizer | Release) ;;
    *)
        printf 'Unknown build configuration: %s\n' "$configuration" >&2
        exit 1
        ;;
esac

bash scripts/check-tools.sh
# shellcheck source=environment.sh
source scripts/environment.sh
xcodegen generate --spec project.yml
lock_directory=App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
mkdir -p "$lock_directory"
cp config/App/Package.resolved "$lock_directory/Package.resolved"
exec xcodebuild -project App.xcodeproj -scheme App -configuration "$configuration" \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData \
    -clonedSourcePackagesDirPath build/SourcePackages \
    -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile "$@"
