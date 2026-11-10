shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Graphics 2.0: lichtbundel tussen de bomen. Een smal vlak langs de zonnestraal dat om zijn as naar de camera draait.
// Geen volumetrisch licht (dat kan de mobiele renderer niet): één optelling per pixel, één ruismonster.

uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0, 0.82, 0.5);
uniform float strength = 0.2;
uniform vec3 sun_dir = vec3(0.5, -0.5, 0.5);  // richting waarin het licht reist (genormaliseerd)

varying float shimmer;

void vertex() {
	// VERTEX.x = -0.5..0.5 dwars, VERTEX.y = 0 (grond) .. 1 (boven); INSTANCE_CUSTOM: x breedte, y lengte, z fase
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 axis = -normalize(sun_dir);
	vec3 centre = base + axis * INSTANCE_CUSTOM.y * 0.5;
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - centre);
	vec3 side = normalize(cross(axis, to_cam));
	vec3 world = base + axis * (VERTEX.y * INSTANCE_CUSTOM.y) + side * (VERTEX.x * INSTANCE_CUSTOM.x);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
	shimmer = INSTANCE_CUSTOM.z;
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	across = across * across * (3.0 - 2.0 * across);
	// boven uitlopend (bladerdak), bij de grond zacht weg
	float along = smoothstep(0.0, 0.22, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float n = texture(noise, vec2(UV.x * 0.9 + shimmer, UV.y * 0.25 + TIME * 0.012 + shimmer * 3.0)).r;
	float streak = 0.55 + 0.9 * n;
	ALBEDO = tint * across * along * streak * strength;
}
