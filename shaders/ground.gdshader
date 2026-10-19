shader_type spatial;
render_mode specular_disabled;
// Junglebodem: meerdere schalen van gras, vochtige aarde en zand. De poortwegen hebben
// rafelige randen en lichte wielsporen, maar blijven op gameplay-veilige afstand van de muur.

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
	float n5 = texture(noise_b, p * 3.8).r;

	vec3 grass_dark = vec3(0.035, 0.085, 0.032);
	vec3 grass_mid = vec3(0.105, 0.17, 0.075);
	vec3 grass_light = vec3(0.19, 0.25, 0.105);
	float grass_mix = smoothstep(0.28, 0.74, n1 * 0.62 + n2 * 0.38);
	vec3 grass = mix(grass_dark, grass_mid, grass_mix);
	grass = mix(grass, grass_light, smoothstep(0.68, 0.91, n2) * 0.52);
	grass *= 0.78 + 0.32 * n3;
	grass = mix(grass, grass * vec3(1.14, 1.08, 0.83), smoothstep(0.69, 0.9, n4) * 0.27);

	vec3 soil = mix(vec3(0.105, 0.075, 0.048), vec3(0.19, 0.125, 0.075), n2);
	soil *= 0.78 + 0.34 * n3 + 0.16 * n4;
	vec3 sand = mix(vec3(0.31, 0.235, 0.135), vec3(0.47, 0.355, 0.22), n3 * 0.7 + n4 * 0.3);
	vec3 dirt = mix(soil, sand, smoothstep(0.34, 0.8, n2) * 0.68);
	// Tiny granular value changes keep dirt legible without a costly normal map.
	dirt *= 0.91 + 0.18 * n5;

	float box_edge = max(abs(p.x), abs(p.y));
	float inside = 1.0 - smoothstep(compound - 0.25, compound + 2.8 + (n3 - 0.5) * 1.6, box_edge);
	float road_width = gate_gap * 1.6 + n2 * 1.4 + (n4 - 0.5) * 0.9;
	float road_mask = (1.0 - smoothstep(road_width, road_width + 1.9, abs(p.x)))
		* smoothstep(compound - 1.8, compound + 1.8, abs(p.y))
		* (1.0 - smoothstep(34.0, 55.0, abs(p.y)));
	// A worn turnaround/apron just outside both gates blends into the road shoulders.
	float apron = (1.0 - smoothstep(0.0, 2.2, abs(p.x)))
		* (1.0 - smoothstep(0.0, 4.0, abs(abs(p.y) - (compound + 2.0))));
	float patches = smoothstep(0.68, 0.84, n1 * 0.75 + n2 * 0.25);
	float dm = clamp(max(max(inside, road_mask), max(apron * 0.66, patches * 0.48)), 0.0, 1.0);
	dm = smoothstep(0.28, 0.72, dm + (n3 - 0.5) * 0.32);

	// Two shallow wheel-worn tracks run along the road without becoming hard stripes.
	float track_a = 1.0 - smoothstep(0.22, 0.72, abs(abs(p.x) - 1.45 + (n3 - 0.5) * 0.22));
	float tracks = track_a * road_mask * 0.18;
	dirt = mix(dirt, soil * 0.88, tracks);
	grass = mix(grass, mix(sand, soil, 0.45), tracks * 0.42);

	ALBEDO = pow(mix(grass, dirt, dm), vec3(2.2));  // kleuren hierboven zijn sRGB gekozen
	ROUGHNESS = mix(0.91 + n5 * 0.06, 0.97 + n5 * 0.03, dm);
}
