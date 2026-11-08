extends SceneTree
## Test van het MCV-model (Dennis' Meshy-wagen) en het uitklappen: de wagen rijdt uit het kamp, blijft als commandokern staan, de clip Uitklappen
## (6 s) speelt, het hoofdkwartier groeit in 20 s met steigers en de wielen draaien en sturen onderweg.
## godot --headless --path . --script tests/mcv_wagen_test.gd --fixed-fps 60

var M: GDScript
var main: Node
var frames := 0
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
	M = load("res://scripts/mcv.gd")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
	if frames == 10:
		mcv = get_nodes_in_group("mcv")[0]
		model = mcv.get_node("Model")
		_check("het model heeft 8 wielen", model.find_children("Wiel_*", "Node3D", true, false).size() == 8)
		_check("de voorwielen sturen (4 stuurknopen)", model.find_children("Stuur_*", "Node3D", true, false).size() == 4)
		_check("de module en vier poten zijn er", model.find_child("Module", true, false) != null and model.find_children("Poot_*", "Node3D", true, false).size() == 4)
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
		_check("er is een bouwplaats (steigers) en het gebouw is nog laag", opb != null and vis.scale.y < vis_scale.y * 0.5)
	if frames == 420:
		# na ~4,5 s: de wagen staat 9,6 m voor het hoofdkwartier en de clip speelt
		var want: Vector3 = hq_at + Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, M.PARK_Z)
		_check("de wagen is uit het kamp gereden en geparkeerd (%.1f m van de plek)" % mcv.global_position.distance_to(want), mcv.global_position.distance_to(want) < 0.3)
		_check("de clip Uitklappen speelt", not model.uitklappen_klaar())
	if frames == 1000:
		# 16 s: de clip is klaar (6 s) en het gebouw is halverwege
		_check("de clip Uitklappen is klaar", model.uitklappen_klaar())
		_check("het schild staat omhoog", absf((model.find_child("Schild", true, false) as Node3D).rotation.x - 0.56) < 0.02)
		_check("het gebouw groeit (tussen laag en hoog)", vis.scale.y > vis_scale.y * 0.3 and vis.scale.y < vis_scale.y * 0.999)
	if frames == 1700:
		# na 28 s: klaar
		var opb2 = main.find_child("Opbouw", true, false)
		_check("het hoofdkwartier is klaar en op volle hoogte", opb2.klaar and is_equal_approx(vis.scale.y, vis_scale.y))
		_check("de steigers zijn weg", main.find_child("Steiger", true, false) == null)
		_check("de wagen blijft staan", is_instance_valid(mcv) and mcv.is_inside_tree())
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
