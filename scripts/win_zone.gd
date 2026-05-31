extends Area2D
class_name WinZone

## 胜利区域 —— 玩家到达后触发胜利

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _triggered:
		_triggered = true
		_trigger_win()


func _trigger_win() -> void:
	print("恭喜！你赢了！")

	# 暂停游戏逻辑（但不暂停 UI）
	get_tree().paused = true

	# 创建胜利UI（CanvasLayer 的 process_mode 设为 ALWAYS 可绕过暂停）
	var canvas := CanvasLayer.new()
	canvas.name = "WinCanvas"
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS

	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	# 主标题
	var title := Label.new()
	title.text = "你 获 胜 了 ！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-200, -80)
	title.size = Vector2(400, 60)
	canvas.add_child(title)

	# 副标题
	var subtitle := Label.new()
	subtitle.text = "按 Esc 返回主菜单"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	subtitle.set_anchors_preset(Control.PRESET_CENTER)
	subtitle.position = Vector2(-200, 0)
	subtitle.size = Vector2(400, 40)
	canvas.add_child(subtitle)

	# 返回主菜单按钮（用 VBoxContainer 居中）
	var btn_container := VBoxContainer.new()
	btn_container.set_anchors_preset(Control.PRESET_CENTER)
	btn_container.position = Vector2(-100, 50)
	btn_container.size = Vector2(200, 45)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.16, 0.22, 0.9)
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.4, 0.45, 0.55, 1.0)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.27, 0.35, 1.0)
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.border_color = Color(0.55, 0.6, 0.7, 1.0)
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6

	var btn := Button.new()
	btn.text = "返回主菜单"
	btn.custom_minimum_size = Vector2(200, 45)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_hover)
	var _return_to_menu := func():
		canvas.queue_free()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	btn.pressed.connect(_return_to_menu)
	btn_container.add_child(btn)
	canvas.add_child(btn_container)

	get_tree().root.add_child(canvas)

	# 用一个独立 Node 的 _process 轮询 Esc（PROCESS_MODE_ALWAYS 绕过暂停）
	var esc_watcher := Node.new()
	esc_watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	esc_watcher.ready.connect(func():
		# 等一帧让 Esc 松开再开始检测
		await get_tree().process_frame
	)
	esc_watcher.process_priority = 100
	esc_watcher.set_script(null)  # 用 set_script 动态加 _process
	# 使用 lambda 方式添加 process 回调
	canvas.add_child(esc_watcher)
	
	# 持续检测直到 canvas 被释放
	while is_instance_valid(canvas) and is_instance_valid(esc_watcher):
		await get_tree().process_frame
		if Input.is_key_pressed(KEY_ESCAPE):
			_return_to_menu.call()
			break
