shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
// Bladeren en stammen. Kleur = textuur (mag leeg zijn) x vertexkleur (rgb); de alfa van de
// vertexkleur zegt hoe hard een punt in de wind beweegt (0 = vast, 1 = losse bladpunt).
// Wat in de textuur doorzichtig is wordt weggeknipt, zo krijgen palmtakken hun bladpunten.

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = true;
uniform bool tile = false;  // schors herhaalt zich; bladeren niet (rand vastgeklemd)
uniform float nrm_depth = 1.0;
uniform float sway = 0.14;
uniform float wind = 0.0;  // 0 = bomen staan stil, 1 = ze bewegen (instelling "Bomen bewegen")
uniform float speed = 1.5;
uniform float cut = 0.45;
uniform float backlight = 0.5;
uniform vec3 tint = vec3(0.82, 0.86, 0.74);

// Zichtlijn: bladeren tussen camera en speler (en de drie dichtstbijzijnde vijanden, w = 1 als actief)
// worden gedither-uitgedund. fade_amount loopt zacht 0..1 (in- en uitfaden in de tijd).
uniform vec3 view_player = vec3(0.0);
uniform vec3 view_camera = vec3(0.0);
uniform vec4 view_e0 = vec4(0.0);
uniform vec4 view_e1 = vec4(0.0);
uniform vec4 view_e2 = vec4(0.0);
uniform float fade_amount = 1.0;
uniform bool fade_sightline = false;
// Wie er door de struiken loopt (speler, soldaten, vijanden, voertuigen): tot 8 stuks, x/y = positie op de grond (x, z),
// z = straal waarbinnen het blad opzij gaat, w = kracht (0 = niet gebruikt). Zet door Foliage.update_pushers.
uniform vec4 pushers[8];
varying vec3 vcol;
varying vec3 world_leaf;

// 0 = blad staat niet in de weg, 1 = midden op de zichtlijn
float sight_hide(vec3 p, vec3 target, vec3 cam, float r) {
	vec3 line = cam - target;
	float param = clamp(dot(p - target, line) / max(dot(line, line), 0.01), 0.0, 1.0);
	float d = distance(p, target + line * param);
	float along = smoothstep(0.03, 0.12, param) * (1.0 - smoothstep(0.84, 0.94, param));
	return along * (1.0 - smoothstep(r * 0.3, r, d));
}

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float ph = wp.x * 0.37 + wp.z * 0.23;
	float m = COLOR.a * wind;
	VERTEX.x += sin(TIME * speed + ph + VERTEX.y * 0.9) * sway * m;
	VERTEX.z += cos(TIME * speed * 0.8 + ph * 1.3) * sway * 0.6 * m;
	VERTEX.y += sin(TIME * speed * 1.7 + ph) * sway * 0.25 * m;
	// Struiken en varens buigen weg van wie erdoorheen loopt, en ritselen zolang het duurt. Alleen laag blad
	// (onder ~2 m): de kronen van palmen en bomen blijven staan. Wortels zitten vast, de bladpunten bewegen het meest.
	vec3 base_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float low = 1.0 - smoothstep(1.3, 2.3, base_pos.y);
	if (low > 0.0 && COLOR.a > 0.0) {
		vec2 push = vec2(0.0);
		float shake = 0.0;
		for (int i = 0; i < 8; i++) {
			vec4 pu = pushers[i];
			if (pu.w <= 0.0) {
				continue;
			}
			vec2 away = base_pos.xz - pu.xy;
			float d = length(away);
			float influence = (1.0 - smoothstep(pu.z * 0.45, pu.z, d)) * pu.w;
			push += away / max(d, 0.05) * influence * pu.z * 1.1;
			shake += influence;
		}
		float w = COLOR.a * low;
		push *= w;
		float len = length(push);
		if (len > 1.1) {
			push *= 1.1 / len;
			len = 1.1;
		}
		shake = min(shake, 1.0) * w;
		vec2 rustle = vec2(sin(TIME * 11.0 + ph * 3.0 + base_pos.y * 4.0), cos(TIME * 9.0 + ph * 2.0)) * 0.13 * shake;
		VERTEX += transpose(MODEL_NORMAL_MATRIX) * vec3(push.x + rustle.x, -min(len * 0.7, base_pos.y * 0.85), push.y + rustle.y);
	}
	vcol = COLOR.rgb;
	world_leaf = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = tile ? UV : clamp(UV, 0.0, 1.0);
	vec3 base = pow(vcol, vec3(2.2));  // vertexkleuren zijn sRGB gekozen, de shader rekent lineair
	vec4 t = use_tex ? texture(tex, uv) : vec4(1.0);
	if (t.a < cut) discard;
	if (fade_sightline) {
		float hide = sight_hide(world_leaf, view_player, view_camera, 2.6);
		if (view_e0.w > 0.5) hide = max(hide, sight_hide(world_leaf, view_e0.xyz, view_camera, 1.8));
		if (view_e1.w > 0.5) hide = max(hide, sight_hide(world_leaf, view_e1.xyz, view_camera, 1.8));
		if (view_e2.w > 0.5) hide = max(hide, sight_hide(world_leaf, view_e2.xyz, view_camera, 1.8));
		// alleen in het hoofdbeeld: in de schaduwkaart (camera = de zon) blijft het blad heel, dus geen gaatjesschaduw
		if (hide > 0.0 && distance(INV_VIEW_MATRIX[3].xyz, view_camera) < 1.0) {
			float n = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));  // goedkoop interleaved-gradient-ruis
			if (n < hide * 0.76 * fade_amount) discard;
		}
	}
	if (use_tex) {
		NORMAL_MAP = texture(nrm, uv).rgb;
		NORMAL_MAP_DEPTH = nrm_depth;
	}
	ALBEDO = base * t.rgb * tint;
	ROUGHNESS = 0.58;
	SPECULAR = 0.3;
	BACKLIGHT = ALBEDO * backlight;
}
