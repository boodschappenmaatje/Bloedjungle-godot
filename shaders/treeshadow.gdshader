shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;
// Vaste nepschaduw onder bomen en struiken: een zachte ovaal op de grond, in de richting van de zon
// en zo lang als de boom hoog is gedeeld door de hoek van de zon. Geen schaduwkaart nodig, dus bijna gratis.

uniform vec2 sun_dir = vec2(0.6, 0.8);  // waarheen de schaduw valt (x, z)
uniform float reach = 1.5;  // lengte per meter boomhoogte (1 / tan(zonhoogte))
uniform float height = 6.0;  // boomhoogte in meters (bij schaal 1)
uniform float width = 2.4;  // breedte van de schaduw in meters
uniform float strength = 0.5;

void vertex() {
	vec2 l = normalize(sun_dir);
	vec2 w = vec2(-l.y, l.x);
	float s = length(MODEL_MATRIX[0].xyz);
	float len = max(height * reach * s, width * s);
	float along = (VERTEX.x + 0.5) * len - width * s * 0.35;
	float across = VERTEX.z * width * s;
	vec3 wp = MODEL_MATRIX[3].xyz + vec3(l.x * along + w.x * across, 0.05, l.y * along + w.y * across);
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.2, 1.0, d)) * strength;
}
