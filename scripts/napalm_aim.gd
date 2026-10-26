class_name NapalmAim
extends Node3D
## Richthulp voor de napalm-aanval: een gloeiende strook op de grond (NAPALM_LENGTH x NAPALM_WIDTH m) met pijltjes in de vliegrichting
## van het toestel en een rode markering om vijanden in de strook. Goud = kan, oranje = jij staat zelf in de strook.

const OK := Color(1.0, 0.82, 0.3)
const SELF_HIT := Color(1.0, 0.5, 0.1)
const ENEMY := Color(1.0, 0.2, 0.15)

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform vec2 half_size = vec2(2.5, 10.0);
varying vec2 lp;
void vertex() { lp = VERTEX.xz; }
void fragment() {
	// lp.x = dwars, lp.y = langs de strook (vliegrichting is -y in lokale ruimte)
	vec2 q = abs(lp) / half_size;
	float inside = step(max(q.x, q.y), 1.0);
	float edge = smoothstep(0.90, 1.0, max(q.x, q.y)) * inside;
	float chev = fract(-lp.y * 0.22 - TIME * 1.1 + abs(lp.x) * 0.22);
	float arrow = smoothstep(0.0, 0.08, chev) * (1.0 - smoothstep(0.18, 0.28, chev));
	float a = inside * (0.10 + 0.26 * arrow) + edge * 0.6;
	a *= 0.8 + 0.2 * sin(TIME * 5.0);
	ALBEDO = col.rgb;
	ALPHA = a;
}
"""

static var _shader: Shader

var self_in_strip := false
var enemies_in_strip := 0
var _mi := MeshInstance3D.new()
var _mat := ShaderMaterial.new()
var _plane := PlaneMesh.new()
var _label := Label3D.new()


func _init() -> void:
	top_level = true
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat.shader = _shader
	_mat.render_priority = 9
	_plane.size = Vector2(Streak.NAPALM_WIDTH + 1.0, Streak.NAPALM_LENGTH + 1.0)
	_mi.mesh = _plane
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
	_label.position = Vector3(0, 1.2, 0)
	add_child(_label)


## Toont de strook rond center, met het toestel dat langs dir vliegt.
func show_strip(center: Vector3, dir: Vector3) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), Vector3(center.x, 0.07, center.z))
	_mat.set_shader_parameter("half_size", Vector2(Streak.NAPALM_WIDTH * 0.5, Streak.NAPALM_LENGTH * 0.5))
	var side := dir.cross(Vector3.UP)
	enemies_in_strip = 0
	for e in Game.enemies:
		if is_instance_valid(e):
			var d: Vector3 = e.global_position - center
			if absf(d.dot(dir)) < Streak.NAPALM_LENGTH * 0.5 and absf(d.dot(side)) < Streak.NAPALM_WIDTH * 0.5:
				enemies_in_strip += 1
	var p = Game.player
	self_in_strip = false
	if p != null and is_instance_valid(p):
		var dp: Vector3 = p.global_position - center
		self_in_strip = absf(dp.dot(dir)) < Streak.NAPALM_LENGTH * 0.5 + 1.0 and absf(dp.dot(side)) < Streak.NAPALM_WIDTH * 0.5 + 1.0
	_mat.set_shader_parameter("col", SELF_HIT if self_in_strip else OK)
	_label.text = ("×%d" % enemies_in_strip) if enemies_in_strip > 0 else ""
	_label.modulate = ENEMY
