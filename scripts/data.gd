class_name Data
## Vaste spelwaarden, overgenomen uit de web-versie (src/js/01-data.js, 05-world.js, 12-state.js).
## Afstanden in meters, tijden in seconden, hoeken in radialen.

## Soldaten zijn ietsje groter dan levensgroot zodat ze op de telefoon goed te zien zijn; hutten schalen mee.
const SOLDIER_SCALE := 1.2

# Wapens (01-data.js). rate = seconden tussen schoten, speed = kogelsnelheid (m/s), life = levensduur kogel,
# pierce = extra mensen waar de kogel doorheen gaat, slow = loopsnelheid met dit wapen, explosive = ontploffingsstraal.
# welk schotgeluid bij welk wapen hoort (Sfx)
const WEAPON_SND := {"m1911": "m1911_real", "thompson": "smg", "garand": "rifle", "trench": "shotgun", "mg42": "mg", "bazooka": "rocket"}
const WEAPONS := {
	"m1911": {"short": "Pistool", "name": "M1911A1 Pistool", "price": 0, "dmg": 26.0, "rate": 0.50, "mag": 7, "reload": 1.05, "spread": 0.035, "speed": 75.0, "pellets": 1, "pierce": 0, "life": 0.6, "desc": ".45 ACP enkelvoudig; zeven patronen in het magazijn."},
	"thompson": {"short": "Thompson", "name": "Thompson M1928", "price": 700, "dmg": 18.0, "rate": 0.075, "mag": 30, "reload": 2.0, "spread": 0.08, "speed": 75.0, "pellets": 1, "pierce": 0, "life": 0.55, "desc": "De Tommy gun. Snel, luid en hongerig."},
	"garand": {"short": "Garand", "name": "M1 Garand", "price": 1000, "dmg": 80.0, "rate": 0.3, "mag": 8, "reload": 1.9, "spread": 0.012, "speed": 120.0, "pellets": 1, "pierce": 2, "life": 0.6, "desc": "Semi-automatisch geweer. Kogel gaat door drie man heen."},
	"trench": {"short": "Shotgun", "name": "Winchester M1897", "price": 1400, "dmg": 16.0, "rate": 0.62, "mag": 6, "reload": 2.6, "spread": 0.2, "speed": 65.0, "pellets": 9, "pierce": 0, "life": 0.32, "desc": "Loopgraafshotgun. Van dichtbij blijft er weinig over."},
	"mg42": {"short": "MG 42", "name": "MG 42", "price": 2800, "dmg": 27.0, "rate": 0.05, "mag": 100, "reload": 3.6, "spread": 0.1, "speed": 95.0, "pellets": 1, "pierce": 1, "life": 0.6, "slow": 0.78, "desc": "1200 schoten per minuut. Je loopt er wel trager mee."},
	"bazooka": {"short": "Bazooka", "name": "M1 Bazooka", "price": 3800, "dmg": 240.0, "rate": 1.0, "mag": 1, "reload": 2.1, "spread": 0.01, "speed": 32.0, "pellets": 1, "pierce": 0, "life": 1.4, "explosive": 4.8, "desc": "Raketwerper. Enorme ontploffing, houd afstand."},
}
# Alleen visuele kogel- en flitsinstellingen; deze waarden veranderen de schietlogica niet.
const WEAPON_VISUALS := {
	"m1911": {"flash_length": 1.35, "flash_width": 0.5, "flash_life": 0.08, "flash_color": Color(1.0, 0.78, 0.38), "flash_particles": 4, "flash_energy": 1.6, "flash_range": 5.2, "trail_every": 1, "trail_length": 3.1, "trail_width": 0.06, "trail_head": Color(1.0, 0.9, 0.42, 1.0), "trail_tail": Color(1.0, 0.52, 0.08, 0.3), "casing_every": 1, "recoil": 0.82},
	"thompson": {"flash_length": 1.05, "flash_width": 0.4, "flash_life": 0.07, "flash_color": Color(1.0, 0.67, 0.27), "flash_particles": 3, "flash_energy": 1.3, "flash_range": 4.8, "trail_every": 1, "trail_length": 2.4, "trail_width": 0.048, "trail_head": Color(1.0, 0.81, 0.22, 1.0), "trail_tail": Color(1.0, 0.41, 0.025, 0.26), "casing_every": 3, "recoil": 0.48},
	"garand": {"flash_length": 1.55, "flash_width": 0.56, "flash_life": 0.09, "flash_color": Color(1.0, 0.84, 0.48), "flash_particles": 5, "flash_energy": 1.8, "flash_range": 5.4, "trail_every": 1, "trail_length": 3.4, "trail_width": 0.058, "trail_head": Color(1.0, 0.88, 0.42, 1.0), "trail_tail": Color(1.0, 0.52, 0.06, 0.3), "casing_every": 1, "recoil": 1.15},
	"trench": {"flash_length": 1.75, "flash_width": 0.7, "flash_life": 0.1, "flash_color": Color(1.0, 0.74, 0.34), "flash_particles": 7, "flash_energy": 2.0, "flash_range": 5.8, "trail_every": 1, "trail_length": 0.78, "trail_width": 0.042, "trail_head": Color(1.0, 0.8, 0.25, 0.95), "trail_tail": Color(0.98, 0.4, 0.025, 0.24), "casing_every": 1, "recoil": 1.35},
	"mg42": {"flash_length": 1.0, "flash_width": 0.4, "flash_life": 0.065, "flash_color": Color(1.0, 0.64, 0.25), "flash_particles": 3, "flash_energy": 1.2, "flash_range": 4.5, "trail_every": 1, "trail_length": 2.5, "trail_width": 0.048, "trail_head": Color(1.0, 0.78, 0.16, 1.0), "trail_tail": Color(1.0, 0.38, 0.02, 0.28), "casing_every": 4, "recoil": 0.38},
	# De bazooka krijgt een raketprojectiel en uitlaatwolk, geen pistoolachtige vlam of tracerbol.
	"bazooka": {"flash_length": 0.0, "flash_width": 0.0, "flash_life": 0.0, "flash_color": Color(0.55, 0.48, 0.36), "flash_particles": 0, "flash_energy": 0.0, "flash_range": 0.0, "trail_every": 0, "trail_length": 0.0, "trail_width": 0.0, "trail_head": Color(0.8, 0.72, 0.55, 0.0), "trail_tail": Color(0.5, 0.42, 0.3, 0.0), "casing_every": 0, "recoil": 1.4},
}
const WEAPON_ORDER := ["m1911", "thompson", "garand", "trench", "mg42", "bazooka"]
const UPGS := [["dmg", "Schade", "+30% schade"], ["rate", "Vuursnelheid", "14% sneller"], ["mag", "Magazijn", "+30% kogels"], ["rel", "Herladen", "18% sneller"]]
const UPG_MAX := 5


## Prijs van het volgende wapenniveau (upgCost in 01-data.js).
static func upg_cost(id: String, lvl: int) -> int:
	return int(round((140.0 + WEAPONS[id].price * 0.22) * (lvl + 1) / 10.0)) * 10


# Vijandtypes. range = schietafstand, rate = seconden tussen aanvallen, burst/pause = salvo's van de MG.
const ETYPES := {
	"knife": {"hp": 45.0, "speed": 4.9, "r": 0.42, "scale": 1.0, "melee": true, "dmg": 10.0, "rate": 0.85, "pts": 50, "color": Color("4c5056")},
	"rifle": {"hp": 65.0, "speed": 3.2, "r": 0.44, "scale": 1.0, "range": 12.0, "dmg": 7.0, "rate": 1.6, "spread": 0.08, "pts": 60, "color": Color("8c7b52")},
	# Canonical standard rifle enemy. `rifle` remains accepted as a compatibility alias for existing tests/tools.
	"assault": {"hp": 65.0, "speed": 3.2, "r": 0.44, "scale": 1.0, "range": 12.0, "dmg": 7.0, "rate": 1.6, "spread": 0.08, "pts": 60, "color": Color("8c7b52"), "gun": "garand"},
	"rocket": {"hp": 85.0, "speed": 2.7, "r": 0.46, "scale": 1.0, "range": 19.0, "dmg": 55.0, "rate": 4.2, "spread": 0.035, "pts": 160, "color": Color("5a4a3a"), "rocket": true, "gun": "rocket"},
	"heavy": {"armor": "zwaar", "hp": 280.0, "speed": 2.2, "r": 0.58, "scale": 1.28, "range": 11.0, "dmg": 6.0, "rate": 0.11, "burst": 9, "pause": 1.9, "spread": 0.13, "pts": 180, "color": Color("3e4a2b")},
}

# Soldatensoorten van de kazerne (Generals-plan C2/C3, Dennis 8 november 2026): kosten, trainingstijd (maal de gewone), gezondheid (maal het niveau), wapen en rol.
# wclass = het soort schade voor het steen-papier-schaar (ARMOR_MULT); "" = neutraal. Waarden zijn voorstellen om te testen.
const SOLDIER_ORDER := ["geweer", "raket", "sluip", "hospik", "ingenieur"]
const SOLDIER_TYPES := {
	"geweer": {"name": "Schutter", "short": "Schutter", "cost": 250, "time": 1.0, "hp": 1.0, "dmg": 1.0, "color": Color("5a6a36"), "gun": "thompson", "wep": "thompson", "range": 16.0, "rate": 0.5, "wclass": "kogel", "desc": "Geweerschutter: gewoon, goedkoop, goed tegen mensen."},
	"raket": {"name": "Raketsoldaat", "short": "Raket", "cost": 400, "time": 1.5, "hp": 0.9, "dmg": 4.4, "color": Color("5a4a3a"), "gun": "rocket", "wep": "bazooka", "range": 22.0, "rate": 3.4, "wclass": "raket", "desc": "Raketsoldaat: zware raket, vooral goed tegen pantser en zware vijanden, traag en slecht tegen losse mensen."},
	"sluip": {"name": "Sluipschutter", "short": "Sluip", "cost": 450, "time": 1.6, "hp": 0.7, "dmg": 5.2, "color": Color("3e5a2b"), "gun": "garand", "wep": "garand", "range": 34.0, "rate": 2.2, "wclass": "scherp", "desc": "Sluipschutter: schiet ver en doodt mensen met \u00e9\u00e9n kogel, doet weinig tegen pantser."},
	"hospik": {"name": "Hospik", "short": "Hospik", "cost": 300, "time": 1.2, "hp": 1.0, "dmg": 0.0, "color": Color("c4c4ae"), "gun": "m1911", "wep": "m1911", "range": 0.0, "rate": 0.0, "wclass": "", "heal": 9.0, "desc": "Hospik: schiet niet, maar heelt jou en je soldaten die dichtbij zijn."},
	"ingenieur": {"name": "Ingenieur", "short": "Ingen.", "cost": 350, "time": 1.4, "hp": 1.0, "dmg": 0.0, "color": Color("9a7a3a"), "gun": "m1911", "wep": "m1911", "range": 0.0, "rate": 0.0, "wclass": "", "repair": 14.0, "desc": "Ingenieur: schiet niet, maar repareert je gebouwen en trucks als er niets te doen is."},
}
# Steen-papier-schaar: schade-vermenigvuldiger per soort schade (wclass van de kogel of raket) tegen het pantser van de vijand ("licht" of "zwaar").
const ARMOR_MULT := {
	"kogel": {"licht": 1.0, "zwaar": 0.5},
	"scherp": {"licht": 2.2, "zwaar": 0.8},
	"raket": {"licht": 0.7, "zwaar": 2.0},
}


## De vermenigvuldiger voor deze soort schade tegen dit pantser; 1.0 voor schade zonder soort (alles wat er al was).
static func counter(wclass: String, armor: String) -> float:
	if wclass == "" or not ARMOR_MULT.has(wclass):
		return 1.0
	return float((ARMOR_MULT[wclass] as Dictionary).get(armor, 1.0))


const PLAYER_SPEED := 6.2
const PLAYER_HP := 100.0
const PLAYER_COLOR := Color("4b5a2c")
const BASE_HP := 1000.0
const START_POINTS := 2000

## De MCV-start (Dennis, 7 november 2026, docs/GENERALS_PLAN.md "Stap MCV"): je begint in een bouwwagen en klapt hem uit als hoofdkwartier; alles gaat uit
## van Game.base_pos. Sinds stap 4b is dit de enige manier om te spelen: het vaste kamp op de oorsprong (muur, poorten, torens, wachthuisjes, generator, oude
## patrouilles) bestaat niet meer.
## Tests (headless) klappen de wagen meteen uit op de oorsprong, waar het oude kamp stond, zodat ze een hoofdkwartier en een speler ernaast hebben. De MCV-tests
## zetten dit uit om zelf te rijden en uit te klappen. In het echte spel (nooit headless) klapt de speler zelf uit.
static var mcv_autodeploy := DisplayServer.get_name() == "headless"
const MCV_RUST := 600.0  # s rust voor de eerste aanvalsgroep, geteld vanaf het uitklappen (Dennis: 10 minuten)

const START_ROAD_HALF := 3.4   # halve breedte van de kale strook (het vroegere pad van de poort) in de jungle rond de startplek; blijft leeg zodat de kaart gelijk blijft
const START_CLEAR := 28.0   # halve breedte van de kale open startplek op de oorsprong waar je begint (er staan daar geen bomen; vroeger de vaste basis)
const WALL_H := 1.55
const BASE_WALL_H := 3.0
const WALL_T := 0.4
const BUNKER_HALF := 2.3
const WORLD_R := 80.0    # in deze proef een kleinere kaart dan de 108 m van de web-versie
const SPAWN_R := 58.0

# Rivier over het noorden van de kaart (05-world.js), 14 m verder naar het noorden dan in de web-versie omdat de basis hier groter is.
const RIVER_HALF := 2.6
const BRIDGE_X := 0.0
const FORD_X := 38.0


## Gebieden in de jungle-strook tussen basismuur en rivier: "moeras" (west), "open" (oost, met rotsen en stammen), anders "dicht".
static func strip_zone(x: float) -> String:
	if x < -22.0:
		return "moeras"
	if x > 16.0 and x < 46.0:
		return "open"
	return "dicht"


## Eerste huis van de stad achter de brug (woonhuis.gd): voordeur naar het zuiden, naar de brug toe.
const HUIS_POS := Vector3(11.0, 0.0, -110.0)
## Winkel met flat erboven (3 lagen), naast het woonhuis aan de oostkant, met een steegje ertussen.
const WINKEL_POS := Vector3(22.0, 0.0, -110.5)
## Oude kerk met toren, aan de westkant van het pad van de brug; de torendeur kijkt naar het zuiden, naar de rivier.
const KERK_POS := Vector3(-14.0, 0.0, -115.0)
## Benzinestation (stad_data.gd): de luifel en de pompen aan de straatkant (+Z).
const BENZINE_POS := Vector3(48.0, 0.0, -111.0)
## Hotel (stad_data.gd): vier lagen met kamers, de entree aan de straatkant (+Z).
const HOTEL_POS := Vector3(-27.0, 0.0, -111.0)

## Midden van de rivier op afstand x: ongeveer 90 m achter de basis, met een bos ertussen.
const RIVER_Z0 := -92.0
const FOREST_Z0 := -30.0   # het bos begint bij de noordmuur
const WORLD_X := 190.0     # kaartrand west/oost, zuid, en noord (voorbij de rivier)
const WORLD_Z_S := 180.0    # +100 m zuidelijke speelruimte; de bestaande 440 m grondplaat loopt al tot z=220
const WORLD_Z_N := 285.0   # Generals-plan D2: de kaart groeit ruim 80 m naar het noorden voor de vijandelijke basis (was 200)
const FOLIAGE_Z_N := 200.0  # tot hier plant foliage.gd de jungle-strook (ongewijzigd, zodat de bestaande vegetatie niet verschuift)

# Vijandelijke basis (Generals-plan stap D2): ver in het noorden achter de stad, 64 x 56 m, poort in de zuidmuur naar jouw basis toe.
const VIJAND_POS := Vector3(-32.0, 0.0, -243.0)
const VIJAND_HALF := Vector2(32.0, 28.0)   # halve breedte (x) en halve diepte (z) van de muur
const VIJAND_GATE := 3.4                   # halve breedte van de poortopening
const GROUND_Z_MIN := -300.0               # noordrand van de grondplaat (level.gd); de zuidrand blijft z = 220

## Wereld per start (W1, Generals-plan los onderdeel "wereld per start"): de jungle wordt elk nieuw spel met een ander
## getal opnieuw neergezet. Blijft op WORLD_SEED_DEFAULT (de oude vaste 11) in de editor, headless/tests en zolang
## randomize_world_seed() niet is aangeroepen, zodat bestaande tests en screenshots exact gelijk blijven.
const WORLD_SEED_DEFAULT := 11
static var world_seed := WORLD_SEED_DEFAULT

## Kiest voor het volgende spel een nieuw willekeurig kaartgetal. Geen opslag en geen zichtbare code (Dennis koos
## "elke start nieuw, onzichtbaar"): elke keer begin() een verse, niet te herhalen jungle.
static func randomize_world_seed() -> void:
	world_seed = 1 + (randi() % 999983)


static func river_z(x: float) -> float:
	return RIVER_Z0 + 5.0 * sin(x * 0.06) + 2.0 * sin(x * 0.15 + 1.0)


## Kronkelpad van de noordpoort door het bos naar de brug (zelfde formule in ground.gdshader).
static func path_x(z: float) -> float:
	var t := clampf((FOREST_Z0 - z) / (-(RIVER_Z0 + 1.8) + FOREST_Z0), 0.0, 1.0)
	return 12.0 * sin(t * 9.6) * sin(t * PI)


## Houdt iets binnen de kaart: een rechthoek die in het noorden voorbij de rivier doorloopt.
static func clamp_world(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, -WORLD_X, WORLD_X), clampf(p.y, -WORLD_Z_N, WORLD_Z_S))


static func river_off(x: float, z: float) -> float:
	return absf(z - river_z(x))


const ENEMY_BULLET_SPEED := 34.0
const ENEMY_BULLET_LIFE := 1.1
const PREP_TIME := 20.0
const GROEP_RUST := 180.0   # s rust voordat de eerste aanvalsgroep uit de vijandbasis komt (Generals-plan stap D2, keuze I)
const GROEP_TUSSEN := 90.0  # s tussen twee aanvalsgroepen daarna: er komt er steeds een, ook als de vorige nog loopt

## Samenstelling van golf n, zoals buildWave() in 13-waves.js .
static func build_wave(n: int) -> Array:
	return _mix(n, 5 + int(n * 3.2))


## Samenstelling van aanvalsgroep n (stap 5a-2): zelfde mix als een golf, maar kleiner omdat er elke 90 s een komt.
static func build_group(n: int) -> Array:
	var kinds := _mix(n, 4 + int(n * 2.4))
	if GameSettings.get_value("enemy_models") == "meshy":
		# Keep the original group size/timing; use only the Meshy Assault
		# archetype, since other enemy types have no validated Meshy rig.
		for i in kinds.size():
			kinds[i] = "assault"
	return kinds


static func _mix(n: int, total: int) -> Array:
	var q := []
	var rockets := 0
	var rifle_share := 0.0 if n < 2 else (0.34 if n < 4 else 0.48)
	for i in total:
		var r := randf()
		var t := "knife"
		if r < rifle_share:
			t = "assault"
		if n >= 4 and r < 0.1 + n * 0.012:
			t = "heavy"
		if n >= 3 and r > 0.94 - n * 0.007 and rockets < 1 + n / 3.0:
			t = "rocket"
			rockets += 1
		q.append(t)
	# Introduce the canonical Assault in the first live wave, replacing one basic knife spawn.
	if n >= 1 and not q.has("assault") and not q.is_empty():
		q[0] = "assault"
	return q
