shader_type spatial;
// Red/cream gores like the moodboard envelope.

uniform float gores = 20.0;
uniform vec3 col_a : source_color = vec3(0.84, 0.30, 0.20);
uniform vec3 col_b : source_color = vec3(0.97, 0.93, 0.85);
uniform float glow = 0.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float a = atan(lpos.z, lpos.x) / TAU + 0.5;
	float s = step(0.5, fract(a * gores * 0.5));
	vec3 col = mix(col_a, col_b, s);
	// Seam shading between gores.
	float seam = abs(fract(a * gores) - 0.5) * 2.0;
	col *= mix(0.86, 1.0, smoothstep(0.0, 0.25, 1.0 - seam));
	ALBEDO = col;
	ROUGHNESS = 0.8;
	// Burner light shining through the fabric from below.
	// The camera only ever sees the shaded underside; lift it so the stripes
	// stay red/cream instead of going grey.
	EMISSION = col * 0.28 + vec3(1.0, 0.55, 0.2) * glow * smoothstep(0.2, -1.0, lpos.y) * 0.6;
}
