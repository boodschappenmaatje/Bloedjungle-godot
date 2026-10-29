shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Napalmrook uit een echte rooksimulatie (Blender Mantaflow, bron/napalm/maak_vlam.py --rook): een beeldreeks van COLS x ROWS beelden
// die eenmalig afspeelt vanaf het moment van starten (instance-parameter age loopt op) en aan het eind uitdooft.

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int cols = 8;
uniform int rows = 8;
uniform float fps = 9.0;
uniform float dark = 0.9;
instance uniform float age = 0.0;      // s sinds de start; door het script bijgehouden
instance uniform float fade_after = 100.0;   // s na de start waarop de rook wegtrekt
instance uniform float fade_len = 3.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

vec4 frame_at(float f, vec2 uv) {
	float n = float(cols * rows);
	f = clamp(f, 0.0, n - 1.0);
	float row = floor(f / float(cols));
	float col = f - row * float(cols);
	vec2 cell = (vec2(col, row) + clamp(uv, vec2(0.002), vec2(0.998))) / vec2(float(cols), float(rows));
	return textureLod(atlas, cell, 0.0);
}

void fragment() {
	float f = age * fps;
	vec4 a = frame_at(floor(f), UV);
	vec4 b = frame_at(floor(f) + 1.0, UV);
	vec4 c = mix(a, b, fract(f));
	ALBEDO = c.rgb * dark;
	float out_fade = 1.0 - smoothstep(fade_after, fade_after + fade_len, age);
	float foot = 1.0 - smoothstep(0.80, 0.93, UV.y);
	ALPHA = clamp(c.a * 1.25, 0.0, 1.0) * out_fade * foot;
}
