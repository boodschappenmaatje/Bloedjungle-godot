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
uniform vec4 pits[8];  // loopgraven: x, z, cos, sin
uniform int pit_n = 0;
uniform vec4 pad = vec4(0.0, 0.0, 1.0, 0.0);  // schacht van het helikopterplatform: x, z, cos, sin
uniform float pad_half = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	// de rivier is uit de grond gesneden (scripts/river.gd legt de bedding eronder; zelfde formule als Data.river_z)
	float river_off = abs(p.y - (-92.0 + 5.0 * sin(p.x * 0.06) + 2.0 * sin(p.x * 0.15 + 1.0)));
	if (river_off < 2.6) {
		discard;
	}
	for (int i = 0; i < pit_n; i++) {
		vec2 r = p - pits[i].xy;
		float lx = r.x * pits[i].z - r.y * pits[i].w;
		float lz = r.x * pits[i].w + r.y * pits[i].z;
		if (abs(lx) < 2.36 && abs(lz) < 0.66) {
			discard;
		}
	}
	if (pad_half > 0.0) {
		vec2 q = p - pad.xy;
		float qx = q.x * pad.z - q.y * pad.w;
		float qz = q.x * pad.w + q.y * pad.z;
		if (abs(qx) < pad_half && abs(qz) < pad_half) {
			discard;
		}
	}
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
	vec3 dirt = mix(d1, d2, 0.5 * smoothstep(0.3, 0.7, n2));
	dirt *= (0.85 + 0.2 * n3) * vec3(0.52, 0.5, 0.47);

	float box = max(abs(p.x), abs(p.y));
	float inside = 1.0 - smoothstep(compound - 0.5, compound + 3.0, box);
	float path = (1.0 - smoothstep(gate_gap * 0.9, gate_gap * 1.9 + n2 * 1.6, abs(p.x)))
		* smoothstep(compound - 2.0, compound + 1.5, abs(p.y))
		* (1.0 - smoothstep(30.0, 52.0, abs(p.y)));
	float patches = smoothstep(0.66, 0.8, n1 + 0.2 * n2);
	float dm = clamp(max(max(inside, path), patches * 0.8), 0.0, 1.0);
	dm = max(dm, 1.0 - smoothstep(2.9, 5.0 + n2 * 1.6, river_off));  // modderige oevers
	// moeras: in het bos ten westen van x = -22, natte donkere bodem
	float swamp = (1.0 - smoothstep(-38.0, -22.0, p.x + n2 * 6.0)) * (1.0 - smoothstep(-70.0, -40.0, p.y)) * smoothstep(-84.0, -70.0, p.y);
	swamp *= 1.0 - smoothstep(0.0, 2.0, river_off - 3.0);
	// kronkelpad van de noordpoort door het bos naar de brug (zelfde formule als Data.path_x)
	float pt = clamp((-30.0 - p.y) / 60.2, 0.0, 1.0);
	float ptx = 12.0 * sin(pt * 9.6) * sin(pt * 3.14159265);
	float trail = (1.0 - smoothstep(1.4, 3.0 + n2 * 1.4, abs(p.x - ptx))) * step(0.001, pt) * step(pt, 0.999);
	dm = max(dm, max(swamp * 0.9, trail * 0.9));
	dm = smoothstep(0.2, 0.8, dm + (n3 - 0.5) * 0.3 + (hgt - 0.5) * 0.5);  // zachte rand, kiezels steken door het gras

	dirt *= 1.0 - 0.45 * swamp;
	// meer variatie in het gras: droge gele plekken, diepgroene weelderige plekken, bladstrooisel en wat wilde bloempjes
	float big = texture(noise_a, p * 0.011 + 0.31).r;
	float lush = smoothstep(0.55, 0.8, big);
	float dry = smoothstep(0.55, 0.78, 1.0 - big) * (1.0 - lush);
	grass = mix(grass, grass * vec3(0.75, 0.95, 0.65), lush * 0.6);
	grass = mix(grass, grass * vec3(1.55, 1.3, 0.7) + vec3(0.03, 0.025, 0.0), dry * 0.6);
	float litter = smoothstep(0.62, 0.75, texture(noise_b, p * 0.33 + 0.7).r) * smoothstep(0.35, 0.6, n4);
	grass = mix(grass, vec3(0.2, 0.12, 0.05) * (0.8 + 0.6 * n3), litter * 0.55);
	vec2 cell = floor(p * 3.2);
	float fr = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	vec2 fc = fract(p * 3.2) - vec2(0.5 + 0.3 * (fr - 0.5), 0.5 + 0.3 * (fract(fr * 7.0) - 0.5));
	float bloom = step(0.965, fr) * (1.0 - smoothstep(0.03, 0.07, length(fc))) * (1.0 - dm) * step(0.45, lush + dry);
	vec3 petal = mix(vec3(0.85, 0.8, 0.25), mix(vec3(0.85, 0.85, 0.8), vec3(0.8, 0.25, 0.2), step(0.5, fract(fr * 13.0))), step(0.33, fract(fr * 5.0)));
	grass = mix(grass, petal, bloom * 0.9);
	// mos op de overgang van gras naar aarde, natte donkere modder in de lage stukken
	float edge = clamp(4.0 * dm * (1.0 - dm), 0.0, 1.0);
	dirt = mix(dirt, vec3(0.14, 0.2, 0.08) * (0.8 + 0.5 * n3), edge * 0.5);
	dirt *= 1.0 - 0.25 * smoothstep(0.5, 0.2, n2) * dm;
	ALBEDO = mix(grass, dirt, dm);  // texturen zijn al lineair ingelezen (source_color)
	ROUGHNESS = 1.0;
	NORMAL_MAP = texture(dirt_normal, pp * 0.11).rgb;
	NORMAL_MAP_DEPTH = dm * 1.1;
}
