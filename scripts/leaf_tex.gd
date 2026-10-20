class_name LeafTex
## Bladtexturen (kleur met doorzichtige randen + normal map), getekend door tools/gen_foliage.py en
## opgeslagen in assets/textures/foliage/. foliage.gdshader knipt alles weg wat doorzichtig is.

static var _cache := {}


static func get_tex(kind: String) -> Texture2D:
	return _load(kind, "color")


static func get_normal(kind: String) -> Texture2D:
	return _load(kind, "normal")


static func _load(kind: String, part: String) -> Texture2D:
	var key := kind + part
	if not _cache.has(key):
		_cache[key] = load("res://assets/textures/foliage/%s_%s.png" % [kind, part])
	return _cache[key]
