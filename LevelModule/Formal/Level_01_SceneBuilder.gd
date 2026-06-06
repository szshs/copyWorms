# ============================================================
# Level_01_SceneBuilder.gd - 场景构建器
# 负责地形、交互物、出生点、Canvas UI 的创建
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
	var ground = level._create_static_body("MainGround", Vector2(750, 620), Vector2(1500, 40), Color(0.3, 0.28, 0.25))
	terrain.add_child(ground)
	var left_wall = level._create_static_body("LeftWall", Vector2(-20, 360), Vector2(20, 720), Color(0.25, 0.23, 0.2))
	terrain.add_child(left_wall)
	var right_wall = level._create_static_body("RightWall", Vector2(1520, 360), Vector2(20, 720), Color(0.25, 0.23, 0.2))
	terrain.add_child(right_wall)

func _build_interactives() -> void:
	var container = level._get_or_create_child("InteractiveObjects", Node2D)

	level._obstacle_box = level._create_interactive("Obstacle_Box", "box", Vector2(500, 580), Vector2(120, 80))
	level._add_physics_blocker(level._obstacle_box, Vector2(120, 80))
	container.add_child(level._obstacle_box)

	level._obstacle_clothes = level._create_interactive("Obstacle_Clothes", "clothes", Vector2(850, 580), Vector2(100, 80))
	level._add_physics_blocker(level._obstacle_clothes, Vector2(100, 80))
	container.add_child(level._obstacle_clothes)

	level._bed_node = level._create_interactive("Bed", "bed", Vector2(1300, 580), Vector2(160, 60))
	level._bed_node.allow_repeat = true
	container.add_child(level._bed_node)

	level._computer_node = level._create_interactive("Computer", "computer", Vector2(1100, 550), Vector2(80, 60))
	container.add_child(level._computer_node)

	level._phone_node = level._create_interactive("Phone", "phone", Vector2(1050, 570), Vector2(50, 40))
	level._phone_node.is_active = false
	container.add_child(level._phone_node)

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
