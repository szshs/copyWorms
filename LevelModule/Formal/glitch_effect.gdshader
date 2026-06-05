// res://LevelModule/Formal/glitch_effect.gdshader
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// 基础水平波浪抖动
	float wave = sin(uv.y * 50.0 + TIME * 20.0) * 0.03 * intensity;
	
	// 随机色散断裂
	float noise = step(0.98 - intensity * 0.1, sin(TIME * 10.0 + uv.y * 100.0));
	uv.x += wave + (noise * 0.05 * intensity);
	
	vec4 color = texture(SCREEN_TEXTURE, uv);
	
	// 注入色相分离色散 (chromatic aberration)
	color.r = texture(SCREEN_TEXTURE, uv + vec2(0.01 * intensity, 0.0)).r;
	color.b = texture(SCREEN_TEXTURE, uv - vec2(0.01 * intensity, 0.0)).b;
	
	// 画面整体微弱变暗
	COLOR = color * (1.0 - intensity * 0.3);
}
