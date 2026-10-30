#!/usr/bin/env bash
set -euo pipefail
evidence="$PWD/evidence/godot-task1"
trap 'adb logcat -d -t 2000 > "$evidence/logcat.txt"; adb shell screencap -p /sdcard/godot.png; adb pull /sdcard/godot.png "$evidence/screen.png"' EXIT
adb shell getprop ro.product.cpu.abi > "$evidence/emulator-abi.txt"
cd apps/world_observer/android
failed=0
# Each instrumentation starts a fresh target process. No data deletion or native
# engine reset is used to hide a re-open failure INSIDE reopenTwentyTimes.
for method in realGodotReadyHasEngineVersion secondOwnerIsRejectedWithoutKillingFirst reopenTwentyTimes resizeAndRotateKeepsHostAlive activityRecreationKeepsHostAlive realChannelReadyAndProbe; do
  report="$evidence/native/$method"
  mkdir -p "$report"
  timeout --kill-after=15s 180s ./gradlew :app:connectedDebugAndroidTest -PgodotTestAbi=x86_64 "-Pandroid.testInstrumentationRunnerArguments.class=com.tivini.livingworld.godot.GodotHostTest#$method" 2>&1 | tee "$report/gradle.log" || failed=1
  cp -a ../build/app/outputs/androidTest-results "$report/" 2>/dev/null || true
  cp -a ../build/app/reports/androidTests "$report/" 2>/dev/null || true
  adb logcat -d -t 500 > "$report/logcat.txt"
  if [ "$method" = realGodotReadyHasEngineVersion ]; then
    adb exec-out run-as com.tivini.livingworld cat cache/godot-ready.png > "$report/ready.png" || rm -f "$report/ready.png"
  fi
done
cd ..
ORG_GRADLE_PROJECT_godotTestAbi=x86_64 timeout --kill-after=15s 180s flutter test integration_test/godot_host_smoke_test.dart -d emulator-5554 --reporter expanded 2>&1 | tee "$evidence/flutter-native-integration.log" || failed=1
exit "$failed"
