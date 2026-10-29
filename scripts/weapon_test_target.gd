extends StaticBody3D
## Damageable prop used only in the dedicated weapon test scene.

var label_text := "Doel"
var max_hp := 100.0
var hp := 100.0
var _phase := 0.0
var _home_x := 0.0


func _ready() -> void:
	_home_x = global_position.x


func _process(delta: float) -> void:
	if has_meta("move_center"):
		_phase += delta * 1.35
		var center: Vector3 = get_meta("move_center")
		global_position.x = center.x + sin(_phase) * float(get_meta("move_range"))


func hit(dmg: float, _dir: Vector3, from_player: bool) -> void:
	if not from_player:
		return
	hp = maxf(0.0, hp - dmg)
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh and mesh.mesh is SphereMesh:
		var mat := (mesh.mesh as SphereMesh).material as StandardMaterial3D
		if mat:
			mat.albedo_color = Color("e8d08a").lerp(Color("8c392d"), 1.0 - hp / max_hp)
	var label := get_node_or_null("Label3D") as Label3D
	if label:
		label.text = "%s · %d / %d HP" % [label_text, roundi(hp), roundi(max_hp)]
