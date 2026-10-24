class_name Data
## Vaste spelwaarden, overgenomen uit de web-versie (src/js/01-data.js, 05-world.js, 12-state.js).
## Afstanden in meters, tijden in seconden, hoeken in radialen.

## Soldaten zijn ietsje groter dan levensgroot zodat ze op de telefoon goed te zien zijn; hutten schalen mee.
const SOLDIER_SCALE := 1.2

# Wapens (01-data.js). rate = seconden tussen schoten, speed = kogelsnelheid (m/s), life = levensduur kogel,
# pierce = extra mensen waar de kogel doorheen gaat, slow = loopsnelheid met dit wapen, explosive = ontploffingsstraal.
# welk schotgeluid bij welk wapen hoort (Sfx)
const WEAPON_SND := {"m1911": "pistol", "thompson": "smg", "garand": "rifle", "trench": "shotgun", "mg42": "mg", "bazooka": "rocket"}
const WEAPONS := {
	"m1911": {"short": "Pistool", "name": "M1911 Pistool", "price": 0, "dmg": 26.0, "rate": 0.19, "mag": 8, "reload": 1.1, "spread": 0.035, "speed": 75.0, "pellets": 1, "pierce": 0, "life": 0.6, "desc": "Betrouwbaar zijwapen. Altijd bij je."},
	"thompson": {"short": "Thompson", "name": "Thompson M1928", "price": 700, "dmg": 18.0, "rate": 0.075, "mag": 30, "reload": 2.0, "spread": 0.08, "speed": 75.0, "pellets": 1, "pierce": 0, "life": 0.55, "desc": "De Tommy gun. Snel, luid en hongerig."},
	"garand": {"short": "Garand", "name": "M1 Garand", "price": 1000, "dmg": 80.0, "rate": 0.3, "mag": 8, "reload": 1.9, "spread": 0.012, "speed": 120.0, "pellets": 1, "pierce": 2, "life": 0.6, "desc": "Semi-automatisch geweer. Kogel gaat door drie man heen."},
	"trench": {"short": "Shotgun", "name": "Winchester M1897", "price": 1400, "dmg": 16.0, "rate": 0.62, "mag": 6, "reload": 2.6, "spread": 0.2, "speed": 65.0, "pellets": 9, "pierce": 0, "life": 0.32, "desc": "Loopgraafshotgun. Van dichtbij blijft er weinig over."},
	"mg42": {"short": "MG 42", "name": "MG 42", "price": 2800, "dmg": 27.0, "rate": 0.05, "mag": 100, "reload": 3.6, "spread": 0.1, "speed": 95.0, "pellets": 1, "pierce": 1, "life": 0.6, "slow": 0.78, "desc": "1200 schoten per minuut. Je loopt er wel trager mee."},
	"bazooka": {"short": "Bazooka", "name": "M1 Bazooka", "price": 3800, "dmg": 240.0, "rate": 1.0, "mag": 1, "reload": 2.1, "spread": 0.01, "speed": 32.0, "pellets": 1, "pierce": 0, "life": 1.4, "explosive": 4.8, "desc": "Raketwerper. Enorme ontploffing, houd afstand."},
}
# Alleen visuele kogel- en flitsinstellingen; deze waarden veranderen de schietlogica niet.
const WEAPON_VISUALS := {
	"m1911": {"flash_length": 1.25, "flash_width": 0.44, "flash_life": 0.08, "flash_color": Color(1.0, 0.76, 0.34), "flash_particles": 3, "flash_energy": 1.5, "flash_range": 5.0, "trail_every": 1, "trail_length": 3.0, "trail_width": 0.052, "trail_head": Color(1.0, 0.86, 0.28, 1.0), "trail_tail": Color(1.0, 0.48, 0.04, 0.28), "casing_every": 1, "recoil": 0.82},
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
	"rocket": {"hp": 85.0, "speed": 2.7, "r": 0.46, "scale": 1.0, "range": 19.0, "dmg": 55.0, "rate": 4.2, "spread": 0.035, "pts": 160, "color": Color("5a4a3a"), "rocket": true, "gun": "rocket"},
	"heavy": {"hp": 280.0, "speed": 2.2, "r": 0.58, "scale": 1.28, "range": 11.0, "dmg": 6.0, "rate": 0.11, "burst": 9, "pause": 1.9, "spread": 0.13, "pts": 180, "color": Color("3e4a2b")},
}

const PLAYER_SPEED := 6.2
const PLAYER_HP := 100.0
const PLAYER_COLOR := Color("4b5a2c")
const BASE_HP := 1000.0
const START_POINTS := 2000

const COMPOUND := 28.0   # halve breedte van de betonmuur rond de basis
const GATE_GAP := 3.4    # halve breedte van de twee poortopeningen (noord en zuid)
const WALL_H := 1.55
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
const WORLD_Z_S := 80.0
const WORLD_Z_N := 200.0


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

## Samenstelling van golf n, zoals buildWave() in 13-waves.js .
static func build_wave(n: int) -> Array:
	var q := []
	var rockets := 0
	var total := 5 + int(n * 3.2)
	var rifle_share := 0.0 if n < 2 else (0.34 if n < 4 else 0.48)
	for i in total:
		var r := randf()
		var t := "knife"
		if r < rifle_share:
			t = "rifle"
		if n >= 4 and r < 0.1 + n * 0.012:
			t = "heavy"
		if n >= 3 and r > 0.94 - n * 0.007 and rockets < 1 + n / 3.0:
			t = "rocket"
			rockets += 1
		q.append(t)
	return q
