class_name Vliegtuig
extends Node3D
## Bestuurbaar vliegtuig bij het vliegveld (stap 1: vliegen en landen; schieten volgt in stap 2).
##
## Besturing (afspraak met Dennis, 1 november):
##  - linkerstick = richting; afstand tot het midden = snelheid; stick los = doorvliegen met minimumsnelheid;
##  - rechterstick = hoogte: naar beneden trekken = stijgen, omhoog duwen = dalen (Instellingen > Vliegtuig: hoogte kan omgekeerd);
##  - opstijgen vanaf de baan: gas geven tot ~13 m/s en de rechterstick naar beneden;
##  - laag (onder ~2 m) boven het asfalt en langzaam genoeg: automatisch landen, uitrollen en terug naar de hangar;
##  - tegen een gebouw, muur of boom aan vliegen: neerstorten met ontploffing, net als de auto's.
## Op een pc: WASD/pijlen = richting, Q = stijgen, E = dalen.
## Het model staat in MODEL_PATH en is zo te verwisselen (Meshy-toestel): pas ook MODEL_SCALE en MODEL_YAW aan.

enum Mode { PARKED, GROUND, AIR, ROLLOUT, TAXI, WRECK }

const MODEL_PATH := "res://assets/straaljager.glb"   # plaatsvervanger tot Dennis' Meshy-toestel er is
const MODEL_SCALE := 0.62                             # straaljager is op schaal 1 ~16 m: zo past hij in de hangar
const MODEL_YAW := 0.0                                # de neus van het model kijkt naar -Z
const FLY_CLIP := "Vliegen"

const MAX_SPEED := 30.0        # m/s bij helemaal doorgeduwde stick
const MIN_AIR := 14.0          # m/s: stick los in de lucht
const LIFTOFF := 13.0          # m/s: sneller dan dit kan de neus omhoog
const LAND_MAX := 18.0         # m/s: langzamer dan dit kan hij landen
const ACCEL := 7.0
const BRAKE := 9.0
const TURN_AIR := 1.7          # rad/s
const TURN_GROUND := 1.1
const CLIMB_RATE := 8.0        # m/s
const MAX_ALT := 24.0
const MIN_FLY_ALT := 1.6       # laagste vlieghoogte boven de grond
const LAND_ALT := 2.2          # lager dan dit boven asfalt (en langzaam) = landen
const TREE_TOP := 8.0          # boven deze hoogte vlieg je over de bomen
const CRASH_R := 1.7
const TAXI_SPEED := 6.0
const BOARD_DIST := 5.0
const PAVEMENT_Y := 0.22
const DEADZONE := 0.15
const BLAST_RADIUS := 11.0
const BLAST_HURT := 420.0

static var driven_plane: Vliegtuig   # het toestel waar de speler nu in zit

var override_move: Variant = null     # alleen voor tests: Vector2 i.p.v. de linkerstick
var override_climb: Variant = null    # alleen voor tests: float i.p.v. de rechterstick

var mode := Mode.PARKED
var driven := false
var speed := 0.0
var alt := 0.0                 # hoogte boven de grond (m)
var climb := 0.0               # laatste hoogte-invoer -1..1 (voor tests en de hoogtemeter)
var airfield: Dictionary       # het bouwstuk uit Buildings (b.node, b.at, b.yaw, ...)
var complex: Node3D            # de vliegveldscène (voor pavement en taxiroute)
var home: Transform3D          # parkeerplek (wereld)
var exploded := false
var _model: Node3D
var _meter: Control
var _trails: Array[CPUParticles3D] = []
var _bar_bg: ColorRect
var _bar: ColorRect
var _hint: Label
var _lbl_left: Label
var _lbl_right: Label
var _hint_t := 0.0
static var _sticks_seen := 0   # stick-labels tonen we de eerste twee vluchten
var _wrap: Node3D
var _anim: AnimationPlayer
var _shadow: MeshInstance3D
var _shadow_mat: ShaderMaterial
var _btn: ActionBtn
var _layer: CanvasLayer
var _info: Label
var _route: Array[Vector3] = []
var _hint_low := false
var _t := 0.0
var _bank := 0.0
var _pitch := 0.0
var _span := 12.0
var _len := 12.0
var _hangar_fit := false
var _tree_t := 0.0

const SHADOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.5;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float body = (1.0 - smoothstep(0.05, 0.16, abs(p.x))) * (1.0 - smoothstep(0.8, 1.0, abs(p.y)));
	float wing = (1.0 - smoothstep(0.1, 0.22, abs(p.y + 0.1 - abs(p.x) * 0.25))) * (1.0 - smoothstep(0.8, 1.0, abs(p.x)));
	float tail = (1.0 - smoothstep(0.05, 0.12, abs(p.y - 0.82))) * (1.0 - smoothstep(0.3, 0.42, abs(p.x)));
	ALBEDO = vec3(0.0);
	ALPHA = clamp(max(body, max(wing, tail)), 0.0, 1.0) * strength;
}
"""
static var _shadow_shader: Shader


## Zet een toestel op de parkeerplek van het vliegveld. b = het vliegveldbouwstuk.
static func spawn(b: Dictionary) -> Vliegtuig:
	var cx: Node3D = b.node.get_meta("complex") if b.node.has_meta("complex") else null
	if cx == null:
		return null
	var v := Vliegtuig.new()
	v.airfield = b
	v.complex = cx
	b.node.get_parent().add_child(v)
	v.home = v._park_transform()
	v.global_transform = v.home
	return v


func _ready() -> void:
	set_physics_process(false)
	process_priority = -50   # eerst het toestel, dan de camera die hem volgt
	_wrap = Node3D.new()
	add_child(_wrap)
	var packed := load(MODEL_PATH) as PackedScene
	if packed != null:
		_model = packed.instantiate()
		_model.scale = Vector3.ONE * MODEL_SCALE
		_model.rotation.y = MODEL_YAW
		_wrap.add_child(_model)
		_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _anim != null:
			_anim.stop()
		_measure()
		_strip_lights(_model)
	_make_shadow()
	_make_trails()
	_make_ui()
	_set_shadow()
	_hangar_fit = _span <= AirfieldFlightIntegration.DOOR_CLEAR_WIDTH_M - 2.5 and _len <= AirfieldFlightIntegration.INTERIOR_CLEAR_LENGTH_M - 0.5
	add_to_group("vliegtuigen")


func _exit_tree() -> void:
	if driven_plane == self:
		driven_plane = null
		Sfx.jet_off()


## Spanwijdte en lengte van het model (voor schaduw en hangar-check).
func _measure() -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var to_wrap := _wrap.global_transform.affine_inverse() * mi.global_transform if _wrap.is_inside_tree() else Transform3D.IDENTITY
		var bb := mi.get_aabb()
		for i in 8:
			var q := to_wrap * bb.get_endpoint(i)
			lo = lo.min(q)
			hi = hi.max(q)
	if lo.x < INF:
		_span = hi.x - lo.x
		_len = hi.z - lo.z
		# onderkant op de grond zetten
		_model.position.y -= lo.y


## Lampen uit een Blender-export zijn in Godot gigantisch (zie vliegveld-HQ2.3-les): weghalen.
func _strip_lights(n: Node) -> void:
	for l in n.find_children("*", "Light3D", true, false):
		l.queue_free()


func _make_shadow() -> void:
	if _shadow_shader == null:
		_shadow_shader = Shader.new()
		_shadow_shader.code = SHADOW_SHADER
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = _shadow_shader
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.0, 1.0)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = pm
	_shadow.material_override = _shadow_mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


## Lichte condensstrepen achter de vleugelpunten: geven snelheid en richting, en blijven in de wereld achter (local_coords uit).
func _make_trails() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 0.5)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	for side in [-1.0, 1.0]:
		var t := CPUParticles3D.new()
		t.mesh = quad
		t.amount = 40
		t.lifetime = 1.1
		t.local_coords = false
		t.emitting = false
		t.direction = Vector3.ZERO
		t.spread = 0.0
		t.initial_velocity_min = 0.0
		t.initial_velocity_max = 0.0
		t.gravity = Vector3.ZERO
		t.color_ramp = fade
		t.scale_amount_min = 0.6
		t.scale_amount_max = 1.0
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.position = Vector3(side * maxf(_span, 4.0) * 0.45, 0.3, maxf(_len, 6.0) * 0.12)
		_wrap.add_child(t)
		_trails.append(t)


func _make_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_btn = ActionBtn.make("enter", "IN")
	_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_btn.offset_left = ActionBtn.slot_x(2)
	_btn.offset_right = ActionBtn.slot_x(2) + ActionBtn.SIZE.x
	_btn.offset_top = -126.0
	_btn.offset_bottom = -126.0 + ActionBtn.SIZE.y
	_btn.pressed.connect(_press)
	_layer.add_child(_btn)
	_btn.hide()
	# Meter onderaan tussen de sticks (niet meer over de golf-knoppen bovenin): hoogte met balk, snelheid, korte hint.
	_meter = Control.new()
	_meter.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_meter.offset_left = -130.0
	_meter.offset_right = 130.0
	_meter.offset_top = -92.0
	_meter.offset_bottom = -20.0
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.hide()
	_layer.add_child(_meter)
	_info = Label.new()
	_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_info.offset_bottom = 22.0
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 15)
	_info.add_theme_color_override("font_color", Color(UI.INK, 0.95))
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 4)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(_info)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0, 0, 0, 0.55)
	_bar_bg.position = Vector2(20.0, 26.0)
	_bar_bg.size = Vector2(220.0, 7.0)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(UI.BRASS, 0.95)
	_bar.position = Vector2(1.0, 1.0)
	_bar.size = Vector2(0.0, 5.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.add_child(_bar)
	_hint = Label.new()
	_hint.position = Vector2(-60.0, 38.0)
	_hint.size = Vector2(380.0, 30.0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(UI.INK, 0.9))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(_hint)
	# Stick-labels bij de eerste vluchten
	_lbl_left = _stick_label("GAS + RICHTING", true)
	_lbl_right = _stick_label("HOOGTE: omlaag = stijgen", false)


func _stick_label(txt: String, left: bool) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(UI.INK, 0.95))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if left else Control.PRESET_BOTTOM_RIGHT)
	if left:
		l.offset_left = 40.0
		l.offset_top = -205.0
	else:
		l.offset_left = -230.0
		l.offset_right = -30.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.offset_top = -205.0
	l.hide()
	_layer.add_child(l)
	return l


# ------------------------------------------------------------------ plaats en grond

## Parkeerplek: in de hangar als het toestel erin past, anders op het platform ervoor.
func _park_transform() -> Transform3D:
	var local := Vector3(0.0, PAVEMENT_Y, 0.0) if _hangar_fit else AirfieldHQ23.layout_point(AirfieldHQ23.APRON_CENTER.x, AirfieldHQ23.APRON_CENTER.y, PAVEMENT_Y)
	return complex.global_transform * Transform3D(Basis.IDENTITY, local)


## Vliegveldcoördinaten (zoals AirfieldHQ23.layout_point ze omzet) van een wereldpunt.
func _airport_xy(world: Vector3) -> Vector2:
	var l := complex.to_local(world)
	return Vector2(l.x + AirfieldHQ23.COMPLEX_CENTER_OFFSET.x, l.z + AirfieldHQ23.COMPLEX_CENTER_OFFSET.z)


func _world_of(ax: float, az: float) -> Vector3:
	return complex.to_global(AirfieldHQ23.layout_point(ax, az, PAVEMENT_Y))


## Ligt dit punt op asfalt (baan, platform of taxibaan)? Alleen daar kun je landen.
func on_pavement(world: Vector3) -> bool:
	if complex == null or not is_instance_valid(complex):
		return false
	var a := _airport_xy(world)
	if absf(a.x - (AirfieldHQ23.RUNWAY_START_X + AirfieldHQ23.RUNWAY_END_X) * 0.5) <= AirfieldHQ23.RUNWAY_LENGTH_M * 0.5 \
			and absf(a.y - AirfieldHQ23.RUNWAY_CENTER_Z) <= AirfieldHQ23.RUNWAY_WIDTH_M * 0.5:
		return true
	if absf(a.x - AirfieldHQ23.APRON_CENTER.x) <= 9.0 and absf(a.y - AirfieldHQ23.APRON_CENTER.y) <= 7.0:
		return true
	var pts := AirfieldHQ23.taxi_centerline_points()
	for i in range(pts.size() - 1):
		var c := Geometry2D.get_closest_point_to_segment(a, pts[i], pts[i + 1])
		if c.distance_to(a) <= AirfieldHQ23.TAXIWAY_WIDTH_M * 0.5:
			return true
	return false


func ground_y(world: Vector3) -> float:
	return PAVEMENT_Y if on_pavement(world) else 0.0


# ------------------------------------------------------------------ in- en uitstappen

func _press() -> void:
	var p = Game.player
	if p == null or p.dead:
		return
	if not driven:
		_board(p)
	elif mode == Mode.GROUND and speed < 1.5:
		_leave(p, false)


func _board(p) -> void:
	if driven_plane != null and is_instance_valid(driven_plane):
		return
	driven = true
	driven_plane = self
	_hint_t = 9.0
	_sticks_seen += 1
	mode = Mode.GROUND
	speed = 0.0
	alt = 0.0
	p.driving = true
	p.airborne = true
	p.visible = false
	p.collision_mask = 0
	p.velocity = Vector3.ZERO
	add_to_group("voertuigen")   # de hangardeuren gaan open voor rijdende toestellen
	_play_clip(true)
	Sfx.jet_on()
	Sfx.play("click")
	Game.banner.emit("VLIEGTUIG", "Links: sturen en snelheid · rechts omlaag: stijgen", 3.5)


func _leave(p, auto: bool) -> void:
	driven = false
	if driven_plane == self:
		driven_plane = null
	Sfx.jet_off()
	if is_in_group("voertuigen") and mode != Mode.WRECK:
		remove_from_group("voertuigen")
	if p != null:
		p.driving = false
		p.airborne = false
		p.visible = true
		var out: Vector3
		if mode == Mode.PARKED and _hangar_fit:
			out = complex.to_global(Vector3(0.0, 0.0, 11.5))   # voor de hangardeur
		else:
			out = global_position + global_transform.basis.x * (_span * 0.5 + 2.0)
		p.global_position = Vector3(out.x, 0.0, out.z)
		p.collision_mask = p.get("_mask0")
	if auto:
		Game.banner.emit("GELAND", "Toestel staat in de hangar", 2.0)
	_play_clip(false)


func _play_clip(on: bool) -> void:
	if _anim == null:
		return
	if on and _anim.has_animation(FLY_CLIP):
		_anim.play(FLY_CLIP)
	elif not on:
		_anim.stop()


# ------------------------------------------------------------------ invoer

func _altitude_input() -> float:
	if override_climb != null:
		return float(override_climb)
	var v := 0.0
	var d: float = TouchSticks.aim_d.y     # + = stick omlaag
	if absf(d) > DEADZONE:
		v = signf(d) * (absf(d) - DEADZONE) / (1.0 - DEADZONE)
		if GameSettings.get_value("vliegtuig_hoogte") == "omgekeerd":
			v = -v
	if Input.is_physical_key_pressed(KEY_Q):
		v = 1.0
	elif Input.is_physical_key_pressed(KEY_E):
		v = -1.0
	return clampf(v, -1.0, 1.0)


# ------------------------------------------------------------------ fysica

## Het toestel rekent in elk getekend beeld (niet in de 60-Hz physics-tik): de camera loopt ook per beeld, en een toestel dat op 120 Hz
## beeld maar 60 keer per seconde stapt (30 m/s = 0,5 m per stap) schokt ten opzichte van de camera, ook bij hoge fps.
## De stap is begrensd zodat een haperend beeld geen sprong geeft.
func _process(delta: float) -> void:
	_step(minf(delta, 0.05))


func _step(delta: float) -> void:
	_t += delta
	_hint_t = maxf(0.0, _hint_t - delta)
	var live: bool = Game.state == "play" or Game.state == "prep"
	var p = Game.player
	if driven and (p == null or p.dead):
		if mode == Mode.AIR:
			crash()
		else:
			_leave(p, false)
	match mode:
		Mode.GROUND:
			_ground(delta, live)
		Mode.AIR:
			_air(delta, live)
		Mode.ROLLOUT:
			_rollout(delta)
		Mode.TAXI:
			_taxi(delta)
		Mode.PARKED, Mode.WRECK:
			pass
	if driven and p != null and mode != Mode.WRECK:
		p.global_position = Vector3(global_position.x, 0.0, global_position.z)
		p.face = rotation.y + PI
		var thrust := clampf(speed / MAX_SPEED, 0.0, 1.0)
		Sfx.jet_set(0.35 + 0.5 * thrust, 0.8 + 0.6 * thrust)
	_visuals(delta)
	_update_ui(p, live)


## Stick -> gewenste koers en snelheid. Geeft (heading_target or NAN, mag).
func _stick() -> Vector2:
	return override_move if override_move != null else Game.move


func _steer(delta: float, rate: float, mv: Vector2) -> void:
	if mv.length() < 0.12:
		return
	var want := atan2(-mv.x, -mv.y)   # stick omhoog = noord (-Z) = koers 0
	var diff := wrapf(want - rotation.y, -PI, PI)
	var turn := clampf(diff, -rate * delta, rate * delta)
	rotation.y += turn
	_bank = lerpf(_bank, clampf(turn / maxf(delta, 0.001) * 0.45, -0.9, 0.9), minf(1.0, delta * 5.0))


func _forward() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))


func _move_flat(delta: float) -> bool:
	## Beweegt vooruit; geeft false als de wereldrand de weg blokkeert.
	var f := _forward()
	global_position += f * speed * delta
	var flat := Vector2(global_position.x, global_position.z)
	var clamped := Data.clamp_world(flat)
	if clamped != flat:
		global_position = Vector3(clamped.x, global_position.y, clamped.y)
		# langs de rand: draai het toestel zachtjes naar het midden
		var to_c := atan2(global_position.x, global_position.z)
		rotation.y += clampf(wrapf(to_c - rotation.y, -PI, PI), -1.2 * delta, 1.2 * delta)
		return false
	return true


func _ground(delta: float, live: bool) -> void:
	var mv: Vector2 = _stick() if (driven and live) else Vector2.ZERO
	var mag := clampf(mv.length(), 0.0, 1.0)
	var target := 0.0 if mag < 0.12 else mag * MAX_SPEED
	if mag >= 0.12:
		# eerst de neus naar de stick draaien: staat de stick ver naast de koers, dan maar stapvoets (draaien op de plaats)
		var off := absf(wrapf(atan2(-mv.x, -mv.y) - rotation.y, -PI, PI))
		if off > 0.8:
			target = minf(target, 3.0)
	speed = move_toward(speed, target, (ACCEL if target > speed else BRAKE) * delta)
	if mag >= 0.12:
		_steer(delta, TURN_GROUND * clampf(0.5 + speed / 6.0, 0.5, 1.0), mv)
	else:
		_bank = lerpf(_bank, 0.0, minf(1.0, delta * 5.0))
	var before := global_position
	_move_flat(delta)
	if _blocked(0.9, 1.2):
		global_position = before
		speed = 0.0
	climb = _altitude_input() if (driven and live) else 0.0
	global_position.y = ground_y(global_position)
	alt = 0.0
	if climb > 0.2 and speed >= LIFTOFF:
		mode = Mode.AIR
		alt = 0.4
		Game.banner.emit("OPGESTEGEN", "", 1.0)


func _air(delta: float, live: bool) -> void:
	var mv: Vector2 = _stick() if (driven and live) else Vector2.ZERO
	var mag := clampf(mv.length(), 0.0, 1.0)
	var target := MIN_AIR if mag < 0.12 else lerpf(MIN_AIR, MAX_SPEED, mag)
	speed = move_toward(speed, target, (ACCEL if target > speed else BRAKE * 0.5) * delta)
	_steer(delta, TURN_AIR, mv)
	_move_flat(delta)
	climb = _altitude_input() if (driven and live) else 0.0
	var floor_alt := 0.0
	var gy := ground_y(global_position)
	var pave := gy > 0.0
	alt = clampf(alt + climb * CLIMB_RATE * delta, 0.0, MAX_ALT)
	# landen: laag, langzaam en boven asfalt; anders blijft hij op minimale vlieghoogte
	if alt < LAND_ALT and pave and speed <= LAND_MAX and climb <= 0.1:
		alt = move_toward(alt, 0.0, 3.0 * delta)
		if alt <= 0.02:
			_touchdown()
			return
	else:
		floor_alt = MIN_FLY_ALT
		if alt < floor_alt:
			alt = floor_alt
			if not pave and not _hint_low and climb < -0.2:
				_hint_low = true
				Game.banner.emit("LANDEN", "Alleen op het vliegveld (asfalt) en langzaam", 2.2)
	global_position.y = gy + alt
	_pitch = lerpf(_pitch, clampf(climb * 0.32, -0.4, 0.4), minf(1.0, delta * 4.0))
	_tree_t -= delta
	var tree_hit := false
	if alt < TREE_TOP and _tree_t <= 0.0:
		_tree_t = 0.07
		tree_hit = Foliage.has_tree_near(global_position.x, global_position.z, 3.0)
	if tree_hit or _blocked(CRASH_R, 0.0):
		crash()


func _touchdown() -> void:
	mode = Mode.ROLLOUT
	alt = 0.0
	global_position.y = ground_y(global_position)
	Sfx.play("thud", 0.6, global_position)
	Fx.dust(get_parent(), global_position)
	add_to_group("voertuigen")
	Game.banner.emit("GELANDEN", "", 1.2)


func _rollout(delta: float) -> void:
	speed = move_toward(speed, 0.0, 5.5 * delta)
	_bank = lerpf(_bank, 0.0, minf(1.0, delta * 4.0))
	_pitch = lerpf(_pitch, 0.0, minf(1.0, delta * 4.0))
	var before := global_position
	_move_flat(delta)
	if _blocked(0.9, 1.2) or not on_pavement(global_position):
		global_position = before
		speed = 0.0
	global_position.y = ground_y(global_position)
	if speed <= 0.05:
		speed = 0.0
		_start_taxi()


## Route terug naar de hangar: via de baan-aansluiting en de taxibaan naar het platform, de hangar in.
func _start_taxi() -> void:
	mode = Mode.TAXI
	var pts := AirfieldHQ23.taxi_centerline_points()
	var path: Array[Vector2] = [Vector2(AirfieldHQ23.TAXI_RUNWAY_END.x, AirfieldHQ23.RUNWAY_CENTER_Z + 2.0)]
	for i in range(pts.size() - 1, -1, -1):
		path.append(pts[i])
	path.append(AirfieldHQ23.APRON_CENTER)
	if _hangar_fit:
		path.append(Vector2(0.0, AirfieldHQ23.HANGAR_CENTER.y + 8.0))
		path.append(Vector2(0.0, AirfieldHQ23.HANGAR_CENTER.y))
	var here := _airport_xy(global_position)
	var best := 0
	var best_d := INF
	for i in path.size():
		var d := here.distance_to(path[i])
		if d < best_d:
			best_d = d
			best = i
	# staan we al voorbij het eerste punt (op de taxibaan), dan niet terug naar de baan
	_route.clear()
	for i in range(best, path.size()):
		_route.append(_world_of(path[i].x, path[i].y))


func _taxi(delta: float) -> void:
	if _route.is_empty():
		_park()
		return
	var tgt := _route[0]
	var to := Vector3(tgt.x - global_position.x, 0.0, tgt.z - global_position.z)
	var d := to.length()
	var last := _route.size() == 1
	if d < (0.6 if last else 3.0):
		_route.pop_front()
		return
	var want := atan2(-to.x, -to.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	var turn := clampf(diff, -1.3 * delta, 1.3 * delta)
	rotation.y += turn
	_bank = lerpf(_bank, 0.0, minf(1.0, delta * 4.0))
	var v_goal := TAXI_SPEED * (0.45 if absf(diff) > 0.6 else 1.0)
	if last:
		v_goal = clampf(d * 1.2, 1.5, TAXI_SPEED)
	speed = move_toward(speed, v_goal, 4.0 * delta)
	global_position += _forward() * speed * delta
	global_position.y = PAVEMENT_Y if on_pavement(global_position) or _inside_hangar() else 0.0


func _inside_hangar() -> bool:
	var l := complex.to_local(global_position)
	return absf(l.x) < 10.5 and absf(l.z) < 10.5


func _park() -> void:
	speed = 0.0
	mode = Mode.PARKED
	if is_in_group("voertuigen"):
		remove_from_group("voertuigen")
	var p = Game.player
	if driven:
		_leave(p, true)
	home = global_transform


## Raakt het toestel op deze hoogte iets (muur, bunker, voertuig)? lift = hoogte van het midden boven de grond.
func _blocked(radius: float, lift: float) -> bool:
	if not is_inside_tree():
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, lift + 0.4, 0.0))
	q.collision_mask = 2 | 16 | 32
	q.collide_with_areas = false
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# ------------------------------------------------------------------ neerstorten

func crash() -> void:
	if exploded:
		return
	exploded = true
	var at := global_position + Vector3(0, 0.8, 0)
	var parent := get_parent()
	var p = Game.player
	var was_driven := driven
	if driven:
		_leave(p, false)
		if p != null:
			p.global_position = Vector3(at.x + 2.5, 0.0, at.z + 2.5)
	mode = Mode.WRECK
	speed = 0.0
	if is_in_group("voertuigen"):
		remove_from_group("voertuigen")
	Game.note_blast(at, BLAST_RADIUS)
	# A crash is a ground explosion and obeys fortification splash occlusion;
	# normal aircraft overflight and overhead attacks keep their existing rules.
	Barrel.area_damage(at, BLAST_RADIUS, BLAST_HURT)
	Barrel.catch_blast(at, BLAST_RADIUS)
	Game.alert(at, 70.0, 10.0)
	Fx.explosion(parent, at, 2.2, Fx.CHUNKS_BARREL)
	get_tree().create_timer(0.16).timeout.connect(func():
		if is_instance_valid(parent):
			Fx.explosion(parent, at + Vector3(randf_range(-1.5, 1.5), 0.3, randf_range(-1.5, 1.5)), 1.5, Fx.CHUNKS_GROUND))
	Sfx.play("boom", 1.0, at)
	var cam: Camera3D = null
	if p != null and is_instance_valid(p):
		cam = p.get_parent().get_node_or_null("Camera") as Camera3D
	if cam != null and cam.has_method("combat_impulse"):
		cam.call("combat_impulse", 0.08)
	# wrak: zwart, scheef, op de grond, brandend
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.045, 0.04)
	dark.roughness = 1.0
	if _model != null:
		for n in _model.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).material_override = dark
	if _anim != null:
		_anim.stop()
	global_position.y = ground_y(global_position)
	_wrap.rotation = Vector3(randf_range(-0.12, 0.12), 0.0, randf_range(-0.35, 0.35))
	_bank = 0.0
	_pitch = 0.0
	alt = 0.0
	for t in _trails:
		t.emitting = false
	if _shadow != null:
		_shadow.visible = false
	var fire := Fx.flame(self, Vector3(0.0, 0.8, 0.0), 2.4)
	var smoke := Fx.burning(self, global_position + Vector3(0, 0.8, 0), false)
	var ft := create_tween()
	ft.tween_interval(24.0)
	ft.tween_callback(func():
		if is_instance_valid(fire):
			fire.queue_free())
	ft.tween_interval(14.0)
	ft.tween_callback(func():
		if is_instance_valid(smoke):
			smoke.queue_free())
	PerfMonitor.note("vliegtuig neergestort")
	if was_driven:
		Game.banner.emit("NEERGESTORT", "Een nieuw toestel staat straks klaar", 2.5)
	# na een tijdje ruimt het wrak op en kan het vliegveld een nieuw toestel zetten
	ft.tween_interval(10.0)
	ft.tween_callback(queue_free)


## Schade van buitenaf (nog niet gekoppeld; komt in stap 2): ontploffing vlakbij laat hem neerstorten in de lucht.
func blast_dist(at: Vector3) -> float:
	return global_position.distance_to(at)


# ------------------------------------------------------------------ beeld

func _visuals(delta: float) -> void:
	if mode == Mode.WRECK:
		return
	var in_air := mode == Mode.AIR
	# Hoger = dichter bij de camera: het toestel wordt tot ~30% groter, zodat hoogte ook zonder getal te zien is.
	var up := 1.0 + clampf(alt / MAX_ALT, 0.0, 1.0) * 0.3 if in_air else 1.0
	_wrap.scale = _wrap.scale.lerp(Vector3.ONE * up, minf(1.0, delta * 5.0))
	_wrap.rotation.z = lerpf(_wrap.rotation.z, _bank if in_air else _bank * 0.15, minf(1.0, delta * 6.0))
	_wrap.rotation.x = lerpf(_wrap.rotation.x, _pitch if in_air else 0.0, minf(1.0, delta * 6.0))
	if _anim != null and _anim.has_animation(FLY_CLIP):
		if (driven or mode == Mode.TAXI or mode == Mode.ROLLOUT) and not _anim.is_playing():
			_anim.play(FLY_CLIP)
	var trail_on := in_air and speed > 16.0 and alt > 2.0
	for t in _trails:
		t.emitting = trail_on
	_set_shadow()


## Schaduw op de grond: kleiner en lichter naarmate hij hoger vliegt, en een stukje opzij zodat de hoogte te zien is.
func _set_shadow() -> void:
	if _shadow == null or not is_inside_tree() or mode == Mode.WRECK:
		return
	var a := alt
	var gy := ground_y(global_position) + 0.04
	var sc := 1.0 / (1.0 + a * 0.02)
	(_shadow.mesh as PlaneMesh).size = Vector2(_span * 1.05 * sc, _len * 1.05 * sc)
	_shadow.global_position = Vector3(global_position.x + a * 0.4, gy, global_position.z + a * 0.55)
	_shadow.global_rotation = Vector3(0.0, rotation.y + _wrap.rotation.y, 0.0)
	_shadow_mat.set_shader_parameter("strength", clampf(0.55 - a * 0.015, 0.16, 0.55))
	_shadow.visible = true


func camera_extra() -> float:
	## Extra camera-afstand: hoger vliegen en sneller = meer overzicht (de tactische camera blijft, hij zoomt alleen mee).
	return minf(alt * 1.3 + speed * 0.45, 34.0)


func camera_lead() -> float:
	return clampf(speed * 0.8, 0.7, 22.0)


func _update_ui(p, live: bool) -> void:
	var what := ""
	if p != null and not p.dead and live and driven_plane == null and not driven and (mode == Mode.PARKED or (mode == Mode.GROUND and speed < 1.5)) \
			and p.global_position.distance_to(global_position) < BOARD_DIST + _span * 0.3:
		what = "in"
	elif driven and mode == Mode.GROUND and speed < 1.5:
		what = "uit"
	_btn.visible = what != ""
	if what != "":
		_btn.dock(2)
		_btn.kind = "enter" if what == "in" else "exit"
		_btn.set_caption("IN" if what == "in" else "UIT")
		_btn.queue_redraw()
	var show_meter := driven and (mode == Mode.AIR or mode == Mode.GROUND or mode == Mode.ROLLOUT or mode == Mode.TAXI)
	_meter.visible = show_meter
	if show_meter:
		var inv := GameSettings.get_value("vliegtuig_hoogte") == "omgekeerd"
		_info.text = "HOOGTE %d m   ·   %d km/u" % [roundi(alt), roundi(speed * 3.6)]
		_bar.size.x = 218.0 * clampf(alt / MAX_ALT, 0.0, 1.0)
		var hint := ""
		match mode:
			Mode.GROUND:
				if _hint_t > 0.0:
					hint = "Gas geven, dan rechterstick %s om op te stijgen" % ("omhoog" if inv else "omlaag")
			Mode.AIR:
				hint = "Landen: laag boven asfalt en langzaam" if alt < 6.0 else ""
			Mode.ROLLOUT:
				hint = "Uitrollen…"
			Mode.TAXI:
				hint = "Terug naar de hangar…"
		_hint.text = hint
	var labels := show_meter and _sticks_seen <= 2 and (mode == Mode.GROUND or mode == Mode.AIR) and _hint_t > 0.0
	_lbl_left.visible = labels
	_lbl_right.visible = labels
	if labels:
		_lbl_right.text = "HOOGTE: %s = stijgen" % ("omhoog" if GameSettings.get_value("vliegtuig_hoogte") == "omgekeerd" else "omlaag")
