# ============================================================
# Level_02_SceneBuilder.gd - 关卡2场景构建器
# 单场景双空间容器架构:
#   DreamWorldRoot  — 梦境: 阁楼(0-900) / 老街(900-8400, 3倍) / 断崖(8400-8870)
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
# 梦境世界（9200px 宽）
# ============================================================

func _build_dream_world() -> void:
	var dream = level._get_or_create_child("DreamWorldRoot", Node2D)
	level._dream_root = dream

	# ---- A 阁楼 (0-900): 温暖色调 ----
	# 阁楼地面
	dream.add_child(level._create_static_body("MainAtticFloor", Vector2(450, 620), Vector2(900, 40), Color(0.45, 0.3, 0.18)))
	# 左墙
	dream.add_child(level._create_static_body("AtticLeftWall", Vector2(-10, 360), Vector2(20, 720), Color(0.4, 0.28, 0.16)))
	# 阁楼与老街之间的木门隔墙（趟栊门打开后移除碰撞）
	var door_wall = level._create_static_body("AtticDoorWall", Vector2(890, 440), Vector2(30, 400), Color(0.5, 0.34, 0.2))
	dream.add_child(door_wall)
	level._attic_door_wall = door_wall
	# 阁楼背景装饰（暖色光斑，无碰撞）
	var attic_glow = ColorRect.new()
	attic_glow.name = "AtticWarmGlow"
	attic_glow.color = Color(1.0, 0.75, 0.4, 0.12)
	attic_glow.size = Vector2(900, 600)
	attic_glow.position = Vector2(0, 0)
	attic_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dream.add_child(attic_glow)

	# ---- B 老街 (900-8400, 3x 延伸) ----
	dream.add_child(level._create_static_body("StreetGround", Vector2(4650, 620), Vector2(7500, 40), Color(0.42, 0.36, 0.3)))
	# 骑楼背景柱（装饰，无碰撞）— 保持 450px 间距，老街加长到 7500px，17 根维持密度
	for i in range(17):
		var pillar = ColorRect.new()
		pillar.name = "ArcadePillar_%d" % i
		pillar.color = Color(0.5, 0.4, 0.3, 0.45)
		pillar.size = Vector2(40, 360)
		pillar.position = Vector2(1100 + i * 450, 240)
		pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dream.add_child(pillar)

	# ---- C 断崖 (8400-8870, 1/3 缩窄) ----
	# 左岸平台（8400-8460 截止）
	dream.add_child(level._create_static_body("CliffLeftGround", Vector2(8420, 660), Vector2(140, 120), Color(0.35, 0.3, 0.26)))
	# 对岸视觉平台（不可达，无碰撞，纯背景）— 深渊缩至 1/3，对岸拉近
	var far_shore = ColorRect.new()
	far_shore.name = "FarShoreVisual"
	far_shore.color = Color(0.4, 0.32, 0.26, 0.85)
	far_shore.size = Vector2(300, 140)
	far_shore.position = Vector2(8827, 600)
	far_shore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dream.add_child(far_shore)
	# 对岸凉茶铺剪影（装饰）
	var tea_shop = ColorRect.new()
	tea_shop.name = "TeaShopSilhouette"
	tea_shop.color = Color(0.3, 0.22, 0.15, 0.9)
	tea_shop.size = Vector2(180, 160)
	tea_shop.position = Vector2(8887, 440)
	tea_shop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dream.add_child(tea_shop)
	# 凉茶铺暖光
	var shop_glow = ColorRect.new()
	shop_glow.name = "TeaShopGlow"
	shop_glow.color = Color(1.0, 0.7, 0.3, 0.35)
	shop_glow.size = Vector2(60, 50)
	shop_glow.position = Vector2(8947, 520)
	shop_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dream.add_child(shop_glow)
	# 爷爷剪影
	var grandpa = ColorRect.new()
	grandpa.name = "GrandpaSilhouette"
	grandpa.color = Color(0.12, 0.1, 0.08, 0.95)
	grandpa.size = Vector2(36, 70)
	grandpa.position = Vector2(8967, 530)
	grandpa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dream.add_child(grandpa)
	# 深渊视觉（黑色渐变区域，无碰撞）— 宽度 337 不变（断崖本身未变）
	var abyss = ColorRect.new()
	abyss.name = "AbyssVisual"
	abyss.color = Color(0.02, 0.02, 0.05, 0.92)
	abyss.size = Vector2(337, 400)
	abyss.position = Vector2(8490, 680)
	abyss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dream.add_child(abyss)

# ============================================================
# 现实房间（复用关卡1布局参数, 初始隐藏, 整体灰暗化）
# ============================================================

func _build_reality_room() -> void:
	var reality = level._get_or_create_child("RealityRoomRoot", Node2D)
	level._reality_root = reality

	# 主地面 + 左右墙（与关卡1坐标一致）
	reality.add_child(level._create_static_body("RealityGround", Vector2(960, 620), Vector2(1920, 40), Color(0.12, 0.12, 0.15)))
	reality.add_child(level._create_static_body("RealityLeftWall", Vector2(-10, 360), Vector2(20, 720), Color(0.1, 0.1, 0.12)))
	reality.add_child(level._create_static_body("RealityRightWall", Vector2(1930, 360), Vector2(20, 720), Color(0.1, 0.1, 0.12)))

	# 关卡2视觉细节: 垃圾桶外溢（装饰，无交互）
	var trash = ColorRect.new()
	trash.name = "TrashOverflow"
	trash.color = Color(0.25, 0.28, 0.22, 0.9)
	trash.size = Vector2(70, 60)
	trash.position = Vector2(500, 540)
	trash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reality.add_child(trash)
	var trash_spill = ColorRect.new()
	trash_spill.name = "TrashSpill"
	trash_spill.color = Color(0.2, 0.22, 0.18, 0.7)
	trash_spill.size = Vector2(130, 14)
	trash_spill.position = Vector2(470, 588)
	trash_spill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reality.add_child(trash_spill)

	# 空速食碗（装饰）
	var noodle = ColorRect.new()
	noodle.name = "InstantNoodleBowl"
	noodle.color = Color(0.5, 0.45, 0.38, 0.85)
	noodle.size = Vector2(36, 18)
	noodle.position = Vector2(900, 584)
	noodle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reality.add_child(noodle)

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
	level._window_node = level._create_interactive("Window_L2", "window_l2", Vector2(420, 480), Vector2(110, 130))
	var win_indicator = level._window_node.get_node_or_null("Indicator")
	if win_indicator:
		win_indicator.color = Color(0.9, 0.6, 0.3, 0.4)
	level._window_node.prompt_text = "按 Enter 观察"
	container.add_child(level._window_node)

	# 2. 木趟栊门（阁楼 → 老街）
	level._attic_door_node = level._create_interactive("AtticDoor", "attic_door", Vector2(840, 520), Vector2(60, 160))
	var door_indicator = level._attic_door_node.get_node_or_null("Indicator")
	if door_indicator:
		door_indicator.color = Color(0.55, 0.35, 0.2, 0.5)
	level._attic_door_node.prompt_text = "按 Enter 推开"
	container.add_child(level._attic_door_node)

	# 3. 旧藤椅（老街，带物理阻挡的低矮障碍）
	level._rattan_chair_node = level._create_interactive("RattanChair", "rattan_chair", Vector2(2200, 575), Vector2(80, 50))
	var chair_indicator = level._rattan_chair_node.get_node_or_null("Indicator")
	if chair_indicator:
		chair_indicator.color = Color(0.6, 0.45, 0.25, 0.5)
	level._rattan_chair_node.prompt_text = "按 Enter 回忆"
	level._add_physics_blocker(level._rattan_chair_node, Vector2(80, 50))
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
	level._street_entry_trigger = _create_trigger_zone("StreetEntryTrigger", Vector2(1000, 460), Vector2(80, 360))
	container.add_child(level._street_entry_trigger)
	level._street_entry_trigger.body_entered.connect(level._on_street_entry_body_entered)

	# 2. 断崖接近触发（一次性: 进入 DREAM_CLIFF_LOOP + 首见独白）
	level._cliff_approach_trigger = _create_trigger_zone("CliffApproachTrigger", Vector2(8300, 460), Vector2(80, 360))
	container.add_child(level._cliff_approach_trigger)
	level._cliff_approach_trigger.body_entered.connect(level._on_cliff_approach_body_entered)

	# 3. 坠落深渊触发（可重复: 黑屏重置）
	level._fall_pit_trigger = _create_trigger_zone("FallPitTrigger", Vector2(8657, 810), Vector2(367, 260))
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
	cliff_safe.position = level.level_data.cliff_safe_spawn if level.level_data else Vector2(3340, 550)
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
