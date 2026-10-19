shader_type spatial;
render_mode specular_disabled;
// Jungle-bodem: twee soorten gras, modder-plekken, vaste aarde in de basis en een pad
// vanaf elke poort. Alles uit ruis, dus de grond herhaalt zich niet.

uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
uniform float compound = 14.0;
uniform float gate_gap = 2.4;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n1 = texture(noise_a, p * 0.025).r;
	float n2 = texture(noise_b, p * 0.09).r;
	float n3 = texture(noise_b, p * 0.55).r;
	float n4 = texture(noise_a, p * 1.7).r;

	vec3 grass_dark = vec3(0.07, 0.17, 0.045);
	vec3 grass_light = vec3(0.24, 0.38, 0.10);
	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.3, 0.7, n1 * 0.6 + n2 * 0.4));
	grass *= 0.8 + 0.4 * n3;
	grass = mix(grass, grass * vec3(1.3, 1.2, 0.7), smoothstep(0.6, 0.8, n2) * 0.5);

	vec3 dirt = mix(vec3(0.21, 0.135, 0.075), vec3(0.38, 0.27, 0.15), n2);
	dirt *= 0.8 + 0.35 * n3 + 0.15 * n4;

	float box = max(abs(p.x), abs(p.y));
	float inside = 1.0 - smoothstep(compound - 0.5, compound + 3.0, box);
	float path = (1.0 - smoothstep(gate_gap * 0.9, gate_gap * 1.9 + n2 * 1.6, abs(p.x)))
		* smoothstep(compound - 2.0, compound + 1.5, abs(p.y))
		* (1.0 - smoothstep(30.0, 52.0, abs(p.y)));
	float patches = smoothstep(0.66, 0.8, n1 + 0.2 * n2);
	float dm = clamp(max(max(inside, path), patches * 0.8), 0.0, 1.0);
	dm = smoothstep(0.35, 0.65, dm + (n3 - 0.5) * 0.4);

	ALBEDO = pow(mix(grass, dirt, dm), vec3(2.2));  // kleuren hierboven zijn sRGB gekozen
	ROUGHNESS = mix(0.95, 1.0, dm);
}
