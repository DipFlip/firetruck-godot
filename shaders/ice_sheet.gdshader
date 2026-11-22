shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform sampler2D ice_mask : filter_linear, repeat_disable;

varying vec2 world_xz;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = noise(p) * 0.55;
	v += noise(p * 2.13 + vec2(11.7, 5.3)) * 0.30;
	v += noise(p * 4.41 + vec2(3.2, 19.8)) * 0.15;
	return v;
}

void vertex() {
	world_xz = VERTEX.xz;
}

void fragment() {
	float m = texture(ice_mask, UV).r;
	if (m < 0.015) discard;

	float shore_wave = (fbm(world_xz * 0.42) - 0.5) * 0.19 * smoothstep(0.02, 0.42, m);
	float v = m + shore_wave;
	float edge = smoothstep(0.20, 0.31, v);
	if (edge < 0.01) discard;

	float rim = smoothstep(0.20, 0.30, v) * (1.0 - smoothstep(0.34, 0.52, v));
	float core = smoothstep(0.30, 0.78, v);
	float sparkle = smoothstep(0.60, 0.88, fbm(world_xz * 1.65 + vec2(4.2, 9.1)));

	vec3 shallow_col = vec3(0.84, 0.95, 1.0);
	vec3 deep_col = vec3(0.56, 0.86, 0.98);
	vec3 frost_rim = vec3(0.95, 0.99, 1.0);
	vec3 col = mix(shallow_col, deep_col, core);
	col = mix(col, frost_rim, rim * 0.65 + sparkle * 0.18);

	ALBEDO = col;
	ROUGHNESS = mix(0.30, 0.06, core);
	METALLIC = 0.06;
	SPECULAR = 0.94;
	CLEARCOAT = mix(0.40, 0.96, core);
	CLEARCOAT_ROUGHNESS = 0.07;
	ALPHA = edge * mix(0.66, 0.88, core);
}
