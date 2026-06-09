# ============================================================
# Level_01_SceneBuilder.gd - 场景构建器
# 负责地形、交互物、出生点、Canvas UI 的创建
# 1920 像素宽横向地图（1.5 屏），客厅-走廊-卧室三段
# ============================================================
extends RefCounted
class_name Level_01_SceneBuilder

var level: Level_01

func _init(parent: Level_01) -> void:
	level = parent

func build_all() -> void:
	_build_terrain()
	_build_interactives()
	_build_spawn_points()
	_build_canvas_ui()

func _build_terrain() -> void:
	var terrain = level._get_or_create_child("Terrain", Node2D)
	# 主地面：1920 像素宽（1.5 屏）
	var ground = level._create_static_body("MainGround", Vector2(960, 620), Vector2(1920, 40), Color(0.12, 0.12, 0.15))
	terrain.add_child(ground)
	# 左/右墙
	var left_wall = level._create_static_body("LeftWall", Vector2(-10, 360), Vector2(20, 720), Color(0.1, 0.1, 0.12))
	terrain.add_child(left_wall)
	var right_wall = level._create_static_body("RightWall", Vector2(1930, 360), Vector2(20, 720), Color(0.1, 0.1, 0.12))
	terrain.add_child(right_wall)

func _build_interactives() -> void:
	var container = level._get_or_create_child("InteractiveObjects", Node2D)

	# --- 客厅 (50-550) ---
	# 1. 纸箱阻挡
	level._obstacle_box = level._create_interactive("Obstacle_Box", "box", Vector2(350, 560), Vector2(120, 80))
	level._add_physics_blocker(level._obstacle_box, Vector2(120, 80))
	container.add_child(level._obstacle_box)

	# --- 走廊 (550-1000) ---
	# 2. 脏衣阻挡
	level._obstacle_clothes = level._create_interactive("Obstacle_Clothes", "clothes", Vector2(750, 560), Vector2(100, 80))
	level._add_physics_blocker(level._obstacle_clothes, Vector2(100, 80))
	container.add_child(level._obstacle_clothes)

	# --- 卧室 (1000-1900) ---
	# 3. 休学告知书
	level._notice_node = level._create_interactive("Notice", "notice", Vector2(1100, 570), Vector2(40, 40))
	container.add_child(level._notice_node)

	# 4. 旧保温杯
	level._thermos_node = level._create_interactive("Thermos", "thermos", Vector2(1280, 580), Vector2(30, 40))
	container.add_child(level._thermos_node)

	# 5. 电脑（初始禁用，需与床交互4次后解锁）
	level._computer_node = level._create_interactive("Computer", "computer", Vector2(1470, 560), Vector2(100, 80))
	level._computer_node.is_active = false
	container.add_child(level._computer_node)

	# 6. 手机（初始禁用，IDE崩溃后启用）
	level._phone_node = level._create_interactive("Phone", "phone", Vector2(1660, 580), Vector2(50, 40))
	level._phone_node.is_active = false
	container.add_child(level._phone_node)

	# 7. 床 - 允许重复交互
	level._bed_node = level._create_interactive("Bed", "bed", Vector2(1830, 570), Vector2(160, 60))
	level._bed_node.allow_repeat = true
	container.add_child(level._bed_node)

func _build_spawn_points() -> void:
	var spawn_container = level._get_or_create_child("SpawnPoints", Node2D)
	var spawn_marker = Marker2D.new()
	spawn_marker.name = "PlayerSpawnPoint"
	spawn_marker.position = Vector2(100, 550)
	spawn_container.add_child(spawn_marker)
	level.player_spawn_point = spawn_marker

func _build_canvas_ui() -> void:
	var canvas = level._get_or_create_child("CanvasLayerUI", CanvasLayer)
	canvas.layer = 2
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS

	var ui_builder = Level_01_UIBuilder.new(level, canvas)
	ui_builder.build_all()
