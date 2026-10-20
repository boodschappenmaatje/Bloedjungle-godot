extends Camera3D
## Schuin van boven meekijkende camera (22-camera.js): staand scherm hoger, liggend dichterbij,
## en een stukje vooruit in de kijkrichting, verder als je richt.

var _lead := Vector3.ZERO
var _snap := true  # eerste beeld meteen op de speler, niet ernaartoe vliegen


func _ready() -> void:
	# lange lens en onscherpe verte: kijkt als een filmbeeld, niet als een kaart
	fov = 42.0
	far = 220.0
	var cam := CameraAttributesPractical.new()
	cam.dof_blur_far_enabled = true
	cam.dof_blur_far_distance = 36.0
	cam.dof_blur_far_transition = 55.0
	cam.dof_blur_amount = 0.07
	attributes = cam
	_dust()


## Stofdeeltjes die in het zonlicht zweven, meebewegend met de camera.
func _dust() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20, 6, 14)
	pm.direction = Vector3(0.6, 0.15, 0.2)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, -0.02, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.93, 0.75, 0.3)
	m.no_depth_test = false
	quad.material = m
	var pa := GPUParticles3D.new()
	pa.process_material = pm
	pa.draw_pass_1 = quad
	pa.amount = 140
	pa.lifetime = 9.0
	pa.preprocess = 9.0
	pa.local_coords = false
	pa.position = Vector3(0, -12, -14)
	pa.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	add_child(pa)


func _process(delta: float) -> void:
	var p = Game.player
	if p == null:
		return
	var size := get_viewport().get_visible_rect().size
	var portrait := size.x < size.y
	var h := 27.0 if portrait else 21.0
	var back := 19.5 if portrait else 17.0
	var aiming := not is_nan(Game.aim)
	var want := Vector3(sin(p.face), 0, cos(p.face)) * ((2.5 if portrait else 4.0) if aiming else 1.2)
	_lead = _lead.lerp(want, 1.0 - exp(-3.0 * delta))
	var target: Vector3 = p.global_position + _lead
	var goal := target + Vector3(0, h, back)
	global_position = goal if _snap else global_position.lerp(goal, minf(1.0, delta * 8.0))
	_snap = false
	look_at(global_position - Vector3(0, h, back), Vector3.UP)
