#!/usr/bin/env bash
set -euo pipefail
# The pinned Flutter shell is tracked. Never regenerate or overwrite this host.
android=apps/world_observer/android
for file in gradlew settings.gradle.kts gradle/wrapper/gradle-wrapper.properties app/build.gradle.kts app/src/main/kotlin/com/tivini/livingworld/MainActivity.kt app/src/main/AndroidManifest.xml; do
  test -f "$android/$file" || { echo "Tracked Android host file missing: $file" >&2; exit 1; }
done
python3 scripts/check_world_boundaries.py
