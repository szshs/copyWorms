# ============================================================
# CodeRain.gd - Matrix 风格代码雨效果（双层面板）
# 背景层：密集单字符列（draw_char），模拟经典 Matrix 雨
# 前景层：项目函数名"数据包"（draw_string），缓慢穿行
# 继承 Control，无需场景文件。
# ============================================================
extends Control
class_name CodeRain


# ---- 可调参数：背景层（单字符雨） ----

## 列间距（像素）
@export var column_spacing: int = 22

## 下落速度范围（像素/秒）
@export var speed_min: float = 50.0
@export var speed_max: float = 180.0

## 拖尾长度范围（字符数）
@export var trail_length_min: int = 10
@export var trail_length_max: int = 22

## 字符大小（像素Silver 16px）
@export var char_size: int = 16

## 基色（#0aae43 终端绿）
@export var rain_color: Color = Color(0.039, 0.682, 0.263)

## 首字符（最亮）透明度
@export var head_alpha: float = 0.95

## 尾字符（最暗）透明度
@export var tail_alpha: float = 0.08

## 字符随机变化间隔（秒）
@export var char_mutation_interval: float = 0.08


# ---- 可调参数：前景层（函数名数据包） ----

## 前景函数名数量
@export var fn_count: int = 6

## 前景下落速度范围（像素/秒），明显慢于背景
@export var fn_speed_min: float = 22.0
@export var fn_speed_max: float = 48.0

## 前景字号（像素Silver 保证可读）
@export var fn_font_size: int = 16

## 前景透明度
@export var fn_alpha: float = 0.9

## 前景色（#0aae43 终端绿，与背景统一）
@export var fn_color: Color = Color(0.039, 0.682, 0.263)

## 前景函数名变化间隔（秒，落入底部后换一个新函数名）
@export var fn_mutation_interval: float = 0.15


# ---- 公共参数 ----

## 淡入/淡出时长（秒）
@export var fade_duration: float = 1.0


# ---- 内部状态 ----

# 背景层
var _columns: Array = []          # Array[Dictionary{ x, y, speed, trail, len }]
var _char_pool: Array[String] = []
var _mutation_timer: float = 0.0

# 前景层
var _fn_columns: Array = []       # Array[Dictionary{ x, y, speed, text }]
var _fn_pool: Array[String] = []
var _fn_mutation_timer: float = 0.0

var _active: bool = false
var _font: Font = null


# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0
	# 加载像素Silver字体
	_font = load("res://Assets/Fonts/像素Silver/像素Silver.ttf") as Font
	_build_char_pool()
	_build_fn_pool()
	set_process(false)


# ============================================================
# 字符池构建（片假名 + 数字 + 符号，营造 Matrix 感）
# ============================================================

func _build_char_pool() -> void:
	_char_pool.clear()
	# 半角片假名
	var katakana = "ｦｧｨｩｪｫｬｭｮｯｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ"
	# 数字
	var digits = "0123456789"
	# 半角符号（类 Matrix 常用字符）
	var symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?/"
	# 全角日文片假名
	var full_katakana = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
	# 十六进制字符
	var hex = "ABCDEF0123456789"

	var raw = katakana + digits + symbols + full_katakana + hex
	for c in raw:
		_char_pool.append(c)


# ============================================================
# 前景函数名池（项目核心函数，营造"系统代码泄漏"叙事）
# ============================================================

func _build_fn_pool() -> void:
	_fn_pool = [
		# 关卡模块
		"_swap_player_to_cyber()",
		"_start_screen_shake(duration)",
		"_trigger_awakening()",
		"_trigger_lingnan_combat()",
		"_trigger_sleep_cycle()",
		"_trigger_climax_transition()",
		"_apply_dream_runtime_flags()",
		"_swap_world(map_id)",
		"_apply_reality_space_settings()",
		"_build_glitch_overlay()",
		# 玩家模块
		"perform_attack(target)",
		"perform_dash(direction)",
		"perform_skill()",
		"_fire_shockwave(radius)",
		"_do_lightning_dash()",
		"_do_spin_slash()",
		"_handle_idle()",
		"_handle_jump()",
		"_handle_hurt()",
		"_spawn_afterimage()",
		# 敌人模块
		"_ai_chase(target)",
		"_ai_attack()",
		"_fire_fireball(dir)",
		"take_damage(amount)",
		"_can_detect_target()",
		"_start_windup()",
		# 全局模块
		"EventBus.emit(event, data)",
		"GameManager.register_player()",
		"InputManager.block_input()",
		"MainEntry._switch_to_level()",
		"subscribe(event, node)",
		"emit_deferred(event)",
	]


# ============================================================
# 列初始化
# ============================================================

func _init_columns() -> void:
	# ---- 背景层 ----
	_columns.clear()
	var screen_w = get_viewport_rect().size.x
	if screen_w <= 0:
		screen_w = 1280.0
	var col_count = maxi(1, int(screen_w / column_spacing))

	for i in range(col_count):
		_columns.append({
			"x": float(i * column_spacing + randi_range(-6, 6)),
			"y": randf_range(-600.0, 0.0),
			"speed": randf_range(speed_min, speed_max),
			"trail": _random_trail(randi_range(trail_length_min, trail_length_max)),
			"len": 0,
		})
		_columns[i]["len"] = _columns[i]["trail"].size()

	# ---- 前景层（函数名数据包，按槽位均匀分布） ----
	_fn_columns.clear()
	if _fn_pool.is_empty():
		return
	var safe_fn_count = mini(fn_count, _fn_pool.size())
	var slot_width = maxf((screen_w - 80.0) / safe_fn_count, 300.0)  # 每槽宽度
	for i in range(safe_fn_count):
		var text = _fn_pool[randi() % _fn_pool.size()]
		var base_x = 40.0 + i * slot_width
		_fn_columns.append({
			"slot": i,
			"x": base_x,
			"y": randf_range(-400.0, -20.0),
			"speed": randf_range(fn_speed_min, fn_speed_max),
			"text": text,
		})


func _random_trail(length: int) -> Array[String]:
	var chars: Array[String] = []
	chars.resize(length)
	for j in range(length):
		chars[j] = _char_pool[randi() % _char_pool.size()]
	return chars


# ============================================================
# 每帧逻辑
# ============================================================

func _process(delta: float) -> void:
	if not _active:
		return

	var viewport_size = get_viewport_rect().size
	var screen_w = viewport_size.x
	var screen_h = viewport_size.y
	if screen_w <= 0:
		screen_w = 1280.0
	if screen_h <= 0:
		screen_h = 720.0

	# 推进每列位置
	for col in _columns:
		col["y"] += col["speed"] * delta
		if col["y"] - col["len"] * char_size > screen_h + 80:
			_reset_column(col, screen_h)

	# 定期随机变更字符（模拟闪烁变换感）
	_mutation_timer += delta
	if _mutation_timer >= char_mutation_interval:
		_mutation_timer = 0.0
		for col in _columns:
			var trail: Array = col["trail"]
			if trail.size() > 0:
				var idx = randi() % trail.size()
				trail[idx] = _char_pool[randi() % _char_pool.size()]

	# ---- 前景层推进 ----
	for fn_col in _fn_columns:
		fn_col["y"] += fn_col["speed"] * delta
		if fn_col["y"] > screen_h + 40:
			_reset_fn_column(fn_col, screen_w)

	# 前景函数名定期更换（比背景慢，避免频繁闪烁）
	_fn_mutation_timer += delta
	if _fn_mutation_timer >= fn_mutation_interval:
		_fn_mutation_timer = 0.0
		for fn_col in _fn_columns:
			if randi() % 3 == 0:  # 每帧约1/3概率换一个函数名
				fn_col["text"] = _fn_pool[randi() % _fn_pool.size()]

	queue_redraw()


func _reset_column(col: Dictionary, screen_h: float) -> void:
	col["y"] = randf_range(-200.0, -20.0)
	col["speed"] = randf_range(speed_min, speed_max)
	col["trail"] = _random_trail(randi_range(trail_length_min, trail_length_max))
	col["len"] = col["trail"].size()


func _reset_fn_column(fn_col: Dictionary, screen_w: float) -> void:
	fn_col["y"] = randf_range(-400.0, -20.0)
	fn_col["speed"] = randf_range(fn_speed_min, fn_speed_max)
	fn_col["text"] = _fn_pool[randi() % _fn_pool.size()]
	# 保持在原槽位内，维持均匀分布
	var slot_width = maxf((screen_w - 80.0) / maxi(1, fn_count), 300.0)
	var base_x = 40.0 + fn_col["slot"] * slot_width
	fn_col["x"] = base_x


# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if not _active or not _font:
		return
	if _columns.is_empty():
		return

	var screen_h = get_viewport_rect().size.y

	# ---- 背景层：单字符雨 ----
	for col in _columns:
		var x: float = col["x"]
		var base_y: float = col["y"]
		var trail: Array = col["trail"]
		var length: int = col["len"]
		for j in range(length):
			var char_y = base_y - j * char_size
			if char_y < -char_size or char_y > screen_h + char_size:
				continue
			var t = float(j) / float(length - 1) if length > 1 else 0.0
			var alpha = lerpf(head_alpha, tail_alpha, t)
			draw_char(_font, Vector2(x, char_y), trail[j], char_size, Color(rain_color, alpha))

	# ---- 前景层：函数名数据包 ----
	if _fn_pool.is_empty():
		return
	for fn_col in _fn_columns:
		var fx: float = fn_col["x"]
		var fy: float = fn_col["y"]
		if fy < -fn_font_size or fy > screen_h + fn_font_size:
			continue
		draw_string(_font, Vector2(fx, fy), fn_col["text"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fn_font_size, Color(fn_color, fn_alpha))


# ============================================================
# 公开接口
# ============================================================

## 启动代码雨（淡入）
func start_rain() -> void:
	if _active:
		return
	_active = true
	_init_columns()
	_mutation_timer = 0.0
	_fn_mutation_timer = 0.0
	visible = true
	modulate.a = 0.0
	set_process(true)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)


## 停止代码雨（淡出）
func stop_rain() -> void:
	if not _active:
		return
	_active = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func():
		set_process(false)
		visible = false
		_columns.clear()
		_fn_columns.clear()
	)
