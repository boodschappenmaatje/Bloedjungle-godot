shader_type spatial;
// Five coherent photographic PBR layers. Geometry/collision and cut-out contracts stay unchanged.
// RGB surface data is OpenGL normal; alpha stores real roughness. Twelve samplers total.
uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
uniform sampler2D earth_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D gravel_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D mud_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D litter_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D earth_surface : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D gravel_surface : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D mud_surface : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_surface : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D litter_surface : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float normal_strength : hint_range(0.0, 1.5) = 0.72;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float earth_gain : hint_range(0.1, 1.0) = 0.60;
uniform float vegetation_gain : hint_range(0.1, 1.0) = 0.48;
uniform float compound = 14.0;
uniform float gate_gap = 2.4;
uniform vec4 pits[8];  // loopgraven: x, z, cos, sin
uniform int pit_n = 0;
uniform vec4 pad = vec4(0.0, 0.0, 1.0, 0.0);  // schacht van het helikopterplatform: x, z, cos, sin
uniform float pad_half = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	// de rivier is uit de grond gesneden (scripts/river.gd legt de bedding eronder; zelfde formule als Data.river_z)
	float river_off = abs(p.y - (-92.0 + 5.0 * sin(p.x * 0.06) + 2.0 * sin(p.x * 0.15 + 1.0)));
	if (river_off < 2.6) {
		discard;
	}
	for (int i = 0; i < pit_n; i++) {
		vec2 r = p - pits[i].xy;
		float lx = r.x * pits[i].z - r.y * pits[i].w;
		float lz = r.x * pits[i].w + r.y * pits[i].z;
		if (abs(lx) < 2.36 && abs(lz) < 0.66) {
			discard;
		}
	}
	if (pad_half > 0.0) {
		vec2 q = p - pad.xy;
		float qx = q.x * pad.z - q.y * pad.w;
		float qz = q.x * pad.w + q.y * pad.z;
		if (abs(qx) < pad_half && abs(qz) < pad_half) {
			discard;
		}
	}
	float macro = texture(noise_a, p * 0.014 + vec2(0.21, 0.53)).r;
	float patch = texture(noise_b, p * 0.052 + vec2(0.13, 0.7)).r;
	float breakup = texture(noise_b, p * 0.28).r;
	float box = max(abs(p.x), abs(p.y));
	float inside = 1.0 - smoothstep(compound - 0.5, compound + 3.0, box);
	float path = (1.0 - smoothstep(gate_gap * 0.9, gate_gap * 1.9 + patch * 1.6, abs(p.x)))
		* smoothstep(compound - 2.0, compound + 1.5, abs(p.y))
		* (1.0 - smoothstep(30.0, 52.0, abs(p.y)));
	float pt = clamp((-30.0 - p.y) / 60.2, 0.0, 1.0);
	float ptx = 12.0 * sin(pt * 9.6) * sin(pt * 3.14159265);
	float trail = (1.0 - smoothstep(1.4, 3.0 + patch * 1.4, abs(p.x - ptx)))
		* step(0.001, pt) * step(pt, 0.999);
	float bank = 1.0 - smoothstep(2.9, 6.2, river_off);
	float swamp = (1.0 - smoothstep(-38.0, -22.0, p.x + patch * 6.0))
		* (1.0 - smoothstep(-70.0, -40.0, p.y)) * smoothstep(-84.0, -70.0, p.y);
	swamp *= 1.0 - smoothstep(0.0, 2.0, river_off - 3.0);
	float clearing = smoothstep(0.63, 0.82, macro + patch * 0.13);
	float earth_mask = clamp(max(max(inside, path), max(trail, max(bank, clearing * 0.8))), 0.0, 1.0);
	earth_mask = smoothstep(0.10, 0.92, earth_mask + (breakup - 0.5) * 0.18);

	// Dry compacted centre, gravel at path shoulders, damp pockets at river and low spots.
	// Track layout follows the existing gates/forest path. No marks cross arbitrary jungle.
	float tracks = (1.0 - smoothstep(0.20, 0.40, abs(abs(p.x) - 0.78)))
		* path * (1.0 - smoothstep(28.0, 42.0, abs(p.y)));
	float forest_tracks = (1.0 - smoothstep(0.16, 0.34, abs(abs(p.x - ptx) - 0.62))) * trail;
	tracks = max(tracks, forest_tracks * 0.65);
	float shoulder = 4.0 * earth_mask * (1.0 - earth_mask);
	float damp = max(bank * 0.8, swamp * 0.9);
	damp = max(damp, inside * smoothstep(0.65, 0.85, macro) * 0.28);
	damp = max(damp, tracks * (0.18 + wetness * 0.30));
	float mud_weight = earth_mask * clamp(damp + wetness * 0.13, 0.0, 0.88);
	float gravel_weight = (earth_mask - mud_weight) * clamp(shoulder * 0.32 + smoothstep(0.52, 0.76, patch) * 0.28, 0.0, 0.45);
	float earth_weight = max(0.0, earth_mask - gravel_weight - mud_weight);
	float litter_weight = (1.0 - earth_mask) * smoothstep(0.30, 0.72, macro + (patch - 0.5) * 0.2);
	float grass_weight = max(0.0, 1.0 - earth_mask - litter_weight);

	vec2 earth_uv = p * 0.24;
	vec2 gravel_uv = p * 0.34 + vec2(0.31, 0.67);
	vec2 mud_uv = p * 0.16 + vec2(0.17, 0.41);
	vec2 grass_uv = p * 0.32;
	vec2 litter_uv = p * 0.25 + vec2(0.37, 0.11);
	// Calibrated under the existing game sun, rather than bright studio lighting.
	vec3 earth = texture(earth_tex, earth_uv).rgb * earth_gain;
	vec3 gravel = texture(gravel_tex, gravel_uv).rgb * earth_gain;
	vec3 mud = texture(mud_tex, mud_uv).rgb * 0.72;
	vec3 grass = texture(grass_tex, grass_uv).rgb * vegetation_gain * vec3(0.85, 1.0, 0.88);
	vec3 litter = texture(litter_tex, litter_uv).rgb * vegetation_gain;
	vec3 color = earth * earth_weight + gravel * gravel_weight + mud * mud_weight
		+ grass * grass_weight + litter * litter_weight;
	// Broad, quiet variation replaces uniform micro-noise. Marks never alter collision or height.
	color *= mix(0.84, 1.10, macro);
	color *= 1.0 - tracks * 0.12;
	color *= 1.0 - wetness * earth_mask * 0.10;
	ALBEDO = color;

	vec4 es = texture(earth_surface, earth_uv);
	vec4 gs = texture(gravel_surface, gravel_uv);
	vec4 ms = texture(mud_surface, mud_uv);
	vec4 vs = texture(grass_surface, grass_uv);
	vec4 ls = texture(litter_surface, litter_uv);
	vec4 surface = es * earth_weight + gs * gravel_weight + ms * mud_weight
		+ vs * grass_weight + ls * litter_weight;
	ROUGHNESS = clamp(surface.a - wetness * earth_mask * 0.16, 0.28, 0.98);
	SPECULAR = 0.35;
	METALLIC = 0.0;
	NORMAL_MAP = normalize(surface.rgb * 2.0 - 1.0) * 0.5 + 0.5;
	float near_detail = 1.0 - smoothstep(24.0, 65.0, distance(CAMERA_POSITION_WORLD, wpos));
	NORMAL_MAP_DEPTH = normal_strength * mix(0.35, 1.0, near_detail);
}
