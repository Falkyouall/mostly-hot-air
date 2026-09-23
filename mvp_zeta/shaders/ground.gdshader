shader_type spatial;
// Miniature landscape far below the basket: teal water, sand rim, mottled
// grass, forest patches and striped fields. `map` is baked by world.gd from
// the same height function that gameplay uses (R = height, 0.5 = sea level).

uniform sampler2D map : filter_linear, repeat_disable;
uniform vec2 world_min;
uniform vec2 world_size;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (wpos.xz - world_min) / world_size;
	vec4 m = texture(map, uv);
	float detail = vnoise(wpos.xz * 0.06) * 0.6 + vnoise(wpos.xz * 0.19) * 0.4;
	float h = (m.r * 2.0 - 1.0) + (detail - 0.5) * 0.05;

	vec3 deep = vec3(0.09, 0.40, 0.52);
	vec3 shallow = vec3(0.22, 0.66, 0.70);
	vec3 sand = vec3(0.87, 0.80, 0.60);
	vec3 grass_a = vec3(0.45, 0.66, 0.31);
	vec3 grass_b = vec3(0.33, 0.55, 0.28);
	vec3 forest = vec3(0.20, 0.41, 0.26);

	vec3 land = mix(grass_a, grass_b, smoothstep(0.35, 0.65, detail));
	land = mix(land, forest, smoothstep(0.55, 0.75, m.g));

	// Patchwork fields on open grass.
	vec2 cell = floor(wpos.xz / 46.0);
	float fh = hash(cell);
	vec2 cuv = fract(wpos.xz / 46.0);
	float inset = step(0.08, cuv.x) * step(cuv.x, 0.92) * step(0.08, cuv.y) * step(cuv.y, 0.92);
	if (fh > 0.72 && m.g < 0.5 && h > 0.08) {
		float dir = step(0.5, hash(cell + 7.0));
		float stripes = step(0.5, fract(mix(wpos.x, wpos.z, dir) / 5.0));
		vec3 field = mix(vec3(0.80, 0.72, 0.36), vec3(0.70, 0.60, 0.30), stripes);
		if (fh > 0.88) {
			field = mix(vec3(0.58, 0.72, 0.30), vec3(0.50, 0.64, 0.27), stripes);
		}
		land = mix(land, field, inset);
	}

	vec3 water = mix(shallow, deep, smoothstep(0.0, 0.25, -h));
	float foam = smoothstep(0.035, 0.0, abs(h + 0.012)) * (0.6 + 0.4 * sin(TIME * 1.5 + detail * 20.0));
	water = mix(water, vec3(0.92, 0.97, 0.97), foam * 0.7);

	vec3 col = mix(water, sand, smoothstep(-0.005, 0.01, h));
	col = mix(col, land, smoothstep(0.03, 0.07, h));

	ALBEDO = col;
	ROUGHNESS = mix(0.25, 0.95, smoothstep(-0.01, 0.02, h));
	SPECULAR = 0.3;
}
