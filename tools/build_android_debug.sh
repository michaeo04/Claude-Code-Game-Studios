#!/usr/bin/env bash
# Builds build/tube_rush_debug.apk. The preset lives in build/ (gitignored) until the
# PiP decision (owner-actions A5) lets export_presets.cfg pass the manifest lint.
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-C:/Users/candl/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe}"
cp build/export_presets.android.cfg export_presets.cfg
trap 'rm -f export_presets.cfg' EXIT
"$GODOT" --headless --path . --export-debug "Android" build/tube_rush_debug.apk
