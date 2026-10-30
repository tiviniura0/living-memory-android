#!/usr/bin/env bash
set -euo pipefail
godot_bin="${GODOT_BIN:-godot}"
"$godot_bin" --headless --version | grep -Eq '^4\.5\.1\.stable\.'
assets="$PWD/packages/living_world_godot/build/generated/assets"
mkdir -p "$assets"
"$godot_bin" --headless --path renderers/godot2d --editor --import
"$godot_bin" --headless --path renderers/godot2d --export-pack Android "$assets/world_godot.pck"
test -s "$assets/world_godot.pck"
sha256sum "$assets/world_godot.pck"
