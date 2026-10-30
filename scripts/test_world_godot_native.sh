#!/usr/bin/env bash
set -euo pipefail
evidence="$PWD/evidence/godot-task1"
trap 'adb logcat -d -t 1500 > "$evidence/logcat.txt"; adb shell screencap -p /sdcard/godot.png; adb pull /sdcard/godot.png "$evidence/screen.png"' EXIT
adb shell getprop ro.product.cpu.abi > "$evidence/emulator-abi.txt"
cd apps/world_observer/android
./gradlew :app:connectedDebugAndroidTest -PgodotTestAbi=x86_64 2>&1 | tee "$evidence/native-tests.log"
