shader_type spatial;
render_mode specular_disabled, cull_back;
// Bergland rond de kaart (scripts/bergland.gd): beboste hellingen met een golvend bladerdak, kale rotswanden waar het
// steil is, donkere dalen (holte in de vertexkleur, r) en een zachte overgang naar de grondplaat (g = afstand tot de plaat).
// Eén textuurlookup per laag, geen extra lichten.

uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform sampler2D canopy_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 canopy_dark : source_color = vec3(0.06, 0.11, 0.04);
uniform vec3 canopy_light : source_color = vec3(0.22, 0.30, 0.10);
uniform vec3 edge_col : source_color = vec3(0.24, 0.30, 0.13);   // ongeveer de kleur van de jungle op de rand van de plaat
uniform vec3 rock_col : source_color = vec3(0.42, 0.40, 0.34);

varying vec3 wpos;
varying vec3 wnorm;
varying float cav;
varying float edge;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	cav = COLOR.r;
	edge = COLOR.g;
}

void fragment() {
	vec2 p = wpos.xz;
	// bladerdak: twee lagen ruis geven boomkruinen (licht) en gaten ertussen (donker)
	float c1 = texture(noise, p * 0.045).r;
	float c2 = texture(noise, p * 0.13 + 0.37).r;
	float crowns = smoothstep(0.35, 0.75, c1 * 0.55 + c2 * 0.45);
	vec3 leaf = texture(canopy_tex, p * 0.05).rgb;
	vec3 canopy = mix(canopy_dark, canopy_light, crowns) * (0.75 + 0.5 * leaf);
	// hoger = iets blauwer en droger groen
	canopy = mix(canopy, canopy * vec3(0.9, 1.0, 1.08), smoothstep(10.0, 50.0, wpos.y));
	// steil = rots (triplanair langs de twee zijkanten, zodat er niets uitrekt)
	vec3 n = normalize(wnorm);
	float steep = smoothstep(0.82, 0.62, n.y);
	vec3 rx = texture(rock_tex, wpos.zy * 0.04).rgb;
	vec3 rz = texture(rock_tex, wpos.xy * 0.04).rgb;
	vec3 rock = rock_col * mix(rx, rz, abs(n.z) / (abs(n.x) + abs(n.z) + 0.001)) * 1.6;
	// mos en struiken ook op rots, maar minder
	rock = mix(rock, canopy_dark * 1.4, smoothstep(0.55, 0.85, c2) * 0.5);
	vec3 col = mix(canopy, rock, steep);
	// holte: dalen en voeten van hellingen donkerder (goedkope occlusie)
	col *= mix(0.62, 1.15, cav);
	// rand van de plaat: zacht overvloeien in de junglekleur van de grond
	col = mix(edge_col * (0.8 + 0.4 * leaf), col, edge);
	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));   // kleuren en texturen zijn al lineair (source_color)
	ROUGHNESS = 1.0;
}
