# ============================================================
# PlayerTest.gd - 玩家模块自测场景
# 自带简易地形，自动生成玩家和小怪，可独立运行
# 含外观切换按钮
# ============================================================
extends Node2D

var _current_player: Player_Warrior = null
var _skin_index: int = 0
var _skin_list: Array = [
	{ "name": "原版",  "path": "res://PlayerModule/Formal/Player_Warrior.tscn" },
	{ "name": "赛博",  "path": "res://PlayerModule/Formal/Player_Warrior_Cyber.tscn" },
	{ "name": "岭南",  "path": "res://PlayerModule/Formal/Player_Warrior_Lingnan.tscn" },
]
var _switch_btn: Button = null
var _refresh_enemy_btn: Button = null
var _switch_enemy_btn: Button = null
var _player_camera: Camera2D = null

# 怪物类型列表
var _enemy_index: int = 0
var _enemy_list: Array = [
	{ "name": "史莱姆",    "scene": "res://EnemyModule/Formal/Enemy_Slime.tscn",         "config": "res://DataConfig/Enemy/SlimeConfig.tres" },
	{ "name": "纸符人",    "scene": "res://EnemyModule/Formal/Enemy_PaperEffigy.tscn",   "config": "res://DataConfig/Enemy/PaperEffigyConfig.tres" },
	{ "name": "灯笼鬼",    "scene": "res://EnemyModule/Formal/Enemy_LanternGhost.tscn",  "config": "res://DataConfig/Enemy/LanternGhostConfig.tres" },
	{ "name": "赛博狼人",  "scene": "res://EnemyModule/Formal/Enemy_CyberWolf.tscn",     "config": "res://DataConfig/Enemy/CleanerConfig.tres" },
	{ "name": "赛博冲撞兽", "scene": "res://EnemyModule/Formal/Enemy_CyberBull.tscn",    "config": "res://DataConfig/Enemy/CyberBullConfig.tres" },
]
var _spawned_enemies: Array = []  # 当前场景中的怪物实例

func _ready() -> void:
	GameManager.run_mode = GlobalDefine.RunMode.SELF_TEST
	print("[PlayerTest] 玩家模块自测场景启动")

	_build_terrain()
	_spawn_player()
	_spawn_test_enemies()
	_load_hud()
	_build_debug_buttons()

func _build_terrain() -> void:
	_create_platform(Vector2(640, 620), Vector2(1280, 80), Color(0.35, 0.35, 0.4))
	_create_platform(Vector2(200, 460), Vector2(200, 20), Color(0.4, 0.4, 0.45))
	_create_platform(Vector2(1000, 460), Vector2(200, 20), Color(0.4, 0.4, 0.45))
	_create_platform(Vector2(600, 320), Vector2(300, 20), Color(0.4, 0.4, 0.45))
	_create_platform(Vector2(0, 360), Vector2(20, 720), Color(0.3, 0.3, 0.35))
	_create_platform(Vector2(1280, 360), Vector2(20, 720), Color(0.3, 0.3, 0.35))

func _create_platform(pos: Vector2, size: Vector2, color: Color) -> void:
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

func _spawn_player() -> void:
	_current_player = _create_player_instance(_skin_index, Vector2(200, 550))

	_player_camera = Camera2D.new()
	_player_camera.enabled = true
	_player_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_player_camera.limit_left = 0
	_player_camera.limit_right = 1280
	_player_camera.limit_top = -1000
	_player_camera.limit_bottom = 1000
	_current_player.add_child(_player_camera)

func _create_player_instance(skin_idx: int, pos: Vector2) -> Player_Warrior:
	var skin = _skin_list[skin_idx]
	var player: Player_Warrior = null
	if ResourceLoader.exists(skin["path"]):
		player = load(skin["path"]).instantiate() as Player_Warrior
	if not player:
		player = Player_Warrior.new()
	player.config = load("res://DataConfig/Player/WarriorConfig.tres") as PlayerConfig
	player.position = pos
	add_child(player)
	GameManager.register_player(player)
	return player

func _spawn_test_enemies() -> void:
	# 清理旧怪物
	for e in _spawned_enemies:
		if is_instance_valid(e):
			e.queue_free()
	_spawned_enemies.clear()

	var enemy_data = _enemy_list[_enemy_index]
	var config: EnemyConfig = load(enemy_data["config"]) as EnemyConfig

	var positions = [Vector2(600, 588), Vector2(900, 588)]
	for pos in positions:
		var enemy: EnemyBase = null
		if ResourceLoader.exists(enemy_data["scene"]):
			enemy = load(enemy_data["scene"]).instantiate() as EnemyBase
		if not enemy:
			continue
		enemy.config = config
		enemy.position = pos
		add_child(enemy)
		_spawned_enemies.append(enemy)

func _load_hud() -> void:
	var hud_path = "res://UI/HUD.tscn"
	if ResourceLoader.exists(hud_path):
		var hud = load(hud_path).instantiate()
		add_child(hud)

func _build_debug_buttons() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "DebugButtonCanvas"
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	# 切换外观按钮
	_switch_btn = Button.new()
	_switch_btn.text = "切换外观: " + _skin_list[_skin_index]["name"]
	_switch_btn.position = Vector2(1120, 60)
	_switch_btn.size = Vector2(140, 36)
	_switch_btn.add_theme_font_size_override("font_size", 14)
	_switch_btn.focus_mode = Control.FOCUS_NONE
	_switch_btn.pressed.connect(_on_switch_skin)
	canvas.add_child(_switch_btn)

	# 刷新怪物按钮
	_refresh_enemy_btn = Button.new()
	_refresh_enemy_btn.text = "刷新怪物"
	_refresh_enemy_btn.position = Vector2(1120, 100)
	_refresh_enemy_btn.size = Vector2(140, 36)
	_refresh_enemy_btn.add_theme_font_size_override("font_size", 14)
	_refresh_enemy_btn.focus_mode = Control.FOCUS_NONE
	_refresh_enemy_btn.pressed.connect(_on_refresh_enemies)
	canvas.add_child(_refresh_enemy_btn)

	# 切换怪物按钮
	_switch_enemy_btn = Button.new()
	_switch_enemy_btn.text = "切换怪物: " + _enemy_list[_enemy_index]["name"]
	_switch_enemy_btn.position = Vector2(1120, 140)
	_switch_enemy_btn.size = Vector2(140, 36)
	_switch_enemy_btn.add_theme_font_size_override("font_size", 14)
	_switch_enemy_btn.focus_mode = Control.FOCUS_NONE
	_switch_enemy_btn.pressed.connect(_on_switch_enemy)
	canvas.add_child(_switch_enemy_btn)

func _on_switch_skin() -> void:
	if not is_instance_valid(_current_player):
		return

	_skin_index = (_skin_index + 1) % _skin_list.size()

	var old_pos = _current_player.global_position

	# 先摘摄像机
	if _player_camera and _player_camera.get_parent():
		_player_camera.get_parent().remove_child(_player_camera)

	# 销毁旧玩家
	_current_player.queue_free()
	_current_player = null
	GameManager.player_ref = null

	# 创建新玩家
	_current_player = _create_player_instance(_skin_index, old_pos)
	_current_player.add_child(_player_camera)

	_switch_btn.text = "切换外观: " + _skin_list[_skin_index]["name"]

func _on_refresh_enemies() -> void:
	_spawn_test_enemies()

func _on_switch_enemy() -> void:
	_enemy_index = (_enemy_index + 1) % _enemy_list.size()
	_switch_enemy_btn.text = "切换怪物: " + _enemy_list[_enemy_index]["name"]
	_spawn_test_enemies()
