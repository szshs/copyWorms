extends Control
class_name SettingsMenu

## 设置界面 —— 音量、返回


@export var master_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var music_volume: float = 1.0


func _ready() -> void:
	_create_background()
	_create_title()
	_create_volume_sliders()
	_create_back_button()


func _create_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _create_title() -> void:
	var title := Label.new()
	title.text = "设  置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1.0))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-250, 60)
	title.size = Vector2(500, 50)
	add_child(title)


func _create_volume_sliders() -> void:
	var panel := Panel.new()
	panel.position = Vector2(212, 160)
	panel.size = Vector2(600, 240)
	add_child(panel)

	# 主音量
	_create_slider_row("主音量", 0, panel)

	# 音效音量
	_create_slider_row("音效音量", 1, panel)

	# 音乐音量
	_create_slider_row("音乐音量", 2, panel)


func _create_slider_row(label_text: String, row: int, parent: Panel) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 1.0))
	label.position = Vector2(40, 40 + row * 65)
	label.size = Vector2(120, 30)
	parent.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 1.0
	slider.position = Vector2(180, 40 + row * 65)
	slider.size = Vector2(300, 30)

	var value_label := Label.new()
	value_label.name = label_text + "Value"
	value_label.text = "100%"
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7, 1.0))
	value_label.position = Vector2(500, 40 + row * 65)
	value_label.size = Vector2(60, 30)
	parent.add_child(value_label)

	# 用 bind 直接绑定 value_label，不依赖子节点查找
	slider.value_changed.connect(func(v: float):
		value_label.text = str(int(v * 100)) + "%"
	)
	parent.add_child(slider)


func _create_back_button() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.18, 0.9)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.3, 0.35, 0.45, 1.0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.2, 0.22, 0.3, 1.0)
	sb_hover.border_width_left = 2
	sb_hover.border_width_right = 2
	sb_hover.border_width_top = 2
	sb_hover.border_width_bottom = 2
	sb_hover.border_color = Color(0.45, 0.5, 0.65, 1.0)
	sb_hover.corner_radius_top_left = 8
	sb_hover.corner_radius_top_right = 8
	sb_hover.corner_radius_bottom_left = 8
	sb_hover.corner_radius_bottom_right = 8

	var sb_pressed := StyleBoxFlat.new()
	sb_pressed.bg_color = Color(0.08, 0.09, 0.13, 1.0)
	sb_pressed.border_width_left = 2
	sb_pressed.border_width_right = 2
	sb_pressed.border_width_top = 2
	sb_pressed.border_width_bottom = 2
	sb_pressed.border_color = Color(0.25, 0.28, 0.35, 1.0)
	sb_pressed.corner_radius_top_left = 8
	sb_pressed.corner_radius_top_right = 8
	sb_pressed.corner_radius_bottom_left = 8
	sb_pressed.corner_radius_bottom_right = 8

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	vbox.position = Vector2(-150, -80)
	vbox.size = Vector2(300, 50)

	var btn := Button.new()
	btn.text = "返回主菜单"
	btn.custom_minimum_size = Vector2(300, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.75, 0.85, 1.0))
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.pressed.connect(_on_back_pressed)
	vbox.add_child(btn)
	add_child(vbox)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
