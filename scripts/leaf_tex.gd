class_name LeafTex
## Bladtexturen met doorzichtige randen, zelf getekend bij het opstarten: palmtak met bladpunten,
## breed jungleblad met nerven, varen en grassprieten. De vorm zit in de alfa; foliage.gdshader
## knipt alles weg wat doorzichtig is. Eigen tekenwerk dus geen losse plaatjes nodig.

static var _cache := {}


static func get_tex(kind: String) -> ImageTexture:
	if not _cache.has(kind):
		var img: Image
		match kind:
			"palm": img = _palm()
			"leaf": img = _leaf()
			"fern": img = _fern()
			_: img = _grass()
		img.generate_mipmaps()
		_cache[kind] = ImageTexture.create_from_image(img)
	return _cache[kind]


static func _blank(w: int, h: int) -> Image:
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Dikke lijn met een ronde kwast; kleur loopt van c0 naar c1 over de lengte.
static func _line(img: Image, a: Vector2, b: Vector2, width: float, c0: Color, c1: Color) -> void:
	var len := a.distance_to(b)
	var steps := int(len * 1.5) + 1
	for i in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t)
		var col := c0.lerp(c1, t)
		var r := width * 0.5 * (1.0 - 0.6 * t)  # loopt dun uit
		for dx in range(-ceili(r), ceili(r) + 1):
			for dy in range(-ceili(r), ceili(r) + 1):
				if dx * dx + dy * dy > r * r + 0.3:
					continue
				var x := int(p.x) + dx
				var y := int(p.y) + dy
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, col)


## 256 x 128: de nerf loopt links naar rechts, aan weerszijden hangen smalle bladpunten.
static func _palm() -> Image:
	var img := _blank(256, 128)
	var rib0 := Color(0.45, 0.5, 0.25)
	var rib1 := Color(0.75, 0.85, 0.45)
	_line(img, Vector2(0, 64), Vector2(255, 64), 4.0, rib0, rib1)
	var n := 34
	for i in n:
		var x := 6.0 + i * (240.0 / n)
		var t := x / 256.0
		var reach := 58.0 * pow(sin(minf(t * 1.15 + 0.05, 1.0) * PI), 0.55)
		for s in [-1.0, 1.0]:
			var tip := Vector2(x + 26.0 - t * 12.0, 64.0 + s * reach)
			var c0 := Color(0.28, 0.45, 0.14).lerp(Color(0.5, 0.7, 0.25), t)
			var c1 := Color(0.55, 0.78, 0.3).lerp(Color(0.8, 0.95, 0.5), t)
			_line(img, Vector2(x, 64), tip, 4.2, c0, c1)
	return img


## 128 x 128: breed blad met spitse punt en nerven.
static func _leaf() -> Image:
	var img := _blank(128, 128)
	for y in 128:
		for x in 128:
			var u := x / 127.0
			var v := (y - 63.5) / 63.5
			var w := sin(pow(u, 0.7) * PI) * (1.0 - 0.25 * u)  # breedte langs het blad
			if absf(v) < w * 0.98 and u > 0.02:
				var vein := absf(sin((u * 9.0 - absf(v) * 3.0) * PI)) < 0.07 or absf(v) < 0.025
				var shade := 0.72 + 0.28 * u + (0.12 if vein else 0.0) - 0.15 * absf(v)
				img.set_pixel(x, y, Color(0.22 * shade + 0.12, 0.5 * shade + 0.1, 0.16 * shade, 1.0))
	return img


## 128 x 128: varen met veel kleine blaadjes.
static func _fern() -> Image:
	var img := _blank(128, 128)
	_line(img, Vector2(0, 64), Vector2(127, 64), 2.6, Color(0.3, 0.45, 0.15), Color(0.55, 0.75, 0.3))
	for i in 22:
		var x := 4.0 + i * 5.4
		var reach := 54.0 * (1.0 - pow(x / 128.0, 2.2)) + 4.0
		for s in [-1.0, 1.0]:
			_line(img, Vector2(x, 64), Vector2(x + 9.0, 64 + s * reach), 3.0, Color(0.2, 0.42, 0.12), Color(0.5, 0.75, 0.25))
	return img


## 64 x 128: een pol grassprieten, onderaan donker en bovenaan licht.
static func _grass() -> Image:
	var img := _blank(64, 128)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 11:
		var x := 6.0 + i * 5.0 + rng.randf_range(-2.0, 2.0)
		var top := Vector2(x + rng.randf_range(-14.0, 14.0), rng.randf_range(6.0, 50.0))
		_line(img, Vector2(x, 127), top, 3.6, Color(0.14, 0.3, 0.08), Color(0.6, 0.82, 0.3))
	return img
