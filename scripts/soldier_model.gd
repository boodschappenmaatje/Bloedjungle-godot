class_name SoldierModel
extends Node3D
## Het geanimeerde mannetje (Quaternius-pop met de Mixamo-geweeranimaties uit assets/soldaat.glb),
## gebruikt door de speler en de vijanden. Kleurt het uniform en hangt een wapen in de rechterhand.

const SCENE := preload("res://assets/soldaat.glb")
const LOOPS := ["stil", "lopen", "rennen", "achteruit", "schieten", "herladen"]

var anim: AnimationPlayer
var current := ""
var _mats: Array[StandardMaterial3D] = []
var _base_cols: Array[Color] = []
var _flash := 0.0


func setup(uniform: Color) -> void:
	var model := SCENE.instantiate()
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	for n in LOOPS:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	# eigen kopie van de materialen, zodat elk mannetje een eigen kleur en rode flits kan hebben
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			var m: StandardMaterial3D = src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
			m.albedo_color = uniform if m.resource_name != "M_Joints" else uniform.darkened(0.45)
			mi.set_surface_override_material(s, m)
			_mats.append(m)
			_base_cols.append(m.albedo_color)
	_attach_gun(model)
	play("stil")


func _attach_gun(model: Node) -> void:
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var hand := BoneAttachment3D.new()
	hand.bone_name = "DEF-handR"
	skel.add_child(hand)
	var gun := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.09, 0.55)
	gun.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.11, 0.1)
	m.metallic = 0.5
	m.roughness = 0.5
	gun.material_override = m
	# zoals gunMountMatrix() in de web-versie: in de stilstaande houding wijst het wapen recht vooruit
	anim.play("stil")
	anim.seek(0.05, true)
	var pose := skel.get_bone_global_pose(skel.find_bone("DEF-handR"))
	var inv := pose.basis.orthonormalized().inverse()
	gun.transform = Transform3D(inv, inv * Vector3(0.0, 0.0, 0.18))
	hand.add_child(gun)


## Speelt een animatie met een zachte overgang; doet niets als hij al speelt.
func play(clip: String, blend := 0.18, speed := 1.0) -> void:
	if current == clip or not anim.has_animation(clip):
		if current == clip:
			anim.speed_scale = speed
		return
	current = clip
	anim.play(clip, blend)
	anim.speed_scale = speed


## Rode flits als hij geraakt wordt.
func flash() -> void:
	_flash = 0.1


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	for i in _mats.size():
		_mats[i].albedo_color = Color(0.9, 0.1, 0.05) if _flash > 0.0 else _base_cols[i]
