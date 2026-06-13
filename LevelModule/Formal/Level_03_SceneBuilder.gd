# ============================================================
# Level_03_SceneBuilder.gd - 关卡3场景构建器
# 单坐标空间布局:
#   凉茶铺 (0-1200) + 岭南街巷 (1200-2400) + 过渡走廊 (2400-3600) + 赛博城 (3600-15600)
# 所有区域在同一坐标空间中左右相连，玩家可无缝步行穿越
# ============================================================
extends RefCounted
class_name Level_03_SceneBuilder

var level: Level_03

func _init(parent: Level_03) -> void:
	level = parent

func build_all() -> void:
	_build_safe_haven()
	_build_lingnan_alley()
	_build_transition_corridor()
	_build_cyber_city()
	_build_interactives()
	_build_triggers()
	_build_spawn_points()
	_build_dynamic_actors_container()
	_build_canvas_ui()
	# 所有纯视觉 ColorRect 必须忽略鼠标事件，否则会拦截鼠标攻击输入
	_set_all_color_rect_mouse_ignore(level)


# ============================================================
# 凉茶铺温馨场景（0-1200px）
# ============================================================

func _build_safe_haven() -> void:
	var haven = level._get_or_create_child("SafeHavenRoot", Node2D)
	level._safe_haven_root = haven

	# 地面
	haven.add_child(level._create_static_body("HavenGround", Vector2(600, 620), Vector2(1200, 40), Color(0.55, 0.35, 0.2)))
	# 左墙
	haven.add_child(level._create_static_body("HavenLeftWall", Vector2(-10, 360), Vector2(20, 720), Color(0.4, 0.28, 0.16)))
	# 右墙（初始封闭，岭南战斗后打开）
	haven.add_child(level._create_static_body("HavenRightWall", Vector2(1210, 360), Vector2(20, 720), Color(0.4, 0.28, 0.16)))

	# 大榕树
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
	haven.add_child(level._create_static_body("CounterBlock", Vector2(775, 590), Vector2(250, 60), Color(0.4, 0.25, 0.15)))

	# 炉火
	var stove_fire = ColorRect.new()
	stove_fire.name = "StoveFire"
	stove_fire.color = Color(1.0, 0.5, 0.15, 0.9)
	stove_fire.size = Vector2(40, 30)
	stove_fire.position = Vector2(680, 500)
	haven.add_child(stove_fire)

	# 满洲窗
	var window_rect = ColorRect.new()
	window_rect.name = "ManchuWindow"
	window_rect.color = Color(0.9, 0.2, 0.2, 0.6)
	window_rect.size = Vector2(50, 70)
	window_rect.position = Vector2(1050, 300)
	haven.add_child(window_rect)

	# 暖光覆盖
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
# 岭南街巷（1200-2400px，复用关卡2街景设计）
# ============================================================

func _build_lingnan_alley() -> void:
	var alley = level._get_or_create_child("LingnanAlleyRoot", Node2D)

	# 地面延续
	alley.add_child(level._create_static_body("AlleyGround", Vector2(1800, 620), Vector2(1200, 40), Color(0.5, 0.32, 0.18)))

	# 左侧骑楼柱子（3根）
	for i in range(3):
		var pillar = ColorRect.new()
		pillar.name = "ArcadePillar_%d" % i
		pillar.color = Color(0.45, 0.35, 0.25, 0.95)
		pillar.size = Vector2(25, 200)
		pillar.position = Vector2(1300 + i * 350, 380)
		alley.add_child(pillar)

	# 右侧店铺门面
	for i in range(3):
		var shop = ColorRect.new()
		shop.name = "ShopFront_%d" % i
		shop.color = Color(0.5, 0.3, 0.2, 0.9) if i % 2 == 0 else Color(0.35, 0.25, 0.15, 0.9)
		shop.size = Vector2(160, 250)
		shop.position = Vector2(1450 + i * 300, 340)
		alley.add_child(shop)

	# 骑楼走廊顶棚
	var arcade_roof = ColorRect.new()
	arcade_roof.name = "ArcadeRoof"
	arcade_roof.color = Color(0.55, 0.4, 0.3, 0.8)
	arcade_roof.size = Vector2(1200, 30)
	arcade_roof.position = Vector2(1200, 340)
	alley.add_child(arcade_roof)

	# 招牌（3块，不同颜色）
	var sign_colors = [Color(0.8, 0.2, 0.2, 0.85), Color(0.2, 0.6, 0.2, 0.85), Color(0.2, 0.3, 0.8, 0.85)]
	for i in range(3):
		var sign = ColorRect.new()
		sign.name = "ShopSign_%d" % i
		sign.color = sign_colors[i]
		sign.size = Vector2(80, 30)
		sign.position = Vector2(1350 + i * 300, 310)
		alley.add_child(sign)

	# 街灯（2盏）
	for i in range(2):
		var lamp = ColorRect.new()
		lamp.name = "StreetLamp_%d" % i
		lamp.color = Color(1.0, 0.9, 0.5, 0.7)
		lamp.size = Vector2(15, 80)
		lamp.position = Vector2(1450 + i * 500, 450)
		alley.add_child(lamp)
		var lamp_head = ColorRect.new()
		lamp_head.name = "LampHead_%d" % i
		lamp_head.color = Color(1.0, 0.95, 0.6, 0.9)
		lamp_head.size = Vector2(30, 15)
		lamp_head.position = Vector2(1443 + i * 500, 440)
		alley.add_child(lamp_head)

	# 右端封闭墙（世界异化后才打开）
	alley.add_child(level._create_static_body("AlleyRightWall", Vector2(2410, 360), Vector2(20, 720), Color(0.4, 0.28, 0.16)))

	# 背景天空/墙体
	var bg_wall = ColorRect.new()
	bg_wall.name = "AlleyBackWall"
	bg_wall.color = Color(0.6, 0.5, 0.4, 0.4)
	bg_wall.size = Vector2(1200, 340)
	bg_wall.position = Vector2(1200, 0)
	bg_wall.z_index = -2
	alley.add_child(bg_wall)


# ============================================================
# 过渡走廊（2400-3600px，岭南→赛博渐变缓冲区）
# ============================================================

func _build_transition_corridor() -> void:
	var corridor = level._get_or_create_child("TransitionCorridorRoot", Node2D)

	# 地面（左暖右冷渐变——用两段拼接）
	corridor.add_child(level._create_static_body("CorridorGroundWarm", Vector2(2700, 620), Vector2(600, 40), Color(0.4, 0.3, 0.2)))
	corridor.add_child(level._create_static_body("CorridorGroundCold", Vector2(3300, 620), Vector2(600, 40), Color(0.15, 0.15, 0.2)))

	# 左半：岭南残垣（2400-3000）
	var cracked_wall = ColorRect.new()
	cracked_wall.name = "CrackedWall"
	cracked_wall.color = Color(0.5, 0.35, 0.2, 0.85)
	cracked_wall.size = Vector2(300, 250)
	cracked_wall.position = Vector2(2450, 350)
	corridor.add_child(cracked_wall)

	# 墙壁裂缝中渗出的绿色代码
	var code_bleed = ColorRect.new()
	code_bleed.name = "CodeBleed"
	code_bleed.color = Color(0, 1.0, 0.25, 0.3)
	code_bleed.size = Vector2(8, 120)
	code_bleed.position = Vector2(2580, 400)
	corridor.add_child(code_bleed)

	# 半毁的满洲窗
	var half_window = ColorRect.new()
	half_window.name = "HalfManchuWindow"
	half_window.color = Color(0.9, 0.2, 0.2, 0.4)
	half_window.size = Vector2(40, 50)
	half_window.position = Vector2(2500, 380)
	corridor.add_child(half_window)

	# 右半：赛博结构初现（3000-3600）
	var metal_frame = ColorRect.new()
	metal_frame.name = "MetalFrame"
	metal_frame.color = Color(0.12, 0.12, 0.18, 0.9)
	metal_frame.size = Vector2(250, 280)
	metal_frame.position = Vector2(3100, 330)
	corridor.add_child(metal_frame)

	# 第一根霓虹管
	var first_neon = ColorRect.new()
	first_neon.name = "FirstNeon"
	first_neon.color = Color(0.9, 0.1, 0.3, 0.6)
	first_neon.size = Vector2(100, 8)
	first_neon.position = Vector2(3050, 350)
	corridor.add_child(first_neon)

	# 第一个管道
	var first_pipe = ColorRect.new()
	first_pipe.name = "FirstPipe"
	first_pipe.color = Color(0.08, 0.08, 0.12, 0.95)
	first_pipe.size = Vector2(15, 180)
	first_pipe.position = Vector2(3350, 400)
	corridor.add_child(first_pipe)

	# 右端封闭墙（世界异化后才打开）
	corridor.add_child(level._create_static_body("CorridorRightWall", Vector2(3610, 360), Vector2(20, 720), Color(0.08, 0.08, 0.12)))


# ============================================================
# 赛博城中村（CyberCityRoot.position.x = 3600，实际全局范围3600-15600）
# ============================================================

func _build_cyber_city() -> void:
	var cyber = level._get_or_create_child("CyberCityRoot", Node2D)
	level._cyber_city_root = cyber
	# 关键：偏移到 x=3600，使赛博城紧接过渡走廊
	cyber.position.x = 3600

	# 地面（local坐标不变，全局映射到 3600-15600）
	cyber.add_child(level._create_static_body("CyberGround", Vector2(6000, 620), Vector2(12000, 40), Color(0.15, 0.15, 0.2)))
	# 左墙（全局x=3590）
	cyber.add_child(level._create_static_body("CyberLeftWall", Vector2(-10, 360), Vector2(20, 720), Color(0.08, 0.08, 0.12)))
	# 右墙
	cyber.add_child(level._create_static_body("CyberRightWall", Vector2(12010, 360), Vector2(20, 720), Color(0.08, 0.08, 0.12)))

	# 霓虹灯管
	for i in range(20):
		var neon = ColorRect.new()
		neon.name = "NeonTube_%d" % i
		neon.color = Color(0.9, 0.1, 0.3, 0.7) if i % 2 == 0 else Color(0.1, 0.3, 0.9, 0.7)
		neon.size = Vector2(120, 8)
		neon.position = Vector2(400 + i * 580, 200 + (i % 3) * 80)
		cyber.add_child(neon)

	# 金属管道
	for i in range(8):
		var pipe = ColorRect.new()
		pipe.name = "MetalPipe_%d" % i
		pipe.color = Color(0.08, 0.08, 0.12, 0.95)
		pipe.size = Vector2(20, 250 + (i % 3) * 50)
		pipe.position = Vector2(800 + i * 1400, 370)
		cyber.add_child(pipe)

	# 集装箱楼房
	for i in range(15):
		var container = ColorRect.new()
		container.name = "Container_%d" % i
		container.color = Color(0.1, 0.1, 0.15, 0.85)
		container.size = Vector2(120 + (i % 3) * 40, 180 + (i % 4) * 60)
		container.position = Vector2(300 + i * 780, 300 - (i % 3) * 40)
		cyber.add_child(container)

	# 趟栊门畸形缝合
	for i in range(6):
		var door = ColorRect.new()
		door.name = "MutatedDoor_%d" % i
		door.color = Color(0.4, 0.3, 0.2, 0.5)
		door.size = Vector2(40, 100)
		door.position = Vector2(1200 + i * 1800, 420)
		cyber.add_child(door)

	# 全息广告
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

	# 光团区域装饰
	var ruins_1 = ColorRect.new()
	ruins_1.name = "MetalRuins_1"
	ruins_1.color = Color(0.12, 0.12, 0.18, 0.8)
	ruins_1.size = Vector2(300, 150)
	ruins_1.position = Vector2(8250, 380)
	cyber.add_child(ruins_1)

	var ruins_2 = ColorRect.new()
	ruins_2.name = "MetalRuins_2"
	ruins_2.color = Color(0.12, 0.12, 0.18, 0.8)
	ruins_2.size = Vector2(350, 180)
	ruins_2.position = Vector2(10650, 360)
	cyber.add_child(ruins_2)

	# 全息监控眼
	var eye = ColorRect.new()
	eye.name = "HologramEye"
	eye.color = Color(1.0, 0.0, 0.0, 0.0)
	eye.size = Vector2(80, 80)
	eye.position = Vector2(360, 350)
	cyber.add_child(eye)

	# 初始隐藏
	cyber.visible = false


# ============================================================
# 交互物（3个，全局坐标）
# ============================================================

func _build_interactives() -> void:
	var container = level._get_or_create_child("InteractiveObjects", Node2D)

	# 1. 爷爷NPC（凉茶铺前）
	level._grandpa_node = level._create_interactive("Grandpa", "grandpa", Vector2(650, 520), Vector2(80, 120))
	var grandpa_indicator = level._grandpa_node.get_node_or_null("Indicator")
	if grandpa_indicator:
		grandpa_indicator.color = Color(0.8, 0.7, 0.4, 0.4)
	level._grandpa_node.prompt_text = "按 Enter 与爷爷对话"
	level._grandpa_node.allow_repeat = false
	container.add_child(level._grandpa_node)

	# 2. 异常数据光团1（赛博城深处，全局坐标+3600偏移）
	var echo1_pos = level.level_data.memory_echo_1_pos if level.level_data else Vector2(12000, 550)
	level._memory_echo_1_node = level._create_interactive("MemoryEcho1", "memory_echo_1", echo1_pos, Vector2(60, 60))
	var echo1_indicator = level._memory_echo_1_node.get_node_or_null("Indicator")
	if echo1_indicator:
		echo1_indicator.color = Color(1.0, 0.85, 0.3, 0.6)
	level._memory_echo_1_node.prompt_text = "按 Enter 触碰记忆"
	level._memory_echo_1_node.is_active = false
	container.add_child(level._memory_echo_1_node)
	var warning_1 = Label.new()
	warning_1.name = "ErrorLabel"
	warning_1.text = "[Error_Data: 建议立刻清除]"
	warning_1.add_theme_font_size_override("font_size", 11)
	warning_1.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 0.9))
	warning_1.position = Vector2(-80, -75)
	warning_1.size = Vector2(160, 18)
	level._memory_echo_1_node.add_child(warning_1)

	# 3. 异常数据光团2
	var echo2_pos = level.level_data.memory_echo_2_pos if level.level_data else Vector2(14400, 550)
	level._memory_echo_2_node = level._create_interactive("MemoryEcho2", "memory_echo_2", echo2_pos, Vector2(60, 60))
	var echo2_indicator = level._memory_echo_2_node.get_node_or_null("Indicator")
	if echo2_indicator:
		echo2_indicator.color = Color(1.0, 0.85, 0.3, 0.6)
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
# 触发器（全局坐标，偏移+3600）
# ============================================================

func _build_triggers() -> void:
	var container = level._get_or_create_child("TriggerZones", Node2D)

	# AI阻挠触发1（赛博城1/3处 ≈ 全局7600）
	level._warning_1_trigger = _create_trigger_zone("Warning1Trigger", Vector2(7600, 460), Vector2(80, 360))
	container.add_child(level._warning_1_trigger)
	level._warning_1_trigger.body_entered.connect(level._on_warning_1_trigger_body_entered)

	# AI阻挠触发2（赛博城2/3处 ≈ 全局11600）
	level._warning_2_trigger = _create_trigger_zone("Warning2Trigger", Vector2(11600, 460), Vector2(80, 360))
	container.add_child(level._warning_2_trigger)
	level._warning_2_trigger.body_entered.connect(level._on_warning_2_trigger_body_entered)

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
	tea_shop_spawn.position = Vector2(400, 550)
	container.add_child(tea_shop_spawn)
	level.player_spawn_point = tea_shop_spawn


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


# ============================================================
# 辅助：递归设置所有 ColorRect 鼠标穿透
# 纯视觉 ColorRect 默认 MOUSE_FILTER_STOP 会拦截鼠标攻击输入
# ============================================================

func _set_all_color_rect_mouse_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is ColorRect:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_all_color_rect_mouse_ignore(child)
