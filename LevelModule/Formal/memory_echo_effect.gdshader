// memory_echo_effect.gdshader - 记忆光团扭曲闪烁特效
// 2层噪声扭曲 + 不规则闪烁 + 亮度增强
shader_type canvas_item;

uniform float distort_strength : hint_range(0.0, 1.0) = 0.4;
uniform float distort_speed : hint_range(0.0, 10.0) = 2.5;
uniform float distort_freq : hint_range(1.0, 30.0) = 8.0;
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float flicker_speed : hint_range(0.5, 20.0) = 6.0;
uniform float brightness : hint_range(0.0, 1.0) = 0.3;
uniform vec4 tint_color : source_color = vec4(1.0, 0.85, 0.35, 1.0);

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	// ---- 2层噪声扭曲（直接调制亮度，无UV偏移）----
	float noise1 = hash2(UV * distort_freq + TIME * distort_speed * 0.7);
	float noise2 = hash2(UV * distort_freq * 2.3 + TIME * distort_speed * 1.3);
	float distort = (noise1 * 0.65 + noise2 * 0.35);
	// 扭曲映射为亮度波动
	float distort_mod = 1.0 + (distort - 0.5) * distort_strength;

	vec4 tex_color = texture(TEXTURE, UV);

	// ---- 不规则闪烁（4层叠加）----
	float flicker = 1.0
		- flicker_intensity * 0.35 * (sin(TIME * flicker_speed * 1.7) * 0.5 + 0.5)
		- flicker_intensity * 0.25 * (hash(floor(TIME * flicker_speed * 0.3)) * 0.5 + 0.5)
		- flicker_intensity * 0.2 * abs(sin(TIME * flicker_speed * 3.1))
		- flicker_intensity * 0.2 * (hash(floor(TIME * flicker_speed * 0.7 + 13.0)) * 0.5 + 0.5);
	flicker = clamp(flicker, 0.05, 1.0);

	// ---- 亮度增强（呼吸式脉动，1.0~4.0）----
	float brightness_mod = 1.0 + 3.0 * brightness * (sin(TIME * 1.8) * 0.5 + 0.5);

	vec3 final_rgb = tex_color.rgb * tint_color.rgb * flicker * distort_mod * brightness_mod;
	float final_alpha = tex_color.a * tint_color.a;

	COLOR = vec4(final_rgb, final_alpha);
}
