import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="../../assets/soldaat.glb")
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
print(bpy.app.version_string, arm.rotation_mode, arm.matrix_world.to_euler(), arm.scale)
for a in bpy.data.actions: print("ACT",a.name, tuple(a.frame_range))
for n in ['root','DEF-hips','DEF-spine001','DEF-thighL','DEF-shinL','DEF-upper_armL','DEF-forearmL','DEF-upper_armR','DEF-head']:
    b=arm.data.bones[n]; m=b.matrix_local
    print(n, [round(v,2) for v in b.head_local], [round(v,2) for v in b.tail_local], "x",[round(v,2) for v in m.col[0][:3]],"z",[round(v,2) for v in m.col[2][:3]])
print(arm.animation_data.action if arm.animation_data else None, arm.pose.bones['DEF-hips'].rotation_mode)
