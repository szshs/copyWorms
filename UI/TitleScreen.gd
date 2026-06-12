# ============================================================
# TitleScreen.gd - 开始游戏界面
# 所有 UI 用代码构建，确保按钮事件可靠触发
# "关卡自测"按钮 → 弹出关卡选择子面板，点击即直达对应关卡测试
# ============================================================
extends Control

# ---- 关卡选择子面板引用 ----
var _level_select_panel: Control = null
var _panel_just_opened: bool = false  # 防抖：打开后同帧内忽略遮罩关闭

# 可用关卡列表（显示名 → 场景路径），后续新增关卡只需在此追加
const LEVEL_LIST: Array[Dictionary] = [
	{ "name": "关卡 1  —  西关老街", "path": "res://LevelModule/Formal/Level_01.tscn" },
	{ "name": "关卡 2  —  撕裂与沉溺", "path": "res://LevelModule/Formal/Level_02.tscn" },
	{ "name": "关卡 3  —  赛博蜃景与真实回声", "path": "res://LevelModule/Formal/Level_03.tscn" },
]

func _ready() -> void:
	print("[TitleScreen] 标题画面加载")
	_build_ui()

func _build_ui() -> void:
	# 深色背景
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.08, 0.15, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 垂直布局容器（主菜单）
	var vbox = VBoxContainer.new()
	vbox.name = "MainMenuVBox"
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-160, -180)
	vbox.size = Vector2(320, 360)
	vbox.add_theme_constant_override("separation", 15)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(vbox)

	# 标题
	var title = Label.new()
	title.text = "黑客松动作游戏"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 1, 1))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# 副标题
	var sub = Label.new()
	sub.text = "Hackathon Action Game"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7, 1))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub)

	# 间隔
	vbox.add_child(_make_spacer(30))

	# 开始游戏按钮
	vbox.add_child(_make_button("开始游戏 (正式模式)", 50, 18, _on_start_game))

	# 分隔线
	var sep = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# 自测标签
	var test_label = Label.new()
	test_label.text = "--- 自测模式 (打包时删除) ---"
	test_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	test_label.add_theme_font_size_override("font_size", 12)
	test_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	test_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(test_label)

	# 自测按钮（关卡自测改为弹出选择面板）
	vbox.add_child(_make_button("玩家模块自测", 40, 14, _on_test_player))
	vbox.add_child(_make_button("敌人模块自测", 40, 14, _on_test_enemy))
	vbox.add_child(_make_button("关卡自测  ▶", 40, 14, _on_open_level_select))

	# 间隔
	vbox.add_child(_make_spacer(15))

	# 退出按钮
	vbox.add_child(_make_button("退出游戏", 40, 14, _on_quit))

	# ---- 关卡选择子面板（初始隐藏，覆盖在主菜单之上） ----
	_build_level_select_panel()

# ============================================================
# 关卡选择子面板
# ============================================================

func _build_level_select_panel() -> void:
	var panel = Control.new()
	panel.name = "LevelSelectPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false

	# 半透明遮罩（仅左键点击关闭；motion/释放事件不过滤会导致面板一闪即逝）
	var overlay = ColorRect.new()
	overlay.name = "DimOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_input)
	panel.add_child(overlay)

	# 居中面板容器
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)

	var box = VBoxContainer.new()
	box.name = "LevelSelectVBox"
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(box)

	# 标题
	var header = Label.new()
	header.text = "选择关卡进行测试"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)

	# 分隔线
	var sep = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sep)

	# 各关卡按钮
	for i in range(LEVEL_LIST.size()):
		var info = LEVEL_LIST[i]
		var btn = Button.new()
		btn.name = "LevelBtn_%d" % i
		btn.text = info.name
		btn.custom_minimum_size = Vector2(360, 48)
		btn.add_theme_font_size_override("font_size", 16)
		var path = info.path  # 闭包捕获
		btn.pressed.connect(func(): _on_select_level(path))
		box.add_child(btn)

	# 间隔
	box.add_child(_make_spacer(8))

	# 返回按钮
	var back_btn = Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "◀  返回主界面"
	back_btn.custom_minimum_size = Vector2(360, 44)
	back_btn.add_theme_font_size_override("font_size", 15)
	back_btn.pressed.connect(_close_level_select)
	box.add_child(back_btn)

	add_child(panel)
	_level_select_panel = panel

func _on_open_level_select() -> void:
	if _level_select_panel:
		_panel_just_opened = true
		_level_select_panel.visible = true
		# 防抖：打开后等一帧再允许遮罩关闭，避免同帧鼠标释放事件穿透导致一闪即逝
		await get_tree().process_frame
		_panel_just_opened = false
	print("[TitleScreen] 关卡选择面板已打开")

func _close_level_select() -> void:
	if _panel_just_opened:
		return
	if _level_select_panel:
		_level_select_panel.visible = false
	print("[TitleScreen] 关卡选择面板已关闭")

## 遮罩层输入处理：仅响应左键按下事件（过滤 motion/释放，否则鼠标移动就关闭面板）
func _on_overlay_input(event: InputEvent) -> void:
	if _panel_just_opened:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_level_select()

func _on_select_level(level_path: String) -> void:
	print("[TitleScreen] >>> 关卡自测: %s <<<" % level_path)
	GameManager.run_mode = GlobalDefine.RunMode.SELF_TEST
	get_tree().change_scene_to_file(level_path)

# ============================================================
# 通用工具
# ============================================================

func _make_spacer(height: int) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _make_button(text: String, min_height: int, font_size: int, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, min_height)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.pressed.connect(callback)
	return btn

# ---- 按钮回调 ----

func _on_start_game() -> void:
	print("[TitleScreen] >>> 开始正式游戏按钮被点击 <<<")
	GameManager.run_mode = GlobalDefine.RunMode.FORMAL
	get_tree().change_scene_to_file("res://Global/MainEntry.tscn")

func _on_quit() -> void:
	print("[TitleScreen] >>> 退出按钮被点击 <<<")
	get_tree().quit()

func _on_test_player() -> void:
	print("[TitleScreen] >>> 玩家自测按钮被点击 <<<")
	GameManager.run_mode = GlobalDefine.RunMode.SELF_TEST
	get_tree().change_scene_to_file("res://PlayerModule/SelfTest/PlayerTest.tscn")

func _on_test_enemy() -> void:
	print("[TitleScreen] >>> 敌人自测按钮被点击 <<<")
	GameManager.run_mode = GlobalDefine.RunMode.SELF_TEST
	get_tree().change_scene_to_file("res://EnemyModule/SelfTest/EnemyTest.tscn")
