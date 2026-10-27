shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Napalmvlam: een brede, hoge vlamtong op een kijkrichting-vlak dat om de verticale as meedraait (de voet blijft op de grond).
// De vorm komt uit ruis die naar boven stroomt: een hete, witgele kern, een oranje lichaam en rode, rafelige toppen.

instance uniform float grow : hint_range(0.0, 1.0) = 1.0;
instance uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 9.1) * 0.15;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.y *= grow;
	VERTEX.x *= 0.55 + 0.45 * grow;
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 2.0, 1.0 - UV.y);   // p.y: 0 = voet, 1 = top
	float t = TIME + seed * 17.0;
	float sway = fbm(vec2(p.x * 1.1 + seed * 5.0, p.y * 1.3 - t * 1.5));
	float x = p.x + (sway - 0.5) * 1.1 * p.y;               // de hele vlam zwiept heen en weer, meer naar boven
	// lange, smalle tongen: hoge frequentie opzij, lage frequentie omhoog, die naar boven stromen
	float tongues = fbm(vec2(x * 3.4 + seed * 7.0, p.y * 0.9 - t * 2.3));
	float turb = fbm(vec2(x * 2.2 - seed, p.y * 2.6 - t * 3.2));
	float width = 0.92 * pow(max(1.0 - p.y, 0.0), 0.4);
	float body = 1.0 - smoothstep(width * 0.15, width, abs(x));
	float heat = body * (0.3 + 1.15 * tongues) - p.y * 0.5 + (turb - 0.5) * 0.55;
	float flame = smoothstep(0.14, 0.42, heat) * (1.0 - smoothstep(0.62, 1.0, p.y)) * smoothstep(0.0, 0.06, p.y);
	vec3 c = mix(vec3(0.28, 0.02, 0.0), vec3(1.0, 0.22, 0.02), smoothstep(0.12, 0.38, heat));
	c = mix(c, vec3(1.0, 0.58, 0.08), smoothstep(0.36, 0.66, heat));
	c = mix(c, vec3(1.0, 0.92, 0.5), smoothstep(0.7, 1.0, heat));
	ALBEDO = c * 1.15;
	ALPHA = flame * 0.95;
}
