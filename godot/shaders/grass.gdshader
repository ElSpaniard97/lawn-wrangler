// Grass clumps. Each MultiMesh instance carries custom data: r = 1 for tall
// grass, 0 for cut stubble. Blades shade from root to tip by height, tall
// grass sways in a slow breeze and turns yellow while the missed-grass
// highlight is on; stubble stays still.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec3 root_color : source_color = vec3(0.13, 0.25, 0.07);
uniform vec3 tip_color : source_color = vec3(0.36, 0.52, 0.17);
uniform float blade_height = 0.3;
uniform float highlight = 0.0;
uniform vec3 highlight_color : source_color = vec3(0.95, 0.78, 0.15);
uniform float sway_strength = 0.05;

varying float tall;
varying float along;

void vertex() {
	tall = INSTANCE_CUSTOM.r;
	along = clamp(VERTEX.y / blade_height, 0.0, 1.0);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float wave = sin(TIME * 1.6 + origin.x * 0.8 + origin.z * 0.55)
		+ 0.5 * sin(TIME * 2.9 + origin.x * 1.7 - origin.z * 1.3);
	float bend = wave * sway_strength * VERTEX.y * 3.0 * tall;
	VERTEX.x += bend;
	VERTEX.z += bend * 0.6;
}

void fragment() {
	vec3 base = mix(root_color, tip_color, along);
	ALBEDO = mix(base, highlight_color * (0.7 + 0.5 * along), highlight * tall);
	ROUGHNESS = 1.0;
}
