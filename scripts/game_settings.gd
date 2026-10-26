class_name GameSettings
## Instellingen uit het web-menu (grafiek, tijd, bouwtijd, weer, fps-teller); blijven bewaard op het apparaat.

const PATH := "user://instellingen.cfg"
const DEFAULTS := {"quality": "high", "time": "day", "prep": "60", "weather": "clear", "fps": "off", "perf": "off", "hz": "60", "sound": "on", "wind": "off", "treeshadow": "fake", "buildshadow": "medium", "t_sun": "on", "t_jungle": "on", "t_stad": "on", "t_post": "on", "t_res": "auto", "diag": "off"}

static var values := {}
static var _loaded := false


static func get_value(key: String) -> String:
	_load()
	return values[key]


static func set_value(key: String, v: String) -> void:
	_load()
	values[key] = v
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("instellingen", k, values[k])
	cf.save(PATH)


## Het hoogste tempo dat het spel de laatste tijd echt haalde (PerfGovernor houdt dit bij). Nodig omdat sommige toestellen
## hun schermsnelheid niet melden (iPhone via Xogot geeft -1): dan weten we alleen wat we meten.
static var observed_peak := 60.0


## Beelden per seconde waar het spel naartoe werkt: 60, of 120 als dat gekozen is en het scherm het kan.
## Meldt het scherm zijn snelheid niet, dan gaan we uit van 60 tot het spel echt boven de ~90 fps komt.
## (Eerder gold dan 120 als doel; op een scherm dat 60 haalt zette de resolutieregelaar het beeld daardoor voor altijd op 50%.)
static func target_fps() -> float:
	if get_value("hz") != "120":
		return 60.0
	var r := DisplayServer.screen_get_refresh_rate()
	if r > 0.0:
		return clampf(r, 60.0, 120.0)
	return 120.0 if observed_peak > 90.0 else 60.0


## Geen eigen beeldsnelheidsgrens: het scherm (vsync) bepaalt het tempo. Een eigen grens van 60 naast vsync blijft telkens
## net na de verversing van het scherm wakker en mist dan elk beeld; het spel zat daardoor vast op ~30 fps terwijl de
## processor bijna niets deed (22 okt, zonder grens: 60 fps; daarna met grens: 29-31 fps).
static func apply_hz() -> void:
	Engine.max_fps = 0


static func prep_time() -> float:
	return float(get_value("prep"))


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	values = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			values[k] = str(cf.get_value("instellingen", k, DEFAULTS[k]))
