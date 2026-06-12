# ============================================================
# Level_03.gd - 第三关「赛博蜃景与真实回声」控制器
# 场景构建 → Level_03_SceneBuilder
# UI 构建   → Level_03_UIBuilder
# 状态调度  → Level_03_FSM
#
# 架构（与 Level_01/02 完全一致的四文件拆分）:
#   1. 双空间: SafeHavenRoot(凉茶铺) / CyberCityRoot(赛博城) 显隐+碰撞联动切换
#   2. 输入: InputManager.game_action 信号为主 + _input() 兜底
#   3. 状态幂等: _is_interacting/_interact_cooldown 任何路径退出都自愈
#   4. 击退反转: 订阅 PLAYER_HURT 事件，赛博阶段敌人击中后玩家向左击退
#   5. 死亡兜底: 血量过低时强制进入觉醒阶段，不走 GameOver
#   6. 跨关卡: 读取 GameManager.dream_runtime_flags 应用关卡2的配置篡改
# ============================================================
extends LevelBase
class_name Level_03

@export var level_data: Level03Data = null

enum LevelState {
	TEA_SHOP_FRONT,       # 凉茶铺前：爷爷NPC对话
	CYBER_TRANSITION,     # 赛博异化转场（3秒失控演出）
	CYBER_CITY,           # 赛博城中村探索+战斗
	MEMORY_COLLECTION,    # 异常数据光团收集（2个）
	AWAKENING,            # 彻底觉醒独白
	LEVEL_END_TRANSIT     # 关卡结束转场
}

var current_state: int = LevelState.TEA_SHOP_FRONT

# ---- 任务进度 ----
var grandpa_dialogue_index: int = 0
var memory_echoes_collected: int = 0
var ai_warning_1_triggered: bool = false
var ai_warning_2_triggered: bool = false

# ---- 场景节点引用（SceneBuilder 写入） ----
var _safe_haven_root: Node2D = null
var _cyber_city_root: Node2D = null
var _dynamic_actors: Node2D = null

# ---- 交互物引用 ----
var _grandpa_node: InteractiveObject = null
var _memory_echo_1_node: InteractiveObject = null
var _memory_echo_2_node: InteractiveObject = null
var _all_interactives: Array[InteractiveObject] = []

# ---- 触发器引用 ----
var _warning_1_trigger: Area2D = null
var _warning_2_trigger: Area2D = null
var _memory_zone_trigger: Area2D = null

# ---- UI 引用（UIBuilder 写入） ----
var _blackout_overlay: ColorRect = null
var _narrative_panel: Panel = null
var _narrative_text: RichTextLabel = null
var _code_rain_overlay: ColorRect = null
var _glitch_overlay: ColorRect = null
var _ending_prompt: Control = null
var _ending_label: Label = null
var _warm_glow_overlay: ColorRect = null

# ---- 交互/叙事状态（关卡1/2同款幂等模式） ----
var _interact_cooldown: float = 0.0
var _is_interacting: bool = false
var _narrative_open: bool = false
var _narrative_enter_pressed: bool = false
var _transition_running: bool = false
const NARRATIVE_INPUT_TIMEOUT: float = 30.0

# ---- 敌人管理 ----
var _enemy_slime_scene: PackedScene = null
var _cyber_enemies: Array[Node2D] = []
var _enemy_spawn_timer: Timer = null
const ENEMY_MAX_ALIVE: int = 6
const ENEMY_MAX_ONSCREEN: int = 4
const ENEMY_SPAWN_INTERVAL: float = 2.5

# ---- 击退反转 ----
const KNOCKBACK_REVERSE_FORCE: float = 350.0



# ---- 转场常量 ----
const CYBER_TRANSITION_DURATION: float = 3.0
const GLITCH_INTENSITY_DURATION: float = 2.0

# ---- 终局 ----
var _ending_enter_armed: bool = false
var _level_complete_emitted: bool = false

# ---- 音效挂点 ----
var _sfx_alarm_player: AudioStreamPlayer = null

var _fsm: Level_03_FSM = null


# ============================================================
# 生命周期
# ============================================================

## 覆写 _setup_player: 凉茶铺阶段使用岭南皮肤
func _setup_player() -> void:
	if GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		return  # 玩家已存在
	var player_path = "res://PlayerModule/Formal/Player_Warrior_Lingnan.tscn"
	if not ResourceLoader.exists(player_path):
		player_path = "res://PlayerModule/Formal/Player_Warrior.tscn"  # 降级
	if ResourceLoader.exists(player_path):
		var player = load(player_path).instantiate()
		var spawn_pos = level_config.spawn_point if level_config else Vector2(600, 550)
		player.position = spawn_pos
		add_child(player)
		GameManager.register_player(player)
		print("[Level_03] 玩家创建成功 (岭南皮肤)")

func _on_ready() -> void:
	super._on_ready()

	if not level_config:
		level_config = load("res://DataConfig/Level/Level03Config.tres") as LevelConfig
		_apply_config()
	if not level_data:
		level_data = load("res://DataConfig/Level/Level03Data.tres") as Level03Data

	# 预加载敌人场景
	var slime_path = "res://EnemyModule/Formal/Enemy_Slime.tscn"
	if ResourceLoader.exists(slime_path):
		_enemy_slime_scene = load(slime_path)

	# 应用跨关卡配置（关卡2"配置篡改"的结果）
	_apply_dream_runtime_flags()

	var builder = Level_03_SceneBuilder.new(self)
	builder.build_all()

	# 赛博城初始: 隐藏 + 碰撞禁用
	_set_space_collision(_cyber_city_root, false)

	_setup_camera_limits()
	# 凉茶铺阶段：摄像机限制在凉茶铺区域
	_set_camera_limits(-50, 1300, -500, 1200)
	_cache_ui_refs()
	_restrict_tea_shop_mechanics()
	_ensure_player_collision_layer()

	_all_interactives = [_grandpa_node, _memory_echo_1_node, _memory_echo_2_node]

	EventBus.subscribe(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, self, "_on_object_interacted")
	# 击退反转：订阅玩家受伤事件
	EventBus.subscribe(GlobalDefine.EventName.PLAYER_HURT, self, "_on_player_hurt")
	_fsm = Level_03_FSM.new(self)

	InputManager.game_action.connect(_on_game_action)

	# 敌人刷新计时器（赛博阶段才启动）
	_enemy_spawn_timer = Timer.new()
	_enemy_spawn_timer.name = "EnemySpawnTimer"
	_enemy_spawn_timer.wait_time = ENEMY_SPAWN_INTERVAL
	_enemy_spawn_timer.one_shot = false
	_enemy_spawn_timer.autostart = false
	_enemy_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)
	add_child(_enemy_spawn_timer)

	_load_hud()
	set_process(true)

	# 开场：凉茶铺前的安静
	print("[Level_03] 初始化完成 — 当前: TEA_SHOP_FRONT")


func _load_hud() -> void:
	var hud_path = "res://UI/HUD.tscn"
	if ResourceLoader.exists(hud_path):
		var hud = load(hud_path).instantiate()
		add_child(hud)
		print("[Level_03] HUD 加载成功")
	else:
		push_warning("[Level_03] HUD.tscn 未找到，跳过")


# ============================================================
# 跨关卡配置应用（读取关卡2写入的 dream_runtime_flags）
# ============================================================

func _apply_dream_runtime_flags() -> void:
	var flags = GameManager.dream_runtime_flags
	if flags.is_empty():
		print("[Level_03] 无跨关卡配置，使用默认值")
		return
	# 关卡2把 allow_external_signal 设为 false → 关卡3中"外部信号"被屏蔽
	# 关卡2把 base_jump_height 设为 99 → 关卡3中玩家跳跃能力增强
	# 关卡2把 player_damage_reduction 设为 true → 关卡3中玩家受伤减半
	print("[Level_03] 应用跨关卡配置: ", flags)
	var player = GameManager.player_ref
	if player and is_instance_valid(player):
		# 跳跃增强：关卡2设了 99，这里允许二段跳
		if flags.get("base_jump_height", 10) > 50:
			player.can_double_jump = true
			print("[Level_03] 跨关卡跳跃增强: 启用二段跳")


# ============================================================
# 工具方法（关卡1/2同模式）
# ============================================================

func _get_or_create_child(node_name: String, node_type) -> Node:
	var existing = get_node_or_null(node_name)
	if existing: return existing
	var node = node_type.new()
	node.name = node_name
	add_child(node)
	return node

func _create_static_body(node_name: String, pos: Vector2, size: Vector2, col: Color) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = GlobalDefine.Collision.TERRAIN
	body.collision_mask = 0
	var col_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = size
	col_shape.shape = rect_shape
	col_shape.name = "CollisionShape2D"
	body.add_child(col_shape)
	var color_rect = ColorRect.new()
	color_rect.name = "ColorRect"
	color_rect.color = col
	color_rect.size = size
	color_rect.position = -size / 2
	body.add_child(color_rect)
	return body

func _create_interactive(node_name: String, obj_id: String, pos: Vector2, size: Vector2) -> InteractiveObject:
	var obj = InteractiveObject.new()
	obj.name = node_name
	obj.position = pos
	obj.object_id = obj_id
	obj.collision_layer = 0
	obj.collision_mask = GlobalDefine.Collision.PLAYER
	var col_shape = CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = size
	col_shape.shape = rect_shape
	obj.add_child(col_shape)
	var indicator = ColorRect.new()
	indicator.name = "Indicator"
	indicator.color = Color(0.5, 0.5, 0.5, 0.3)
	indicator.size = size
	indicator.position = -size / 2
	obj.add_child(indicator)
	return obj

func _add_physics_blocker(parent: Node2D, size: Vector2) -> void:
	var blocker = StaticBody2D.new()
	blocker.name = "StaticBody2D"
	blocker.collision_layer = GlobalDefine.Collision.TERRAIN
	blocker.collision_mask = 0
	blocker.position = Vector2.ZERO
	var col_shape = CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	var rect = RectangleShape2D.new()
	rect.size = size
	col_shape.shape = rect
	blocker.add_child(col_shape)
	parent.add_child(blocker)

func _ensure_player_collision_layer() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	if not (player.collision_layer & GlobalDefine.Collision.PLAYER):
		push_warning("[Level_03] 玩家 collision_layer 缺失 PLAYER 位，修正中...")
		player.collision_layer |= GlobalDefine.Collision.PLAYER

func _set_space_collision(root: Node, enabled: bool) -> void:
	if not root or not is_instance_valid(root):
		return
	for child in root.get_children():
		if child is StaticBody2D:
			var shape = child.get_node_or_null("CollisionShape2D")
			if shape:
				shape.disabled = not enabled
		_set_space_collision(child, enabled)

func _setup_camera_limits() -> void:
	if not level_config:
		return
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	var cam = player.get_node_or_null("SmoothCamera") as SmoothCamera
	if not cam:
		return
	cam.limit_left = level_config.camera_limit_left
	cam.limit_right = level_config.camera_limit_right
	cam.limit_top = level_config.camera_limit_top
	cam.limit_bottom = level_config.camera_limit_bottom
	cam.bind_target(player)
	print("[Level_03] SmoothCamera 已配置 (limit_left=%d, limit_right=%d)" % [cam.limit_left, cam.limit_right])

func _set_camera_limits(left: int, right: int, top: int, bottom: int) -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	var cam = player.get_node_or_null("SmoothCamera") as SmoothCamera
	if not cam:
		return
	cam.limit_left = left
	cam.limit_right = right
	cam.limit_top = top
	cam.limit_bottom = bottom
	cam.bind_target(player)
	print("[Level_03] SmoothCamera limit 更新 (left=%d, right=%d)" % [left, right])

func _cache_ui_refs() -> void:
	var canvas = $CanvasLayerUI
	if not canvas: return
	_narrative_panel = canvas.get_node_or_null("NarrativePanel")
	if _narrative_panel: _narrative_text = _narrative_panel.get_node_or_null("RichTextLabel")
	_blackout_overlay = canvas.get_node_or_null("BlackoutOverlay")
	_code_rain_overlay = canvas.get_node_or_null("CodeRainOverlay")
	_glitch_overlay = canvas.get_node_or_null("GlitchOverlay")
	_warm_glow_overlay = canvas.get_node_or_null("WarmGlowOverlay")
	_ending_prompt = canvas.get_node_or_null("EndingPrompt")
	if _ending_prompt: _ending_label = _ending_prompt.get_node_or_null("EndingLabel")


# ============================================================
# 玩家控制
# ============================================================

func _restore_player_mechanics() -> void:
	var player = GameManager.player_ref
	if not player: return
	player.can_jump = true
	player.can_dash = true
	player.can_attack = true
	player.can_skill = true
	player.can_double_jump = false
	player.runtime_move_speed_multiplier = 1.0

func _restrict_tea_shop_mechanics() -> void:
	var player = GameManager.player_ref
	if not player: return
	# 凉茶铺前：只允许移动和跳跃，禁用战斗
	player.can_attack = false
	player.can_dash = false
	player.can_skill = false

func _restore_cyber_mechanics() -> void:
	var player = GameManager.player_ref
	if not player: return
	player.can_attack = true
	player.can_dash = true
	player.can_skill = true
	# 重新应用跨关卡跳跃增强
	var flags = GameManager.dream_runtime_flags
	if flags.get("base_jump_height", 10) > 50:
		player.can_double_jump = true

## 赛博转场时将玩家从岭南皮肤切换为赛博皮肤（含延迟命中战斗系统）
func _swap_player_to_cyber(spawn_pos: Vector2) -> void:
	var old_player = GameManager.player_ref
	if not old_player or not is_instance_valid(old_player):
		return

	# 1) 保存旧玩家状态
	var saved_health: int = old_player.current_health
	var saved_max_health: int = old_player.max_health
	var saved_facing_right: bool = old_player.is_facing_right
	var saved_vel: Vector2 = old_player.velocity

	# 2) 清理旧玩家
	GameManager.player_ref = null
	for enemy in GameManager.get_enemies():
		pass  # 敌人列表保留，新玩家会自动重连
	old_player.queue_free()

	# 3) 实例化赛博玩家
	var cyber_path = "res://PlayerModule/Formal/Player_Warrior_Cyber.tscn"
	if not ResourceLoader.exists(cyber_path):
		push_error("[Level_03] Player_Warrior_Cyber.tscn 不存在!")
		return
	var new_player = load(cyber_path).instantiate()
	add_child(new_player)

	# 4) 恢复状态
	new_player.current_health = saved_health
	new_player.max_health = saved_max_health
	new_player.global_position = spawn_pos
	new_player.velocity = saved_vel
	new_player.is_facing_right = saved_facing_right

	# 5) 注册
	GameManager.register_player(new_player)

	# 6) 重新配置相机
	_set_camera_limits(-50, 12200, -500, 1200)

	print("[Level_03] 玩家切换为赛博皮肤 (Player_Warrior_Cyber)")

func _enforce_level_restrictions() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player): return
	if current_state == LevelState.TEA_SHOP_FRONT:
		if player.can_attack:
			player.can_attack = false

func _freeze_player(freeze: bool) -> void:
	var player = GameManager.player_ref
	if not player: return
	if freeze:
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		player.set_process_input(false)
		player._change_state(GlobalDefine.PlayerState.IDLE)
	else:
		player.set_physics_process(true)
		player.set_process_input(true)
	for obj in _all_interactives:
		if is_instance_valid(obj):
			obj.freeze_monitoring(freeze)


# ============================================================
# 输入处理（关卡1/2模式: 信号驱动为主 + _input 兜底）
# ============================================================

func _on_game_action(action: StringName, _event: InputEvent) -> void:
	if action != &"ui_accept":
		return
	_handle_accept_input()

func _handle_accept_input() -> void:
	if current_state == LevelState.LEVEL_END_TRANSIT:
		if _ending_enter_armed:
			_ending_enter_armed = false
			_emit_level_complete()
		return
	if _narrative_open:
		_narrative_enter_pressed = true
		return
	if _is_interacting or _interact_cooldown > 0.0 or _transition_running:
		if not _transition_running and _interact_cooldown > 0.5:
			_safe_end_interaction()
		return
	var obj = _find_nearby_interactive()
	if obj:
		_interact_cooldown = 0.3
		EventBus.emit(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, {"object_id": obj.object_id})

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return

	if current_state == LevelState.LEVEL_END_TRANSIT:
		if _ending_enter_armed:
			_ending_enter_armed = false
			_emit_level_complete()
			get_viewport().set_input_as_handled()
		return

	if _narrative_open:
		_narrative_enter_pressed = true
		get_viewport().set_input_as_handled()
		return

	if _is_interacting or _interact_cooldown > 0.0 or _transition_running:
		if not _transition_running and _interact_cooldown > 0.5:
			_safe_end_interaction()
		return

	var nearby_obj = _find_nearby_interactive()
	if nearby_obj:
		_interact_cooldown = 0.3
		EventBus.emit(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, {"object_id": nearby_obj.object_id})
		get_viewport().set_input_as_handled()

func _find_nearby_interactive() -> InteractiveObject:
	for obj in _all_interactives:
		if is_instance_valid(obj) and obj.is_active and not obj.completed and obj.is_player_in_range:
			return obj
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return null
	var best: InteractiveObject = null
	var best_dist: float = INF
	const FALLBACK_RADIUS: float = 120.0
	for obj in _all_interactives:
		if not is_instance_valid(obj) or not obj.is_active or obj.completed:
			continue
		var d: float = player.global_position.distance_to(obj.global_position)
		if d < FALLBACK_RADIUS and d < best_dist:
			best_dist = d
			best = obj
	if best:
		best.is_player_in_range = true
	return best


# ============================================================
# 每帧逻辑
# ============================================================

func _process(delta: float) -> void:
	if _interact_cooldown > 0.0:
		_interact_cooldown -= delta
	_enforce_level_restrictions()
	_poll_interactives_in_range()



	# 防御性自愈（关卡1/2同款）
	if _is_interacting and current_state not in [LevelState.LEVEL_END_TRANSIT]:
		if not _narrative_open and not _transition_running:
			_safe_end_interaction()

func _poll_interactives_in_range() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	for obj in _all_interactives:
		if is_instance_valid(obj):
			obj.check_player_in_range(player)

func _safe_end_interaction() -> void:
	if not _narrative_open and not _transition_running:
		_is_interacting = false
	_interact_cooldown = 0.0

func _run_safely(fn: Callable) -> void:
	if not fn.is_valid():
		return
	_interact_cooldown = 0.0
	fn.call()
	_safe_end_interaction()


# ============================================================
# FSM 调度
# ============================================================

func _on_object_interacted(data: Dictionary) -> void:
	var obj_id: String = data.get("object_id", "")
	if not _fsm:
		push_error("[Level_03] FSM 为 null，无法处理交互: %s" % obj_id)
		return
	_run_safely(func(): _fsm.handle_interaction(obj_id))

func _get_interactive_by_id(obj_id: String) -> InteractiveObject:
	match obj_id:
		"grandpa": return _grandpa_node
		"memory_echo_1": return _memory_echo_1_node
		"memory_echo_2": return _memory_echo_2_node
	return null

func _mark_interaction_completed(obj_id: String) -> void:
	var obj = _get_interactive_by_id(obj_id)
	if obj and not obj.allow_repeat:
		obj.mark_completed()


# ============================================================
# 叙事面板（关卡1/2同款: 超时保护 + 输入屏蔽配对）
# ============================================================

func _show_narrative(text: String, callback: Callable = Callable()) -> void:
	InputManager.block_input("叙事面板", self)

	if _narrative_open:
		if _narrative_panel: _narrative_panel.hide()
		_narrative_open = false
	_is_interacting = true
	_narrative_open = true
	_freeze_player(true)
	if _narrative_panel:
		_narrative_panel.show()
		if _narrative_text: _narrative_text.text = text
	await get_tree().create_timer(0.3).timeout

	_narrative_enter_pressed = false
	var wait_elapsed: float = 0.0
	var wait_delta: float = 0.05
	while _narrative_open and wait_elapsed < NARRATIVE_INPUT_TIMEOUT:
		if _narrative_enter_pressed:
			break
		await get_tree().create_timer(wait_delta).timeout
		wait_elapsed += wait_delta

	if _narrative_panel: _narrative_panel.hide()
	_freeze_player(false)
	_narrative_open = false
	_is_interacting = false
	_interact_cooldown = 0.0

	InputManager.unblock_input("叙事面板")

	if callback.is_valid():
		_run_safely(callback)


# ============================================================
# 黑屏过渡工具
# ============================================================

func _fade_blackout(to_alpha: float, duration: float) -> void:
	if not _blackout_overlay:
		await get_tree().create_timer(duration).timeout
		return
	_blackout_overlay.show()
	var tween = create_tween()
	tween.tween_property(_blackout_overlay, "color:a", to_alpha, duration)
	await tween.finished
	if to_alpha <= 0.0:
		_blackout_overlay.hide()


# ============================================================
# 阶段1: 凉茶铺前 — 爷爷对话链
# ============================================================

func _start_grandpa_dialogue() -> void:
	if not level_data: return
	grandpa_dialogue_index = 0
	_advance_grandpa_dialogue()

func _advance_grandpa_dialogue() -> void:
	if not level_data: return
	if grandpa_dialogue_index >= level_data.grandpa_dialogues.size():
		# 对话链结束 → 触发崩坏
		_trigger_grandpa_glitch()
		return

	var entry = level_data.grandpa_dialogues[grandpa_dialogue_index]
	var speaker = entry.get("speaker", "")
	var text = entry.get("text", "")

	var formatted = ""
	match speaker:
		"Ming":
			formatted = "[color=white]阿明：[/color]" + text
		"Grandpa":
			if grandpa_dialogue_index >= 4:
				# 后两轮爷爷对话越来越机械
				formatted = "[color=gray][GLITCH] [/color][color=cyan]爷爷：[/color]" + text
			else:
				formatted = "[color=cyan]爷爷：[/color]" + text
		_:
			formatted = text

	grandpa_dialogue_index += 1

	# 爷爷的第二轮重复 → 用轻微视觉暗示
	if speaker == "Grandpa" and grandpa_dialogue_index == 4:
		# 第二次重复台词时，给爷爷的indicator闪一下绿光
		_flash_grandpa_indicator()

	_show_narrative(formatted, func():
		_advance_grandpa_dialogue()
	)

func _flash_grandpa_indicator() -> void:
	if not _grandpa_node: return
	var indicator = _grandpa_node.get_node_or_null("Indicator")
	if not indicator: return
	indicator.color = Color(0, 1, 0, 0.5)
	var tween = create_tween()
	tween.tween_property(indicator, "color:a", 0.15, 0.3)
	tween.tween_property(indicator, "color:a", 0.5, 0.3)

func _trigger_grandpa_glitch() -> void:
	if not level_data: return
	# 爷爷崩坏对话
	_show_narrative(level_data.grandpa_glitch_text, func():
		_show_narrative(level_data.ming_realization_text, func():
			# 进入赛博异化转场
			_trigger_cyber_transition()
		)
	)


# ============================================================
# 阶段2: 赛博异化转场（3秒失控演出）
# ============================================================

func _trigger_cyber_transition() -> void:
	if _transition_running: return
	_transition_running = true
	_is_interacting = true
	current_state = LevelState.CYBER_TRANSITION
	print("[Level_03] 赛博异化转场开始")

	_freeze_player(true)
	InputManager.block_input("异化转场", self)

	# 1) 爷爷NPC消失
	if _grandpa_node and is_instance_valid(_grandpa_node):
		_grandpa_node.is_active = false
		# 爷爷变成全息监控眼视觉
		var indicator = _grandpa_node.get_node_or_null("Indicator")
		if indicator:
			indicator.color = Color(1, 0, 0, 0.8)  # 红色监控眼
			indicator.size = Vector2(60, 60)
			indicator.position = Vector2(-30, -30)

	# 2) Glitch效果增强
	if _glitch_overlay and _glitch_overlay.material:
		_glitch_overlay.show()
		var tween = create_tween()
		tween.tween_property(_glitch_overlay.material, "shader_parameter/intensity", 1.0, 1.5)

	# 3) 等待1.5秒（Glitch增强期间）
	await get_tree().create_timer(1.5).timeout

	# 4) 双空间切换: 凉茶铺→赛博城
	if _safe_haven_root:
		_safe_haven_root.visible = false
		_set_space_collision(_safe_haven_root, false)
	if _cyber_city_root:
		_cyber_city_root.visible = true
		_set_space_collision(_cyber_city_root, true)

	# 5) 切换玩家为赛博皮肤（含延迟命中战斗系统）
	var cyber_spawn_pos = level_data.cyber_spawn if level_data else Vector2(200, 550)
	_swap_player_to_cyber(cyber_spawn_pos)

	# 6) 渐黑1秒 + Glitch渐退
	if _blackout_overlay:
		_blackout_overlay.color.a = 1.0
		_blackout_overlay.show()
	await get_tree().create_timer(0.5).timeout
	if _glitch_overlay and _glitch_overlay.material:
		var tween2 = create_tween()
		tween2.tween_property(_glitch_overlay.material, "shader_parameter/intensity", 0.0, 1.0)
	await _fade_blackout(0.0, 0.5)

	# 7) 恢复玩家控制 + 启动赛博阶段
	_restore_cyber_mechanics()
	_freeze_player(false)

	# 8) CodeBuddy全频道广播
	await _show_codebuddy_broadcast()

	# 9) 启动代码雨 + 生成初始敌人 + 启动刷新计时器
	_start_code_rain()
	_spawn_cyber_enemies()
	if _enemy_spawn_timer:
		_enemy_spawn_timer.start()

	# 10) 激活交互物
	if _memory_echo_1_node:
		_memory_echo_1_node.is_active = true
	if _memory_echo_2_node:
		_memory_echo_2_node.is_active = true

	current_state = LevelState.CYBER_CITY
	InputManager.unblock_input("异化转场")
	_transition_running = false
	_safe_end_interaction()
	print("[Level_03] 进入 CYBER_CITY")


# ============================================================
# CodeBuddy 全频道广播
# ============================================================

func _show_codebuddy_broadcast() -> void:
	if not level_data: return
	var lines = level_data.codebuddy_broadcast_lines
	if lines.is_empty():
		return
	# 广播期间玩家已被冻结+输入已屏蔽，直接使用 _show_narrative
	# 每行广播单独弹出，玩家按 Enter 继续
	for i in range(lines.size()):
		var line = lines[i]
		var formatted = "[color=red][BROADCAST] " + line + "[/color]"
		await _show_narrative(formatted)


# ============================================================
# 代码雨
# ============================================================

func _start_code_rain() -> void:
	if _code_rain_overlay:
		_code_rain_overlay.show()
		var tween = create_tween()
		tween.tween_property(_code_rain_overlay, "color:a", 0.15, 1.0)
	print("[Level_03] 代码雨启动")

func _stop_code_rain() -> void:
	if _code_rain_overlay:
		if is_instance_valid(_code_rain_overlay):
			var tween = create_tween()
			tween.tween_property(_code_rain_overlay, "color:a", 0.0, 1.0)
		_code_rain_overlay.hide()


# ============================================================
# 阶段3: AI阻挠弹窗（1/3处 和 2/3处）
# ============================================================

func _on_warning_1_trigger_body_entered(body: Node2D) -> void:
	if not _is_player_body(body): return
	if ai_warning_1_triggered: return
	if current_state not in [LevelState.CYBER_CITY, LevelState.MEMORY_COLLECTION]: return
	ai_warning_1_triggered = true
	if level_data and level_data.ai_warning_1_text != "":
		_show_narrative(level_data.ai_warning_1_text)

func _on_warning_2_trigger_body_entered(body: Node2D) -> void:
	if not _is_player_body(body): return
	if ai_warning_2_triggered: return
	if current_state not in [LevelState.CYBER_CITY, LevelState.MEMORY_COLLECTION]: return
	ai_warning_2_triggered = true
	if level_data and level_data.ai_warning_2_text != "":
		_show_narrative(level_data.ai_warning_2_text)

func _is_player_body(body: Node2D) -> bool:
	if not body is CharacterBody2D:
		return false
	if body.collision_layer & GlobalDefine.Collision.PLAYER:
		return true
	return body.is_in_group("player")


# ============================================================
# 阶段3: 赛博城敌人管理
# ============================================================

func _spawn_cyber_enemies() -> void:
	if not _enemy_slime_scene:
		push_warning("[Level_03] Enemy_Slime.tscn 缺失，跳过敌人")
		return

	# 清理程序
	var cleaner_config = load("res://DataConfig/Enemy/CleanerConfig.tres") as EnemyConfig
	var cleaner_points = level_data.cleaner_spawn_points if level_data else []
	if cleaner_points.is_empty():
		cleaner_points = [Vector2(2400, 540), Vector2(3600, 540), Vector2(5200, 540), Vector2(6800, 540), Vector2(7600, 540)]
	for i in range(mini(cleaner_points.size(), 5)):
		var enemy = _spawn_enemy_with_config(_enemy_slime_scene, cleaner_points[i], cleaner_config)
		if enemy:
			enemy.modulate = Color(0.3, 0.35, 0.4, 0.95)  # 灰蓝色
			_cyber_enemies.append(enemy)

	# 安保探照灯
	var security_config = load("res://DataConfig/Enemy/SecurityConfig.tres") as EnemyConfig
	var security_points = level_data.security_spawn_points if level_data else []
	if security_points.is_empty():
		security_points = [Vector2(3000, 480), Vector2(4800, 480), Vector2(7200, 480)]
	for i in range(mini(security_points.size(), 3)):
		var enemy = _spawn_enemy_with_config(_enemy_slime_scene, security_points[i], security_config)
		if enemy:
			enemy.modulate = Color(0.9, 0.15, 0.15, 0.95)  # 红色
			_cyber_enemies.append(enemy)

	print("[Level_03] 赛博敌人生成: %d 只" % _cyber_enemies.size())

func _spawn_enemy_with_config(scene: PackedScene, spawn_pos: Vector2, config: EnemyConfig) -> Node2D:
	if not scene: return null
	var enemy = scene.instantiate()
	if config:
		enemy.config = config
	enemy.global_position = spawn_pos
	if _dynamic_actors:
		_dynamic_actors.add_child(enemy)
	else:
		add_child(enemy)
	return enemy

func _on_enemy_spawn_timer_timeout() -> void:
	if current_state not in [LevelState.CYBER_CITY, LevelState.MEMORY_COLLECTION]:
		return
	if not _enemy_slime_scene:
		return
	# 性能约束
	_cyber_enemies = _cyber_enemies.filter(func(e): return is_instance_valid(e))
	if _cyber_enemies.size() >= ENEMY_MAX_ALIVE:
		return
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	var onscreen := 0
	for e in _cyber_enemies:
		if e.global_position.distance_to(player.global_position) < 700.0:
			onscreen += 1
	if onscreen >= ENEMY_MAX_ONSCREEN:
		return

	# 在玩家前方随机刷新清理程序
	var side = 1.0 if randf() > 0.3 else -1.0  # 偏向前方
	var spawn_x = clampf(player.global_position.x + side * randf_range(400.0, 600.0), 200.0, 11800.0)
	var config = load("res://DataConfig/Enemy/CleanerConfig.tres") as EnemyConfig
	var enemy = _spawn_enemy_with_config(_enemy_slime_scene, Vector2(spawn_x, 540), config)
	if enemy:
		enemy.modulate = Color(0.3, 0.35, 0.4, 0.95)
		_cyber_enemies.append(enemy)


# ============================================================
# 击退反转（核心关卡3机制）
# ============================================================

func _on_player_hurt(data: Dictionary) -> void:
	if current_state not in [LevelState.CYBER_CITY, LevelState.MEMORY_COLLECTION]:
		return
	var player = data.get("player")
	if not player or not is_instance_valid(player):
		return

	var flags = GameManager.dream_runtime_flags
	var has_damage_reduction = flags.get("player_damage_reduction", false)

	# 伤害减免：关卡2配置了 damage_reduction=true → 回补一半伤害
	if has_damage_reduction:
		var heal_amount = data.get("damage", 0) / 2
		if heal_amount > 0 and player.current_health < player.max_health:
			player.current_health = mini(player.current_health + heal_amount, player.max_health)
			EventBus.emit(GlobalDefine.EventName.HEALTH_CHANGED, {
				"target": player,
				"current_health": player.current_health,
				"max_health": player.max_health
			})

	# 击退方向反转：强制向左（凉茶铺方向）击退
	player.velocity.x = -KNOCKBACK_REVERSE_FORCE




func _apply_interference_restrictions() -> void:
	var player = GameManager.player_ref
	if not player: return
	player.can_jump = true
	player.can_dash = false
	player.can_skill = false
	player.can_attack = true
	player.runtime_move_speed_multiplier = 0.65


# ============================================================
# 阶段4: 异常数据光团收集
# ============================================================

func _handle_memory_echo_1() -> void:
	if not level_data: return
	memory_echoes_collected += 1
	_mark_interaction_completed("memory_echo_1")
	# 温暖光晕效果
	_show_warm_glow()
	_show_narrative(level_data.memory_echo_1_subtitle, func():
		# CodeBuddy拦截
		_show_narrative(level_data.memory_echo_1_codebuddy, func():
			_hide_warm_glow()
			_check_memory_collection_complete()
		)
	)

func _handle_memory_echo_2() -> void:
	if not level_data: return
	memory_echoes_collected += 1
	_mark_interaction_completed("memory_echo_2")
	# 温暖光晕效果
	_show_warm_glow()
	_show_narrative(level_data.memory_echo_2_subtitle, func():
		# CodeBuddy拦截
		_show_narrative(level_data.memory_echo_2_codebuddy, func():
			_hide_warm_glow()
			_check_memory_collection_complete()
		)
	)

func _check_memory_collection_complete() -> void:
	if memory_echoes_collected >= 2:
		# 所有光团收集完毕 → 触发觉醒
		_trigger_awakening()
	else:
		# 进入光团收集阶段
		if current_state == LevelState.CYBER_CITY:
			current_state = LevelState.MEMORY_COLLECTION
			print("[Level_03] 进入 MEMORY_COLLECTION (已收集 %d/2)" % memory_echoes_collected)

func _show_warm_glow() -> void:
	if _warm_glow_overlay:
		_warm_glow_overlay.show()
		var tween = create_tween()
		tween.tween_property(_warm_glow_overlay, "color:a", 0.25, 0.5)

func _hide_warm_glow() -> void:
	if _warm_glow_overlay:
		var tween = create_tween()
		tween.tween_property(_warm_glow_overlay, "color:a", 0.0, 0.8)
		await tween.finished
		_warm_glow_overlay.hide()


# ============================================================
# 阶段5: 觉醒与终局
# ============================================================

func _trigger_awakening() -> void:
	if _transition_running: return
	_transition_running = true
	_is_interacting = true
	current_state = LevelState.AWAKENING
	print("[Level_03] 觉醒开始")

	InputManager.block_input("觉醒", self)
	_freeze_player(true)

	# 1) 停止敌人 + 代码雨
	_stop_cyber_elements()

	# 2) 赛博世界褪色（变灰暗线框）
	if _cyber_city_root:
		var tween = create_tween()
		tween.tween_property(_cyber_city_root, "modulate", Color(0.3, 0.3, 0.35), 1.5)
		await tween.finished

	# 3) 核心独白
	if level_data and level_data.awakening_monologue != "":
		_show_narrative(level_data.awakening_monologue, func():
			_trigger_level_end()
		)
	else:
		_trigger_level_end()

func _stop_cyber_elements() -> void:
	# 停止敌人刷新
	if _enemy_spawn_timer:
		_enemy_spawn_timer.stop()
	# 停止代码雨
	_stop_code_rain()
	# 清理敌人（冻结在原地，不删除——视觉上"失去动力"）
	for e in _cyber_enemies:
		if is_instance_valid(e):
			e.set_physics_process(false)

func _trigger_level_end() -> void:
	current_state = LevelState.LEVEL_END_TRANSIT
	print("[Level_03] 终局转场")

	# 显示终局提示
	if _ending_prompt:
		_ending_prompt.show()
		if _ending_label and level_data:
			_ending_label.text = level_data.override_protocol_text
	_ending_enter_armed = true

	# 终局提示阶段解除全局屏蔽: Enter 经 game_action/_input 走 LEVEL_END_TRANSIT 分支
	InputManager.unblock_input("觉醒")
	_transition_running = false

func _emit_level_complete() -> void:
	if _level_complete_emitted: return
	_level_complete_emitted = true
	var next_path = level_data.next_level_path if level_data else "res://LevelModule/Formal/Level_04.tscn"
	print("[Level_03] 发射 LEVEL_COMPLETE → ", next_path)
	_full_cleanup()
	EventBus.emit(GlobalDefine.EventName.LEVEL_COMPLETE, {
		"level": self,
		"next_level": next_path
	})

## 关卡退出全量清理
func _full_cleanup() -> void:
	# 清理敌人
	for e in _cyber_enemies:
		if is_instance_valid(e):
			GameManager.unregister_enemy(e)
			e.queue_free()
	_cyber_enemies.clear()
	# 停止计时器
	if _enemy_spawn_timer and is_instance_valid(_enemy_spawn_timer):
		_enemy_spawn_timer.stop()
	# 停止音效
	_stop_sfx_loop(_sfx_alarm_player)
	_sfx_alarm_player = null
	# 解除输入屏蔽
	InputManager.unblock_input("关卡3清理")
	EventBus.unsubscribe_all(self)


# ============================================================
# 音效安全降级挂点（关卡2同款）
# ============================================================

func _play_sfx_loop_safe(path: String) -> AudioStreamPlayer:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var stream = load(path) as AudioStream
	if not stream:
		return null
	var player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(func():
		if is_instance_valid(player): player.play()
	)
	player.play()
	return player

func _stop_sfx_loop(player: AudioStreamPlayer) -> void:
	if player and is_instance_valid(player):
		player.stop()
		player.queue_free()
