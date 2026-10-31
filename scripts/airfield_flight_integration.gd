extends Node3D
class_name AirfieldFlightIntegration
## Airfield geometry and flight waypoints only. Aircraft animation stays with the
## real Meshy P-47 scene when supplied; no surrogate aircraft is instantiated.

const P47_LENGTH_M := 11.0
const P47_WINGSPAN_M := 12.44
const P47_HEIGHT_M := 4.45
const DOOR_CLEAR_WIDTH_M := 39.4
const DOOR_CLEAR_HEIGHT_M := 13.0
const TAXIWAY_WIDTH_M := 18.4
const RUNWAY_WIDTH_M := 38.0
const RUNWAY_LENGTH_M := 900.0
const DEMO_ACCELERATION_MPS2 := 2.0
const DEMO_LIFTOFF_SPEED_MPS := 50.0

@onready var taxi_route: Path3D = $P47_Taxi_Route
@onready var takeoff_path: Path3D = $P47_Takeoff_Path
@onready var landing_path: Path3D = $P47_Landing_Path

func _ready() -> void:
	_build_paths()

func clearance_report() -> Dictionary:
	return {
		"door_wing_margin_each_side_m": (DOOR_CLEAR_WIDTH_M - P47_WINGSPAN_M) / 2.0,
		"door_height_margin_m": DOOR_CLEAR_HEIGHT_M - P47_HEIGHT_M,
		"taxi_wing_margin_each_side_m": (TAXIWAY_WIDTH_M - P47_WINGSPAN_M) / 2.0,
		"fits_hangar": DOOR_CLEAR_WIDTH_M > P47_WINGSPAN_M + 3.0 and DOOR_CLEAR_HEIGHT_M > P47_HEIGHT_M + 2.0,
		"fits_taxiway": TAXIWAY_WIDTH_M > P47_WINGSPAN_M + 4.0,
	}

func takeoff_profile_report() -> Dictionary:
	var distance := DEMO_LIFTOFF_SPEED_MPS * DEMO_LIFTOFF_SPEED_MPS / (2.0 * DEMO_ACCELERATION_MPS2)
	return {
		"profile_type": "gameplay demonstration assumption; not measured P-47 flight data",
		"acceleration_mps2": DEMO_ACCELERATION_MPS2,
		"liftoff_speed_mps": DEMO_LIFTOFF_SPEED_MPS,
		"required_ground_roll_m": distance,
		"paved_runway_m": RUNWAY_LENGTH_M,
		"remaining_runway_m": RUNWAY_LENGTH_M - distance,
		"fits_demonstration": distance < RUNWAY_LENGTH_M - 100.0,
	}

func _curve(points: Array[Vector3]) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = 1.0
	for point in points: c.add_point(point)
	return c

func _build_paths() -> void:
	# Godot X/Z correspond to Blender X/-Y. Extra samples soften the turn from
	# the apron around the tower into the runway holding point.
	taxi_route.curve = _curve([
		Vector3(0, .22, 48), Vector3(18, .22, 48), Vector3(34, .22, 46),
		Vector3(47, .22, 42), Vector3(54, .22, 33), Vector3(60, .22, 15),
		Vector3(58, .22, -5), Vector3(55, .22, -36), Vector3(54, .22, -70),
		Vector3(51, .22, -105), Vector3(43, .22, -140),
		Vector3(30, .22, -175), Vector3(19, .22, -204),
		Vector3(11, .22, -230), Vector3(0, .22, -245),
	])
	takeoff_path.curve = _curve([
		Vector3(0, .22, -245), Vector3(0, .22, -400),
		Vector3(0, .22, -650), Vector3(0, .22, -870),
		Vector3(0, 6, -900), Vector3(0, 20, -945), Vector3(0, 55, -1040),
	])
	landing_path.curve = _curve([
		Vector3(0, 60, -1160), Vector3(0, 25, -1020),
		Vector3(0, 7, -900), Vector3(0, .22, -850),
		Vector3(0, .22, -550), Vector3(0, .22, -300),
	])

func place_real_aircraft(aircraft: Node3D) -> void:
	## Call with the user's actual Meshy aircraft scene once available.
	add_child(aircraft)
	aircraft.global_transform = $P47_Hangar_Spawn.global_transform
