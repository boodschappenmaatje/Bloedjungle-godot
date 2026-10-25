class_name GrenadeAim
extends Node3D
## Richthulp voor de handgranaat: lichtboog met bewegende pijltjes, een gloeiende landingszone met de ontploffingsstraal,
## rode markeringen om vijanden in de straal en een waarschuwing als jij er zelf in staat.
## Goud = vrije baan, rood = een muur of auto staat in de weg, oranje = jij staat zelf in de straal.
## Alles tekent door bladeren en daken heen.

const OK := Color(1.0, 0.82, 0.3)
const BLOCKED := Color(0.95, 0.18, 0.12)
const SELF_HIT := Color(1.0, 0.5, 0.1)
const ENEMY := Color(1.0, 0.2, 0.15)
const GROUND := 0.06   # zone iets boven de grond tegen flikkeren

const ZONE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float radius = 5.0;
uniform float core = 0.55;
uniform float grow = 1.0;
varying vec2 lp;
void vertex() { lp = VERTEX.xz; }
void fragment() {
	float d = length(lp);
	float r = radius * grow;
	float a = 0.0;
	vec3 c = col.rgb;
	if (d < r + 0.1) {
		float t = clamp(d / r, 0.0, 1.0);
		// zachte vulling, naar de rand toe sterker, met een golf die naar buiten loopt
		float wave = 0.5 + 0.5 * sin(TIME * 4.0 - d * 1.6);
		a = (0.07 + 0.22 * t * t) * (0.75 + 0.25 * wave);
		// rand: heldere band met draaiende streepjes
		float rim = smoothstep(r - 0.28, r - 0.02, d) * (1.0 - smoothstep(r - 0.02, r + 0.07, d));
		float ang = atan(lp.y, lp.x) / 6.28318 + 0.5;
		float dash = 0.55 + 0.45 * step(0.5, fract(ang * 28.0 + TIME * 0.25));
		a = max(a, rim * 0.9 * dash);
		// landingspunt: schaduwvlek met ring, kruis en stip
		float blob = 1.0 - smoothstep(0.1, core, d);
		c = mix(c, vec3(0.0), blob * 0.55);
		a = max(a, blob * 0.38);
		float ring = (1.0 - smoothstep(0.05, 0.1, abs(d - core)));
		float cross_ = (1.0 - smoothstep(0.03, 0.07, min(abs(lp.x), abs(lp.y)))) * step(d, core * 1.5) * step(core * 0.55, d);
		float dot_ = 1.0 - smoothstep(0.1, 0.16, d);
		a = max(a, max(max(ring, cross_), dot_) * 0.97);
		if (max(max(ring, cross_), dot_) > 0.5) { c = col.rgb; }
	}
	ALBEDO = c;
	ALPHA = a;
}
"""

const ARC_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.82, 0.3, 1.0);
void fragment() {
	// UV.x = meters langs de boog, UV.y = -1..1 dwars; pijltjes lopen in de vliegrichting
	float y = abs(UV.y);
	float f = fract(UV.x * 1.1 - TIME * 2.6 - y * 0.7);
	float chev = smoothstep(0.0, 0.08, f) * (1.0 - smoothstep(0.22, 0.34, f));
	float line = 1.0 - smoothstep(0.0, 0.5, y);
	float a = max(chev * 1.0, line * 0.5) * (1.0 - y * y);
	a *= smoothstep(0.0, 1.2, UV.x);
	ALBEDO = col.rgb;
	ALPHA = a;
}
"""

static var _zone_shader: Shader
static var _arc_shader: Shader

var blocked := false
var land := Vector3.ZERO
var self_in_blast := false
var enemies_in_blast := 0

var _arc := MeshInstance3D.new()
var _arc_im := ImmediateMesh.new()
var _arc_mat := ShaderMaterial.new()
var _zone := MeshInstance3D.new()
var _zone_mat := ShaderMaterial.new()
var _zone_plane := PlaneMesh.new()
var _marks := MeshInstance3D.new()
var _marks_im := ImmediateMesh.new()
var _label := Label3D.new()
var _age := 0.0


func _init() -> void:
	top_level = true
	if _zone_shader == null:
		_zone_shader = Shader.new()
		_zone_shader.code = ZONE_SHADER
		_arc_shader = Shader.new()
		_arc_shader.code = ARC_SHADER
	_arc_mat.shader = _arc_shader
	_arc_mat.render_priority = 10
	_arc.mesh = _arc_im
	_arc.material_override = _arc_mat
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_arc)
	_zone_mat.shader = _zone_shader
	_zone_mat.render_priority = 9
	_zone.mesh = _zone_plane
	_zone.material_override = _zone_mat
	_zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_zone)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 11
	_marks.mesh = _marks_im
	_marks.material_override = m
	_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marks)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = false
	_label.pixel_size = 0.016
	_label.font_size = 56
	_label.outline_size = 14
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.render_priority = 12
	add_child(_label)


## Tekent de voorspelde baan van from naar target; blast = straal van de ontploffing.
func show_throw(from: Vector3, target: Vector3, blast: float) -> void:
	global_transform = Transform3D.IDENTITY
	var p := Grenade.predict(get_world_3d(), from, target)
	blocked = p.blocked
	land = p.land
	var ground := Vector3(land.x, target.y + GROUND, land.z)

	# wie zit er in de straal?
	enemies_in_blast = 0
	var marks: Array[Vector3] = []
	for e in Game.enemies:
		if is_instance_valid(e) and Vector2(e.global_position.x - land.x, e.global_position.z - land.z).length() < blast:
			enemies_in_blast += 1
			marks.append(e.global_position)
	var pl = Game.player
	self_in_blast = pl != null and is_instance_valid(pl) and Vector2(pl.global_position.x - land.x, pl.global_position.z - land.z).length() < blast

	var col := BLOCKED if blocked else (SELF_HIT if self_in_blast else OK)

	# zone: schaalt open als je begint te richten
	var size := (blast + 0.4) * 2.0
	_zone_plane.size = Vector2(size, size)
	_zone.global_position = ground
	_zone_mat.set_shader_parameter("col", col)
	_zone_mat.set_shader_parameter("radius", blast)
	_zone_mat.set_shader_parameter("grow", 1.0 - exp(-_age * 14.0) * 0.7)
	_age += get_process_delta_time()

	_build_arc(p.points, col)
	_build_marks(marks)

	# label: aantal vijanden en waarschuwing voor jezelf
	var txt := ""
	if enemies_in_blast > 0:
		txt = "%d vijand%s" % [enemies_in_blast, "" if enemies_in_blast == 1 else "en"]
	if self_in_blast:
		txt += ("\n" if txt != "" else "") + "LET OP: JIJ OOK"
	_label.text = txt
	_label.visible = txt != ""
	_label.modulate = SELF_HIT if self_in_blast else ENEMY.lerp(Color.WHITE, 0.35)
	_label.global_position = ground + Vector3(0.0, 2.4, 0.0)
	visible = true


## Boog als lint op de grond-richting, dunner naar de landing toe, met UV.x = afgelegde meters.
func _build_arc(pts: PackedVector3Array, col: Color) -> void:
	_arc_mat.set_shader_parameter("col", col)
	_arc_im.clear_surfaces()
	if pts.size() < 2:
		return
	_arc_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var dist := 0.0
	var tangent := Vector3.FORWARD
	for i in pts.size():
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if d.length() > 0.001:
			tangent = d.normalized()
		var side := Vector3(-tangent.z, 0.0, tangent.x)
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		var k := float(i) / float(pts.size() - 1)
		var w := lerpf(0.5, 0.2, k)
		_arc_im.surface_set_uv(Vector2(dist, -1.0))
		_arc_im.surface_add_vertex(pts[i] - side * w)
		_arc_im.surface_set_uv(Vector2(dist, 1.0))
		_arc_im.surface_add_vertex(pts[i] + side * w)
	_arc_im.surface_end()


## Rode ring en stip onder elke vijand die in de straal staat.
func _build_marks(marks: Array[Vector3]) -> void:
	_marks_im.clear_surfaces()
	if marks.is_empty():
		return
	_marks_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.012)
	for m in marks:
		var c := Vector3(m.x, GROUND + 0.02, m.z)
		_ring(c, 0.75 * pulse, 0.09, Color(ENEMY, 0.95))
		_disc(c, 0.14, Color(ENEMY, 0.95), 8)
		for k in 4:
			var a := TAU * k / 4.0 + PI * 0.25
			var d := Vector3(cos(a), 0, sin(a))
			_quad(c + d * 0.95, d, 0.28, 0.07, Color(ENEMY, 0.95))
	_marks_im.surface_end()


func _disc(c: Vector3, r: float, col: Color, n: int) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		_marks_im.surface_set_color(col)
		_marks_im.surface_add_vertex(c)
		_marks_im.surface_add_vertex(c + Vector3(cos(a0), 0, sin(a0)) * r)
		_marks_im.surface_add_vertex(c + Vector3(cos(a1), 0, sin(a1)) * r)


func _ring(c: Vector3, r: float, w: float, col: Color) -> void:
	var n := 28
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		_marks_im.surface_set_color(col)
		for v in [c + d0 * (r - w), c + d0 * (r + w), c + d1 * (r + w), c + d0 * (r - w), c + d1 * (r + w), c + d1 * (r - w)]:
			_marks_im.surface_add_vertex(v)


## Streepje van lengte len dat naar het midden wijst (hoekmarkering van het doelkruis).
func _quad(at: Vector3, dir: Vector3, len: float, w: float, col: Color) -> void:
	var side := Vector3(-dir.z, 0, dir.x)
	var a := at - dir * len * 0.5 - side * w
	var b := at - dir * len * 0.5 + side * w
	var c := at + dir * len * 0.5 + side * w
	var d := at + dir * len * 0.5 - side * w
	_marks_im.surface_set_color(col)
	for v in [a, b, c, a, c, d]:
		_marks_im.surface_add_vertex(v)
