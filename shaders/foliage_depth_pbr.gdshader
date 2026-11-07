shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Scanned CC0 understory assets use their own physical roughness and normal
// maps. Keep the older wrap-Lambert shader for the painted legacy foliage.
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 foliage_grade = vec3(1.06, 1.02, 0.94);
uniform float foliage_saturation = 0.84;
uniform float cut = 0.42;
uniform float nrm_depth = 0.62;
uniform float roughness_scale = 1.0;
uniform float roughness_floor = 0.56;
uniform float leaf_specular = 0.24;
uniform float sway = 0.14;
uniform float wind = 0.0;
uniform float speed = 1.5;
uniform float backlight = 0.08;
uniform vec3 tint = vec3(1.02, 1.03, 0.95);

uniform vec3 view_player = vec3(0.0);
uniform vec3 view_camera = vec3(0.0);
uniform vec4 view_e0 = vec4(0.0);
uniform vec4 view_e1 = vec4(0.0);
uniform vec4 view_e2 = vec4(0.0);
uniform vec2 focus_player_uv = vec2(0.5);
uniform vec3 focus_e0_uv = vec3(0.0);
uniform vec3 focus_e1_uv = vec3(0.0);
uniform vec3 focus_e2_uv = vec3(0.0);
uniform vec2 screen_size_px = vec2(1280.0, 720.0);
uniform float screen_aspect = 1.7777778;
uniform float fade_amount = 1.0;
uniform bool fade_sightline = false;
uniform vec4 pushers[8];

varying float root_contact;
varying vec3 world_leaf;
varying vec3 instance_tint;

float sight_hide(vec3 p, vec3 target, vec3 cam, float radius) {
	vec3 line = cam - target;
	float param = clamp(dot(p - target, line) / max(dot(line, line), 0.01), 0.0, 1.0);
	float d = distance(p, target + line * param);
	float along = smoothstep(0.03, 0.12, param) * (1.0 - smoothstep(0.84, 0.94, param));
	return along * (1.0 - smoothstep(radius * 0.3, radius, d));
}

// Clear foliage by its actual screen overlap with the actor. This catches high
// palm fronds that project over the soldier while their trunks sit metres away.
float actor_screen_hide(vec2 screen_uv, vec2 actor_uv) {
	vec2 delta = (screen_uv - actor_uv) * vec2(screen_aspect, 1.0);
	return 1.0 - smoothstep(0.032, 0.11, length(delta));
}

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float phase = wp.x * 0.37 + wp.z * 0.23;
	float movable = COLOR.a * wind;
	VERTEX.x += sin(TIME * speed + phase + VERTEX.y * 0.9) * sway * movable;
	VERTEX.z += cos(TIME * speed * 0.8 + phase * 1.3) * sway * 0.6 * movable;
	VERTEX.y += sin(TIME * speed * 1.7 + phase) * sway * 0.25 * movable;
	vec3 base_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float low = 1.0 - smoothstep(1.3, 2.3, base_pos.y);
	if (low > 0.0 && COLOR.a > 0.0) {
		vec2 push = vec2(0.0);
		float rustle = 0.0;
		for (int i = 0; i < 8; i++) {
			vec4 pusher = pushers[i];
			if (pusher.w <= 0.0) { continue; }
			vec2 away = base_pos.xz - pusher.xy;
			float d = length(away);
			float influence = (1.0 - smoothstep(pusher.z * 0.45, pusher.z, d)) * pusher.w;
			push += away / max(d, 0.05) * influence * pusher.z * 1.1;
			rustle += influence;
		}
		float weight = COLOR.a * low;
		push *= weight;
		float push_length = length(push);
		if (push_length > 1.1) { push *= 1.1 / push_length; push_length = 1.1; }
		rustle = min(rustle, 1.0) * weight;
		vec2 flutter = vec2(sin(TIME * 11.0 + phase * 3.0 + base_pos.y * 4.0), cos(TIME * 9.0 + phase * 2.0)) * 0.13 * rustle;
		VERTEX += transpose(MODEL_NORMAL_MATRIX) * vec3(push.x + flutter.x, -min(push_length * 0.7, base_pos.y * 0.85), push.y + flutter.y);
	}
	root_contact = mix(0.86, 1.0, smoothstep(0.0, 0.38, COLOR.a));
	instance_tint = COLOR.rgb;
	world_leaf = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 leaf = texture(tex, UV);
	if (leaf.a < cut) { discard; }
	if (fade_sightline) {
		float hide = sight_hide(world_leaf, view_player, view_camera, 5.2);
		vec2 screen_uv = FRAGCOORD.xy / screen_size_px;
		float actor_clear = actor_screen_hide(screen_uv, focus_player_uv);
		if (view_e0.w > 0.5) { hide = max(hide, sight_hide(world_leaf, view_e0.xyz, view_camera, 3.1)); }
		if (view_e1.w > 0.5) { hide = max(hide, sight_hide(world_leaf, view_e1.xyz, view_camera, 3.1)); }
		if (view_e2.w > 0.5) { hide = max(hide, sight_hide(world_leaf, view_e2.xyz, view_camera, 3.1)); }
		if (focus_e0_uv.z > 0.5) { actor_clear = max(actor_clear, actor_screen_hide(screen_uv, focus_e0_uv.xy)); }
		if (focus_e1_uv.z > 0.5) { actor_clear = max(actor_clear, actor_screen_hide(screen_uv, focus_e1_uv.xy)); }
		if (focus_e2_uv.z > 0.5) { actor_clear = max(actor_clear, actor_screen_hide(screen_uv, focus_e2_uv.xy)); }
		actor_clear *= fade_amount;
		hide = max(hide, actor_clear);
		if (hide > 0.0 && distance(INV_VIEW_MATRIX[3].xyz, view_camera) < 1.0) {
			float noise = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
			if (actor_clear > 0.985) { discard; }
			if (noise < hide * 0.93 * fade_amount) { discard; }
		}
	}
	vec3 mapped_color = mix(vec3(dot(leaf.rgb, vec3(0.2126, 0.7152, 0.0722))), leaf.rgb, foliage_saturation);
	ALBEDO = mapped_color * foliage_grade * tint * instance_tint * root_contact;
	vec3 surface = texture(rough_tex, UV).rgb;
	ROUGHNESS = clamp(surface.r * roughness_scale, roughness_floor, 0.96);
	SPECULAR = leaf_specular;
	METALLIC = 0.0;
	AO = clamp(surface.g * root_contact, 0.70, 1.0);
	AO_LIGHT_AFFECT = 0.18;
	NORMAL_MAP = texture(nrm, UV).rgb;
	NORMAL_MAP_DEPTH = nrm_depth;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	BACKLIGHT = ALBEDO * backlight;
}
