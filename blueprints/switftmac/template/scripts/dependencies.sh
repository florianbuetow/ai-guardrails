#!/bin/bash
set -euo pipefail

# shellcheck source=environment.sh
source scripts/environment.sh
app_lock=App.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
tool_lock=Tools/Guardrails/Package.resolved
for lock in "$app_lock" "$tool_lock"; do
    if [ ! -s "$lock" ]; then
        printf 'Missing dependency resolution: %s; run just init\n' "$lock" >&2
        exit 1
    fi
done
before="$(shasum -a 256 "$app_lock" "$tool_lock")"
cmp config/App/Package.resolved "$app_lock"
xcodebuild -resolvePackageDependencies -project App.xcodeproj -scheme App \
    -clonedSourcePackagesDirPath build/SourcePackages -onlyUsePackageVersionsFromResolvedFile
xcrun swift package --package-path Tools/Guardrails --force-resolved-versions resolve
after="$(shasum -a 256 "$app_lock" "$tool_lock")"
if [ "$before" != "$after" ]; then
    printf 'Dependency resolution changed during validation\n' >&2
    exit 1
fi
# The scanner exits nonzero on findings or scanner/network failure. Neither is skipped.
osv-scanner scan source --lockfile "$app_lock" --lockfile "$tool_lock" --format json >build/reports/dependencies.json
printf '\033[32mDependency locks and advisories verified\033[0m\n'
