#!/usr/bin/env python3
"""Prepare the focused, headgear-free default player look for iPhone Quick Look."""
import argparse
import json
import sys
from pathlib import Path

import bpy


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", required=True, type=Path)
    p.add_argument("--weapons", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--report", required=True, type=Path)
    return p.parse_args(raw)


def run(args):
    for p in (args.source,):
        if not p.is_file():
            raise FileNotFoundError(p)
    for p in (args.output, args.report):
        if p.exists():
            raise FileExistsError(f"Refusing to overwrite {p}")
        p.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(args.source))
    visible = {"Lijf_JungleCommando", "Vest", "Koppel", "Laarzen", "Mag_Pouches", "Radio_Field", "IFAK_Pouch"}
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.hide_render = obj.name not in visible
            obj.hide_set(obj.name not in visible)
    rig = bpy.data.objects.get("Rig")
    if rig is None or len(rig.data.bones) != 53:
        raise RuntimeError("53-bone VQ2 rig missing")
    rig.animation_data_create()
    action = bpy.data.actions.get("stil")
    if action is None:
        raise RuntimeError("Idle animation 'stil' is missing")
    action_name = action.name
    rig.animation_data.action = action
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = (int(round(v)) for v in action.frame_range)
    scene.render.fps = 30
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.frame_set(scene.frame_start)
    if not args.weapons.is_file():
        raise FileNotFoundError(args.weapons)
    before_import = set(bpy.data.objects)
    existing_action_names = {action.name for action in bpy.data.actions}
    bpy.ops.import_scene.gltf(filepath=str(args.weapons))
    weapon_objects = set(bpy.data.objects) - before_import
    weapon = bpy.data.objects.get("M1911")
    if weapon is None:
        raise RuntimeError("Existing M1911 game weapon is missing")
    for obj in list(scene.objects):
        if obj.type == "MESH" and obj.name not in visible and obj.name not in {"M1911_HoutDonker", "M1911_Parkerized", "M1911_Slede_Parkerized", "M1911_Slede_Staal", "M1911_Staal"}:
            obj.hide_render = True
            obj.hide_set(True)
        elif obj.type == "MESH" and obj.name.startswith(("Garand_", "Bazooka_", "MG42_", "Thompson_", "Trench_", "M1911_")):
            keep_m1911 = obj.name in {"M1911_HoutDonker", "M1911_Parkerized", "M1911_Slede_Parkerized", "M1911_Slede_Staal", "M1911_Staal"}
            obj.hide_render = not keep_m1911
            obj.hide_set(not keep_m1911)
    weapon.parent = rig
    weapon.parent_type = "BONE"
    weapon.parent_bone = "DEF-handR"
    weapon.location = (0.0, 0.0, 0.0)
    weapon.rotation_euler = (0.0, 0.0, 0.0)
    weapon.scale = (1.0, 1.0, 1.0)
    weapon.hide_render = False
    weapon.hide_set(False)
    weapon["Preview only"] = "Existing game M1911 attached to the unchanged VQ2 hand bone"
    keep_weapon = {weapon, *weapon.children_recursive}
    for obj in list(weapon_objects - keep_weapon):
        bpy.data.objects.remove(obj, do_unlink=True)
    for action_candidate in list(bpy.data.actions):
        if action_candidate.name not in existing_action_names and not action_candidate.name.startswith("M1911"):
            if action_candidate.users == 0:
                bpy.data.actions.remove(action_candidate)
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output))
    report = {"status": "PASS", "source": str(args.source), "preview_blend": str(args.output), "visible_meshes": sorted(visible), "game_weapon": "Existing M1911, parented to DEF-handR for preview only", "rig_bones": len(rig.data.bones), "active_animation": action_name, "frame_range": [scene.frame_start, scene.frame_end], "units": "meters"}
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    run(arguments())
