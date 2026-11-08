class_name Upscaling
## Slimme upscaling (keuzekaart 8 nov 2026: 1A 2A 3A 4B 5B). De 3D-wereld wordt op minder pixels getekend en Apple's
## MetalFX Spatial maakt het beeld weer scherp; de HUD blijft altijd op volle resolutie.
## - Alleen MetalFX Spatial: in de Mobile-renderer vallen FSR 1/2 en MetalFX Temporal in Godot 4.7.2 terug op bilineair
##   (servers/rendering/renderer_viewport.cpp), dus die gebruiken we niet.
## - Per stand een band waarbinnen PerfGovernor de resolutie op en neer mag zetten (keuze 3A).
## - Geen MetalFX (Windows/Vulkan, editor zonder Metal, headless): de stand doet niets en alles werkt zoals vóór v193.

const STANDS := {
	"quality": {"scale": 0.77, "min": 0.67, "max": 0.85, "tag": "K"},
	"balanced": {"scale": 0.67, "min": 0.58, "max": 0.77, "tag": "G"},
	"performance": {"scale": 0.59, "min": 0.50, "max": 0.67, "tag": "P"},
}

## -1 = nog niet bekeken. Tests kunnen force_support op 1 of 0 zetten.
static var _support := -1
static var force_support := -1


static func metalfx_supported() -> bool:
	if force_support >= 0:
		return force_support == 1
	if _support < 0:
		var rd := RenderingServer.get_rendering_device()
		_support = 1 if rd != null and rd.has_feature(RenderingDevice.SUPPORTS_METALFX_SPATIAL) else 0
	return _support == 1


## Staat upscaling nu echt aan (gekozen stand en een toestel met MetalFX)?
static func active() -> bool:
	return STANDS.has(GameSettings.get_value("upscaling")) and metalfx_supported()


## De grafiekstand die echt gebruikt wordt: met upscaling aan krijgt de iPhone de Ultra-effecten (keuze 4B),
## omdat de lagere tekenresolutie daar de tijd voor vrijmaakt. De regelaar en de kwaliteitstrap bewaken de fps.
static func effective_quality() -> String:
	return "ultra" if active() else GameSettings.get_value("quality")


## Begin-, laagste en hoogste resolutie voor de resolutieregelaar.
## Upscaling uit: zoals vroeger, van 50% tot de schaal van de grafiekstand.
static func band() -> Dictionary:
	if active():
		var s: Dictionary = STANDS[GameSettings.get_value("upscaling")]
		return {"start": s.scale, "min": s.min, "max": s.max}
	var table: Dictionary = (load("res://scripts/atmosphere.gd") as GDScript).get("QUALITY")
	var cap: float = table[GameSettings.get_value("quality")].scale
	return {"start": cap, "min": PerfGovernor.MIN_SCALE, "max": cap}


static func apply_mode(vp: Viewport) -> void:
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL if active() else Viewport.SCALING_3D_MODE_BILINEAR


## Korte aanduiding voor de fps-teller, bijvoorbeeld " · MFX K".
static func overlay_tag() -> String:
	return (" · MFX %s" % STANDS[GameSettings.get_value("upscaling")].tag) if active() else ""


static func note() -> String:
	var u := GameSettings.get_value("upscaling")
	if not metalfx_supported():
		return "Upscaling: dit toestel heeft geen MetalFX (alleen iPhone/iPad/Mac), dus de stand doet hier niets."
	if u == "off":
		return "Upscaling uit: de 3D-wereld op de resolutie van de grafiekstand, gewoon vergroot."
	var s: Dictionary = STANDS[u]
	return "Upscaling (MetalFX): tekent op %d%% en maakt het scherp; zakt bij drukte tot %d%%, in rust tot %d%%." % [roundi(s.scale * 100.0), roundi(s.min * 100.0), roundi(s.max * 100.0)]
