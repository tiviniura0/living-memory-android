#!/usr/bin/env bash
set -euo pipefail
# Reproducible Android shell from the pinned SDK. Preserve the audited main manifest.
scaffold=$(mktemp -d)
flutter create --no-pub --platforms=android --org=com.tivini --project-name=livingworld "$scaffold/livingworld"
cp apps/world_observer/android/app/src/main/AndroidManifest.xml "$scaffold/world-manifest.xml"
cp -a "$scaffold/livingworld/android/." apps/world_observer/android/
cp "$scaffold/world-manifest.xml" apps/world_observer/android/app/src/main/AndroidManifest.xml
python3 scripts/check_world_boundaries.py
