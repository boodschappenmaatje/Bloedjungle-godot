shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Brandende napalmstrook: vanaf elke inslag rolt een vuurgolf uit langs de lengte van de strook (x), tot alles één brandend veld is.
// imp_s = positie van elke inslag langs de strook in meters, imp_t = seconden sinds die inslag (< 0: nog niet gevallen).

uniform vec4 imp_s = vec4(-10.0, -3.3, 3.3, 10.0);
uniform vec4 imp_t = vec4(-1.0);
uniform float wave_speed = 7.0;
uniform float max_reach = 5.0;
uniform float half_width = 2.5;
uniform float fade = 1.0;

varying vec2 local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	local = VERTEX.xz;
}

void fragment() {
	float cov = 0.0;
	for (int i = 0; i < 4; i++) {
		float t = imp_t[i];
		if (t >= 0.0) {
			float r = min(t * wave_speed, max_reach);
			cov = max(cov, 1.0 - smoothstep(r - 1.6, r, abs(local.x - imp_s[i])));
		}
	}
	float n1 = vnoise(vec2(local.x * 1.1, local.y * 1.1 - TIME * 2.2));
	float n2 = vnoise(vec2(local.x * 2.6 + 7.0, local.y * 2.6 - TIME * 4.0));
	float f = n1 * 0.65 + n2 * 0.35;
	float across = abs(local.y) / half_width;
	float edge = 1.0 - smoothstep(0.55, 1.0, across + (f - 0.5) * 0.5);
	float inten = cov * edge * (0.25 + 0.75 * f);
	vec3 col = mix(vec3(0.55, 0.08, 0.01), vec3(0.95, 0.5, 0.08), clamp(f * f * 1.8, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(inten * 1.1, 0.0, 0.85) * fade;
}
