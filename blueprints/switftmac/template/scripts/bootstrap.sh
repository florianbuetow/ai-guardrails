#!/bin/bash
set -euo pipefail

bash scripts/check-host.sh
bash scripts/install-tools.sh
# shellcheck source=environment.sh
source scripts/environment.sh
bash scripts/check-tools.sh
xcodegen generate --spec project.yml
lock_directory=App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
mkdir -p "$lock_directory"
cp config/App/Package.resolved "$lock_directory/Package.resolved"
xcrun swift package --package-path Tools/Guardrails --force-resolved-versions resolve
xcrun swift build --package-path Tools/Guardrails --force-resolved-versions -c release -Xswiftc -warnings-as-errors
xcodebuild -resolvePackageDependencies -project App.xcodeproj -scheme App \
    -clonedSourcePackagesDirPath build/SourcePackages -onlyUsePackageVersionsFromResolvedFile
hooks="$(git rev-parse --git-path hooks)"
mkdir -p "$hooks"
install -m 755 .githooks/pre-commit "$hooks/pre-commit"
if [ ! -e config/performance-baseline.json ]; then
    printf 'Calibrating initial performance baseline on this runner\n'
    bash scripts/tests.sh performance-calibrate
fi
printf '\033[32mEvery tool and application dependency is configured\033[0m\n'
