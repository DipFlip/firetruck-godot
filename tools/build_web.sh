#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_BIN" ]]; then GODOT_BIN="$(command -v godot)"; fi
mkdir -p builds/web
"$GODOT_BIN" --headless --editor --import --quit
"$GODOT_BIN" --headless --path . --script tools/bake_scenery.gd
"$GODOT_BIN" --headless --export-release Web builds/web/index.html
cp assets/fonts/Nunito.ttf builds/web/Nunito.ttf
cp assets/fonts/OFL-Nunito.txt builds/web/OFL-Nunito.txt
cp web/render_budget.js builds/web/render_budget.js
touch builds/web/.nojekyll
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
folder=Path('builds/web')
with ZipFile('builds/firetruck-web.zip','w',ZIP_DEFLATED) as archive:
    for path in sorted(folder.rglob('*')):
        if path.is_file(): archive.write(path,path.relative_to(folder))
print('Web build: builds/web/index.html; upload archive: builds/firetruck-web.zip')
PY
