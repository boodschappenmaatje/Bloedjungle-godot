extends SceneTree
## Test: de speler schiet ECHT (Game.aim + Game.fire, zoals de rechter stick) op een auto en een bus, met elk wapen,
## uit 8 richtingen en op verschillende afstanden, met gewone, gedraaide en gespiegelde auto's (stadseditor).
## Draaien: godot --headless --path . -s tests/auto_raken_test.gd --fixed-fps 60

var main: Node
var G
var frames := 0
var bad := 0
var cases: Array = []
var ci := -1
var t := 0
var hp0 := 0.0
var car: Node3D
var cars := {}
var fails := {}
var total := {}

var WEAPONS := ["m1911", "thompson", "garand", "trench", "mg42", "bazooka"]
const SHOOT_FRAMES := 40


func check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + name)
	if not ok:
		bad += 1


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 10:
		G = root.get_node("Game")
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		var Stad = load("res://scripts/stad.gd")
		# auto's en bussen ver uit elkaar, elk in een andere stand: [soort, x, z, kwartslagen, gespiegeld]
		var lines: Array = [["auto", 0, -96, 0, 0], ["auto", 40, -96, 1, 0], ["auto", 80, -96, 1, 1], ["auto", -40, -96, 2, 1],
				["bus", 0, -150, 0, 0], ["bus", 40, -150, 1, 0], ["bus", 80, -150, 3, 1]]
		Stad.current.set_items(Stad.from_lines(lines))
		var list: Array = []
		for d in Stad.current.items:
			list.append(d.node)
		for w in WEAPONS:
			if not G.owned.has(w):
				G.owned[w] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 50}
			if not G.loadout.has(w):
				G.loadout.append(w)
		for w in WEAPONS:
			for c in list:
				for dist in ([3.2, 7.0] if _is_auto(c) else [4.0, 9.0]):
					for k in 8:
						cases.append({"w": w, "car": c, "dist": dist, "ang": k * TAU / 8.0})
		print("gevallen: ", cases.size())
		_next()
	if frames > 10 and ci < cases.size():
		t += 1
		var p = G.player
		if t == 2:
			G.fire = true
		if t == SHOOT_FRAMES:
			G.fire = false
			var cs: Dictionary = cases[ci]
			var key := "%s %s" % [cs.w, "auto" if _is_auto(cs.car) else "bus"]
			total[key] = total.get(key, 0) + 1
			if car.hp >= hp0 - 0.5:
				fails[key] = fails.get(key, 0) + 1
				print("MIS  ", key, " auto ", car.global_position, " rot ", car.rotation, " expl ", car.exploded, " wrak ", car.wreck, " r=%d m=%d dist %.1f hoek %d" % [roundi(car.rotation.y / (PI / 2.0)), 1 if car.scale.x < 0 else 0, cs.dist, roundi(rad_to_deg(cs.ang))], " speler ", p.global_position, " face ", p.face)
				for e in G.enemies:
					if is_instance_valid(e):
						print("   vijand ", e.global_position)
				print("   game state ", G.state, " aim ", G.aim, " ammo ", p.ammo, " reload ", p.reload_t)
			_next()
		elif t > 1 and t < SHOOT_FRAMES:
			# blijf mikken (zoals de stick vasthouden)
			p.ammo = 50
			p.reload_t = 0.0
	if ci >= cases.size() and frames > 12:
		for k in total:
			check("%s: %d van %d raak" % [k, total[k] - fails.get(k, 0), total[k]], fails.get(k, 0) == 0)
		print("AUTO RAKEN TEST KLAAR, fouten: ", bad)
		quit(1 if bad > 0 else 0)
		return true
	return false


func _next() -> void:
	ci += 1
	t = 0
	G.fire = false
	if ci >= cases.size():
		return
	var cs: Dictionary = cases[ci]
	car = cs.car
	_heal(car)
	hp0 = car.hp
	var p = G.player
	var center: Vector3 = car.global_transform * Vector3(0, 0, 0)
	# de afstand gemeten vanaf de rand van de botsdoos
	var half: Vector3 = (car.get_node("Shape").shape as BoxShape3D).size * 0.5
	var a: float = cs.ang
	var dir := Vector3(sin(a), 0, cos(a))
	var local := car.global_transform.basis.inverse() * dir
	var edge: float = 1.0 / maxf(absf(local.x) / half.x, absf(local.z) / half.z)
	var pos: Vector3 = center + dir * (edge + cs.dist)
	pos.y = 0.0
	p.global_position = pos
	p.velocity = Vector3.ZERO
	G.cur = cs.w
	p.equip(cs.w)
	p.fire_t = 0.0
	var aim := atan2(-dir.x, -dir.z)
	p.face = aim
	p.rotation.y = aim
	G.aim = aim
	G.move = Vector2.ZERO
	for e in G.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	G.enemies.clear()


func _heal(c) -> void:
	c.hp = c.HP
	c.burning = false
	c._fuse = 0.0


func _is_auto(c) -> bool:
	return String(c.get_script().resource_path).ends_with("auto.gd")
