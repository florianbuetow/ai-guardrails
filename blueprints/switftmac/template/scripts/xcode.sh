#!/bin/bash
set -euo pipefail

bash scripts/check-tools.sh
# shellcheck source=environment.sh
source scripts/environment.sh
xcodegen generate --spec project.yml
lock_directory=App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
mkdir -p "$lock_directory"
cp config/App/Package.resolved "$lock_directory/Package.resolved"
exec xcodebuild -project App.xcodeproj -scheme App -configuration Debug \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData \
    -clonedSourcePackagesDirPath build/SourcePackages \
    -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile "$@"
