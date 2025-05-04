shader_type canvas_item;

void fragment() {
	if (length(COLOR.rgb) < 0.15 ) {
		COLOR.rgb = vec3(0.0, 0.8, 0.8);
	}
}
