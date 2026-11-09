class_name McvFx
extends RefCounted
## Kleine effecten voor de bouwwagen en de opbouw van het hoofdkwartier (stofwolkjes).


## Een stofwolkje: zachte ronde kaartjes die opkomen, groeien en vervagen.
static func puff(parent: Node, pos: Vector3, size := 1.0, col := Color(0.62, 0.55, 0.44), amount := 9, rise := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.7
	p.explosiveness = 0.85
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.5 * rise
	p.initial_velocity_max = 1.7 * rise
	p.gravity = Vector3(0.0, 0.25, 0.0)
	p.damping_min = 0.8
	p.damping_max = 1.4
	p.scale_amount_min = size * 0.55
	p.scale_amount_max = size * 1.1
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.7))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	p.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Fx.soft()
	m.albedo_color = col
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
