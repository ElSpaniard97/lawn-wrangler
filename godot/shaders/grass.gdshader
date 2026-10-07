// Grass clumps. Each MultiMesh instance carries custom data: r = 1 for tall
// grass, 0 for cut stubble; g = 1 for stubble on a light stripe. Blades shade from root to tip by height, tall
// grass sways in a slow breeze and turns yellow while the missed-grass
// highlight is on; stubble stays still. UV.x is a random shade per blade.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 root_color : source_color = vec3(0.07, 0.17, 0.03);
uniform vec3 tip_color : source_color = vec3(0.36, 0.55, 0.13);
// Some blades are a drier yellow-green at the tip, some a deeper green.
uniform vec3 dry_tip_color : source_color = vec3(0.52, 0.60, 0.20);
uniform float blade_height = 0.34;
uniform float highlight = 0.0;
uniform vec3 highlight_color : source_color = vec3(0.95, 0.78, 0.15);
uniform float sway_strength = 0.05;
uniform vec3 stripe_light : source_color = vec3(0.21, 0.44, 0.07);
uniform vec3 stripe_dark : source_color = vec3(0.10, 0.25, 0.04);

varying float tall;
varying float along;
varying float light;
varying float shade;

void vertex() {
	tall = INSTANCE_CUSTOM.r;
	light = INSTANCE_CUSTOM.g;
	shade = UV.x;
	along = clamp(VERTEX.y / blade_height, 0.0, 1.0);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float wave = sin(TIME * 1.6 + origin.x * 0.8 + origin.z * 0.55)
		+ 0.5 * sin(TIME * 2.9 + origin.x * 1.7 - origin.z * 1.3);
	float bend = wave * sway_strength * VERTEX.y * 3.0 * tall;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.6;
}

void fragment() {
	vec3 tip = mix(tip_color * (0.8 + 0.3 * shade), dry_tip_color, smoothstep(0.75, 1.0, shade));
	vec3 grown = mix(root_color, tip, along * along * (3.0 - 2.0 * along));
	vec3 stubble = mix(stripe_dark, stripe_light, light) * (0.75 + 0.25 * along) * (0.9 + 0.2 * shade);
	vec3 base = mix(stubble, grown, tall);
	ALBEDO = mix(base, highlight_color * (0.7 + 0.5 * along), highlight * tall);
	ROUGHNESS = 1.0;
}
