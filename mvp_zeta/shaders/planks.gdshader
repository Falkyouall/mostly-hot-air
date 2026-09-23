shader_type spatial;
// Basket floor: warm herringbone-ish planks.

varying vec3 lpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec2 p = lpos.xz / 0.62;
	vec2 cell = floor(p);
	float flip = mod(cell.x + cell.y, 2.0);
	vec2 f = fract(p);
	float along = mix(f.x, f.y, flip);
	float plank = floor(along * 3.0);
	float tone = hash(cell * 3.0 + plank);
	vec3 col = mix(vec3(0.62, 0.40, 0.22), vec3(0.78, 0.55, 0.32), tone);
	float gap = smoothstep(0.0, 0.06, fract(along * 3.0)) * smoothstep(0.0, 0.03, min(f.x, f.y));
	ALBEDO = col * mix(0.55, 1.0, gap);
	ROUGHNESS = 0.85;
}
