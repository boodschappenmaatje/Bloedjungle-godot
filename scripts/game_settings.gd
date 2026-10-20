class_name GameSettings
## Instellingen uit het web-menu (grafiek, tijd, bouwtijd, weer, fps-teller); blijven bewaard op het apparaat.

const PATH := "user://instellingen.cfg"
const DEFAULTS := {"quality": "ultra", "time": "day", "prep": "60", "weather": "clear", "fps": "off", "sound": "on"}

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
