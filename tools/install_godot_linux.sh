#!/usr/bin/env bash
# Source this file to use the same pinned engine in GitHub Actions and Vercel.
set -euo pipefail
FIREDRIVER_GODOT_VERSION=4.7.2
FIREDRIVER_GODOT_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/firedriver-godot/$FIREDRIVER_GODOT_VERSION"
FIREDRIVER_TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$FIREDRIVER_GODOT_VERSION.stable"
FIREDRIVER_RELEASE_URL="https://github.com/godotengine/godot-builds/releases/download/$FIREDRIVER_GODOT_VERSION-stable"
mkdir -p "$FIREDRIVER_GODOT_CACHE" "$FIREDRIVER_TEMPLATE_DIR"
export GODOT_BIN="$FIREDRIVER_GODOT_CACHE/Godot_v${FIREDRIVER_GODOT_VERSION}-stable_linux.x86_64"
if [[ ! -x "$GODOT_BIN" ]]; then
  curl -fL --retry 3 -o "$FIREDRIVER_GODOT_CACHE/engine.zip" "$FIREDRIVER_RELEASE_URL/Godot_v${FIREDRIVER_GODOT_VERSION}-stable_linux.x86_64.zip"
  unzip -o -q "$FIREDRIVER_GODOT_CACHE/engine.zip" -d "$FIREDRIVER_GODOT_CACHE"
  chmod +x "$GODOT_BIN"
  rm "$FIREDRIVER_GODOT_CACHE/engine.zip"
fi
if [[ ! -f "$FIREDRIVER_TEMPLATE_DIR/web_release.zip" ]]; then
  curl -fL --retry 3 -o "$FIREDRIVER_GODOT_CACHE/templates.tpz" "$FIREDRIVER_RELEASE_URL/Godot_v${FIREDRIVER_GODOT_VERSION}-stable_export_templates.tpz"
  unzip -o -j -q "$FIREDRIVER_GODOT_CACHE/templates.tpz" 'templates/web*' -d "$FIREDRIVER_TEMPLATE_DIR"
  rm "$FIREDRIVER_GODOT_CACHE/templates.tpz"
fi
