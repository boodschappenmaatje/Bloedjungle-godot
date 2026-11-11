shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Wapeneffecten AAA: 4x4 vlam-flipbook (bron/wapenfx/maak_wapenfx.py). Het loopeinde zit bovenaan in het midden van elk beeld.
uniform sampler2D flipbook_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float frame_index : hint_range(0.0, 15.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 4.0) = 1.4;
uniform vec3 tint : source_color = vec3(1.0, 0.88, 0.66);

void fragment() {
	float frame = floor(clamp(frame_index, 0.0, 15.0));
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0));
	vec2 atlas_uv = (clamp(UV, vec2(0.002), vec2(0.998)) + cell) / 4.0;
	vec4 c = texture(flipbook_atlas, atlas_uv);
	ALBEDO = c.rgb * tint * c.a;
	EMISSION = c.rgb * tint * intensity * c.a;
	ALPHA = c.a;
}
