# ============================================================
# Level_03_SceneBuilder.gd - 关卡3场景构建器
# 单场景双空间容器架构:
#   SafeHavenRoot  — 凉茶铺温馨场景 (0-1200)
#   CyberCityRoot  — 赛博城中村 (0-12000, 约9倍屏幕)
# 另构建: 交互物 / 触发器 / 出生点 / 动态演员容器 / CanvasLayerUI
# 只创建节点并写入主控字段，不处理流程
# ============================================================
extends RefCounted
class_name Level_03_SceneBuilder

var level: Level_03

func _init(parent: Level_03) -> void:
	level = parent

func build_all() -> void:
	_build_safe_haven()
	_build_cyber_city()
	_build_interactives()
	_build_triggers()
	_build_spawn_points()
	_build_dynamic_actors_container()
	_build_canvas_ui()


# ============================================================
# 凉茶铺温馨场景（1200px 宽，虚假完美的过曝暖色调）
# ============================================================

func _build_safe_haven() -> void:
	var haven = level._get_or_create_child("SafeHavenRoot", Node2D)
	level._safe_haven_root = haven

	# 地面：温暖赭石色
	haven.add_child(level._create_static_body("HavenGround", Vector2(600, 620), Vector2(1200, 40), Color(0.55, 0.35, 0.2)))
	# 左墙
	haven.add_child(level._create_static_body("HavenLeftWall", Vector2(-10, 360), Vector2(20, 720), Color(0.4, 0.28, 0.16)))
	# 右墙（凉茶铺右边封闭，但玩家可向右走到赛博城）
	haven.add_child(level._create_static_body("HavenRightWall", Vector2(1210, 360), Vector2(20, 720), Color(0.4, 0.28, 0.16)))

	# 大榕树（装饰，无碰撞）
	var banyan_trunk = ColorRect.new()
	banyan_trunk.name = "BanyanTrunk"
	banyan_trunk.color = Color(0.3, 0.2, 0.12, 0.95)
	banyan_trunk.size = Vector2(60, 200)
	banyan_trunk.position = Vector2(270, 400)
	haven.add_child(banyan_trunk)

	var banyan_crown = ColorRect.new()
	banyan_crown.name = "BanyanCrown"
	banyan_crown.color = Color(0.2, 0.45, 0.15, 0.7)
	banyan_crown.size = Vector2(200, 140)
	banyan_crown.position = Vector2(200, 280)
	haven.add_child(banyan_crown)

	# 凉茶铺柜台
	var counter = ColorRect.new()
	counter.name = "TeaShopCounter"
	counter.color = Color(0.4, 0.25, 0.15, 0.95)
	counter.size = Vector2(250, 60)
	counter.position = Vector2(650, 530)
	haven.add_child(counter)
	# 柜台物理阻挡
	haven.add_child(level._create_static_body("CounterBlock", Vector2(775, 590), Vector2(250, 60), Color(0.4, 0.25, 0.15)))

	# 炉火（静态火焰，无粒子飘动——死寂感）
	var stove_fire = ColorRect.new()
	stove_fire.name = "StoveFire"
	stove_fire.color = Color(1.0, 0.5, 0.15, 0.9)
	stove_fire.size = Vector2(40, 30)
	stove_fire.position = Vector2(680, 500)
	haven.add_child(stove_fire)

	# 满洲窗（装饰，右侧墙上方）
	var window_rect = ColorRect.new()
	window_rect.name = "ManchuWindow"
	window_rect.color = Color(0.9, 0.2, 0.2, 0.6)
	window_rect.size = Vector2(50, 70)
	window_rect.position = Vector2(1050, 300)
	haven.add_child(window_rect)

	# 全局暖光覆盖（过曝感）
	var warm_glow = ColorRect.new()
	warm_glow.name = "HavenWarmGlow"
	warm_glow.color = Color(1.0, 0.85, 0.5, 0.08)
	warm_glow.size = Vector2(1200, 600)
	warm_glow.position = Vector2(0, 0)
	warm_glow.z_index = -1
	haven.add_child(warm_glow)

	# 凉茶铺屋顶
	var roof = ColorRect.new()
	roof.name = "TeaShopRoof"
	roof.color = Color(0.35, 0.22, 0.12, 0.9)
	roof.size = Vector2(350, 80)
	roof.position = Vector2(600, 240)
	haven.add_child(roof)


# ============================================================
# 赛博城中村（12000px 宽，暗色调+霓虹+金属）
# ============================================================

func _build_cyber_city() -> void:
	var cyber = level._get_or_create_child("CyberCityRoot", Node2D)
	level._cyber_city_root = cyber

	# 地面：合金地板（暗灰反光）
	cyber.add_child(level._create_static_body("CyberGround", Vector2(6000, 620), Vector2(12000, 40), Color(0.15, 0.15, 0.2)))
	# 左墙
	cyber.add_child(level._create_static_body("CyberLeftWall", Vector2(-10, 360), Vector2(20, 720), Color(0.08, 0.08, 0.12)))
	# 右墙
	cyber.add_child(level._create_static_body("CyberRightWall", Vector2(12010, 360), Vector2(20, 720), Color(0.08, 0.08, 0.12)))

	# ---- 霓虹灯管装饰（红蓝交替，闪烁感靠主控Tween驱动）----
	for i in range(20):
		var neon = ColorRect.new()
		neon.name = "NeonTube_%d" % i
		# 红蓝交替
		if i % 2 == 0:
			neon.color = Color(0.9, 0.1, 0.3, 0.7)  # 红
		else:
			neon.color = Color(0.1, 0.3, 0.9, 0.7)  # 蓝
		neon.size = Vector2(120, 8)
		neon.position = Vector2(400 + i * 580, 200 + (i % 3) * 80)
		cyber.add_child(neon)

	# ---- 金属管道（粗壮黑色管道从地底破出）----
	for i in range(8):
		var pipe = ColorRect.new()
		pipe.name = "MetalPipe_%d" % i
		pipe.color = Color(0.08, 0.08, 0.12, 0.95)
		pipe.size = Vector2(20, 250 + (i % 3) * 50)
		pipe.position = Vector2(800 + i * 1400, 370)
		cyber.add_child(pipe)

	# ---- 集装箱楼房（堆叠的方块）----
	for i in range(15):
		var container = ColorRect.new()
		container.name = "Container_%d" % i
		container.color = Color(0.1, 0.1, 0.15, 0.85)
		container.size = Vector2(120 + (i % 3) * 40, 180 + (i % 4) * 60)
		container.position = Vector2(300 + i * 780, 300 - (i % 3) * 40)
		cyber.add_child(container)

	# ---- 趟栊门畸形缝合（集装箱上的老门装饰）----
	for i in range(6):
		var door = ColorRect.new()
		door.name = "MutatedDoor_%d" % i
		door.color = Color(0.4, 0.3, 0.2, 0.5)  # 旧木色半透明
		door.size = Vector2(40, 100)
		door.position = Vector2(1200 + i * 1800, 420)
		cyber.add_child(door)

	# ---- 全息广告（巨大刺眼文字区域，无碰撞）----
	var hologram_1 = ColorRect.new()
	hologram_1.name = "HologramAd_1"
	hologram_1.color = Color(0.9, 0.1, 0.3, 0.35)
	hologram_1.size = Vector2(400, 120)
	hologram_1.position = Vector2(3000, 150)
	cyber.add_child(hologram_1)

	var hologram_2 = ColorRect.new()
	hologram_2.name = "HologramAd_2"
	hologram_2.color = Color(0.1, 0.3, 0.9, 0.35)
	hologram_2.size = Vector2(350, 100)
	hologram_2.position = Vector2(6500, 180)
	cyber.add_child(hologram_2)

	var hologram_3 = ColorRect.new()
	hologram_3.name = "HologramAd_3"
	hologram_3.color = Color(0.0, 1.0, 0.25, 0.25)
	hologram_3.size = Vector2(300, 90)
	hologram_3.position = Vector2(9500, 200)
	cyber.add_child(hologram_3)

	# ---- 光团区域装饰（赛博最深处的废墟）----
	# 光团1周围：金属废墟
	var ruins_1 = ColorRect.new()
	ruins_1.name = "MetalRuins_1"
	ruins_1.color = Color(0.12, 0.12, 0.18, 0.8)
	ruins_1.size = Vector2(300, 150)
	ruins_1.position = Vector2(8250, 380)
	cyber.add_child(ruins_1)

	# 光团2周围：更大废墟
	var ruins_2 = ColorRect.new()
	ruins_2.name = "MetalRuins_2"
	ruins_2.color = Color(0.12, 0.12, 0.18, 0.8)
	ruins_2.size = Vector2(350, 180)
	ruins_2.position = Vector2(10650, 360)
	cyber.add_child(ruins_2)

	# ---- 全息监控眼（凉茶铺废墟上方，异化后出现）----
	var eye = ColorRect.new()
	eye.name = "HologramEye"
	eye.color = Color(1.0, 0.0, 0.0, 0.0)  # 初始不可见
	eye.size = Vector2(80, 80)
	eye.position = Vector2(360, 350)
	cyber.add_child(eye)

	# 初始隐藏
	cyber.visible = false


# ============================================================
# 交互物（3个）
# ============================================================

func _build_interactives() -> void:
	var container = level._get_or_create_child("InteractiveObjects", Node2D)

	# 1. 爷爷NPC（凉茶铺前，初始可交互）
	level._grandpa_node = level._create_interactive("Grandpa", "grandpa", Vector2(650, 520), Vector2(80, 120))
	var grandpa_indicator = level._grandpa_node.get_node_or_null("Indicator")
	if grandpa_indicator:
		grandpa_indicator.color = Color(0.8, 0.7, 0.4, 0.4)  # 温暖黄色
	level._grandpa_node.prompt_text = "按 Enter 与爷爷对话"
	level._grandpa_node.allow_repeat = false
	container.add_child(level._grandpa_node)

	# 2. 异常数据光团1（赛博城深处，初始禁用）
	var echo1_pos = level.level_data.memory_echo_1_pos if level.level_data else Vector2(8400, 550)
	level._memory_echo_1_node = level._create_interactive("MemoryEcho1", "memory_echo_1", echo1_pos, Vector2(60, 60))
	var echo1_indicator = level._memory_echo_1_node.get_node_or_null("Indicator")
	if echo1_indicator:
		echo1_indicator.color = Color(1.0, 0.85, 0.3, 0.6)  # 温暖金色
	level._memory_echo_1_node.prompt_text = "按 Enter 触碰记忆"
	level._memory_echo_1_node.is_active = false
	container.add_child(level._memory_echo_1_node)
	# 光团上方红色警告标签
	var warning_1 = Label.new()
	warning_1.name = "ErrorLabel"
	warning_1.text = "[Error_Data: 建议立刻清除]"
	warning_1.add_theme_font_size_override("font_size", 11)
	warning_1.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 0.9))
	warning_1.position = Vector2(-80, -75)
	warning_1.size = Vector2(160, 18)
	level._memory_echo_1_node.add_child(warning_1)

	# 3. 异常数据光团2（赛博城最深处，初始禁用）
	var echo2_pos = level.level_data.memory_echo_2_pos if level.level_data else Vector2(10800, 550)
	level._memory_echo_2_node = level._create_interactive("MemoryEcho2", "memory_echo_2", echo2_pos, Vector2(60, 60))
	var echo2_indicator = level._memory_echo_2_node.get_node_or_null("Indicator")
	if echo2_indicator:
		echo2_indicator.color = Color(1.0, 0.85, 0.3, 0.6)  # 温暖金色
	level._memory_echo_2_node.prompt_text = "按 Enter 触碰记忆"
	level._memory_echo_2_node.is_active = false
	container.add_child(level._memory_echo_2_node)
	var warning_2 = Label.new()
	warning_2.name = "ErrorLabel"
	warning_2.text = "[Error_Data: 建议立刻清除]"
	warning_2.add_theme_font_size_override("font_size", 11)
	warning_2.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 0.9))
	warning_2.position = Vector2(-80, -75)
	warning_2.size = Vector2(160, 18)
	level._memory_echo_2_node.add_child(warning_2)


# ============================================================
# 非交互触发器（Area2D, collision_layer=0, mask=PLAYER）
# ============================================================

func _build_triggers() -> void:
	var container = level._get_or_create_child("TriggerZones", Node2D)

	# 1. AI阻挠触发1（1/3处 ≈ 4000px）
	level._warning_1_trigger = _create_trigger_zone("Warning1Trigger", Vector2(4000, 460), Vector2(80, 360))
	container.add_child(level._warning_1_trigger)
	level._warning_1_trigger.body_entered.connect(level._on_warning_1_trigger_body_entered)

	# 2. AI阻挠触发2（2/3处 ≈ 8000px）
	level._warning_2_trigger = _create_trigger_zone("Warning2Trigger", Vector2(8000, 460), Vector2(80, 360))
	container.add_child(level._warning_2_trigger)
	level._warning_2_trigger.body_entered.connect(level._on_warning_2_trigger_body_entered)

	# 3. 光团区域触发（提示玩家进入光团区域）
	level._memory_zone_trigger = _create_trigger_zone("MemoryZoneTrigger", Vector2(8100, 460), Vector2(80, 360))
	container.add_child(level._memory_zone_trigger)

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

	var tea_shop_spawn = Marker2D.new()
	tea_shop_spawn.name = "TeaShopSpawn"
	tea_shop_spawn.position = level.level_data.tea_shop_spawn if level.level_data else Vector2(400, 550)
	container.add_child(tea_shop_spawn)
	level.player_spawn_point = tea_shop_spawn

	var cyber_spawn = Marker2D.new()
	cyber_spawn.name = "CyberSpawn"
	cyber_spawn.position = level.level_data.cyber_spawn if level.level_data else Vector2(200, 550)
	container.add_child(cyber_spawn)


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

	var ui_builder = Level_03_UIBuilder.new(level, canvas)
	ui_builder.build_all()
