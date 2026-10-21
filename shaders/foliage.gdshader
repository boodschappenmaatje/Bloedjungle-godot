shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
// Bladeren en stammen. Kleur = textuur (mag leeg zijn) x vertexkleur (rgb); de alfa van de
// vertexkleur zegt hoe hard een punt in de wind beweegt (0 = vast, 1 = losse bladpunt).
// Wat in de textuur doorzichtig is wordt weggeknipt, zo krijgen palmtakken hun bladpunten.

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap, repeat_disable;
uniform bool use_tex = true;
uniform float nrm_depth = 1.0;
uniform float sway = 0.14;
uniform float wind = 0.0;  // 0 = bomen staan stil, 1 = ze bewegen (instelling "Bomen bewegen")
uniform float speed = 1.5;
uniform float cut = 0.45;
uniform float backlight = 0.5;
uniform vec3 tint = vec3(0.82, 0.86, 0.74);

varying vec3 vcol;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float ph = wp.x * 0.37 + wp.z * 0.23;
	float m = COLOR.a * wind;
	VERTEX.x += sin(TIME * speed + ph + VERTEX.y * 0.9) * sway * m;
	VERTEX.z += cos(TIME * speed * 0.8 + ph * 1.3) * sway * 0.6 * m;
	VERTEX.y += sin(TIME * speed * 1.7 + ph) * sway * 0.25 * m;
	vcol = COLOR.rgb;
}

void fragment() {
	vec3 base = pow(vcol, vec3(2.2));  // vertexkleuren zijn sRGB gekozen, de shader rekent lineair
	vec4 t = use_tex ? texture(tex, UV) : vec4(1.0);
	if (t.a < cut) discard;
	if (use_tex) {
		NORMAL_MAP = texture(nrm, UV).rgb;
		NORMAL_MAP_DEPTH = nrm_depth;
	}
	ALBEDO = base * t.rgb * tint;
	ROUGHNESS = 0.58;
	SPECULAR = 0.3;
	BACKLIGHT = ALBEDO * backlight;
}
