#!/usr/bin/env bash
set -euo pipefail
evidence="$PWD/evidence/godot-task1"
mkdir -p "$evidence"
collect_exit() {
  local original_status=$?
  trap - EXIT
  adb logcat -d -t 2000 > "$evidence/logcat.txt" || true
  adb exec-out screencap -p > "$evidence/screen.png" || echo "Final diagnostic screenshot unavailable"
  exit "$original_status"
}
trap collect_exit EXIT
diagnostic() {
  local output="$1"
  shift
  local diagnostic_status=0
  "$@" > "$output" 2>&1 || diagnostic_status=$?
  printf '%s: diagnostic exit %s\n' "$output" "$diagnostic_status"
  head -n 24 "$output"
}
adb shell rm -f /data/local/tmp/living-world-godot-ready.png /data/local/tmp/living-world-godot-reopened.png /data/local/tmp/living-world-godot-recreated.png /data/local/tmp/living-world-godot-relaunched.png /data/local/tmp/living-world-godot-touched.png
diagnostic "$evidence/emulator-version.txt" "$ANDROID_HOME/emulator/emulator" -version
diagnostic "$evidence/emulator-gpu-options.txt" "$ANDROID_HOME/emulator/emulator" -help-gpu
diagnostic "$evidence/graphics-driver.txt" adb shell dumpsys SurfaceFlinger
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
ORG_GRADLE_PROJECT_godotTestAbi=x86_64 timeout --kill-after=15s 180s flutter test integration_test/godot_host_smoke_test.dart -d emulator-5554 --reporter expanded > "$evidence/flutter-native-integration.log" 2>&1 &
flutter_pid=$!
flutter_canvas=0
while kill -0 "$flutter_pid" 2>/dev/null; do
  if [[ "$(< "$evidence/flutter-native-integration.log")" == *GODOT_CANVAS_CAPTURE_READY* ]]; then
    if adb exec-out screencap -p > "$evidence/flutter-scene.png" && \
       python3 ../../scripts/verify_world_godot_capture.py "$evidence/flutter-scene.png" > "$evidence/flutter-scene.json" 2>&1; then
      flutter_canvas=1
      break
    fi
  fi
  sleep 0.2
done
wait "$flutter_pid" || failed=1
cat "$evidence/flutter-native-integration.log"
if [ "$flutter_canvas" -ne 1 ]; then
  echo "Real Flutter PlatformView did not expose the Godot Canvas signature"
  cat "$evidence/flutter-scene.json" 2>/dev/null || true
  failed=1
fi
exit "$failed"
