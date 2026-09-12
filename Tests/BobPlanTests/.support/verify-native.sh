#!/bin/sh
set -eu

planning_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
cd "$planning_root"
planning_build="$planning_root/Tests/BobPlanTests/.build/native"
mkdir -p "$planning_build"

for planning_platform in iphonesimulator iphoneos; do
    case "$planning_platform" in
        iphonesimulator) planning_target=arm64-apple-ios26.0-simulator ;;
        iphoneos) planning_target=arm64-apple-ios26.0 ;;
    esac
    planning_sdk=$(xcrun --sdk "$planning_platform" --show-sdk-path)
    planning_modules="$planning_build/$planning_platform"
    mkdir -p "$planning_modules"
    set -- -swift-version 6 -warnings-as-errors -strict-concurrency=complete \
        -sdk "$planning_sdk" -target "$planning_target" \
        -module-cache-path "$planning_build/ModuleCache"

    xcrun swiftc "$@" -parse-as-library -emit-module -module-name BobCore \
        Sources/BobCore/*.swift -emit-module-path "$planning_modules/BobCore.swiftmodule"
    xcrun swiftc "$@" -parse-as-library -emit-module -module-name BobPlan \
        Sources/BobPlan/*.swift -I "$planning_modules" \
        -emit-module-path "$planning_modules/BobPlan.swiftmodule"
    xcrun swiftc "$@" -typecheck -I "$planning_modules" Bob/Planning/LocalPlanner.swift
    printf '%s\n' "PASS: LocalPlanner + BobPlan, $planning_target, Swift 6 strict concurrency, warnings as errors"
done
