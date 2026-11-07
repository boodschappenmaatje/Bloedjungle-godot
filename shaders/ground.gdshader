shader_type spatial;
render_mode diffuse_burley;
// Visual B: world-anchored PBR. RGB+A surface maps reuse normal/roughness sources.
// No parallax or displacement; geometric/collision contracts and holes stay intact.
uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D jungle_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D mud_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D moss_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D gravel_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D dirt_normal : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_surface : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D jungle_surface : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D mud_surface : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D moss_surface : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D gravel_surface : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float detail_mip_bias : hint_range(0.0, 2.0) = 0.10;
uniform float compound = 14.0;
uniform float gate_gap = 2.4;
uniform vec4 pits[8];
uniform int pit_n = 0;
uniform vec4 pad = vec4(0.0, 0.0, 1.0, 0.0);
uniform float pad_half = 0.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	float pixel_span = max(length(dFdx(p)), length(dFdy(p)));
	float micro_detail = 1.0 - smoothstep(0.04, 0.24, pixel_span);
	float river_off = abs(p.y - (-92.0 + 5.0 * sin(p.x * 0.06) + 2.0 * sin(p.x * 0.15 + 1.0)));
	if (river_off < 2.6) { discard; }
	for (int i = 0; i < pit_n; i++) {
		vec2 r = p - pits[i].xy;
		float lx = r.x * pits[i].z - r.y * pits[i].w;
		float lz = r.x * pits[i].w + r.y * pits[i].z;
		if (abs(lx) < 2.36 && abs(lz) < 0.66) { discard; }
	}
	if (pad_half > 0.0) {
		vec2 q = p - pad.xy;
		float qx = q.x * pad.z - q.y * pad.w;
		float qz = q.x * pad.w + q.y * pad.z;
		if (abs(qx) < pad_half && abs(qz) < pad_half) { discard; }
	}
	float n1 = texture(noise_a, p * 0.025).r;
	float n2 = texture(noise_b, p * 0.09).r;
	float n3 = texture(noise_b, p * 0.48).r;
	// Fine, pixel-gated variation breaks broad painted patches without adding
	// distant subpixel sparkle on the mobile renderer.
	float n_micro = texture(noise_a, p * 1.7).r;
	float micro_gate = 1.0 - smoothstep(0.055, 0.19, pixel_span);
	// Keep the photographed grass, leaf litter and earth at a tighter physical
	// scale so open ground retains small texture structure in the real camera.
	vec2 guv = p * 0.14;
	vec2 juv = p * 0.15 + 0.37;
	vec2 duv = p * 0.16;
	vec2 muv = vec2(p.y, -p.x) * 0.16;
	vec2 moss_uv = p * 0.15;
	// The gravel map's natural pebble size lands around 5–10 cm at this scale,
	// making path aggregate visible without a high-frequency shimmer pattern.
	vec2 gravel_uv = p * 0.42;
	vec3 g = texture(grass_tex, guv, detail_mip_bias).rgb;
	vec3 j = texture(jungle_tex, juv, detail_mip_bias).rgb;
	vec3 d = texture(dirt_tex, duv, detail_mip_bias).rgb;
	vec3 m = texture(mud_tex, muv, detail_mip_bias).rgb;
	vec3 moss = texture(moss_tex, moss_uv, detail_mip_bias).rgb;
	vec3 gravel = texture(gravel_tex, gravel_uv, detail_mip_bias).rgb;
	vec4 gs = texture(grass_surface, guv, detail_mip_bias);
	vec4 js = texture(jungle_surface, juv, detail_mip_bias);
	vec4 ds = texture(dirt_normal, duv, detail_mip_bias);
	vec4 ms = texture(mud_surface, muv, detail_mip_bias);
	// muv=(z,-x): convert this normal into the common ground tangent frame.
	ms.rg = vec2(ms.g,1.0-ms.r);
	vec4 mos = texture(moss_surface, moss_uv, detail_mip_bias);
	vec4 grs = texture(gravel_surface, gravel_uv, detail_mip_bias);
	float floor_mix = smoothstep(0.27, 0.72, n1 * 0.6 + n2 * 0.4) * 0.9;
	// Shift the broad floor away from the former yellow wash while keeping the
	// source atlas's fine blades legible after mobile mip filtering.
	vec3 grass = mix(g * vec3(0.54,0.65,0.47), j * vec3(0.48,0.59,0.43), floor_mix);
	grass *= mix(vec3(0.88,0.88,0.79),vec3(0.77,0.82,0.70),smoothstep(0.3,0.7,n1));
	grass *= (0.82 + 0.34*n3) * mix(1.0,0.86+0.28*n_micro,micro_gate*0.72);
	float inside = 1.0 - smoothstep(compound-0.5,compound+3.0,max(abs(p.x),abs(p.y)));
	float path = (1.0-smoothstep(gate_gap*0.9,gate_gap*1.9+n2*1.6,abs(p.x)))
		* smoothstep(compound-2.0,compound+1.5,abs(p.y))*(1.0-smoothstep(30.0,52.0,abs(p.y)));
	float pt = clamp((-30.0-p.y)/60.2,0.0,1.0);
	float ptx = 12.0*sin(pt*9.6)*sin(pt*3.14159265);
	float side = abs(p.x-ptx);
	float road_active = step(0.001,pt)*step(pt,0.999);
	// Shoulder breakup uses broad noise, with fine edges prefiltered by the pixel footprint.
	float trail = (1.0-smoothstep(0.9,1.9+n2*0.65,side+(n3-0.5)*0.5))*road_active;
	float bank = 1.0-smoothstep(2.9,5.0+n2*1.6,river_off);
	float swamp = (1.0-smoothstep(-38.0,-22.0,p.x+n2*6.0))*(1.0-smoothstep(-70.0,-40.0,p.y))*smoothstep(-84.0,-70.0,p.y);
	swamp *= 1.0-smoothstep(0.0,2.0,river_off-3.0);
	// Dirt stays in broken, occasional patches. The earlier wide mask left broad bare
	// fields that visually swallowed the short grass and understory.
	float patches = smoothstep(0.45,0.76,n1*0.20+n2*0.45+n3*0.35);
	float dm = clamp(max(max(inside,path),max(patches*0.68,max(bank,max(swamp*0.9,trail)))),0.0,1.0);
	dm = smoothstep(0.10,0.78,dm+(n3-0.5)*0.19);
	// Two broken wheel/walk ruts remain readable through the pebble layer, but
	// their uneven edges follow the existing path noise instead of drawing rails.
	float rut_a = 1.0-smoothstep(0.12,0.36,abs(side-0.54+(n2-0.5)*0.14));
	float rut_b = 1.0-smoothstep(0.14,0.39,abs(side-1.02+(n3-0.5)*0.16));
	float rut = max(rut_a*0.78,rut_b)*road_active*trail;
	float puddle_noise = smoothstep(0.73,0.90,n_micro)*micro_gate*trail;
	float wet = max(bank*0.65,max(swamp,max(rut*smoothstep(0.43,0.63,n2),puddle_noise*0.72)));
	wet = clamp(wet+trail*smoothstep(0.67,0.8,n2)*0.65,0.0,1.0);
	// Gravel follows the established path and its worn shoulders, with broken edges from the existing macro noise.
	float gravel_mix = clamp(max(path*0.84,trail*0.82)*mix(0.50,1.0,smoothstep(0.18,0.76,n2)),0.0,0.90);
	vec3 dirt = d*vec3(0.82,0.73,0.61)*(0.9+0.2*n3);
	dirt = mix(dirt,gravel*vec3(0.96,0.89,0.77),gravel_mix*0.92);
	float pebble_speckle = smoothstep(0.68,0.87,n_micro)*micro_gate*gravel_mix;
	dirt = mix(dirt,gravel*vec3(1.02,0.94,0.82),pebble_speckle*0.32);
	dirt *= 1.0-rut*0.30;
	dirt = mix(dirt,m*vec3(0.54,0.47,0.37),wet*0.55);
	float edge = 4.0*dm*(1.0-dm);
	float moss_mix = clamp(edge*0.3+bank*(1.0-wet)*0.2+smoothstep(0.58,0.76,n2)*(1.0-dm)*0.23,0.0,0.45);
	vec3 base = mix(grass,dirt,dm);
	ALBEDO = mix(base,moss*vec3(0.45,0.58,0.40),moss_mix);
	// Keep close grass and earth from averaging into a painted field. The
	// derivative gate fades this fine material grain before it can shimmer at distance.
	ALBEDO *= 0.94 + 0.12 * n_micro * micro_gate;
	vec4 earth_surface = mix(ds,grs,gravel_mix*0.90);
	vec4 surf = mix(mix(gs,js,floor_mix),mix(earth_surface,ms,wet*0.55),dm);
	surf = mix(surf,mos,moss_mix);
	ROUGHNESS = clamp(mix(0.94,mix(0.79,0.97,surf.a),dm)-wet*(0.20+0.16*puddle_noise),0.48,1.0);
	// Restrained dielectric response; broaden specular at subpixel normal scales.
	ROUGHNESS = mix(max(ROUGHNESS,0.86),ROUGHNESS,micro_detail);
	SPECULAR = mix(0.12,0.25,dm);
	NORMAL_MAP = surf.rgb;
	NORMAL_MAP_DEPTH = mix(0.72,0.88,dm)*micro_detail;
	AO = 1.0-0.12*(1.0-dm)*n3;
	AO_LIGHT_AFFECT = 0.12;
}
