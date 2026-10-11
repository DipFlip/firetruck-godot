#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_BIN" ]]; then GODOT_BIN="$(command -v godot)"; fi
mkdir -p builds/web
# Export into a fresh directory, then publish a complete version atomically
# from the browser's perspective before updating the latest entry page.
WEB_STAGE=$(mktemp -d "$PWD/builds/web-export.XXXXXX")
trap 'rm -rf "$WEB_STAGE"' EXIT
"$GODOT_BIN" --headless --editor --import --quit
"$GODOT_BIN" --headless --path . --script tools/bake_scenery.gd
"$GODOT_BIN" --headless --export-release Web "$WEB_STAGE/index.html"
cp assets/fonts/Nunito.ttf "$WEB_STAGE/Nunito.ttf"
cp assets/fonts/OFL-Nunito.txt "$WEB_STAGE/OFL-Nunito.txt"
cp web/render_budget.js "$WEB_STAGE/render_budget.js"
python3 tools/package_web.py "$WEB_STAGE" builds/web builds/firetruck-web.zip
