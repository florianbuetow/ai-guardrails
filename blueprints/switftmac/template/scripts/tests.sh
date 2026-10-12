#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    printf 'Usage: tests.sh unit|ui|accessibility|snapshots|coverage|address|thread|performance|performance-calibrate\n' >&2
    exit 1
fi
kind="$1"
case "$kind" in
    unit) arguments=(-only-testing:AppTests) ;;
    ui) arguments=(-only-testing:AppUITests) ;;
    accessibility) arguments=(-only-testing:AppUITests/AccessibilityTests) ;;
    snapshots) arguments=(-only-testing:AppTests/SnapshotTests) ;;
    coverage) arguments=(-only-testing:AppTests -only-testing:AppUITests -enableCodeCoverage YES) ;;
    address) arguments=(-only-testing:AppTests -enableAddressSanitizer YES -enableThreadSanitizer NO) ;;
    thread) arguments=(-only-testing:AppTests -enableThreadSanitizer YES -enableAddressSanitizer NO) ;;
    performance | performance-calibrate) arguments=(-only-testing:PerformanceTests -enableCodeCoverage NO -enableAddressSanitizer NO -enableThreadSanitizer NO) ;;
    *)
        printf 'Unknown test suite: %s\n' "$kind" >&2
        exit 1
        ;;
esac
mkdir -p build/results
result="$(mktemp -d "$PWD/build/results/$kind.XXXXXXXX")"
log="$result/xcodebuild.log"
bash scripts/xcode.sh Debug test "${arguments[@]}" -resultBundlePath "$result/tests.xcresult" 2>&1 | tee "$log"
xcrun xcresulttool get test-results summary --path "$result/tests.xcresult" >"$result/summary.json"
xcrun swift scripts/verify.swift tests "$result/summary.json"
if grep -Eq 'Main Thread Checker:|WARNING: ThreadSanitizer|ERROR: AddressSanitizer' "$log"; then
    printf 'Runtime diagnostic reported; inspect %s\n' "$log" >&2
    exit 1
fi
if [ "$kind" = coverage ]; then
    xcrun xccov view --report --json "$result/tests.xcresult" >"$result/coverage.json"
    xcrun swift scripts/verify.swift coverage "$result/coverage.json"
fi
case "$kind" in
    performance | performance-calibrate)
        xcrun xcresulttool get test-results metrics --schema-version 0.1.0 \
            --path "$result/tests.xcresult" --compact >"$result/metrics.json"
        if [ "$kind" = performance-calibrate ]; then
            xcrun swift scripts/performance.swift calibrate "$result/metrics.json" config/performance-baseline.json
        else
            xcrun swift scripts/performance.swift verify "$result/metrics.json" config/performance-baseline.json
        fi
        ;;
esac
printf '\033[32m%s tests passed; evidence: %s\033[0m\n' "$kind" "$result"
