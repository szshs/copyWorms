extends "res://LevelModule/Formal/Level_fuzhan_memory_base.gd"
class_name LevelFuzhan01


func _init() -> void:
	area_index = 1
	spawn_node_path = ^"SpawnPoints/AtticSpawn"
	camera_limit_left = 0
	camera_limit_right = 5328
	camera_limit_top = -500
	camera_limit_bottom = 640
	camera_zoom = Vector2.ONE
	camera_lerp_speed = 2.5
	use_override_spawn_position = true
	override_spawn_position = Vector2(2264, 544)
	enemy_spawn_y = 540.0
	enemy_spawn_x_range = Vector2(260.0, 5100.0)
	drop_spawn_y = 560.0
	drop_spawn_x_range = Vector2(200.0, 5200.0)
	max_alive_enemies = 4
	enemy_spawn_interval = 3.0
