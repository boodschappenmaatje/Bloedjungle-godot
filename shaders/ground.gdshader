shader_type spatial;
// Beperkte specularrespons wordt per fragment gemaskeerd tot de aardelaag.
// Jungle-bodem: twee soorten gras, modder-plekken, vaste aarde in de basis en een pad
// vanaf elke poort. Alles uit ruis, dus de grond herhaalt zich niet.

uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D jungle_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D mud_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_height : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
// A half mip of prefiltering also covers albedo detail; fading normals alone
// leaves the high-contrast pebbles shimmering at reduced mobile resolutions.
uniform float detail_mip_bias : hint_range(0.0, 2.0) = 0.5;
uniform vec4 pits[8];  // loopgraven: x, z, cos, sin
uniform int pit_n = 0;
uniform vec4 pad = vec4(0.0, 0.0, 1.0, 0.0);  // schacht van het helikopterplatform: x, z, cos, sin
uniform float pad_half = 0.0;
// wereld per start (W2): rivier-kronkel per sessie, door level.gd gezet vanuit Data._river_* (Data.river_z() zelfde formule)
uniform float g2_gold = 0.0;  // Graphics 2.0 gouden ochtend: helderder, warmer gras
uniform vec3 g2_sky : source_color = vec3(0.9, 0.82, 0.6);  // kleur die de plassen weerspiegelen
uniform float g2_wet = 0.0;  // Graphics 2.0: natte glans op modder, oevers en moeras
uniform float river_amp1 = 5.0;
uniform float river_freq1 = 0.06;
uniform float river_phase1 = 0.0;
uniform float river_amp2 = 2.0;
uniform float river_freq2 = 0.15;
uniform float river_phase2 = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	// Pixelafdruk in wereldmeters: fijne bodemruis mag niet wisselen bij camerabeweging.
	// Afhankelijk van de native iOS-renderresolutie loopt microdetail automatisch terug.
	float pixel_span = max(length(dFdx(p)), length(dFdy(p)));
	float micro_detail = 1.0 - smoothstep(0.012, 0.075, pixel_span);
	// de rivier is uit de grond gesneden (scripts/river.gd legt de bedding eronder; zelfde formule als Data.river_z)
	float river_off = abs(p.y - (-92.0 + river_amp1 * sin(p.x * river_freq1 + river_phase1) + river_amp2 * sin(p.x * river_freq2 + river_phase2)));
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
	float n3 = mix(0.5, texture(noise_b, p * 0.55).r, micro_detail);
	float n4 = mix(0.5, texture(noise_a, p * 1.7).r, micro_detail);

	// foto-texturen, op twee maten door elkaar zodat je de herhaling niet ziet
	vec3 g1 = texture(grass_tex, p * 0.23, detail_mip_bias).rgb;
	vec3 g2 = texture(jungle_tex, p * 0.18 + 0.37, detail_mip_bias).rgb;
	vec3 g3 = texture(grass_tex, p * 0.058 + 0.11, detail_mip_bias).rgb;
	vec3 grass = mix(g1, g2, smoothstep(0.28, 0.72, n1 * 0.6 + n2 * 0.4));
	grass = grass * (0.77 + 0.46 * g3.g) * (0.84 + 0.32 * n3);
	grass *= vec3(0.43, 0.47, 0.36);  // rustiger contrast en minder verzadigd groen
	// Graphics 2.0: structuur in het gras. Fijne sprietjes dichtbij en donkere en lichte pollen op armlengte.
	float blades = texture(grass_tex, p * 0.71 + 0.23, detail_mip_bias).g;
	float clumps = texture(noise_b, p * 0.21 + 0.4).r;
	grass *= mix(1.0, (0.62 + 0.95 * blades) * (0.74 + 0.55 * clumps), g2_gold * mix(0.45, 1.0, micro_detail));

	// Houd de grondtexturen vast aan de wereld. View-dependent parallax op dit grote vlak
	// verschoof de hoogfrequente albedo en normal map bij iedere camerabeweging en gaf shimmer.
	float roughness_sample = texture(dirt_height, p * 0.095, detail_mip_bias).r;
	float hgt = mix(0.5, roughness_sample, micro_detail);
	vec2 pp = p;
	vec3 d1 = texture(dirt_tex, pp * 0.095, detail_mip_bias).rgb;
	vec3 d2 = texture(mud_tex, pp * 0.08 + 0.5, detail_mip_bias).rgb;
	vec3 dirt = mix(d1, d2, 0.5 * smoothstep(0.3, 0.7, n2));
	dirt *= (0.85 + 0.2 * n3) * vec3(0.52, 0.5, 0.47);

	float patches = smoothstep(0.68, 0.92, n1 + 0.12 * n2);
	float dm = clamp(patches * 0.56, 0.0, 1.0);
	dm = max(dm, 1.0 - smoothstep(2.9, 5.0 + n2 * 1.6, river_off));  // modderige oevers
	// moeras: in het bos ten westen van x = -22, natte donkere bodem
	float swamp = (1.0 - smoothstep(-38.0, -22.0, p.x + n2 * 6.0)) * (1.0 - smoothstep(-70.0, -40.0, p.y)) * smoothstep(-84.0, -70.0, p.y);
	swamp *= 1.0 - smoothstep(0.0, 2.0, river_off - 3.0);
	// kronkelpad van de noordpoort door het bos naar de brug (zelfde formule als Data.path_x)
	float pt = clamp((-30.0 - p.y) / 60.2, 0.0, 1.0);
	float ptx = 12.0 * sin(pt * 9.6) * sin(pt * 3.14159265);
	float trail = (1.0 - smoothstep(mix(1.4, 0.9, g2_wet), 3.0 + n2 * 1.4 + 0.9 * g2_wet, abs(p.x - ptx))) * step(0.001, pt) * step(pt, 0.999);
	dm = max(dm, max(swamp * 0.9, trail * 0.9));
	dm = smoothstep(0.12, 0.88, dm + (n3 - 0.5) * 0.12 + (hgt - 0.5) * 0.16);  // brede rand zonder kleine bruine uitschieters

	dirt *= 1.0 - 0.45 * swamp;
	// meer variatie in het gras: droge gele plekken, diepgroene weelderige plekken, bladstrooisel en wat wilde bloempjes
	float big = texture(noise_a, p * 0.011 + 0.31).r;
	float lush = smoothstep(0.55, 0.8, big);
	float dry = smoothstep(0.55, 0.78, 1.0 - big) * (1.0 - lush);
	grass = mix(grass, grass * vec3(0.88, 1.0, 0.82), lush * 0.5);
	grass = mix(grass, grass * vec3(1.18, 1.1, 0.86) + vec3(0.012, 0.01, 0.0), dry * 0.5);
	float litter = smoothstep(0.62, 0.75, texture(noise_b, p * 0.33 + 0.7).r) * smoothstep(0.35, 0.6, n4);
	grass = mix(grass, vec3(0.2, 0.12, 0.05) * (0.8 + 0.6 * n3), litter * 0.32);
	vec2 cell = floor(p * 3.2);
	float fr = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	vec2 fc = fract(p * 3.2) - vec2(0.5 + 0.3 * (fr - 0.5), 0.5 + 0.3 * (fract(fr * 7.0) - 0.5));
	// Subpixelbloemen kunnen anders vonken bij langzaam scrollen op een 72%-3D-render.
	float bloom = step(0.965, fr) * (1.0 - smoothstep(0.03, 0.07, length(fc))) * (1.0 - dm) * step(0.45, lush + dry);
	bloom *= 1.0 - smoothstep(0.012, 0.035, pixel_span);
	vec3 petal = mix(vec3(0.85, 0.8, 0.25), mix(vec3(0.85, 0.85, 0.8), vec3(0.8, 0.25, 0.2), step(0.5, fract(fr * 13.0))), step(0.33, fract(fr * 5.0)));
	grass = mix(grass, petal, bloom * 0.9);
	// mos op de overgang van gras naar aarde, natte donkere modder in de lage stukken
	float edge = clamp(4.0 * dm * (1.0 - dm), 0.0, 1.0);
	dirt = mix(dirt, vec3(0.14, 0.2, 0.08) * (0.8 + 0.5 * n3), edge * 0.5);
	dirt *= 1.0 - 0.25 * smoothstep(0.5, 0.2, n2) * dm;
	grass *= mix(vec3(1.0), vec3(0.9, 1.26, 0.6), g2_gold);  // dieper groen; het goud komt van de zon, niet van het gras
	// Graphics 2.0: het bospad is warme roodbruine modder met losse steentjes
	vec3 stones = texture(dirt_tex, p * 0.37 + 0.19, detail_mip_bias).rgb;
	float gravel = g2_wet * smoothstep(0.3, 0.8, trail);
	dirt = mix(dirt, dirt * (0.55 + 1.5 * stones.r) * vec3(0.84, 0.86, 0.84) * 0.74, mix(0.75, 0.9, micro_detail) * gravel);
	// Graphics 2.0: twee bandensporen in het pad door het bos
	float track_d = abs(abs(p.x - ptx) - 0.62);
	float track = g2_wet * (1.0 - smoothstep(0.1, 0.3, track_d)) * smoothstep(0.55, 0.9, trail) * (0.6 + 0.4 * n2);
	dirt *= 1.0 - 0.42 * track;
	ALBEDO = mix(grass, dirt, dm);  // texturen zijn al lineair ingelezen (source_color)
	// De droge-aarde roughnesskaart varieert subtiel binnen een matte band.
	// Gras blijft volledig mat; op afstand vervaagt materiaalruis met albedo-detail.
	float dirt_roughness = mix(0.98, 0.82, roughness_sample);
	ROUGHNESS = mix(1.0, dirt_roughness, dm * micro_detail);
	SPECULAR = dm * 0.16;
	// Graphics 2.0: plassen in moeras, langs de oever en op de laagste plekken van de modder glanzen in de zon
	float wet = g2_wet * dm * clamp(max(swamp, 1.0 - smoothstep(2.9, 6.0, river_off)) + smoothstep(0.42, 0.2, n2) * 0.7, 0.0, 1.0);
	ROUGHNESS = mix(ROUGHNESS, 0.3, wet * 0.8);
	SPECULAR = mix(SPECULAR, 0.5, wet);
	ALBEDO *= 1.0 - 0.28 * wet;
	// Graphics 2.0: plassen in de modder en in de sporen: donker, spiegelglad, met een zweem van de lucht
	// Een paar grotere plassen op de laagste plekken (geen spikkels): natte donkere rand, glad water dat de lucht spiegelt.
	float pud_n = texture(noise_a, p * 0.075 + 0.61).r + 0.05 * (n2 - 0.5);
	float pud_zone = g2_wet * smoothstep(0.6, 0.95, dm) * max(smoothstep(0.5, 0.9, trail), swamp);
	float pud_rim = pud_zone * smoothstep(0.69, 0.75, pud_n);
	float puddle = pud_zone * smoothstep(0.745, 0.775, pud_n);
	ALBEDO *= 1.0 - 0.45 * pud_rim;
	ROUGHNESS = mix(ROUGHNESS, 0.35, pud_rim);
	ALBEDO = mix(ALBEDO, vec3(0.035, 0.032, 0.026), puddle * 0.94);
	ROUGHNESS = mix(ROUGHNESS, 0.03, puddle);
	SPECULAR = mix(SPECULAR, 0.55, puddle);
	EMISSION = g2_sky * vec3(0.7, 0.85, 1.0) * puddle * 0.035;
	vec2 dirt_uv = pp * 0.095;
	NORMAL_MAP = texture(dirt_normal, dirt_uv, detail_mip_bias).rgb;
	// Vervaag bumpdetail zodra een pixel meerdere detailtexels beslaat; dit voorkomt
	// temporele aliasing op de schuine top-down camera zonder de dichtbijtextuur vlak te maken.
	float normal_footprint = pixel_span * 0.095;
	float normal_detail = 1.0 - smoothstep(0.001, 0.007, normal_footprint);
	// Geen resterende bump op afstand: dat geeft mobiele shading-shimmer.
	NORMAL_MAP_DEPTH = dm * 0.55 * normal_detail * (1.0 + 0.6 * g2_wet + 0.9 * gravel) * (1.0 - 0.6 * wet) * (1.0 - puddle);
}
