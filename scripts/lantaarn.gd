class_name Lantaarn
extends Node3D
## Straatlantaarn. Bij avond en nacht (Tijd in het pauzemenu) brandt de lamp: warm licht, gloed om de kap en een lichte flikkering.
## Alleen lantaarns dicht bij de camera krijgen echt licht (de mobiele renderer heeft een maximum aan lampen).

const LAMP := Vector3(0.0, 3.72, 0.7)   # onder de kap (voorkant = +z)
const RANGE := 11.0
const ENERGY := 2.4
const CAM_RANGE := 48.0

var _light: OmniLight3D
var _halo: Sprite3D
var _glass: StandardMaterial3D
var _t := randf() * 10.0
var _poll := randf() * 0.4
var _on := false


func _ready() -> void:
	var part: Dictionary = Stad._part("Lantaarn")
	if part.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = part.mesh
	add_child(mi)
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m != null and m.resource_name == "LampGlas" and m is StandardMaterial3D:
			_glass = m
	_light = OmniLight3D.new()
	_light.position = LAMP
	_light.omni_range = RANGE
	_light.omni_attenuation = 1.4
	_light.light_color = Color("ffc477")
	_light.light_energy = ENERGY
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	_halo = Sprite3D.new()
	_halo.texture = Fx.soft()
	_halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_halo.shaded = false
	_halo.pixel_size = 1.6 / 64.0
	_halo.modulate = Color(1.0, 0.78, 0.42, 0.5)
	_halo.position = LAMP + Vector3(0, 0.12, 0)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.visible = false
	add_child(_halo)
	_apply()


func _process(delta: float) -> void:
	if _light == null:
		return
	_t += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.4
		_apply()
	if _light.visible:
		_light.light_energy = ENERGY * (0.97 + 0.03 * sin(_t * 11.0) + 0.02 * sin(_t * 23.0))


func _apply() -> void:
	_on = GameSettings.get_value("time") != "day" and Game.power
	if _glass != null:
		_glass.emission_energy_multiplier = 3.0 if _on else 0.0
	var cam := get_viewport().get_camera_3d()
	var near := cam == null or cam.global_position.distance_to(global_position) < CAM_RANGE
	_light.visible = _on and near
	_halo.visible = _on and near
