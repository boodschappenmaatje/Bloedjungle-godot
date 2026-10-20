class_name Data
## Vaste spelwaarden, overgenomen uit de web-versie (src/js/01-data.js, 05-world.js, 12-state.js).
## Afstanden in meters, tijden in seconden, hoeken in radialen.

## Soldaten zijn ietsje groter dan levensgroot zodat ze op de telefoon goed te zien zijn; hutten schalen mee.
const SOLDIER_SCALE := 1.2

# Wapens. rate = seconden tussen schoten, speed = kogelsnelheid (m/s), life = levensduur kogel.
const WEAPONS := {
	"m1911": {"name": "M1911 Pistool", "dmg": 26.0, "rate": 0.19, "mag": 8, "reload": 1.1, "spread": 0.035, "speed": 75.0, "pellets": 1, "life": 0.6},
	"thompson": {"name": "Thompson M1928", "dmg": 18.0, "rate": 0.075, "mag": 30, "reload": 2.0, "spread": 0.08, "speed": 75.0, "pellets": 1, "life": 0.55},
	"garand": {"name": "M1 Garand", "dmg": 80.0, "rate": 0.3, "mag": 8, "reload": 1.9, "spread": 0.012, "speed": 120.0, "pellets": 1, "life": 0.6},
	"trench": {"name": "Winchester M1897", "dmg": 16.0, "rate": 0.62, "mag": 6, "reload": 2.6, "spread": 0.2, "speed": 65.0, "pellets": 9, "life": 0.32},
}

# Vijandtypes. range = schietafstand, rate = seconden tussen aanvallen, burst/pause = salvo's van de MG.
const ETYPES := {
	"knife": {"hp": 45.0, "speed": 4.9, "r": 0.42, "scale": 1.0, "melee": true, "dmg": 10.0, "rate": 0.85, "pts": 50, "color": Color("4c5056")},
	"rifle": {"hp": 65.0, "speed": 3.2, "r": 0.44, "scale": 1.0, "range": 12.0, "dmg": 7.0, "rate": 1.6, "spread": 0.08, "pts": 60, "color": Color("8c7b52")},
	"heavy": {"hp": 280.0, "speed": 2.2, "r": 0.58, "scale": 1.28, "range": 11.0, "dmg": 6.0, "rate": 0.11, "burst": 9, "pause": 1.9, "spread": 0.13, "pts": 180, "color": Color("3e4a2b")},
}

const PLAYER_SPEED := 6.2
const PLAYER_HP := 100.0
const PLAYER_COLOR := Color("4b5a2c")
const BASE_HP := 1000.0
const START_POINTS := 300

const COMPOUND := 14.0   # halve breedte van de betonmuur rond de basis
const GATE_GAP := 2.4    # halve breedte van de twee poortopeningen (noord en zuid)
const WALL_H := 1.55
const WALL_T := 0.4
const BUNKER_HALF := 2.3
const WORLD_R := 60.0    # in deze proef een kleinere kaart dan de 108 m van de web-versie
const SPAWN_R := 46.0

const ENEMY_BULLET_SPEED := 34.0
const ENEMY_BULLET_LIFE := 1.1
const PREP_TIME := 20.0

## Samenstelling van golf n, zoals buildWave() in 13-waves.js (zonder raketwerpers).
static func build_wave(n: int) -> Array:
	var q := []
	var total := 5 + int(n * 3.2)
	var rifle_share := 0.0 if n < 2 else (0.34 if n < 4 else 0.48)
	for i in total:
		var r := randf()
		var t := "knife"
		if r < rifle_share:
			t = "rifle"
		if n >= 4 and r < 0.1 + n * 0.012:
			t = "heavy"
		q.append(t)
	return q
