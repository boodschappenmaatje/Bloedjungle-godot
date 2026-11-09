class_name AanvalRoutes
## Vaste aanvalsroutes voor de golven: vijanden komen niet meer overal vandaan, maar via de straten van de stad,
## de kade, de zijstraat naar de ondiepte of een van de junglepaden. Per golf zijn er een, twee of drie routes actief;
## de HUD wijst ze aan met rode pijlen (hud_extra.gd) zodat je kunt kiezen waar je verdedigt.
## Na het laatste punt van een route neemt Route.waypoint het over (brug of ondiepte, poort, bunker).

## pts: punten die de vijand afloopt (noordkant voor de stadsroutes, de rivier steekt hij daarna zelf over).
## show: waar de pijl op wijst, op de plek waar ze bij de basis aankomen.
const LIST := {
	"brug": {"naam": "HOOFDSTRAAT", "uitleg": "van het plein door de hoofdstraat en over de brug", "stad": true,
		"pts": [Vector3(52, 0, -126), Vector3(16, 0, -126), Vector3(0, 0, -121), Vector3(0, 0, -104)], "show": Vector3(0, 0, -82)},
	"wijk": {"naam": "WOONWIJK", "uitleg": "door de woonwijk en het steegje naar de brug", "stad": true,
		"pts": [Vector3(-62, 0, -126), Vector3(-30, 0, -126), Vector3(-30, 0, -110), Vector3(-8, 0, -108), Vector3(0, 0, -104)], "show": Vector3(-12, 0, -82)},
	"kade": {"naam": "KADE", "uitleg": "langs de kade naar de brug", "stad": true,
		"pts": [Vector3(-80, 0, -99.5), Vector3(-45, 0, -100.5), Vector3(-6, 0, -101.5)], "show": Vector3(-24, 0, -82)},
	"industrie": {"naam": "INDUSTRIE", "uitleg": "langs de wegversperring en de ondiepte", "stad": true,
		"pts": [Vector3(72, 0, -108), Vector3(60, 0, -108)], "show": Vector3(40, 0, -80)},
	"moeras": {"naam": "MOERAS", "uitleg": "door het moeras in het westen", "stad": false,
		"pts": [Vector3(-64, 0, -14), Vector3(-40, 0, -10)], "show": Vector3(-38, 0, -10)},
	"jungle": {"naam": "JUNGLE", "uitleg": "door de jungle in het oosten", "stad": false,
		"pts": [Vector3(64, 0, 6), Vector3(40, 0, 4)], "show": Vector3(38, 0, 4)},
	"zuid": {"naam": "ZUIDEN", "uitleg": "van het zuiden naar de zuidpoort", "stad": false,
		"pts": [Vector3(6, 0, 64), Vector3(0, 0, 42)], "show": Vector3(0, 0, 40)},
}


## De eerste golven staan vast, zodat je de routes een voor een leert kennen.
const FIRST := [["brug"], ["wijk"], ["brug", "moeras"], ["kade", "jungle"]]
const CITY := ["brug", "wijk", "kade", "industrie"]
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


## Routes voor aanvalsgroep n (stap 5a-2): de vijandbasis ligt ver in het noorden, dus alleen de stadsroutes. De eerste groepen
## staan vast, zodat je de routes een voor een leert kennen; daarna twee, vanaf groep 8 drie routes tegelijk.
const FIRST_GROUP := [["brug"], ["wijk"], ["kade"], ["industrie"], ["brug", "wijk"]]


static func pick_group(n: int) -> Array:
	if n >= 1 and n <= FIRST_GROUP.size():
		return FIRST_GROUP[n - 1].duplicate()
	var city := CITY.duplicate()
	city.shuffle()
	return city.slice(0, 2 if n < 8 else 3)


## De weg van een vijandelijk voertuig (stap V1): uit de poort van de vijandbasis door de jungle naar de oostkant van de stad, door de Hoofdstraat en naar de
## noordkant van de brug. Een voertuig is breed en draait ruim, dus hij gebruikt alleen de brede straat ("brug"), nooit de steegjes van de woonwijk. In de straat
## rijdt hij langs de zuidkant en dan door de strook ten westen van de geparkeerde auto (x -6): daar is plek voor een jeep. De rivier steekt VijandJeep zelf over
## (brug, of wacht als die omhoog staat). Dezelfde punten voor elk voertuig; de zijwaartse spreiding van de soldaten laat hij weg.
const VOERTUIG_WEG := [Vector3(-30, 0, -190), Vector3(20, 0, -168), Vector3(54, 0, -146), Vector3(54, 0, -128), Vector3(30, 0, -127.5), Vector3(8, 0, -128.5),
	Vector3(-3, 0, -128.5), Vector3(-6, 0, -124.5), Vector3(-6, 0, -118.5), Vector3(-6.2, 0, -112.5), Vector3(-5.5, 0, -108.5), Vector3(-1.5, 0, -106.5), Vector3(0, 0, -103)]


static func voertuig_pad() -> Array:
	var out := [VijandBasis.gate_outside()]
	out.append_array(VOERTUIG_WEG)
	return out


## Aftelklok "02:41": op de plaat boven in beeld en bij de vijandenteller.
static func klok(t: float) -> String:
	var s := maxi(0, ceili(t))
	return "%02d:%02d" % [floori(s / 60.0), posmod(s, 60)]


## De tocht van een aanvalsgroep: uit de poort van de vijandbasis, dan naar het begin van de stadsroute en over de route zelf.
static func path_from_base(id: String) -> Array:
	var out := [VijandBasis.gate_outside() + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(0.0, 3.0))]
	out.append_array(path_for(id))
	return out


## De mars van jouw leger naar de vijandbasis (stap 5a-3a): precies de woonwijk-route van de aanvalsgroepen, maar dan andersom
## (brug, Hoofdstraat, westelijke straat en dan de uitgang aan de westkant), daarna rechtdoor naar de poort en erdoorheen.
## Die route lopen vijanden al elke groep, dus hij is vrij van muren en huizen. De rivier steekt Route.waypoint zelf over.
static func march_path() -> Array:
	var out: Array = (LIST["wijk"].pts as Array).duplicate()
	out.reverse()
	out.append(VijandBasis.gate_outside())
	out.append(VijandBasis.gate_inside())
	return out


## Waar de mars voor een soldaat op dit punt begint: het eerstvolgende punt van het stuk route waar hij het dichtst bij staat.
## Wie al in de stad staat, hoeft dus niet eerst terug naar de brug, en snijdt geen hoeken af (een steegje blijft een steegje).
## Wie al in de vijandbasis staat (path.size()) heeft geen punten meer over en gaat meteen naar zijn plek voor het HK.
static func march_start(from: Vector3) -> int:
	var path := march_path()
	if VijandBasis.contains(from):
		return path.size()   # al binnen de muur: rechtstreeks naar zijn plek, niet eerst terug naar de poort
	var best := 0
	var best_d := INF
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t := 0.0
		if ab.length_squared() > 0.001:
			t = clampf(Vector2(from.x - a.x, from.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var closest := Vector2(a.x, a.z) + ab * t
		var d := Vector2(from.x - closest.x, from.z - closest.y).length()
		if d < best_d - 0.001:
			best_d = d
			best = i if t < 0.001 else i + 1
	return best


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
