# res://LevelModule/SelfTest/MiniTestWorld.gd
# IDE 预览微型场景 - 自动向右行走，超出边界触发崩溃
extends Node2D

signal prototype_crashed


func _ready() -> void:
	_build_terrain()
	_create_test_runner()


func _build_terrain() -> void:
	# 地面 (Y=250, X 范围 0~450)
	_add_platform("Ground", Vector2(200, 250), Vector2(450, 20), Color(0.2, 0.5, 0.3))
	
	# 左墙
	_add_wall("LeftWall", Vector2(-10, 120), Vector2(20, 260), Color(0.15, 0.4, 0.25))


func _add_platform(name_str: String, pos: Vector2, size: Vector2, col: Color) -> void:
	var body = StaticBody2D.new()
	body.name = name_str
	body.position = pos
	body.collision_layer = GlobalDefine.Collision.TERRAIN
	
	var col_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	col_shape.shape = rect
	body.add_child(col_shape)
	
	var color_rect = ColorRect.new()
	color_rect.color = col
	color_rect.size = size
	color_rect.position = -size / 2
	body.add_child(color_rect)
	
	add_child(body)


func _add_wall(name_str: String, pos: Vector2, size: Vector2, col: Color) -> void:
	_add_platform(name_str, pos, size, col)


func _create_test_runner() -> void:
	var runner_scene = load("res://LevelModule/SelfTest/TestRunnerCharacter.tscn")
	if not runner_scene:
		printerr("[MiniTestWorld] 找不到 TestRunnerCharacter.tscn")
		# 降级：直接 emit 信号
		await get_tree().create_timer(2.0).timeout
		prototype_crashed.emit()
		return
	
	var runner = runner_scene.instantiate()
	runner.position = Vector2(50, 200)
	add_child(runner)
