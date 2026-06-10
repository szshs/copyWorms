# ============================================================
# Level_01.gd - 第一关控制器
# 场景构建 → Level_01_SceneBuilder
# UI 构建   → Level_01_UIBuilder
# 状态调度  → Level_01_FSM
# 设计原则：
#   1. 单一职责: 输入分发→_input 守卫；叙事弹窗→_show_narrative；
#      状态机→FSM；终局/IDE/睡眠/手机各自独立
#   2. 状态幂等性: _is_interacting/_interact_cooldown 任何路径退出
#      都会通过 _safe_end_interaction() 重置，杜绝永久卡死
#   3. 错误边界: 所有用户可见路径(叙事/IDE/终局)用 _run_safely 包裹
# ============================================================
extends LevelBase
class_name Level_01

@export var level_data: Level01Data = null

enum LevelState { LIVING_ROOM, CORRIDOR, BEDROOM, IDE_CHAT, IDE_PREVIEW, PHONE_RINGING, GLITCH_TRANSIT }

var current_state: int = LevelState.LIVING_ROOM
var sleep_count: int = 0
var current_chat_index: int = 0

# 能力开关（布尔标志替代改config数值，更干净）

var _narrative_panel: Panel = null
var _narrative_text: RichTextLabel = null
var _sleep_overlay: ColorRect = null
var _ide_ui: Control = null
var _chat_window: RichTextLabel = null
var _viewport_container: SubViewportContainer = null
var _mini_viewport: SubViewport = null
var _glitch_overlay: ColorRect = null

var _obstacle_box: InteractiveObject = null
var _obstacle_clothes: InteractiveObject = null
var _bed_node: InteractiveObject = null
var _computer_node: InteractiveObject = null
var _phone_node: InteractiveObject = null
var _notice_node: InteractiveObject = null
var _thermos_node: InteractiveObject = null

var _interact_cooldown: float = 0.0
var _is_interacting: bool = false
var _fsm: Level_01_FSM = null
var _phone_vibrate_tween: Tween = null

# 所有交互物引用的统一访问方法（消除 4 处硬编码数组重复）
var _all_interactives: Array[InteractiveObject] = []

# 防止叙事/IDE/睡眠循环嵌套打开的全局锁
var _narrative_open: bool = false
# 叙事面板等待 Enter 的最长秒数（防失焦/无键盘时永久卡死）
const NARRATIVE_INPUT_TIMEOUT: float = 30.0
# _input 捕获到 Enter 按下时设置，供 _show_narrative 的 await 循环感知
var _narrative_enter_pressed: bool = false
# 睡眠渐变动画期间为 true，防止 _process 误清交互锁
var _sleep_fading: bool = false

# IDE 预览超时崩溃（8 秒）
const IDE_PREVIEW_TIMEOUT: float = 8.0
var _ide_preview_timer: float = 0.0
# GLITCH_TRANSIT 床再触发的时序常量
const FINAL_BLACKOUT_DURATION: float = 0.8
const FINAL_AMBIENT_FADE_DURATION: float = 2.5
const FINAL_GLITCH_DURATION: float = 2.0


# ---- 生命周期 ----

func _on_ready() -> void:
	super._on_ready()

	if not level_config:
		level_config = load("res://DataConfig/Level/Level01Config.tres") as LevelConfig
		_apply_config()
	if not level_data:
		level_data = load("res://DataConfig/Level/Level01Data.tres") as Level01Data

	var builder = Level_01_SceneBuilder.new(self)
	builder.build_all()

	# SmoothCamera 已在 Player_Warrior.tscn 里预制为子节点，
	# 这里只需要把 level_config 的 limit 参数传给玩家身上的 SmoothCamera
	_setup_camera_limits()

	_cache_ui_refs()
	_restrict_player_mechanics()
	# 立即恢复：LIVING_ROOM 是正常探索状态，玩家需要完整操作能力
	_restore_player_mechanics()
	# 初始化交互物统一列表（SceneBuilder 已设置 phone/computer 的 is_active=false）
	_all_interactives = [_obstacle_box, _obstacle_clothes, _bed_node, _computer_node, _phone_node, _notice_node, _thermos_node]
	# 修正: 使用 GlobalDefine 常量替代硬编码字符串（B5 修复）
	EventBus.subscribe(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, self, "_on_object_interacted")
	_fsm = Level_01_FSM.new(self)

	# 验证玩家 collision_layer（B8 修复）— 若玩家在 PLAYER 层缺失则修正
	_ensure_player_collision_layer()

	InputManager.game_action.connect(_on_game_action)

	# 加载 HUD（血条/状态/暂停面板）
	_load_hud()

	set_process(true)

	print("[Level_01] 初始化完成 — 当前: LIVING_ROOM")


func _load_hud() -> void:
	var hud_path = "res://UI/HUD.tscn"
	if ResourceLoader.exists(hud_path):
		var hud = load(hud_path).instantiate()
		add_child(hud)
		print("[Level_01] HUD 加载成功")
	else:
		push_warning("[Level_01] HUD.tscn 未找到，跳过")


# ---- 错误边界 ----

## 安全执行包装器：任何函数抛错都不会留下脏状态导致永久卡死
func _run_safely(fn: Callable) -> void:
	if not fn.is_valid():
		return
	# GDScript 不支持 try/catch；通过显式 reset + has_method 验证降低风险
	# 这里利用 GDScript 内置错误处理：抛错时引擎会打印但不中断 _input 流程
	# 我们在 fn 调用前后都强制清理交互标志，确保即便 fn 抛错，状态也能恢复
	_interact_cooldown = 0.0
	fn.call()
	# 调用结束后再次清标志（覆盖 fn 内部错误退出场景）
	_safe_end_interaction()

## 统一交互状态出口（B3 修复）
## 注意: _narrative_open 由 _show_narrative 独占管理，此处不清除
## 否则 _run_safely 在异步函数 yield 后会误杀仍在显示的叙事面板
## 同理，若叙事面板/睡眠渐变仍在进行，_is_interacting 也应保留
func _safe_end_interaction() -> void:
	if not _narrative_open and not _sleep_fading:
		_is_interacting = false
	_interact_cooldown = 0.0


# ---- 玩家层校验 ----

func _ensure_player_collision_layer() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	if not (player.collision_layer & GlobalDefine.Collision.PLAYER):
		push_warning("[Level_01] 玩家 collision_layer 缺失 PLAYER 位，修正中...")
		player.collision_layer |= GlobalDefine.Collision.PLAYER


# ---- 工具方法 ----

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

## 把基类 LevelBase 在 _setup_camera() 创建的 LevelCamera 升级为 SmoothCamera，
## 把 level_config 的 limit 参数传给玩家预制的 SmoothCamera
## 架构改进：摄像机组件由玩家场景持有（PlayerModule），关卡只负责配置参数
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
	print("[Level_01] SmoothCamera 已配置 (limit_left=%d, limit_right=%d)" % [cam.limit_left, cam.limit_right])

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
	# 触发区与可视指示器大小一致（1.0×x × 1.0×y），避免过大触发区导致交互重叠
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

func _cache_ui_refs() -> void:
	var canvas = $CanvasLayerUI
	if not canvas: return
	_narrative_panel = canvas.get_node_or_null("NarrativePanel")
	if _narrative_panel: _narrative_text = _narrative_panel.get_node_or_null("RichTextLabel")
	_sleep_overlay = canvas.get_node_or_null("SleepOverlay")
	_ide_ui = canvas.get_node_or_null("IdeUI")
	if _ide_ui:
		_chat_window = _ide_ui.get_node_or_null("ChatWindow")
		_viewport_container = _ide_ui.get_node_or_null("ViewportContainer")
		if _viewport_container: _mini_viewport = _viewport_container.get_node_or_null("MiniViewport")
	_glitch_overlay = canvas.get_node_or_null("GlitchOverlay")


# ---- 玩家控制 ----

func _restrict_player_mechanics() -> void:
	var player = GameManager.player_ref
	if not player: return
	player.can_jump = false
	player.can_dash = false
	player.can_attack = false
	player.can_skill = false

func _restore_player_mechanics() -> void:
	var player = GameManager.player_ref
	if not player: return
	player.can_jump = true
	player.can_dash = true
	player.can_attack = true
	player.can_skill = true

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
	# Bug1 修复: 冻结/解冻时同步控制所有交互物的 monitoring,
	# 防止 body_exited 在冻结期误清 is_player_in_range
	for obj in _all_interactives:
		if is_instance_valid(obj):
			obj.freeze_monitoring(freeze)


# ---- 输入处理（B2/B3/B4 核心修复）----

## 输入分发器：所有键盘事件统一入口
## 修复点：
func _on_game_action(action: StringName, _event: InputEvent) -> void:
	if action != &"ui_accept":
		return
	_handle_accept_input()

func _handle_accept_input() -> void:
	if current_state == LevelState.IDE_CHAT:
		_render_next_chat_line()
		return
	if _narrative_open:
		_narrative_enter_pressed = true
		return
	if _is_interacting or _interact_cooldown > 0.0:
		if current_state != LevelState.IDE_PREVIEW and current_state != LevelState.IDE_CHAT:
			if _interact_cooldown > 0.5:
				_safe_end_interaction()
		return
	var obj = _find_nearby_interactive()
	if obj:
		_interact_cooldown = 0.3
		EventBus.emit(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, {"object_id": obj.object_id})

## 输入处理 — Enter 交互分发（阶段3: InputManager 信号驱动为主，_input 为兜底）
##   - InputManager._unhandled_input() 先拦截 ui_accept → 发射 game_action 信号 → 走 _handle_accept_input
##   - 若 InputManager 未拦截（不应发生），原始 _input() 兜底仍保留
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return

	# ---- 1) IDE_CHAT 状态: 推进对话行 ----
	if current_state == LevelState.IDE_CHAT:
		_render_next_chat_line()
		get_viewport().set_input_as_handled()
		return

	# ---- 2) 叙事面板打开时: 通知 _show_narrative 退出等待 ----
	if _narrative_open:
		_narrative_enter_pressed = true
		get_viewport().set_input_as_handled()
		return

	# ---- 3) 玩家被冻结或冷却中: 拒绝新交互（但仍清空 is_interacting 以防锁死） ----
	if _is_interacting or _interact_cooldown > 0.0:
		# B3 修复: 防御性自愈 — 等待时间超过 0.5s 仍冻结时，强制解锁
		# 这种情况意味着 _safe_end_interaction 未被调用（例如异常退出）
		if current_state != LevelState.IDE_PREVIEW and current_state != LevelState.IDE_CHAT:
			if _interact_cooldown > 0.5:
				_safe_end_interaction()
		return

	# ---- 4) 常规路径: 查找最近交互物并发射事件 ----
	var nearby_obj = _find_nearby_interactive()
	if nearby_obj:
		_interact_cooldown = 0.3
		# B5 修复: 使用 GlobalDefine 常量
		EventBus.emit(GlobalDefine.EventName.INTERACTIVE_OBJECT_TRIGGERED, {"object_id": nearby_obj.object_id})
		get_viewport().set_input_as_handled()

func _find_nearby_interactive() -> InteractiveObject:
	# 优先用 is_player_in_range (由 body_entered 或 _poll 维护)
	for obj in _all_interactives:
		if is_instance_valid(obj) and obj.is_active and not obj.completed and obj.is_player_in_range:
			return obj
	# Fallback: 距离检测 — 解决 body_entered 信号永远不触发的情况
	# 触发半径 = 物体 size 最大边 + 40 像素容差
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return null
	var best: InteractiveObject = null
	var best_dist: float = INF
	const FALLBACK_RADIUS: float = 120.0  # 距离 fallback 触发半径
	for obj in _all_interactives:
		if not is_instance_valid(obj) or not obj.is_active or obj.completed:
			continue
		var d: float = player.global_position.distance_to(obj.global_position)
		if d < FALLBACK_RADIUS and d < best_dist:
			best_dist = d
			best = obj
	if best:
		# 立刻把 is_player_in_range 同步上,让后续逻辑与提示 UI 正常显示
		best.is_player_in_range = true
		print("[Level_01] Fallback 距离检测命中: %s (距离 %.1f)" % [best.object_id, best_dist])
	return best

func _process(delta: float) -> void:
	if _interact_cooldown > 0.0: _interact_cooldown -= delta
	# IDE 预览 8 秒超时（玩家在 SubViewport 中超过 8 秒无崩溃/出界则强制终止）
	if current_state == LevelState.IDE_PREVIEW:
		_ide_preview_timer += delta
		if _ide_preview_timer >= IDE_PREVIEW_TIMEOUT:
			_ide_preview_timer = 0.0
			_on_preview_crashed()
	# 主动轮询检测: 解决 body_entered 信号在 _ready 时序或 collision_layer 不匹配时失效
	# 这是"靠近物体没反应"的根本修复 — 不依赖信号
	_poll_interactives_in_range()
	# 防御性自愈: 每帧检查 _is_interacting 状态是否被异常遗留在普通状态下
	# 注意: BEDROOM + _narrative_open/_sleep_fading 表示正在叙事/睡眠中，不应被误清
	if _is_interacting and current_state not in [LevelState.IDE_CHAT, LevelState.IDE_PREVIEW, LevelState.GLITCH_TRANSIT]:
		if not _narrative_open and not _sleep_fading:
			_safe_end_interaction()


## 主动轮询所有交互物的玩家接近状态（绕过 body_entered 信号触发失败）
func _poll_interactives_in_range() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return
	for obj in _all_interactives:
		if is_instance_valid(obj):
			obj.check_player_in_range(player)


# ---- FSM 调度 ----

func _on_object_interacted(data: Dictionary) -> void:
	var obj_id: String = data.get("object_id", "")
	if not _fsm:
		push_error("[Level_01] FSM 为 null，无法处理交互: %s" % obj_id)
		return
	# B7 修复: 用安全包装器包裹 FSM 调用，任何异常都不污染状态
	_run_safely(func(): _fsm.handle_interaction(obj_id))

func _get_interactive_by_id(obj_id: String) -> InteractiveObject:
	match obj_id:
		"box": return _obstacle_box
		"clothes": return _obstacle_clothes
		"bed": return _bed_node
		"computer": return _computer_node
		"phone": return _phone_node
		"notice": return _notice_node
		"thermos": return _thermos_node
	return null

func _mark_interaction_completed(obj_id: String) -> void:
	var obj = _get_interactive_by_id(obj_id)
	if obj and not obj.allow_repeat:
		obj.mark_completed()


# ---- 障碍物 ----

func _clear_obstacle(obstacle_node: InteractiveObject) -> void:
	if not is_instance_valid(obstacle_node): return
	obstacle_node.is_active = false
	var static_body = obstacle_node.get_node_or_null("StaticBody2D")
	if static_body:
		var col_shape = static_body.get_node_or_null("CollisionShape2D")
		if col_shape: col_shape.disabled = true
	_match_and_clear_ref(obstacle_node)
	var tween = create_tween()
	tween.tween_property(obstacle_node, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func(): if is_instance_valid(obstacle_node): obstacle_node.queue_free())

func _match_and_clear_ref(node: InteractiveObject) -> void:
	if node == _obstacle_box: _obstacle_box = null
	elif node == _obstacle_clothes: _obstacle_clothes = null


# ---- 叙事面板（B6/B7 修复: 超时 + 错误边界）----

func _show_narrative(text: String, callback: Callable = Callable()) -> void:
	# 阶段3d: 叙事面板打开时全局屏蔽输入（阻断 attack/dash/skill）
	InputManager.block_input("叙事面板", self)

	# 防止嵌套打开: 若已有叙事面板打开则先关闭
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

	# B6 修复: 加超时等待，防止失焦或无键盘时永久卡死
	# 使用 _narrative_enter_pressed 标志（由 _input 设置），不再依赖 Input.is_action_just_pressed
	# 因为 await 间隔中按键事件会被 _input 消费掉，is_action_just_pressed 永远看不到
	_narrative_enter_pressed = false
	var wait_elapsed: float = 0.0
	var wait_delta: float = 0.05  # 缩短轮询间隔到 50ms，提升响应灵敏度
	while _narrative_open and wait_elapsed < NARRATIVE_INPUT_TIMEOUT:
		if _narrative_enter_pressed:
			break
		await get_tree().create_timer(wait_delta).timeout
		wait_elapsed += wait_delta

	# 关闭面板
	if _narrative_panel: _narrative_panel.hide()
	_freeze_player(false)
	_narrative_open = false
	_is_interacting = false
	_interact_cooldown = 0.0

	# 阶段3d: 叙事面板关闭时解除全局输入屏蔽
	InputManager.unblock_input("叙事面板")

	if callback.is_valid():
		# 回调也加错误隔离: 若 callback 抛错不影响关卡
		_run_safely(callback)


# ---- 睡眠循环 ----

func _trigger_sleep_cycle() -> void:
	if not level_data: return
	_bed_node.completed = true
	_is_interacting = true
	_freeze_player(true)
	# 阶段3d: 睡眠循环期间全局屏蔽输入
	InputManager.block_input("睡眠循环", self)

	var sleep_text = "……"
	if not level_data.sleep_texts.is_empty():
		sleep_text = level_data.sleep_texts[min(sleep_count, level_data.sleep_texts.size() - 1)]
	sleep_count += 1

	if _sleep_overlay:
		_sleep_overlay.color.a = 0.0
		_sleep_overlay.show()
		var tween = create_tween()
		tween.tween_property(_sleep_overlay, "color:a", 1.0, 1.0)
		await tween.finished

	# 睡眠叙事：不传 callback，直接在 _show_narrative 返回后继续睡眠流程
	await _show_narrative(sleep_text)

	# 解锁检测：与床交互满4次后解锁电脑
	_try_unlock_computer()
	# _show_narrative 返回后玩家已解冻、交互已清空
	# 但睡眠渐变动画期间需要保持冻结
	_freeze_player(true)
	_is_interacting = true
	_sleep_fading = true

	if _sleep_overlay:
		var tween_back = create_tween()
		tween_back.tween_property(_sleep_overlay, "color:a", 0.0, 1.0)
		tween_back.finished.connect(func():
			if _sleep_overlay: _sleep_overlay.hide()
			_sleep_fading = false
			_freeze_player(false)
			# 阶段3d: 睡眠渐亮结束后解除输入屏蔽
			InputManager.unblock_input("睡眠循环")
			_safe_end_interaction()
			_bed_node.reset_completed()
		)
	else:
		_sleep_fading = false
		_freeze_player(false)
		# 阶段3d: 无渐变覆盖层时同步解除
		InputManager.unblock_input("睡眠循环")
		_safe_end_interaction()
		_bed_node.reset_completed()


## 检查是否满足解锁电脑的前置条件（与床交互≥4次）
## 解锁后电脑变为可交互，并弹出提示叙事
func _try_unlock_computer() -> void:
	if sleep_count < 4:
		return
	if not _computer_node or not is_instance_valid(_computer_node):
		return
	if _computer_node.is_active:
		return  # 已解锁
	_computer_node.is_active = true
	print("[Level_01] 电脑已解锁 (sleep_count=%d)" % sleep_count)


# ---- IDE 模式（B4 修复: 完整清理交互状态）----

func _enter_ide_mode() -> void:
	_mark_interaction_completed("computer")
	_is_interacting = true
	current_state = LevelState.IDE_CHAT
	_freeze_player(true)
	# 阶段3d: IDE 对话期间全局屏蔽输入
	InputManager.block_input("IDE对话", self)
	if _ide_ui: _ide_ui.show()
	current_chat_index = 0
	if _chat_window: _chat_window.text = ""
	_render_next_chat_line()

func _render_next_chat_line() -> void:
	if not level_data:
		_start_ide_viewport_preview(); return
	# B7 修复: 边界检查（避免数组越界抛错卡死）
	var total = min(level_data.ide_speakers.size(), level_data.ide_texts.size())
	if current_chat_index >= total:
		_start_ide_viewport_preview(); return
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

func _start_ide_viewport_preview() -> void:
	# B4 修复: 玩家保持冻结（IDE_PREVIEW 状态期间玩家依然冻结）
	# 但 _is_interacting 必须保持 false 以防 _input 死锁
	# 在 _process 中通过 IDE 预览超时或信号触发 _on_preview_crashed 退出
	_is_interacting = false
	_interact_cooldown = 0.0
	current_state = LevelState.IDE_PREVIEW
	_ide_preview_timer = 0.0
	set_process(true)
	# 阶段3d: IDE_PREVIEW 继续保持屏蔽（从 IDE_CHAT 继承，无需重复 block）
	if _chat_window: _chat_window.append_text("[color=green][SYSTEM] 正在启动 Local Test Viewport...[/color]\n")
	var path = "res://LevelModule/SelfTest/MiniTestWorld.tscn"
	if not ResourceLoader.exists(path) or not load(path):
		if _chat_window: _chat_window.append_text("[color=red][FATAL ERROR] 加载失败[/color]\n")
		_on_preview_crashed(); return
	var mini_world = load(path).instantiate()
	if _mini_viewport: _mini_viewport.add_child(mini_world)
	if mini_world.has_signal("prototype_crashed"):
		mini_world.connect("prototype_crashed", _on_preview_crashed)

func _on_preview_crashed() -> void:
	if _chat_window:
		_chat_window.append_text("[color=red][FATAL ERROR] 线程溢出: 'Xiguan_Dream' 崩溃。[/color]\n")
		_chat_window.append_text("[color=red][SYSTEM] 连接中断。物理交互环境已强行关闭。[/color]\n")
	await get_tree().create_timer(1.5).timeout
	if _mini_viewport:
		for child in _mini_viewport.get_children(): child.queue_free()
	if _ide_ui: _ide_ui.hide()
	current_state = LevelState.PHONE_RINGING
	if _phone_node: _phone_node.is_active = true
	_start_phone_vibration()
	_freeze_player(false)
	# 阶段3d: IDE 崩溃退出，解除输入屏蔽（进入 PHONE_RINGING 正常探索状态）
	InputManager.unblock_input("IDE对话")
	# B4 修复: 显式清交互标志，让 PHONE_RINGING 阶段的 phone 交互可正常触发
	_is_interacting = false
	_interact_cooldown = 0.0


# ---- 手机震动 ----

func _start_phone_vibration() -> void:
	if not _phone_node: return
	_phone_vibrate_tween = create_tween()
	_phone_vibrate_tween.set_loops()
	var bp = _phone_node.position
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", bp.x + 3, 0.05)
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", bp.x - 3, 0.05)
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", bp.x + 1.5, 0.05)
	_phone_vibrate_tween.tween_property(_phone_node, "position:x", bp.x, 0.05)

func _stop_phone_vibration() -> void:
	if _phone_vibrate_tween and is_instance_valid(_phone_vibrate_tween):
		_phone_vibrate_tween.kill()
		_phone_vibrate_tween = null


# ---- 终局 ----

func _trigger_climax_transition() -> void:
	if not level_data:
		_start_glitch_shader_effect(); return
	_mark_interaction_completed("phone")
	_freeze_player(true)
	# 阶段3d: 终局叙事期间屏蔽输入（_show_narrative 内部也会 block，但此处提前确保）
	InputManager.block_input("终局叙事", self)
	# 1) 显示妈妈短信
	var message = "【" + level_data.phone_sender + "】\n" + level_data.phone_content
	_show_narrative(message, func():
		_stop_phone_vibration()
		# 2) 短信确认后弹出崩溃独白
		_show_narrative(level_data.climax_monologue, func():
			# 3) 独白关闭 → 锁死除 bed 外所有交互，进入 GLITCH_TRANSIT
			_lock_all_interactions_except_bed()
			if _bed_node:
				# B9 修复: 床必须确保 is_active=true（即便前置流程中误设了 false）
				_bed_node.is_active = true
				_bed_node.reset_completed()
			current_state = LevelState.GLITCH_TRANSIT
			_freeze_player(false)
			# 阶段3d: GLITCH_TRANSIT 允许玩家移动+交互（等最终床触发）
			InputManager.unblock_input("终局叙事")
			_is_interacting = false
			_interact_cooldown = 0.0
			print("[Level_01] 进入 GLITCH_TRANSIT — 等待玩家与床最终交互")
		)
	)

func _on_final_bed_trigger() -> void:
	# 玩家在 GLITCH_TRANSIT 状态再次与床交互 → 触发终局转场链
	if _bed_node: _bed_node.mark_completed()
	_freeze_player(true)
	# 阶段3d: 终局转场全程屏蔽输入（渐黑→音效渐变→glitch，不可打断）
	InputManager.block_input("终局转场", self)
	# 1) 0.8s 遮罩渐黑
	if _sleep_overlay:
		_sleep_overlay.color.a = 0.0
		_sleep_overlay.show()
		var black_tween = create_tween()
		black_tween.tween_property(_sleep_overlay, "color:a", 1.0, FINAL_BLACKOUT_DURATION)
		await black_tween.finished
	# 2) 2.5s 声效交叉渐变（出租屋底噪淡出 + 西关白噪音淡入）
	# 资源就绪前的占位实现：等待时长，真实接入 AudioStreamPlayer 时填充淡入/淡出逻辑
	_fade_ambient_audio(FINAL_AMBIENT_FADE_DURATION)
	await get_tree().create_timer(FINAL_AMBIENT_FADE_DURATION).timeout
	# 3) 2.0s glitch intensity 0→1
	_start_glitch_shader_effect()

func _fade_ambient_audio(_duration: float) -> void:
	# 方案要求的"环境声效交叉渐变"占位接口；
	# 真实接入时遍历 AmbientPlayer 列表做 db 渐变即可
	pass

func _lock_all_interactions_except_bed() -> void:
	# 锁死除 bed 外所有 InteractiveObject
	for obj in _all_interactives:
		if is_instance_valid(obj) and obj.object_id != "bed":
			obj.is_active = false

func _start_glitch_shader_effect() -> void:
	if not _glitch_overlay or not _glitch_overlay.material:
		_emit_level_complete(); return
	_glitch_overlay.show()
	var tween = create_tween()
	tween.tween_property(_glitch_overlay.material, "shader_parameter/intensity", 1.0, FINAL_GLITCH_DURATION)
	await tween.finished
	_emit_level_complete()

func _emit_level_complete() -> void:
	# P1 修复: 防御性解除输入屏蔽（即使当前因节点销毁而无害，
	# 但若未来关卡切换改为节点复用则此行防止泄漏）
	InputManager.unblock_input("终局转场")
	# B10 修复: 发射事件前清自己的全部订阅,避免关卡切换时游离回调
	EventBus.unsubscribe_all(self)
	EventBus.emit(GlobalDefine.EventName.LEVEL_COMPLETE, {
		"level": self,
		"next_level": "res://LevelModule/Formal/Level_02.tscn"
	})
