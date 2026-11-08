class_name M47Vfx
extends Node3D
## M-47 Muurbreker: schuss-effect (VFX 2.1 doelbeeld) in Godot, voor de Mobile-renderer.
## Eén voorgebouwde set (geen allocaties tijdens het schot): mondingsflits, projectiel met kern en ringen, spiraalrook,
## honingraat-schokgolf (shaders/m47_honingraat.gdshader), vonken, stof en een blauwe nagloed in de muuropening.
## Aanroep: fire(van, naar, muur) speelt het hele schot; muur is een M47Wall (optioneel).
## Kosten: vier textuurkaarten met blending, ~30 kleine kaartjes, één lamp zonder schaduw, alleen zolang het schot duurt.

signal impact(pos: Vector3)
signal klaar

const FLIGHT_SPEED := 26.0
const SPARKS := 32
const TRAIL := 26
const DUST := 14
const BLAUW := Color(0.15, 0.58, 1.0)
const WIT := Color(0.8, 0.94, 1.0)

static var _tex := {}

var _t := -1.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _dir := Vector3.RIGHT
var _flight := 0.2
var _wall: Node3D
var _impacted := false

var _flash: Sprite3D
var _flash2: Sprite3D
var _projectile: Node3D
var _core: MeshInstance3D
var _rings: Array[MeshInstance3D] = []
var _halo: Sprite3D
var _light: OmniLight3D
var _trail: Array[Sprite3D] = []
var _sparks: Array[MeshInstance3D] = []
var _spark_vel: Array[Vector3] = []
var _dust: Array[Sprite3D] = []
var _ring_wall: MeshInstance3D
var _ring_ground: MeshInstance3D
var _wall_mat: ShaderMaterial
var _ground_mat: ShaderMaterial
var _burst: Sprite3D
var _burst_glow: Sprite3D


func _ready() -> void:
	_build()


## Procedurele kaartjes: ster (flits) en zachte gloed. Geen extra bestanden nodig.
static func _make_flare() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var r := p.length()
			var a := atan2(p.y, p.x)
			var spikes := pow(absf(cos(a * 2.0)), 22.0) * 0.9 + pow(absf(cos(a * 2.0 + 0.7)), 40.0) * 0.45
			var v := exp(-r * r * 22.0) + spikes * exp(-r * 3.2) * 0.9 + exp(-r * 2.6) * 0.18
			v = clampf(v, 0.0, 1.0) * clampf((1.0 - r) * 5.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, v))
	return ImageTexture.create_from_image(img)


static func _make_glow() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			var v := clampf(pow(1.0 - clampf(r, 0.0, 1.0), 2.4), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, v))
	return ImageTexture.create_from_image(img)


static func textures() -> Dictionary:
	if _tex.is_empty():
		_tex["flare"] = _make_flare()
		_tex["glow"] = _make_glow()
		_tex["sliert"] = load("res://assets/m47/rook_sliert.png")
		_tex["stof"] = load("res://assets/m47/rook_stof.png")
	return _tex


func _additive(tex: Texture2D, tint: Color, billboard := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.albedo_color = tint
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.disable_receive_shadows = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return m


func _sprite(tex: Texture2D, tint: Color, size: float, additive := true) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = size / float(tex.get_width())
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.double_sided = true
	s.transparent = true
	s.modulate = tint
	s.visible = false
	if additive:
		s.material_override = _additive(tex, tint)
	add_child(s)
	return s


func _flip_sprite(tex: Texture2D, tint: Color, size: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.hframes = 4
	s.vframes = 4
	s.pixel_size = size / 192.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.double_sided = true
	s.transparent = true
	s.modulate = tint
	s.visible = false
	add_child(s)
	return s


func _build() -> void:
	var t := textures()
	_flash = _sprite(t["flare"], Color(0.7, 0.9, 1.0, 1.0), 1.1)
	_flash2 = _sprite(t["glow"], Color(0.1, 0.45, 1.0, 1.0), 0.8)
	_projectile = Node3D.new()
	_projectile.visible = false
	add_child(_projectile)
	var sm := SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	sm.radial_segments = 12
	sm.rings = 6
	_core = MeshInstance3D.new()
	_core.mesh = sm
	_core.material_override = _emissive(Color(0.65, 0.9, 1.0), 4.0)
	_projectile.add_child(_core)
	for i in 2:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.2 + i * 0.07
		tm.outer_radius = 0.235 + i * 0.07
		tm.rings = 16
		tm.ring_segments = 6
		var r := MeshInstance3D.new()
		r.mesh = tm
		r.material_override = _emissive(BLAUW, 3.0)
		r.rotation.z = PI * 0.5
		_projectile.add_child(r)
		_rings.append(r)
	_halo = _sprite(t["glow"], Color(0.15, 0.55, 1.0, 1.0), 1.3)
	_halo.reparent(_projectile, false)
	_halo.visible = true
	_light = OmniLight3D.new()
	_light.light_color = Color(0.3, 0.62, 1.0)
	_light.omni_range = 7.0
	_light.shadow_enabled = false
	_light.light_energy = 0.0
	add_child(_light)
	for i in TRAIL:
		_trail.append(_flip_sprite(t["sliert"], Color(0.7, 0.86, 1.0, 0.0), 2.2))
	for i in DUST:
		_dust.append(_flip_sprite(t["stof"], Color(0.62, 0.62, 0.64, 0.0), 3.0))
	var spm := QuadMesh.new()
	spm.size = Vector2(0.05, 0.05)
	for i in SPARKS:
		var s := MeshInstance3D.new()
		s.mesh = spm
		s.material_override = _additive(t["glow"], Color(1.0, 0.62, 0.3, 1.0))
		s.visible = false
		add_child(s)
		_sparks.append(s)
		_spark_vel.append(Vector3.ZERO)
	var shader := load("res://shaders/m47_honingraat.gdshader") as Shader
	var qm := QuadMesh.new()
	qm.size = Vector2(4.4, 4.4)
	_wall_mat = ShaderMaterial.new()
	_wall_mat.shader = shader
	_ring_wall = MeshInstance3D.new()
	_ring_wall.mesh = qm
	_ring_wall.material_override = _wall_mat
	_ring_wall.visible = false
	add_child(_ring_wall)
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = shader
	_ground_mat.set_shader_parameter("intensiteit", 1.2)
	_ring_ground = MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(4.6, 4.6)
	_ring_ground.mesh = gq
	_ring_ground.rotation.x = -PI * 0.5
	_ring_ground.material_override = _ground_mat
	_ring_ground.visible = false
	add_child(_ring_ground)
	_burst = _sprite(t["flare"], Color(1, 1, 1, 1), 3.4)
	_burst_glow = _sprite(t["glow"], Color(0.1, 0.5, 1.0, 1.0), 3.8)


func _emissive(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * e
	return m


## Speelt het hele schot. van = monding, naar = inslagpunt (op de muur), muur = Node met begin_breuk() (optioneel).
func fire(van: Vector3, naar: Vector3, muur: Node3D = null) -> void:
	_from = van
	_to = naar
	_wall = muur
	_dir = (naar - van).normalized()
	_flight = maxf(0.12, van.distance_to(naar) / FLIGHT_SPEED)
	_impacted = false
	_t = 0.0
	for s in _trail:
		s.visible = false
	for s in _dust:
		s.visible = false
	_ring_wall.visible = false
	_ring_ground.visible = false
	for i in SPARKS:
		_sparks[i].visible = false
		var up := Vector3(randf_range(-1, 1), randf_range(0.2, 1.4), randf_range(-1, 1))
		_spark_vel[i] = (-_dir * randf_range(1.5, 5.0) + up * randf_range(0.8, 3.0))
	set_process(true)


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var t := _t
	# 1. Mondingsflits (0 - 0.16 s)
	var fl := clampf(1.0 - t / 0.16, 0.0, 1.0)
	_flash.visible = fl > 0.0
	_flash.global_position = _from
	_flash.scale = Vector3.ONE * (0.45 + 0.6 * (1.0 - fl))
	_flash.modulate.a = fl
	_flash.rotation.z = t * 6.0
	_flash2.visible = fl > 0.0
	_flash2.global_position = _from
	_flash2.modulate.a = fl * 0.55
	# 2. Projectiel (vanaf 0.05 s)
	var f := clampf((t - 0.05) / _flight, 0.0, 1.0)
	var vliegt := t >= 0.05 and not _impacted
	_projectile.visible = vliegt
	if vliegt:
		_projectile.global_position = _from.lerp(_to, f)
		_projectile.look_at(_projectile.global_position + _dir, Vector3.UP)
		for i in _rings.size():
			_rings[i].rotation.z = t * (11.0 + i * 7.0) * (1 if i == 0 else -1)
		_light.global_position = _projectile.global_position
		_light.light_energy = 3.2
	# Spoorrook: kaartjes blijven achter op de baan en draaien er in een spiraal omheen.
	for i in TRAIL:
		var ph := float(i) / TRAIL
		var leeftijd := t - 0.05 - ph * _flight   # elk kaartje blijft achter op de plek waar het projectiel was
		var s := _trail[i]
		var baan := ph
		var ok := leeftijd > 0.0 and leeftijd < 2.0
		s.visible = ok
		if ok:
			var hoek := leeftijd * 14.0 + i * 0.9
			var zij := _dir.cross(Vector3.UP).normalized()
			var op := zij * cos(hoek) + Vector3.UP * sin(hoek)
			var uitslag := 0.22 + leeftijd * 0.42
			s.global_position = _from.lerp(_to, baan) + op * uitslag
			s.frame = mini(15, 3 + int(leeftijd * 6.0))
			s.modulate.a = 0.95 * clampf(leeftijd * 8.0, 0.0, 1.0) * clampf((2.0 - leeftijd) / 1.0, 0.0, 1.0)
	# 3. Inslag
	if t >= 0.05 + _flight and not _impacted:
		_impacted = true
		_projectile.visible = false
		impact.emit(_to)
		if _wall != null and _wall.has_method("begin_breuk"):
			_wall.begin_breuk()
		for i in SPARKS:
			_sparks[i].global_position = _to
		var wn := -_dir
		_ring_wall.global_position = _to + wn * 0.07
		_ring_wall.look_at(_ring_wall.global_position + wn, Vector3.UP)
		_ring_ground.global_position = Vector3(_to.x - _dir.x * 0.2, 0.06, _to.z - _dir.z * 0.2)
		_ring_wall.visible = true
		_ring_ground.visible = true
		var zij2 := _dir.cross(Vector3.UP).normalized()
		for i in DUST:
			var d := _dust[i]
			d.global_position = Vector3(_to.x, 0.0, _to.z) + wn * randf_range(0.2, 2.2) + zij2 * randf_range(-2.2, 2.2) + Vector3(0, randf_range(0.6, 1.9), 0)
	if _impacted:
		var a := t - (0.05 + _flight)
		_light.global_position = _to - _dir * 0.5
		_light.light_energy = 6.0 * clampf(1.0 - a / 0.3, 0.0, 1.0) + 1.4 * clampf(1.0 - a / 1.6, 0.0, 1.0)
		var b := clampf(1.0 - a / 0.3, 0.0, 1.0)
		_burst.visible = b > 0.0
		_burst.global_position = _to - _dir * 0.3
		_burst.modulate.a = b
		_burst.scale = Vector3.ONE * (0.8 + (1.0 - b) * 0.9)
		_burst_glow.visible = a < 0.9
		_burst_glow.global_position = _to - _dir * 0.4
		_burst_glow.modulate.a = clampf(1.0 - a / 0.9, 0.0, 1.0) * 0.9
		var p := clampf(a / 1.1, 0.0, 1.0)
		_wall_mat.set_shader_parameter("voortgang", p)
		_ground_mat.set_shader_parameter("voortgang", clampf(a / 1.3, 0.0, 1.0))
		_ring_wall.visible = p < 1.0
		_ring_ground.visible = a < 1.3
		for i in SPARKS:
			var s := _sparks[i]
			s.visible = a < 0.9
			_spark_vel[i].y -= 9.0 * delta
			s.global_position += _spark_vel[i] * delta
			if s.global_position.y < 0.03:
				s.global_position.y = 0.03
				_spark_vel[i] = Vector3.ZERO
		for i in DUST:
			var da := a - i * 0.03
			var d := _dust[i]
			d.visible = da > 0.0 and da < 3.4
			if d.visible:
				d.frame = mini(15, int(da * 5.0))
				d.global_position += (Vector3(-_dir.x, 0.25, -_dir.z) * 0.55 + Vector3(sin(i * 2.1), 0, cos(i * 2.1)) * 0.35) * delta
				d.modulate.a = 0.55 * clampf(da * 5.0, 0.0, 1.0) * clampf((3.4 - da) / 1.6, 0.0, 1.0)
		if a > 3.5:
			_t = -1.0
			_light.light_energy = 0.0
			set_process(false)
			klaar.emit()
