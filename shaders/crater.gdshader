shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, shadows_disabled;
// Krater: de vorm (kuil met opgeworpen rand) komt uit het model, de kleuren rekent de shader zelf uit: een donkere, verbrande
// bodem, omgewoelde bruine aarde op de rand en een roetwaaier die zacht in de grond uitloopt. (De hoekkleuren uit het model
// komen na het exporteren niet betrouwbaar in het spel aan.)

uniform float radius = 1.35;  // buitenrand van het model in meters
uniform float rim = 0.78;  // gemiddelde straal van de rand in meters
uniform vec3 bowl_color : source_color = vec3(0.075, 0.06, 0.05);
uniform vec3 soil_color : source_color = vec3(0.24, 0.16, 0.09);
uniform vec3 crest_color : source_color = vec3(0.3, 0.2, 0.12);
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

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
	vec2 p = local_pos.xz;
	float r = length(p);
	float a = atan(p.y, p.x);
	float n = vnoise(p * 4.0);
	float rr = rim * (1.0 + 0.12 * sin(a * 3.0 + radius) + 0.08 * sin(a * 7.0));
	float u = r / rr;  // 1 = op de rand
	vec3 col = mix(bowl_color, soil_color, smoothstep(0.45, 1.0, u));
	col = mix(col, crest_color, smoothstep(0.85, 1.05, u) * (1.0 - smoothstep(1.05, 1.5, u)));
	// buiten de rand: roetwaaier, steeds donkerder dan de grond en doorlopend naar niets
	float out_t = smoothstep(1.0, radius / rr, u);
	col = mix(col, bowl_color * 1.6, out_t * 0.55);
	col *= 0.85 + 0.3 * n;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = 1.0 - smoothstep(0.62, 1.0, r / radius);
}
