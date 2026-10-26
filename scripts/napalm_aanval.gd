class_name NapalmAanval
extends Node3D
## Killstreak NAPALM-AANVAL: een straaljager (assets/straaljager.glb) scheert laag over een strook van NAPALM_LENGTH x NAPALM_WIDTH meter
## en laat vier napalmbussen vallen die elk op een vast punt van de strook neerkomen. Elke bus ontploft in een vuurbal en laat
## brandende napalm achter; vijanden die in de strook staan of erin lopen vatten vlam, rennen 5 s panisch rond en vallen dan dood. De speler brandt een beetje mee als hij erin staat.
## Schade telt als "lucht": die kills tellen niet mee voor je eigen streak.

const JET := preload("res://assets/straaljager.glb")
const SPEED := 58.0       # m/s
const HEIGHT := 13.0      # m boven de grond
const LEAD := 80.0        # m voor de strook waar het toestel begint
const FALL_V := 20.0      # m/s vooruitsnelheid van een losgelaten bus
const GRAVITY := 22.0
const BURN_TIME := 9.0
const BURN_RUN := 5.0     # s dat een vijand brandend rondrent voor hij dood neervalt (enemy.gd: ignite)
const SELF_DPS := 8.0
const TICK := 0.25

var center := Vector3.ZERO
var dir := Vector3.FORWARD
var jet: Node3D
var _t := 0.0
var _bombs: Array = []        # [{node, released, hit, at (inslagpunt), s (positie langs de strook waar hij valt)}]
var _impacts: Array[Vector3] = []
var _burn_t := -1.0
var _tick := 0.0
var _fires: Array = []


func start(target: Vector3, d: Vector3) -> void:
	center = Vector3(target.x, 0.0, target.z)
	dir = Vector3(d.x, 0.0, d.z).normalized()
	if dir.length() < 0.1:
		dir = Vector3.FORWARD
	jet = JET.instantiate()
	add_child(jet)
	jet.top_level = true
	jet.scale = Vector3.ONE * 0.8   # 13 m lang: past op het scherm en leest als een toestel boven de strook
	_place(-LEAD - Streak.NAPALM_LENGTH * 0.5)
	jet.rotation.y = atan2(-dir.x, -dir.z)
	var ap: AnimationPlayer = jet.find_child("AnimationPlayer", true, false)
	if ap != null and ap.has_animation("Vliegen"):   # Godot haalt het -loop-achtervoegsel van de clipnaam en laat hem lussen
		ap.play("Vliegen")
	var kinds := ["Bom1", "Bom2", "Bom3", "Bom4"]
	for i in kinds.size():
		var node: Node3D = jet.find_child(kinds[i], true, false)
		var s_along := -Streak.NAPALM_LENGTH * 0.5 + Streak.NAPALM_LENGTH * float(i) / float(kinds.size() - 1)
		_bombs.append({"node": node, "released": false, "hit": false, "s": s_along, "at": center + dir * s_along})
	Game.banner.emit("NAPALM ONDERWEG", "Blijf uit de strook", 1.5)
	Sfx.play("straal", 0.9, center - dir * 40.0)


## Zet het toestel op afstand s (m) langs de strook; s = 0 is het midden.
func _place(s: float) -> void:
	jet.global_position = center + dir * s + Vector3.UP * HEIGHT


func _physics_process(delta: float) -> void:
	if Game.state != "play" and Game.state != "prep":
		return
	_t += delta
	if jet != null:
		var s := -LEAD - Streak.NAPALM_LENGTH * 0.5 + SPEED * _t
		_place(s)
		var lead := FALL_V * sqrt(2.0 * (HEIGHT - 1.0) / GRAVITY)
		for b in _bombs:
			if not b.released and s >= float(b.s) - lead:
				_release(b)
		if s > LEAD + Streak.NAPALM_LENGTH:
			jet.queue_free()
			jet = null
	if not _impacts.is_empty():
		# vanaf de eerste inslag brandt het: wie in een brandende strook staat of erin loopt, vat vlam
		_burn_t = maxf(_burn_t, 0.0) + delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			_burn_damage()
		var all_hit := true
		for b in _bombs:
			if not b.hit:
				all_hit = false
		if all_hit and _burn_t > BURN_TIME and jet == null:
			for f in _fires:
				if is_instance_valid(f):
					f.queue_free()
			queue_free()


func _release(b: Dictionary) -> void:
	b.released = true
	var src: Node3D = b.node
	var bomb := Node3D.new()
	add_child(bomb)
	bomb.top_level = true
	if src != null:
		for c in src.get_children():
			bomb.add_child(c.duplicate())
		src.visible = false
		bomb.global_transform = src.global_transform
	else:
		bomb.global_position = Vector3(b.at.x, HEIGHT - 0.5, b.at.z)
	b["fly"] = bomb
	b["t"] = 0.0
	b["from"] = bomb.global_position
	Sfx.play("click", 0.5, bomb.global_position)


func _process(delta: float) -> void:
	for b in _bombs:
		if b.released and not b.hit and b.has("fly"):
			var bomb: Node3D = b.fly
			b.t += delta
			var fall := sqrt(2.0 * (float(b["from"].y) - 0.3) / GRAVITY)
			var k := clampf(float(b.t) / fall, 0.0, 1.0)
			var flat: Vector3 = (b["from"] as Vector3).lerp(b.at, k)
			bomb.global_position = Vector3(flat.x, float(b["from"].y) * (1.0 - k * k) + 0.3 * k * k, flat.z)
			# de neus draait naar beneden tijdens de val
			bomb.rotation = Vector3(-k * 1.0, atan2(-dir.x, -dir.z), 0.0)
			if k >= 1.0:
				_impact(b)
				bomb.queue_free()


func _impact(b: Dictionary) -> void:
	b.hit = true
	var at: Vector3 = b.at
	_impacts.append(at)
	var parent := get_parent()
	Fx.explosion(parent, at, 0.9)
	Sfx.play("napalm", 1.0, at)
	Game.note_blast(at, 3.5)
	# vuurpoel: drie vlammen op een rij, de middelste met schijnsel
	for i in 3:
		var off := dir * (float(i) - 1.0) * 1.7 + dir.cross(Vector3.UP) * randf_range(-0.8, 0.8)
		var flame := Fx.flame(parent, at + off, randf_range(1.8, 2.6), i == 1)
		_fires.append(flame)
	_fires.append(Fx.burning(parent, at, false))
	Game.alert(at, 16.0, 4.0)


func _in_strip(p: Vector3) -> bool:
	for at: Vector3 in _impacts:
		var d := Vector3(p.x - at.x, 0.0, p.z - at.z)
		var along := d.dot(dir)
		var across := absf(d.dot(dir.cross(Vector3.UP)))
		if absf(along) < 4.4 and across < Streak.NAPALM_WIDTH * 0.5 + 0.8:
			return true
	return false


func _burn_damage() -> void:
	for e in Game.enemies.duplicate():
		if is_instance_valid(e) and not e.dead and _in_strip(e.global_position):
			e.ignite(BURN_RUN)   # in de brandende strook: vlam vat, 5 s rennen, dan neer
	var p = Game.player
	if p != null and is_instance_valid(p) and not p.dead and _in_strip(p.global_position):
		p.hit(SELF_DPS * TICK, dir, false)
