# ============================================================
# LevelBase.gd - 关卡基类 (Node2D → LevelBase)
#
# 生命周期（严格顺序, 子类 _on_ready() 中先 super._on_ready()）:
#   _ready():
#     1. _apply_config()     → 应用 LevelConfig.bg_color
#     2. _setup_camera()     → pass (相机已移交 SmoothCamera, 见下方说明)
#     3. _setup_player()     → 若 player_ref 不存在则实例化 Player_Warrior.tscn
#     4. _setup_enemies()    → 遍历 enemy_spawn_points
#     5. _setup_triggers()   → 虚函数(子类可选)
#     6. GameManager.current_level = self
#     7. EventBus.emit(LEVEL_LOADED)
#     8. _on_ready()         → 【子类入口】
#
# 相机架构变更(v0.4.0):
#   _setup_camera() 不再创建 Camera2D。 SmoothCamera 作为子节点预置于:
#     - PlayerModule/Formal/Player_Warrior.tscn
#     - PlayerModule/Formal/Player_Warrior_Cyber.tscn
#     - PlayerModule/Formal/Player_Warrior_Lingnan.tscn
#   SmoothCamera 在自身 _ready() 中自动: bind_target + make_current + top_level + 安全默认limit
#   子类(Level_01)通过 _setup_camera_limits() 配置 limit 参数到已有 SmoothCamera
# ============================================================
extends Node2D
class_name LevelBase

@export var level_config: LevelConfig = null

# 关卡中的敌人出生点
@export var enemy_spawn_points: Array[Marker2D] = []

# 玩家出生点
@export var player_spawn_point: Marker2D = null

var _enemies_spawned: Array[Node2D] = []

# ---- 生命周期 ----

func _ready() -> void:
	_apply_config()
	_setup_camera()
	_setup_player()
	_setup_enemies()
	_setup_triggers()
	GameManager.current_level = self
	EventBus.emit(GlobalDefine.EventName.LEVEL_LOADED, { "level": self })
	_on_ready()

func _apply_config() -> void:
	if level_config and level_config.bg_color:
		RenderingServer.set_default_clear_color(level_config.bg_color)

func _setup_camera() -> void:
	# 相机管理已移交 SmoothCamera（Player_Warrior 预制体子节点）
	# SmoothCamera 在 _ready 中自动绑定目标 + make_current + top_level
	# 子类 Level_01 通过 _setup_camera_limits() 配置 limit 参数
	pass

func _setup_player() -> void:
	# 正式关卡自动生成玩家
	if GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		return  # 玩家已存在
	var player_path = "res://PlayerModule/Formal/Player_Warrior.tscn"
	if ResourceLoader.exists(player_path):
		var player = load(player_path).instantiate()
		var spawn_pos = level_config.spawn_point if level_config else Vector2(640, 500)
		player.position = spawn_pos
		add_child(player)
		GameManager.register_player(player)

func _setup_enemies() -> void:
	for spawn_point in enemy_spawn_points:
		if not is_instance_valid(spawn_point):
			continue
		var enemy = _spawn_enemy_at(spawn_point)
		if enemy:
			_enemies_spawned.append(enemy)

func _spawn_enemy_at(_spawn_point: Marker2D) -> Node2D:
	# 子类重写此方法实现敌人实例化
	return null

func _setup_triggers() -> void:
	# 子类重写此方法添加关卡触发区域
	pass

# ---- 公共方法 ----

## 在指定位置创建敌人
func spawn_enemy(enemy_scene_path: String, spawn_pos: Vector2) -> Node2D:
	if not ResourceLoader.exists(enemy_scene_path):
		print("[LevelBase] 敌人场景不存在: ", enemy_scene_path)
		return null

	var enemy = load(enemy_scene_path).instantiate()
	enemy.global_position = spawn_pos
	add_child(enemy)
	return enemy

## 创建简单的地面平台
func create_ground(pos: Vector2, size: Vector2, color: Color = Color(0.4, 0.4, 0.4)) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = GlobalDefine.Collision.TERRAIN

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var rect = ColorRect.new()
	rect.color = color
	rect.size = size
	rect.position = -size / 2
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(rect)

	add_child(body)
	return body

## 创建墙壁
func create_wall(pos: Vector2, size: Vector2, color: Color = Color(0.35, 0.35, 0.35)) -> StaticBody2D:
	return create_ground(pos, size, color)

# ---- 虚函数（子类重写点，不要修改基类源码） ----

func _on_ready() -> void:
	pass
