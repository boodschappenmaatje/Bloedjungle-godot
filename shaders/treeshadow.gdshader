shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;
// Mobiele hulp-schaduw: een zachte, lage-cost projectie met richting en lengte uit
// de zonstand. De echte boomkroon blijft verantwoordelijk voor het bladpatroon.

uniform vec2 sun_dir = vec2(0.6, 0.8);  // waarheen de schaduw valt (x, z)
uniform float reach = 1.5;  // lengte per meter boomhoogte (1 / tan(zonhoogte))
uniform float height = 6.0;  // boomhoogte in meters (bij schaal 1)
uniform float width = 2.4;  // breedte van de schaduw in meters
uniform float strength = 0.5;
uniform bool canopy_detail = false;
uniform sampler2D canopy_tex : filter_linear_mipmap, repeat_disable;
uniform bool actor_focus_active = false;
uniform vec2 focus_player_uv = vec2(0.5);
uniform vec3 focus_e0_uv = vec3(0.0);
uniform vec3 focus_e1_uv = vec3(0.0);
uniform vec3 focus_e2_uv = vec3(0.0);
uniform vec2 screen_size_px = vec2(1280.0, 720.0);
uniform float screen_aspect = 1.7777778;

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
		vec2 screen_uv = FRAGCOORD.xy / screen_size_px;
		vec2 delta = (screen_uv - focus_player_uv) * vec2(screen_aspect, 1.0);
		actor_clear = smoothstep(0.04, 0.14, length(delta));
		if (focus_e0_uv.z > 0.5) {
			vec2 enemy_delta = (screen_uv - focus_e0_uv.xy) * vec2(screen_aspect, 1.0);
			actor_clear = min(actor_clear, smoothstep(0.04, 0.14, length(enemy_delta)));
		}
		if (focus_e1_uv.z > 0.5) {
			vec2 enemy_delta = (screen_uv - focus_e1_uv.xy) * vec2(screen_aspect, 1.0);
			actor_clear = min(actor_clear, smoothstep(0.04, 0.14, length(enemy_delta)));
		}
		if (focus_e2_uv.z > 0.5) {
			vec2 enemy_delta = (screen_uv - focus_e2_uv.xy) * vec2(screen_aspect, 1.0);
			actor_clear = min(actor_clear, smoothstep(0.04, 0.14, length(enemy_delta)));
		}
	}
	ALPHA = (1.0 - smoothstep(0.2, 1.0, d)) * strength * mask * actor_clear;
}
