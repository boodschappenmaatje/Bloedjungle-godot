class_name Parachutisten
extends Node3D
## Kracht PARACHUTISTEN (generaalsrang E2, Rang): een transportvliegtuig (assets/c47.glb) vliegt over het gekozen punt en dropt soldaten met een
## parachute (assets/parachute.glb: clips Openen, Zweven-loop, Inzakken). Aantal en soorten staan in Rang.DROP_SOORTEN (4 / 6 / 8 per niveau).
## Na de landing zijn het gewone eigen soldaten (Ally) die HOUD staan. In de lucht zijn ze kwetsbaar: M2-kogels kunnen ze raken.
## Je dropt niet binnen de muur van de vijandbasis: zo'n doel wordt naar buiten geschoven (VijandBasis.contains).

const C47_PAD := "res://assets/c47.glb"          # zwaar OTA-bestand: pas laden als het nodig is
const P47_PAD := "res://assets/p47.glb"          # tijdelijk als er nog geen C-47 is
const PARACHUTE_PAD := "res://assets/parachute.glb"
const SPEED := 26.0       # m/s
const HEIGHT := 17.0      # m boven de grond
const LEAD := 90.0        # m voor het doel waar het toestel begint
const JUMP_EVERY := 0.42  # s tussen twee springers
const FREEFALL := 0.5     # s vrije val voor de parachute opengaat
const OPEN_T := 0.8       # s dat de parachute opengaat (clip Openen)
const SINK := 4.4         # m/s zakken
const LAND_T := 1.2       # s dat de parachute inzakt (clip Inzakken)
const SPREAD_ALONG := 5.0
const SPREAD_SIDE := 3.2

var center := Vector3.ZERO
var dir := Vector3.FORWARD
var kinds: Array = []
var plane: Node3D
var _t := 0.0
var _jumpers: Array = []   # [{ally, kind, land, from, s_jump, state, t, chute}]
var _done := false


## Ververst het doel: niet binnen de vijandmuur. Static zodat de test het direct kan aanroepen.
static func veilig_doel(at: Vector3) -> Vector3:
	var p := Vector3(at.x, 0.0, at.z)
	if not VijandBasis.contains(p, Rang.DROP_STRAAL):
		return p
	var P := VijandBasis.P
	var half := Data.VIJAND_HALF + Vector2(Rang.DROP_STRAAL + 2.0, Rang.DROP_STRAAL + 2.0)
	var d := Vector2(p.x - P.x, p.z - P.z)
	var kx := half.x - absf(d.x)
	var kz := half.y - absf(d.y)
	if kx < kz:
		p.x = P.x + signf(d.x if d.x != 0.0 else 1.0) * half.x
	else:
		p.z = P.z + signf(d.y if d.y != 0.0 else 1.0) * half.y
	return p


static func start_drop(main: Node, at: Vector3, n: int) -> void:
	var d := Parachutisten.new()
	main.add_child(d)
	d.start(at, n)


func start(at: Vector3, n: int) -> void:
	var ground := veilig_doel(at)
	if ground.distance_to(Vector3(at.x, 0.0, at.z)) > 0.5:
		Game.banner.emit("DROPZONE VERPLAATST", "Niet binnen de muur van de vijandbasis", 1.8)
	center = ground
	var from: Vector3 = Game.player.global_position if Game.player != null and is_instance_valid(Game.player) else center + Vector3(0, 0, 60)
	dir = Vector3(center.x - from.x, 0.0, center.z - from.z)
	if dir.length() < 1.0:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	kinds = (Rang.DROP_SOORTEN[clampi(n, 1, 3) - 1] as Array).duplicate()
	var side := dir.cross(Vector3.UP)
	var count := kinds.size()
	for i in count:
		var s_land := -SPREAD_ALONG + 2.0 * SPREAD_ALONG * float(i) / float(maxi(count - 1, 1))
		var land := center + dir * s_land + side * randf_range(-SPREAD_SIDE, SPREAD_SIDE)
		land.y = 0.0
		# springt vroeg genoeg om met de vliegsnelheid mee te dalen en op zijn plek te landen
		var lead := SPEED * (FREEFALL + OPEN_T * 0.5) + 6.0
		_jumpers.append({"kind": kinds[i], "land": land, "s_jump": s_land - lead + randf_range(-0.6, 0.6), "state": "wacht", "t": 0.0, "ally": null, "chute": null, "from": Vector3.ZERO, "fall_t": 0.0})
	var path := C47_PAD if ResourceLoader.exists(C47_PAD) else P47_PAD
	plane = (load(path) as PackedScene).instantiate()
	add_child(plane)
	plane.top_level = true
	if path == P47_PAD:
		plane.scale = Vector3.ONE * 1.5   # tijdelijk: nog geen C-47 in de assets
	_place(-LEAD)
	plane.rotation.y = atan2(-dir.x, -dir.z)
	var ap: AnimationPlayer = plane.find_child("AnimationPlayer", true, false)
	if ap != null and ap.has_animation("Vliegen"):
		ap.play("Vliegen")
	for nm in ["Bom1", "Bom2", "Raket1", "Raket2", "Raket3", "Raket4"]:
		var bomb: Node3D = plane.find_child(nm, true, false)
		if bomb != null and path == P47_PAD:
			bomb.visible = false
	Game.banner.emit("PARACHUTISTEN ONDERWEG", "%d man · landen bij het teken" % count, 1.8)
	Sfx.jet_on()


func _place(s: float) -> void:
	plane.global_position = center + dir * s + Vector3.UP * HEIGHT


func _physics_process(delta: float) -> void:
	if Game.state != "play" and Game.state != "prep":
		Sfx.jet_set(0.0, 1.0)
		return
	_t += delta
	var s := -LEAD + SPEED * _t
	if plane != null:
		_place(s)
		var ear: Vector3 = Game.player.global_position if Game.player != null and is_instance_valid(Game.player) else center
		var d := (ear - plane.global_position).length()
		Sfx.jet_set(1.2 * exp(-d / 55.0) + 0.04, 0.75 + 0.25 * dir.dot((ear - plane.global_position) / maxf(d, 0.1)))
		for j in _jumpers:
			if j.state == "wacht" and s >= float(j.s_jump):
				_jump(j)
		if s > LEAD:
			plane.queue_free()
			plane = null
			Sfx.jet_off()
	var open := false
	for j in _jumpers:
		if j.state == "wacht":
			open = true   # springt nog uit het toestel
		elif j.state != "klaar":
			_step(j, delta)
			open = true
	if plane == null and not open:
		queue_free()


func _jump(j: Dictionary) -> void:
	var a := Ally.new()
	a.kind = j.kind
	var lv := _level()
	add_child(a)
	a.top_level = true
	a.global_position = plane.global_position + Vector3(0, -1.0, 0)
	a.face = atan2(dir.x, dir.z)
	a.setup(float(Buildings.LEVELS[lv].hp), float(Buildings.LEVELS[lv].dmg), Game.allies.size())
	a.rotation.y = a.face
	a.set_physics_process(false)   # tot de landing doet hij niets: hij hangt aan zijn parachute
	Game.allies.append(a)
	j.ally = a
	j.state = "val"
	j.t = 0.0
	j.from = a.global_position
	Sfx.play("click", 0.4, a.global_position)
	Game.changed.emit()


func _level() -> int:
	var lv := 1
	for b in Game.buildings:
		if b.kind == "kazerne":
			lv = maxi(lv, int(b.lv))
	return clampi(lv, 1, Buildings.LEVELS.size() - 1)


func _chute(a: Node3D) -> Node3D:
	var c: Node3D
	if ResourceLoader.exists(PARACHUTE_PAD):
		c = (load(PARACHUTE_PAD) as PackedScene).instantiate()
	else:
		c = _canopy_fallback()
	a.add_child(c)
	c.position = Vector3(0, 1.6, 0)
	return c


## Tijdelijke koepel zolang er nog geen parachute.glb is.
func _canopy_fallback() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.4
	sm.height = 2.4
	sm.is_hemisphere = true
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.5, 0.3)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.position = Vector3(0, 1.8, 0)
	root.add_child(mi)
	return root


func _step(j: Dictionary, delta: float) -> void:
	var a: Ally = j.ally
	if a == null or not is_instance_valid(a):   # neergeschoten in de lucht
		j.state = "klaar"
		if j.chute != null and is_instance_valid(j.chute):
			j.chute.queue_free()
		return
	j.t += delta
	var land: Vector3 = j.land
	match String(j.state):
		"val":   # vrije val, de vlieger gaat nog even met het toestel mee
			var k := clampf(float(j.t) / FREEFALL, 0.0, 1.0)
			var p: Vector3 = (j.from as Vector3) + dir * SPEED * 0.55 * float(j.t) + Vector3.DOWN * (6.0 * float(j.t) * float(j.t))
			a.global_position = p
			a.rotation.x = 0.35 * k
			if float(j.t) >= FREEFALL:
				j.state = "open"
				j.t = 0.0
				j.from = a.global_position
				j.chute = _chute(a)
				_play(j.chute, "Openen")
				Sfx.play("ping", 0.5, a.global_position)
		"open":
			var k2 := clampf(float(j.t) / OPEN_T, 0.0, 1.0)
			_canopy_open(j.chute, k2)
			a.rotation.x = lerpf(0.35, 0.0, k2)
			_drift(a, j, land, delta)
			if float(j.t) >= OPEN_T:
				j.state = "zweef"
				j.t = 0.0
				_play(j.chute, "Zweven")
		"zweef":
			_drift(a, j, land, delta)
			_sway(j.chute, float(j.t))
			if a.global_position.y <= 0.02:
				a.global_position.y = 0.0
				j.state = "inzak"
				j.t = 0.0
				_play(j.chute, "Inzakken")
		"inzak":
			var k3 := clampf(float(j.t) / LAND_T, 0.0, 1.0)
			_canopy_collapse(j.chute, k3)
			if float(j.t) >= LAND_T:
				_land(j)


func _drift(a: Ally, j: Dictionary, land: Vector3, delta: float) -> void:
	var to := Vector3(land.x - a.global_position.x, 0.0, land.z - a.global_position.z)
	var remain := maxf(a.global_position.y, 0.0) / SINK
	var v := to / maxf(remain, 0.25)
	v = v.limit_length(SPEED)
	a.global_position += Vector3(v.x, -SINK, v.z) * delta


func _play(c: Node, clip: String) -> void:
	if c == null:
		return
	var ap: AnimationPlayer = c.find_child("AnimationPlayer", true, false)
	if ap != null:
		if ap.has_animation(clip):
			ap.play(clip)
		elif ap.has_animation(clip + "-loop"):
			ap.play(clip + "-loop")


func _has_clips(c: Node) -> bool:
	return c != null and c.find_child("AnimationPlayer", true, false) != null


func _canopy_open(c: Node3D, k: float) -> void:
	if c == null or _has_clips(c):
		return
	var e := 1.0 - pow(1.0 - k, 3.0)
	c.scale = Vector3(0.25 + 0.75 * e, 0.3 + 0.7 * e, 0.25 + 0.75 * e)


func _sway(c: Node3D, t: float) -> void:
	if c == null or _has_clips(c):
		return
	c.rotation = Vector3(sin(t * 1.7) * 0.06, 0.0, sin(t * 1.3 + 1.0) * 0.07)


func _canopy_collapse(c: Node3D, k: float) -> void:
	if c == null or _has_clips(c):
		return
	c.rotation = Vector3.ZERO
	c.scale = Vector3(1.0 + 0.5 * k, maxf(1.0 - k, 0.05), 1.0 + 0.5 * k)
	c.position.y = lerpf(1.6, 0.2, k)


func _land(j: Dictionary) -> void:
	var a: Ally = j.ally
	j.state = "klaar"
	var pos: Vector3 = a.global_position
	var chute: Node3D = j.chute
	if chute != null and is_instance_valid(chute):
		chute.reparent(get_parent(), true)
		get_tree().create_timer(6.0).timeout.connect(chute.queue_free)
	a.top_level = false
	a.reparent(get_parent(), true)
	a.global_position = Vector3(pos.x, 0.0, pos.z)
	a.rotation = Vector3(0, a.face, 0)
	a.set_physics_process(true)
	a.set_command("hold", a.global_position)
	Fx.dust(get_parent(), a.global_position)
	Game.changed.emit()
