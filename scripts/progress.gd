class_name Progress
## Wat je bewaart tussen spellen (25b-gear.js en 25-menus.js): topscores, naam, statistieken en uitrusting.

const PATH := "user://voortgang.cfg"

# unlock: [soort, aantal]; soorten: wave (beste golf), kills (alle spellen), games, boss
const GEAR := {
	"camo": [
		{"id": "jungle", "name": "Jungle", "bonus": "Vijanden richten 10% slechter", "b": {"enemySpread": 1.1}, "col": Color("4b5a2c")},
		{"id": "tijger", "name": "Tijgerstreep", "bonus": "5% sneller lopen", "b": {"speed": 1.05}, "unlock": ["wave", 5], "col": Color("56653a")},
		{"id": "woestijn", "name": "Woestijn", "bonus": "10% meer punten", "b": {"points": 1.1}, "unlock": ["kills", 250], "col": Color("b59a6a")},
		{"id": "nacht", "name": "Nacht", "bonus": "'s Nachts richten vijanden 30% slechter", "b": {"nightSpread": 1.3}, "unlock": ["boss", 1], "col": Color("24272c")},
		{"id": "stad", "name": "Stedelijk", "bonus": "10% sneller herladen", "b": {"reload": 0.9}, "unlock": ["wave", 10], "col": Color("6e6e6a")},
	],
	"band": [
		{"id": "rood", "name": "Rood", "color": Color("c0140f"), "bonus": "5% meer schade", "b": {"dmg": 1.05}},
		{"id": "zwart", "name": "Zwart", "color": Color("15151a"), "bonus": "5% minder schade ontvangen", "b": {"taken": 0.95}},
		{"id": "groen", "name": "Groen", "color": Color("3d6b2d"), "bonus": "+10 maximale gezondheid", "b": {"hp": 10}, "unlock": ["kills", 100]},
		{"id": "wit", "name": "Wit", "color": Color("e8e4da"), "bonus": "50% sneller genezen in het hospitaal", "b": {"heal": 1.5}, "unlock": ["wave", 8]},
		{"id": "blauw", "name": "Blauw", "color": Color("1f4fa8"), "bonus": "Granaten 15% grotere ontploffing", "b": {"grenade": 1.15}, "unlock": ["games", 3]},
		{"id": "goud", "name": "Goud", "color": Color("d6ad4f"), "bonus": "15% meer punten", "b": {"points": 1.15}, "unlock": ["wave", 15]},
	],
	"top": [
		{"id": "bloot", "name": "Ontbloot", "bonus": "Rambo: 6% sneller", "b": {"speed": 1.06}},
		{"id": "mouwloos", "name": "Mouwloos shirt", "bonus": "3% sneller, 3% minder schade", "b": {"speed": 1.03, "taken": 0.97}},
		{"id": "uniform", "name": "Uniform", "bonus": "6% minder schade", "b": {"taken": 0.94}, "unlock": ["wave", 3]},
		{"id": "vest", "name": "Tactisch vest", "bonus": "12% minder schade, 5% trager", "b": {"taken": 0.88, "speed": 0.95}, "unlock": ["kills", 500]},
	],
}
const TITLES := {"camo": "Camouflage", "band": "Hoofdband", "top": "Bovenlijf"}

static var scores: Array = []
static var player_name := "Rambo"
static var stats := {"bestWave": 0, "kills": 0, "games": 0, "boss": 0}
static var sel := {"camo": "jungle", "band": "rood", "top": "bloot"}
static var autostart := false  # na "Opnieuw" meteen spelen, zonder hoofdmenu
static var _loaded := false
static var _bonus := {}


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	scores = cf.get_value("v", "scores", [])
	player_name = cf.get_value("v", "name", "Rambo")
	for k in stats:
		stats[k] = int(cf.get_value("stats", k, 0))
	for k in sel:
		sel[k] = cf.get_value("gear", k, sel[k])


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("v", "scores", scores)
	cf.set_value("v", "name", player_name)
	for k in stats:
		cf.set_value("stats", k, stats[k])
	for k in sel:
		cf.set_value("gear", k, sel[k])
	cf.save(PATH)


static func stat_of(kind: String) -> int:
	return {"wave": stats.bestWave, "kills": stats.kills, "games": stats.games, "boss": stats.boss}[kind]


static func is_unlocked(item: Dictionary) -> bool:
	return not item.has("unlock") or stat_of(item.unlock[0]) >= item.unlock[1]


static func unlock_text(u: Array) -> String:
	return {"wave": "Overleef golf %d" % u[1], "kills": "%d vijanden doden" % u[1], "games": "Speel %d missies" % u[1], "boss": "Versla De Kweker"}[u[0]]


static func progress_text(u: Array) -> String:
	return "%d / %d" % [mini(stat_of(u[0]), u[1]), u[1]]


static func item(slot: String) -> Dictionary:
	load_all()
	for i in GEAR[slot]:
		if i.id == sel[slot] and is_unlocked(i):
			return i
	return GEAR[slot][0]


## Alles wat je draagt bij elkaar opgeteld.
static func bonus() -> Dictionary:
	load_all()
	if _bonus.is_empty():
		recompute()
	return _bonus


static func recompute() -> void:
	var b := {"dmg": 1.0, "taken": 1.0, "speed": 1.0, "hp": 0.0, "reload": 1.0, "points": 1.0, "enemySpread": 1.0, "nightSpread": 1.0, "heal": 1.0, "grenade": 1.0}
	for slot in GEAR:
		var ib: Dictionary = item(slot).b
		for k in ib:
			b[k] = b[k] + ib[k] if k == "hp" else b[k] * ib[k]
	_bonus = b


static func add_score(score: int, wave: int, kills: int) -> int:
	var id := Time.get_ticks_usec()
	scores.append({"id": id, "name": player_name, "score": score, "wave": wave, "kills": kills})
	scores.sort_custom(func(a, b): return a.score > b.score)
	scores = scores.slice(0, 10)
	save()
	return id


## Meldt nieuwe vrijgespeelde onderdelen (leeg als er niets nieuws is).
static var _seen := {}
static func check_unlocks() -> Array:
	var fresh := []
	for slot in GEAR:
		for i in GEAR[slot]:
			var key: String = slot + ":" + i.id
			if i.has("unlock") and is_unlocked(i) and not _seen.has(key):
				_seen[key] = true
				fresh.append("%s: %s" % [TITLES[slot], i.name])
	return fresh


static func seed_seen() -> void:
	for slot in GEAR:
		for i in GEAR[slot]:
			if i.has("unlock") and is_unlocked(i):
				_seen[slot + ":" + i.id] = true
