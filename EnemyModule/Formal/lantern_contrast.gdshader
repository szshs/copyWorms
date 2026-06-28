shader_type canvas_item;

// 提高灯笼怪图片对比度，让怪物位置更醒目
// contrast > 1 增强对比，< 1 降低对比

uniform float contrast : hint_range(0.5, 3.0) = 1.5;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// 以 0.5 为中心做对比度拉伸
	c.rgb = (c.rgb - 0.5) * contrast + 0.5;
	c.rgb = clamp(c.rgb, 0.0, 1.0);
	COLOR = c;
}
