# ============================================================
# StageTestPanel.gd - 阶段测试面板（调试用）
# 按0显示/隐藏面板，点击按钮切换到指定阶段
# 用法：var panel = StageTestPanel.new(self, stages_data)
#       stages_data = [{"name": "阶段1", "action": func(): ...}, ...]
# ============================================================
extends CanvasLayer

var _target: Node = null
var _stages: Array = []
var _panel: Panel = null
var _visible: bool = false

func _init(target: Node, stages: Array) -> void:
	_target = target
	_stages = stages
	layer = 500
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_build_ui()
	set_process_input(true)

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.position = Vector2(500, 200)
	_panel.size = Vector2(280, 60 + _stages.size() * 50)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var title = Label.new()
	title.text = "阶段测试面板 (按0开关)"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title.position = Vector2(10, 10)
	title.size = Vector2(260, 30)
	_panel.add_child(title)

	for i in _stages.size():
		var btn = Button.new()
		btn.text = _stages[i].get("name", "阶段%d" % i)
		btn.position = Vector2(10, 50 + i * 50)
		btn.size = Vector2(260, 40)
		btn.add_theme_font_size_override("font_size", 16)
		btn.focus_mode = Control.FOCUS_NONE
		var action: Callable = _stages[i].get("action", Callable())
		btn.pressed.connect(func():
			if action.is_valid():
				action.call()
		)
		_panel.add_child(btn)

	_panel.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_0:
		_visible = not _visible
		_panel.visible = _visible
		get_viewport().set_input_as_handled()
