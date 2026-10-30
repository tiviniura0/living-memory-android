#!/usr/bin/env bash
set -euo pipefail
# Bootstrap only missing Flutter-owned files; never overwrite the tracked host.
android=apps/world_observer/android
if [ ! -f "$android/gradlew" ]; then
  scaffold=$(mktemp -d)
  trap 'rm -rf "$scaffold"' EXIT
  flutter create --no-pub --platforms=android --org=com.tivini --project-name=livingworld "$scaffold/livingworld"
  cp -an "$scaffold/livingworld/android/." "$android/"
fi
python3 scripts/check_world_boundaries.py
