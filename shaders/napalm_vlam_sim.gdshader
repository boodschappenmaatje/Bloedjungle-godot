shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Napalmvlam uit een echte vuursimulatie (Blender Mantaflow): een beeldreeks van COLS x ROWS beelden (bron/napalm/maak_vlam.py).
// Het vlak draait om de verticale as mee met de camera, de voet blijft op de grond. Elke vlam start op een eigen moment in de reeks.

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int cols = 8;
uniform int rows = 8;
uniform float fps = 20.0;
uniform float boost = 1.35;
instance uniform float grow : hint_range(0.0, 1.0) = 1.0;
instance uniform float seed = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.y *= grow;
	VERTEX.x *= 0.55 + 0.45 * grow;
}

vec4 frame_at(float f, vec2 uv) {
	float n = float(cols * rows);
	f = mod(f, n);
	float row = floor(f / float(cols));
	float col = f - row * float(cols);
	vec2 cell = (vec2(col, row) + clamp(uv, vec2(0.002), vec2(0.998))) / vec2(float(cols), float(rows));
	return textureLod(atlas, cell, 0.0);
}

void fragment() {
	float f = TIME * fps + seed * 13.0;
	vec4 a = frame_at(floor(f), UV);
	vec4 b = frame_at(floor(f) + 1.0, UV);
	vec4 c = mix(a, b, fract(f));      // ineenvloeien tussen opeenvolgende beelden
	ALBEDO = c.rgb * boost;
	float foot = 1.0 - smoothstep(0.74, 0.88, UV.y);   // de onderrand van de simulatie zacht laten uitlopen, geen harde streep
	ALPHA = clamp(c.a * 1.1, 0.0, 1.0) * foot;
}
