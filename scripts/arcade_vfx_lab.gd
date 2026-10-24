extends Node3D
## Afgesloten testomgeving: gebruikt de echte speler, camera, projectielen en Fx zonder golfspawns.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const PROFILE: ArcadeVfxProfile = preload("res://resources/arcade_vfx_profile.tres")

var game_scene: Node3D
var player: CharacterBody3D
var test_enemy: CharacterBody3D
var targets: Dictionary = {}
var selected_target := "enemy"
var is_lab_ready := false
var _scenario_time := 0.0
var _scenario_move := Vector2.ZERO
var _sticks: Control
var _hud: CanvasLayer

@onready var target_status: Label = $LabUI/Panel/Layout/TargetStatus
@onready var ready_status: Label = $LabUI/Panel/Layout/ReadyStatus


func _ready() -> void:
	process_priority = 100
	_style_controls()
	$LabUI/Panel/Layout/Targets/Earth.pressed.connect(choose_target.bind("earth"))
	$LabUI/Panel/Layout/Targets/Concrete.pressed.connect(choose_target.bind("concrete"))
	$LabUI/Panel/Layout/Targets/Metal.pressed.connect(choose_target.bind("metal"))
	$LabUI/Panel/Layout/Targets/Enemy.pressed.connect(choose_target.bind("enemy"))
	$LabUI/Panel/Layout/Actions/Single.pressed.connect(run_scenario.bind("single"))
	$LabUI/Panel/Layout/Actions/Burst.pressed.connect(run_scenario.bind("burst"))
	$LabUI/Panel/Layout/Actions/MoveFire.pressed.connect(run_scenario.bind("move_fire"))
	$LabUI/Panel/Layout/Actions/Reset.pressed.connect(reset_lab)
	get_viewport().size_changed.connect(_place_panel)
	call_deferred("_setup_lab")


func _setup_lab() -> void:
	# Main mag de opgeslagen autostart niet gebruiken: de labscène start zelf één wereld zonder golven.
	Progress.autostart = false
	game_scene = MAIN_SCENE.instantiate()
	add_child(game_scene)
	# When main is embedded in this lab, explicitly activate its gameplay camera.
	(game_scene.get_node("Camera") as Camera3D).make_current()
	for menu in get_tree().get_nodes_in_group("menus"):
		menu.hide()
	await game_scene.call("begin")
	game_scene.set_process(false)  # stopt alleen de golfspawner; speler, camera en wereld blijven actief
	for menu in get_tree().get_nodes_in_group("menus"):
		menu.hide()
	_hud = game_scene.get_node("Hud") as CanvasLayer
	_sticks = _hud.get_node("Sticks") as Control
	_sticks.show()
	_sticks.set_process(true)
	_suppress_game_hud()
	player = Game.player as CharacterBody3D
	player.global_position = Vector3(0.0, 0.0, 50.0)
	player.face = PI
	player.rotation.y = PI
	player.arcade_vfx_profile = PROFILE
	player.fire_t = 0.0
	player.reload_t = 0.0
	player.ammo = Data.WEAPONS.m1911.mag
	Game.owned["m1911"].ammo = player.ammo
	Game.state = "play"
	Game.prep_t = 3600.0
	Game.fire = false
	Game.move = Vector2.ZERO
	Game.aim = NAN
	_build_targets()
	Game.changed.emit()
	is_lab_ready = true
	ready_status.text = "KLAAR · GEEN GOLF"
	choose_target("enemy")
	_place_panel()


func _build_targets() -> void:
	targets["earth"] = _add_surface_target("AARDE", "dirt", Vector3(4.8, 0.0, 40.0), "res://assets/textures/terrain/dry_earth/base_color.jpg", Color(0.48, 0.31, 0.16))
	targets["concrete"] = _add_surface_target("BETON", "concrete", Vector3(8.0, 0.0, 40.0), "res://assets/textures/buildings/concrete/base_color.jpg", Color(0.58, 0.56, 0.5))
	targets["metal"] = _add_surface_target("METAAL", "metal", Vector3(12.0, 0.0, 40.0), "res://assets/textures/buildings/rusted_metal/base_color.jpg", Color(0.31, 0.32, 0.29))
	test_enemy = ENEMY_SCENE.instantiate() as CharacterBody3D
	test_enemy.call("setup", "knife", 1)
	game_scene.add_child(test_enemy)
	test_enemy.global_position = Vector3(0.0, 0.0, 42.0)
	test_enemy.set_physics_process(false)  # houdt de collider actief maar bevriest de AI voor herhaalbare treffers
	test_enemy.hp = 5000.0
	test_enemy.max_hp = 5000.0
	test_enemy.face = 0.0
	targets["enemy"] = test_enemy


func _add_surface_target(label: String, material_name: String, at: Vector3, texture_path: String, fallback_color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TestTarget_%s" % label
	body.set_script(load("res://scripts/arcade_vfx_target.gd"))
	body.collision_layer = Bullet.MASK_WALL
	body.collision_mask = 0
	body.set_meta("impact_material", material_name)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 1.8, 0.32)
	shape.shape = box
	shape.position.y = 0.9
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(3.0, 1.8, 0.32)
	mesh.mesh = box_mesh
	mesh.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = fallback_color
	material.roughness = 0.88
	if ResourceLoader.exists(texture_path):
		material.albedo_texture = load(texture_path)
	if material_name == "metal":
		material.metallic = 0.55
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	body.position = at
	game_scene.add_child(body)
	return body


func choose_target(target_id: String) -> void:
	if not is_lab_ready or not targets.has(target_id):
		return
	selected_target = target_id
	target_status.text = "DOEL: %s" % target_id.to_upper()
	var target_buttons := {"earth": "Earth", "concrete": "Concrete", "metal": "Metal", "enemy": "Enemy"}
	for option in target_buttons:
		var button: Button = $LabUI/Panel/Layout/Targets.get_node(target_buttons[option]) as Button
		button.button_pressed = option == target_id
	_sticks.set_process(false)
	_set_aim(target_id)
	await get_tree().create_timer(0.2).timeout
	if _scenario_time <= 0.0:
		_sticks.set_process(true)


func _set_aim(target_id: String) -> void:
	var target: Node3D = targets[target_id]
	var aim_at := target.global_position + Vector3.UP * 0.9
	if target_id == "enemy":
		aim_at = target.global_position + Vector3.UP * 1.0
	var muzzle: Vector3 = player.model.muzzle_position()
	var to := aim_at - muzzle
	Game.aim = atan2(to.x, to.z)


func run_scenario(mode: String) -> void:
	if not is_lab_ready or _scenario_time > 0.0:
		return
	_sticks.set_process(false)
	_set_aim(selected_target)
	await get_tree().create_timer(0.16).timeout
	player.fire_t = 0.0
	match mode:
		"single":
			_scenario_time = 0.11
			_scenario_move = Vector2.ZERO
			ready_status.text = "TEST · ÉÉN SCHOT"
		"burst":
			_scenario_time = 0.92
			_scenario_move = Vector2.ZERO
			ready_status.text = "TEST · BURST"
		"move_fire":
			_scenario_time = 1.1
			_scenario_move = Vector2(0.0, -0.65)
			ready_status.text = "TEST · LOPEN + SCHIETEN"
		_:
			_sticks.set_process(true)


func _process(delta: float) -> void:
	_suppress_game_hud()
	if _scenario_time <= 0.0:
		return
	_scenario_time = maxf(0.0, _scenario_time - delta)
	Game.fire = _scenario_time > 0.0
	Game.move = _scenario_move if _scenario_time > 0.0 else Vector2.ZERO
	if _scenario_time <= 0.0:
		_scenario_move = Vector2.ZERO
		_sticks.set_process(true)
		ready_status.text = "KLAAR · GEEN GOLF"


func reset_lab() -> void:
	if player == null or not is_lab_ready:
		return
	_scenario_time = 0.0
	_scenario_move = Vector2.ZERO
	Game.fire = false
	Game.move = Vector2.ZERO
	_sticks.set_process(true)
	player.global_position = Vector3(0.0, 0.0, 50.0)
	player.face = PI
	player.rotation.y = PI
	player.fire_t = 0.0
	player.reload_t = 0.0
	player.ammo = Data.WEAPONS.m1911.mag
	Game.owned["m1911"].ammo = player.ammo
	if test_enemy != null and is_instance_valid(test_enemy):
		test_enemy.hp = test_enemy.max_hp
		test_enemy.dead = false
	Game.changed.emit()
	ready_status.text = "KLAAR · GEEN GOLF"


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: choose_target("earth")
		KEY_2: choose_target("concrete")
		KEY_3: choose_target("metal")
		KEY_4: choose_target("enemy")
		KEY_F1: run_scenario("single")
		KEY_F2: run_scenario("burst")
		KEY_F3: run_scenario("move_fire")


func _place_panel() -> void:
	if not is_inside_tree():
		return
	var safe := UI.safe_margins(get_viewport().get_visible_rect().size)
	$LabUI/Panel.position = Vector2(safe.x, safe.y)


func _suppress_game_hud() -> void:
	if _hud == null:
		return
	for child in _hud.get_children():
		if child != _sticks:
			_hide_hud_branch(child)


func _hide_hud_branch(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).hide()
	elif node is CanvasLayer:
		(node as CanvasLayer).visible = false
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_hide_hud_branch(child)


func _style_controls() -> void:
	var panel: PanelContainer = $LabUI/Panel
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.035, 0.045, 0.035, 0.94), UI.BRASS.darkened(0.32), 1, 8, 8))
	var layout: VBoxContainer = $LabUI/Panel/Layout
	layout.add_theme_constant_override("separation", 5)
	for label_path in ["TargetStatus", "ReadyStatus", "Hint"]:
		var label: Label = layout.get_node(label_path)
		label.add_theme_font_override("font", UI.body(700))
		label.add_theme_font_size_override("font_size", 16 if label_path != "Hint" else 13)
		label.add_theme_color_override("font_color", UI.INK if label_path != "Hint" else UI.INK_DIM)
	var target_group := ButtonGroup.new()
	for row_path in ["Targets", "Actions"]:
		var row: HBoxContainer = layout.get_node(row_path)
		row.add_theme_constant_override("separation", 5)
		for child in row.get_children():
			if child is Button:
				var button := child as Button
				if row_path == "Targets":
					button.toggle_mode = true
					button.button_group = target_group
				button.add_theme_font_override("font", UI.body(700))
				button.add_theme_font_size_override("font_size", 16)
				button.add_theme_color_override("font_color", UI.INK)
				button.add_theme_color_override("font_hover_color", Color.WHITE)
				button.add_theme_color_override("font_pressed_color", UI.BRASS)
				button.add_theme_stylebox_override("normal", UI.bevel(UI.box(Color(0.09, 0.11, 0.075, 0.96), Color("657144"), 1, 6, 4), 3))
				button.add_theme_stylebox_override("hover", UI.bevel(UI.box(Color(0.16, 0.18, 0.105, 0.98), UI.BRASS, 1, 6, 4), 3))
				button.add_theme_stylebox_override("pressed", UI.bevel(UI.box(Color(0.12, 0.13, 0.08, 1.0), UI.BRASS, 1, 6, 4), 1, true))
				button.add_theme_stylebox_override("focus", UI.box(Color(0.09, 0.11, 0.075, 0.96), Color("657144"), 1, 6, 4))
