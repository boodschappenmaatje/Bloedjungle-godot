extends SceneTree
func _initialize() -> void:
 call_deferred('_check')
func _check() -> void:
 var visual: Node3D = load('res://assets/vijand_m2_toren.glb').instantiate()
 root.add_child(visual)
 var names := ['TowerStatic','MG_Yaw','MG_ShieldMount','MG_Pitch','MG_Recoil','MG_BarrelReceiver','Muzzle']
 for n in names:
  assert(visual.find_child(n,true,false) != null, 'missing '+n)
 var static_mesh := visual.find_child('TowerStatic',true,false) as MeshInstance3D
 var shield := visual.find_child('MG_ShieldMount',true,false) as MeshInstance3D
 var barrel := visual.find_child('MG_BarrelReceiver',true,false) as MeshInstance3D
 var yaw := visual.find_child('MG_Yaw',true,false) as Node3D
 var pitch := visual.find_child('MG_Pitch',true,false) as Node3D
 var recoil := visual.find_child('MG_Recoil',true,false) as Node3D
 var muzzle := visual.find_child('Muzzle',true,false) as Node3D
 var tris := 0
 for mesh in [static_mesh,shield,barrel]:
  assert(mesh.mesh.get_surface_count() == 1)
  var arrays: Array = mesh.mesh.surface_get_arrays(0)
  assert((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() > 0)
  tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
  var mat := mesh.mesh.surface_get_material(0) as StandardMaterial3D
  assert(mat != null and mat.albedo_texture != null)
 assert(tris == 60000)
 assert(absf(muzzle.global_position.y - 5.75) < 0.02)
 assert(absf(muzzle.global_position.x + 2.25) < 0.02)
 var old_static := static_mesh.global_transform
 var old_shield := shield.global_transform
 var old_barrel := barrel.global_transform
 var old_muzzle := muzzle.global_position
 yaw.rotation.y = 0.785398
 assert(shield.global_transform != old_shield)
 assert(barrel.global_transform != old_barrel)
 assert(muzzle.global_position.distance_to(old_muzzle) > 0.5)
 assert(static_mesh.global_transform == old_static)
 pitch.rotation = Vector3(0,0,0.17)
 assert(muzzle.global_position.distance_to(old_muzzle) > 0.5)
 var muzzle_pitch := muzzle.global_position
 recoil.position.x = 0.12
 assert(muzzle.global_position.distance_to(muzzle_pitch) > 0.1)
 print('M2_ARTICULATIE_PASS triangles=',tris,' muzzle=',old_muzzle,' yaw_muzzle=',muzzle_pitch)
 quit()
