# ============================================================
# Level_02.gd - 第二关「撕裂与沉溺」控制器
# 场景构建 → Level_02_SceneBuilder
# UI 构建   → Level_02_UIBuilder
# 状态调度  → Level_02_FSM
#
# 架构（与 Level_01 完全一致的四文件拆分 + 单一中枢原则）:
#   1. 单场景双空间: DreamWorldRoot / RealityRoomRoot 显隐+碰撞 联动切换
#   2. 输入: InputManager.game_action 信号为主 + _input() 兜底（关卡1模式）
#      长按 Tab 为连续输入，仅在干扰/睁眼状态下 _process 轮询 KEY_TAB
#   3. 状态幂等: _is_interacting/_interact_cooldown 任何路径退出都自愈
#   4. 嵌套 block 应对: InputManager 非栈式 → 外层长流程在 _show_narrative
#      返回后重新 block，保证最终状态正确（与关卡1 _trigger_sleep_cycle 同模式）
#   5. 音效安全降级: 路径存于 Level02Data, 资源不存在时跳过播放
# ============================================================
extends LevelBase
class_name Level_02

@export var level_data: Level02Data = null

enum LevelState {
	DREAM_ATTIC,             # 梦境阁楼：满洲窗、木趟栊门
	DREAM_STREET,            # 老街探索：藤椅、低难度敌人
	DREAM_CLIFF_LOOP,        # 断崖坠落循环
	DREAM_INTERFERENCE,      # 现实干扰：红光、手机UI、阴影敌人、沉重化
	WAKING_HOLD_TAB,         # 长按 Tab 睁眼
	REALITY_PHONE_LOCKED,    # 现实房间：仅手机可交互
	REALITY_PHONE_READ,      # 已读短信，电脑解锁
	REALITY_IDE_CHAT,        # CodeBuddy 对话
	REALITY_CONFIG_EDIT,     # 配置篡改解谜
	REALITY_RECOMPILE,       # 重新编译日志播放
	REALITY_BED_READY,       # 床解锁，等待入梦
	LEVEL_END_TRANSIT        # 关卡结束转场
}

var current_state: int = LevelState.DREAM_ATTIC

# ---- 任务进度变量 ----
var has_observed_window: bool = false
var has_entered_street: bool = false
var has_triggered_chair_memory: bool = false
var fall_count: int = 0
var interference_triggered: bool = false
var wake_hold_time: float = 0.0
var has_read_reality_phone: bool = false
var current_chat_index: int = 0
var config_flags: Dictionary = {
	"player_damage_reduction": false,
	"base_jump_height": 10,
	"allow_external_signal": true
}
var recompilation_done: bool = false

# ---- 场景节点引用（SceneBuilder 写入） ----
var _dream_root: Node2D = null
var _reality_root: Node2D = null
var _dynamic_actors: Node2D = null
var _attic_door_wall: StaticBody2D = null
var _street_entry_trigger: Area2D = null
var _cliff_approach_trigger: Area2D = null
var _fall_pit_trigger: Area2D = null
var _cliff_safe_spawn: Marker2D = null
var _reality_spawn: Marker2D = null

# ---- 交互物引用 ----
var _window_node: InteractiveObject = null
var _attic_door_node: InteractiveObject = null
var _rattan_chair_node: InteractiveObject = null
var _reality_phone_node: InteractiveObject = null
var _reality_computer_node: InteractiveObject = null
var _reality_bed_node: InteractiveObject = null
var _all_interactives: Array[InteractiveObject] = []

# ---- UI 引用（UIBuilder 写入） ----
var _blackout_overlay: ColorRect = null
var _narrative_panel: Panel = null
var _narrative_text: RichTextLabel = null
var _red_overlay: ColorRect = null
var _wake_hint_label: Label = null
var _phone_msg_panel: Panel = null
var _phone_msg_text: RichTextLabel = null
var _eye_overlay: Control = null
var _eye_rect_top: ColorRect = null
var _eye_rect_bottom: ColorRect = null
var _eye_rect_left: ColorRect = null
var _eye_rect_right: ColorRect = null
var _ide_ui: Control = null
var _chat_window: RichTextLabel = null
var _config_ui: Panel = null
var _config_value_labels: Array = []
var _config_feedback_labels: Array = []
var _config_buttons: Array = []
var _recompile_button: Button = null
var _recompile_panel: Panel = null
var _recompile_log: RichTextLabel = null
var _ending_prompt: Control = null
var _ending_label: Label = null

# ---- 交互/叙事状态（关卡1同款幂等模式） ----
var _interact_cooldown: float = 0.0
var _is_interacting: bool = false
var _narrative_open: bool = false
var _narrative_enter_pressed: bool = false
var _transition_running: bool = false
const NARRATIVE_INPUT_TIMEOUT: float = 30.0

# ---- 坠落循环 ----
var _fall_reset_running: bool = false

# ---- 干扰期 ----
var _red_tween: Tween = null
var _shadow_spawn_timer: Timer = null
var _shadow_enemies: Array[Node2D] = []
const SHADOW_MAX_ALIVE: int = 8
const SHADOW_MAX_ONSCREEN: int = 6
const SHADOW_SPAWN_INTERVAL: float = 1.5
const INTERFERENCE_MOVE_MULTIPLIER: float = 0.55
const DEATH_GUARD_HEALTH: int = 10

# ---- 老街敌人 ----
var _street_enemies: Array[Node2D] = []
var _enemy_slime_scene: PackedScene = null

# ---- 睁眼 ----
var wake_hold_required: float = 1.5
const VIEW_W: float = 1280.0
const VIEW_H: float = 720.0

# ---- 终局 ----
var _bed_glow_tween: Tween = null
var _ending_enter_armed: bool = false
var _level_complete_emitted: bool = false

# ---- 音效挂点 ----
var _sfx_phone_player: AudioStreamPlayer = null
var _sfx_noise_player: AudioStreamPlayer = null
var _fsm: Level_02_FSM = null


# ============================================================
# 生命周期
# ============================================================

func _on_ready() -> void:
	super._on_ready()

	if not level_config:
		level_config = load("res://DataConfig/Level/Level02Config.tres") as LevelConfig
		_apply_config()
	if not level_data:
		level_data = load("res://DataConfig/Level/Level02Data.tres") as Level02Data
	wake_hold_required = level_data.wake_hold_required if level_data else 1.5

	# 预加载敌人场景（避免干扰期频繁 load）
	var slime_path = "res://EnemyModule/Formal/Enemy_Slime.tscn"
	if ResourceLoader.exists(slime_path):
		_enemy_slime_scene = load(slime_path)

	var builder = Level_02_SceneBuilder.new(self)
	builder.build_all()

	# 现实房间初始: 隐藏 + 碰撞禁用（双空间在同一坐标系，必须物理隔离）
	_set_space_collision(_reality_root, false)

	_setup_camera_limits()

	_restore_player_mechanics()
	_ensure_player_collision_layer()

	_all_interactives = [
		_window_node, _attic_door_node, _rattan_chair_node,
		_reality_phone_node, _reality_computer_node, _reality_bed_node
	]

	EventBus.subscribe(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, self, "_on_object_interacted")
	_fsm = Level_02_FSM.new(self)

	InputManager.game_action.connect(_on_game_action)

	# 阴影敌人刷新计时器
	_shadow_spawn_timer = Timer.new()
	_shadow_spawn_timer.name = "ShadowSpawnTimer"
	_shadow_spawn_timer.wait_time = SHADOW_SPAWN_INTERVAL
	_shadow_spawn_timer.one_shot = false
	_shadow_spawn_timer.autostart = false
	_shadow_spawn_timer.timeout.connect(_on_shadow_spawn_timer_timeout)
	add_child(_shadow_spawn_timer)

	_load_hud()
	set_process(true)

	# 开场独白
	if level_data and level_data.attic_intro_text != "":
		_show_narrative(level_data.attic_intro_text)

	print("[Level_02] 初始化完成 — 当前: DREAM_ATTIC")


func _load_hud() -> void:
	var hud_path = "res://UI/HUD.tscn"
	if ResourceLoader.exists(hud_path):
		var hud = load(hud_path).instantiate()
		add_child(hud)
		print("[Level_02] HUD 加载成功")
	else:
		push_warning("[Level_02] HUD.tscn 未找到，跳过")


# ============================================================
# 工具方法（与关卡1同模式）
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
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		push_warning("[Level_02] 玩家 collision_layer 缺失 PLAYER 位，修正中...")
		player.collision_layer |= GlobalDefine.Collision.PLAYER

## 递归启用/禁用某空间根节点下所有 StaticBody2D 的碰撞
## 双空间共存于同一坐标系: 隐藏空间必须同时禁用碰撞，否则地形互相干涉
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
	_set_camera_limits(level_config.camera_limit_left, level_config.camera_limit_right,
		level_config.camera_limit_top, level_config.camera_limit_bottom)

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
	print("[Level_02] SmoothCamera limit 更新 (left=%d, right=%d)" % [left, right])


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
	# 关卡2设计约束：禁用二段跳（梦境规则限制；坠落循环是核心机制，二段跳可绕过深渊）
	# 在关卡模块内拦截，不修改 PlayerBase 核心代码
	player.can_double_jump = false
	player.runtime_move_speed_multiplier = 1.0

## 关卡级技能限制守卫：每帧强制维持 can_double_jump=false
## 防止任何外部路径意外重新启用被禁技能
func _enforce_level_restrictions() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player): return
	if player.can_double_jump:
		player.can_double_jump = false

## 干扰期"沉重化": 禁跳/禁冲刺/禁技能/移速降低（保留攻击表达围攻压力）
func _apply_interference_restrictions() -> void:
	var player = GameManager.player_ref
	if not player: return
	player.can_jump = false
	player.can_dash = false
	player.can_skill = false
	player.can_attack = true
	player.runtime_move_speed_multiplier = INTERFERENCE_MOVE_MULTIPLIER

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
# 输入处理（关卡1模式: 信号驱动为主 + _input 兜底）
# ============================================================

func _on_game_action(action: StringName, _event: InputEvent) -> void:
	if action != &"ui_accept":
		return
	_handle_accept_input()

func _handle_accept_input() -> void:
	if current_state == LevelState.REALITY_IDE_CHAT:
		_render_next_chat_line()
		return
	if current_state == LevelState.LEVEL_END_TRANSIT:
		if _ending_enter_armed:
			_ending_enter_armed = false
			_emit_level_complete()
		return
	if _narrative_open:
		_narrative_enter_pressed = true
		return
	if current_state in [LevelState.REALITY_CONFIG_EDIT, LevelState.REALITY_RECOMPILE]:
		return  # 鼠标操作阶段，Enter 不参与
	if _is_interacting or _interact_cooldown > 0.0 or _transition_running or _fall_reset_running:
		if not _transition_running and not _fall_reset_running and _interact_cooldown > 0.5:
			_safe_end_interaction()
		return
	var obj = _find_nearby_interactive()
	if obj:
		_interact_cooldown = 0.3
		EventBus.emit(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, {"object_id": obj.object_id})

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return

	if current_state == LevelState.REALITY_IDE_CHAT:
		_render_next_chat_line()
		get_viewport().set_input_as_handled()
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

	if current_state in [LevelState.REALITY_CONFIG_EDIT, LevelState.REALITY_RECOMPILE]:
		get_viewport().set_input_as_handled()
		return

	if _is_interacting or _interact_cooldown > 0.0 or _transition_running or _fall_reset_running:
		if not _transition_running and not _fall_reset_running and _interact_cooldown > 0.5:
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

	# 关卡级技能限制守卫：确保被禁技能不会被任何外部路径意外恢复
	_enforce_level_restrictions()

	_poll_interactives_in_range()

	# 长按 Tab 睁眼（仅干扰/睁眼状态轮询; 转场/重置/叙事期间不累计）
	if current_state in [LevelState.DREAM_INTERFERENCE, LevelState.WAKING_HOLD_TAB]:
		if not _transition_running and not _fall_reset_running:
			_update_wake_hold(delta)
		# 死亡兜底守卫: 血量过低强制"噩梦惊醒"，不走 GameOver
		_check_interference_death_guard()

	# 防御性自愈（关卡1同款）
	if _is_interacting and current_state not in [LevelState.REALITY_IDE_CHAT, LevelState.REALITY_CONFIG_EDIT, LevelState.REALITY_RECOMPILE, LevelState.LEVEL_END_TRANSIT]:
		if not _narrative_open and not _transition_running and not _fall_reset_running:
			_safe_end_interaction()

func _poll_interactives_in_range() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	for obj in _all_interactives:
		if is_instance_valid(obj):
			obj.check_player_in_range(player)

func _safe_end_interaction() -> void:
	if not _narrative_open and not _transition_running and not _fall_reset_running:
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
		push_error("[Level_02] FSM 为 null，无法处理交互: %s" % obj_id)
		return
	_run_safely(func(): _fsm.handle_interaction(obj_id))

func _get_interactive_by_id(obj_id: String) -> InteractiveObject:
	match obj_id:
		"window_l2": return _window_node
		"attic_door": return _attic_door_node
		"rattan_chair": return _rattan_chair_node
		"reality_phone": return _reality_phone_node
		"reality_computer": return _reality_computer_node
		"reality_bed": return _reality_bed_node
	return null

func _mark_interaction_completed(obj_id: String) -> void:
	var obj = _get_interactive_by_id(obj_id)
	if obj and not obj.allow_repeat:
		obj.mark_completed()


# ============================================================
# 叙事面板（关卡1同款: 超时保护 + 输入屏蔽配对）
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
# 阁楼 → 老街（木趟栊门）
# ============================================================

func _handle_window_observe() -> void:
	if not level_data: return
	has_observed_window = true
	_mark_interaction_completed("window_l2")
	_show_narrative(level_data.window_text_l2)

func _transition_attic_to_street() -> void:
	if _transition_running: return
	if not level_data: return
	_mark_interaction_completed("attic_door")
	_show_narrative(level_data.attic_door_text, func(): _do_attic_door_transition())

func _do_attic_door_transition() -> void:
	_transition_running = true
	_is_interacting = true
	InputManager.block_input("趟栊门转场", self)
	_freeze_player(true)

	await _fade_blackout(1.0, 0.8)

	# 移除门墙碰撞 + 移动玩家到老街入口
	if _attic_door_wall and is_instance_valid(_attic_door_wall):
		var shape = _attic_door_wall.get_node_or_null("CollisionShape2D")
		if shape: shape.disabled = true
		_attic_door_wall.visible = false
	if _attic_door_node and is_instance_valid(_attic_door_node):
		_attic_door_node.set_active(false)
		_attic_door_node.visible = false
	var player = GameManager.player_ref
	if player and is_instance_valid(player):
		player.global_position = Vector2(980, 550)
		player.velocity = Vector2.ZERO

	_enter_street_state()

	await _fade_blackout(0.0, 0.8)

	_freeze_player(false)
	InputManager.unblock_input("趟栊门转场")
	_transition_running = false
	_safe_end_interaction()

## 状态推进: ATTIC → STREET（门转场与触发器双入口, 幂等）
func _enter_street_state() -> void:
	if has_entered_street:
		return
	has_entered_street = true
	current_state = LevelState.DREAM_STREET
	_spawn_street_enemies()
	print("[Level_02] 进入 DREAM_STREET")

func _on_street_entry_body_entered(body: Node2D) -> void:
	if not _is_player_body(body): return
	if current_state != LevelState.DREAM_ATTIC: return
	_enter_street_state()

func _is_player_body(body: Node2D) -> bool:
	if not body is CharacterBody2D:
		return false
	if body.collision_layer & GlobalDefine.Collision.PLAYER:
		return true
	return body.is_in_group("player")


# ============================================================
# 老街敌人
# ============================================================

func _spawn_street_enemies() -> void:
	if not _enemy_slime_scene:
		push_warning("[Level_02] Enemy_Slime.tscn 缺失，跳过老街敌人")
		return
	var config = load("res://DataConfig/Enemy/StreetSlimeConfig.tres") as EnemyConfig
	var spawn_points: Array[Vector2] = []
	if level_data and not level_data.street_enemy_spawn_points.is_empty():
		spawn_points = level_data.street_enemy_spawn_points
	else:
		spawn_points = [Vector2(1500, 540), Vector2(2100, 540), Vector2(2800, 540)]
	# 性能约束: 常驻老街敌人 ≤ 5（走廊 3x 后人数同步扩展）
	var count = mini(spawn_points.size(), 5)
	for i in range(count):
		var enemy = _spawn_enemy_with_config(_enemy_slime_scene, spawn_points[i], config)
		if enemy:
			_street_enemies.append(enemy)
	print("[Level_02] 老街敌人生成: %d 只" % _street_enemies.size())

## 关卡内工具: instantiate 后先赋 config 再 add_child（保证 _ready 应用配置）
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


# ============================================================
# 断崖循环
# ============================================================

func _on_cliff_approach_body_entered(body: Node2D) -> void:
	if not _is_player_body(body): return
	if current_state != LevelState.DREAM_STREET: return
	current_state = LevelState.DREAM_CLIFF_LOOP
	print("[Level_02] 进入 DREAM_CLIFF_LOOP")
	if level_data and level_data.cliff_first_sight_text != "":
		_show_narrative(level_data.cliff_first_sight_text)

func _on_fall_pit_body_entered(body: Node2D) -> void:
	if not _is_player_body(body): return
	if current_state not in [LevelState.DREAM_STREET, LevelState.DREAM_CLIFF_LOOP, LevelState.DREAM_INTERFERENCE, LevelState.WAKING_HOLD_TAB]: return
	if _fall_reset_running or _transition_running: return
	_trigger_fall_reset()

func _trigger_fall_reset() -> void:
	_fall_reset_running = true
	fall_count += 1
	print("[Level_02] 坠崖重置 #%d" % fall_count)
	InputManager.block_input("坠落重置", self)
	_freeze_player(true)

	await _fade_blackout(1.0, 0.5)

	var player = GameManager.player_ref
	if player and is_instance_valid(player):
		var spawn_pos = _cliff_safe_spawn.position if _cliff_safe_spawn else Vector2(8340, 550)
		player.global_position = spawn_pos
		player.velocity = Vector2.ZERO

	await _fade_blackout(0.0, 0.3)

	_freeze_player(false)
	InputManager.unblock_input("坠落重置")
	_fall_reset_running = false
	_safe_end_interaction()

	var threshold = level_data.interference_fall_threshold if level_data else 1
	if fall_count >= threshold and not interference_triggered:
		_trigger_reality_interference()


# ============================================================
# 现实干扰
# ============================================================

func _trigger_reality_interference() -> void:
	if interference_triggered: return
	interference_triggered = true
	current_state = LevelState.DREAM_INTERFERENCE
	print("[Level_02] 触发现实干扰 — DREAM_INTERFERENCE")

	# 视觉: 红光循环闪烁 + 梦境冷灰化
	if _red_overlay:
		_red_overlay.color.a = 0.0
		_red_overlay.show()
		_kill_red_tween()
		_red_tween = create_tween()
		_red_tween.set_loops()
		_red_tween.tween_property(_red_overlay, "color:a", 0.4, 0.6)
		_red_tween.tween_property(_red_overlay, "color:a", 0.12, 0.6)
	if _dream_root:
		var grey_tween = create_tween()
		grey_tween.tween_property(_dream_root, "modulate", Color(0.55, 0.55, 0.65), 1.5)

	# UI: 梦境短信回声 + Tab 提示
	if _phone_msg_panel and level_data:
		_phone_msg_panel.show()
		if _phone_msg_text:
			_phone_msg_text.text = "[b]%s[/b]\n\n%s" % [level_data.dream_phone_echo_sender, level_data.dream_phone_echo_text]
	if _wake_hint_label:
		_wake_hint_label.show()
	if _eye_overlay:
		_eye_overlay.show()
		_update_eye_overlay(0.0)

	# 听觉挂点（资源缺失时安全跳过）
	_sfx_phone_player = _play_sfx_loop_safe(level_data.sfx_phone_vibrate_path if level_data else "")
	_sfx_noise_player = _play_sfx_loop_safe(level_data.sfx_electric_noise_path if level_data else "")

	# 玩家"沉重化"
	_apply_interference_restrictions()

	# 阴影敌人定时刷新
	if _shadow_spawn_timer:
		_shadow_spawn_timer.start()

func _kill_red_tween() -> void:
	if _red_tween and is_instance_valid(_red_tween):
		_red_tween.kill()
	_red_tween = null

func _on_shadow_spawn_timer_timeout() -> void:
	if current_state not in [LevelState.DREAM_INTERFERENCE, LevelState.WAKING_HOLD_TAB]:
		return
	if not _enemy_slime_scene:
		return
	# 性能约束: 总存活 ≤ 8, 同屏 ≤ 6
	_shadow_enemies = _shadow_enemies.filter(func(e): return is_instance_valid(e))
	if _shadow_enemies.size() >= SHADOW_MAX_ALIVE:
		return
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	var onscreen := 0
	for e in _shadow_enemies:
		if e.global_position.distance_to(player.global_position) < 700.0:
			onscreen += 1
	if onscreen >= SHADOW_MAX_ONSCREEN:
		return
	# 在玩家两侧 400-600px 随机刷新, clamp 在老街/断崖范围
	var side = 1.0 if randf() > 0.5 else -1.0
	var spawn_x = clampf(player.global_position.x + side * randf_range(400.0, 600.0), 980.0, 8380.0)
	var config = load("res://DataConfig/Enemy/ShadowConfig.tres") as EnemyConfig
	var shadow = _spawn_enemy_with_config(_enemy_slime_scene, Vector2(spawn_x, 540), config)
	if shadow:
		shadow.modulate = Color(0, 0, 0, 0.9)
		_shadow_enemies.append(shadow)

## 干扰期死亡兜底: 血量过低 → 强制"噩梦惊醒"切现实，不触发 GameOver
func _check_interference_death_guard() -> void:
	if _transition_running: return
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	if player.current_health <= DEATH_GUARD_HEALTH:
		player.is_invincible = true
		player.invincible_timer = 999.0
		print("[Level_02] 死亡兜底触发 — 噩梦惊醒")
		_complete_wake_up_transition()


# ============================================================
# 长按 Tab 睁眼
# ============================================================

func _update_wake_hold(delta: float) -> void:
	if _narrative_open:
		return
	if Input.is_key_pressed(KEY_TAB):
		wake_hold_time += delta
		if current_state == LevelState.DREAM_INTERFERENCE and wake_hold_time > 0.0:
			current_state = LevelState.WAKING_HOLD_TAB
		_update_eye_overlay(wake_hold_time / wake_hold_required)
		if wake_hold_time >= wake_hold_required:
			_complete_wake_up_transition()
	else:
		wake_hold_time = maxf(wake_hold_time - delta * 2.0, 0.0)
		if current_state == LevelState.WAKING_HOLD_TAB and wake_hold_time <= 0.0:
			current_state = LevelState.DREAM_INTERFERENCE
		_update_eye_overlay(wake_hold_time / wake_hold_required)

## 4 块黑色 ColorRect 从四周向中心收缩 (progress 0→1)
func _update_eye_overlay(progress: float) -> void:
	var p = clampf(progress, 0.0, 1.0)
	if _eye_rect_top:
		_eye_rect_top.size = Vector2(VIEW_W, p * VIEW_H * 0.5)
	if _eye_rect_bottom:
		_eye_rect_bottom.size = Vector2(VIEW_W, p * VIEW_H * 0.5)
		_eye_rect_bottom.position = Vector2(0, VIEW_H - p * VIEW_H * 0.5)
	if _eye_rect_left:
		_eye_rect_left.size = Vector2(p * VIEW_W * 0.5, VIEW_H)
	if _eye_rect_right:
		_eye_rect_right.size = Vector2(p * VIEW_W * 0.5, VIEW_H)
		_eye_rect_right.position = Vector2(VIEW_W - p * VIEW_W * 0.5, 0)

func _complete_wake_up_transition() -> void:
	if _transition_running: return
	_transition_running = true
	_is_interacting = true
	print("[Level_02] 睁眼转场 — 切换到现实房间")
	InputManager.block_input("睁眼转场", self)
	_freeze_player(true)

	# 1) 遮罩收至全黑
	_update_eye_overlay(1.0)
	if _blackout_overlay:
		_blackout_overlay.color.a = 1.0
		_blackout_overlay.show()
	await get_tree().create_timer(0.6).timeout

	# 2) 清理梦境干扰表现（Tween/音效/敌人/UI）
	_cleanup_dream_interference()

	# 3) 空间切换: 隐藏梦境(禁碰撞) → 显示现实(启碰撞)
	if _dream_root:
		_dream_root.visible = false
		_set_space_collision(_dream_root, false)
	if _reality_root:
		_reality_root.visible = true
		_set_space_collision(_reality_root, true)
	# 梦境交互物彻底停用（含其内嵌物理阻挡体 — 藤椅坐标落在现实房间范围内，必须禁碰撞）
	for obj in [_window_node, _attic_door_node, _rattan_chair_node]:
		if is_instance_valid(obj):
			obj.set_active(false)
			obj.visible = false
			var blocker = obj.get_node_or_null("StaticBody2D")
			if blocker:
				var blocker_shape = blocker.get_node_or_null("CollisionShape2D")
				if blocker_shape:
					blocker_shape.disabled = true

	# 4) 玩家移到现实出生点 + 恢复状态 + 相机 limit 缩到现实房间
	var player = GameManager.player_ref
	if player and is_instance_valid(player):
		player.global_position = _reality_spawn.position if _reality_spawn else Vector2(1830, 550)
		player.velocity = Vector2.ZERO
		player.current_health = player.max_health
		player.is_invincible = false
		player.invincible_timer = 0.0
		# 关键: 干扰期受击触发闪烁(_update_blink)会在 _sprite_node.visible=false 帧
		# 冻结玩家; 直接置 invincible=false 跳过了 _update_timers→_restore_visibility 路径，
		# 导致精灵永远不可见。必须显式恢复。
		player._restore_visibility()
		EventBus.emit(GlobalDefine.EventName.HEALTH_CHANGED, {"target": player, "current_health": player.current_health, "max_health": player.max_health})
	_restore_player_mechanics()
	_set_camera_limits(-50, 1920, -500, 1200)

	# 5) 激活现实手机, 进入 REALITY_PHONE_LOCKED
	current_state = LevelState.REALITY_PHONE_LOCKED
	for obj in [_reality_phone_node, _reality_computer_node, _reality_bed_node]:
		if is_instance_valid(obj):
			obj.visible = true
	if _reality_phone_node:
		_reality_phone_node.is_active = true
	_start_phone_glow()

	# 6) 淡入现实
	if _eye_overlay:
		_eye_overlay.hide()
	await _fade_blackout(0.0, 1.0)

	_freeze_player(false)
	InputManager.unblock_input("睁眼转场")
	_transition_running = false
	_safe_end_interaction()
	print("[Level_02] 进入 REALITY_PHONE_LOCKED")

	# 7) 醒来独白
	if level_data and level_data.wake_up_monologue != "":
		_show_narrative(level_data.wake_up_monologue)

## 清理干扰期所有表现（Tween 必须 kill / 循环音效停止 / 阴影敌人清场）
func _cleanup_dream_interference() -> void:
	_kill_red_tween()
	if _red_overlay:
		_red_overlay.hide()
		_red_overlay.color.a = 0.0
	if _phone_msg_panel:
		_phone_msg_panel.hide()
	if _wake_hint_label:
		_wake_hint_label.hide()
	if _shadow_spawn_timer:
		_shadow_spawn_timer.stop()
	_stop_sfx_loop(_sfx_phone_player)
	_sfx_phone_player = null
	_stop_sfx_loop(_sfx_noise_player)
	_sfx_noise_player = null
	# 清理全部梦境敌人（阴影 + 老街）: 走公开死亡流程外的直接清场
	for e in _shadow_enemies:
		if is_instance_valid(e):
			GameManager.unregister_enemy(e)
			e.queue_free()
	_shadow_enemies.clear()
	for e in _street_enemies:
		if is_instance_valid(e):
			GameManager.unregister_enemy(e)
			e.queue_free()
	_street_enemies.clear()

## 现实手机微光提示
var _phone_glow_tween: Tween = null
func _start_phone_glow() -> void:
	if not _reality_phone_node: return
	var indicator = _reality_phone_node.get_node_or_null("Indicator")
	if not indicator: return
	indicator.color = Color(0.9, 0.2, 0.2, 0.4)
	_phone_glow_tween = create_tween()
	_phone_glow_tween.set_loops()
	_phone_glow_tween.tween_property(indicator, "color:a", 0.7, 0.5)
	_phone_glow_tween.tween_property(indicator, "color:a", 0.25, 0.5)

func _stop_phone_glow() -> void:
	if _phone_glow_tween and is_instance_valid(_phone_glow_tween):
		_phone_glow_tween.kill()
	_phone_glow_tween = null


# ============================================================
# 现实流程: 手机 → 电脑(IDE+配置) → 床
# ============================================================

func _handle_reality_phone() -> void:
	if not level_data: return
	has_read_reality_phone = true
	_mark_interaction_completed("reality_phone")
	_stop_phone_glow()
	var message = "【%s】\n\n%s" % [level_data.reality_phone_sender, level_data.reality_phone_content]
	_show_narrative(message, func():
		_show_narrative(level_data.reality_phone_monologue, func():
			_unlock_reality_computer()
		)
	)

func _unlock_reality_computer() -> void:
	current_state = LevelState.REALITY_PHONE_READ
	if _reality_computer_node:
		_reality_computer_node.is_active = true
		var indicator = _reality_computer_node.get_node_or_null("Indicator")
		if indicator:
			indicator.color = Color(0.3, 0.6, 0.9, 0.4)
	print("[Level_02] 电脑解锁 — REALITY_PHONE_READ")

# ---- IDE 对话 ----

func _enter_ide_chat() -> void:
	_mark_interaction_completed("reality_computer")
	_is_interacting = true
	current_state = LevelState.REALITY_IDE_CHAT
	_freeze_player(true)
	InputManager.block_input("IDE对话", self)
	if _ide_ui: _ide_ui.show()
	current_chat_index = 0
	if _chat_window: _chat_window.text = ""
	_render_next_chat_line()
	print("[Level_02] 进入 REALITY_IDE_CHAT")

func _render_next_chat_line() -> void:
	if not level_data:
		_enter_config_edit(); return
	var total = mini(level_data.ide_speakers.size(), level_data.ide_texts.size())
	if current_chat_index >= total:
		_enter_config_edit(); return
	var speaker = level_data.ide_speakers[current_chat_index]
	var text = level_data.ide_texts[current_chat_index]
	var format_text = ""
	match speaker:
		"System": format_text = "[color=yellow][SYSTEM] " + text + "[/color]\n"
		"CodeBuddy", "AI": format_text = "[color=cyan]CodeBuddy: " + text + "[/color]\n"
		"Ming": format_text = "[color=white]阿明: " + text + "[/color]\n"
		_: format_text = text + "\n"
	if _chat_window: _chat_window.append_text(format_text)
	current_chat_index += 1

# ---- 配置篡改解谜 ----

func _enter_config_edit() -> void:
	current_state = LevelState.REALITY_CONFIG_EDIT
	# IDE 背景保留, 弹出配置编辑器; 输入屏蔽保持（按钮走鼠标, 不受 game_action 屏蔽影响）
	if not level_data: return
	for i in range(3):
		if i < level_data.config_item_labels.size() and i < _config_value_labels.size():
			var item_label = _config_ui.get_node_or_null("ItemLabel_%d" % i)
			if item_label:
				item_label.text = level_data.config_item_labels[i]
			var init_display = level_data.config_initial_display[i] if i < level_data.config_initial_display.size() else level_data.config_initial_values[i]
			_config_value_labels[i].text = "= " + init_display
	if _config_ui: _config_ui.show()
	print("[Level_02] 进入 REALITY_CONFIG_EDIT")

func _on_config_button_pressed(index: int) -> void:
	if current_state != LevelState.REALITY_CONFIG_EDIT: return
	if not level_data: return
	if index >= level_data.config_item_ids.size(): return
	_set_config_value(level_data.config_item_ids[index], level_data.config_target_values[index], index)

func _set_config_value(id: String, value: String, index: int) -> void:
	# 写入 flag（按目标类型转换）
	match id:
		"player_damage_reduction":
			config_flags[id] = (value == "true")
		"base_jump_height":
			config_flags[id] = int(value)
		"allow_external_signal":
			config_flags[id] = (value == "true")
		_:
			config_flags[id] = value
	# UI 反馈
	if index < _config_value_labels.size():
		var target_display = level_data.config_target_display[index] if (level_data and index < level_data.config_target_display.size()) else value
		_config_value_labels[index].text = "= " + target_display
		_config_value_labels[index].add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	if index < _config_feedback_labels.size() and index < level_data.config_success_feedbacks.size():
		_config_feedback_labels[index].text = level_data.config_success_feedbacks[index]
	if index < _config_buttons.size():
		_config_buttons[index].disabled = true
	print("[Level_02] 配置已修改: %s = %s" % [id, value])
	# 三项达标后启用重编译按钮
	if _can_recompile() and _recompile_button:
		_recompile_button.disabled = false

func _can_recompile() -> bool:
	return config_flags.get("player_damage_reduction", false) == true \
		and config_flags.get("base_jump_height", 10) == 99 \
		and config_flags.get("allow_external_signal", true) == false

# ---- 重新编译 ----

func _on_recompile_pressed() -> void:
	if current_state != LevelState.REALITY_CONFIG_EDIT: return
	if not _can_recompile(): return
	_run_recompile_sequence()

func _run_recompile_sequence() -> void:
	current_state = LevelState.REALITY_RECOMPILE
	if _config_ui: _config_ui.hide()
	if _recompile_panel: _recompile_panel.show()
	if _recompile_log: _recompile_log.text = ""
	print("[Level_02] 进入 REALITY_RECOMPILE")

	var lines: Array[String] = []
	if level_data:
		lines = level_data.recompilation_lines
	for line in lines:
		if _recompile_log:
			var color = "orange" if line.begins_with("[WARN]") else "lime"
			_recompile_log.append_text("[color=%s]%s[/color]\n" % [color, line])
		await get_tree().create_timer(0.45).timeout

	recompilation_done = true

	# 写入跨关卡梦境配置（关卡3读取应用）
	GameManager.dream_runtime_flags = {
		"player_damage_reduction": config_flags.get("player_damage_reduction", true),
		"base_jump_height": config_flags.get("base_jump_height", 99),
		"allow_external_signal": config_flags.get("allow_external_signal", false),
		"dream_version": "2.0"
	}
	print("[Level_02] dream_runtime_flags 已写入: ", GameManager.dream_runtime_flags)

	await get_tree().create_timer(1.0).timeout
	if _recompile_panel: _recompile_panel.hide()
	if _ide_ui: _ide_ui.hide()
	_freeze_player(false)
	InputManager.unblock_input("IDE对话")
	_is_interacting = false
	_interact_cooldown = 0.0

	# 编译成功叙事 → 解锁床
	_show_narrative(level_data.compile_success_text if level_data else "编译完成。", func():
		_unlock_reality_bed()
	)

func _unlock_reality_bed() -> void:
	current_state = LevelState.REALITY_BED_READY
	if _reality_bed_node:
		_reality_bed_node.is_active = true
		_reality_bed_node.reset_completed()
		# 床发蓝光
		var indicator = _reality_bed_node.get_node_or_null("Indicator")
		if indicator:
			indicator.color = Color(0.3, 0.5, 1.0, 0.3)
			if _bed_glow_tween and is_instance_valid(_bed_glow_tween):
				_bed_glow_tween.kill()
			_bed_glow_tween = create_tween()
			_bed_glow_tween.set_loops()
			_bed_glow_tween.tween_property(indicator, "color:a", 0.65, 0.8)
			_bed_glow_tween.tween_property(indicator, "color:a", 0.2, 0.8)
	print("[Level_02] 床已解锁 — REALITY_BED_READY")
	if level_data and level_data.bed_unlocked_text != "":
		_show_narrative(level_data.bed_unlocked_text)


# ============================================================
# 终局转场
# ============================================================

func _trigger_level_end() -> void:
	if _transition_running: return
	_transition_running = true
	_is_interacting = true
	_mark_interaction_completed("reality_bed")
	print("[Level_02] 终局转场开始")
	InputManager.block_input("关卡2终局转场", self)
	_freeze_player(true)
	if _bed_glow_tween and is_instance_valid(_bed_glow_tween):
		_bed_glow_tween.kill()
		_bed_glow_tween = null

	# 入梦渐黑
	await _fade_blackout(1.0, 1.2)

	# 显示终局提示, 等待 Enter
	current_state = LevelState.LEVEL_END_TRANSIT
	if _ending_prompt:
		_ending_prompt.show()
		if _ending_label and level_data:
			_ending_label.text = level_data.dream_rebuilt_text
	_transition_running = false
	_ending_enter_armed = true
	# 终局提示阶段解除全局屏蔽: Enter 经 game_action/_input 走 LEVEL_END_TRANSIT 分支
	InputManager.unblock_input("关卡2终局转场")

func _emit_level_complete() -> void:
	if _level_complete_emitted: return
	_level_complete_emitted = true
	var next_path = level_data.next_level_path if level_data else "res://LevelModule/Formal/Level_03.tscn"
	print("[Level_02] 发射 LEVEL_COMPLETE → ", next_path)
	# 全量清理（防跨关卡泄漏）
	_full_cleanup()
	EventBus.emit(GlobalDefine.EventName.LEVEL_COMPLETE, {
		"level": self,
		"next_level": next_path
	})

## 关卡退出全量清理: 循环 Tween / 计时器 / 音效 / 敌人 / 订阅 / 输入屏蔽
func _full_cleanup() -> void:
	_cleanup_dream_interference()
	_stop_phone_glow()
	if _bed_glow_tween and is_instance_valid(_bed_glow_tween):
		_bed_glow_tween.kill()
		_bed_glow_tween = null
	if _shadow_spawn_timer and is_instance_valid(_shadow_spawn_timer):
		_shadow_spawn_timer.stop()
	InputManager.unblock_input("关卡2清理")
	EventBus.unsubscribe_all(self)


# ============================================================
# 音效安全降级挂点
# ============================================================

## 循环音效: 资源存在则创建 AudioStreamPlayer 并循环播放, 否则返回 null（安全跳过）
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
