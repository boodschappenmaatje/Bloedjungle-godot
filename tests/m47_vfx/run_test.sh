#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="$ROOT_DIR/tests/m47_vfx"
GODOT_BIN="${GODOT_BIN:-godot}"
VERSION="$($GODOT_BIN --version)"

if [[ "$VERSION" != 4.7.2.stable.* ]]; then
	printf 'Expected official Godot 4.7.2, got: %s\n' "$VERSION" >&2
	exit 2
fi
if [[ -z "${DISPLAY:-}" ]]; then
	echo "A real or virtual X11 display is required for screenshots and video." >&2
	exit 2
fi

"$GODOT_BIN" --headless --editor --path "$TEST_DIR" --import
rm -f "$TEST_DIR"/captures/frame_*.png
"$GODOT_BIN" --audio-driver Dummy --fixed-fps 30 --path "$TEST_DIR" --quit-after 600 2>&1 | tee "$TEST_DIR/logs/godot_m47_vfx_test.log"
grep -Fq "M47_VFX_TEST PASS" "$TEST_DIR/logs/godot_m47_vfx_test.log"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|ERROR:' "$TEST_DIR/logs/godot_m47_vfx_test.log"; then
	echo "Godot reported an error during the M-47 VFX test." >&2
	exit 1
fi

ffmpeg -hide_banner -loglevel error -y \
	-framerate 30 -i "$TEST_DIR/captures/frame_%04d.png" \
	-c:v libx264 -preset medium -crf 25 -pix_fmt yuv420p -movflags +faststart \
	"$TEST_DIR/screenshots/m47_vfx_preview.mp4"

"$GODOT_BIN" --audio-driver Dummy --fixed-fps 30 --path "$TEST_DIR" --quit-after 600 -- --no-capture 2>&1 | tee "$TEST_DIR/logs/godot_m47_vfx_performance.log"
grep -Fq "M47_VFX_TEST PASS" "$TEST_DIR/logs/godot_m47_vfx_performance.log"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|ERROR:' "$TEST_DIR/logs/godot_m47_vfx_performance.log"; then
	echo "Godot reported an error during the M-47 VFX performance pass." >&2
	exit 1
fi

echo "M47 VFX 2.0 checks and captures passed with $VERSION"
