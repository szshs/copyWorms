extends Control
class_name MainMenu

## 主界面 —— 开始游戏、设置、退出


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.08, 1.0))
	_create_background()
	_create_title()
	_create_buttons()


func _create_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 背景装饰粒子
	for _i in range(40):
		var dot := ColorRect.new()
		dot.color = Color(1.0, 1.0, 1.0, randf_range(0.03, 0.12))
		dot.size = Vector2(randf_range(1.5, 3.5), randf_range(1.5, 3.5))
		dot.position = Vector2(randf_range(0, 1024), randf_range(0, 600))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)


func _create_title() -> void:
	var title := Label.new()
	title.text = "Hollow Knight Demo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1.0))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-300, 80)
	title.size = Vector2(600, 70)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A Small Adventure Awaits"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 1.0))
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-300, 150)
	subtitle.size = Vector2(600, 30)
	add_child(subtitle)


func _create_buttons() -> void:
	var button_style := _make_button_stylebox()

	# 使用 VBoxContainer 实现自动居中布局
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-150, -80)
	vbox.size = Vector2(300, 200)
	add_child(vbox)

	# 开始游戏按钮
	var start_btn := _create_button("开始游戏", button_style)
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

	# 设置按钮
	var settings_btn := _create_button("设  置", button_style)
	settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_btn)

	# 退出按钮
	var quit_btn := _create_button("退出游戏", button_style)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)


func _create_button(text: String, style: StyleBoxFlat) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 55)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.75, 0.85, 1.0))
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", _make_button_hover_stylebox())
	btn.add_theme_stylebox_override("pressed", _make_button_pressed_stylebox())
	return btn


func _make_button_stylebox() -> StyleBoxFlat:
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
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	return sb


func _make_button_hover_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.22, 0.3, 1.0)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.45, 0.5, 0.65, 1.0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	return sb


func _make_button_pressed_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.13, 1.0)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.25, 0.28, 0.35, 1.0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	return sb


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level.tscn")


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
