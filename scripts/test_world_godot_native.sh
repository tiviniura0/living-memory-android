#!/usr/bin/env bash
set -euo pipefail
evidence="$PWD/evidence/godot-task1"
trap 'adb logcat -d -t 2000 > "$evidence/logcat.txt"; adb shell screencap -p /sdcard/godot.png; adb pull /sdcard/godot.png "$evidence/screen.png"' EXIT
adb shell getprop ro.product.cpu.abi > "$evidence/emulator-abi.txt"
cd apps/world_observer/android
failed=0
# Each instrumentation starts a fresh target process. No data deletion or native
# engine reset is used to hide a re-open failure INSIDE reopenTwentyTimes.
for method in realGodotReadyHasEngineVersion secondOwnerIsRejectedWithoutKillingFirst reopenTwentyTimes resizeAndRotateKeepsHostAlive realChannelReadyAndProbe; do
  report="$evidence/native/$method"
  mkdir -p "$report"
  ./gradlew :app:connectedDebugAndroidTest -PgodotTestAbi=x86_64 "-Pandroid.testInstrumentationRunnerArguments.class=com.tivini.livingworld.godot.GodotHostTest#$method" 2>&1 | tee "$report/gradle.log" || failed=1
  cp -a ../build/app/outputs/androidTest-results "$report/" 2>/dev/null || true
  cp -a ../build/app/reports/androidTests "$report/" 2>/dev/null || true
  adb logcat -d -t 500 > "$report/logcat.txt"
done
exit "$failed"
