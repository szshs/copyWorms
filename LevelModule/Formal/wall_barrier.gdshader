// wall_barrier.gdshader - 结界/光幕效果
// 扫描线向上流动 + 边缘发光 + 脉冲呼吸
shader_type canvas_item;

// 扫描线流速
uniform float scan_speed : hint_range(0.0, 50.0) = 12.0;

// 整体强度
uniform float intensity : hint_range(0.0, 1.0) = 0.55;

// 淡出控制（_remove_wall 会 Tween 到 0）
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// 1. 垂直扫描线：向上流动
	float scan = sin((UV.y * 50.0 - TIME * scan_speed)) * 0.5 + 0.5;

	// 2. 水平边缘发光：中心最亮，两侧渐暗
	float edge = 1.0 - abs(UV.x - 0.5) * 2.5;
	edge = smoothstep(0.0, 1.0, edge);

	// 3. 纵向渐变：上端亮、下端暗（光幕从高处延伸感）
	float v_grad = UV.y * 0.5 + 0.5;

	// 4. 呼吸脉冲
	float pulse = sin(TIME * 1.6) * 0.5 + 0.5;

	// 5. 组合
	float alpha = scan * edge * v_grad * intensity * (0.7 + 0.3 * pulse) * fade;

	COLOR = vec4(COLOR.rgb, alpha);
}
