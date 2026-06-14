# ============================================================
# Level_02_SceneBuilder.gd - 关卡2场景构建器
# 单场景双空间容器架构:
#   DreamWorldRoot  — 梦境: 阁楼(0-424) / 老街(424-5416) / 断崖(5416+)
#   RealityRoomRoot — 现实房间: 复用关卡1布局参数（宽1920, 地面Y=620), 初始隐藏
# 另构建: 交互物 / 触发器 / 出生点 / CanvasLayerUI
# 只创建节点并写入主控字段，不处理流程
# ============================================================
extends RefCounted
class_name Level_02_SceneBuilder

var level: Level_02

func _init(parent: Level_02) -> void:
	level = parent

func build_all() -> void:
	_build_dream_world()
	_build_reality_room()
	_build_interactives()
	_build_triggers()
	_build_spawn_points()
	_build_dynamic_actors_container()
	_build_canvas_ui()

# ============================================================
# 梦境世界
# ============================================================

func _build_dream_world() -> void:
	var dream = level._get_or_create_child("DreamWorldRoot", Node2D)
	level._dream_root = dream

	# ---- A 阁楼 (0-424) ----
	dream.add_child(level._create_static_body("MainAtticFloor", Vector2(212, 620), Vector2(424, 40)))
	dream.add_child(level._create_static_body("AtticLeftWall", Vector2(-10, 360), Vector2(20, 720)))
	var door_wall = level._create_static_body("AtticDoorWall", Vector2(424, 424), Vector2(30, 400))
	dream.add_child(door_wall)
	level._attic_door_wall = door_wall

	# ---- B 老街 (424-5416) ----
	dream.add_child(level._create_static_body("StreetGround", Vector2(2920, 620), Vector2(4992, 40)))

	# ---- C 老街右端墙壁 (5416-5512) ----
	dream.add_child(level._create_static_body("StreetRightWall", Vector2(5464, 540), Vector2(96, 200)))

	# ---- D 断崖深渊 (5520-5896，无碰撞，玩家可坠落) ----

	# ---- E 断崖右端墙壁 (5896-6192) ----
	dream.add_child(level._create_static_body("CliffRightWall", Vector2(6044, 480), Vector2(296, 320)))

# ============================================================
# 现实房间（复用关卡1布局参数, 初始隐藏, 整体灰暗化）
# ============================================================

func _build_reality_room() -> void:
	var reality = level._get_or_create_child("RealityRoomRoot", Node2D)
	level._reality_root = reality

	# 主地面 + 左右墙（与关卡1坐标一致）
	reality.add_child(level._create_static_body("RealityGround", Vector2(960, 620), Vector2(1920, 40)))
	reality.add_child(level._create_static_body("RealityLeftWall", Vector2(-10, 360), Vector2(20, 720)))
	reality.add_child(level._create_static_body("RealityRightWall", Vector2(1930, 360), Vector2(20, 720)))

	# 整体灰暗化
	reality.modulate = Color(0.65, 0.65, 0.7)
	# 初始隐藏 + 物理禁用（防止与梦境地形在同坐标系下冲突）
	reality.visible = false

# ============================================================
# 交互物（6 个）
# ============================================================

func _build_interactives() -> void:
	var container = level._get_or_create_child("InteractiveObjects", Node2D)

	# ---- 梦境交互物 ----
	# 1. 五彩满洲窗（阁楼）
	level._window_node = level._create_interactive("Window_L2", "window_l2", Vector2(304, 552), Vector2(110, 130))
	var win_indicator = level._window_node.get_node_or_null("Indicator")
	if win_indicator:
		win_indicator.queue_free()
	level._window_node.prompt_text = "按 Enter 观察"
	container.add_child(level._window_node)

	# 2. 木趟栊门（阁楼 → 老街）
	level._attic_door_node = level._create_interactive("AtticDoor", "attic_door", Vector2(424, 500), Vector2(60, 160))
	var door_indicator = level._attic_door_node.get_node_or_null("Indicator")
	if door_indicator:
		door_indicator.queue_free()
	level._attic_door_node.prompt_text = "按 Enter 推开"
	container.add_child(level._attic_door_node)

	# 3. 杂货店（老街，无碰撞阻挡）
	level._rattan_chair_node = level._create_interactive("GroceryStore", "rattan_chair", Vector2(880, 552), Vector2(80, 50))
	var chair_indicator = level._rattan_chair_node.get_node_or_null("Indicator")
	if chair_indicator:
		chair_indicator.queue_free()
	level._rattan_chair_node.prompt_text = "按 Enter 回忆"
	container.add_child(level._rattan_chair_node)

	# ---- 现实交互物（初始全部不可见/不激活, 随 RealityRoomRoot 显示再启用） ----
	# 4. 现实手机（睁眼后唯一激活）
	level._reality_phone_node = level._create_interactive("RealityPhone", "reality_phone", Vector2(1660, 580), Vector2(50, 40))
	level._reality_phone_node.is_active = false
	level._reality_phone_node.visible = false
	level._reality_phone_node.prompt_text = "按 Enter 查看"
	container.add_child(level._reality_phone_node)

	# 5. 电脑（读完短信后解锁）
	level._reality_computer_node = level._create_interactive("RealityComputer", "reality_computer", Vector2(1470, 560), Vector2(100, 80))
	level._reality_computer_node.is_active = false
	level._reality_computer_node.visible = false
	level._reality_computer_node.prompt_text = "按 Enter 使用"
	container.add_child(level._reality_computer_node)

	# 6. 单人床（重编译完成后解锁）
	level._reality_bed_node = level._create_interactive("RealityBed", "reality_bed", Vector2(1830, 570), Vector2(160, 60))
	level._reality_bed_node.is_active = false
	level._reality_bed_node.visible = false
	level._reality_bed_node.prompt_text = "按 Enter 入梦"
	container.add_child(level._reality_bed_node)

# ============================================================
# 非交互触发器（Area2D, collision_layer=0, mask=PLAYER）
# ============================================================

func _build_triggers() -> void:
	var container = level._get_or_create_child("TriggerZones", Node2D)

	# 1. 老街进入触发（一次性: 状态推进 ATTIC → STREET）
	level._street_entry_trigger = _create_trigger_zone("StreetEntryTrigger", Vector2(500, 460), Vector2(80, 360))
	container.add_child(level._street_entry_trigger)
	level._street_entry_trigger.body_entered.connect(level._on_street_entry_body_entered)

	# 2. 断崖接近触发（一次性: 进入 DREAM_CLIFF_LOOP + 首见独白）
	level._cliff_approach_trigger = _create_trigger_zone("CliffApproachTrigger", Vector2(5500, 460), Vector2(80, 360))
	container.add_child(level._cliff_approach_trigger)
	level._cliff_approach_trigger.body_entered.connect(level._on_cliff_approach_body_entered)

	# 3. 坠落深渊触发（可重复: 黑屏重置）
	level._fall_pit_trigger = _create_trigger_zone("FallPitTrigger", Vector2(5708, 608), Vector2(376, 64))
	container.add_child(level._fall_pit_trigger)
	level._fall_pit_trigger.body_entered.connect(level._on_fall_pit_body_entered)

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

# ============================================================
# 出生点
# ============================================================

func _build_spawn_points() -> void:
	var container = level._get_or_create_child("SpawnPoints", Node2D)

	var attic_spawn = Marker2D.new()
	attic_spawn.name = "AtticSpawn"
	attic_spawn.position = Vector2(140, 550)
	container.add_child(attic_spawn)
	level.player_spawn_point = attic_spawn

	var cliff_safe = Marker2D.new()
	cliff_safe.name = "CliffSafeSpawn"
	cliff_safe.position = level.level_data.cliff_safe_spawn if level.level_data else Vector2(2240, 576)
	container.add_child(cliff_safe)
	level._cliff_safe_spawn = cliff_safe

	var reality_spawn = Marker2D.new()
	reality_spawn.name = "RealitySpawn"
	reality_spawn.position = Vector2(1830, 550)
	container.add_child(reality_spawn)
	level._reality_spawn = reality_spawn

# ============================================================
# 动态敌人容器
# ============================================================

func _build_dynamic_actors_container() -> void:
	var actors = level._get_or_create_child("DynamicActors", Node2D)
	level._dynamic_actors = actors

# ============================================================
# Canvas UI
# ============================================================

func _build_canvas_ui() -> void:
	var canvas = level._get_or_create_child("CanvasLayerUI", CanvasLayer)
	canvas.layer = 2
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS

	var ui_builder = Level_02_UIBuilder.new(level, canvas)
	ui_builder.build_all()
