class_name ArtillerieAim
extends Node3D
## Richthulp voor het artilleriecommando: een pulserende ring op de grond (Artillerie.RADIUS) met kruisdraad,
## goud = vrij, rood = er staan vijanden in. Het aantal vijanden in de ring staat erboven.

const OK := Color(1.0, 0.82, 0.3)
const ENEMY := Color(1.0, 0.25, 0.15)

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float radius = 6.5;
uniform float alpha = 0.7;
varying vec2 lp;
void vertex() { lp = VERTEX.xz; }
void fragment() {
	float r = length(lp) / radius;
	float ring = smoothstep(0.90, 0.97, r) * (1.0 - smoothstep(1.0, 1.05, r));
	float cross_ = (1.0 - smoothstep(0.0, 0.025, min(abs(lp.x), abs(lp.y)) / radius)) * (1.0 - smoothstep(0.55, 0.6, r));
	float fill = (1.0 - smoothstep(0.97, 1.0, r)) * 0.12;
	float a = (ring * 0.9 + cross_ * 0.55 + fill) * alpha;
	ALBEDO = col.rgb;
	ALPHA = a;
}
"""

static var _shader: Shader

var enemies_inside := 0
var _mi := MeshInstance3D.new()
var _mat := ShaderMaterial.new()
var _label := Label3D.new()


func _init() -> void:
	top_level = true
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat.shader = _shader
	_mat.render_priority = 9
	_mat.set_shader_parameter("radius", Artillerie.RADIUS)
	var plane := PlaneMesh.new()
	plane.size = Vector2(Artillerie.RADIUS * 2.0 + 1.0, Artillerie.RADIUS * 2.0 + 1.0)
	_mi.mesh = plane
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.014
	_label.font_size = 52
	_label.outline_size = 12
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.render_priority = 12
	_label.position = Vector3(0, 1.4, 0)
	add_child(_label)


## Standaard de artilleriering; de parachutisten (E2) tonen hun landingscirkel met eigen straal en naam.
func show_at(center: Vector3, radius: float = Artillerie.RADIUS, naam: String = "ARTILLERIE") -> void:
	global_position = Vector3(center.x, 0.08, center.z)
	_mat.set_shader_parameter("radius", radius)
	(_mi.mesh as PlaneMesh).size = Vector2(radius * 2.0 + 1.0, radius * 2.0 + 1.0)
	enemies_inside = 0
	for e in Game.enemies:
		if is_instance_valid(e) and e.get("dead") != true:
			if Vector2(e.global_position.x - center.x, e.global_position.z - center.z).length() < radius:
				enemies_inside += 1
	_mat.set_shader_parameter("col", ENEMY if enemies_inside > 0 else OK)
	_mat.set_shader_parameter("alpha", 0.6 + 0.3 * sin(Time.get_ticks_msec() / 160.0))
	_label.text = naam if enemies_inside == 0 else "%s · %d" % [naam, enemies_inside]
	_label.modulate = ENEMY if enemies_inside > 0 else OK
