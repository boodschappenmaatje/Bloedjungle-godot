extends Node3D
## Playable test wrapper around the shipping Main scene and its real camera/HUD/player.
## Desktop: 1–6 select, hold F to fire forward, R reload, WASD move. Touch controls work as usual.

const TARGET := preload("res://scripts/weapon_test_target.gd")
const VEHICLE_AUTO := preload("res://scripts/auto.gd")
const VEHICLE_BUS := preload("res://scripts/bus.gd")

@onready var main: Node3D = $Main
var _keyboard_fire := false
var _help: Label


func _ready() -> void:
	_initialize_zone.call_deferred()


func _initialize_zone() -> void:
	await main.begin()
	var p: Node3D = Game.player
	p.global_position = Vector3(40.0, 0.0, 40.0)
	p.face = PI
	p.rotation.y = PI
	p.set("elev", 0.0)
	Game.move = Vector2.ZERO
	Game.aim = NAN
	Game.fire = false
	Game.loadout = Data.WEAPON_ORDER.duplicate()
	for id: String in Data.WEAPON_ORDER:
		if not Game.owned.has(id):
			Game.owned[id] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": Data.WEAPONS[id].mag}
		Game.owned[id].ammo = Data.WEAPONS[id].mag
	Game.cur = "m1911"
	Game.state = "prep"  # No wave spawns; ordinary player firing and reload flow remain active.
	Game.prep_t = 3600.0
	Game.changed.emit()
	_spawn_targets()
	_add_help()


func _process(_delta: float) -> void:
	if Game.state == "prep":
		Game.prep_t = 3600.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D):
		Game.move = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_F):
		_keyboard_fire = true
		Game.aim = PI
		Game.fire = true
	elif _keyboard_fire:
		_keyboard_fire = false
		Game.fire = false
		Game.aim = NAN


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var index := -1
	match event.keycode:
		KEY_1: index = 0
		KEY_2: index = 1
		KEY_3: index = 2
		KEY_4: index = 3
		KEY_5: index = 4
		KEY_6: index = 5
	if index >= 0:
		Game.cur = Data.WEAPON_ORDER[index]
		Game.changed.emit()
		get_viewport().set_input_as_handled()


func _spawn_targets() -> void:
	# Targets are ranged along the player's default aim, with one strafe target and vehicle damage targets.
	var light := _target("Licht doel · hout", 90.0, Color("a77b45"), 0.9)
	light.position = Vector3(40.0, 0.0, 23.0)
	main.add_child(light)
	var hard := _target("Hard doel · staal", 650.0, Color("59656a"), 1.25)
	hard.position = Vector3(40.0, 0.0, 16.0)
	main.add_child(hard)
	var mover := _target("Bewegend doel", 260.0, Color("8d4938"), 0.85)
	mover.set_meta("move_center", Vector3(44.0, 0.0, 20.0))
	mover.set_meta("move_range", 3.5)
	main.add_child(mover)
	var car: CharacterBody3D = VEHICLE_AUTO.new()
	car.set("kind", "auto")
	car.position = Vector3(48.0, 0.0, 19.0)
	main.add_child(car)
	var bus: CharacterBody3D = VEHICLE_BUS.new()
	bus.set("kind", "bus")
	bus.position = Vector3(55.0, 0.0, 19.0)
	main.add_child(bus)


func _target(label_text: String, hp: float, tint: Color, radius: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "WeaponTestTarget"
	body.collision_layer = Bullet.MASK_ENEMY
	body.collision_mask = 0
	body.set_script(TARGET)
	body.set("label_text", label_text)
	body.set("max_hp", hp)
	body.set("hp", hp)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	shape.position.y = radius + 0.25
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.78
	sphere_mesh.material = material
	mesh.mesh = sphere_mesh
	mesh.position.y = radius + 0.25
	body.add_child(mesh)
	var label := Label3D.new()
	label.text = label_text
	label.position.y = radius * 2.0 + 0.5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	body.add_child(label)
	return body


func _add_help() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WeaponTestControls"
	add_child(layer)
	_help = Label.new()
	_help.name = "Help"
	_help.text = "WEAPON TEST ZONE  ·  1–6 wisselen  ·  F vasthouden: vuur  ·  R: herladen\nWASD of linker stick bewegen  ·  rechter stick: richten en vuren\nTest hout, staal, bewegend doel, auto en bus in de echte gamecamera"
	_help.position = Vector2(22, 18)
	_help.add_theme_font_size_override("font_size", 18)
	_help.add_theme_color_override("font_color", Color("f2e7c6"))
	_help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_help.add_theme_constant_override("shadow_offset_x", 2)
	_help.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_help)
