shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Graphics 2.0: laaghangende nevel tussen de bomen. Eén vlak dat met de camera meeschuift; de ruis zit vast aan de wereld,
// dus de slierten blijven liggen en drijven alleen langzaam met de wind. Twee textuurmonsters per pixel.

uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.72, 0.78, 0.7);
uniform float strength = 0.3;
uniform vec4 clear_zone = vec4(0.0, 0.0, 26.0, 26.0);  // midden x,z en halve maat: daar (de basis) hangt geen nevel
uniform float half_size = 80.0;

varying vec3 wpos;
varying vec2 local;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX.xz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = texture(noise, p * 0.011 + TIME * vec2(0.0035, 0.0015)).r;
	float n2 = texture(noise, p * 0.037 - TIME * vec2(0.006, 0.001) + 0.4).r;
	float a = smoothstep(0.5, 0.82, n1 * 0.65 + n2 * 0.35);
	vec2 q = abs(p - clear_zone.xy) - clear_zone.zw;
	a *= smoothstep(0.0, 14.0, max(q.x, q.y));
	// rand van het vlak zacht laten uitlopen
	a *= 1.0 - smoothstep(half_size * 0.7, half_size, max(abs(local.x), abs(local.y)));
	ALBEDO = tint;
	ALPHA = a * strength;
}
