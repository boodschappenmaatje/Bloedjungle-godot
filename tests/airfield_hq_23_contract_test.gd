extends Node
## Contract checks for the Airfield HQ build reservation and safe asset-gated P-47 purchase.

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = get_tree().root.get_node_or_null("Game")
	assert(game != null, "The project Game autoload must be available to the contract test")
	assert(Buildings.DEFS.has("airfield"), "Airfield build card definition must exist")
	assert(BuildMode.ORDER.has("airfield"), "The airfield card must appear in the existing build menu")
	assert(Buildings.DEFS.airfield.cost == 2800, "Airfield cost must remain centralized at 2,800")
	assert(Buildings.DEFS.airfield.max == 1, "Only one airfield is allowed per base")
	assert(is_equal_approx(AirfieldHQ23.BASE_GROUND_SIZE.x, 56.65) and is_equal_approx(AirfieldHQ23.BASE_GROUND_SIZE.y, 56.95), "Base ground size must use the exact authored BaseProps wall extents")
	assert(is_equal_approx(AirfieldHQ23.MAX_GROUND_AREA, 6452.435), "Area ceiling must equal exactly twice the authored base ground area")
	assert(AirfieldHQ23.footprint_area() <= AirfieldHQ23.MAX_GROUND_AREA, "The conservative sum of constructed regions must stay within twice the base area")
	assert(is_equal_approx(AirfieldHQ23.footprint_area(), 5160.9318), "The conservative layout-area bound must include the fixed buildings, 75x18 runway, apron, and taxi end coverage")
	assert(is_equal_approx(AirfieldFlightIntegration.RUNWAY_LENGTH_M, 75.0), "The revised runway must be exactly 75 m long")
	assert(is_equal_approx(AirfieldFlightIntegration.RUNWAY_WIDTH_M, 18.0), "The revised runway must be exactly 18 m wide")
	assert(AirfieldHQ23.RUNWAY_END_X - AirfieldHQ23.RUNWAY_START_X == AirfieldFlightIntegration.RUNWAY_LENGTH_M, "Runway slab span must match route/runway configuration")
	assert(absf(AirfieldHQ23.RUNWAY_START_X) <= AirfieldHQ23.FOOTPRINT.x * 0.5 and absf(AirfieldHQ23.RUNWAY_END_X) <= AirfieldHQ23.FOOTPRINT.x * 0.5, "Runway longitudinal bounds must be within the airport's map-view bounds")
	assert(absf(AirfieldHQ23.RUNWAY_CENTER_Z) + AirfieldFlightIntegration.RUNWAY_WIDTH_M * 0.5 <= AirfieldHQ23.FOOTPRINT.z * 0.5, "Runway cross-section must be within the airport's map-view bounds")
	assert(AirfieldHQ23.AIRCRAFT.p47.cost == 1800, "P-47 price must remain centralized at 1,800")
	assert(not ResourceLoader.exists(AirfieldHQ23.P47_SCENE), "No surrogate P-47 scene may be present")
	assert(AirfieldHQ23.shop_status("p47").contains("uitgesteld tot na de iPhone-vliegveldtest") and AirfieldHQ23.shop_status("p47").contains("origineel Meshy Pro-model ontbreekt"), "P-47 purchase must remain explicitly deferred and disclose the missing model")
	game.points = 5000
	var candidate := {"kind": "airfield", "down": false, "hp": 3000.0, "aircraft": []}
	var points_before: int = int(game.points)
	assert(not AirfieldHQ23.can_buy(null, candidate, "p47"), "Missing model must prevent charge and purchase")
	assert(game.points == points_before, "A blocked model purchase must not deduct points")
	var shop_building := {"kind": "airfield", "down": false, "hp": 2400.0, "max_hp": 3000.0, "aircraft": [], "aircraft_capacity": 1}
	game.buildings.append(shop_building)
	var shop_builds := Buildings.new()
	add_child(shop_builds)
	game.builds = shop_builds
	var shop_panel := GarageMenu.new()
	add_child(shop_panel)
	await get_tree().process_frame
	shop_panel._sel = shop_building
	shop_panel._refresh()
	assert(shop_panel._panel.visible, "Tapping a placed airfield must open the existing garage-style shop panel")
	var shop_text := ""
	for label in shop_panel._box.find_children("*", "Label", true, false):
		shop_text += (label as Label).text + "\n"
	assert(shop_text.contains("VLIEGVELD — VLIEGTUIGHANGAR"), "Airfield shop must show the required title")
	assert(shop_text.contains("schade 20%") and shop_text.contains("Vliegtuigplaatsen: 0 / 1"), "Shop must show building damage and available capacity")
	assert(shop_text.contains("uitgesteld tot na de iPhone-vliegveldtest") and shop_text.contains("origineel Meshy Pro-model ontbreekt"), "Shop must disclose that the purchase is deferred and the source model is missing")
	var p47_button: Button
	for button in shop_panel._box.find_children("*", "Button", true, false):
		if (button as Button).text.contains("Thunderbolt"):
			p47_button = button as Button
	assert(p47_button != null and p47_button.disabled and p47_button.text.contains("1800 pt"), "Missing P-47 must remain visibly priced but disabled")
	game.buildings.erase(shop_building)
	shop_panel.free()
	game.builds = null
	shop_builds.free()
	var builder := Buildings.new()
	add_child(builder)
	await get_tree().process_frame
	assert(builder.can_place("airfield", AirfieldHQ23.SUGGESTED_CENTER, 0.0), "A valid free-map site outside protected areas should be accepted")
	assert(not builder.can_place("airfield", Vector3.ZERO, 0.0), "The protected base and enemy spawn zone must be rejected")
	assert(not builder.can_place("airfield", Vector3(180.0, 0.0, -190.0), 0.0), "The full footprint must stay inside world bounds")
	assert(AirfieldHQ23.site_clear_of_river(AirfieldHQ23.SUGGESTED_CENTER, 0.0), "Suggested free-map site must clear the river")
	assert(AirfieldHQ23.site_clear_of_south_gate_route(AirfieldHQ23.SUGGESTED_CENTER, 0.0), "Suggested site south of the base must preserve the gate route")
	assert(AirfieldHQ23.SUGGESTED_CENTER.z > Data.COMPOUND and AirfieldHQ23.SUGGESTED_CENTER.z < Data.WORLD_Z_S, "The default preview must be on playable terrain south of the base")
	assert(not AirfieldHQ23.site_clear_of_river(Vector3(0.0, 0.0, Data.RIVER_Z0), 0.0), "River overlap must be rejected")
	assert(AirfieldHQ23.site_inside_world(Vector3(120.0, 0.0, 20.0), PI * 0.5), "A rotated footprint may fit where the full rectangle clears the world edge")
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = Kit.LAYER_WALL
	var obstacle_shape := CollisionShape3D.new()
	var obstacle_box := BoxShape3D.new()
	obstacle_box.size = Vector3(2.0, 2.0, 2.0)
	obstacle_shape.shape = obstacle_box
	obstacle.add_child(obstacle_shape)
	obstacle.position = AirfieldHQ23.SUGGESTED_CENTER + Vector3(0.0, 0.6, 0.0)
	add_child(obstacle)
	await get_tree().physics_frame
	assert(not builder.can_place("airfield", AirfieldHQ23.SUGGESTED_CENTER, 0.0), "A wall collision anywhere in the footprint must reject placement")
	obstacle.free()
	await get_tree().physics_frame
	assert(builder.can_place("airfield", Vector3(120.0, 0.0, 20.0), PI * 0.5), "A rotated full footprint must be accepted at a clear site")
	# Model a palm with near/far/shadow MultiMesh slots and a separate grass instance.
	# The footprint query must ignore clearable palms, while placement removes only
	# entries within actual construction lobes and retains off-footprint instances.
	Foliage._vegetation_cells.clear()
	Foliage._vegetation_serial = 0
	Foliage._root = null
	Foliage._reg.clear()
	Foliage.trees.clear()
	var tree_at := AirfieldHQ23.SUGGESTED_CENTER + Vector3(AirfieldHQ23.HANGAR_CENTER.x, 0.0, AirfieldHQ23.HANGAR_CENTER.y)
	var tree_near := StaticBody3D.new()
	tree_near.collision_layer = Kit.LAYER_NATURE
	tree_near.set_meta("clearable_vegetation", true)
	tree_near.set_meta("vegetation_kind", "palm")
	var tree_shape := CollisionShape3D.new()
	var tree_cylinder := CylinderShape3D.new()
	tree_cylinder.radius = 0.35
	tree_cylinder.height = 2.2
	tree_shape.shape = tree_cylinder
	tree_shape.position = tree_at + Vector3(0.0, 1.1, 0.0)
	tree_near.add_child(tree_shape)
	add_child(tree_near)
	var tree_mm_nodes: Array[MultiMeshInstance3D] = []
	var tree_slots: Array[Dictionary] = []
	for _lod in 3:
		var tree_mm_node := MultiMeshInstance3D.new()
		var tree_mm := MultiMesh.new()
		tree_mm.transform_format = MultiMesh.TRANSFORM_3D
		tree_mm.mesh = BoxMesh.new()
		tree_mm.instance_count = 1
		tree_mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, tree_at))
		tree_mm_node.multimesh = tree_mm
		add_child(tree_mm_node)
		tree_mm_node.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, tree_at))
		tree_mm_nodes.append(tree_mm_node)
		tree_slots.append({"multimesh": tree_mm, "index": 0})
	var tree_key := Vector2i(floori(tree_at.x / Foliage.VEG_CELL), floori(tree_at.z / Foliage.VEG_CELL))
	var tree_entry := {"kind": "palm", "local_position": tree_at, "slots": tree_slots, "shapes": [tree_shape], "tracks_tree": true, "reg_key": tree_key}
	Foliage._register_vegetation(tree_entry)
	Foliage._reg[tree_key] = [tree_entry]
	var grass_at := AirfieldHQ23.SUGGESTED_CENTER + Vector3(AirfieldHQ23.APRON_CENTER.x, 0.0, AirfieldHQ23.APRON_CENTER.y)
	var grass_nodes: Array[MultiMeshInstance3D] = []
	var grass_slots: Array[Dictionary] = []
	for _lod in 3:
		var grass_node := MultiMeshInstance3D.new()
		var grass_mm := MultiMesh.new()
		grass_mm.transform_format = MultiMesh.TRANSFORM_3D
		grass_mm.mesh = BoxMesh.new()
		grass_mm.instance_count = 1
		grass_mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, grass_at))
		grass_node.multimesh = grass_mm
		add_child(grass_node)
		grass_node.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, grass_at))
		grass_nodes.append(grass_node)
		grass_slots.append({"multimesh": grass_mm, "index": 0})
	var grass_entry: Dictionary = Foliage.register_grass_instance(grass_at, grass_slots)
	var outside_at := Vector3(160.0, 0.0, 160.0)
	var outside_mm_node := MultiMeshInstance3D.new()
	var outside_mm := MultiMesh.new()
	outside_mm.transform_format = MultiMesh.TRANSFORM_3D
	outside_mm.mesh = BoxMesh.new()
	outside_mm.instance_count = 1
	outside_mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, outside_at))
	outside_mm_node.multimesh = outside_mm
	add_child(outside_mm_node)
	outside_mm_node.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, outside_at))
	var outside_entry: Dictionary = Foliage.register_grass_instance(outside_at, [{"multimesh": outside_mm, "index": 0}])
	var clear_count := Foliage.count_clearable_in_regions(AirfieldHQ23.site_regions(), AirfieldHQ23.SUGGESTED_CENTER, 0.0)
	assert(clear_count == 2, "Only the palm and grass instances within the paved and building regions should be selected for clearance")
	var invalid_status: Dictionary = builder.placement_status("airfield", Vector3.ZERO, 0.0)
	assert(not invalid_status.valid and invalid_status.reason == "Vijandelijke spawnzone", "Protected base/spawn locations must report a specific rejection")
	assert(not tree_entry.cleared and not tree_shape.disabled, "Preview and cancellation must not remove trees or collisions")
	if DisplayServer.get_name() != "headless":
		assert(tree_mm_nodes[0].multimesh.get_instance_transform(0).origin.is_equal_approx(tree_at), "Preview must leave the actual palm instance in place")
		assert(grass_nodes[0].multimesh.get_instance_transform(0).origin.is_equal_approx(grass_at), "Preview must leave the grass instance in place")
	game.points = 0
	game.build_credit = 0
	assert(builder.placement_status("airfield", AirfieldHQ23.SUGGESTED_CENTER, 0.0).valid and not game.can_afford_build(AirfieldHQ23.BUILD_COST), "Geometric validity must be independent of insufficient funds")
	assert(builder.place("airfield", AirfieldHQ23.SUGGESTED_CENTER, 0.0) == null, "Insufficient funds must reject a build before clearance")
	assert(not tree_entry.cleared and not tree_shape.disabled, "Unaffordable construction must leave vegetation intact")
	if DisplayServer.get_name() != "headless":
		assert(tree_mm_nodes[0].multimesh.get_instance_transform(0).origin.is_equal_approx(tree_at), "Unaffordable construction must leave the actual palm instance in place")
		assert(grass_nodes[0].multimesh.get_instance_transform(0).origin.is_equal_approx(grass_at), "Unaffordable construction must leave the grass instance in place")
	game.points = 2800
	var vegetation_build: Variant = builder.place("airfield", AirfieldHQ23.SUGGESTED_CENTER, 0.0)
	assert(vegetation_build != null and game.points == 0, "Valid construction through the payment system must charge exactly once")
	assert(tree_entry.cleared and int(tree_entry.get("hidden_slot_count", 0)) == 3, "Confirmed placement must hide every registered palm LOD and shadow slot")
	assert(grass_entry.cleared and int(grass_entry.get("hidden_slot_count", 0)) == 3, "Confirmed placement must hide grass from all three LODs")
	assert(not outside_entry.cleared and Foliage._vegetation_cells.has(outside_entry.vegetation_cell), "Vegetation outside construction regions must remain registered and untouched")
	if DisplayServer.get_name() != "headless":
		assert(tree_mm_nodes[0].multimesh.get_instance_transform(0).origin.y < -999.0, "The nearby palm instance must be removed on confirmed placement")
		assert(tree_mm_nodes[1].multimesh.get_instance_transform(0).origin.y < -999.0 and tree_mm_nodes[2].multimesh.get_instance_transform(0).origin.y < -999.0, "All tree LOD variants must remain cleared")
		assert(grass_nodes[0].multimesh.get_instance_transform(0).origin.y < -999.0 and grass_nodes[1].multimesh.get_instance_transform(0).origin.y < -999.0 and grass_nodes[2].multimesh.get_instance_transform(0).origin.y < -999.0, "Grass must be cleared from every rendered LOD")
		assert(outside_mm.get_instance_transform(0).origin.is_equal_approx(outside_at), "Outside foliage transforms must remain unchanged")
	await get_tree().physics_frame
	assert(tree_shape.disabled, "The cleared palm collision must be disabled")
	assert(Foliage.trees.is_empty() and not Foliage._reg.has(tree_key), "Cleared trees must leave gameplay and spatial tree registries")
	assert(Foliage._building_clearings.has(vegetation_build.node.get_instance_id()), "Placed buildings must retain their clearance for a world rebuild")
	var vegetation_sale_value: int = builder.sell_value(vegetation_build)
	builder.sell(vegetation_build)
	assert(not Foliage._building_clearings.has(vegetation_build.node.get_instance_id()) and game.build_credit == vegetation_sale_value, "Selling must release the saved clearance registry")
	tree_near.free()
	for node in tree_mm_nodes:
		node.free()
	for node in grass_nodes:
		node.free()
	outside_mm_node.free()
	game.buildings = [{"kind": "airfield"}]
	assert(not builder.can_place("airfield", AirfieldHQ23.SUGGESTED_CENTER, 0.0), "A second airfield must be rejected")
	game.buildings.clear()
	game.points = 10000
	game.build_credit = 0
	game.state = "prep"
	var placed_airfield: Variant = builder.place("airfield", Vector3(120.0, 0.0, 20.0), PI * 0.5)
	assert(placed_airfield != null, "The valid rotated airfield must build through the existing Buildings.place path")
	assert(game.points == 7200 and game.build_credit == 0, "Placing the airfield must charge its 2,800-point cost once")
	assert(game.buildings.has(placed_airfield) and placed_airfield.node.get_meta("complex") != null, "The purchased building must register and instantiate the full hangar/tower/paving complex")
	var old_airfield_position: Vector3 = placed_airfield.at
	builder.move_to(placed_airfield, AirfieldHQ23.SUGGESTED_CENTER, 0.0)
	assert(placed_airfield.at == AirfieldHQ23.SUGGESTED_CENTER and placed_airfield.node.position == AirfieldHQ23.SUGGESTED_CENTER and not is_equal_approx(placed_airfield.yaw, PI * 0.5), "An existing airfield must be movable and rotatable through the normal building path")
	builder.move_to(placed_airfield, Vector3.ZERO, 0.0)
	assert(placed_airfield.at == AirfieldHQ23.SUGGESTED_CENTER, "An invalid move over the protected base must leave the airfield in its previous safe location")
	assert(old_airfield_position != placed_airfield.at, "The airfield relocation check must exercise a real position change")
	builder.damage(placed_airfield, 1600.0)
	assert(not placed_airfield.down and placed_airfield.cracked and placed_airfield.hp < placed_airfield.max_hp, "An airfield must use the existing building damage state")
	game.build_credit = 100
	builder.repair(placed_airfield)
	assert(placed_airfield.hp == placed_airfield.max_hp and not placed_airfield.cracked and game.build_credit == 0, "Repair must use the existing build-credit-first repair cost")
	builder.damage(placed_airfield, 4000.0)
	assert(placed_airfield.down and placed_airfield.hp == 0.0, "A destroyed airfield must enter the rebuildable down state")
	game.build_credit = builder.fix_cost(placed_airfield)
	builder.repair(placed_airfield)
	assert(not placed_airfield.down and placed_airfield.node.scale == Vector3.ONE, "Rebuilding must restore the placed airfield and collisions")
	var expected_sale_credit: int = builder.sell_value(placed_airfield)
	builder.sell(placed_airfield)
	assert(not game.buildings.has(placed_airfield) and game.build_credit == expected_sale_credit, "Selling must remove the complex and return the normal building value as build credit")
	game.build_credit = 1000
	game.points = 2000
	assert(game.pay_build(2800), "Build payment should combine the existing credit and point balances")
	assert(game.build_credit == 0 and game.points == 200, "Build credit must be spent before points")
	assert(not AirfieldHQ23.P47_PURCHASE_ENABLED, "P-47 purchases must remain disabled until after the native airport test")
	assert(AirfieldHQ23.site_regions().size() > 8, "The airport placement footprint must expose separate construction regions, including taxi turns")
	builder.free()
	print("AIRFIELD HQ 2.3 contract: PASS")
	get_tree().quit(0)
