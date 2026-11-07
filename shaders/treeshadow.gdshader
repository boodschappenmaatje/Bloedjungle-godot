shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;
// Vaste nepschaduw onder bomen en struiken: een zachte ovaal op de grond, in de richting van de zon
// en zo lang als de boom hoog is gedeeld door de hoek van de zon. Geen schaduwkaart nodig, dus bijna gratis.

uniform vec2 sun_dir = vec2(0.6, 0.8);  // waarheen de schaduw valt (x, z)
uniform float reach = 1.5;  // lengte per meter boomhoogte (1 / tan(zonhoogte))
uniform float height = 6.0;  // boomhoogte in meters (bij schaal 1)
uniform float width = 2.4;  // breedte van de schaduw in meters
uniform float strength = 0.5;
uniform bool canopy_detail = false;
uniform sampler2D canopy_tex : filter_linear_mipmap, repeat_disable;
uniform bool actor_focus_active = false;
uniform vec2 focus_player_xz = vec2(0.0);
uniform vec3 focus_e0 = vec3(0.0);
uniform vec3 focus_e1 = vec3(0.0);
uniform vec3 focus_e2 = vec3(0.0);
uniform float actor_clear_inner = 0.9;
uniform float actor_clear_outer = 2.8;
varying vec2 world_shadow_xz;

void vertex() {
	vec2 l = normalize(sun_dir);
	vec2 w = vec2(-l.y, l.x);
	float s = length(MODEL_MATRIX[0].xyz);
	float len = max(height * reach * s, width * s);
	float along = (VERTEX.x + 0.5) * len - width * s * 0.35;
	float across = VERTEX.z * width * s;
	vec3 wp = MODEL_MATRIX[3].xyz + vec3(l.x * along + w.x * across, 0.05, l.y * along + w.y * across);
	world_shadow_xz = wp.xz;
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	float d = length((UV - 0.5) * 2.0);
	ALBEDO = vec3(0.0);
	float mask = 1.0;
	if (canopy_detail) {
		// Reuse the shipped palm alpha silhouette on the existing shadow quad.
		// This is explicitly an approximate fixed shadow, never geometry-accurate shadowing.
		vec2 q = (UV-0.5)*2.0;
		float angle = atan(q.y,q.x);
		vec2 frond_uv = vec2(clamp(d,0.0,1.0),fract((angle/6.2831853+0.5)*9.0));
		float leaf = texture(canopy_tex,frond_uv).a;
		float detail = 1.0-smoothstep(0.02,0.1,max(length(dFdx(q)),length(dFdy(q))));
		mask = mix(0.62,0.28+0.72*leaf,detail);
	}
	float actor_clear = 1.0;
	if (actor_focus_active) {
		actor_clear = smoothstep(actor_clear_inner, actor_clear_outer, distance(world_shadow_xz, focus_player_xz));
		if (focus_e0.z > 0.5) actor_clear = min(actor_clear, smoothstep(actor_clear_inner, actor_clear_outer, distance(world_shadow_xz, focus_e0.xy)));
		if (focus_e1.z > 0.5) actor_clear = min(actor_clear, smoothstep(actor_clear_inner, actor_clear_outer, distance(world_shadow_xz, focus_e1.xy)));
		if (focus_e2.z > 0.5) actor_clear = min(actor_clear, smoothstep(actor_clear_inner, actor_clear_outer, distance(world_shadow_xz, focus_e2.xy)));
	}
	ALPHA = (1.0 - smoothstep(0.2, 1.0, d)) * strength * mask * actor_clear;
}
