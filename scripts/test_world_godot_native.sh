#!/usr/bin/env bash
set -euo pipefail
evidence="$PWD/evidence/godot-task1"
trap 'adb logcat -d -t 2000 > "$evidence/logcat.txt"; adb shell screencap -p /sdcard/godot.png; adb pull /sdcard/godot.png "$evidence/screen.png"' EXIT
adb shell rm -f /data/local/tmp/living-world-godot-ready.png /data/local/tmp/living-world-godot-reopened.png /data/local/tmp/living-world-godot-recreated.png /data/local/tmp/living-world-godot-relaunched.png /data/local/tmp/living-world-godot-touched.png
"$ANDROID_HOME/emulator/emulator" -version > "$evidence/emulator-version.txt" 2>&1
"$ANDROID_HOME/emulator/emulator" -help-gpu > "$evidence/emulator-gpu-options.txt" 2>&1 || true
adb shell dumpsys SurfaceFlinger > "$evidence/graphics-driver.txt"
adb shell getprop ro.product.cpu.abi > "$evidence/emulator-abi.txt"
cd apps/world_observer/android
failed=0
# Each instrumentation starts a fresh target process. No data deletion or native
# engine reset is used to hide a re-open failure INSIDE reopenTwentyTimes.
for method in realGodotReadyHasEngineVersion secondOwnerIsRejectedWithoutKillingFirst reopenTwentyTimes resizeAndRotateKeepsHostAlive activityRecreationKeepsHostAlive touchAfterRecreationReachesGodotScene activityFinishAndRelaunchKeepsHostAlive backgroundAndForegroundKeepsHostAlive realChannelReadyAndProbe; do
  report="$evidence/native/$method"
  mkdir -p "$report"
  timeout --kill-after=15s 180s ./gradlew :app:connectedDebugAndroidTest -PgodotTestAbi=x86_64 "-Pandroid.testInstrumentationRunnerArguments.class=com.tivini.livingworld.godot.GodotHostTest#$method" 2>&1 | tee "$report/gradle.log" || failed=1
  cp -a ../build/app/outputs/androidTest-results "$report/" 2>/dev/null || true
  cp -a ../build/app/reports/androidTests "$report/" 2>/dev/null || true
  adb logcat -d -t 500 > "$report/logcat.txt"
  adb logcat -d -t 4000 -s godot:V Godot:V GodotRenderer:V GodotGLRenderView:V AndroidRuntime:E '*:S' > "$report/godot-engine.log"
  capture=""
  case "$method" in
    realGodotReadyHasEngineVersion) capture=ready ;;
    reopenTwentyTimes) capture=reopened ;;
    activityRecreationKeepsHostAlive) capture=recreated ;;
    touchAfterRecreationReachesGodotScene) capture=touched ;;
    activityFinishAndRelaunchKeepsHostAlive) capture=relaunched ;;
  esac
  if [ -n "$capture" ]; then
    adb pull "/data/local/tmp/living-world-godot-$capture.png" "$report/ready.png" || failed=1
    python3 - "$report/ready.png" <<'PYPNG' || failed=1
import struct
import sys
from pathlib import Path
png = Path(sys.argv[1]).read_bytes()
assert png[:8] == b"\x89PNG\r\n\x1a\n", "Native ready capture is not a PNG"
width, height = struct.unpack(">II", png[16:24])
assert width > 0 and height > 0, "Native ready capture is empty"
print(f"Native ready capture: {width}x{height}")
PYPNG
  fi
done
cd ..
ORG_GRADLE_PROJECT_godotTestAbi=x86_64 timeout --kill-after=15s 180s flutter test integration_test/godot_host_smoke_test.dart -d emulator-5554 --reporter expanded 2>&1 | tee "$evidence/flutter-native-integration.log" || failed=1
exit "$failed"
