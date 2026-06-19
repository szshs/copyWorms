# ============================================================
# HUD.gd - 游戏抬头显示（纯代码构建UI）
# 显示血条、状态、返回主界面按钮
# ============================================================
extends CanvasLayer

var health_bar: ColorRect          # 血条填充（改为ColorRect）
var health_label: Label
var health_bar_max_width: float = 280.0
var pause_panel: Panel
var game_over_panel: Panel
var _keybind_dim: Panel = null
var _btn_tex: Texture2D = null
var _health_frame: TextureRect = null   # 血条外框
var _health_frame_lingnan: Texture2D = null
var _health_frame_cyber: Texture2D = null

# ---- 技能冷却UI ----
var _skill_icon_container: Control = null   # 技能图标容器（右下角）
var _skill_cooldown_overlay: ColorRect = null  # 冷却遮罩（从上往下收缩）
var _skill_key_label: Label = null           # 按键提示"I"
var _skill_cd_label: Label = null            # 冷却剩余秒数
var _skill_ready_glow: ColorRect = null      # 就绪时边框高亮
const SKILL_ICON_SIZE: float = 64.0
const SKILL_ICON_PATH: String = "res://Assets/UI/skill_icon.png"  # 后续替换图片用

func _ready() -> void:
	# 关键：暂停时 HUD 必须继续运行，否则按钮无法响应
	process_mode = Node.PROCESS_MODE_ALWAYS
	_btn_tex = load("res://Assets/UI/btn.png") as Texture2D
	_health_frame_lingnan = load("res://Assets/UI/血条岭南.png") as Texture2D
	_health_frame_cyber = load("res://Assets/UI/血条赛博.png") as Texture2D
	_build_ui()
	_connect_events()

func _build_ui() -> void:
	# === 左上角：血条容器 ===
	var bar_container = Control.new()
	bar_container.name = "HealthBarContainer"
	bar_container.position = Vector2(20, 20)
	bar_container.size = Vector2(280, 36)
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_container)

	# 背景
	var bar_bg = ColorRect.new()
	bar_bg.name = "BarBackground"
	bar_bg.size = Vector2(280, 36)
	bar_bg.color = Color(0.15, 0.15, 0.15, 0.9)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_bg)

	# 填充条（用 ColorRect 手动控制宽度）
	var bar_fill = ColorRect.new()
	bar_fill.name = "BarFill"
	bar_fill.size = Vector2(280, 36)
	bar_fill.color = Color(0.85, 0.15, 0.15, 0.95)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_fill)
	health_bar = bar_fill  # 赋值给变量，后续更新用

	# 文字标签（直接放在容器上，不在 ProgressBar 内）
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.size = Vector2(280, 36)
	health_label.position = Vector2(0, 0)
	health_label.text = "100 / 100"
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 16)
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(health_label)

	# 把 health_bar 变量重新指向 bar_fill 用于后续更新
	health_bar = bar_fill

	# 血条外框（覆盖在填充条和文字之上，随皮肤切换）
	# 外框图 1408×768(比例1.83:1)，保持比例放大到宽280→高约153，垂直居中包住血条
	_health_frame = TextureRect.new()
	_health_frame.name = "HealthFrame"
	_health_frame.size = Vector2(360, 197)
	_health_frame.position = Vector2(-40, -80)
	_health_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_health_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_health_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_frame.z_index = 10
	bar_container.add_child(_health_frame)
	_update_health_frame()

	# === 返回主界面按钮（右上角） ===
	var back_btn = Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "返回主界面"
	back_btn.position = Vector2(1120, 20)
	back_btn.size = Vector2(140, 36)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(_on_back_pressed)
	add_child(back_btn)

	# === 暂停面板 ===
	pause_panel = Panel.new()
	pause_panel.name = "PausePanel"
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.hide()
	var pause_style = StyleBoxFlat.new()
	pause_style.bg_color = Color(0, 0, 0, 0.6)
	pause_panel.add_theme_stylebox_override("panel", pause_style)
	add_child(pause_panel)

	var pause_label = Label.new()
	pause_label.text = "游戏已暂停"
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.add_theme_font_size_override("font_size", 28)
	pause_label.add_theme_color_override("font_color", Color.WHITE)
	pause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_label.position = Vector2(440, 270)
	pause_label.size = Vector2(400, 50)
	pause_panel.add_child(pause_label)

	var resume_btn = _make_panel_btn("继续游戏", Vector2(540, 340), Vector2(200, 56))
	resume_btn.pressed.connect(_on_resume_pressed)
	pause_panel.add_child(resume_btn)

	var keybind_btn = _make_panel_btn("按键设置", Vector2(540, 410), Vector2(200, 56))
	keybind_btn.pressed.connect(_on_keybind_settings_pressed)
	pause_panel.add_child(keybind_btn)

	var back_btn2 = _make_panel_btn("返回主界面", Vector2(540, 480), Vector2(200, 56))
	back_btn2.pressed.connect(_on_back_pressed)
	pause_panel.add_child(back_btn2)

	# === 游戏结束面板 ===
	game_over_panel = Panel.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_panel.hide()
	var go_style = StyleBoxFlat.new()
	go_style.bg_color = Color(0, 0, 0, 0.7)
	game_over_panel.add_theme_stylebox_override("panel", go_style)
	add_child(game_over_panel)

	var go_label = Label.new()
	go_label.text = "游戏结束"
	go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_label.add_theme_font_size_override("font_size", 40)
	go_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	go_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go_label.position = Vector2(390, 240)
	go_label.size = Vector2(500, 60)
	game_over_panel.add_child(go_label)

	var restart_btn = Button.new()
	restart_btn.text = "重新开始"
	restart_btn.position = Vector2(540, 340)
	restart_btn.size = Vector2(200, 44)
	restart_btn.add_theme_font_size_override("font_size", 16)
	restart_btn.focus_mode = Control.FOCUS_NONE
	restart_btn.pressed.connect(_on_restart_pressed)
	game_over_panel.add_child(restart_btn)

	var back_btn3 = Button.new()
	back_btn3.text = "返回主界面"
	back_btn3.position = Vector2(540, 400)
	back_btn3.size = Vector2(200, 44)
	back_btn3.add_theme_font_size_override("font_size", 16)
	back_btn3.focus_mode = Control.FOCUS_NONE
	back_btn3.pressed.connect(_on_back_pressed)
	game_over_panel.add_child(back_btn3)

	# === 右下角：技能冷却图标 ===
	_build_skill_icon()

## 构建技能冷却图标（右下角，便于后续替换图片）
func _build_skill_icon() -> void:
	_skill_icon_container = Control.new()
	_skill_icon_container.name = "SkillIcon"
	_skill_icon_container.position = Vector2(1200, 620)
	_skill_icon_container.size = Vector2(SKILL_ICON_SIZE, SKILL_ICON_SIZE)
	_skill_icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skill_icon_container)

	# 就绪高亮边框（就绪时呼吸闪烁，冷却时隐藏）
	_skill_ready_glow = ColorRect.new()
	_skill_ready_glow.name = "ReadyGlow"
	_skill_ready_glow.color = Color(0.3, 0.9, 1.0, 0.0)
	_skill_ready_glow.size = Vector2(SKILL_ICON_SIZE + 6, SKILL_ICON_SIZE + 6)
	_skill_ready_glow.position = Vector2(-3, -3)
	_skill_ready_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_icon_container.add_child(_skill_ready_glow)

	# 底框背景
	var bg = ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0.12, 0.12, 0.18, 0.85)
	bg.size = Vector2(SKILL_ICON_SIZE, SKILL_ICON_SIZE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_icon_container.add_child(bg)

	# 技能图标（TextureRect，后续替换图片只需改 SKILL_ICON_PATH 常量）
	var tex = load(SKILL_ICON_PATH) as Texture2D
	if tex:
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.texture = tex
		icon.size = Vector2(SKILL_ICON_SIZE, SKILL_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_skill_icon_container.add_child(icon)
	else:
		# 无图标资源时用文字占位
		var placeholder = Label.new()
		placeholder.name = "Placeholder"
		placeholder.text = "技"
		placeholder.size = Vector2(SKILL_ICON_SIZE, SKILL_ICON_SIZE)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_font_size_override("font_size", 28)
		placeholder.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_skill_icon_container.add_child(placeholder)

	# 冷却遮罩（从上往下收缩，冷却中半透明黑覆盖）
	_skill_cooldown_overlay = ColorRect.new()
	_skill_cooldown_overlay.name = "CdOverlay"
	_skill_cooldown_overlay.color = Color(0, 0, 0, 0.7)
	_skill_cooldown_overlay.size = Vector2(SKILL_ICON_SIZE, 0)
	_skill_cooldown_overlay.position = Vector2(0, 0)
	_skill_cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_icon_container.add_child(_skill_cooldown_overlay)

	# 冷却剩余秒数文字
	_skill_cd_label = Label.new()
	_skill_cd_label.name = "CdLabel"
	_skill_cd_label.text = ""
	_skill_cd_label.size = Vector2(SKILL_ICON_SIZE, SKILL_ICON_SIZE)
	_skill_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill_cd_label.add_theme_font_size_override("font_size", 24)
	_skill_cd_label.add_theme_color_override("font_color", Color.WHITE)
	_skill_cd_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_skill_cd_label.add_theme_constant_override("shadow_offset_x", 1)
	_skill_cd_label.add_theme_constant_override("shadow_offset_y", 1)
	_skill_cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_icon_container.add_child(_skill_cd_label)

	# 按键提示"I"（左下角小字）
	_skill_key_label = Label.new()
	_skill_key_label.name = "KeyHint"
	_skill_key_label.text = "[I]"
	_skill_key_label.size = Vector2(30, 18)
	_skill_key_label.position = Vector2(-2, SKILL_ICON_SIZE - 16)
	_skill_key_label.add_theme_font_size_override("font_size", 13)
	_skill_key_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_skill_key_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_skill_key_label.add_theme_constant_override("shadow_offset_x", 1)
	_skill_key_label.add_theme_constant_override("shadow_offset_y", 1)
	_skill_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_icon_container.add_child(_skill_key_label)

func _process(_delta: float) -> void:
	_update_skill_cooldown()

## 每帧更新技能冷却UI
func _update_skill_cooldown() -> void:
	if not _skill_icon_container: return
	var p = GameManager.player_ref
	if not p or not is_instance_valid(p):
		_skill_icon_container.visible = false
		return
	# 仅 Player_Warrior 系列有 _skill_cooldown_timer
	if not ("_skill_cooldown_timer" in p):
		_skill_icon_container.visible = false
		return
	_skill_icon_container.visible = true

	var cd_remaining: float = p.get("_skill_cooldown_timer")
	# 获取冷却总时间（赛博4s/岭南5s/基类3s）
	var cd_max: float = 3.0
	if "CYBER_SKILL_CD" in p:
		cd_max = p.get("CYBER_SKILL_CD")
	elif "LINGNAN_SKILL_CD" in p:
		cd_max = p.get("LINGNAN_SKILL_CD")
	elif "SKILL_COOLDOWN" in p:
		cd_max = p.get("SKILL_COOLDOWN")

	if cd_remaining > 0.01:
		# 冷却中：遮罩从上往下覆盖，高度按比例
		var ratio = clampf(cd_remaining / cd_max, 0.0, 1.0)
		_skill_cooldown_overlay.size.y = SKILL_ICON_SIZE * ratio
		_skill_cd_label.text = "%.1f" % cd_remaining
		_skill_ready_glow.color.a = 0.0
	else:
		# 就绪：遮罩清空，边框呼吸闪烁
		_skill_cooldown_overlay.size.y = 0
		_skill_cd_label.text = ""
		var t = Time.get_ticks_msec() * 0.004
		_skill_ready_glow.color.a = 0.15 + 0.2 * abs(sin(t))

func _connect_events() -> void:
	EventBus.subscribe(GlobalDefine.EventName.HEALTH_CHANGED, self, "_on_health_changed")
	EventBus.subscribe(GlobalDefine.EventName.GAME_PAUSE, self, "_on_game_pause")
	EventBus.subscribe(GlobalDefine.EventName.GAME_RESUME, self, "_on_game_resume")
	EventBus.subscribe(GlobalDefine.EventName.GAME_OVER, self, "_on_game_over")

# ---- 事件回调 ----

func _on_health_changed(data: Dictionary) -> void:
	if data.get("target") == GameManager.player_ref:
		var hp = data.get("current_health", 100)
		var max_hp = data.get("max_health", 100)
		var ratio = clampf(float(hp) / float(max_hp), 0.0, 1.0)
		health_bar.size.x = health_bar_max_width * ratio
		health_label.text = "%d / %d" % [hp, max_hp]
		_update_health_frame()

## 根据当前玩家皮肤切换血条外框
func _update_health_frame() -> void:
	if not _health_frame: return
	var p = GameManager.player_ref
	if not p or not is_instance_valid(p): return
	var tex: Texture2D = null
	# 判断皮肤类型（Player_Warrior_Cyber / Player_Warrior_Lingnan）
	if p is Player_Warrior_Lingnan:
		tex = _health_frame_lingnan
	elif p is Player_Warrior_Cyber:
		tex = _health_frame_cyber
	_health_frame.texture = tex

func _on_game_pause(_data: Dictionary = {}) -> void:
	pause_panel.show()

func _on_game_resume(_data: Dictionary = {}) -> void:
	pause_panel.hide()

func _on_game_over(_data: Dictionary = {}) -> void:
	game_over_panel.show()

# ---- 按钮回调 ----

func _on_resume_pressed() -> void:
	GameManager.toggle_pause()

func _on_restart_pressed() -> void:
	GameManager.restart_from_checkpoint()

func _on_back_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/TitleScreen.tscn")

func _on_keybind_settings_pressed() -> void:
	pause_panel.hide()
	# 用和暂停面板完全一样的方式创建变暗遮罩（Panel.new + StyleBoxFlat）
	_keybind_dim = Panel.new()
	_keybind_dim.name = "KeybindDimPanel"
	_keybind_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_keybind_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim_style := StyleBoxFlat.new()
	dim_style.bg_color = Color(0, 0, 0, 0.6)
	_keybind_dim.add_theme_stylebox_override("panel", dim_style)
	add_child(_keybind_dim)
	# 创建按键设置界面
	var scene: PackedScene = load("res://UI/KeybindSettingsScreen.tscn")
	if scene:
		var screen: Control = scene.instantiate()
		screen.closed.connect(_on_keybind_screen_closed)
		add_child(screen)
	else:
		push_error("[HUD] 无法加载按键设置界面")
		_keybind_dim.queue_free()
		_keybind_dim = null
		pause_panel.show()

func _on_keybind_screen_closed() -> void:
	if _keybind_dim:
		_keybind_dim.queue_free()
		_keybind_dim = null
	pause_panel.show()

## 创建带 btn.png 底板的纹理按钮（暂停面板等局内UI共用）
func _make_panel_btn(text: String, pos: Vector2, size: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	btn.position = pos
	btn.custom_minimum_size = size
	btn.size = size
	btn.focus_mode = Control.FOCUS_NONE
	if _btn_tex:
		btn.texture_normal = _btn_tex
		btn.texture_hover = _btn_tex
		btn.texture_pressed = _btn_tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 16)
	btn.add_child(lbl)
	# hover/pressed 动效：self_modulate 染底板淡蓝色，不影响文字
	btn.self_modulate = Color(0.6, 0.75, 1.0, 1.0)
	btn.mouse_entered.connect(func() -> void: btn.self_modulate = Color(0.75, 0.88, 1.0, 1.0))
	btn.mouse_exited.connect(func() -> void: btn.self_modulate = Color(0.6, 0.75, 1.0, 1.0))
	btn.button_down.connect(func() -> void: btn.self_modulate = Color(0.45, 0.6, 0.85, 1.0))
	btn.button_up.connect(func() -> void: btn.self_modulate = Color(0.75, 0.88, 1.0, 1.0))
	return btn
