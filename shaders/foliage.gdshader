shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
// Bladeren en stammen: kleur komt uit de vertexkleuren (rgb), de alfa zegt hoe hard een punt in de wind
// beweegt (0 = vast bij de grond, 1 = losse bladpunt). Elke boom krijgt zijn eigen fase.

uniform float sway = 0.14;
uniform float speed = 1.5;

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
	ALBEDO = pow(vcol, vec3(2.2));  // vertexkleuren zijn sRGB gekozen, de shader rekent lineair
	ROUGHNESS = 0.8;
	// licht dat door het blad schijnt
	BACKLIGHT = ALBEDO * 0.5;
}
