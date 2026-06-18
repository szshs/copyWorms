// res://LevelModule/Formal/PixelTearing.gdshader
// 侵蚀从四周向内渗透：离玩家越近越完整
// noise 随时间滚动 → 渐变带像素持续动态
shader_type canvas_item;

uniform sampler2D noise_tex : filter_nearest, repeat_enable;
uniform vec2 noise_size = vec2(512.0, 512.0);
uniform float corruption_level : hint_range(0.0, 1.0) = 0.0;
uniform vec2 player_uv = vec2(0.5, 0.5);
uniform float chunk_size : hint_range(4.0, 64.0) = 20.0;
uniform vec4 glitch_color : source_color = vec4(0.8, 0.1, 0.6, 1.0);

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 player_px = player_uv * screen_size;

	vec2 pixel_coord = SCREEN_UV * screen_size;
	vec2 chunk_coord = floor(pixel_coord / chunk_size) * chunk_size;
	vec2 chunk_center_px = chunk_coord + chunk_size * 0.5;

	// noise 随时间缓慢滚动 → 边缘像素持续动态
	vec2 noise_uv = chunk_coord / noise_size;
	noise_uv += vec2(TIME * 0.012, TIME * 0.008);
	float noise_val = texture(noise_tex, fract(noise_uv)).r;

	// 安全区 + 渐变带
	float safe_radius = 0.296;   // 固定大小，corruption=0.1 时对应的值
	float transition  = 0.42;
	float safe_px     = safe_radius * screen_size.y;
	float trans_px    = transition  * screen_size.y;

	vec2 diff = chunk_center_px - player_px;
	diff.y *= 1.18;  // Y 权重略高 → 竖直偏扁，水平略宽
	float dist = length(diff);
	float erosion = smoothstep(safe_px, safe_px + trans_px, dist);

	float mask = step(noise_val, erosion);

	float edge_width = 0.03;
	float in_edge = (1.0 - step(erosion + edge_width, noise_val))
	             * step(erosion - edge_width * 0.5, noise_val);

	vec4 base_color = texture(TEXTURE, UV);
	vec4 result = base_color;
	result.rgb = mix(result.rgb, glitch_color.rgb, in_edge * glitch_color.a * 0.6);
	result.a *= mask;

	COLOR = result;
}
