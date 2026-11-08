shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// M-47 schokgolf: een ring van zeshoekjes (honingraat) die uitdijt, oplicht en cel voor cel uitdooft.
// Een vlak (QuadMesh) is genoeg; de ring wordt in de fragmentshader getekend.
uniform float voortgang : hint_range(0.0, 1.0) = 0.0;   // 0 = net geraakt, 1 = weg
uniform vec3 kleur : source_color = vec3(0.12, 0.55, 1.0);
uniform vec3 kern : source_color = vec3(0.75, 0.93, 1.0);
uniform float cel = 0.14;       // zeshoekgrootte t.o.v. de halve kaartbreedte
uniform float intensiteit = 1.7;

// Afstand tot de rand van het dichtstbijzijnde zeshoekje (0 = op de lijn) en het celnummer.
vec3 hex(vec2 p) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(p - hc.xy * s, p - (hc.zw + 0.5) * s);
	vec4 d = vec4(dot(h.xy, h.xy), h.xy, 0.0);
	vec4 e = vec4(dot(h.zw, h.zw), h.zw, 0.0);
	vec2 q; vec2 id;
	if (d.x < e.x) { q = h.xy; id = hc.xy; } else { q = h.zw; id = hc.zw + 0.5; }
	q = abs(q);
	float rand = 0.5 - max(dot(q, s * 0.5), q.x);   // 0 op de rand, 0.5 in het midden
	return vec3(rand, id);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = (UV - 0.5) * 2.0;
	float r = length(uv);
	float rr = mix(0.12, 0.92, 1.0 - pow(1.0 - voortgang, 2.2));  // ring-straal, remt af
	vec3 h = hex(uv / cel);
	float fw = fwidth(h.x) * 1.5;
	float lijn = 1.0 - smoothstep(0.045, 0.045 + fw + 0.02, h.x);   // zeshoeklijn met schermafgeleide: nooit dunner dan een pixel
	float halo = exp(-h.x * 14.0) * 0.35;                // zachte gloed rond de lijn
	float vul = smoothstep(0.5, 0.0, h.x) * 0.03;        // heel zwakke celvulling
	// Per cel een eigen helderheid en moment van uitdoven: de golf breekt op, enkele cellen ontbreken.
	float n = hash(h.yz);
	float cel_aan = step(0.14, n);
	float helder = 0.55 + 0.9 * hash(h.yz + 7.3);
	float band = exp(-pow((r - rr) / (0.075 + 0.04 * voortgang), 2.0));
	float binnen = smoothstep(rr, 0.0, r) * 0.30 * (1.0 - voortgang);   // zwak nalichten achter de rand
	float uit = smoothstep(n * 0.55 + 0.3, n * 0.55 + 0.55, voortgang); // cel dooft uit
	float a = (band * (lijn + halo + vul) + binnen * (lijn * 0.6 + halo * 0.5 + vul)) * helder * cel_aan * (1.0 - uit);
	a *= smoothstep(1.0, 0.82, r);                        // zachte buitenrand van de kaart
	// Blauwe lijnen; alleen op de allervoorste rand van de golf een wit-blauwe kern.
	vec3 c = mix(kleur, kern, clamp(band * band * lijn * helder * 0.9, 0.0, 1.0));
	ALBEDO = c * a * intensiteit;
}
