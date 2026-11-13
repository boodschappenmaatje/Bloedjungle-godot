shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Tankschot: 4x4 vuur-flipbook (bron/tankfx/maak_flipbooks.py). Het vel is al met de dekking vermenigvuldigd, dus transparant = zwart en optellen klopt.
// De loopmond zit onderin elk beeld en het vuur schiet omhoog.
uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform float frame_index : hint_range(0.0, 15.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 4.0) = 1.6;
uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.7);

void fragment() {
	float f = floor(clamp(frame_index, 0.0, 15.0));
	vec2 cell = vec2(mod(f, 4.0), floor(f / 4.0));
	vec2 uv = (clamp(UV, vec2(0.002), vec2(0.998)) + cell) / 4.0;
	vec4 c = texture(sheet, uv);
	// ALPHA = helderheid: waar het vel zwart is telt ook de mist van de omgeving niet mee (anders staat er een bleek vierkant)
	float m = max(c.r, max(c.g, c.b));
	ALBEDO = c.rgb / max(m, 0.02) * tint * intensity;
	ALPHA = clamp(m, 0.0, 1.0);
}
