shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, fog_disabled;
// Beeldreeks (flipbook) uit Blender: een vel met cols x rows beeldjes, links boven eerst.
// Speelt af via `progress`, zacht tussen twee beeldjes in, en kijkt altijd naar de camera.

uniform sampler2D sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform int cols = 6;
uniform int rows = 6;
uniform int frames = 36;
uniform float progress : hint_range(0.0, 1.0) = 0.0;  // 0 = eerste beeldje, 1 = laatste; Fx.explosion tweent dit
uniform float fade_in = 0.03;
uniform float fade_out = 0.25;  // aandeel van de duur waarin hij uitdooft
uniform float bright = 1.0;
uniform bool flip_x = false;  // gespiegeld: dezelfde reeks ziet er dan anders uit
uniform bool looping = false;  // herhalende reeks (vlam): wraparound en geen in- of uitfaden
uniform bool ground = false;  // plat op de grond in plaats van naar de camera gedraaid (schokgolfring)

void vertex() {
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
	float a = clamp(progress, 0.0, 1.0);
	float x = looping ? fract(progress) * float(frames) : a * float(frames - 1);
	int f0 = min(int(floor(x)), frames - 1);
	int f1 = looping ? (f0 + 1) % frames : min(f0 + 1, frames - 1);
	vec2 uv = flip_x ? vec2(1.0 - UV.x, UV.y) : UV;
	vec4 c = mix(cell(f0, uv), cell(f1, uv), fract(x));
	float env = looping ? 1.0 : smoothstep(0.0, fade_in, progress) * (1.0 - smoothstep(1.0 - fade_out, 1.0, progress));
	// Het vel is met rechte alpha opgeslagen: voor premultiplied blending eerst vermenigvuldigen
	// de donkere stofring onderin (afgesneden door de grond in Blender) zacht laten uitlopen: geen harde rand
	float low = smoothstep(0.7, 0.95, uv.y);
	float dark = 1.0 - smoothstep(0.05, 0.3, dot(c.rgb, vec3(0.33)));
	c.a *= 1.0 - low * (0.85 * dark + 0.35);
	// ook links en rechts zacht uitlopen: de stofring loopt door tot de rand van het beeld en zou daar een rechte lijn geven
	c.a *= smoothstep(0.0, 0.08, uv.x) * (1.0 - smoothstep(0.92, 1.0, uv.x));
	ALBEDO = c.rgb * c.a * bright * env;
	ALPHA = c.a * env;
}
