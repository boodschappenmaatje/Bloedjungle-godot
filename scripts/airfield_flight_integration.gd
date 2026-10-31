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
const RUNWAY_WIDTH_M := AirfieldHQ23.RUNWAY_WIDTH_M
const RUNWAY_LENGTH_M := AirfieldHQ23.RUNWAY_LENGTH_M
const RUNWAY_END_X := AirfieldHQ23.RUNWAY_END_X
const TAKEOFF_START_X := RUNWAY_END_X - 2.5 # eastern entry; roll west toward the runway end
const TAKEOFF_AVAILABLE_ROLL_M := TAKEOFF_START_X - AirfieldHQ23.RUNWAY_START_X
const DEMO_ACCELERATION_MPS2 := 5.0
const DEMO_LIFTOFF_SPEED_MPS := 10.0

@onready var taxi_route: Path3D = $P47_Taxi_Route
@onready var takeoff_path: Path3D = $P47_Takeoff_Path
@onready var landing_path: Path3D = $P47_Landing_Path

var _runway_reserved_by := ""

func _ready() -> void:
	_build_paths()

func reserve_runway(aircraft_id: String) -> bool:
	if aircraft_id.is_empty() or (not _runway_reserved_by.is_empty() and _runway_reserved_by != aircraft_id):
		return false
	_runway_reserved_by = aircraft_id
	return true

func release_runway(aircraft_id: String) -> void:
	if _runway_reserved_by == aircraft_id:
		_runway_reserved_by = ""

func runway_reserved() -> bool:
	return not _runway_reserved_by.is_empty()

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
		"profile_type": "arcade gameplay assumption; not measured or historically representative P-47 flight data",
		"acceleration_mps2": DEMO_ACCELERATION_MPS2,
		"liftoff_speed_mps": DEMO_LIFTOFF_SPEED_MPS,
		"required_ground_roll_m": distance,
		"paved_runway_m": RUNWAY_LENGTH_M,
		"available_roll_from_start_marker_m": TAKEOFF_AVAILABLE_ROLL_M,
		"remaining_runway_m": TAKEOFF_AVAILABLE_ROLL_M - distance,
		"fits_demonstration": distance <= TAKEOFF_AVAILABLE_ROLL_M - 0.25,
	}

func _curve(points: Array[Vector3]) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = 1.0
	for point in points: c.add_point(point)
	return c

func _build_paths() -> void:
	# Prepared markers stay relative to the placed complex. Aircraft functionality
	# remains disabled until after the owner's native field test and approval.
	$P47_Hangar_Spawn.position = Vector3(0.0, 0.22, 0.0)
	var parking := AirfieldHQ23.layout_point(AirfieldHQ23.APRON_CENTER.x, AirfieldHQ23.APRON_CENTER.y)
	$P47_Apron_Parking.position = parking
	$P47_Taxi_Start.position = parking
	$P47_Runway_Hold.position = AirfieldHQ23.layout_point(AirfieldHQ23.TAXI_ARC_END.x, AirfieldHQ23.TAXI_ARC_END.y)
	$P47_Runway_Start.position = AirfieldHQ23.layout_point(TAKEOFF_START_X, AirfieldHQ23.RUNWAY_CENTER_Z)
	$P47_Landing_Touchdown.position = AirfieldHQ23.layout_point(AirfieldHQ23.RUNWAY_START_X + 3.0, AirfieldHQ23.RUNWAY_CENTER_Z)
	$P47_Landing_Approach.position = AirfieldHQ23.layout_point(AirfieldHQ23.RUNWAY_START_X - 25.0, AirfieldHQ23.RUNWAY_CENTER_Z, 24.0)
	var taxi_points: Array[Vector3] = []
	for point in AirfieldHQ23.taxi_centerline_points():
		taxi_points.append(AirfieldHQ23.layout_point(point.x, point.y))
	taxi_route.curve = _curve(taxi_points)
	takeoff_path.curve = _curve([
		AirfieldHQ23.layout_point(TAKEOFF_START_X, AirfieldHQ23.RUNWAY_CENTER_Z),
		AirfieldHQ23.layout_point(-10.0, AirfieldHQ23.RUNWAY_CENTER_Z, 0.22),
		AirfieldHQ23.layout_point(-37.0, AirfieldHQ23.RUNWAY_CENTER_Z, 2.0),
		AirfieldHQ23.layout_point(-55.0, AirfieldHQ23.RUNWAY_CENTER_Z + 4.0, 12.0),
		AirfieldHQ23.layout_point(-70.0, AirfieldHQ23.RUNWAY_CENTER_Z + 8.0, 24.0),
	])
	landing_path.curve = _curve([
		AirfieldHQ23.layout_point(AirfieldHQ23.RUNWAY_START_X - 25.0, AirfieldHQ23.RUNWAY_CENTER_Z, 24.0),
		AirfieldHQ23.layout_point(AirfieldHQ23.RUNWAY_START_X - 12.0, AirfieldHQ23.RUNWAY_CENTER_Z, 10.0),
		AirfieldHQ23.layout_point(AirfieldHQ23.RUNWAY_START_X - 5.0, AirfieldHQ23.RUNWAY_CENTER_Z, 3.0),
		$P47_Landing_Touchdown.position,
		AirfieldHQ23.layout_point(AirfieldHQ23.RUNWAY_START_X + 18.0, AirfieldHQ23.RUNWAY_CENTER_Z),
	])

func place_real_aircraft(aircraft: Node3D) -> void:
	## Call with the user's actual Meshy aircraft scene once available.
	add_child(aircraft)
	aircraft.global_transform = $P47_Hangar_Spawn.global_transform
