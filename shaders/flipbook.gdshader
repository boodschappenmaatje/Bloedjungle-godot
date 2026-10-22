shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled;
// Beeldreeks (flipbook) uit Blender: een vel met cols x rows beeldjes, links boven eerst.
// Speelt zichzelf af vanaf start (TIME), zacht tussen twee beeldjes in, en kijkt altijd naar de camera.

uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform int cols = 6;
uniform int rows = 6;
uniform int frames = 36;
uniform float start = 0.0;
uniform float duration = 1.8;
uniform float fade_in = 0.03;
uniform float fade_out = 0.25;  // aandeel van de duur waarin hij uitdooft
uniform float bright = 1.0;
uniform bool ground = false;  // plat op de grond in plaats van naar de camera gedraaid (schokgolfring)

varying float age;

void vertex() {
	age = (TIME - start) / duration;
	if (!ground) {
		// kijkt naar de camera, behoudt de schaal van het object
		mat4 m = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		m[0] *= length(MODEL_MATRIX[0].xyz);
		m[1] *= length(MODEL_MATRIX[1].xyz);
		m[2] *= length(MODEL_MATRIX[2].xyz);
		MODELVIEW_MATRIX = m;
	}
}

vec4 cell(int f, vec2 uv) {
	int cx = f % cols;
	int cy = f / cols;
	vec2 p = (vec2(float(cx), float(cy)) + uv) / vec2(float(cols), float(rows));
	return texture(sheet, p);
}

void fragment() {
	float a = clamp(age, 0.0, 1.0);
	float x = a * float(frames - 1);
	int f0 = int(floor(x));
	int f1 = min(f0 + 1, frames - 1);
	vec4 c = mix(cell(f0, UV), cell(f1, UV), fract(x));
	float env = smoothstep(0.0, fade_in, age) * (1.0 - smoothstep(1.0 - fade_out, 1.0, age));
	// Het vel is met rechte alpha opgeslagen: voor premultiplied blending eerst vermenigvuldigen
	ALBEDO = c.rgb * c.a * bright * env;
	ALPHA = c.a * env;
}
