shader_type canvas_item;
// The round minimap: a window onto the lawn texture centred on the mower,
// with the house roof drawn over it and the fence and neighbours' grass
// outside the lot. Everything outside the circle is transparent.

uniform vec2 center = vec2(0.5);
// How much of the map, as fractions across it, fits across the circle.
uniform vec2 span = vec2(1.0);
// The house roof as fractions across the map: left, top, right, bottom.
uniform vec4 roof = vec4(0.0);
// The lawn texture is darker than the lit ground looks.
uniform float brightness = 1.7;

void fragment() {
	vec2 offset = UV - 0.5;
	vec2 map = center + offset * span;
	vec3 color;
	if (map.x < 0.0 || map.y < 0.0 || map.x > 1.0 || map.y > 1.0) {
		vec2 beyond = max(max(-map, map - 1.0), vec2(0.0)) / span;
		color = max(beyond.x, beyond.y) < 0.012 ? vec3(0.58, 0.40, 0.24) : vec3(0.17, 0.27, 0.12);
	} else {
		color = texture(TEXTURE, map).rgb * brightness;
		if (map.x > roof.x && map.x < roof.z && map.y > roof.y && map.y < roof.w) {
			float ridge = abs(map.x - (roof.x + roof.z) * 0.5) / span.x;
			color = ridge < 0.006 ? vec3(0.42, 0.42, 0.45) : vec3(0.66, 0.66, 0.68);
		}
	}
	COLOR = vec4(color, smoothstep(0.5, 0.49, length(offset)));
}
