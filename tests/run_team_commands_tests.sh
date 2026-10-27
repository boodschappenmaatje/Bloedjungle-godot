#!/bin/sh
set -eu
GODOT_BIN="${GODOT:-godot}"
FIXTURE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/team_commands_fixture" && pwd)"
"$GODOT_BIN" --headless --path "$FIXTURE_DIR" --editor --quit
"$GODOT_BIN" --headless --path "$FIXTURE_DIR" --script res://team_commands_test.gd
"$GODOT_BIN" --headless --path "$FIXTURE_DIR" res://ally_parse_test.tscn
exec "$GODOT_BIN" --headless --path "$FIXTURE_DIR"
