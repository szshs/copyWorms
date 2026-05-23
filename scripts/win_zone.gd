extends Area2D
class_name WinZone

## 胜利区域 —— 玩家到达后触发胜利


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_trigger_win()


func _trigger_win() -> void:
	print("恭喜！你赢了！")

	# 暂停游戏
	get_tree().paused = true

	# 创建胜利UI
	var canvas := CanvasLayer.new()
	canvas.name = "WinCanvas"
	canvas.layer = 100

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
	subtitle.text = "按 R 键重新开始游戏"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	subtitle.set_anchors_preset(Control.PRESET_CENTER)
	subtitle.position = Vector2(-200, 0)
	subtitle.size = Vector2(400, 40)
	canvas.add_child(subtitle)

	get_tree().root.add_child(canvas)

	# 监听R键重新开始
	_restart_listener(canvas)


func _restart_listener(canvas: CanvasLayer) -> void:
	while is_instance_valid(canvas):
		await get_tree().process_frame
		if Input.is_key_pressed(KEY_R):
			canvas.queue_free()
			get_tree().paused = false
			get_tree().reload_current_scene()
			break
