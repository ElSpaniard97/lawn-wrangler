// Summer sky: deep blue overhead fading to a pale horizon, a soft sun glow,
// and fair-weather clouds made from layered value noise. The clouds stay
// still, so the sky's lighting is only worked out once. No textures are used.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.16, 0.40, 0.84);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.82, 0.93);
uniform vec3 ground_color : source_color = vec3(0.30, 0.38, 0.26);
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.68, 0.74, 0.84);
uniform float cloud_cover = 0.48;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += amplitude * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		amplitude *= 0.5;
	}
	return sum;
}

void sky() {
	float up = EYEDIR.y;
	vec3 color = mix(horizon_color, top_color, pow(clamp(up, 0.0, 1.0), 0.45));
	if (up < 0.0) {
		color = mix(horizon_color, ground_color, clamp(-up * 4.0, 0.0, 1.0));
	}
	vec3 sun_dir = LIGHT0_DIRECTION;
	float sun = max(dot(EYEDIR, sun_dir), 0.0);
	color += LIGHT0_COLOR * (pow(sun, 600.0) * 4.0 + pow(sun, 12.0) * 0.12);
	if (up > 0.02 && !AT_CUBEMAP_PASS) {
		// Project onto a flat cloud layer so clouds shrink towards the horizon.
		vec2 layer = EYEDIR.xz / (up + 0.08) * 1.6;
		float n = fbm(layer);
		float density = smoothstep(cloud_cover, cloud_cover + 0.25, n);
		float lit = smoothstep(cloud_cover, cloud_cover + 0.4, fbm(layer + sun_dir.xz * 0.06));
		vec3 cloud = mix(cloud_color, cloud_shade, lit * 0.8);
		color = mix(color, cloud, density * smoothstep(0.02, 0.2, up) * 0.95);
	}
	COLOR = color;
}
