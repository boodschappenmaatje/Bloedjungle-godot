class_name BaseProps
## Het hoofdkwartier van je kamp: de bunkerbody (schadescript en botsblok) met het HK-model, de zandzakkenring en het voorplein. Het komt uit de wagen
## (mcv.gd). Sinds stap 4b (Generals-plan) bestaat het vaste kamp met muur, poorten en torens niet meer: muren, poorten en torens bouw je zelf
## (kampmuur.gd, gates.gd, de wachttoren in buildings.gd).

const BUNKER_GAME_ASSET_PAD := "res://assets/tests/bunker/bloedjungle_bunker_hq.glb"  # zwaar OTA-bestand: pas laden als het nodig is (zie tests/ota_vroeg_test.gd)
const BUNKER_COLLISION_SIZE := Vector3(4.6, 2.0, 4.6)
const BASE_WALL_ASSET := "res://assets/base_wall_hq2.glb"   # de muurmodule van de kampmuur (kampmuur.gd)


## Het hoofdkwartier (bunkerbody met schadescript, HK-model, zandzakkenring en voorplein) onder `root`, dat al op de plek en in de draaiing van de
## uitgeklapte wagen staat. Alles staat in de lokale coordinaten van `root` (deur naar +Z).
static func build_hq(root: Node3D) -> void:
	_bunker(root)


static func _bunker(root: Node3D) -> void:
	# Keep the original gameplay body exactly: same layer, 4.6 × 2 × 4.6 m box,
	# position, damage script and FX anchors. Only the visual child is replaced.
	var b := StaticBody3D.new()
	b.name = "Bunker"
	b.collision_layer = Kit.LAYER_BUNKER
	b.collision_mask = 0
	b.set_script(preload("res://scripts/bunker.gd"))
	b.set_process(true)
	var collision := CollisionShape3D.new()
	collision.name = "BunkerCollision"
	var shape := BoxShape3D.new()
	shape.size = BUNKER_COLLISION_SIZE
	collision.shape = shape
	collision.position.y = BUNKER_COLLISION_SIZE.y / 2.0
	b.add_child(collision)
	# Het hoofdkwartier (assets/hoofdkwartier.glb) staat op de plek van de bunker; model 5,0 m x 0,92 = 4,6 m botsblok.
	var visual := Node3D.new()
	visual.name = "Hoofdkwartier"
	visual.set_script(preload("res://scripts/hoofdkwartier.gd"))
	b.add_child(visual)
	root.add_child(b)
	# zandzakkenring met een opening bij de deur
	var r := 3.6
	Kit.sandbags(root, Vector3(-r, 0, -r), Vector3(r, 0, -r), 2, 21)
	Kit.sandbags(root, Vector3(-r, 0, r), Vector3(-r, 0, -r), 2, 22)
	Kit.sandbags(root, Vector3(r, 0, -r), Vector3(r, 0, r), 2, 23)
	Kit.sandbags(root, Vector3(-r, 0, r), Vector3(0.1, 0, r), 2, 24)
	root.add_child(HqOmgeving.new())   # voorplein met belijning, lichtmasten, afzetblokken, vaten en kisten
