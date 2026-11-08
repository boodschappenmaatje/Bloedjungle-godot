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
uniform float detail_mip_bias : hint_range(0.0, 2.0) = 0.05;
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
	// World-space texture warp breaks long, obvious repeat seams without extra
	// texture fetches. The two slow noise fields already used for the terrain mask
	// also bend all ground maps together, preserving their PBR registration.
	vec2 uv_warp = (vec2(n1,n2)-0.5)*0.18;
	// Keep photographed grass blades, leaf litter and trail aggregate large enough
	// to resolve from the tactical camera. Derivative-gated micro breakup and
	// mipmapping fade this larger grain before it can shimmer in the distance.
	// Tighter world tiling keeps the grass and floor litter from averaging into a
	// broad painted wash at the tactical camera. Mipmapping still filters distant detail.
	vec2 guv = p * 0.30 + uv_warp;
	vec2 juv = p * 0.32 + vec2(0.37,-0.21) + uv_warp;
	vec2 duv = p * 0.29 + uv_warp;
	vec2 muv = vec2(p.y, -p.x) * 0.30 + vec2(uv_warp.x,-uv_warp.y);
	vec2 moss_uv = p * 0.29 + uv_warp;
	// Keep trail stone and crushed grit visible at the fixed combat-camera scale.
	vec2 gravel_uv = p * 0.34 + uv_warp;
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
	// Bring photographed litter into the clearings instead of letting grass dominate
	// almost every pixel. This reuses the texture reads already needed by the terrain.
	float floor_mix = smoothstep(0.17, 0.64, n1 * 0.34 + n2 * 0.50 + n3 * 0.16) * 0.90;
	// Shift the broad floor away from the former yellow wash while keeping the
	// source atlas's fine blades legible after mobile mip filtering.
	vec3 grass = mix(g * vec3(0.70,0.70,0.62), j * vec3(0.76,0.76,0.68), floor_mix);
	// Keep the canopy floor cool/neutral. Small shifts among olive, leaf litter,
	// and shaded soil give the clearing material depth without a global warm grade.
	grass *= mix(vec3(0.97,1.00,0.96),vec3(0.91,0.96,0.92),smoothstep(0.28,0.72,n1));
	grass *= (0.76 + 0.48*n3) * mix(1.0,0.88+0.24*n_micro,micro_gate*0.72);
	float litter_breakup = smoothstep(0.50,0.78,n1*0.56+n2*0.31+n3*0.13) * (1.0-floor_mix*0.30);
	grass = mix(grass,j*vec3(0.79,0.78,0.69),litter_breakup*0.23);
	float inside = 1.0 - smoothstep(compound-0.5,compound+3.0,max(abs(p.x),abs(p.y)));
	float path = (1.0-smoothstep(gate_gap*0.88,gate_gap*1.86+n2*1.7,abs(p.x)+(n3-0.5)*0.24))
		* smoothstep(compound-2.0,compound+1.5,abs(p.y))*(1.0-smoothstep(30.0,52.0,abs(p.y)));
	float pt = clamp((-30.0-p.y)/60.2,0.0,1.0);
	float ptx = 12.0*sin(pt*9.6)*sin(pt*3.14159265);
	float side = abs(p.x-ptx);
	float road_active = step(0.001,pt)*step(pt,0.999);
	// Irregular, softly eroded trail edges combine metre-scale breakup with a
	// filtered sub-metre wobble. Keep the centerline and collision route unchanged.
	float trail_edge = side + (n2-0.5)*0.56 + (n3-0.5)*0.34;
	float trail = (1.0-smoothstep(0.96,1.98+n2*0.34,trail_edge))*road_active;
	float trail_shoulder = (1.0-smoothstep(1.45,3.10+n2*0.48,trail_edge))*road_active;
	float bank = 1.0-smoothstep(2.9,5.0+n2*1.6,river_off);
	float swamp = (1.0-smoothstep(-38.0,-22.0,p.x+n2*6.0))*(1.0-smoothstep(-70.0,-40.0,p.y))*smoothstep(-84.0,-70.0,p.y);
	swamp *= 1.0-smoothstep(0.0,2.0,river_off-3.0);
	// Dirt stays in broken, occasional patches. The earlier wide mask left broad bare
	// fields that visually swallowed the short grass and understory.
	float patches = smoothstep(0.43,0.77,n1*0.27+n2*0.43+n3*0.30);
	float dm = clamp(max(max(inside,path),max(patches*0.80,max(bank,max(swamp*0.9,trail)))),0.0,1.0);
	dm = smoothstep(0.07,0.79,dm+(n3-0.5)*0.25+(n1-0.5)*0.07);
	// Two broken wheel/walk ruts remain readable through the pebble layer, but
	// their uneven edges follow the existing path noise instead of drawing rails.
	float rut_a = 1.0-smoothstep(0.10,0.34,abs(side-0.56+(n2-0.5)*0.14+(n3-0.5)*0.10));
	float rut_b = 1.0-smoothstep(0.12,0.38,abs(side-1.04+(n3-0.5)*0.17));
	float rut = max(rut_a*0.78,rut_b)*road_active*trail;
	float puddle_noise = smoothstep(0.73,0.90,n_micro)*micro_gate*trail;
	float wet = max(bank*0.65,max(swamp,max(rut*smoothstep(0.43,0.63,n2),puddle_noise*0.72)));
	wet = clamp(wet+trail*smoothstep(0.67,0.8,n2)*0.65,0.0,1.0);
	// Gravel follows the established path and its worn shoulders, with broken edges from the existing macro noise.
	float gravel_mix = clamp(max(max(path*0.92,trail*0.94)*mix(0.38,1.0,smoothstep(0.16,0.78,n2)),trail_shoulder*0.28),0.0,0.95);
	vec3 dirt = d*vec3(0.82,0.76,0.67)*(0.91+0.18*n3);
	dirt = mix(dirt,gravel*vec3(1.20,1.16,1.08),gravel_mix*0.94);
	float pebble_speckle = smoothstep(0.68,0.87,n_micro)*micro_gate*gravel_mix;
	dirt = mix(dirt,gravel*vec3(1.30,1.20,1.03),pebble_speckle*0.70);
	dirt *= 1.0-rut*0.31;
	dirt = mix(dirt,m*vec3(0.64,0.59,0.52),wet*0.54);
	float edge = 4.0*dm*(1.0-dm);
	float moss_mask = smoothstep(0.53,0.77,n1*0.58+n2*0.42);
	float moss_mix = clamp(edge*0.34+bank*(1.0-wet)*0.22+moss_mask*(1.0-dm)*0.24+trail_shoulder*0.08,0.0,0.52);
	vec3 base = mix(grass,dirt,dm);
	ALBEDO = mix(base,moss*vec3(0.45,0.58,0.40),moss_mix);
	// Keep close grass and earth from averaging into a painted field. The
	// derivative gate fades this fine material grain before it can shimmer at distance.
	ALBEDO *= 0.88 + 0.24 * n_micro * micro_gate;
	vec4 earth_surface = mix(ds,grs,gravel_mix*0.90);
	vec4 surf = mix(mix(gs,js,floor_mix),mix(earth_surface,ms,wet*0.55),dm);
	surf = mix(surf,mos,moss_mix);
	ROUGHNESS = clamp(mix(0.94,mix(0.79,0.97,surf.a),dm)-wet*(0.20+0.16*puddle_noise),0.48,1.0);
	// Restrained dielectric response; broaden specular at subpixel normal scales.
	ROUGHNESS = mix(max(ROUGHNESS,0.86),ROUGHNESS,micro_detail);
	SPECULAR = mix(0.12,0.25,dm);
	NORMAL_MAP = surf.rgb;
	NORMAL_MAP_DEPTH = mix(1.02,1.42,dm)*micro_detail;
	AO = 1.0-0.19*(1.0-dm)*n3;
	AO_LIGHT_AFFECT = 0.20;
}
