shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Tankschot: 4x4 flipbook voor rook, stof en de aardfontein (bron/tankfx/maak_flipbooks.py), gewone dekking.
// billboard = true: het vlak draait naar de camera en staat met zijn onderkant op de grond (aardfontein).
uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform float frame_index : hint_range(0.0, 15.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform float strength : hint_range(0.0, 1.5) = 1.0;
uniform bool billboard = false;

void vertex() {
	if (billboard) {
		mat4 m = mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * m;
	}
}

void fragment() {
	float f = floor(clamp(frame_index, 0.0, 15.0));
	vec2 cell = vec2(mod(f, 4.0), floor(f / 4.0));
	vec2 uv = (clamp(UV, vec2(0.002), vec2(0.998)) + cell) / 4.0;
	vec4 c = texture(sheet, uv);
	ALBEDO = c.rgb * tint;
	ALPHA = clamp(c.a * strength, 0.0, 1.0);
}
