shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// 4x4 RGBA flipbook; kept opt-in until an atlas has been approved.
uniform sampler2D flipbook_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float frame_index : hint_range(0.0, 15.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.72, 0.3, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.0;

void fragment() {
    float frame = floor(clamp(frame_index, 0.0, 15.0));
    vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0));
    vec2 atlas_uv = (clamp(UV, vec2(0.001), vec2(0.999)) + cell) / 4.0;
    vec4 sample_color = texture(flipbook_atlas, atlas_uv);
    ALBEDO = sample_color.rgb * tint.rgb;
    EMISSION = sample_color.rgb * tint.rgb * intensity;
    ALPHA = sample_color.a * tint.a;
}
