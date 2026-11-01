class_name RallyFlag
extends Node3D
## Verzamelvlag uit assets/verzamelvlag.glb (Blender-bron: bron/verzamelvlag/).
## Paal in een zandzakkenstapel, olijfgroen doek met gouden zoom en ster dat zacht wappert (echte clip
## "Wapperen-loop"), kleine gouden lamp bovenin die alleen 's avonds en 's nachts gloeit, en een zachte gouden
## ring op de grond (Ø 3 m, pulseert langzaam). Geen botsing. Op afstand wordt LOD1 getoond.
## Dit script verwijst bewust niet naar autoloads, zodat het ook in tests laadt.

const LOD_SWITCH := 38.0   # meter vanaf de camera
const RING_DIAMETER := 3.0
const LAMP_DAY := 0.12
const LAMP_NIGHT := 5.0

var model_hi: Node
var model_lo: Node
var ring: MeshInstance3D
var _lamp_mats: Array[StandardMaterial3D] = []

static var _ring_shader: Shader


func _init() -> void:
	name = "Verzamelvlag"


func setup(night: bool) -> void:
	model_hi = _load_model("res://assets/verzamelvlag.glb", 0.0, LOD_SWITCH)
	model_lo = _load_model("res://assets/verzamelvlag_lod1.glb", LOD_SWITCH, 0.0)
	ring = _make_ring()
	add_child(ring)
	set_night(night)


func set_night(night: bool) -> void:
	for m in _lamp_mats:
		m.emission_energy_multiplier = LAMP_NIGHT if night else LAMP_DAY


func _load_model(path: String, range_begin: float, range_end: float) -> Node:
	var model: Node = (load(path) as PackedScene).instantiate()
	add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_begin = range_begin
		g.visibility_range_end = range_end
		if g.name == "Lamp":
			var mat := g.get_active_material(0)
			if mat is StandardMaterial3D:
				var own := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				own.emission_enabled = true
				g.material_override = own
				_lamp_mats.append(own)
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if ap:
		# Godot haalt het achtervoegsel "-loop" van de clipnaam en zet de clip zelf op herhalen
		var clip := "Wapperen" if ap.has_animation("Wapperen") else "Wapperen-loop"
		if ap.has_animation(clip):
			ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			ap.play(clip)
			ap.seek(randf() * 2.0, true)
	return model


func _make_ring() -> MeshInstance3D:
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float pulse = 0.75 + 0.25 * sin(TIME * 2.0);
	float line = exp(-pow((d - 0.93) / 0.05, 2.0));
	float glow = smoothstep(0.55, 0.95, d) * (1.0 - smoothstep(0.95, 1.0, d)) * 0.25;
	float a = (line * 0.9 + glow) * pulse;
	ALBEDO = vec3(1.0, 0.78, 0.25) * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
	var q := QuadMesh.new()
	q.size = Vector2(RING_DIAMETER, RING_DIAMETER)
	q.orientation = PlaneMesh.FACE_Y
	var m := ShaderMaterial.new()
	m.shader = _ring_shader
	var mi := MeshInstance3D.new()
	mi.name = "Ring"
	mi.mesh = q
	mi.material_override = m
	mi.position.y = 0.04
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
