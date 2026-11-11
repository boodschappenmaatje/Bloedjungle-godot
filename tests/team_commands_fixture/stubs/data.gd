class_name Data
extends RefCounted

const SOLDIER_SCALE := 1.0
const COMPOUND := 14.0
const WEAPON_VISUALS := {"thompson": {"trail_every": 1, "casing_every": 3}}
# Alleen de soort die de fixture gebruikt (de echte lijst staat in scripts/data.gd).
const SOLDIER_TYPES := {
	"geweer": {"name": "Schutter", "short": "Schutter", "cost": 250, "time": 1.0, "hp": 1.0, "dmg": 1.0, "color": Color("5a6a36"), "gun": "thompson", "wep": "thompson", "range": 16.0, "rate": 0.5, "wclass": "kogel"},
}
