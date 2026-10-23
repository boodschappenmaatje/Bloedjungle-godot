class_name StadEditorPreview
extends Node3D
## Een pure GLB-preview. Geen Woonhuis-script, schade, botsingen, lampen of spelregistratie.

var kind := ""
var model: Node3D
var material := StandardMaterial3D.new()
var _scenes := {}


func _init() -> void:
	name = "Plaatsingspreview"
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1.0
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.28, 0.78, 0.42, 0.22)
	visible = false


func show_item(d: Dictionary, valid: bool) -> void:
	var data: Dictionary = Stad.KINDS[d.k]
	if data.cat != "gebouw":
		visible = false
		return
	if kind != String(d.k):
		kind = d.k
		if model:
			remove_child(model)
			model.queue_free()
		var path := String(data.get("glb", "res://assets/%s.glb" % kind))
		if data.get("model", false) and ResourceLoader.exists(path):
			if not _scenes.has(path):
				_scenes[path] = load(path)
			model = (_scenes[path] as PackedScene).instantiate()
			_clean(model)
		else:
			model = Node3D.new()
			_block(Vector3(0, float(data.h) * 0.5, 0), Vector3(data.hx * 2.0, data.h, data.hz * 2.0))
			_block(Vector3(0, data.h, 0), Vector3(data.hx * 2.0 + 0.4, 0.3, data.hz * 2.0 + 0.4))
			_block(Vector3(0, 1.15, data.hz), Vector3(1.4, 2.3, 0.15))
		add_child(model)
	position = Vector3(d.x, 0.02, d.z)
	rotation.y = Stad.yaw_of(d)
	# De bestaande gebouwlogica spiegelt geen gebouwen; de editor biedt die actie daar niet aan.
	scale = Vector3.ONE
	material.albedo_color = Color(0.28, 0.78, 0.42, 0.22) if valid else Color(0.95, 0.26, 0.20, 0.24)
	visible = true


func _block(at: Vector3, dimensions: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mi.mesh = mesh
	mi.position = at
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(mi)


func _clean(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		var nm := String(child.name)
		if child is CollisionObject3D or child is Light3D or child is AnimationPlayer or nm.begins_with("Ruine") or nm.begins_with("Puin") or nm.ends_with("_kapot"):
			node.remove_child(child)
			child.free()
		else:
			_clean(child)
	if node is MeshInstance3D:
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
