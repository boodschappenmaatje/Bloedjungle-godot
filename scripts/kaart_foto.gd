class_name KaartFoto
extends Node
## Luchtfoto van jouw wereld voor de radar en de grote kaart (Dennis' keuze 2A, 11 nov 2026).
## Een kleine orthografische camera fotografeert de wereld recht van boven in 4 x 5 tegels, één tegel per beeld,
## en plakt ze aan elkaar tot één plaatje. Laag boven elke tegel, zodat bomen en struiken binnen hun zichtafstand blijven
## (Foliage tekent ver weg geen gebladerte). Zo kost het per beeld maar één kleine extra tekening en nooit een lange hapering.
## Daarna is het een gewoon plaatje: de radar en de kaart tekenen het zonder iets te herberekenen.
## Zonder echte grafische kaart (headless tests) blijft het plaatje leeg en tekenen radar en kaart het terrein in vlakken.

const COLS := 4
const ROWS := 5
const TILE_PX := Vector2i(160, 157)   # 95 x 93 m per tegel: ongeveer 1,7 pixel per meter, ook ingezoomd nog scherp genoeg
const HEIGHT := 40.0                   # m boven de grond: binnen de zichtafstand van palmen, struiken en varens (Foliage.VIS_END)
const REFRESH := 75.0                  # s: een kaart die ouder is wordt bij het openen opnieuw gefotografeerd (nieuwe gebouwen, brand)

static var tex: Texture2D              # het hele plaatje; null zolang er nog geen foto is
static var made_at := -1000.0          # echte tijd (s) van de laatste volledige foto

var _vp: SubViewport
var _cam: Camera3D
var _img: Image
var _tile := -1                        # tegel die nu gefotografeerd wordt; -1 = niets bezig
var _wait := 0
var _start_delay := -1


func _ready() -> void:
	name = "KaartFoto"
	process_mode = Node.PROCESS_MODE_ALWAYS
	tex = null
	made_at = -1000.0


static func age() -> float:
	return Time.get_ticks_msec() / 1000.0 - made_at


func busy() -> bool:
	return _tile >= 0 or _start_delay >= 0


## Vraag een nieuwe foto aan, `delay` beelden later (de wereld moet eerst staan).
func request(delay := 0) -> void:
	if busy():
		return
	_start_delay = delay


func _process(_delta: float) -> void:
	if _start_delay >= 0:
		_start_delay -= 1
		if _start_delay < 0:
			_begin()
		return
	if _tile < 0:
		return
	_wait -= 1
	if _wait > 0:
		return
	# de vorige tegel is getekend: overnemen en de volgende klaarzetten
	var shot := _vp.get_texture().get_image() if _vp != null else null
	if shot == null or shot.is_empty():
		_finish(false)   # geen grafische kaart: dan maar zonder foto
		return
	if shot.get_format() != Image.FORMAT_RGBA8:
		shot.convert(Image.FORMAT_RGBA8)
	var cx := _tile % COLS
	var cy := _tile / COLS
	_img.blit_rect(shot, Rect2i(Vector2i.ZERO, TILE_PX), Vector2i(cx * TILE_PX.x, cy * TILE_PX.y))
	_tile += 1
	if _tile >= COLS * ROWS:
		_finish(true)
		return
	_aim_tile()


func _begin() -> void:
	if DisplayServer.get_name() == "headless":
		return   # headless: niets te fotograferen
	_img = Image.create(COLS * TILE_PX.x, ROWS * TILE_PX.y, false, Image.FORMAT_RGBA8)
	_vp = SubViewport.new()
	_vp.size = TILE_PX
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_vp.positional_shadow_atlas_size = 0
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.near = 0.5
	_cam.far = HEIGHT + 40.0
	_cam.environment = _environment()
	_cam.rotation = Vector3(-PI * 0.5, 0.0, 0.0)   # recht naar beneden, noorden (−z) boven in beeld zoals op de radar
	_vp.add_child(_cam)
	_cam.current = true
	_tile = 0
	_aim_tile()


func _aim_tile() -> void:
	var tw := 2.0 * Data.WORLD_X / float(COLS)
	var th := (Data.WORLD_Z_N + Data.WORLD_Z_S) / float(ROWS)
	var cx := _tile % COLS
	var cy := _tile / COLS
	_cam.size = th
	_cam.global_position = Vector3(-Data.WORLD_X + (float(cx) + 0.5) * tw, HEIGHT, -Data.WORLD_Z_N + (float(cy) + 0.5) * th)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_wait = 2


func _finish(ok: bool) -> void:
	if ok:
		_img.generate_mipmaps()   # de radar tekent het plaatje veel kleiner: zonder mipmaps wordt het korrelig
		tex = ImageTexture.create_from_image(_img)
		made_at = Time.get_ticks_msec() / 1000.0
	_img = null
	_tile = -1
	if _vp != null:
		_vp.queue_free()
	_vp = null
	_cam = null


## Licht en lucht voor de foto: geen mist of nevel van het spel, wel een helder daglicht, ook als je 's nachts speelt.
func _environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.2, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.9, 0.8)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	return env
