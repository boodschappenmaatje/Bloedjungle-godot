extends SceneTree
## Test van het MCV-model (Dennis' Meshy-wagen) en het uitklappen: de wagen rijdt uit het kamp, blijft als commandokern staan, de clip Uitklappen
## (6 s) speelt, de kraan hijst 8 platen op het groeiende hoofdkwartier (35 s), de container zakt weg en de wielen draaien en sturen onderweg.
## godot --headless --path . --script tests/mcv_wagen_test.gd --fixed-fps 60

var M: GDScript
var main: Node
var frames := 0
var raw := 0
var started := false
var fails := 0
var mcv: Node
var model
var hq_at := Vector3.ZERO
var yaw := 0.0
var vis: Node3D
var vis_scale := Vector3.ONE
var wheel: Node3D
var steer: Node3D
var steer_max := 0.0


func _initialize() -> void:
	load("res://scripts/data.gd").set("mcv_mode", true)
	load("res://scripts/data.gd").set("mcv_autodeploy", false)
	M = load("res://scripts/mcv.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	var g = root.get_node("Game")
	if not started:
		raw += 1
		if raw == 2:
			main.get_node("Hud/Sticks").set_process(false)
		if raw == 4:
			main.begin()
		if get_nodes_in_group("mcv").is_empty():
			return false   # de wereld (met vijandbasis) wordt gefaseerd gebouwd: wacht op de wagen
		started = true
		frames = 9
	frames += 1
	if frames == 10:
		mcv = get_nodes_in_group("mcv")[0]
		model = mcv.get_node("Model")
		_check("het model heeft 8 wielen", model.find_children("Wiel_*", "Node3D", true, false).size() == 8)
		_check("de voorwielen sturen (4 stuurknopen)", model.find_children("Stuur_*", "Node3D", true, false).size() == 4)
		_check("de module en vier poten zijn er", model.find_child("Module", true, false) != null and model._poten.size() == 4)
		var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_check("clip Uitklappen is 6 s", ap != null and ap.has_animation("Uitklappen") and absf(ap.get_animation("Uitklappen").length - 6.0) < 0.05)
		wheel = model.find_child("Wiel_A3R", true, false)
		steer = model.find_child("Stuur_A1L", true, false)
		mcv.global_position = Vector3(40.0, 0.0, 40.0)
		g.move = Vector2(-1, 0)    # stick naar links: de wagen draait en rijdt
	if frames > 10 and frames < 100 and is_instance_valid(steer):
		steer_max = maxf(steer_max, absf(steer.rotation.y))
	if frames == 100:
		_check("de wielen draaien tijdens het rijden", absf(wheel.rotation.x) > 0.5)
		_check("de voorwielen sturen in de bocht", steer_max > 0.02)
		g.move = Vector2.ZERO
	if frames == 140:
		mcv.rotation.y = 0.0
		mcv.global_position = Vector3(40.0, 0.0, 40.0)
	if frames == 150:
		hq_at = mcv.global_position
		yaw = mcv.rotation.y
		mcv.deploy_now()
		vis = main.find_child("Bunker", true, false).get_node("Hoofdkwartier") as Node3D
		vis_scale = Vector3(0.92, 0.92, 0.92)   # Hoofdkwartier.MODEL_SCALE: het gebouw zelf op volle hoogte
	if frames == 156:
		_check("de wagen is geen bestuurbaar voertuig meer", get_nodes_in_group("mcv").is_empty() and get_nodes_in_group("mcv_wagen").size() == 1)
		_check("het hoofdkwartier staat op de wagenplek", g.base_pos.distance_to(hq_at) < 0.01)
		var opb := main.find_child("Opbouw", true, false)
		_check("de bouw wacht op het uitklappen: gebouw en voorplein nog verborgen", opb != null and not opb.begonnen and not vis.visible and not main.find_child("Voorplein", true, false).visible)
		_check("de kraan zit vast op de wagen en staat in transportstand (stempels in, platen in het rek)", model.kraan != null and model.kraan.is_inside_tree() and model.kraan.platen.size() == 8 and (model.kraan._stempels[0].balk as Node3D).scale.x < 0.1 and model.kraan.in_haak() == -1)
		_check("de container is los van de wagen (kantelt op de laadbak)", model.container_los() and model.container_pos().y > 1.4 and model.container_pos().y < 2.6)
	if frames == 1225:
		# deploy + 1,3 s tillen + ~4 s wegrijden: de wagen staat 9,6 m voor het hoofdkwartier, de container staat op de grond en de clip speelt
		var want: Vector3 = hq_at + Basis(Vector3.UP, yaw) * Vector3(M.PARK_X, 0.0, M.PARK_EIND_Z)
		_check("de wagen is uit het kamp gereden en geparkeerd (%.1f m van de plek)" % mcv.global_position.distance_to(want), mcv.global_position.distance_to(want) < 0.3)
		var c: Vector3 = model.container_pos()
		_check("de container is achtergebleven op de bouwplek, op de grond (y %.2f)" % c.y, absf(c.y) < 0.05 and Vector2(c.x - hq_at.x, c.z - hq_at.z).length() < 2.2)
		_check("de clip Uitklappen speelt", not model.uitklappen_klaar())
	if frames == 1700:
		# de clip is klaar en de bouw is begonnen: het voorplein komt omhoog en de kraan staat op de laadbak
		var opb1 = main.find_child("Opbouw", true, false)
		_check("de clip Uitklappen is klaar", model.uitklappen_klaar())
		_check("het schild staat omhoog", absf((model.find_child("Schild", true, false) as Node3D).rotation.x - 0.56) < 0.02)
		var dak := model.find_child("Dak_L", true, false) as Node3D
		_check("de dakpanelen zijn open geklapt (180 graden om het scharnier)", absf(dak.transform.basis.x.x + 1.0) < 0.05)
		_check("het baken knippert oranje tijdens de bouw", model._baken_modus == 1)
		_check("de bouw is begonnen met gebouw en voorplein", opb1.begonnen and vis.visible)
		var plein1: Node3D = main.find_child("Voorplein", true, false)
		_check("het voorplein komt omhoog uit de grond", plein1.visible and plein1.position.y < -0.5)
		_check("de kraan staat op de wagen", mcv.find_child("Kraan", true, false) != null and mcv.find_child("Plaat8", true, false) != null)
		_check("er zijn bouwers aan het werk", get_nodes_in_group("mcv_bouwer").size() == 3)
	if frames == 2200:
		_check("de stempels staan uit en de poten op de grond", absf((model.kraan._stempels[0].balk as Node3D).scale.x - 1.0) < 0.01 and absf((model.kraan._stempels[0].poot as Node3D).scale.z - model.kraan.POOT_LENGTE) < 0.01)
		var opb3 = main.find_child("Opbouw", true, false)
		_check("de kraan heeft de eerste plaat geplaatst en het gebouw groeit", opb3._geland >= 0 and vis.scale.y > vis_scale.y * 0.1 and vis.scale.y < vis_scale.y * 0.999)
	if frames == 2900:
		var opb4 = main.find_child("Opbouw", true, false)
		_check("de kraan werkt door (laag %d)" % (opb4._geland + 1), opb4._geland >= 3 and not opb4.klaar)
		_check("het voorplein staat op de grond", absf((main.find_child("Voorplein", true, false) as Node3D).position.y) < 0.01)
	if frames == 3800:
		# na ~38 s: klaar
		var opb2 = main.find_child("Opbouw", true, false)
		_check("het hoofdkwartier is klaar en op volle hoogte", opb2.klaar and is_equal_approx(vis.scale.y, vis_scale.y))
		_check("het baken is groen als alles klaar is", model._baken_modus == 2)
		_check("alle acht platen zijn geplaatst", opb2._geland == 7)
		_check("de haak bereikte elk doel (grootste afwijking %.2f m)" % opb2.max_fout, opb2.max_fout < 0.6)
		_check("de wagen staat nog (hij vertrekt pas na de container)", is_instance_valid(mcv) and mcv.is_inside_tree())
	if frames == 4100:
		_check("de container is weggezakt en de bouwers zijn naar binnen", not (model._module as Node3D).visible and get_nodes_in_group("mcv_bouwer").is_empty())
	if frames == 4600:
		var opbv = main.find_child("Opbouw", true, false)
		_check("de wagen is aan het vertrekken of al weg", opbv._rijdt or opbv.vertrokken)
	if frames == 6300:
		var opbw = main.find_child("Opbouw", true, false)
		_check("de wagen is uit beeld gereden en dan pas weggehaald", opbw.vertrokken and not is_instance_valid(mcv))
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
