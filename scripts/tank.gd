extends CharacterBody3D
## Eigen tank, gekocht bij de garage. Kom je dichtbij, dan verschijnt INSTAPPEN: linker stick = rijden en draaien, rechter stick = koepel richten, tot de rand duwen = schieten. Hij rijdt de lijst `goals` af (uit de garage naar zijn plek) en blijft
## dan staan; de koepel draait naar de dichtstbijzijnde vijand. Model: assets/tank.glb (gemaakt in Blender), voorkant is -Z,
## met de delen Toren (draait om Y) en Loop (kantelt om X). De animaties uit Blender (Stationair,
## Rijden, Achteruit, Draaien, Schieten) laten wielen, rupsschakels en de vering bewegen.

const SPEED := 3.2         # m/s rijden
const TURN := 0.7          # rad/s draaien op de plek
const TURRET_TURN := 1.3   # rad/s koepel
const SIGHT := 34.0        # m, vanaf hier volgt de koepel een vijand
const SHELL_DAMAGE := 70.0   # schade van de granaat; zet op 0 voor alleen het effect
const SHELL_RADIUS := 3.2    # m
const RELOAD := 4.0          # s tussen twee schoten

var goals: Array = []  # Vector3-punten die hij afrijdt; leeg = blijft staan en bewaakt
var _reload := 2.0
var _turning := false
const ANIM_SPEED := 3.12   # m/s waarmee de rups in de clip Rijden loopt
var _clip := ""
const DRIVE_SPEED := 5.5   # m/s vooruit als jij bestuurt
const DRIVE_REVERSE := 2.5
const DRIVE_TURN := 1.5    # rad/s draaien als jij bestuurt
const DRIVE_TURRET := 2.4  # rad/s koepel als jij richt
const DRIVE_RELOAD := 1.6
const BOARD_DIST := 6.5
const RAM_DAMAGE := 60.0
const SHOT_RANGE := 45.0   # m, verder landt de granaat op de grond

const LOCK_FWD_MIN := 3.0   # m, muurstukken dichterbij dan dit worden niet gekozen
const LOCK_FWD_MAX := 38.0
const LOCK_SIDE := 2.1      # m, zo ver mag een muurstuk naast de lijn van je stick liggen
const LOCK_STICKY := 3.0    # m, het gekozen stuk blijft gekozen tot het zo ver van de lijn ligt

var driven := false
var _lock: Dictionary = {}     # het muurstuk waarop de koepel nu vastzit (leeg = geen)
var _lock_house: Node3D
var _mark: Node3D
var _line: MeshInstance3D
var _line_mesh := ImmediateMesh.new()
var _mark_t := 0.0
var _speed := 0.0
var _btn: ActionBtn
var _ram_cd := 0.0
@onready var _toren: Node3D = $Model/Tank/Body/Toren
@onready var _loop: Node3D = $Model/Tank/Body/Toren/Loop
@onready var _anim: AnimationPlayer = $Model/AnimationPlayer


func _ready() -> void:
	add_to_group("voertuigen")   # brandkranen spuiten als je erover rijdt
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_btn = ActionBtn.make("enter", "IN")
	_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_btn.offset_left = ActionBtn.slot_x(2)
	_btn.offset_right = ActionBtn.slot_x(2) + ActionBtn.SIZE.x
	_btn.offset_top = -126.0
	_btn.offset_bottom = -126.0 + ActionBtn.SIZE.y
	_btn.pressed.connect(_toggle)
	_btn.hide()
	layer.add_child(_btn)
	_build_sight()


func _toggle() -> void:
	var p = Game.player
	if p == null or p.dead:
		return
	if driven:
		driven = false
		p.driving = false
		p.in_tank = false
		p.visible = true
		_clear_sight()
		p.global_position = global_position - global_transform.basis.x * 3.2
		p.global_position.y = 0.0
		p.collision_mask = p.get("_mask0")
		_btn.kind = "enter"
		_btn.set_caption("IN")
	else:
		driven = true
		goals.clear()
		p.driving = true
		p.in_tank = true
		p.visible = false
		p.collision_mask = 0
		p.velocity = Vector3.ZERO
		_btn.kind = "exit"
		_btn.set_caption("UIT")
	_btn.queue_redraw()


func _physics_process(delta: float) -> void:
	_ram_cd -= delta
	var pl = Game.player
	var live: bool = Game.state == "play" or Game.state == "prep"
	if pl != null and pl.dead and driven:
		_toggle()
	_btn.visible = pl != null and not pl.dead and live and (driven or pl.global_position.distance_to(global_position) < BOARD_DIST)
	collision_mask = 0 if not goals.is_empty() else 50
	if driven:
		_drive_driven(delta, live)
		return
	_speed = 0.0
	if goals.is_empty():
		_turning = false
		_play("Stationair", 1.0)
		_aim(delta)
		return
	var goal: Vector3 = goals[0]
	var to := goal - global_position
	to.y = 0.0
	var want := atan2(-to.x, -to.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	if to.length() < 0.3:
		goals.pop_front()
		_turning = true
	elif _turning:
		rotation.y += clampf(diff, -TURN * delta, TURN * delta)
		_turning = absf(diff) > 0.02
		_play("Draaien", 1.0)
	else:
		rotation.y += clampf(diff, -TURN * delta, TURN * delta)
		global_position += to.normalized() * minf(SPEED * delta, to.length())
		_play("Rijden", SPEED / ANIM_SPEED)
	_aim(delta)


func _play(clip: String, speed: float) -> void:
	if clip != _clip:
		_clip = clip
		_anim.play(clip, 0.35)
	_anim.speed_scale = speed


func _aim(delta: float) -> void:
	var target = null
	var best := SIGHT
	for e in Game.enemies:
		var d: float = e.global_position.distance_to(global_position)
		if d < best:
			best = d
			target = e
	var local := 0.0
	var tilt := 0.03
	if target:
		var v: Vector3 = target.global_position - global_position
		local = wrapf(atan2(-v.x, -v.z) - rotation.y, -PI, PI)
		tilt = 0.0
	var d := wrapf(local - _toren.rotation.y, -PI, PI)
	_toren.rotation.y += clampf(d, -TURRET_TURN * delta, TURRET_TURN * delta)
	_loop.rotation.x = lerpf(_loop.rotation.x, tilt, delta * 2.0)
	_reload -= delta
	if target and _reload <= 0.0 and absf(d) < 0.12:
		_reload = RELOAD
		_shoot(target.global_position)


## Schiet een granaat: vuur uit de loop, een halve seconde later ontploft hij waar de vijand stond.
func _shoot(at: Vector3) -> void:
	var tip := _loop.global_position - _loop.global_transform.basis.z * 3.4
	Fx.muzzle(get_parent(), tip)
	Fx.dust(get_parent(), tip)
	var boom := at
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		Fx.explosion(get_parent(), boom, 1.0)
		Game.note_blast(boom, SHELL_RADIUS)
		Barrel.catch_blast(boom, 2.0)
		Woonhuis.blast_all(boom, 1.8, 140.0)  # kleiner dan de straal tegen vijanden: alleen de muur waar hij op mikt
		for e in Game.enemies.duplicate():
			var flat: Vector3 = e.global_position - boom if is_instance_valid(e) else Vector3.ZERO
			flat.y = 0.0
			if is_instance_valid(e) and flat.length() < SHELL_RADIUS and SHELL_DAMAGE > 0.0:
				e.hit(SHELL_DAMAGE, (e.global_position - boom).normalized(), true))


## Door jou bestuurd: de linker stick geeft de richting (de tank draait op de plek en rijdt dan door,
## ligt de richting achter hem dan rijdt hij achteruit), de rechter stick richt de koepel.
func _drive_driven(delta: float, live: bool) -> void:
	var mv := Game.move
	var want_speed := 0.0
	var turning := false
	if live and mv.length() > 0.15:
		var want := atan2(-mv.x, -mv.y)
		var diff := wrapf(want - rotation.y, -PI, PI)
		var reverse := absf(diff) > 2.3
		if reverse:
			diff = wrapf(diff - PI, -PI, PI)
		rotation.y += clampf(diff, -DRIVE_TURN * delta, DRIVE_TURN * delta)
		turning = absf(diff) > 0.05
		var align := clampf(1.0 - absf(diff) / 0.9, 0.0, 1.0)
		want_speed = (-DRIVE_REVERSE if reverse else DRIVE_SPEED) * minf(mv.length() * 1.3, 1.0) * align
	_speed = move_toward(_speed, want_speed, 7.0 * delta)
	if absf(_speed) > 0.01:
		velocity = -global_transform.basis.z * _speed
		move_and_slide()
		global_position.y = 0.0
		if get_slide_collision_count() > 0:
			_speed *= 0.5
		var flat := Vector2(global_position.x, global_position.z)
		var clamped := Data.clamp_world(flat)
		if clamped != flat:
			flat = clamped
			global_position = Vector3(flat.x, 0.0, flat.y)
	if absf(_speed) > 0.3:
		_play("Rijden" if _speed > 0.0 else "Achteruit", absf(_speed) / ANIM_SPEED)
	elif turning:
		_play("Draaien", 1.0)
	else:
		_play("Stationair", 1.0)
	var p = Game.player
	p.global_position = Vector3(global_position.x, 0.0, global_position.z)
	p.face = rotation.y + PI
	# koepel
	var local := 0.0
	if live and not is_nan(Game.aim):
		var want_world := atan2(-sin(Game.aim), -cos(Game.aim))
		_pick_lock(Vector2(sin(Game.aim), cos(Game.aim)))
		if not _lock.is_empty():
			var c: Vector3 = _lock_point()
			want_world = atan2(-(c.x - global_position.x), -(c.z - global_position.z))  # koepel draait naar het gekozen muurstuk
		local = wrapf(want_world - rotation.y, -PI, PI)
	else:
		_lock = {}
	var d := wrapf(local - _toren.rotation.y, -PI, PI)
	_toren.rotation.y += clampf(d, -DRIVE_TURRET * delta, DRIVE_TURRET * delta)
	_update_sight(delta)
	_loop.rotation.x = lerpf(_loop.rotation.x, 0.0, delta * 2.0)
	_reload -= delta
	if live and Game.fire and _reload <= 0.0 and absf(d) < 0.15:
		_reload = DRIVE_RELOAD
		_shoot(_aim_point())
	_ram()


## Waar de granaat landt: het eerste dat de loop op zijn weg tegenkomt (muur, huis, bunker, vijand), anders het verste punt.
func _aim_point() -> Vector3:
	if not _lock.is_empty():
		return _lock_point()
	var fwd := -_loop.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best := SHOT_RANGE
	for e in Game.enemies:
		if not is_instance_valid(e):
			continue
		var v: Vector3 = e.global_position - global_position
		v.y = 0.0
		var dist := v.length()
		if dist > 3.0 and dist < best and absf(fwd.angle_to(v)) < 0.1:
			best = dist
	var from := _loop.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * best, Kit.LAYER_WALL | Kit.LAYER_BUNKER | 8)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	# auto's en bussen zijn lager dan de loop: zoek ze op ooghoogte, zodat de granaat óp de auto valt en niet erachter
	var low := Vector3(from.x, 1.0, from.z)
	var v := Bullet.vehicle_on_path(low, low + fwd * best)
	if not v.is_empty() and v.car != self and (not hit or from.distance_to(hit.position) > low.distance_to(v.pos)):
		var vp: Vector3 = v.pos
		return Vector3(vp.x, 0.8, vp.z)
	if hit:
		var at: Vector3 = hit.position
		return Vector3(at.x, clampf(at.y, 0.0, 5.0), at.z)
	return global_position + fwd * best


## Rijdt hij op een vijand voor zijn neus, dan gaat die neer.
func _ram() -> void:
	if _speed < 2.0 or _ram_cd > 0.0:
		return
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var lp := to_local(e.global_position)
		if absf(lp.x) < 2.1 and lp.z < 0.8 and lp.z > -4.2:
			_ram_cd = 0.2
			e.hit(RAM_DAMAGE, -global_transform.basis.z, true)


# ---------------------------------------------------------------- mikken op muurstukken van huizen

## Kiest het muurstuk (buitenkant naar de tank toe) dat het dichtst bij de lijn van je stick ligt; blijft op dat stuk
## zitten zolang het redelijk in de lijn ligt, zodat de koepel niet heen en weer springt.
func _pick_lock(f: Vector2) -> void:
	var here := Vector2(global_position.x, global_position.z)
	if not _lock.is_empty():
		var c: Vector3 = _lock_house.seg_center(_lock)
		if _lock.staat >= 2 or not is_instance_valid(_lock_house) or _side(here, f, c) > LOCK_STICKY or _fwd(here, f, c) < LOCK_FWD_MIN:
			_lock = {}
	if not _lock.is_empty():
		return
	var best := LOCK_SIDE
	for h: Woonhuis in Woonhuis.all:
		if h.global_position.distance_to(global_position) > LOCK_FWD_MAX + 8.0:
			continue
		for s in h.segs:
			if s.staat >= 2 or String(s.name).begins_with("P"):
				continue
			var c: Vector3 = h.seg_center(s)
			var fw := _fwd(here, f, c)
			if fw < LOCK_FWD_MIN or fw > LOCK_FWD_MAX:
				continue
			if h.seg_outward(s).dot(Vector3(here.x - c.x, 0.0, here.y - c.z)) <= 0.0:
				continue  # de binnenkant of achterkant van het huis: de granaat zou er toch tegenaan klappen
			var side := _side(here, f, c) + fw * 0.01
			if side < best:
				best = side
				_lock = s
				_lock_house = h


func _fwd(here: Vector2, f: Vector2, c: Vector3) -> float:
	return (Vector2(c.x, c.z) - here).dot(f)


func _side(here: Vector2, f: Vector2, c: Vector3) -> float:
	var v := Vector2(c.x, c.z) - here
	return absf(v.x * f.y - v.y * f.x)


## Het inslagpunt: het midden van het muurstuk, een tikje voor de buitenkant.
func _lock_point() -> Vector3:
	var c: Vector3 = _lock_house.seg_center(_lock)
	return c + _lock_house.seg_outward(_lock) * 0.15


func _build_sight() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.2, 0.12, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 10
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.material_override = mat
	_line.top_level = true
	_line.visible = false
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_mark = Node3D.new()
	_mark.top_level = true
	_mark.visible = false
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.7
	tm.rings = 20
	tm.ring_segments = 6
	ring.mesh = tm
	ring.rotation.x = PI / 2.0
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.add_child(ring)
	var dot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	dot.mesh = sm
	dot.material_override = mat
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.add_child(dot)
	add_child(_mark)


func _clear_sight() -> void:
	_lock = {}
	if _line:
		_line.visible = false
		_mark.visible = false


## Stippellijn van de loop naar het inslagpunt en een rode ring daar: wat je ziet is wat je raakt.
func _update_sight(delta: float) -> void:
	var fwd := -_loop.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var tip := _loop.global_position - _loop.global_transform.basis.z * 3.4
	var target: Vector3 = _aim_point()
	var out := fwd
	if not _lock.is_empty():
		out = _lock_house.seg_outward(_lock)
	_line.visible = true
	_mark.visible = true
	_mark_t += delta
	_mark.global_position = target
	_mark.look_at(target + out, Vector3.UP)
	_mark.scale = Vector3.ONE * (1.0 + 0.08 * sin(_mark_t * 8.0)) * (1.15 if _lock.is_empty() else 1.0)
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var from := tip
	var to := Vector3(target.x, maxf(target.y, 0.2), target.z)
	var len_ := from.distance_to(to)
	var n := int(len_ / 0.9)
	for i in n:
		var a := from.lerp(to, float(i) / n)
		var b := from.lerp(to, minf((i + 0.55) / n, 1.0))
		_line_mesh.surface_add_vertex(a)
		_line_mesh.surface_add_vertex(b)
	if n > 0:
		_line_mesh.surface_end()
	else:
		_line_mesh.clear_surfaces()
