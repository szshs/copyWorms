# ============================================================
# TitleScreen.gd - 开始游戏界面（节点化 + 点击转场版本）
# 初始：只显示底图 + 游戏名称标题，按钮组隐藏
# 点击 (424,332) 附近热区 → 黑色矩形从点击点放大铺满全屏 → 按钮组淡入
# ============================================================
extends Control

# ---- 节点引用 ----
@onready var _title_group: Control = $TitleGroup
@onready var _button_group: VBoxContainer = $MenuCenter/ButtonGroup
@onready var _click_hotspot: Control = $ClickHotspot
@onready var _hotspot_indicator: ColorRect = $ClickHotspot/Indicator
@onready var _hotspot_glow: ColorRect = $ClickHotspot/Glow
@onready var _black_rect: ColorRect = $TransitionLayer/BlackRect

# ---- 转场参数 ----
const HOTSPOT_CENTER := Vector2(332.0, 349.0)
const TRANSITION_DURATION := 0.7    # 黑色矩形放大时长
const FADE_IN_DURATION := 0.45      # 按钮组淡入时长
const HIGHLIGHT_SCENE := "res://LevelModule/Formal/Level_02_03.tscn"

var _transitioned: bool = false

func _ready() -> void:
	print("[TitleScreen] 标题画面加载")
	# 标题界面播放结局主题音乐
	MusicManager.restart_bgm("res://Assets/Music/lv5-end.ogg")
	_setup_initial_state()
	_connect_signals()
	_start_hotspot_flicker()
	set_process_input(true)

# ============================================================
# 光点闪烁：复用关卡1 InteractiveObject.apply_level01_dot_visual 的正弦呼吸
# Indicator alpha 0.2↔0.9，Glow alpha 0.0↔0.3，各 0.6s
# ============================================================

func _start_hotspot_flicker() -> void:
	if _hotspot_indicator:
		var tw = _hotspot_indicator.create_tween().set_loops()
		tw.tween_property(_hotspot_indicator, "color:a", 0.2, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_hotspot_indicator, "color:a", 0.9, 0.6).set_trans(Tween.TRANS_SINE)
	if _hotspot_glow:
		var tw2 = _hotspot_glow.create_tween().set_loops()
		tw2.tween_property(_hotspot_glow, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(_hotspot_glow, "color:a", 0.3, 0.6).set_trans(Tween.TRANS_SINE)

# ============================================================
# 初始状态：只显示底图 + 标题，按钮组隐藏
# ============================================================

func _setup_initial_state() -> void:
	# 标题组始终显示
	_title_group.modulate.a = 1.0
	# 按钮组隐藏且不可点击（visible=false 时子节点不接收输入）
	_button_group.visible = false
	_button_group.modulate.a = 0.0
	# 黑色矩形初始不可见、尺寸为0、定位在热区中心
	_black_rect.visible = false
	_set_rect_size_around(HOTSPOT_CENTER, Vector2.ZERO)
	# 热区可点击
	_click_hotspot.mouse_filter = Control.MOUSE_FILTER_STOP

## 以 center 为中心设置 BlackRect 的 size 与 position
func _set_rect_size_around(center: Vector2, size: Vector2) -> void:
	_black_rect.size = size
	_black_rect.position = center - size * 0.5

# ============================================================
# 信号连接
# ============================================================

func _connect_signals() -> void:
	# 热区点击 → 触发转场
	_click_hotspot.gui_input.connect(_on_hotspot_input)

	# 主菜单按钮
	$MenuCenter/ButtonGroup/StartButton.pressed.connect(_on_start_game)
	$MenuCenter/ButtonGroup/HighlightButton.pressed.connect(_on_highlight_start)
	$MenuCenter/ButtonGroup/SettingsButton.pressed.connect(_on_open_settings)
	$MenuCenter/ButtonGroup/QuitButton.pressed.connect(_on_quit)

	# 主菜单按钮加 hover 动效
	_connect_btn_hover_modulate($MenuCenter/ButtonGroup/StartButton)
	_connect_btn_hover_modulate($MenuCenter/ButtonGroup/HighlightButton)
	_connect_btn_hover_modulate($MenuCenter/ButtonGroup/SettingsButton)
	_connect_btn_hover_modulate($MenuCenter/ButtonGroup/QuitButton)

## TextureButton hover/pressed 动效：modulate 染底板淡蓝色，Label self_modulate 反抵消保持白字
func _connect_btn_hover_modulate(btn: TextureButton) -> void:
	btn.modulate = Color(0.4, 0.65, 1.0, 1.0)
	var lbl := btn.get_node_or_null("Label") as Label
	if lbl: lbl.self_modulate = Color(2.5, 1.54, 1.0)
	btn.mouse_entered.connect(func() -> void:
		if not btn.disabled:
			btn.modulate = Color(0.55, 0.78, 1.0, 1.0)
			if lbl: lbl.self_modulate = Color(1.82, 1.28, 1.0)
	)
	btn.mouse_exited.connect(func() -> void:
		btn.modulate = Color(0.4, 0.65, 1.0, 1.0)
		if lbl: lbl.self_modulate = Color(2.5, 1.54, 1.0)
	)
	btn.button_down.connect(func() -> void:
		btn.modulate = Color(0.25, 0.48, 0.85, 1.0)
		if lbl: lbl.self_modulate = Color(4.0, 2.08, 1.18)
	)
	btn.button_up.connect(func() -> void:
		btn.modulate = Color(0.55, 0.78, 1.0, 1.0)
		if lbl: lbl.self_modulate = Color(1.82, 1.28, 1.0)
	)

# ============================================================
# 点击热区 → 黑色矩形从点击点放大铺满 + 按钮淡入
# ============================================================

func _on_hotspot_input(event: InputEvent) -> void:
	if _transitioned:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_transition()

func _start_transition() -> void:
	_transitioned = true
	# 禁用热区，避免重复触发
	_click_hotspot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 光点消失
	if _hotspot_indicator:
		_hotspot_indicator.visible = false
	if _hotspot_glow:
		_hotspot_glow.visible = false

	# 计算铺满全屏所需的正方形边长：以 HOTSPOT_CENTER 为中心的正方形要覆盖整个屏幕
	# 边长 = 2 * max(中心到屏幕四边的最远距离)
	var view_size := get_viewport_rect().size
	var half: float = max(
		max(HOTSPOT_CENTER.x, view_size.x - HOTSPOT_CENTER.x),
		max(HOTSPOT_CENTER.y, view_size.y - HOTSPOT_CENTER.y)
	)
	var cover: float = 2.0 * half
	var final_size := Vector2(cover, cover)

	# 显示黑色矩形并从0放大到铺满
	_black_rect.visible = true
	_set_rect_size_around(HOTSPOT_CENTER, Vector2.ZERO)

	# 纯串行 tween：放大 → 显示按钮组 → 淡入
	var tween := create_tween()
	tween.tween_method(
		func(s: Vector2) -> void: _set_rect_size_around(HOTSPOT_CENTER, s),
		Vector2.ZERO, final_size, TRANSITION_DURATION
	).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		_button_group.visible = true
	)
	tween.tween_property(_button_group, "modulate:a", 1.0, FADE_IN_DURATION).set_ease(Tween.EASE_IN_OUT)
	print("[TitleScreen] 转场动画启动")

# ============================================================
# 按钮回调
# ============================================================

func _on_start_game() -> void:
	SFXManager.play(SFXManager.SFX.UI_CLICK)
	print("[TitleScreen] >>> 开始正式游戏按钮被点击 <<<")
	GameManager.run_mode = GlobalDefine.RunMode.FORMAL
	SceneTransitionManager.request_scene_change("res://Global/MainEntry.tscn", self)

func _on_highlight_start() -> void:
	SFXManager.play(SFXManager.SFX.UI_CLICK)
	print("[TitleScreen] >>> 从精彩处开始按钮被点击 <<<")
	GameManager.run_mode = GlobalDefine.RunMode.FORMAL
	SceneTransitionManager.request_scene_change(HIGHLIGHT_SCENE, self)

func _on_quit() -> void:
	SFXManager.play(SFXManager.SFX.UI_CLICK)
	print("[TitleScreen] >>> 退出按钮被点击 <<<")
	get_tree().quit()

func _on_open_settings() -> void:
	SFXManager.play(SFXManager.SFX.UI_CLICK)
	print("[TitleScreen] >>> 设置按钮被点击 <<<")
	var scene: PackedScene = load("res://UI/KeybindSettingsScreen.tscn")
	if scene:
		# 半透明遮罩
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.6)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		dim.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				dim.queue_free()
		)
		add_child(dim)
		var screen: Control = scene.instantiate()
		screen.closed.connect(func() -> void:
			dim.queue_free()
		)
		add_child(screen)
	else:
		push_error("[TitleScreen] 无法加载按键设置界面")

func _input(event: InputEvent) -> void:
	# 按1进入玩家测试场景
	if event is InputEventKey and event.pressed and event.keycode == KEY_1:
		SFXManager.play(SFXManager.SFX.UI_CLICK)
		print("[TitleScreen] >>> 进入玩家测试场景 <<<")
		GameManager.run_mode = GlobalDefine.RunMode.FORMAL
		SceneTransitionManager.request_scene_change("res://Scenes/TestArena.tscn", self)
