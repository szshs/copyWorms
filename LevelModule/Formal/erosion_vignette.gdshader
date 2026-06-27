// res://LevelModule/Formal/erosion_vignette.gdshader
// 侵蚀值 — 连续渐进：轻微色散(0%) → 暗角+紫晕(中段) → 扭曲(高段)
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = uv - 0.5;
	float dist = length(center) * 1.4;

	// ---- 阶段门控：由外部侵蚀百分比连续驱动 ----
	float ca_stage   = smoothstep(0.02, 0.30, intensity);
	float vig_stage  = smoothstep(0.30, 0.65, intensity);
	float warp_stage = smoothstep(0.65, 1.00, intensity);

	// ---- 阶段1: 色散 (chromatic aberration) ----
	float ca_edge = smoothstep(0.35, 0.85, dist) * ca_stage;
	vec4 color = texture(SCREEN_TEXTURE, uv);
	if (ca_edge > 0.0) {
		float ca = ca_edge * mix(0.001, 0.006, intensity);
		color.r = texture(SCREEN_TEXTURE, uv + vec2(ca, 0.0)).r;
		color.b = texture(SCREEN_TEXTURE, uv - vec2(ca, 0.0)).b;
	}

	// ---- 阶段2: 暗角 + 紫晕 ----
	float vig_edge = smoothstep(0.35, 0.85, dist) * vig_stage;
	color.rgb = mix(color.rgb, vec3(0.0, 0.0, 0.0), vig_edge * mix(0.08, 0.28, intensity));
	color.rgb = mix(color.rgb, vec3(0.4, 0.04, 0.45), vig_edge * mix(0.04, 0.14, intensity));

	// ---- 阶段3: 扭曲 (保留最初强度) ----
	float warp_edge = smoothstep(0.30, 0.85, dist) * warp_stage;
	if (warp_edge > 0.0) {
		vec2 warp_uv = uv;
		float warp = warp_edge * mix(0.006, 0.028, intensity);
		warp_uv.x += sin(uv.y * 50.0 + TIME * 20.0) * warp;
		warp_uv.y += cos(uv.x * 50.0 + TIME * 22.0) * warp * 0.7;
		vec4 warped = texture(SCREEN_TEXTURE, warp_uv);
		color.rgb = mix(color.rgb, warped.rgb, warp_edge * 0.6);
		// 扭曲时附加更浓的色散
		color.r = mix(color.r, warped.r, warp_edge * 0.3);
		color.b = mix(color.b, texture(SCREEN_TEXTURE, warp_uv - vec2(0.01 * warp_edge, 0.0)).b, warp_edge * 0.3);
	}

	COLOR = color;
}
