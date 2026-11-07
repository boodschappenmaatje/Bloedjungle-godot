shader_type spatial;
// Opaque mobile water avoids a full-screen transparent pass; depth and color
// bands encode the shallow shelves while PBR specular carries sky/sun glints.
render_mode depth_draw_opaque, cull_disabled;
// Rivierwater: helder groen-blauw dat zichtbaar naar het oosten stroomt: lange strepen en schuimvlokken schuiven langs
// de stroomrichting (x), sneller in het midden dan bij de oevers, met schuim langs de rand.

uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.25, 0.48, 0.49);
uniform vec3 shallow : source_color = vec3(0.48, 0.69, 0.62);
uniform vec3 foam : source_color = vec3(0.85, 0.92, 0.88);
uniform float speed = 1.6;

varying vec3 wpos;

float river_z(float x) {
	return -92.0 + 5.0 * sin(0.06 * x) + 2.0 * sin(0.15 * x + 1.0);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = abs(wpos.z - river_z(wpos.x));       // afstand tot het midden
	float mid = 1.0 - smoothstep(0.0, 2.6, d);     // 1 in het midden, 0 aan de oever
	float v = speed * (0.45 + 0.55 * mid);
	vec2 p = vec2(wpos.x, wpos.z);
	// lange strepen langs de stroom
	float s1 = texture(noise, vec2(p.x * 0.035 - TIME * v * 0.05, p.y * 0.45)).r;
	float s2 = texture(noise, vec2(p.x * 0.07 - TIME * v * 0.09, p.y * 0.9 + 0.37)).r;
	float streak = s1 * 0.6 + s2 * 0.4;
	// schuimvlokken die voorbij drijven
	float f = texture(noise, vec2(p.x * 0.11 - TIME * v * 0.14, p.y * 0.7 + 0.71)).r;
	float flake = smoothstep(0.66, 0.8, f * 0.6 + streak * 0.5);
	float edge = smoothstep(1.7, 2.5, d);
	float edgefoam = edge * smoothstep(0.42, 0.65, texture(noise, vec2(p.x * 0.3 - TIME * v * 0.12, p.y * 0.3)).r);
	// Diepte: een iets donkerder stroomgoot, ondiepe turkooizen randen.
	float depth = smoothstep(2.7, 0.28, d);
	float current_glint = smoothstep(0.38, 0.7, streak);
	vec3 col = mix(shallow, deep, depth * 0.72);
	col = mix(col, shallow * vec3(1.02, 1.07, 1.04), current_glint * 0.24);
	col += vec3(0.025, 0.055, 0.055) * current_glint;
	col = mix(col, foam, clamp(flake * 0.55 + edgefoam * 0.8, 0.0, 1.0));
	// rimpels die in twee richtingen schuiven: geven glinsteringen in het zonlicht en een bewegend oppervlak
	float r1 = texture(noise, p * 0.55 + vec2(-TIME * v * 0.09, TIME * 0.03)).r;
	float r2 = texture(noise, p * 0.9 + vec2(-TIME * v * 0.14, -TIME * 0.05) + 0.3).r;
	float rip = r1 * 0.55 + r2 * 0.45;
	float glint = smoothstep(0.68, 0.82, rip) * (1.0 - flake);
	col += vec3(0.20,0.18,0.12) * glint * 0.14;
	vec2 g = vec2(r1 - 0.5, r2 - 0.5) * 0.5 + vec2(s1 - 0.5, s2 - 0.5) * 0.25;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(g.x, 0.0, g.y, 0.0)).xyz);
	// spiegeling van de lucht onder een scheve kijkhoek
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	col = mix(col, vec3(0.36, 0.66, 0.70), fres * 0.32);
	ALBEDO = col;
	EMISSION = vec3(0.0);
	ROUGHNESS = 0.12 + 0.19 * flake;
	SPECULAR = 0.72;
	METALLIC = 0.0;
}
