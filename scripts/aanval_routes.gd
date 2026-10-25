class_name AanvalRoutes
## Vaste aanvalsroutes voor de golven: vijanden komen niet meer overal vandaan, maar via de straten van de stad,
## de kade, de zijstraat naar de ondiepte of een van de junglepaden. Per golf zijn er een, twee of drie routes actief;
## de HUD wijst ze aan met rode pijlen (hud_extra.gd) zodat je kunt kiezen waar je verdedigt.
## Na het laatste punt van een route neemt Route.waypoint het over (brug of ondiepte, poort, bunker).

## pts: punten die de vijand afloopt (noordkant voor de stadsroutes, de rivier steekt hij daarna zelf over).
## show: waar de pijl op wijst, op de plek waar ze bij de basis aankomen.
const LIST := {
	"brug": {"naam": "BRUG", "uitleg": "door de hoofdstraat en over de brug", "stad": true,
		"pts": [Vector3(0, 0, -132), Vector3(0, 0, -118), Vector3(0, 0, -104)], "show": Vector3(0, 0, -82)},
	"kade": {"naam": "KADE", "uitleg": "langs de kade naar de brug", "stad": true,
		"pts": [Vector3(-80, 0, -98.5), Vector3(-45, 0, -100.5), Vector3(-6, 0, -101.5)], "show": Vector3(-6, 0, -82)},
	"oost": {"naam": "ONDIEPTE", "uitleg": "door de zijstraat en de ondiepte", "stad": true,
		"pts": [Vector3(78, 0, -103), Vector3(44, 0, -102)], "show": Vector3(38, 0, -80)},
	"moeras": {"naam": "MOERAS", "uitleg": "door het moeras in het westen", "stad": false,
		"pts": [Vector3(-64, 0, -14), Vector3(-40, 0, -10)], "show": Vector3(-38, 0, -10)},
	"jungle": {"naam": "JUNGLE", "uitleg": "door de jungle in het oosten", "stad": false,
		"pts": [Vector3(64, 0, 6), Vector3(40, 0, 4)], "show": Vector3(38, 0, 4)},
	"zuid": {"naam": "ZUIDEN", "uitleg": "van het zuiden naar de zuidpoort", "stad": false,
		"pts": [Vector3(6, 0, 64), Vector3(0, 0, 42)], "show": Vector3(0, 0, 40)},
}

## De eerste golven staan vast, zodat je de routes een voor een leert kennen.
const FIRST := [["brug"], ["oost"], ["brug", "moeras"], ["kade", "jungle"]]
const CITY := ["brug", "kade", "oost"]
const OTHER := ["moeras", "jungle", "zuid"]
const SPREAD := 2.2  # m zijwaartse spreiding, zodat ze niet in een rij lopen


## Routes voor golf n: altijd minstens een door de stad; vanaf golf 5 twee, vanaf golf 8 drie.
static func pick(n: int) -> Array:
	if n >= 1 and n <= FIRST.size():
		return FIRST[n - 1].duplicate()
	var count := 2 if n < 8 else 3
	var city := CITY.duplicate()
	city.shuffle()
	var rest := (CITY + OTHER).duplicate()
	rest.erase(city[0])
	rest.shuffle()
	var out := [city[0]]
	for id in rest:
		if out.size() >= count:
			break
		out.append(id)
	return out


## De punten voor een vijand op deze route, met een eigen zijwaartse verschuiving.
static func path_for(id: String) -> Array:
	var r: Dictionary = LIST[id]
	var pts: Array = r.pts
	var side := randf_range(-SPREAD, SPREAD)
	var out := []
	for i in pts.size():
		var p: Vector3 = pts[i]
		var nxt: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var prv: Vector3 = pts[maxi(i - 1, 0)]
		var dir := (nxt - prv)
		dir.y = 0.0
		var perp := Vector3(-dir.z, 0.0, dir.x).normalized() if dir.length() > 0.01 else Vector3.RIGHT
		out.append(p + perp * side)
	return out


## Startplek: iets terug langs de route vanaf het eerste punt, zodat een groep niet op één plek verschijnt.
static func spawn_at(path: Array) -> Vector3:
	var a: Vector3 = path[0]
	var b: Vector3 = path[1] if path.size() > 1 else Vector3.ZERO
	var back := (a - b)
	back.y = 0.0
	return a + back.normalized() * randf_range(0.0, 6.0)


## "door de hoofdstraat en over de brug en door het moeras"
static func describe(ids: Array) -> String:
	var parts := []
	for id in ids:
		parts.append(String(LIST[id].uitleg))
	return " en ".join(parts)
