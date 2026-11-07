#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHOWCASE_DIR="$ROOT_DIR/tests/m47_cinematic_vfx"
GODOT_BIN="${GODOT_BIN:-/tmp/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
VERSION="$($GODOT_BIN --version)"
if [[ "$VERSION" != 4.7.2.stable.* ]]; then
    printf 'Godot 4.7.2 required, found %s\n' "$VERSION" >&2
    exit 2
fi
if [[ -z "${DISPLAY:-}" ]]; then
    printf 'A real or virtual X11 display is needed for cinematic captures.\n' >&2
    exit 2
fi
mkdir -p "$SHOWCASE_DIR/frames" "$SHOWCASE_DIR/screenshots" "$SHOWCASE_DIR/logs"
"$GODOT_BIN" --headless --editor --path "$SHOWCASE_DIR" --import > "$SHOWCASE_DIR/logs/import.log" 2>&1
rm -f "$SHOWCASE_DIR"/frames/frame_*.png
"$GODOT_BIN" --audio-driver Dummy --fixed-fps 30 --path "$SHOWCASE_DIR" --quit-after 400 > "$SHOWCASE_DIR/logs/godot_showcase.log" 2>&1
grep -Fq 'M47_CINEMATIC_TEST PASS' "$SHOWCASE_DIR/logs/godot_showcase.log"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|ERROR:' "$SHOWCASE_DIR/logs/godot_showcase.log"; then
    printf 'Godot logged an error. Inspect logs/godot_showcase.log.\n' >&2
    exit 1
fi
ffmpeg -hide_banner -loglevel error -y -framerate 30 \
    -i "$SHOWCASE_DIR/frames/frame_%04d.png" \
    -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -movflags +faststart \
    "$SHOWCASE_DIR/screenshots/m47_cinematic_vfx_4_0.mp4"
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 \
    "$SHOWCASE_DIR/screenshots/m47_cinematic_vfx_4_0.mp4"
