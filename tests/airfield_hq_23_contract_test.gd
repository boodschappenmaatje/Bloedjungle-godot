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
	assert(is_equal_approx(AirfieldHQ23.footprint_area(), 6274.05), "The compact layout footprint must use its measured unscaled bounds")
	assert(AirfieldHQ23.FOOTPRINT.x * AirfieldHQ23.FOOTPRINT.z <= AirfieldHQ23.MAX_GROUND_AREA, "The complete placed footprint must stay within twice the base area")
	assert(AirfieldFlightIntegration.RUNWAY_LENGTH_M == 30.0, "The compact runway must be the configured 30 m gameplay runway")
	assert(AirfieldHQ23.RUNWAY_END_X - AirfieldHQ23.RUNWAY_START_X == AirfieldFlightIntegration.RUNWAY_LENGTH_M, "Runway slab span must match route/runway configuration")
	assert(AirfieldHQ23.RUNWAY_END_X <= AirfieldHQ23.FOOTPRINT.x * 0.5, "Runway must stay inside the placement footprint")
	assert(AirfieldHQ23.RUNWAY_CENTER_Z + AirfieldFlightIntegration.RUNWAY_WIDTH_M * 0.5 <= AirfieldHQ23.FOOTPRINT.z * 0.5, "Runway width must stay inside the placement footprint")
	assert(AirfieldHQ23.AIRCRAFT.p47.cost == 1800, "P-47 price must remain centralized at 1,800")
	assert(not ResourceLoader.exists(AirfieldHQ23.P47_SCENE), "No surrogate P-47 scene may be present")
	assert(AirfieldHQ23.shop_status("p47").contains("origineel Meshy Pro-vliegtuigmodel ontbreekt"), "Missing model status must be explicit")
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
	assert(shop_text.contains("origineel Meshy Pro-vliegtuigmodel ontbreekt"), "Shop must disclose the missing P-47 source model")
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
	assert(builder.can_place("airfield", Vector3(100.0, 0.0, 0.0), PI * 0.5), "A rotated full footprint must be accepted at a clear site")
	game.buildings = [{"kind": "airfield"}]
	assert(not builder.can_place("airfield", AirfieldHQ23.SUGGESTED_CENTER, 0.0), "A second airfield must be rejected")
	game.buildings.clear()
	game.build_credit = 1000
	game.points = 2000
	assert(game.pay_build(2800), "Build payment should combine the existing credit and point balances")
	assert(game.build_credit == 0 and game.points == 200, "Build credit must be spent before points")
	var flight := AirfieldFlightIntegration.new()
	assert(flight.reserve_runway("p47-a"), "First aircraft must reserve runway")
	assert(not flight.reserve_runway("p47-b"), "Second aircraft must not share an occupied runway")
	flight.release_runway("p47-a")
	assert(flight.reserve_runway("p47-b"), "Runway reservation must be available after release")
	flight.free()
	builder.free()
	print("AIRFIELD HQ 2.3 contract: PASS")
	get_tree().quit(0)
