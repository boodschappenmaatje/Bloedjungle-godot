extends Node
signal changed
signal banner(big: String, small: String, time: float)

var state := "prep"
var build_mode := false
var editing := false
var troop_mode := "follow"
var squad_order := "follow"
var squad_target := Vector3.ZERO
var squad_target_enemy: Node3D
var allies: Array = []
var enemies: Array = []
var equipment_sel := "grenade"
var grenades := 3
var inv := {"mine": 2}
var rang_punten := 0
var kracht_sel := ""
var move := Vector2.ZERO
var aim := NAN
var fire := false
var player: Node3D
