shader_type spatial;
render_mode specular_disabled;
// Jungle-bodem: twee soorten gras, modder-plekken, vaste aarde in de basis en een pad
// vanaf elke poort. Alles uit ruis, dus de grond herhaalt zich niet.

uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D jungle_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D mud_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt_height : repeat_enable, filter_linear_mipmap;
uniform sampler2D dirt_normal : hint_normal, repeat_enable, filter_linear_mipmap;
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

	// foto-texturen, op twee maten door elkaar zodat je de herhaling niet ziet
	vec3 g1 = texture(grass_tex, p * 0.30).rgb;
	vec3 g2 = texture(jungle_tex, p * 0.21 + 0.37).rgb;
	vec3 g3 = texture(grass_tex, p * 0.071 + 0.11).rgb;
	vec3 grass = mix(g1, g2, smoothstep(0.35, 0.65, n1 * 0.6 + n2 * 0.4));
	grass = grass * (0.65 + 0.7 * g3.g) * (0.75 + 0.5 * n3);
	grass *= vec3(0.4, 0.48, 0.32);  // donkerder en minder fel, past bij de jungle

	// diepte in de aarde: de kijkhoek verschuift het beeld per hoogte, zodat kiezels boven de modder uitsteken
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float hgt = texture(dirt_height, p * 0.11).r;
	vec2 pp = p + vw.xz / max(vw.y, 0.25) * (hgt - 0.5) * 0.16;
	vec3 d1 = texture(dirt_tex, pp * 0.11).rgb;
	vec3 d2 = texture(mud_tex, pp * 0.09 + 0.5).rgb;
	vec3 dirt = mix(d1, d2, smoothstep(0.3, 0.7, n2));
	dirt *= (0.85 + 0.2 * n3) * vec3(0.58, 0.54, 0.5);

	float box = max(abs(p.x), abs(p.y));
	float inside = 1.0 - smoothstep(compound - 0.5, compound + 3.0, box);
	float path = (1.0 - smoothstep(gate_gap * 0.9, gate_gap * 1.9 + n2 * 1.6, abs(p.x)))
		* smoothstep(compound - 2.0, compound + 1.5, abs(p.y))
		* (1.0 - smoothstep(30.0, 52.0, abs(p.y)));
	float patches = smoothstep(0.66, 0.8, n1 + 0.2 * n2);
	float dm = clamp(max(max(inside, path), patches * 0.8), 0.0, 1.0);
	dm = smoothstep(0.2, 0.8, dm + (n3 - 0.5) * 0.3 + (hgt - 0.5) * 0.5);  // zachte rand, kiezels steken door het gras

	ALBEDO = mix(grass, dirt, dm);  // texturen zijn al lineair ingelezen (source_color)
	ROUGHNESS = 1.0;
	NORMAL_MAP = texture(dirt_normal, pp * 0.11).rgb;
	NORMAL_MAP_DEPTH = dm * 1.1;
}
