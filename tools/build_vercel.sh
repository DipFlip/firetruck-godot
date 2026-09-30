#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/install_godot_linux.sh
tools/build_web.sh
