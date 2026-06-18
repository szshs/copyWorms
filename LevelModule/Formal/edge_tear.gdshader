// res://LevelModule/Formal/edge_tear.gdshader
// 屏幕边缘撕裂 + 色散 + 溢色
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = uv - 0.5;
	float dist = length(center) * 1.4;
	float edge = smoothstep(0.30, 0.88, dist) * intensity;

	vec4 color = texture(SCREEN_TEXTURE, uv);

	// 色散：R/B 通道在边缘分离
	float ca = edge * 0.009;
	float r = texture(SCREEN_TEXTURE, uv + vec2(ca, 0.0)).r;
	float b = texture(SCREEN_TEXTURE, uv - vec2(ca, 0.0)).b;
	color.r = mix(color.r, r, edge * 0.8);
	color.b = mix(color.b, b, edge * 0.8);

	// 边缘像素微小撕裂
	float tear = edge * 0.006;
	uv.x += sin(uv.y * 60.0 + TIME * 6.0) * tear;
	uv.y += cos(uv.x * 55.0 + TIME * 5.5) * tear * 0.6;
	vec4 torn = texture(SCREEN_TEXTURE, uv);
	color.rgb = mix(color.rgb, torn.rgb, edge * 0.35);

	// 边缘压暗
	color.rgb = mix(color.rgb, vec3(0.0, 0.0, 0.0), edge * 0.25);

	// 暖紫红 → 冷青色渐变溢色（随 TIME 缓慢变换）
	float cycle = sin(TIME * 0.3) * 0.5 + 0.5;
	vec3 warm = vec3(0.5, 0.06, 0.35);
	vec3 cool = vec3(0.06, 0.4, 0.55);
	color.rgb = mix(color.rgb, mix(warm, cool, cycle), edge * 0.18);

	COLOR = color;
}
