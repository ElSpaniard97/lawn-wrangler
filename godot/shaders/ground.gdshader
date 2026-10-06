shader_type spatial;
// The lawn's ground: the colour of each cell (tall, light or dark stripe,
// highlighted, or mulch) from a one-pixel-per-cell texture, roughened by a
// photo of grass tiled across the yard. Only the photo's brightness is
// used, so the stripes and highlight keep their own colours.

uniform sampler2D cells : source_color, filter_linear;
uniform sampler2D detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Metres covered by one copy of the detail photo.
uniform float tile = 1.6;
// Average brightness of the photo, so it neither lightens nor darkens.
uniform float detail_mean = 0.169;
uniform float strength = 0.75;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(cells, UV).rgb;
	float brightness = dot(texture(detail, world_position.xz / tile).rgb, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = base * clamp(mix(1.0, brightness / detail_mean, strength), 0.3, 2.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
