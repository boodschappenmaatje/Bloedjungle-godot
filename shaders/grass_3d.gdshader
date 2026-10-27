shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Opaque curved blades: no alpha cards, transparency sorting or per-blade physics.
uniform sampler2D albedo_tex : source_color, repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, repeat_disable, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : repeat_disable, filter_linear_mipmap;
uniform float wind = 0.0;
uniform float normal_strength = 0.35;
uniform float player_bend = 0.0;  // 1 = gras buigt voor wie erdoorheen loopt (uit in de bouwmodus)
uniform vec4 pushers[8];          // zoals in foliage.gdshader: x/y = positie (x, z), z = straal, w = kracht
varying vec3 blade_color;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// glTF flips Blender V. Vertex alpha is the authored root-to-tip weight.
	float tip = pow(clamp(COLOR.a, 0.0, 1.0), 1.8);
	float phase = wp.x * 0.41 + wp.z * 0.29;
	float gust = sin(TIME * 1.35 + phase) * 0.65 + sin(TIME * 2.1 + phase * 0.7) * 0.35;
	float amount = tip * wind * clamp(VERTEX.y, 0.1, 1.4);
	VERTEX.x += gust * 0.075 * amount;
	VERTEX.z += sin(TIME * 1.1 + phase * 0.8) * 0.045 * amount;
	// Gras buigt weg van speler, soldaten, vijanden en voertuigen; wortels blijven vast, geen AI-effect.
	vec2 push = vec2(0.0);
	for (int i = 0; i < 8; i++) {
		vec4 pu = pushers[i];
		if (pu.w <= 0.0) {
			continue;
		}
		vec2 away = wp.xz - pu.xy;
		float d = length(away);
		float influence = (1.0 - smoothstep(pu.z * 0.2, pu.z, d)) * pu.w;
		push += away / max(d, 0.05) * 0.16 * (pu.z / 0.85) * influence;
	}
	push *= tip * player_bend;
	// Convert a world-space push into the local basis (rotation/scale may vary per tuft).
	VERTEX += transpose(MODEL_NORMAL_MATRIX) * vec3(push.x, 0.0, push.y);
	blade_color = COLOR.rgb;
}

void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec3 base = texture(albedo_tex, UV).rgb * blade_color;
	vec3 orm = texture(orm_tex, UV).rgb;
	ALBEDO = base;
	ROUGHNESS = orm.g;
	METALLIC = 0.0;
	SPECULAR = 0.25;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.15;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	BACKLIGHT = base * 0.28;
}
