extends StaticBody3D
## Lightweight, opt-in hit-reactive practice dummy for the M1911 test scene.
## Simulated armor is a test multiplier, NOT real zombie armor gameplay.

var label_text := "LIGHT"
var distance_m := 5
var damage_multiplier := 1.0
var max_hp := 100.0
var hp := 100.0
var hits := 0
var knockdowns := 0
var _visual: MeshInstance3D
var _label: Label3D


func configure(title: String, distance: int, damage_scale: float) -> void:
	label_text = title
	distance_m = distance
	damage_multiplier = clampf(damage_scale, 0.05, 1.0)


func _ready() -> void:
	collision_layer = Bullet.MASK_ENEMY
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 2.0
	capsule.radius = 0.40
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)
	_visual = MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.height = 2.0
	body.radius = 0.40
	_visual.mesh = body
	_visual.position.y = 1.0
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.45
	_label.font_size = 48
	_label.pixel_size = 0.003
	add_child(_label)
	_update_visual()


func hit(damage: float, _direction: Vector3, by_player: bool) -> void:
	if not by_player:
		return
	hits += 1
	hp = maxf(0.0, hp - maxf(0.0, damage) * damage_multiplier)
	if hp <= 0.0:
		knockdowns += 1
		hp = max_hp  # Infinite training: instantly reset the next health bar.
	_update_visual()


func reset_target() -> void:
	hp = max_hp
	hits = 0
	knockdowns = 0
	_update_visual()


func _update_visual() -> void:
	if _visual == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("597f45") if damage_multiplier > 0.8 else (Color("ae8744") if damage_multiplier > 0.5 else Color("58718c"))
	m.roughness = 0.85
	_visual.material_override = m
	_label.text = "%s %dm  |  HP %.0f%%  |  HITS %d" % [label_text, distance_m, hp / max_hp * 100.0, hits]
