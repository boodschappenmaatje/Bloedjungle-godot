shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Brandende plas: een onregelmatige vlek vloeibaar vuur die na de inslag uitdijt, met gloed die naar de rand toe uitdooft.

uniform float t = 0.0;        // s sinds de ontsteking
uniform float fade = 1.0;     // 1 = brandt, 0 = uit
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 9.0;   // meters vanaf het midden
	float ang = atan(p.y, p.x);
	float r = length(p);
	float reach = min(t * 3.0, 3.6) * (0.8 + 0.4 * vnoise(vec2(ang * 1.7 + seed, seed)));   // golvende rand
	float edge = 1.0 - smoothstep(reach - 1.4, reach, r);
	float n = vnoise(p * 1.6 + vec2(0.0, -TIME * 1.5)) * 0.6 + vnoise(p * 3.7 + vec2(seed, TIME * 2.4)) * 0.4;
	float inten = edge * (0.35 + 0.65 * n) * fade;
	vec3 col = mix(vec3(0.5, 0.07, 0.01), vec3(1.0, 0.5, 0.1), n);
	inten = clamp(inten, 0.0, 1.0);
	ALBEDO = col;
	ALPHA = inten * 0.75;
}
