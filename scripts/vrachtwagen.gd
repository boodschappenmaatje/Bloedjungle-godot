extends CharacterBody3D
## Zware legertruck (zeswieler) die tot 10 soldaten vervoert. Gekocht bij de garage; kom je dichtbij, dan
## verschijnt IN. Instappen start de motor (rookwolk) en roept je soldaten in de buurt: de laadklep zakt, het
## trapje klapt uit en ze klimmen één voor één de laadbak in en gaan op de banken zitten. UIT laat ze er weer
## uitspringen. Tijdens het rijden: TROEPEN laadt of lost ze, ZEIL rolt het zeil af of op. Zitten ze met open
## zeil achterin, dan schieten ze op vijanden in de buurt.
## Model: assets/vrachtwagen.glb (Blender, bron/vrachtwagen), voorkant is -Z. Wielen, sturen, vering, schakelen,
## rook en geluid doet deze code; uit Blender komen de clips Open/Dicht (klep) en ZeilDicht/ZeilOpen.

const SPEED := 11.0         # m/s vooruit (40 km/u)
const REVERSE := 3.0        # m/s achteruit
const ACCEL := 4.2          # m/s² gas geven (zwaar)
const BRAKE := 7.5          # m/s² remmen
const WHEELBASE := 4.7      # m van de vooras tot het midden van de achterassen
const WHEEL_R := 0.57
const MAX_STEER := 0.55     # rad
const BOARD_DIST := 6.0     # m van het midden: dichterbij toont IN
const CALL_DIST := 30.0     # m: soldaten binnen deze afstand komen instappen
const RAM_DAMAGE := 70.0
const SEATS := 10
const GEARS := [0.0, 2.2, 4.6, 7.6, 11.5]  # m/s waar elke versnelling ophoudt
const FIRE_T := 0.55        # s tussen schoten van een soldaat in de laadbak
const RANGE := 16.0

# maten uit bron/vrachtwagen/maak_vrachtwagen.py (Blender-eenheden: x, y vooruit, z omhoog)
const BAK_Y0 := -3.75
const VLOER := 1.30
const RUN := 4.6            # m/s: soldaten rennen naar de truck
const WALK := 1.8           # m/s lopen in de laadbak (modelmaat)
const CLIMB_T := 1.3        # s om het trapje op te klimmen

var driven := false
var goals: Array = []
var _speed := 0.0
var _steer := 0.0
var _yaw_rate := 0.0
var _accel := 0.0
var _t := 0.0
var _ram_cd := 0.0
var _night := false
var _head_mat: StandardMaterial3D
var _tail_mat: StandardMaterial3D
var _body_base: Transform3D
var _btn: ActionBtn
var _btn_troops: ActionBtn
var _btn_zeil: ActionBtn
# motor: uit / starten / aan; rpm 0..1 binnen de versnelling
var _engine := "uit"
var _engine_t := 0.0
var _gear := 1
var _rpm := 0.0
var _shift_t := 0.0
var _jolt := 0.0
var _was_fast := false
var _engine_vol := 0.0
# laadbak
var _riders := {}  # Ally -> {"st": String, "seat": int, "t": float, "from": Vector3, "delay": float}
var _klep_open := false
var _klep_t := 9.0
var _zeil_dicht := false
var _smoke: CPUParticles3D

@onready var _anim: AnimationPlayer = $Model/AnimationPlayer
var _zanim: AnimationPlayer  # tweede speler voor het zeil, zodat klep en zeil tegelijk kunnen bewegen
@onready var _body: Node3D = $Model/Vrachtwagen/Body
@onready var _stuur := [$Model/Vrachtwagen/Body/StuurLV, $Model/Vrachtwagen/Body/StuurRV]
@onready var _wheels := [$Model/Vrachtwagen/Body/StuurLV/WielLV, $Model/Vrachtwagen/Body/StuurRV/WielRV,
	$Model/Vrachtwagen/Body/WielLM, $Model/Vrachtwagen/Body/WielRM, $Model/Vrachtwagen/Body/WielLA, $Model/Vrachtwagen/Body/WielRA]
@onready var _uitlaat: Node3D = $Model/Vrachtwagen/Body/Uitlaat

static var _snd := {}
var _eng_player: AudioStreamPlayer
var _fx_player: AudioStreamPlayer


func _ready() -> void:
	add_to_group("voertuigen")   # brandkranen spuiten als je erover rijdt
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	process_physics_priority = -1  # eerst de truck, dan de soldaten die erop zitten
	_body_base = _body.transform
	_split_clips()
	# rusthouding: klep dicht, zeil opgerold
	_anim.play("Dicht")
	_anim.seek(_anim.current_animation_length, true)
	_zanim.play("ZeilOpen")
	_zanim.seek(_zanim.current_animation_length, true)
	_setup_lights()
	_build_buttons()
	_build_smoke()
	_make_sounds()
	_eng_player = AudioStreamPlayer.new()
	add_child(_eng_player)
	_fx_player = AudioStreamPlayer.new()
	add_child(_fx_player)


## De Blender-clips keyen allemaal klep, trapje en zeil. Open/Dicht houden alleen de klep, ZeilDicht/ZeilOpen
## alleen het zeil, en het zeil krijgt een eigen AnimationPlayer.
func _split_clips() -> void:
	var lib := AnimationLibrary.new()
	for clip in ["Open", "Dicht", "ZeilDicht", "ZeilOpen"]:
		var a := _anim.get_animation(clip)
		var zeil: bool = clip.begins_with("Zeil")
		for i in range(a.get_track_count() - 1, -1, -1):
			if String(a.track_get_path(i)).contains("Zeil") != zeil:
				a.remove_track(i)
		if zeil:
			lib.add_animation(clip, a)
	_zanim = AnimationPlayer.new()
	_anim.get_parent().add_child(_zanim)
	_zanim.root_node = _zanim.get_path_to(_anim.get_node(_anim.root_node))
	_zanim.add_animation_library("", lib)


func _setup_lights() -> void:
	var romp: MeshInstance3D = $Model/Vrachtwagen/Body/RompMesh
	for i in romp.mesh.get_surface_count():
		var m := romp.mesh.surface_get_material(i)
		if m is StandardMaterial3D and (m.resource_name == "Koplamp" or m.resource_name == "Achterlicht"):
			var copy: StandardMaterial3D = m.duplicate()
			romp.set_surface_override_material(i, copy)
			if m.resource_name == "Koplamp":
				_head_mat = copy
			else:
				_tail_mat = copy
	_night = GameSettings.get_value("time") != "day"
	for n in ["KoplampL", "KoplampR"]:
		get_node("Model/Vrachtwagen/Body/" + n).visible = _night
	if _head_mat:
		_head_mat.emission_energy_multiplier = 6.0 if _night else 0.0


func _make_btn(kind: String, cap: String, slot: int, cb: Callable, layer: CanvasLayer) -> ActionBtn:
	var b := ActionBtn.make(kind, cap)
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = ActionBtn.slot_x(slot)
	b.offset_right = ActionBtn.slot_x(slot) + ActionBtn.SIZE.x
	b.offset_top = -126.0
	b.offset_bottom = -126.0 + ActionBtn.SIZE.y
	b.pressed.connect(cb)
	b.hide()
	layer.add_child(b)
	return b


func _build_buttons() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_btn = _make_btn("enter", "IN", 2, _toggle, layer)
	_btn_troops = _make_btn("troepen", "LADEN", 1, _troops_button, layer)
	_btn_zeil = _make_btn("zeil", "ZEIL", 0, _zeil_button, layer)


## Rook uit de uitlaatpijp: dun als hij stationair draait, dik en zwart bij gas geven.
func _build_smoke() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.amount = 20
	_smoke.lifetime = 1.6
	_smoke.local_coords = false
	_smoke.direction = Vector3.UP
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 1.2
	_smoke.initial_velocity_max = 2.0
	_smoke.gravity = Vector3(0, 0.5, 0)
	_smoke.scale_amount_min = 0.35
	_smoke.scale_amount_max = 0.55
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 2.4))
	_smoke.scale_amount_curve = c
	_smoke.angle_min = -180.0
	_smoke.angle_max = 180.0
	_smoke.color_ramp = Fx._ramp([Color(0.1, 0.1, 0.1, 0.0), Color(0.12, 0.11, 0.1, 0.55), Color(0.3, 0.3, 0.3, 0.0)], [0.0, 0.15, 1.0])
	_smoke.mesh = Fx._quad()
	_smoke.mesh.material = Fx._particle_mat(Color.WHITE, false)
	_smoke.emitting = false
	_uitlaat.add_child(_smoke)


## Dikke zwarte wolk (starten, schakelen, flink gas).
func _puff(big: float) -> void:
	var p := Fx._puff(int(8 * big) + 4, 1.8, 0.9 * big, false, Fx._ramp([Color(0.05, 0.05, 0.05, 0.0), Color(0.07, 0.07, 0.06, 0.85), Color(0.25, 0.25, 0.25, 0.0)], [0.0, 0.1, 1.0]), Vector2(1.5, 3.5) * big, 2.6)
	p.one_shot = true
	p.explosiveness = 0.85
	get_parent().add_child(p)
	p.global_position = _uitlaat.global_position
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)


# ---------------------------------------------------------------- in- en uitstappen

func _toggle() -> void:
	var p = Game.player
	if p == null or p.dead:
		return
	if driven:
		driven = false
		p.driving = false
		p.visible = true
		var side := global_transform.basis.x
		p.global_position = global_position - side * 2.2 + global_transform.basis.z * -1.6
		p.global_position.y = 0.0
		p.collision_mask = p.get("_mask0")
		_btn.kind = "enter"
		_btn.set_caption("IN")
		_btn.queue_redraw()
		_unload()
		_play_fx("hiss", 0.7)
	else:
		driven = true
		goals.clear()
		p.driving = true
		p.visible = false
		p.collision_mask = 0
		p.velocity = Vector3.ZERO
		_btn.kind = "exit"
		_btn.set_caption("UIT")
		_btn.queue_redraw()
		if _engine == "uit":
			_engine = "starten"
			_engine_t = 0.0
			_eng_player.stream = _snd.starter
			_eng_player.pitch_scale = 1.0
			_eng_player.play()
		_load()


func _troops_button() -> void:
	if _riders.is_empty():
		_play_fx("horn", 0.9)
		_load()
	else:
		_unload()


func _zeil_button() -> void:
	_zeil_dicht = not _zeil_dicht
	_zanim.play("ZeilDicht" if _zeil_dicht else "ZeilOpen")
	Sfx.play("gate", 0.5, global_position)


## Volgorde van de zitplaatsen: van voor naar achter, links en rechts om en om.
const FILL := [0, 5, 1, 6, 2, 7, 3, 8, 4, 9]


func _load() -> void:
	var taken := {}
	for a in _riders:
		taken[_riders[a].seat] = true
	var cands: Array = []
	for a in Game.allies:
		if is_instance_valid(a) and a.get("truck") == null and a.global_position.distance_to(global_position) < CALL_DIST:
			cands.append(a)
	cands.sort_custom(func(x, y): return x.global_position.distance_to(global_position) < y.global_position.distance_to(global_position))
	for a in cands:
		var seat := -1
		for s in FILL:
			if not taken.has(s):
				seat = s
				break
		if seat < 0:
			break
		taken[seat] = true
		a.truck = self
		_riders[a] = {"st": "rennen", "seat": seat, "t": 0.0, "from": Vector3.ZERO, "delay": 0.0}
	if not _riders.is_empty():
		_open_klep()


func _unload() -> void:
	var order: Array = []
	for a in _riders:
		var r: Dictionary = _riders[a]
		if r.st == "rennen":
			_release(a)
		elif r.st == "zit":
			order.append(a)
	# achterste eerst
	order.sort_custom(func(x, y): return int(_riders[x].seat) % 5 > int(_riders[y].seat) % 5)
	var i := 0
	for a in order:
		var r: Dictionary = _riders[a]
		r.st = "opstaan"
		r.t = 0.0
		r.delay = i * 0.45
		r.from = a.global_position
		i += 1
	if not order.is_empty():
		_open_klep()


func _release(a: Node) -> void:
	_riders.erase(a)
	if is_instance_valid(a):
		a.truck = null
		a.position.y = 0.0


func _open_klep() -> void:
	if _klep_open:
		return
	_klep_open = true
	_klep_t = 0.0
	_anim.play("Open")
	Sfx.play("thud", 0.6, global_position)


func _close_klep() -> void:
	if not _klep_open:
		return
	_klep_open = false
	_anim.play("Dicht")
	Sfx.play("thud", 0.45, global_position)


## Punt in de laadbak in Blender-maat (x, y vooruit, z omhoog), in de wereld; volgt de vering van de bak.
func _bp(x: float, y: float, z: float) -> Vector3:
	return _body.to_global(Vector3(x, z, -y))


func _seat_node(i: int) -> Node3D:
	return get_node("Model/Vrachtwagen/Body/Zit%d" % i)


func _seat_side(i: int) -> float:
	return -1.0 if i < 5 else 1.0


func _seat_y(i: int) -> float:
	return -float(i % 5) * 0.75


## Kijkrichting van een mannetje (zijn voorkant is +Z) langs een richting in de wereld.
static func _face_of(d: Vector3) -> float:
	return atan2(d.x, d.z)


func _busy() -> bool:
	for a in _riders:
		var st: String = _riders[a].st
		if st != "zit" and st != "rennen":
			return true
	return false


## Wordt door Ally aangeroepen zolang hij bij deze truck hoort: hier staat wat hij doet.
func ride_step(a: Node, delta: float) -> void:
	if not _riders.has(a):
		a.truck = null
		return
	var r: Dictionary = _riders[a]
	var fwd := -global_transform.basis.z
	var fwd_face := _face_of(fwd)
	var seat: int = r.seat
	var sx := _seat_side(seat)
	match r.st:
		"rennen":
			# naar de achterkant; wie niet de eerste in de rij is wacht een stukje erachter
			var q := _queue_index(a)
			var goal := _bp(0.0, BAK_Y0 - 0.75 - q * 0.9, 0.0)
			goal.y = 0.0
			var to := Vector3(goal.x - a.global_position.x, 0, goal.z - a.global_position.z)
			if to.length() > 0.25:
				var wp := Route.waypoint(a.global_position, goal)
				var d := Vector3(wp.x - a.global_position.x, 0, wp.z - a.global_position.z)
				a.velocity = d.normalized() * minf(RUN, to.length() * 4.0)
				a.move_and_slide()
				a.position.y = 0.0
				a.face = lerp_angle(a.face, _face_of(d), minf(1.0, delta * 12.0))
				a.model.play("rennen" if to.length() > 1.2 else "lopen", 0.15)
			else:
				a.face = lerp_angle(a.face, fwd_face, minf(1.0, delta * 10.0))
				a.model.play("stil", 0.2)
				if q == 0 and _klep_open and _klep_t > 1.1 and _ladder_free() and absf(_speed) < 0.3:
					r.st = "klimmen"
					r.t = 0.0
					r.from = a.global_position
		"klimmen":
			# trapje op: van de grond achter de klep tot op de laadvloer
			r.t += delta / CLIMB_T
			var k: float = minf(r.t, 1.0)
			var bottom := _bp(0.0, BAK_Y0 - 0.55, 0.0)
			var top := _bp(0.0, BAK_Y0 - 0.32, VLOER)
			if k < 0.15:
				a.global_position = r.from.lerp(bottom, k / 0.15)
			else:
				a.global_position = bottom.lerp(top, (k - 0.15) / 0.85)
			a.face = fwd_face
			a.model.play("klimmen", 0.12, 2.0)
			if r.t >= 1.0:
				r.st = "opstap"
				r.t = 0.0
				Sfx.play("thud", 0.25, a.global_position)
		"opstap":
			# over de rand de bak in
			r.t += delta / 0.4
			var k: float = minf(r.t, 1.0)
			a.global_position = _bp(0.0, BAK_Y0 - 0.32, VLOER).lerp(_bp(0.0, BAK_Y0 + 0.45, VLOER), k)
			a.face = fwd_face
			a.model.play("lopen", 0.15)
			if r.t >= 1.0:
				r.st = "lopen"
				r.t = 0.0
		"lopen":
			# door het middenpad naar zijn bank
			var ys: float = BAK_Y0 + 0.45 + r.t
			var target := _seat_y(seat)
			r.t += WALK * delta
			if BAK_Y0 + 0.45 + r.t >= target:
				r.st = "gaan_zitten"
				r.t = 0.0
				ys = target
			a.global_position = _bp(0.0, ys, VLOER)
			a.face = fwd_face
			a.model.play("lopen", 0.15)
		"gaan_zitten":
			r.t += delta / 0.45
			var k := ease(minf(r.t, 1.0), -1.8)
			var seat_pos := _seat_node(seat).global_position
			a.global_position = _bp(0.0, _seat_y(seat), VLOER).lerp(seat_pos, k)
			var inward := global_transform.basis.x * -sx
			a.face = lerp_angle(fwd_face, _face_of(inward), k)
			a.model.play("zitten", 0.25)
			if r.t >= 1.0:
				r.st = "zit"
		"zit":
			a.global_position = _seat_node(seat).global_position
			var inward := global_transform.basis.x * -sx
			var look := _face_of(inward)
			var target: Node3D = a._nearest_enemy() if not _zeil_dicht else null
			if target != null:
				var td: Vector3 = target.global_position - a.global_position
				var want := angle_difference(look, _face_of(td))
				look += clampf(want, -1.1, 1.1)
				if absf(want) < 1.4:
					a.fire_t -= delta
					if a.fire_t <= 0.0:
						a.fire_t = FIRE_T * randf_range(0.8, 1.3)
						_seat_shot(a, _face_of(td))
			a.face = lerp_angle(a.face, look, minf(1.0, delta * 6.0))
			a.model.play("zitten", 0.25)
		"opstaan":
			if r.delay > 0.0:
				r.delay -= delta
				a.global_position = _seat_node(seat).global_position
				a.model.play("zitten", 0.25)
				return
			r.t += delta / 0.4
			var k := minf(r.t, 1.0)
			a.global_position = _seat_node(seat).global_position.lerp(_bp(0.0, _seat_y(seat), VLOER), k)
			a.face = lerp_angle(a.face, fwd_face + PI, k)
			a.model.play("stil", 0.2)
			if r.t >= 1.0:
				r.st = "naar_achter"
				r.t = 0.0
		"naar_achter":
			r.t += WALK * 1.3 * delta
			var ys: float = _seat_y(seat) - r.t
			if ys <= BAK_Y0 + 0.3:
				ys = BAK_Y0 + 0.3
				r.st = "springen"
				r.t = 0.0
				r.from = _bp(0.0, ys, VLOER)
			a.global_position = _bp(0.0, ys, VLOER)
			a.face = fwd_face + PI
			a.model.play("lopen", 0.15, 1.3)
		"springen":
			# met een boog van de laadvloer op de grond, een eindje achter de wagen en iets opzij
			r.t += delta / 0.55
			var k := minf(r.t, 1.0)
			var land := _bp(sx * 0.7, BAK_Y0 - 1.6, 0.0)
			land.y = 0.0
			var p: Vector3 = r.from.lerp(land, k)
			p.y = lerpf(r.from.y, 0.0, k * k) + sin(k * PI) * 0.45
			a.global_position = p
			a.face = fwd_face + PI
			a.model.play("rennen", 0.1)
			if r.t >= 1.0:
				Fx.dust(get_parent(), a.global_position)
				Sfx.play("thud", 0.3, a.global_position)
				a.global_position = land
				_release(a)


func _queue_index(a: Node) -> int:
	# wie het dichtst bij de klep staat (en nog moet klimmen) is de eerste
	var mine: float = a.global_position.distance_to(_bp(0.0, BAK_Y0 - 0.75, 0.0))
	var i := 0
	for b in _riders:
		if b == a or _riders[b].st != "rennen":
			continue
		var d: float = b.global_position.distance_to(_bp(0.0, BAK_Y0 - 0.75, 0.0))
		if d < mine or (is_equal_approx(d, mine) and b.get_instance_id() < a.get_instance_id()):
			i += 1
	return i


func _ladder_free() -> bool:
	for b in _riders:
		var r: Dictionary = _riders[b]
		if r.st == "klimmen" and r.t < 0.6:
			return false
		if r.st == "springen" or (r.st == "naar_achter"):
			return false
	return true


func _seat_shot(a: Node, angle: float) -> void:
	var dir := Vector3(sin(angle), 0, cos(angle))
	var muzzle: Vector3 = a.global_position + Vector3.UP * 1.6 + dir * 0.6
	Bullet.fire(get_parent(), muzzle, angle + randf_range(-0.06, 0.06), 70.0, a.dmg, 0.6, true, true)
	Fx.muzzle(get_parent(), muzzle)
	Sfx.play("ak", 0.4, muzzle)


# ---------------------------------------------------------------- rijden

func _physics_process(delta: float) -> void:
	_t += delta
	_ram_cd -= delta
	_klep_t += delta
	var p = Game.player
	var live: bool = Game.state == "play" or Game.state == "prep"
	if p != null and p.dead and driven:
		_toggle()
	for a in _riders.keys():
		if not is_instance_valid(a):
			_riders.erase(a)
	if _btn:
		var near: bool = p != null and not p.dead and live and (driven or p.global_position.distance_to(global_position) < BOARD_DIST)
		_btn.visible = near
		_btn_troops.visible = driven and live
		_btn_zeil.visible = driven and live
		var cap := "LOSSEN" if not _riders.is_empty() else "LADEN"
		_btn_troops.set_caption(cap)
		_btn_zeil.open_state = _zeil_dicht
		_btn_zeil.set_caption("OPEN" if _zeil_dicht else "DICHT")
	# klep weer dicht als niemand meer klimt of springt
	if _klep_open and _klep_t > 1.4 and not _busy():
		var waiting := false
		for a in _riders:
			if _riders[a].st == "rennen":
				waiting = true
		if not waiting:
			_close_klep()
	_drive(delta, live)
	_animate(delta)
	_engine_step(delta)
	if driven and p != null:
		p.global_position = Vector3(global_position.x, 0.0, global_position.z)
		p.face = rotation.y + PI
		_ram()


func _drive(delta: float, live: bool) -> void:
	var want_speed := 0.0
	var want_steer := 0.0
	var pivot := 0.0
	var mv := Game.move
	collision_mask = 0 if not goals.is_empty() else 50
	var can_go := _engine == "aan" and not _busy() and not (_klep_open and _klep_t < 1.0)
	if not driven and not goals.is_empty():
		# uit de garage naar zijn parkeerplek: sturen naar het volgende punt
		var to: Vector3 = goals[0] - global_position
		to.y = 0.0
		var fwd := -global_transform.basis.z
		var alpha := atan2(fwd.cross(to).y, fwd.dot(to))
		# aangekomen, of het punt ligt al naast/achter hem: stoppen in plaats van een rondje te rijden
		if to.length() < 1.6 or absf(alpha) > 1.0:
			goals.pop_front()
		else:
			want_steer = clampf(atan(2.0 * WHEELBASE * sin(alpha) / maxf(to.length(), 3.0)), -MAX_STEER, MAX_STEER)
			# de motor staat uit: hij rolt rustig de garage uit en komt recht tot stilstand
			want_speed = clampf(to.length() * 0.5, 0.6, 2.5)
	elif driven and live and can_go and mv.length() > 0.15:
		# hij draait naar waar je de stick duwt; ligt dat achter hem, dan rijdt hij achteruit
		var want := atan2(-mv.x, -mv.y)
		var diff := wrapf(want - rotation.y, -PI, PI)
		var reverse := absf(diff) > 2.3
		if reverse:
			diff = wrapf(diff - PI, -PI, PI)
		want_steer = clampf(diff * 1.5, -MAX_STEER, MAX_STEER) * (-1.0 if reverse else 1.0)
		var bend := 1.0 - 0.5 * minf(absf(diff) / 1.2, 1.0)
		pivot = diff
		want_speed = (-REVERSE if reverse else SPEED * bend) * minf(mv.length() * 1.3, 1.0)
		# wie nog aan komt rennen blijft achter als je wegrijdt
		for a in _riders.keys():
			if _riders[a].st == "rennen":
				_release(a)
	var old := _speed
	var braking := signf(want_speed) != signf(_speed) or absf(want_speed) < absf(_speed)
	# tijdens het schakelen even geen trekkracht
	var acc := ACCEL * (0.15 if _shift_t > 0.0 else 1.0) * (1.0 - 0.45 * absf(_speed) / SPEED)
	_speed = move_toward(_speed, want_speed, (BRAKE if braking else acc) * delta)
	_accel = lerpf(_accel, (_speed - old) / delta, delta * 4.0)
	_steer = move_toward(_steer, want_steer, 1.6 * delta)
	_yaw_rate = _speed * tan(_steer) / WHEELBASE
	# luchtdrukrem: na flink remmen tot stilstand
	if absf(_speed) > 3.0:
		_was_fast = true
	elif _was_fast and absf(_speed) < 0.4:
		_was_fast = false
		_play_fx("hiss", 0.6)
	# stilstaand kan hij langzaam bijdraaien, anders loop je vast
	rotation.y += clampf(pivot, -1.0, 1.0) * 0.7 * clampf(1.0 - absf(_speed) / 2.0, 0.0, 1.0) * delta
	if absf(_speed) < 0.01:
		return
	rotation.y += _yaw_rate * delta
	velocity = -global_transform.basis.z * _speed
	move_and_slide()
	global_position.y = 0.0
	if get_slide_collision_count() > 0:
		_speed *= 0.6
	var flat := Vector2(global_position.x, global_position.z)
	var clamped := Data.clamp_world(flat)
	if clamped != flat:
		flat = clamped
		global_position = Vector3(flat.x, 0.0, flat.y)


func _animate(delta: float) -> void:
	for w in _wheels:
		w.rotation.x = wrapf(w.rotation.x - _speed * delta / WHEEL_R, -PI, PI)
	for s in _stuur:
		s.rotation.y = _steer
	# vering: zwaar deinen, neus omhoog bij gas en omlaag bij remmen, overhellen in de bocht,
	# schudden bij het starten en een schok bij het schakelen
	var amp := clampf(absf(_speed) / 5.0, 0.2, 1.0)
	var bounce := (0.014 * sin(_t * 6.5) + 0.007 * sin(_t * 11.3)) * amp
	var pitch := clampf(_accel * 0.008, -0.04, 0.04) + 0.003 * sin(_t * 5.1) * amp
	var roll := clampf(-_yaw_rate * _speed * 0.005, -0.05, 0.05)
	if _engine == "starten":
		var k := 0.012 * sin(_t * 55.0) * (0.4 + 0.6 * absf(sin(_t * 9.0)))
		roll += k
		bounce += k * 0.5
	elif _engine == "aan":
		var idle := 0.0025 * sin(_t * 70.0) * (1.0 - _rpm * 0.5)
		roll += idle
	_jolt = move_toward(_jolt, 0.0, delta * 0.12)
	pitch += _jolt * sin(_t * 30.0) * 0.4 + _jolt
	_body.transform = _body_base * Transform3D(Basis.from_euler(Vector3(pitch, 0, roll)), Vector3(0, bounce, 0))
	if _tail_mat:
		var brake_light: bool = _accel < -1.0 or (driven and absf(_speed) < 0.3 and Game.move.length() < 0.15)
		_tail_mat.emission_energy_multiplier = lerpf(_tail_mat.emission_energy_multiplier, 6.0 if brake_light else (3.0 if _night else 0.6), delta * 10.0)


## Rijdt hij op een vijand voor zijn neus, dan gaat die neer.
func _ram() -> void:
	if _speed < 3.0 or _ram_cd > 0.0:
		return
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var lp := to_local(e.global_position)
		if absf(lp.x) < 1.5 and lp.z < -2.5 and lp.z > -5.0:
			_ram_cd = 0.2
			e.hit(RAM_DAMAGE, -global_transform.basis.z, true)


# ---------------------------------------------------------------- motor en geluid

func _engine_step(delta: float) -> void:
	_engine_t += delta
	_shift_t -= delta
	var v := absf(_speed)
	match _engine:
		"uit":
			_smoke.emitting = false
			return
		"starten":
			_eng_player.volume_db = linear_to_db(0.5 * _vol())
			if _engine_t > 1.25:
				# hij slaat aan: brullen, een dikke wolk en de motor loopt
				_engine = "aan"
				_engine_t = 0.0
				_eng_player.stream = _snd.engine
				_eng_player.play()
				_puff(1.6)
				_rpm = 0.9
				Sfx.play("thud", 0.5, global_position)
			return
	# versnelling kiezen: bij optrekken boven de grens één hoger, bij afremmen terug
	var up: float = GEARS[mini(_gear, GEARS.size() - 1)]
	var lo: float = GEARS[_gear - 1]
	if _gear < GEARS.size() - 1 and v > up and _accel > 0.2:
		_gear += 1
		_shift_t = 0.3
		_jolt = 0.025
		_puff(0.7)
		Sfx.play("thud", 0.35, global_position)
	elif _gear > 1 and v < lo - 0.4:
		_gear -= 1
	up = GEARS[mini(_gear, GEARS.size() - 1)]
	lo = GEARS[_gear - 1]
	var frac := clampf((v - lo) / maxf(0.1, up - lo), 0.0, 1.0)
	var load := clampf(_accel / ACCEL, 0.0, 1.0)
	var want_rpm := (0.18 + 0.82 * frac) if v > 0.2 else 0.0
	if _shift_t > 0.0:
		want_rpm *= 0.55
	if _engine_t < 1.0:
		want_rpm = maxf(want_rpm, 0.9 * (1.0 - _engine_t))  # na het aanslaan zakt hij terug naar stationair
	_rpm = lerpf(_rpm, want_rpm, minf(1.0, delta * 5.0))
	_eng_player.pitch_scale = 1.0 + _rpm * 0.85
	_engine_vol = lerpf(_engine_vol, 0.45 + 0.35 * load + 0.2 * _rpm, minf(1.0, delta * 6.0))
	_eng_player.volume_db = linear_to_db(maxf(0.001, _engine_vol * _vol()))
	_smoke.emitting = true
	_smoke.initial_velocity_max = 2.0 + 3.0 * load
	_smoke.scale_amount_max = 0.55 + 0.6 * load
	if load > 0.6 and randf() < delta * 2.0:
		_puff(0.5)
	# niemand meer aan boord en niemand achter het stuur: na een tijdje gaat de motor uit
	if not driven and _riders.is_empty() and goals.is_empty() and _engine_t > 2.0 and v < 0.1:
		_engine = "uit"
		_eng_player.stop()


## Hoe hard de truck klinkt: zachter als hij ver van de speler staat.
func _vol() -> float:
	var p = Game.player
	if p == null:
		return 0.0
	return clampf(1.2 - p.global_position.distance_to(global_position) / 40.0, 0.0, 1.0) * Sfx.MASTER


func _play_fx(name: String, vol: float) -> void:
	_fx_player.stream = _snd[name]
	_fx_player.volume_db = linear_to_db(maxf(0.001, vol * _vol()))
	_fx_player.pitch_scale = randf_range(0.95, 1.05)
	_fx_player.play()


# Geluiden worden één keer gemaakt, net als in sfx.gd: geen bestanden nodig.
const RATE := 22050


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, clampi(roundi(tanh(samples[i]) * 30000.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


static func _make_sounds() -> void:
	if not _snd.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# zware diesel: 22 ontstekingen per seconde (stationair), elk een lage, ronde dreun (grondtoon 44 Hz met
	# boventonen, zodat je de brom ook op een telefoonspeaker hoort) en een zachte doffe plof in plaats van
	# geratel; alles gaat door een laagdoorlaatfilter. De lus is precies 1 s: 22 hele slagen, geen klik.
	var n := RATE
	var s := PackedFloat32Array()
	s.resize(n)
	var amps: Array[float] = []
	for k in 22:
		amps.append(rng.randf_range(0.85, 1.12))
	var lp := 0.0
	var lp2 := 0.0
	var out := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := int(t * 22.0)
		var dt := t - float(k) / 22.0
		var a := amps[k % 22]
		var noise := rng.randf_range(-1.0, 1.0)
		lp += 0.08 * (noise - lp)
		lp2 += 0.012 * (noise - lp2)
		var env := exp(-dt * 22.0)
		var thump := env * (sin(TAU * 44.0 * dt) + 0.7 * sin(TAU * 88.0 * dt + 0.5) + 0.45 * sin(TAU * 132.0 * dt + 1.0)
			+ 0.3 * sin(TAU * 176.0 * dt + 1.5) + 0.15 * sin(TAU * 220.0 * dt + 2.0))
		var chug := lp * exp(-dt * 60.0) * 0.6
		var rumble := sin(TAU * 11.0 * t) * 0.25 + lp2 * 2.2
		var v := (thump * a + chug * a) * 0.8 + rumble
		out += 0.35 * (v - out)
		s[i] = out * 1.1
	_snd.engine = _wav(s, true)
	# startmotor: zeurende elektromotor met de compressieslagen van het ronddraaien
	n = RATE
	s = PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var crank := 0.5 + 0.5 * sin(TAU * 8.0 * t)
		ph += TAU * (180.0 + 40.0 * crank) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var dt := fmod(t, 0.125)
		s[i] = sin(ph) * 0.25 * crank + sin(ph * 2.0) * 0.1 + noise * 0.15 * exp(-dt * 40.0) + sin(TAU * 55.0 * t) * 0.3 * exp(-dt * 25.0)
	_snd.starter = _wav(s, true)
	# luchtdrukrem: scherp sissen dat uitsterft
	n = int(RATE * 0.8)
	s = PackedFloat32Array()
	s.resize(n)
	lp = 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		lp += 0.5 * (noise - lp)
		var env := minf(1.0, t / 0.02) * pow(0.02, t / 0.8)
		s[i] = (noise - lp) * 1.4 * env
	_snd.hiss = _wav(s, false)
	# claxon: twee lage tonen samen, met een korte aanzet en uitklinken
	n = int(RATE * 0.75)
	s = PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.03) * clampf((0.75 - t) / 0.12, 0.0, 1.0)
		var v := 0.0
		for f in [196.0, 247.0]:
			for h in range(1, 6):
				v += sin(TAU * f * h * t) / float(h)
		s[i] = v * 0.35 * env
	_snd.horn = _wav(s, false)
