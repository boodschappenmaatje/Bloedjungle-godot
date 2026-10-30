class_name SoldierMark
extends Node3D
## Leesbaarheid van soldaten: een subtiele ring op de grond, een richtingstreep voor de speler
## en een zacht randlicht langs het lichaam. Instelling "markeringen":
## "on" = in beide camerastanden, "tact" = alleen in Tactisch, "off" = uit. Hangt als kind aan een SoldierModel.

const MODEL_BOOST := 1.0   # De camera zorgt voor leesbaarheid zonder onnatuurlijke modelschaal.
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float ring = smoothstep(0.66, 0.72, d) * (1.0 - smoothstep(0.84, 0.90, d));
	float fill = (1.0 - smoothstep(0.2, 0.72, d)) * 0.18;
	ALBEDO = col.rgb;
	ALPHA = col.a * max(ring, fill);
}
"""
const RIM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color;
uniform float strength = 1.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = col.rgb * f * strength;
}
"""
const COLORS := {"speler": Color("d9b36a"), "vijand": Color("e34b37"), "vriend": Color("4fd36b")}
const RIM_STRENGTH := {"speler": 0.62, "vijand": 0.38, "vriend": 0.34}

static var _ring_shader: Shader
static var _rim_shader: Shader
static var _rim_mats := {}
static var _frame := -1
static var _active := true
static var _tactical := false

var kind := "vriend"
var model: SoldierModel
var _ring: MeshInstance3D
var _direction: MeshInstance3D
var _boost := 1.0


## Bepaalt voor elke frame één keer of de markeringen aan staan en of de camera in Tactisch staat.
static func _refresh(tree: SceneTree) -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	var cam := tree.root.get_viewport().get_camera_3d()
	_tactical = cam != null and not bool(cam.get("combat_view"))
	var mode: String = GameSettings.get_value("markeringen")
	_active = mode == "on" or (mode == "tact" and _tactical)
	for k in _rim_mats:
		(_rim_mats[k] as ShaderMaterial).set_shader_parameter("strength", 1.0 if _active else 0.0)


static func _rim(k: String) -> ShaderMaterial:
	if not _rim_mats.has(k):
		if _rim_shader == null:
			_rim_shader = Shader.new()
			_rim_shader.code = RIM_SHADER
		var m := ShaderMaterial.new()
		m.shader = _rim_shader
		m.set_shader_parameter("col", Color(1.0, 0.93, 0.7) * RIM_STRENGTH[k])
		_rim_mats[k] = m
	return _rim_mats[k]


## Zet de markering bij dit mannetje; kind volgt uit de look (speler, vijand of bondgenoot/wacht).
static func attach(m: SoldierModel) -> void:
	var s := SoldierMark.new()
	s.name = "SoldierMark"
	s.model = m
	s.kind = "speler" if m.look.begins_with("speler") else ("vijand" if m.look.begins_with("vijand") else "vriend")
	m.add_child(s)


func _ready() -> void:
	_make_ring()
	if kind == "speler":
		_make_direction()
	# randlicht als tweede laag op elk lichaamsdeel
	var rim := _rim(kind)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.get_surface_override_material(s)
			if src is StandardMaterial3D and src.next_pass == null:
				(src as StandardMaterial3D).next_pass = rim


func _make_ring() -> void:
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = RING_SHADER
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (0.46 if kind == "speler" else 0.6) * 2.0 / 0.9
	var mat := ShaderMaterial.new()
	mat.shader = _ring_shader
	mat.render_priority = 1
	mat.set_shader_parameter("col", Color(COLORS[kind], 0.52 if kind == "speler" else 0.85))
	_ring = MeshInstance3D.new()
	_ring.mesh = plane
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.05
	add_child(_ring)


func _make_direction() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.075, 0.01, 0.19)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.72, 0.35, 0.62)
	mesh.material = mat
	_direction = MeshInstance3D.new()
	_direction.mesh = mesh
	_direction.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_direction.position = Vector3(0.0, 0.065, 0.55)
	add_child(_direction)


func _process(_d: float) -> void:
	_refresh(get_tree())
	var body := model.get_parent()
	if body != null and body.get("dead") == true:
		if _ring != null:
			_ring.visible = false
		if _direction != null:
			_direction.visible = false
		_set_boost(1.0)
		return
	if _ring != null:
		_ring.visible = _active
	if _direction != null:
		_direction.visible = _active
	_set_boost(MODEL_BOOST if _active and _tactical else 1.0)


func _set_boost(b: float) -> void:
	if is_equal_approx(_boost, b) or model._model == null:
		return
	_boost = b
	(model._model as Node3D).scale = Vector3.ONE * b
