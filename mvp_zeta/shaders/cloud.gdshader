shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// Puffy toon clouds. Ways to see through them:
//  - a tunnel along the camera→basket line dithers away, so the crew never
//    vanishes while the balloon crosses the layer,
//  - the Fernrohr rips a hole (GDD §2.3): a cylinder sheared along the view ray.

uniform vec3 light_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 col_light : source_color = vec3(1.0, 0.95, 0.93);
uniform vec3 col_mid : source_color = vec3(0.93, 0.80, 0.82);
uniform vec3 col_shadow : source_color = vec3(0.66, 0.56, 0.68);
uniform vec2 hole_center = vec2(0.0);
uniform vec2 hole_shear = vec2(0.0);
uniform float hole_radius = 0.0;
uniform float near_fade = 14.0;
uniform vec3 focus = vec3(0.0);
uniform float tunnel_radius = 9.0;

varying vec3 wpos;
varying vec3 wnormal;

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float keep = smoothstep(near_fade * 0.45, near_fade, distance(wpos, CAMERA_POSITION_WORLD));
	vec3 to_focus = focus - CAMERA_POSITION_WORLD;
	float along = clamp(dot(wpos - CAMERA_POSITION_WORLD, to_focus) / dot(to_focus, to_focus), 0.0, 1.15);
	float off_axis = length(wpos - (CAMERA_POSITION_WORLD + to_focus * along));
	keep *= smoothstep(tunnel_radius * 0.5, tunnel_radius, off_axis);
	if (hole_radius > 0.5) {
		vec2 p = wpos.xz - hole_center - hole_shear * wpos.y;
		keep *= smoothstep(hole_radius * 0.8, hole_radius, length(p));
	}
	if (keep < ign(FRAGCOORD.xy)) {
		discard;
	}
	float l = dot(normalize(wnormal), normalize(light_dir)) * 0.5 + 0.5;
	vec3 col = mix(col_shadow, col_mid, smoothstep(0.15, 0.5, l));
	col = mix(col, col_light, smoothstep(0.55, 0.85, l));
	ALBEDO = col;
}
