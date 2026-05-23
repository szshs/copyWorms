extends Node2D
class_name Level

## 关卡管理器 —— 构建地图、生成玩家与敌人


# 关卡数据：平台定义 {pos, size, color}
var platforms_data: Array[Dictionary] = [
	# 起始地面
	{"pos": Vector2(-400, 250), "size": Vector2(800, 40), "color": Color(0.25, 0.25, 0.3, 1.0)},
	# 第一个平台
	{"pos": Vector2(100, 180), "size": Vector2(200, 24), "color": Color(0.3, 0.28, 0.35, 1.0)},
	# 中间地面（有间隔）
	{"pos": Vector2(200, 250), "size": Vector2(300, 40), "color": Color(0.25, 0.25, 0.3, 1.0)},
	# 小平台（跳过间隔）
	{"pos": Vector2(520, 180), "size": Vector2(160, 24), "color": Color(0.3, 0.28, 0.35, 1.0)},
	# 继续地面
	{"pos": Vector2(600, 250), "size": Vector2(400, 40), "color": Color(0.25, 0.25, 0.3, 1.0)},
	# 高台
	{"pos": Vector2(700, 120), "size": Vector2(180, 24), "color": Color(0.35, 0.32, 0.4, 1.0)},
	# 中段地面
	{"pos": Vector2(1050, 250), "size": Vector2(400, 40), "color": Color(0.25, 0.25, 0.3, 1.0)},
	# 双层平台
	{"pos": Vector2(1150, 140), "size": Vector2(160, 24), "color": Color(0.3, 0.28, 0.35, 1.0)},
	{"pos": Vector2(1200, 60), "size": Vector2(120, 24), "color": Color(0.35, 0.32, 0.4, 1.0)},
	# 后段地面
	{"pos": Vector2(1500, 250), "size": Vector2(600, 40), "color": Color(0.25, 0.25, 0.3, 1.0)},
	# 最后一段平台
	{"pos": Vector2(1700, 170), "size": Vector2(200, 24), "color": Color(0.3, 0.28, 0.35, 1.0)},
	# 终点区域地面
	{"pos": Vector2(2150, 250), "size": Vector2(600, 40), "color": Color(0.25, 0.25, 0.3, 1.0)},
	# 胜利前的小平台
	{"pos": Vector2(2400, 140), "size": Vector2(160, 24), "color": Color(0.35, 0.32, 0.4, 1.0)},
	# 最终地面（绿色提示终点）
	{"pos": Vector2(2650, 250), "size": Vector2(400, 40), "color": Color(0.2, 0.35, 0.25, 1.0)},
]

# 敌人出生点
var enemy_spawns: Array[Vector2] = [
	Vector2(100, 210),
	Vector2(420, 210),
	Vector2(750, 210),
	Vector2(1100, 210),
	Vector2(1600, 210),
	Vector2(1900, 210),
	Vector2(2300, 210),
]

# 胜利区域位置
var win_zone_pos := Vector2(2900, 220)

# 玩家出生点
var player_spawn := Vector2(-300, 200)

# 运行时引用
var player_ref: Player = null
var hud_health_label: Label
var hud_hint_label: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.08, 1.0))

	_create_background()
	_create_platforms()
	_spawn_player()
	_spawn_enemies()
	_create_win_zone()
	_create_hud()


func _create_background() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = -10

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)

	# 背景装饰粒子
	for _i in range(30):
		var dot := ColorRect.new()
		dot.color = Color(1.0, 1.0, 1.0, randf_range(0.05, 0.2))
		dot.size = Vector2(randf_range(1.5, 3.0), randf_range(1.5, 3.0))
		dot.position = Vector2(randf_range(-500, 3200), randf_range(-100, 500))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(dot)

	add_child(canvas)


func _create_platforms() -> void:
	for data in platforms_data:
		var platform := _create_platform(data["pos"], data["size"], data["color"])
		add_child(platform)


func _create_platform(pos: Vector2, size: Vector2, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos

	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	collision.shape = rect
	body.add_child(collision)

	var sprite := Sprite2D.new()
	sprite.position = Vector2.ZERO
	var img := Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	img.fill(color)
	var border_color := color.lightened(0.15)
	for x in range(int(size.x)):
		img.set_pixel(x, 0, border_color)
		img.set_pixel(x, 1, border_color)
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.centered = true
	body.add_child(sprite)

	return body


func _spawn_player() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	if player_scene:
		player_ref = player_scene.instantiate()
		player_ref.position = player_spawn
		player_ref.health_changed.connect(_on_player_health_changed)
		player_ref.player_died.connect(_on_player_died)
		add_child(player_ref)
	else:
		push_error("无法加载玩家场景!")


func _spawn_enemies() -> void:
	var enemy_scene := load("res://scenes/enemy.tscn") as PackedScene
	if not enemy_scene:
		push_error("无法加载敌人场景!")
		return

	for spawn_pos in enemy_spawns:
		var enemy := enemy_scene.instantiate()
		enemy.position = spawn_pos
		add_child(enemy)


func _create_win_zone() -> void:
	var zone := Area2D.new()
	zone.name = "WinZone"
	zone.position = win_zone_pos

	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 100)
	collision.shape = rect
	zone.add_child(collision)

	var sprite := Sprite2D.new()
	sprite.position = Vector2.ZERO
	var img := Image.create(60, 100, false, Image.FORMAT_RGBA8)
	for x in range(60):
		for y in range(100):
			var dx := float(x - 30) / 28.0
			var alpha: float = maxf(0.0, 0.5 - dx * dx)
			if alpha > 0:
				img.set_pixel(x, y, Color(0.3, 1.0, 0.4, alpha))
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex
	sprite.centered = true
	zone.add_child(sprite)

	var script := load("res://scripts/win_zone.gd") as Script
	if script:
		zone.set_script(script)

	add_child(zone)


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	canvas.layer = 10

	# 操作提示
	hud_hint_label = Label.new()
	hud_hint_label.text = "[WASD] 移动  [空格] 跳跃  [鼠标左键] 攻击  → 向右前进到达绿色终点!"
	hud_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_hint_label.add_theme_font_size_override("font_size", 13)
	hud_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.7))
	hud_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_hint_label.position = Vector2(0, 8)
	canvas.add_child(hud_hint_label)

	# 生命值显示
	hud_health_label = Label.new()
	hud_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_health_label.add_theme_font_size_override("font_size", 20)
	hud_health_label.add_theme_color_override("font_color", Color.WHITE)
	hud_health_label.position = Vector2(12, 8)
	hud_health_label.text = _format_health(5, 5)
	canvas.add_child(hud_health_label)

	add_child(canvas)


func _format_health(current: int, maximum: int) -> String:
	var text := ""
	for i in range(maximum):
		if i < current:
			text += "♥ "
		else:
			text += "♡ "
	return text.strip_edges()


func _on_player_health_changed(new_health: int, max_hp: int) -> void:
	hud_health_label.text = _format_health(new_health, max_hp)


func _on_player_died() -> void:
	# 死亡提示
	var canvas := CanvasLayer.new()
	canvas.name = "DeathOverlay"
	canvas.layer = 90

	var bg := ColorRect.new()
	bg.color = Color(0.8, 0.1, 0.1, 0.35)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var label := Label.new()
	label.text = "你 死 了"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.RED)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(-150, -30)
	label.size = Vector2(300, 60)
	canvas.add_child(label)

	add_child(canvas)
