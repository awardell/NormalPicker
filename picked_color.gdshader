shader_type spatial;
render_mode unshaded, ambient_light_disabled;

uniform vec4 picked: source_color;
uniform float n_amt: hint_range(0.0, 1.0, 0.01) = .25;

varying vec3 n;

void vertex() {
	n = NORMAL;
}

void fragment() {
	ALBEDO = picked.rgb * (1. - n_amt + n_amt * step(0.001, n.g));
}
