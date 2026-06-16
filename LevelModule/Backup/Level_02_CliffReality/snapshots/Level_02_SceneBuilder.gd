# ============================================================
# Level_02_SceneBuilder.gd - 关卡2场景构建器
# 单场景双空间容器架构:
#   DreamWorldRoot  — 梦境: 阁楼(0-424) / 老街(424-4552) / 断崖(4552+)
#   RealityRoomRoot — 现实房间: 实例化 Level_02_sub01.tscn, 初始隐藏
# 另构建: 交互物 / 触发器 / 出生点 / CanvasLayerUI
# 只创建节点并写入主控字段，不处理流程
# ============================================================
extends RefCounted

var level: Level_02
const REALITY_ROOM_SCENE_PATH: String = "res://LevelModule/Formal/Level_02_sub01.tscn"

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

	# ---- B 老街 (424-4552) ----
	dream.add_child(level._create_static_body("StreetGround", Vector2(2488, 620), Vector2(4128, 40)))

	# ---- C 老街右端墙壁 (4552-4648) ----
	dream.add_child(level._create_static_body("StreetRightWall", Vector2(4600, 540), Vector2(96, 200)))

	# ---- D 断崖深渊 (4656-5032，无碰撞，玩家可坠落) ----

	# ---- E 断崖右端墙壁 (5032-5328) ----
	dream.add_child(level._create_static_body("CliffRightWall", Vector2(5180, 480), Vector2(296, 320)))

	# Level_02.tscn 里预置的梦境 Pixelwork 地图挂在根节点，需收进 DreamWorldRoot，
	# 否则睁眼切现实时 _dream_root.visible=false 无法隐藏它。
	_attach_dream_visual_layers(dream)

func _attach_dream_visual_layers(dream: Node2D) -> void:
	var to_reparent: Array[Node] = []
	for child in level.get_children():
		if child == dream or not child is Node2D:
			continue
		var scene_path: String = child.scene_file_path
		if scene_path.contains("PixelworkMapStitch"):
			to_reparent.append(child)
	for node in to_reparent:
		node.reparent(dream)

# ============================================================
# 现实房间（Level_02_sub01.tscn, 初始隐藏；睁眼后应用 Level_01 背景/相机）
# ============================================================

func _build_reality_room() -> void:
	var reality = level.get_node_or_null("RealityRoomRoot") as Node2D
	if not reality:
		var packed_scene = load(REALITY_ROOM_SCENE_PATH) as PackedScene
		if not packed_scene:
			push_error("[Level_02_SceneBuilder] 无法加载现实空间子场景: %s" % REALITY_ROOM_SCENE_PATH)
			return
		reality = packed_scene.instantiate() as Node2D
		reality.name = "RealityRoomRoot"
		level.add_child(reality)

	level._reality_root = reality
	# 初始隐藏 + 物理禁用（防止与梦境地形在同坐标系下冲突）
	reality.visible = false

# ============================================================
# 交互物（梦境动态创建, 现实从 Level_02_sub01.tscn 取引用）
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

	_cache_reality_interactives()

func _cache_reality_interactives() -> void:
	if not level._reality_root:
		push_error("[Level_02_SceneBuilder] RealityRoomRoot 未创建，无法获取现实交互物")
		return

	level._reality_phone_node = level._reality_root.get_node_or_null("InteractiveObjects/RealityPhone") as InteractiveObject
	level._reality_computer_node = level._reality_root.get_node_or_null("InteractiveObjects/RealityComputer") as InteractiveObject
	level._reality_bed_node = level._reality_root.get_node_or_null("InteractiveObjects/RealityBed") as InteractiveObject

	var required_nodes: Dictionary = {
		"RealityPhone": level._reality_phone_node,
		"RealityComputer": level._reality_computer_node,
		"RealityBed": level._reality_bed_node
	}
	for node_name in required_nodes:
		if not required_nodes[node_name]:
			push_error("[Level_02_SceneBuilder] Level_02_sub01.tscn 缺少现实交互物: %s" % node_name)

	for obj in [level._reality_phone_node, level._reality_computer_node, level._reality_bed_node]:
		if obj:
			obj.apply_level01_dot_visual()

	if level._reality_phone_node:
		level._reality_phone_node.set_active(false)
		level._reality_phone_node.visible = false
		level._reality_phone_node.prompt_text = "按 Enter 查看"
	if level._reality_computer_node:
		level._reality_computer_node.set_active(false)
		level._reality_computer_node.visible = false
		level._reality_computer_node.prompt_text = "按 Enter 使用"
	if level._reality_bed_node:
		level._reality_bed_node.set_active(false)
		level._reality_bed_node.visible = false
		level._reality_bed_node.prompt_text = "按 Enter 入梦"

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
	level._cliff_approach_trigger = _create_trigger_zone("CliffApproachTrigger", Vector2(4636, 460), Vector2(80, 360))
	container.add_child(level._cliff_approach_trigger)
	level._cliff_approach_trigger.body_entered.connect(level._on_cliff_approach_body_entered)

	# 3. 坠落深渊触发（可重复: 黑屏重置）
	level._fall_pit_trigger = _create_trigger_zone("FallPitTrigger", Vector2(4844, 608), Vector2(376, 64))
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
	reality_spawn.position = Vector2(1504, 550)
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
