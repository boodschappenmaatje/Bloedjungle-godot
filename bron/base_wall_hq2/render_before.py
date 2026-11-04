#!/usr/bin/env python3
"""Render the original primitive wall builder for a clearly labeled comparison.

This is a Blender reconstruction from the pre-HQ2 BaseProps._wall() dimensions,
not a capture of a running game. The final views use render_perimeter.py.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_perimeter as preview


def add_legacy_wall():
    concrete = preview.material("Old primitive concrete", (0.35, 0.36, 0.33), 0.96)
    dark = preview.material("Old primitive concrete trim", (0.23, 0.24, 0.22), 0.96)
    compound, gate_gap, wall_height, thickness = 28.0, 3.4, 1.55, 0.4
    half = (compound - gate_gap) / 2.0
    spans = [
        (-(gate_gap + half), -compound, compound - gate_gap, thickness, True),
        ((gate_gap + half), -compound, compound - gate_gap, thickness, True),
        (-(gate_gap + half), compound, compound - gate_gap, thickness, True),
        ((gate_gap + half), compound, compound - gate_gap, thickness, True),
        (-compound, 0.0, compound * 2.0 + thickness, thickness, False),
        (compound, 0.0, compound * 2.0 + thickness, thickness, False),
    ]
    for index, (axis_center, cross_center, length, depth, along_x) in enumerate(spans):
        x, y = axis_center, cross_center
        size = (length, depth, wall_height) if along_x else (depth, length, wall_height)
        preview.box(f"OldWall_{index}_body", size,
                    (x, y, wall_height * 0.5), concrete)
        cap_size = (length + 0.1, depth + 0.14, 0.14) if along_x else (depth + 0.14, length + 0.1, 0.14)
        foot_size = (length + 0.06, depth + 0.2, 0.28) if along_x else (depth + 0.2, length + 0.06, 0.28)
        preview.box(f"OldWall_{index}_cap", cap_size,
                    (x, y, wall_height + 0.07), dark)
        preview.box(f"OldWall_{index}_foot", foot_size,
                    (x, y, 0.14), dark)
        post_count = int(length / 3.5)
        for post_index in range(post_count + 1):
            offset = -length * 0.5 + post_index * (length / max(post_count, 1))
            px, py = ((x + offset, y) if along_x else (x, y + offset))
            size = (0.55, depth + 0.25, wall_height + 0.3) if along_x else (depth + 0.25, 0.55, wall_height + 0.3)
            preview.box(f"OldWall_{index}_post_{post_index}", size,
                        (px, py, (wall_height + 0.3) * 0.5), dark)


def add_legacy_gate_and_towers():
    concrete = preview.material("Old gate concrete", (0.30, 0.31, 0.29), 0.94)
    olive = preview.material("Old olive gate steel", (0.20, 0.22, 0.15), 0.6, 0.35)
    yellow = preview.material("Old gate ochre", (0.56, 0.39, 0.1), 0.66, 0.12)
    dark = preview.material("Old gate black", (0.055, 0.06, 0.05), 0.72, 0.1)
    for side, z, rotation in (("north", -28.0, 0.0), ("south", 28.0, math.pi)):
        preview.group_import(preview.ROOT / "assets/poort.glb", f"Existing_{side}_sliding_gate", (0, z, 0), rotation)
        for x in (-3.7, 3.7):
            preview.box(f"{side}_gate_post", (0.7, 0.7, 2.1), (x, z, 1.05), concrete)
            preview.box(f"{side}_gate_post_cap", (0.9, 0.9, 0.16), (x, z, 2.18), concrete)
        preview.box(f"{side}_gate_header", (7.8, 0.4, 0.18), (0, z, 2.09), olive)
        for i in range(10):
            x = -3.4 + i * (6.8 / 9.0)
            preview.box(f"{side}_gate_mark_{i}", (0.22, 0.44, 0.16), (x, z, 1.92), yellow if i % 2 == 0 else dark)
    for sx in (-1, 1):
        for sy in (-1, 1):
            rotation = 0.0 if sx < 0 else math.pi
            preview.group_import(preview.ROOT / "assets/wachttoren.glb", f"Existing_watchtower_{sx}_{sy}",
                                 (sx * 26.2, sy * 26.2, 0), rotation)


def main():
    preview.add_wall_instances = add_legacy_wall
    preview.add_wall_berm = lambda: None
    preview.add_gate_and_towers = add_legacy_gate_and_towers
    scene = preview.setup_scene()
    preview.render_view(scene, "00_before_primitive_wall.jpg", (77, -92, 74), (0, 0, 1), 82)


if __name__ == "__main__":
    main()
