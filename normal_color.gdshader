shader_type spatial;
render_mode unshaded, ambient_light_disabled;

varying vec3 n;
void vertex() {
	n = 0.5 + VERTEX;
}

void fragment() {
	ALBEDO = n;
}
