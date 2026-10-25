extends SceneTree
## Test: stadsbus (kogelpantser, schadefases, brand, grote ontploffing met kettingreactie, wrak, instappen en rijden, echte kogels).
## Draaien: godot --headless --path . -s tests/bus_test.gd --fixed-fps 60

var main: Node
var frames := 0
var Stad
var B
var buses: Array = []
var bad := 0
var hp0 := 0.0
var car_hp0 := 0.0


func check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + name)
	if not ok:
		bad += 1


func _initialize() -> void:
	Stad = load("res://scripts/stad.gd")
	B = load("res://scripts/bus.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 10:
		var lines: Array = [["bus", 0, -96, 0, 0], ["bus", 7, -96, 0, 0], ["bus", 60, -96, 0, 0], ["buswrak", 90, -96, 0, 0], ["busbrand", 120, -96, 0, 0], ["bus", 150, -125, 0, 0], ["auto", 2.5, -108, 1, 0]]
		Stad.current.set_items(Stad.from_lines(lines))
		for d in Stad.current.items:
			buses.append(d.node)
		check("7 voertuigen geplaatst", buses.size() == 7 and buses[0].get_script() == B)
		var a = buses[0]
		check("spelclips: wissers, knipperen, alarm, lichten aan", a._anim.get_animation_list().size() == 4)
		check("blendshape Deuk", a._romp.mesh.get_blend_shape_count() == 1)
		check("kogellaag en muurlaag", (a.collision_layer & 2) != 0 and (a.collision_layer & 1024) != 0)
		check("wrak staat al verkoold", buses[3].wreck and buses[3]._romp.get_surface_override_material(0) == buses[3]._wrak_mat)
		check("brandende bus brandt zonder lont", buses[4].burning and buses[4]._fuse == 0.0)
		check("bus is groot: botsdoos 10,6 m", absf((a.get_node("Shape").shape as BoxShape3D).size.z - 10.6) < 0.01)
	if frames == 15:
		# echte kogels van de speler, vlak naast de bus (borstweringstand) en vanuit de botsdoos
		var a = buses[1]
		hp0 = a.hp
		var Bu = load("res://scripts/bullet.gd")
		for over in [true, false]:
			Bu.fire(main, a.global_position + Vector3(-2.9, 1.3, 2.0 if over else -2.0), PI / 2.0, 30.0, 26.0, 1.0, true, over, 0, 0.0, 0.0, 0.0, "")
		Bu.fire(main, a.global_position + Vector3(-0.5, 1.3, 0.0), PI / 2.0, 30.0, 26.0, 1.0, true, true, 0, 0.0, 0.0, 0.0, "")
	if frames == 25:
		check("echte kogels (ook met over_wall) raken de bus: hp %.0f van %.0f" % [buses[1].hp, hp0], buses[1].hp <= hp0 - 3.0 * 26.0 * B.BULLET_ARMOR + 0.5)
		var a = buses[0]
		for i in 30:
			a.hit(26.0, Vector3.RIGHT, true)
		check("30 pistoolkogels: hp %.0f (verwacht %.0f)" % [a.hp, B.HP - 30 * 26.0 * B.BULLET_ARMOR], absf(a.hp - (B.HP - 30 * 26.0 * B.BULLET_ARMOR)) < 1.0)
		check("buurbus op 7 m ongedeerd (buiten schade)", buses[2].hp == B.HP)
	if frames == 30:
		var a = buses[0]
		for i in 21:
			a.hit(26.0, Vector3.RIGHT, true)
		check("na 51 kogels: hp %.0f, stage %d, deuk %.2f" % [a.hp, a.stage, a._blend], a.stage >= 3 and a._blend > 0.2)
		check("banden plat", a._flat.size() >= 2)
		check("ruiten eruit", not a._car.get_node("Voorruit").visible and not a._car.get_node("RuitenR").visible)
		check("deur eraf", a._gone.size() >= 1)
		check("na 51 kogels brandt hij (onder 30%%): hp %.0f" % a.hp, a.burning and not a.exploded)
	if frames == 800:
		var a = buses[0]
		check("zelf ontploft na de lont", a.exploded and a.wreck)
		check("wrak behoudt collision lager", (a.get_node("Shape").shape as BoxShape3D).size.y < 2.5)
		check("onderdelen vlogen weg (4 deuren + luik + dakdelen)", a._gone.size() >= 8)
		check("kettingreactie: buurbus op 7 m kreeg schade: hp %.0f" % buses[1].hp, buses[1].hp < B.HP - 400.0)
		check("auto op 10 m raakte beschadigd: hp %.0f" % buses[6].hp, buses[6].hp < 700.0 - 50.0)
		root.get_node("Game").note_blast(Vector3(60, 0.5, -96), 4.8)
		check("explosie vlakbij: forse schade (hp %.0f)" % buses[2].hp, buses[2].hp < B.HP * 0.65)
		for i in 3:
			root.get_node("Game").note_blast(Vector3(60, 0.5, -96), 4.8)
		check("herhaalde explosies: gaat op", buses[2].exploded)
		var d = buses[5]
		var p = root.get_node("Game").player
		p.global_position = d.global_position + Vector3(4.0, 0, 0)
		d._cand = d
		d._cand_ms = Time.get_ticks_msec()
		d._enter()
		check("instappen: bestuurder zit in bus", d.driven and p.driving and B.driven_car == d)
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		root.get_node("Game").move = Vector2(0, -1)
	if frames == 1000:
		var d = buses[5]
		check("bus rijdt: snelheid %.1f" % d._speed, d._speed > 4.0)
		check("bus is verplaatst", absf(d.global_position.z + 125.0) > 4.0)
		check("bus langzamer dan de auto (max %.1f < 17)" % B.SPEED, B.SPEED < 17.0 and d._speed <= B.SPEED)
		d._exit_player(false)
		root.get_node("Game").move = Vector2.ZERO
		check("uitstappen", not d.driven and not root.get_node("Game").player.driving)
		print("BUS TEST KLAAR, fouten: ", bad)
		quit(1 if bad > 0 else 0)
		return true
	return false
