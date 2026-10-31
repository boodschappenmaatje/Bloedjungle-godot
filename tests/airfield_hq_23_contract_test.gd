extends SceneTree
## Contract checks for the Airfield HQ build reservation and safe asset-gated P-47 purchase.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(Buildings.DEFS.has("airfield"), "Airfield build card definition must exist")
	assert(Buildings.DEFS.airfield.cost == 2800, "Airfield cost must remain centralized at 2,800")
	assert(Buildings.DEFS.airfield.max == 1, "Only one airfield is allowed per base")
	assert(AirfieldHQ23.FOOTPRINT.z >= 900.0, "The reserved construction plot must fit the full runway")
	assert(AirfieldHQ23.AIRCRAFT.p47.cost == 1800, "P-47 price must remain centralized at 1,800")
	assert(not ResourceLoader.exists(AirfieldHQ23.P47_SCENE), "No surrogate P-47 scene may be present")
	assert(AirfieldHQ23.shop_status("p47").contains("origineel Meshy Pro-vliegtuigmodel ontbreekt"), "Missing model status must be explicit")
	Game.points = 5000
	var candidate := {"kind": "airfield", "down": false, "hp": 3000.0, "aircraft": []}
	var points_before := Game.points
	assert(not AirfieldHQ23.can_buy(null, candidate, "p47"), "Missing model must prevent charge and purchase")
	assert(Game.points == points_before, "A blocked model purchase must not deduct points")
	var builder := Buildings.new()
	assert(builder.can_place("airfield", AirfieldHQ23.ANCHOR, 0.0), "The fixed construction plot should accept its reserved placement")
	assert(not builder.can_place("airfield", Vector3.ZERO, 0.0), "The ordinary combat map must reject the runway-sized footprint")
	assert(not builder.can_place("airfield", AirfieldHQ23.ANCHOR, PI * 0.5), "Unsupported plot rotation must be rejected")
	Game.buildings = [{"kind": "airfield"}]
	assert(not builder.can_place("airfield", AirfieldHQ23.ANCHOR, 0.0), "A second airfield must be rejected")
	Game.buildings.clear()
	Game.build_credit = 1000
	Game.points = 2000
	assert(Game.pay_build(2800), "Build payment should combine the existing credit and point balances")
	assert(Game.build_credit == 0 and Game.points == 200, "Build credit must be spent before points")
	var flight := AirfieldFlightIntegration.new()
	assert(flight.reserve_runway("p47-a"), "First aircraft must reserve runway")
	assert(not flight.reserve_runway("p47-b"), "Second aircraft must not share an occupied runway")
	flight.release_runway("p47-a")
	assert(flight.reserve_runway("p47-b"), "Runway reservation must be available after release")
	print("AIRFIELD HQ 2.3 contract: PASS")
	quit(0)
