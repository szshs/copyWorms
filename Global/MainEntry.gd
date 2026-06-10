# ============================================================
# MainEntry.gd - 正式入口场景脚本
# 打开工程直接运行即开局游玩
#
# 职责:
#   1. 设置 FORMAL 运行模式
#   2. 发射 GAME_START 事件
#   3. 加载 Level_01.tscn (add_child, 不再创建 Camera2D/HUD)
#   4. 失败时回退到占位场景 (地面+墙+玩家+HUD)
#
# 关键设计决策:
#   - 正式关卡路径不创建 Camera2D: 玩家预制体(Player_Warrior/Cyber/Lingnan)
#     已内含 SmoothCamera 子节点, 避免重复相机冲突
#   - 正式关卡路径不加载 HUD: 由关卡模块(Level_01)自行管理 HUD 生命周期,
#     避免挂错父节点导致关卡切换时 HUD 泄漏
#   - 占位场景保留旧逻辑(创建裸Camera2D + HUD), 用于无正式关卡时调试
#
# 玩家外观切换: 当前硬编码 Player_Warrior.tscn,
#   正式游戏中需接入外观选择系统(Cyber/Lingnan)
# ============================================================
extends Node2D

## 当前已加载的关卡实例引用（关卡切换用）
var _current_level_node: Node = null
## 关卡切换进行中标志（防止重复 LEVEL_COMPLETE 触发双重切换）
var _switching_level: bool = false

func _ready() -> void:
	print("[MainEntry] 游戏启动 - 正式模式")
	GameManager.run_mode = GlobalDefine.RunMode.FORMAL

	# 发射游戏开始事件
	EventBus.emit(GlobalDefine.EventName.GAME_START)

	# 订阅关卡完成事件 → 多关卡切换（架构文档 §18.2 预留接入点）
	EventBus.subscribe(GlobalDefine.EventName.LEVEL_COMPLETE, self, "_on_level_complete")

	# 加载正式关卡（后续由关卡模块替换）
	_load_formal_level()

# ---- 多关卡切换 ----

func _on_level_complete(data: Dictionary) -> void:
	if _switching_level:
		return
	var next_path: String = data.get("next_level", "")
	print("[MainEntry] 收到 LEVEL_COMPLETE, next_level=", next_path)
	_switching_level = true
	_switch_to_level(next_path)

func _switch_to_level(next_path: String) -> void:
	# 1) 释放旧关卡（玩家作为关卡子节点随之销毁; EventBus tree_exited 自动清理订阅）
	if _current_level_node and is_instance_valid(_current_level_node):
		_current_level_node.queue_free()
	_current_level_node = null
	# 防御: 清除游离玩家引用，让新关卡 LevelBase._setup_player() 重建玩家
	GameManager.player_ref = null
	GameManager.enemy_list.clear()
	# 防御: 解除可能遗留的输入屏蔽，避免跨关卡输入锁泄漏
	InputManager.unblock_input("关卡切换")

	# 2) 等一帧让 queue_free 生效
	await get_tree().process_frame

	# 3) 加载新关卡（不存在时安全降级，不崩溃）
	if next_path != "" and ResourceLoader.exists(next_path):
		var level = load(next_path).instantiate()
		add_child(level)
		_current_level_node = level
		print("[MainEntry] 关卡切换成功: ", next_path)
	else:
		push_warning("[MainEntry] 下一关不存在: %s — 安全降级显示提示" % next_path)
		_show_end_placeholder()
	_switching_level = false

## 后续关卡尚未制作时的安全降级画面
func _show_end_placeholder() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	var label = Label.new()
	label.text = "—— 未完待续 ——\n\n后续关卡正在制作中"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(440, 320)
	canvas.add_child(label)

func _load_formal_level() -> void:
	# 尝试加载正式关卡
	var level_path = "res://LevelModule/Formal/Level_01.tscn"
	if ResourceLoader.exists(level_path):
		var level = load(level_path).instantiate()
		add_child(level)
		_current_level_node = level
		EventBus.emit(GlobalDefine.EventName.LEVEL_LOADED, { "level": level })
		print("[MainEntry] 关卡加载成功: Level_01")
		# HUD 由关卡模块自行管理，MainEntry 不再插手
		return
	else:
		# 关卡不存在时加载临时占位场景
		print("[MainEntry] 关卡未找到，加载占位场景")
		_spawn_placeholder()

func _spawn_placeholder() -> void:
	# 创建基础地面和墙壁（占位用）
	_create_ground(Vector2(640, 620), Vector2(1280, 80))
	_create_wall(Vector2(0, 360), Vector2(20, 720))
	_create_wall(Vector2(1280, 360), Vector2(20, 720))

	# 尝试加载玩家
	_spawn_player()

	# 加载HUD
	_load_hud()

func _create_ground(pos: Vector2, size: Vector2) -> void:
	var body = StaticBody2D.new()
	body.position = pos
	body.collision_layer = GlobalDefine.Collision.TERRAIN
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var rect = ColorRect.new()
	rect.color = Color(0.35, 0.35, 0.4)
	rect.size = size
	rect.position = -size / 2
	body.add_child(rect)
	add_child(body)

func _create_wall(pos: Vector2, size: Vector2) -> void:
	_create_ground(pos, size)

func _spawn_player() -> void:
	var player_path = "res://PlayerModule/Formal/Player_Warrior.tscn"
	if ResourceLoader.exists(player_path):
		var player = load(player_path).instantiate()
		player.position = Vector2(200, 550)  # 地面左侧，远离敌人
		add_child(player)
		GameManager.register_player(player)

		print("[MainEntry] 玩家创建成功")
	else:
		print("[MainEntry] 警告: 玩家场景未找到")

func _load_hud() -> void:
	var hud_path = "res://UI/HUD.tscn"
	if ResourceLoader.exists(hud_path):
		var hud = load(hud_path).instantiate()
		add_child(hud)
		print("[MainEntry] HUD加载成功")
