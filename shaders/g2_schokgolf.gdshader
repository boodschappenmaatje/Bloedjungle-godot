shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Graphics 2.0: schokgolf over de grond bij een explosie: een ring van stof die snel uitdijt en vervaagt.

uniform float t = 0.0;  // 0 = begin, 1 = volle grootte en weg

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float r = mix(0.12, 0.96, t);
	float ring = smoothstep(r - 0.2, r - 0.03, d) * (1.0 - smoothstep(r - 0.03, r + 0.04, d));
	float inner = (1.0 - smoothstep(0.0, r, d)) * 0.1;
	ALBEDO = mix(vec3(1.0, 0.9, 0.7), vec3(0.62, 0.56, 0.46), smoothstep(0.0, 0.5, t));
	ALPHA = (ring * 0.5 + inner) * (1.0 - t) * (1.0 - t);
}
