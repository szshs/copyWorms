extends "res://LevelModule/Formal/Level_fuzhan_memory_base.gd"
class_name LevelFuzhan02


func _apply_area_configuration() -> void:
	area_index = 2
	spawn_node_path = ^"SpawnPoints/SegmentSpawn"
	camera_limit_left = 0
	camera_limit_right = 4474
	camera_limit_top = 56
	camera_limit_bottom = 616
	camera_zoom = Vector2(1.5, 1.5)
	camera_lerp_speed = 2.5
	use_override_spawn_position = true
	override_spawn_position = Vector2(1816, 512)
	enemy_spawn_y = 540.0
	enemy_spawn_x_range = Vector2(220.0, 4300.0)
	drop_spawn_y = 560.0
	drop_spawn_y_range = Vector2(360.0, 536.0)
	drop_spawn_x_range = Vector2(1800.0, 4300.0)
	max_alive_enemies = 4
	enemy_spawn_interval = 3.0


func _validate_area_configuration() -> void:
	super._validate_area_configuration()
	drop_spawn_x_range = Vector2(1800.0, 4300.0)
