// warning_barrier.gdshader - 能量结界光幕 v3
// 视觉：垂直能量流（底部升起）+ 六边形蜂巢结构 + 顶底渐隐 + 能量火花
// 用法：挂在墙壁 ColorRect 上，barrier_color 控制主色（Level_03 用深蓝）
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 2.0) = 0.7;
uniform float alert_level : hint_range(0.0, 1.0) = 1.0;
uniform vec4 barrier_color : source_color = vec4(0.04, 0.12, 0.7, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.6;

// ---- 噪声工具 ----
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// ---- 六边形距离场：返回到最近六边形中心的距离 ----
// 返回值：[0, 1]，0=中心，1=边缘
float hex_dist(vec2 uv, float scale) {
	uv *= scale;
	vec2 r = vec2(1.0, 1.732);      // 六边形基向量
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;        // 当前格内坐标
	vec2 b = mod(uv - h, r) - h;    // 相邻格偏移坐标
	// 取距离中心更近的那个
	float d = min(dot(a, a), dot(b, b));
	return sqrt(d) / h.x;            // 归一化到 [0,1]
}

void fragment() {
	vec2 uv = UV;

	// ============================================================
	// 1. 顶底渐隐：底部最亮（接地），顶部渐隐入空气
	// ============================================================
	float v_fade = smoothstep(1.0, 0.15, uv.y);  // 底部1.0 → 顶部0.0
	// 顶部留一点微光，避免完全断裂
	v_fade = max(v_fade, 0.05);

	// ============================================================
	// 2. 垂直能量流：从底部升起的竖向光柱
	// ============================================================
	// 多层不同频率的正弦波叠加，模拟能量上升
	float flow1 = sin(uv.y * 8.0 - TIME * scroll_speed * 3.0) * 0.5 + 0.5;
	float flow2 = sin(uv.y * 15.0 - TIME * scroll_speed * 2.0 + uv.x * 6.0) * 0.5 + 0.5;
	float flow3 = sin(uv.y * 3.0 - TIME * scroll_speed * 1.5) * 0.5 + 0.5;
	float energy_flow = (flow1 * 0.5 + flow2 * 0.3 + flow3 * 0.2);
	energy_flow = pow(energy_flow, 1.5);

	// ============================================================
	// 3. 六边形蜂巢结构：能量场的骨架纹理
	// ============================================================
	// 六边形网格随时间缓慢下移（像能量在下沉回流）
	vec2 hex_uv = uv + vec2(0.0, TIME * scroll_speed * 0.15);
	float hex_scale = 12.0;
	float hd = hex_dist(hex_uv, hex_scale);
	// 边缘亮（接近1），中心暗（接近0）
	float hex_edge = smoothstep(0.7, 1.0, hd);
	// 蜂巢整体随 alert_level 强度变化
	hex_edge *= (0.4 + alert_level * 0.6);

	// ============================================================
	// 4. 柔和波纹：低频涟漪，像能量场表面张力
	// ============================================================
	float ripple = sin(uv.x * 20.0 + uv.y * 30.0 + TIME * 2.0) * 0.5 + 0.5;
	ripple = pow(ripple, 4.0) * 0.15;

	// ============================================================
	// 5. 能量火花：沿六边形边缘随机闪过
	// ============================================================
	// 用 hash 在六边形格点位置生成随机火花
	float spark_seed = floor(TIME * 4.0);
	vec2 cell = floor(hex_uv * hex_scale);
	float spark_rand = hash2(cell + spark_seed);
	float spark = step(0.92, spark_rand) * hd;
	// 火花随时间快速衰减
	float spark_life = fract(TIME * 4.0);
	spark *= smoothstep(1.0, 0.0, spark_life);

	// ============================================================
	// 6. 整体呼吸脉动
	// ============================================================
	float pulse = 0.85 + 0.15 * sin(TIME * (1.2 + alert_level * 2.0));

	// ============================================================
	// 7. 加法合成
	// ============================================================
	// 基础半透明底（均匀微光）
	float base_alpha = 0.12 * v_fade;
	// 能量流（主结构，从下往上流动）
	float flow_alpha = energy_flow * 0.35 * v_fade;
	// 蜂巢边缘（骨架纹理）
	float hex_alpha = hex_edge * 0.4 * v_fade;
	// 波纹（细节）
	float ripple_alpha = ripple * v_fade;
	// 火花（点缀）
	float spark_alpha = spark * 0.8 * v_fade;

	float alpha = (base_alpha + flow_alpha + hex_alpha + ripple_alpha + spark_alpha);
	alpha = alpha * intensity * fade * pulse;

	// ============================================================
	// 8. 颜色：基础色 + 火花处提亮
	// ============================================================
	vec3 col = barrier_color.rgb;
	// 火花和能量流峰值处颜色偏亮白
	float bright = clamp(spark * 0.7 + energy_flow * 0.2, 0.0, 0.8);
	col = mix(col, vec3(0.8, 0.9, 1.0), bright);

	// 底部接地辉光：颜色更饱和
	col = mix(col, col * 1.3, v_fade * 0.5);

	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
