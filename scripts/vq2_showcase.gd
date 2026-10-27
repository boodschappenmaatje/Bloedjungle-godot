extends Node3D
## Review inside the existing jungle/main scene. No production camera/settings changes.

const MAIN := preload("res://scenes/main.tscn")
const ANCHOR := Vector3(0, 0, 52)
const ASSETS := ["kazerne", "wachttoren", "legerjeep", "jeep", "grass_short", "grass_medium", "grass_tall", "grass_all"]
@export var initial_asset := "kazerne"
var main: Node3D
var subject: Node3D
var tower: Node3D
var player: CharacterBody3D
var camera: Camera3D
var selected := "kazerne"
var version := "v2"
var is_ready := false
var ui: CanvasLayer
var panel: VBoxContainer
var asset_picker: OptionButton
var version_picker: OptionButton
var clips: OptionButton
var info: Label
var demo_anim: AnimationPlayer
var clip_play_button: Button
var clip_pause_button: Button
var _capture_manifest: Array = []
var _jeep_rest: Dictionary = {}


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	Progress.autostart = false
	main = MAIN.instantiate()
	add_child(main)
	await main.begin()
	main.set_process(false) # disable wave spawning only in this review scene
	Game.state = "prep"
	Game.prep_t = 3600.0
	player = Game.player
	camera = main.get_node("Camera")
	camera.make_current()
	_build_ui()
	is_ready = true
	select_asset(initial_asset, "v2")
	if "--vq2-capture" in OS.get_cmdline_user_args():
		await _captures()


func _process(_delta: float) -> void:
	if main == null:
		return
	# Existing touch movement stays active; suppress the ordinary combat HUD in the lab.
	var hud: CanvasLayer = main.get_node("Hud")
	for child in hud.get_children():
		if child.name != "Sticks":
			if child is CanvasItem:
				child.hide()
			elif child is CanvasLayer:
				child.visible = false
	for menu in get_tree().get_nodes_in_group("menus"):
		if menu is CanvasItem:
			menu.hide()
		elif menu is CanvasLayer:
			menu.visible = false


func select_asset(asset: String, revision := "v2") -> void:
	if not is_ready:
		return
	if subject != null:
		if selected == "jeep" and subject.get("driven"):
			subject.call("_toggle")
		player.climb = -1.0
		player.elev = 0.0
		player.tower = null
		player.collision_mask = player.get("_mask0")
		main.remove_child(subject)
		subject.queue_free()
	selected = asset
	version = "v2" if asset == "jeep" else revision
	asset_picker.select(ASSETS.find(asset))
	version_picker.select(0 if version == "v2" else 1)
	tower = null
	demo_anim = null
	_jeep_rest.clear()
	match asset:
		"kazerne":
			subject = Game.builds.make_node("kazerne")
			if version == "v1":
				_replace_visual(subject, "kazerne", "kazerne")
		"wachttoren":
			subject = Node3D.new()
			BaseProps._tower(subject, Vector3.ZERO)
			tower = subject.get_child(0)
			tower.rotation.y = 0.0
			if version == "v1":
				_replace_visual(tower, "wachttoren", "toren")
		"legerjeep":
			subject = load("res://scenes/legerjeep.tscn").instantiate()
			if version == "v1":
				_replace_visual(subject, "legerjeep")
		"jeep":
			subject = load("res://scenes/jeep.tscn").instantiate()
		_:
			if asset.begins_with("grass_"):
				subject = GrassField.preview(asset.trim_prefix("grass_"), version == "v1")
	subject.position = ANCHOR
	main.add_child(subject)
	player.global_position = ANCHOR + Vector3(0, 0, 5)
	player.visible = true
	Game.fire = false
	Game.move = Vector2.ZERO
	Game.aim = NAN
	clips.clear()
	if asset == "jeep":
		subject.set_physics_process(false)
		demo_anim = subject.get_node("Model/AnimationPlayer")
		for node: Node3D in subject.get_node("Model").find_children("*", "Node3D", true, false):
			_jeep_rest[node] = node.transform
		for clip in demo_anim.get_animation_list():
			if clip != "RESET":
				clips.add_item(clip)
	else:
		clips.add_item("Geen animaties in dit model")
	clips.disabled = demo_anim == null
	clip_play_button.disabled = demo_anim == null
	clip_pause_button.disabled = demo_anim == null
	version_picker.disabled = asset == "jeep"
	info.text = "%s · %s · echte gameplaywereld" % [asset.to_upper(), version.to_upper()]
	if asset.begins_with("grass_"):
		info.text = "3D-GRAS · 2K PBR · wind via Godot-shader, geen GLB-clip"
	preset(false)


func _replace_visual(body: Node3D, asset: String, skin := "") -> void:
	for child in body.get_children():
		if not child is CollisionShape3D and not child is StaticBody3D:
			body.remove_child(child)
			child.queue_free()
	var visual: Node3D = load("res://assets/vq2_baseline/%s.glb" % asset).instantiate()
	if not skin.is_empty():
		Kit.skin(visual, skin)
	body.add_child(visual)


func preset(game_camera: bool) -> void:
	camera.set_process(false)
	camera.fov = 45.0 # exact current gameplay FOV; only this scene camera instance
	if game_camera:
		var a := deg_to_rad(58.0)
		camera.global_position = ANCHOR + Vector3(0, sin(a) * 28.0, cos(a) * 28.0)
		camera.look_at(ANCHOR)
	else:
		var h := 8.4 if selected == "wachttoren" else (3.8 if selected == "kazerne" else (1.5 if selected.begins_with("grass_") else 2.8))
		var target := ANCHOR + Vector3(0, h * 0.45, 0)
		camera.global_position = target + Vector3(1, 0.8, 1.3).normalized() * (h * 2.3 + 3.0)
		camera.look_at(target)


func play_clip(_index := -1) -> void:
	if demo_anim == null:
		return
	subject.set_physics_process(false)
	_reset_clip_pose()
	demo_anim.play(clips.get_item_text(clips.selected))
	demo_anim.seek(0.0, true)


func _reset_clip_pose() -> void:
	demo_anim.stop()
	for node: Node3D in _jeep_rest:
		if is_instance_valid(node):
			node.transform = _jeep_rest[node]


func pause_clip() -> void:
	if demo_anim:
		if demo_anim.is_playing():
			demo_anim.pause()
		else:
			demo_anim.play()


func drive() -> void:
	if selected != "jeep":
		select_asset("jeep")
	_reset_clip_pose()
	subject.set_physics_process(true)
	player.global_position = subject.global_position + Vector3(2, 0, 0)
	if not subject.get("driven"):
		subject.call("_toggle")
	camera.set_process(true)
	info.text = "RIJ ZELF · bestaande linker/rechter touchstick · IN/UIT om uit te stappen"


func climb() -> void:
	if selected != "wachttoren":
		select_asset("wachttoren")
	player.global_position = tower.to_global(Vector3(1.8, 0, 0))
	player.climb_cd = 0.0
	player.call("_find_stairs", Vector2(-1, 0))
	camera.set_process(true)
	info.text = "KLIMMEN · bestaande ladderlogica · dak verdwijnt op platform"


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	var box := PanelContainer.new()
	ui.add_child(box)
	var safe := UI.safe_margins(get_viewport().get_visible_rect().size, 14.0)
	box.position = Vector2(safe.x, safe.y)
	box.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.07, 0.05, 0.94), UI.BRASS, 1, 6, 8))
	panel = VBoxContainer.new()
	box.add_child(panel)
	info = Label.new()
	panel.add_child(info)
	var row := HBoxContainer.new()
	panel.add_child(row)
	asset_picker = OptionButton.new()
	for asset in ASSETS:
		asset_picker.add_item({"grass_short": "Gras kort", "grass_medium": "Gras middelhoog", "grass_tall": "Gras hoog", "grass_all": "Alle grashoogtes"}.get(asset, asset.capitalize()))
	row.add_child(asset_picker)
	version_picker = OptionButton.new()
	version_picker.add_item("Nieuw VQ2")
	version_picker.add_item("Oud V1")
	row.add_child(version_picker)
	asset_picker.item_selected.connect(func(i: int): select_asset(ASSETS[i], "v1" if version_picker.selected == 1 else "v2"))
	version_picker.item_selected.connect(func(i: int): select_asset(selected, "v1" if i == 1 else "v2"))
	var cameras := HBoxContainer.new()
	panel.add_child(cameras)
	_button(cameras, "Schuin", func(): preset(false))
	_button(cameras, "Gamecamera", func(): preset(true))
	_button(cameras, "Loop zelf", func(): camera.set_process(true))
	_button(cameras, "Wind", func():
		var on := GameSettings.get_value("wind") != "on"
		GameSettings.values["wind"] = "on" if on else "off"
		Foliage.set_wind(on))
	clips = OptionButton.new()
	panel.add_child(clips)
	clips.item_selected.connect(play_clip)
	var actions := HBoxContainer.new()
	panel.add_child(actions)
	clip_play_button = _button(actions, "Clip afspelen", play_clip)
	clip_pause_button = _button(actions, "Pauze", pause_clip)
	_button(actions, "Rij zelf", drive)
	_button(actions, "Klim toren", climb)
	for button in panel.find_children("*", "BaseButton", true, false):
		button.custom_minimum_size.y = 44
		button.add_to_group("hud_button")


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _save_capture(name: String) -> void:
	get_tree().paused = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "res://docs/vq2/renders/" + name + ".png"
	image.save_png(path)
	_capture_manifest.append({"file": path, "sha256": FileAccess.get_sha256(path), "size": [image.get_width(), image.get_height()],
		"asset": selected, "version": version, "camera_position": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
		"camera_rotation": [camera.global_rotation.x, camera.global_rotation.y, camera.global_rotation.z], "fov": camera.fov,
		"exposure": get_world_3d().environment.tonemap_exposure, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name()})
	get_tree().paused = false
	print("VQ2_GODOT_CAPTURE ", name)


func _captures() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/vq2/renders")
	player.set_physics_process(false)
	player.hide()
	ui.hide()
	main.get_node("Hud").hide()
	for asset in ["kazerne", "wachttoren", "legerjeep"]:
		for revision in ["v1", "v2"]:
			select_asset(asset, revision)
			player.hide()
			preset(true)
			for _i in 5:
				await get_tree().process_frame
			await _save_capture("%s-godot-game-%s" % [asset, revision])
	select_asset("jeep")
	player.hide()
	for clip in ["Rijden", "Bocht", "Vuren"]:
		for i in clips.item_count:
			if clips.get_item_text(i) == clip:
				clips.select(i)
		play_clip()
		demo_anim.seek(0.7 if clip == "Bocht" else (0.13 if clip == "Vuren" else 0.17), true)
		demo_anim.pause()
		for _i in 3:
			await get_tree().process_frame
		await _save_capture("jeep-" + clip.to_lower())
	var manifest := FileAccess.open("res://docs/vq2/results/godot-captures.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(_capture_manifest, "  ") + "\n")
	get_tree().quit(0)
