shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;
// Stuwmeer achter de dam: rustig, diep en donker midden, heldere ondiepe rand met zachte schuimrand. De diepte zit in
// de vertexkleur (r = diepte / 12 m), gemaakt in scripts/stuwmeer.gd uit de terreinhoogte. Geen stroming.

uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.05, 0.20, 0.22);
uniform vec3 shallow : source_color = vec3(0.24, 0.50, 0.44);
uniform vec3 foam : source_color = vec3(0.85, 0.92, 0.88);

varying vec3 wpos;
varying float depth_m;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth_m = COLOR.r * 12.0;
}

void fragment() {
	vec2 p = wpos.xz;
	float r1 = texture(noise, p * 0.06 + vec2(TIME * 0.012, TIME * 0.008)).r;
	float r2 = texture(noise, p * 0.17 + vec2(-TIME * 0.02, TIME * 0.014) + 0.3).r;
	float rip = r1 * 0.55 + r2 * 0.45;
	float shallow_k = 1.0 - smoothstep(0.3, 4.5, depth_m);
	vec3 col = mix(deep, shallow, shallow_k * 0.85 + 0.15 * smoothstep(0.4, 0.7, rip));
	float edge = 1.0 - smoothstep(0.05, 0.9, depth_m);
	float fl = smoothstep(0.45, 0.7, texture(noise, p * 0.4 + vec2(TIME * 0.03, 0.0)).r);
	col = mix(col, foam, clamp(edge * (0.35 + 0.5 * fl), 0.0, 0.8));
	vec2 g = vec2(r1 - 0.5, r2 - 0.5) * 0.25;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(g.x, 0.0, g.y, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	col = mix(col, vec3(0.45, 0.72, 0.78), fres * 0.45);
	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	float glint = smoothstep(0.68, 0.82, rip);
	EMISSION = vec3(1.0, 0.95, 0.8) * glint * 0.35;
	ROUGHNESS = 0.07 + 0.2 * edge;
	SPECULAR = 0.8;
	ALPHA = clamp(smoothstep(0.0, 0.7, depth_m) * mix(0.97, 0.62, shallow_k), 0.0, 1.0);
}
