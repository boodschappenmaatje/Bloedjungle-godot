extends SceneTree
## Test: personenauto (kogelpantser, schadefases, brand, ontploffing met kettingreactie, wrak, instappen en rijden).
## Draaien: godot --headless --path . -s tests/auto_test.gd --fixed-fps 60

var main: Node
var frames := 0
var Stad
var A
var cars: Array = []
var bad := 0
var bullets_hp0 := 0.0


func check(name: String, ok: bool) -> void:
	print(("OK    " if ok else "FAIL  ") + name)
	if not ok:
		bad += 1


func _initialize() -> void:
	Stad = load("res://scripts/stad.gd")
	A = load("res://scripts/auto.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 10:
		var lines: Array = [["auto", 0, -96, 0, 0], ["auto", 4, -96, 0, 0], ["auto", 40, -96, 0, 0], ["autowrak", 60, -96, 0, 0], ["autobrand", 80, -96, 0, 0], ["auto", 100, -125, 0, 0]]
		Stad.current.set_items(Stad.from_lines(lines))
		for d in Stad.current.items:
			cars.append(d.node)
		check("6 auto's geplaatst", cars.size() == 6 and cars[0].get_script() == A)
		var a = cars[0]
		check("spelclips: wissers, knipperen, alarm (deuren/kap/koffer zitten in de glb voor de viewer)", a._anim.get_animation_list().size() == 3)
		check("blendshape Deuk", a._romp.mesh.get_blend_shape_count() == 1)
		check("collision op laag van kogels", (a.collision_layer & 2) != 0 and a.get_node("Shape") != null and (a.collision_layer & 2) != 0)
		check("wrak staat al verkoold", cars[3].wreck and cars[3]._romp.get_surface_override_material(0) == cars[3]._wrak_mat)
		check("brandende auto brandt zonder lont", cars[4].burning and cars[4]._fuse == 0.0)
	if frames == 20:
		var a = cars[0]
		# 6 kogels van 26: volle schade (v95)
		for i in 6:
			a.hit(26.0, Vector3.RIGHT, true)
		check("6 pistoolkogels: hp %.0f (verwacht 544)" % a.hp, absf(a.hp - 544.0) < 1.0)
		check("nog niet in brand na 6 kogels", not a.burning and a.stage == 1)
		check("voorruit eruit na de eerste fase", not a._car.get_node("Voorruit").visible)
		# auto ernaast op 4 m blijft heel zolang er geen explosie is
		check("buurauto ongedeerd", cars[1].hp == A.HP)
	if frames == 21:
		# echte kogels van de speler, vlak naast de auto (borstweringstand: over_wall = true) en van verder weg
		var a = cars[1]
		var hp0: float = a.hp
		var B = load("res://scripts/bullet.gd")
		for over in [true, false]:
			B.fire(main, a.global_position + Vector3(-1.9, 1.1, 1.0 if over else -1.0), PI / 2.0, 30.0, 26.0, 1.0, true, over, 0, 0.0, 0.0, 0.0, "")
		B.fire(main, a.global_position + Vector3(-0.5, 1.1, 0.0), PI / 2.0, 30.0, 26.0, 1.0, true, true, 0, 0.0, 0.0, 0.0, "")   # begint binnen de botsdoos
		bullets_hp0 = hp0
	if frames == 30:
		check("echte kogels (ook met over_wall) raken de auto: hp %.0f van %.0f" % [cars[1].hp, bullets_hp0], cars[1].hp <= bullets_hp0 - 30.0)
		var a = cars[0]
		for i in 10:
			a.hit(26.0, Vector3.RIGHT, true)
		check("na 16 kogels: hp %.0f, stage %d, deuk %.2f" % [a.hp, a.stage, a._blend], a.stage >= 3 and a._blend > 0.2)
		check("banden plat", a._flat.size() >= 2)
		check("deur eraf", a._gone.size() >= 1)
		for i in 10:
			a.hit(26.0, Vector3.RIGHT, true)
		check("na 26 kogels brandt hij: hp %.0f" % a.hp, a.burning and not a.exploded)
	if frames == 60:
		var a = cars[0]
		print("lont: ", a._fuse)
	if frames == 700:
		var a = cars[0]
		check("zelf ontploft na de lont", a.exploded and a.wreck)
		check("wrak behoudt collision lager", (a.get_node("Shape").shape as BoxShape3D).size.y < 1.2)
		check("onderdelen vlogen weg", a._gone.size() == 4)
		# kettingreactie: buurauto op 4 m kreeg schade
		check("buurauto kreeg ontploffingsschade: hp %.0f" % cars[1].hp, cars[1].hp < A.HP - 100.0)
		# ontploffing van buiten: raket-achtig op de verre auto
		root.get_node("Game").note_blast(Vector3(40, 0.5, -96), 4.8)
		check("explosie vlakbij: veel schade (hp %.0f)" % cars[2].hp, cars[2].hp < A.HP * 0.6)
		root.get_node("Game").note_blast(Vector3(40, 0.5, -96), 4.8)
		check("tweede explosie: gaat meteen op", cars[2].exploded)
		# rijden
		var d = cars[5]
		var p = root.get_node("Game").player
		p.global_position = d.global_position + Vector3(2.5, 0, 0)
		d._cand = d
		d._cand_ms = Time.get_ticks_msec()
		d._enter()
		check("instappen: bestuurder zit in auto", d.driven and p.driving and A.driven_car == d)
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		root.get_node("Game").move = Vector2(0, -1)   # vooruit
	if frames == 800:
		var d = cars[5]
		var cl = d.get_last_slide_collision()
		print("botst met ", cl.get_collider() if cl else null, " ", cl.get_collider().collision_layer if cl else 0)
		print("state ", root.get_node("Game").state, " move ", root.get_node("Game").move, " rot ", d.rotation.y)
		check("auto rijdt: snelheid %.1f" % d._speed, d._speed > 5.0)
		check("auto is verplaatst: x %.1f" % d.global_position.x, absf(d.global_position.z + 125.0) > 3.0)
		d._exit_player(false)
		root.get_node("Game").move = Vector2.ZERO
		check("uitstappen", not d.driven and not root.get_node("Game").player.driving)
		print("AUTO TEST KLAAR, fouten: ", bad)
		quit(1 if bad > 0 else 0)
		return true
	return false
