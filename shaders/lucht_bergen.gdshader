shader_type sky;
// Lucht met verre bergen (dambreuk-plan stap 1, keuze 3B): dezelfde hemel als de vroegere ProceduralSkyMaterial
// (boven, horizon, grond, zon) plus twee lagen bergsilhouetten op de horizon. Die staan "oneindig" ver weg en zijn dus ook
// in third person (zichtafstand 60 m) te zien, waar het echte bergland (scripts/bergland.gd) achter de mist valt.
// Alleen wiskunde per pixel van de lucht: geen texturen, geen extra tekenopdrachten.

uniform vec3 sky_top_color : source_color = vec3(0.337, 0.439, 0.478);
uniform vec3 sky_horizon_color : source_color = vec3(0.639, 0.69, 0.604);
uniform vec3 ground_horizon_color : source_color = vec3(0.557, 0.612, 0.502);
uniform vec3 ground_bottom_color : source_color = vec3(0.165, 0.22, 0.125);
uniform float sky_curve = 0.18;
uniform float ground_curve = 0.02;
uniform float sun_angle_max = 25.0;   // graden
uniform float sun_curve = 0.15;
uniform float mountains = 1.0;        // 0 = zonder bergen (Klassiek)
uniform vec3 far_tint : source_color = vec3(0.52, 0.6, 0.64);     // verste rij: blauwig door de lucht ervoor
uniform vec3 near_tint : source_color = vec3(0.22, 0.3, 0.2);     // dichtere rij: beboste ruggen

// golvende ruglijn uit een paar sinussen (deterministisch, geen ruistextuur nodig)
float ridge(float a, float s) {
	float h = 0.0;
	h += 0.50 * sin(a * 3.0 + s);
	h += 0.28 * sin(a * 7.0 + s * 2.3);
	h += 0.16 * abs(sin(a * 17.0 + s * 4.1));
	h += 0.07 * abs(sin(a * 41.0 + s * 1.7));
	return h * 0.5 + 0.5;
}

void sky() {
	float v_angle = acos(clamp(EYEDIR.y, -1.0, 1.0));
	float c = 1.0 - v_angle / (PI * 0.5);
	vec3 sky = mix(sky_horizon_color, sky_top_color, clamp(1.0 - pow(1.0 - c, 1.0 / sky_curve), 0.0, 1.0));
	if (LIGHT0_ENABLED) {
		float sun_angle = acos(clamp(dot(LIGHT0_DIRECTION, EYEDIR), -1.0, 1.0));
		float smax = radians(sun_angle_max);
		if (sun_angle < LIGHT0_SIZE) {
			sky = LIGHT0_COLOR * LIGHT0_ENERGY;
		} else if (sun_angle < smax) {
			float c2 = (sun_angle - LIGHT0_SIZE) / (smax - LIGHT0_SIZE);
			sky = mix(LIGHT0_COLOR * LIGHT0_ENERGY, sky, clamp(1.0 - pow(1.0 - c2, 1.0 / sun_curve), 0.0, 1.0));
		}
	}
	float cg = (v_angle - PI * 0.5) / (PI * 0.5);
	vec3 ground = mix(ground_horizon_color, ground_bottom_color, clamp(1.0 - pow(1.0 - clamp(cg, 0.0, 1.0), 1.0 / ground_curve), 0.0, 1.0));
	vec3 col = mix(ground, sky, step(0.0, EYEDIR.y));
	if (mountains > 0.0 && !AT_CUBEMAP_PASS) {
		// onder de horizon (voorbij de zichtafstand van de camera): heiig in plaats van een donkere band, zodat het bergland
		// en de grondplaat in de verte in de nevel overlopen; de belichting (cubemap) houdt de oude grondkleur
		col = mix(col, mix(sky_horizon_color, near_tint, 0.35), (1.0 - step(0.0, EYEDIR.y)) * 0.9);
		float el = asin(clamp(EYEDIR.y, -1.0, 1.0));
		float az = atan(EYEDIR.x, EYEDIR.z);
		// verste rij: hoog en blauwig
		float h1 = 0.028 + 0.055 * ridge(az, 1.3);
		float m1 = smoothstep(h1 + 0.002, h1 - 0.002, el);
		vec3 far_c = mix(sky_horizon_color, far_tint * (sky_horizon_color * 1.1), 0.7);
		// dichtere rij: lager, donkerder en groener, met mist aan de voet
		float h2 = 0.012 + 0.04 * ridge(az * 1.6, 4.7);
		float m2 = smoothstep(h2 + 0.0015, h2 - 0.0015, el);
		vec3 near_c = mix(sky_horizon_color, near_tint, 0.75);
		near_c = mix(near_c, sky_horizon_color, smoothstep(h2, -0.01, el) * 0.55);   // nevel in de dalen ervoor
		far_c = mix(far_c, sky_horizon_color, smoothstep(h1, 0.0, el) * 0.35);
		col = mix(col, far_c, m1 * mountains * step(-0.02, el));
		col = mix(col, near_c, m2 * mountains * step(-0.02, el));
	}
	COLOR = col;
}
