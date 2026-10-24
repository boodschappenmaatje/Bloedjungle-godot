extends Node3D
## Original SVG asset look-dev preview. Does not call Bullet, Fx, Player, SoldierModel or Sfx.
## Renderer verification and Xogot/iPhone performance checks are still required.

const TEX = "res://assets/vfx/weapons/m1911/source_svg/"
var target_id := 0
var quality_high := false
var flash_index := 0

func _ready() -> void:
    var camera := Camera3D.new()
    add_child(camera)
    camera.position = Vector3(0, 13, 14)
    camera.look_at(Vector3(0, 0, 0))
    camera.fov = 48.0
    camera.current = true
    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(21, 19)
    ground.mesh = plane
    var ground_mat := StandardMaterial3D.new()
    ground_mat.albedo_color = Color(0.13, 0.17, 0.13)
    ground.material_override = ground_mat
    add_child(ground)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-50, 25, 0)
    light.light_energy = 0.75
    add_child(light)
    _show_sprite("ground_glow.svg", Vector3(0, 0.05, 3.5), 0.007, 1.0)
    _build_buttons()
    _fire()

func _build_buttons() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var controls := HBoxContainer.new()
    controls.position = Vector2(16, 20)
    canvas.add_child(controls)
    var fire := Button.new()
    fire.text = "M1911 SCHOT"
    fire.custom_minimum_size = Vector2(148, 56)
    controls.add_child(fire)
    fire.pressed.connect(_fire)
    var change := Button.new()
    change.text = "ANDER DOEL"
    change.custom_minimum_size = Vector2(148, 56)
    controls.add_child(change)
    change.pressed.connect(func(): target_id = (target_id + 1) % 4; _fire())
    var quality := Button.new()
    quality.text = "LOW / HIGH"
    quality.custom_minimum_size = Vector2(148, 56)
    controls.add_child(quality)
    quality.pressed.connect(func(): quality_high = not quality_high; _fire())

func _show_sprite(name: String, pos: Vector3, pixel_scale: float, seconds: float) -> void:
    var sprite := Sprite3D.new()
    sprite.texture = load(TEX + name)
    sprite.pixel_size = pixel_scale
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.shaded = false
    sprite.no_depth_test = false
    add_child(sprite)
    sprite.global_position = pos
    if seconds > 0:
        var t := create_tween()
        t.tween_property(sprite, "modulate:a", 0.0, seconds)
        t.finished.connect(sprite.queue_free)

func _fire() -> void:
    flash_index = (flash_index + 1) % 3
    var muzzle := "muzzle_%02d.svg" % [flash_index + 1]
    _show_sprite(muzzle, Vector3(0, 1.1, 3.5), 0.0034, 0.10 if quality_high else 0.07)
    _show_sprite("tracer.svg", Vector3(0.0, 1.2, 0.0), 0.008, 0.12 if quality_high else 0.08)
    var impact := ["dirt_puff.svg", "concrete_puff.svg", "metal_sparks.svg", "blood_splash.svg"][target_id]
    get_tree().create_timer(0.07).timeout.connect(func():
        if is_inside_tree():
            _show_sprite(impact, Vector3(0, 1.1, -4.0), 0.0026, 0.32 if quality_high else 0.2)
    )
