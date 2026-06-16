extends LevelBase
class_name Level_02_02

@export var next_level_path: String = "res://LevelModule/Formal/Level_03.tscn"
@export var map_left: int = 0
@export var map_right: int = 4096
@export var map_top: int = -3456
@export var map_bottom: int = 640
@export var segment_spawn_position: Vector2 = Vector2(384, 384)
@export var exit_trigger_position: Vector2 = Vector2(3890, -2520)
@export var exit_trigger_size: Vector2 = Vector2(180, 260)

const CAMERA_ZOOM: Vector2 = Vector2(2, 2)
const CAMERA_LERP_SPEED: float = 2.5

var _exit_trigger: Area2D = null
var _dynamic_actors: Node2D = null
var _level_complete_emitted: bool = false


func _setup_player() -> void:
	if GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		return
	var player_path: String = level_config.player_scene_path if level_config else "res://PlayerModule/Formal/Player_Warrior_Lingnan.tscn"
	if not ResourceLoader.exists(player_path):
		push_warning("[Level_02_02] 玩家场景不存在: %s" % player_path)
		return
	var player = load(player_path).instantiate()
	player.top_level = true
	player.scale = Vector2.ONE
	add_child(player)
	player.global_position = _get_spawn_global_position()
	GameManager.register_player(player)


func _on_ready() -> void:
	super._on_ready()

	_bind_spawn_point()
	_setup_camera_limits()
	_ensure_player_collision_layer()
	_build_exit_trigger()
	_build_dynamic_actors_container()
	_load_hud()
	print("[Level_02_02] 初始化完成")


func _setup_camera_limits() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	var cam = player.get_node_or_null("SmoothCamera") as SmoothCamera
	if not cam:
		return
	var limits = _get_global_camera_limits()
	cam.limit_left = limits["left"]
	cam.limit_right = limits["right"]
	cam.limit_top = limits["top"]
	cam.limit_bottom = limits["bottom"]
	cam.zoom = CAMERA_ZOOM
	cam.offset = Vector2.ZERO
	cam.lerp_speed = CAMERA_LERP_SPEED
	cam.bind_target(player)


func _load_hud() -> void:
	var hud_path = "res://UI/HUD.tscn"
	if ResourceLoader.exists(hud_path):
		var hud = load(hud_path).instantiate()
		add_child(hud)
		print("[Level_02_02] HUD 加载成功")
	else:
		push_warning("[Level_02_02] HUD.tscn 未找到，跳过")


func _ensure_player_collision_layer() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	if not (player.collision_layer & GlobalDefine.Collision.PLAYER):
		player.collision_layer |= GlobalDefine.Collision.PLAYER


func _bind_spawn_point() -> void:
	var container = _get_or_create_child("SpawnPoints", Node2D)
	var spawn = container.get_node_or_null("SegmentSpawn") as Marker2D
	if not spawn:
		spawn = Marker2D.new()
		spawn.name = "SegmentSpawn"
		container.add_child(spawn)
	spawn.position = segment_spawn_position
	player_spawn_point = spawn


func _get_spawn_position() -> Vector2:
	var spawn = get_node_or_null("SpawnPoints/SegmentSpawn") as Marker2D
	if spawn:
		return spawn.position
	return segment_spawn_position


func _get_spawn_global_position() -> Vector2:
	# The level root may be scaled to fit authored background art. Runtime actors
	# stay top-level so their render size is not affected by that map transform.
	return to_global(_get_spawn_position())


func _get_global_camera_limits() -> Dictionary:
	var top_left = to_global(Vector2(map_left, map_top))
	var bottom_right = to_global(Vector2(map_right, map_bottom))
	return {
		"left": int(floor(min(top_left.x, bottom_right.x))),
		"right": int(ceil(max(top_left.x, bottom_right.x))),
		"top": int(floor(min(top_left.y, bottom_right.y))),
		"bottom": int(ceil(max(top_left.y, bottom_right.y))),
	}


func _build_exit_trigger() -> void:
	var container = _get_or_create_child("TriggerZones", Node2D)
	_exit_trigger = _ensure_trigger_zone(container, "Level0202ExitTrigger", exit_trigger_position, exit_trigger_size)
	if not _exit_trigger.body_entered.is_connected(_on_exit_trigger_body_entered):
		_exit_trigger.body_entered.connect(_on_exit_trigger_body_entered)


func _build_dynamic_actors_container() -> void:
	_dynamic_actors = _get_or_create_child("DynamicActors", Node2D) as Node2D


func _get_or_create_child(node_name: String, node_type: Variant) -> Node:
	var existing = get_node_or_null(node_name)
	if existing:
		return existing
	var node = node_type.new()
	node.name = node_name
	add_child(node)
	return node


func _create_trigger_zone(zone_name: String, pos: Vector2, size: Vector2) -> Area2D:
	var area = Area2D.new()
	area.name = zone_name
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = GlobalDefine.Collision.PLAYER
	area.monitoring = true
	area.monitorable = false
	var col = CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	return area


func _ensure_trigger_zone(container: Node, zone_name: String, pos: Vector2, size: Vector2) -> Area2D:
	var area = container.get_node_or_null(zone_name) as Area2D
	if area:
		area.position = pos
		var col = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col and col.shape is RectangleShape2D:
			col.shape.size = size
		return area
	area = _create_trigger_zone(zone_name, pos, size)
	container.add_child(area)
	return area


func _on_exit_trigger_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	_emit_level_complete()


func _is_player_body(body: Node2D) -> bool:
	if not body is CharacterBody2D:
		return false
	if body.collision_layer & GlobalDefine.Collision.PLAYER:
		return true
	return body.is_in_group("player")


func _emit_level_complete() -> void:
	if _level_complete_emitted:
		return
	_level_complete_emitted = true
	get_viewport().gui_release_focus()
	InputManager.force_unblock_all()
	EventBus.unsubscribe_all(self)
	if next_level_path == "":
		print("[Level_02_02] 下一关路径为空，停留在当前关卡")
		return
	if not _is_loaded_under_main_entry():
		print("[Level_02_02] 无 MainEntry，直接切换场景 → ", next_level_path)
		var err = get_tree().change_scene_to_file(next_level_path)
		if err != OK:
			push_warning("[Level_02_02] 直接切换失败: %s (err=%d)" % [next_level_path, err])
		return
	print("[Level_02_02] 发射 LEVEL_COMPLETE → ", next_level_path)
	EventBus.emit(GlobalDefine.EventName.LEVEL_COMPLETE, {
		"level": self,
		"next_level": next_level_path,
	})


func _is_loaded_under_main_entry() -> bool:
	var node = get_parent()
	while node:
		if node.name == "MainEntry":
			return true
		node = node.get_parent()
	return false
