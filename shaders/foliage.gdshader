shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
// Bladeren en stammen. Kleur = textuur (mag leeg zijn) x vertexkleur (rgb); de alfa van de
// vertexkleur zegt hoe hard een punt in de wind beweegt (0 = vast, 1 = losse bladpunt).
// Wat in de textuur doorzichtig is wordt weggeknipt, zo krijgen palmtakken hun bladpunten.

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_tex = true;
uniform float sway = 0.14;
uniform float speed = 1.5;
uniform float cut = 0.45;
uniform float backlight = 0.5;

varying vec3 vcol;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float ph = wp.x * 0.37 + wp.z * 0.23;
	float m = COLOR.a;
	VERTEX.x += sin(TIME * speed + ph + VERTEX.y * 0.9) * sway * m;
	VERTEX.z += cos(TIME * speed * 0.8 + ph * 1.3) * sway * 0.6 * m;
	VERTEX.y += sin(TIME * speed * 1.7 + ph) * sway * 0.25 * m;
	vcol = COLOR.rgb;
}

void fragment() {
	vec3 base = pow(vcol, vec3(2.2));  // vertexkleuren zijn sRGB gekozen, de shader rekent lineair
	vec4 t = use_tex ? texture(tex, UV) : vec4(1.0);
	if (t.a < cut) discard;
	ALBEDO = base * t.rgb * vec3(0.42, 0.5, 0.33);  // dieper, minder fel groen
	ROUGHNESS = 0.75;
	BACKLIGHT = ALBEDO * backlight;
}
