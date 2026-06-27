# ============================================================
# WarningBarrier.gd - 系统入侵防火墙特效（v2 完整版）
# 状态机: HIDDEN → ALERT (玩家接近，连续渐变) → BREACHED (进入触发区，爆发) → DISABLED
#
# v2 改进:
#   A: IDLE 完全隐藏 + 真实滚动文字
#   B: 距离→alert_level 连续渐变（非二元切换）
#   C: BREACHED 并行 Tween + 红色火花粒子
#   D: 实时获取 player / _exit_tree 清理 / 幂等保护
# ============================================================
extends Node2D
class_name WarningBarrier


# ---- 配置 ----

## 警戒触发距离（像素）
@export var detect_range: float = 220.0

## 警戒文字内容
@export var warning_text: String = "[!] RESTRICTED AREA [!] ACCESS DENIED [!] UNAUTHORIZED ENTRY [!]"

## 滚动速度（像素/秒）
@export var scroll_speed: float = 140.0

## 火花粒子数量（爆发时）
@export var spark_count: int = 10


# ---- 状态机 ----

enum State { HIDDEN, ALERT, BREACHED, DISABLED }

var _state: int = State.ALERT  # 始终处于 ALERT 态
var _trigger: Area2D = null
var _shader_rect: ColorRect = null
var _warning_label: Label = null
var _mat: ShaderMaterial = null
var _scroll_tween: Tween = null
var _current_alert_level: float = 0.0  # 连续渐变值 0~1
var _barrier_size: Vector2 = Vector2(80, 360)
var _is_breaching: bool = false


# ============================================================
# 生命周期
# ============================================================

func _exit_tree() -> void:
	_kill_all_tweens()


func _kill_all_tweens() -> void:
	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
		_scroll_tween = null
	# Tween 是 RefCounted 不是 Node，不会出现在 get_children() 中
	# 节点销毁时所有由 create_tween() 创建的 Tween 会自动失效


# ============================================================
# 初始化
# ============================================================

func setup(trigger: Area2D, shader: Shader) -> void:
	_trigger = trigger

	# 定位到触发区世界坐标
	global_position = trigger.global_position

	# 从 CollisionShape2D 获取尺寸和位置
	var col_shape = trigger.get_node_or_null("CollisionShape2D")
	var s: Vector2 = Vector2(80, 360)
	var pos: Vector2 = Vector2.ZERO
	if col_shape and col_shape.shape is RectangleShape2D:
		s = col_shape.shape.size
		pos = col_shape.position
	_barrier_size = s

	# 创建独立的 ShaderMaterial
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("intensity", 1.4)  # 始终显示（两倍强度）
	_mat.set_shader_parameter("barrier_color", Color(1.0, 0.06, 0.04, 1.0))
	_mat.set_shader_parameter("alert_level", 1.0)  # 始终最高警戒
	_mat.set_shader_parameter("fade", 1.0)

	# Shader 结界 ColorRect
	_shader_rect = ColorRect.new()
	_shader_rect.name = "BarrierShader"
	_shader_rect.size = s
	_shader_rect.position = pos - s / 2
	_shader_rect.material = _mat
	_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_rect.visible = true  # 始终显示
	add_child(_shader_rect)

	# 警告文字
	_warning_label = Label.new()
	_warning_label.name = "WarningLabel"
	_warning_label.text = warning_text
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning_label.add_theme_font_size_override("font_size", 21)
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.08, 0.9))
	_warning_label.position = Vector2(-500, -14)
	_warning_label.size = Vector2(s.x * 4, 28)
	_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_label.visible = true
	add_child(_warning_label)

	# 启动滚动
	_start_scroll_loop()

	print("[WarningBarrier] 初始化完成 size=%s pos=%s" % [s, pos])


func _start_scroll_loop() -> void:
	if not _warning_label:
		return
	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()
	# 计算单次文本宽度（一段 warning_text + 4 空格）
	var single_w = _warning_label.get_theme_font("font").get_string_size(
		warning_text + "    ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	if single_w <= 0:
		single_w = 300.0
	var start_x = _warning_label.position.x  # 保持初始偏移位置
	var end_x = start_x + single_w  # 向右滚动一个文本段长度
	var duration = single_w / scroll_speed
	_scroll_tween = create_tween()
	_scroll_tween.set_loops()
	_scroll_tween.tween_property(_warning_label, "position:x", end_x, duration)
	_scroll_tween.tween_property(_warning_label, "position:x", start_x, 0.0)  # 瞬间复位


# ============================================================
# 每帧更新（由 Level_03._process 驱动）
# ============================================================

func update(player_global_pos: Vector2) -> void:
	if _state >= State.BREACHED:
		return
	# 始终显示，无需距离检测
	_current_alert_level = 1.0
	if _mat:
		_mat.set_shader_parameter("alert_level", 1.0)
		_mat.set_shader_parameter("intensity", 1.4)


func _fade_label(alpha: float, duration: float) -> void:
	if not _warning_label:
		return
	_warning_label.visible = alpha > 0.01
	var tween = create_tween()
	tween.tween_property(_warning_label, "modulate:a", alpha, duration)


# ============================================================
# 玩家进入触发区 — 并行爆发序列
# ============================================================

func trigger_breach(on_complete: Callable) -> void:
	if _state >= State.BREACHED or _is_breaching:
		# 已触发过，直接回调
		if on_complete.is_valid():
			on_complete.call()
		return
	_is_breaching = true
	_state = State.BREACHED

	# 文字瞬间消失
	_fade_label(0.0, 0.1)
	# 停止滚动
	if _scroll_tween and _scroll_tween.is_valid():
		_scroll_tween.kill()

	# C: 并行 Tween — Glitch 狂闪 + 颜色变白同时进行
	var tween_glitch = create_tween()
	tween_glitch.tween_method(
		func(v: float): _mat.set_shader_parameter("intensity", v),
		_mat.get_shader_parameter("intensity"), 2.0, 0.12
	)
	tween_glitch.tween_method(
		func(v: float): _mat.set_shader_parameter("alert_level", v),
		_mat.get_shader_parameter("alert_level"), 1.0, 0.12
	)

	var cur_color: Color = _mat.get_shader_parameter("barrier_color")
	var tween_color = create_tween()
	tween_color.tween_method(
		func(v: float): _mat.set_shader_parameter("barrier_color", cur_color.lerp(Color(1.0, 1.0, 1.0, 1.0), v)),
		0.0, 1.0, 0.15
	)

	# C: 火花粒子爆发
	_spawn_sparks()

	# 等待爆发动画完成 (0.2s)
	await get_tree().create_timer(0.2).timeout

	# 第三阶段：整体淡出
	_state = State.DISABLED
	var tween_fade = create_tween()
	tween_fade.tween_method(
		func(v: float): _mat.set_shader_parameter("fade", v),
		1.0, 0.0, 0.3
	)
	tween_fade.tween_callback(func():
		_is_breaching = false
		if _shader_rect:
			_shader_rect.visible = false
		if on_complete.is_valid():
			on_complete.call()
	)


# ============================================================
# C: 火花粒子（爆发时向外扩散）
# ============================================================

func _spawn_sparks() -> void:
	var center = _barrier_size / 2
	for i in range(spark_count):
		var spark = ColorRect.new()
		spark.name = "Spark_%d" % i
		spark.size = Vector2(4, 4)
		spark.position = center - Vector2(2, 2)
		spark.color = Color(1.0, 0.8, 0.3, 1.0)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)

		# 随机方向向外扩散
		var angle = (float(i) / float(spark_count)) * TAU + randf_range(-0.3, 0.3)
		var distance = randf_range(60, 120)
		var target_pos = center + Vector2(cos(angle), sin(angle)) * distance - Vector2(2, 2)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", target_pos, 0.4).set_trans(Tween.TRANS_SINE)
		tween.tween_property(spark, "color:a", 0.0, 0.4)
		tween.chain().tween_callback(func():
			if is_instance_valid(spark):
				spark.queue_free()
		)


# ============================================================
# 公开接口
# ============================================================

func deactivate() -> void:
	_state = State.DISABLED
	_is_breaching = false
	_kill_all_tweens()
	if _shader_rect:
		_shader_rect.visible = false
	if _warning_label:
		_warning_label.visible = false
