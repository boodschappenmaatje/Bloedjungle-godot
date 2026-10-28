#!/usr/bin/env python3
"""Prepare the focused, headgear-free default player look for iPhone Quick Look."""
import argparse
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector


def arguments():
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", required=True, type=Path)
    p.add_argument("--weapons", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--report", required=True, type=Path)
    p.add_argument("--action", default="stil", help="Existing VQ2 action to show in USDZ")
    p.add_argument("--frame", type=int, help="Frame within the selected action; defaults to its midpoint")
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
    visible_v2 = {
        "Lijf_JungleCommando", "Uniform_Jacket_Shell", "Uniform_Trousers_Shell", "Hair_Cropped",
        "Vest_JungleCommando", "Vest_JungleCommando_Details", "Koppel", "Laarzen", "Mag_Pouches",
        "Radio_Field", "IFAK_Pouch", "Gloves_Closed", "Knee_Reinforcements", "Elbow_Reinforcements",
        "Boot_Sole_L", "Boot_Sole_R", "Boot_Laces_L", "Boot_Laces_R", "Boot_Eyelets_L", "Boot_Eyelets_R",
    }
    visible = visible_v2 if "Uniform_Jacket_Shell" in bpy.data.objects else {
        "Lijf_JungleCommando", "Vest", "Koppel", "Laarzen", "Mag_Pouches", "Radio_Field", "IFAK_Pouch"
    }
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.hide_render = obj.name not in visible
            obj.hide_set(obj.name not in visible)
    rig = bpy.data.objects.get("Rig")
    if rig is None or len(rig.data.bones) != 53:
        raise RuntimeError("53-bone VQ2 rig missing")
    rig.animation_data_create()
    action = bpy.data.actions.get(args.action)
    if action is None:
        raise RuntimeError(f"VQ2 action {args.action!r} is missing")
    action_name = action.name
    rig.animation_data.action = action
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = (int(round(v)) for v in action.frame_range)
    scene.render.fps = 30
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    frame = max(scene.frame_start, min(scene.frame_end, args.frame if args.frame is not None else (scene.frame_start + scene.frame_end) // 2))
    scene.frame_set(frame)
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
    # In-game SoldierPose supplies this support-hand IK at runtime. Mirror it in
    # the review-only .blend so the USDZ doesn't show the source clip's open,
    # outstretched support hand away from the pistol.
    if args.action in {"stil", "schieten", "lopen", "rennen", "geraakt"}:
        forearm = rig.pose.bones.get("DEF-forearmL")
        upper = rig.pose.bones.get("DEF-upper_armL")
        if forearm is None or upper is None:
            raise RuntimeError("Left arm bones required to preview the two-hand weapon hold")
        bpy.context.view_layer.update()
        target = bpy.data.objects.new("Preview IK · left support palm", None)
        scene.collection.objects.link(target)
        target.empty_display_type = "SPHERE"
        target.empty_display_size = 0.025
        # Put the support palm just forward of the pistol grip. The target follows
        # the weapon through the short firing clip.
        target.parent = weapon
        target.location = (0.0, 0.08, 0.0)
        bpy.context.view_layer.update()
        pole = bpy.data.objects.new("Preview IK · left elbow pole", None)
        scene.collection.objects.link(pole)
        pole.empty_display_type = "SPHERE"
        pole.empty_display_size = 0.018
        shoulder = rig.matrix_world @ upper.head
        elbow = rig.matrix_world @ upper.tail
        axis = (target.matrix_world.translation - shoulder).normalized()
        pole_direction = elbow - shoulder
        pole_direction -= axis * pole_direction.dot(axis)
        if pole_direction.length < 0.001:
            pole_direction = Vector((0.0, 0.0, 1.0))
        pole.location = elbow + pole_direction.normalized() * 0.22
        ik = forearm.constraints.new("IK")
        ik.name = "Preview two-hand weapon hold (Godot IK reference)"
        ik.target = target
        ik.pole_target = pole
        ik.chain_count = 2
        ik.iterations = 48
        ik.use_stretch = False
        # Blender's positive pole axis differs from Godot's basis-converted pole;
        # this quarter-turn keeps the preview elbow low instead of crossing the face.
        ik.pole_angle = -1.5707963267948966
        bpy.context.view_layer.update()
    keep_weapon = {weapon, *weapon.children_recursive}
    for obj in list(weapon_objects - keep_weapon):
        bpy.data.objects.remove(obj, do_unlink=True)
    for action_candidate in list(bpy.data.actions):
        if action_candidate.name not in existing_action_names and not action_candidate.name.startswith("M1911"):
            if action_candidate.users == 0:
                bpy.data.actions.remove(action_candidate)
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output))
    report = {"status": "PASS", "source": str(args.source), "preview_blend": str(args.output), "visible_meshes": sorted(visible), "game_weapon": "Existing M1911, parented to DEF-handR for preview only", "preview_left_hand_ik": "Preview-only two-bone support-arm IK at the pistol foregrip; game runtime IK remains in SoldierPose", "rig_bones": len(rig.data.bones), "active_animation": action_name, "frame": frame, "frame_range": [scene.frame_start, scene.frame_end], "units": "meters"}
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    run(arguments())
